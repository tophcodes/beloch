# Sparse spatially-indexed layer ordering — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `Fold_state`'s dense `rel array array` layer order with a sparse, sweep-and-prune-built structure so distributed fold patterns (tessellations) evaluate in sub-quadratic time, with byte-identical output.

**Architecture:** New `lib/layer_order.ml` holds an abstract sparse order (per-face `(j → rel)` hashtables) built by an exact sweep-and-prune broad phase over face bounding boxes. `Fold_state.t.order` becomes `Layer_order.t`; the per-fold hot paths (`build_order`, `validity_error`, `subdivide`, `fold_with_records`, `flip`, `topmost_preimage`) use the sparse API; the one-time `fold_emit` keeps its nested loop via `Layer_order.get`.

**Tech Stack:** OCaml, dune, zarith (`Num`/`Q`), alcotest. No new dependencies.

## Global Constraints

- **Byte-identical output**: every golden `.fold` (esp. `faceOrders` arrays) unchanged. Hard gate — a golden diff is a real regression, never "bless" it.
- **Exact decision path**: overlap is decided ONLY by `Geom.convex_overlap`. The spatial index is a conservative broad-phase cull over exact `Num` bounding boxes — no float in the decision, and it can never drop a real overlap.
- **Semantics unchanged**: the layer model (framing A), validity rules (Above-cycle + tortilla-tortilla; taco-taco/taco-tortilla still deferred), and messages are identical.
- **Sparse invariant**: the order stores every OVERLAPPING pair with its `rel ∈ {Above,Below,Apart}`. Absent = not overlapping. `present with Apart` = overlap-but-undecided = a tortilla-tortilla violation.
- Build/test from the worktree root with `dune build` / `dune test` (a `dune-workspace` pins the build root). Never `dune exec tests/*.exe` directly for golden — CWD-relative example reads need `dune test`.

---

### Task 1: `Layer_order` module + unit tests

Self-contained new module and its tests. No `Fold_state` change yet.

**Files:**
- Create: `lib/layer_order.ml`
- Create: `tests/test_layer_order.ml`
- Modify: `tests/dune` (register the new test)

**Interfaces:**
- Consumes: `Geom.point`, `Geom.convex_overlap`, `Num.compare`.
- Produces:
  - `type rel = Above | Below | Apart`
  - `val negate : rel -> rel`
  - `type t`
  - `val build : Geom.point array array -> (int -> int -> rel) -> t`
    — `polys.(i)` is face `i`'s table-space polygon; `rel_of i j` gives the relation for each overlapping pair. Stores every overlapping pair (incl. `Apart`).
  - `val get : t -> int -> int -> rel` — `Apart` when absent.
  - `val iter : t -> (int -> int -> rel -> unit) -> unit` — each overlapping pair once as `i<j`.
  - `val above_neighbors : t -> int -> int list` — `j` with `get t i j = Above`.
  - `val flip : t -> int -> t` — for `n` faces, remap `k ↦ n-1-k` and negate every relation.

- [ ] **Step 1: Write the module**

Create `lib/layer_order.ml`:

```ocaml
(** Sparse layer order for folded states. Stores, for each face, the relation
    to every face it OVERLAPS on the table (Above/Below/Apart); non-overlapping
    pairs are absent. Built by an exact sweep-and-prune broad phase so
    distributed patterns cost O(n log n + overlapping pairs) instead of O(n²).
    The spatial index only culls candidate pairs; overlap is always decided by
    the exact Geom.convex_overlap. *)

type rel = Above | Below | Apart

let negate = function Above -> Below | Below -> Above | Apart -> Apart

(* adj.(i) maps j -> relation of i to j, for every j overlapping i. Symmetric:
   adj.(i)[j] = r  ⟺  adj.(j)[i] = negate r. *)
type t = { n : int; adj : (int, rel) Hashtbl.t array }

let get (t : t) (i : int) (j : int) : rel =
  if i = j then Apart
  else match Hashtbl.find_opt t.adj.(i) j with Some r -> r | None -> Apart

(* exact table-space bounding box of a polygon: (xmin, xmax, ymin, ymax) *)
let bbox (poly : Geom.point array) : Num.t * Num.t * Num.t * Num.t =
  let x0 = poly.(0).Geom.x and y0 = poly.(0).Geom.y in
  let xmin = ref x0 and xmax = ref x0 and ymin = ref y0 and ymax = ref y0 in
  Array.iter
    (fun (p : Geom.point) ->
      if Num.compare p.Geom.x !xmin < 0 then xmin := p.Geom.x;
      if Num.compare p.Geom.x !xmax > 0 then xmax := p.Geom.x;
      if Num.compare p.Geom.y !ymin < 0 then ymin := p.Geom.y;
      if Num.compare p.Geom.y !ymax > 0 then ymax := p.Geom.y)
    poly;
  (!xmin, !xmax, !ymin, !ymax)

let build (polys : Geom.point array array) (rel_of : int -> int -> rel) : t =
  let n = Array.length polys in
  let adj = Array.init n (fun _ -> Hashtbl.create 8) in
  if n > 1 then begin
    let boxes = Array.map bbox polys in
    (* indices sorted by bbox xmin, ascending *)
    let order = Array.init n (fun i -> i) in
    Array.sort
      (fun a b ->
        let (xa, _, _, _) = boxes.(a) and (xb, _, _, _) = boxes.(b) in
        Num.compare xa xb)
      order;
    (* sweep: active list holds indices whose xmax >= current xmin *)
    let active = ref [] in
    Array.iter
      (fun i ->
        let (xmin_i, _, ymin_i, ymax_i) = boxes.(i) in
        (* drop actives ending before i starts *)
        active := List.filter (fun k -> let (_, xmax_k, _, _) = boxes.(k) in
                                        Num.compare xmax_k xmin_i >= 0) !active;
        List.iter
          (fun k ->
            (* x-intervals overlap by construction; check y-interval overlap *)
            let (_, _, ymin_k, ymax_k) = boxes.(k) in
            if Num.compare ymin_i ymax_k <= 0 && Num.compare ymin_k ymax_i <= 0
               && Geom.convex_overlap polys.(i) polys.(k)
            then begin
              (* store both directions; rel_of is called canonically as (min,max) *)
              let a = min i k and b = max i k in
              let r = rel_of a b in
              Hashtbl.replace adj.(a) b r;
              Hashtbl.replace adj.(b) a (negate r)
            end)
          !active;
        active := i :: !active)
      order
  end;
  { n; adj }

let iter (t : t) (f : int -> int -> rel -> unit) : unit =
  for i = 0 to t.n - 1 do
    Hashtbl.iter (fun j r -> if i < j then f i j r) t.adj.(i)
  done

let above_neighbors (t : t) (i : int) : int list =
  if i < 0 || i >= t.n then []
  else Hashtbl.fold (fun j r acc -> if r = Above then j :: acc else acc) t.adj.(i) []

let flip (t : t) (n : int) : t =
  let adj = Array.init n (fun _ -> Hashtbl.create 8) in
  for i = 0 to t.n - 1 do
    Hashtbl.iter (fun j r -> Hashtbl.replace adj.(n - 1 - i) (n - 1 - j) (negate r))
      t.adj.(i)
  done;
  { n; adj }
```

- [ ] **Step 2: Write the failing test**

Create `tests/test_layer_order.ml`:

```ocaml
open Beloch
module L = Layer_order

let p x y = { Geom.x = Num.of_int x; y = Num.of_int y }
let sq cx cy = [| p cx cy; p (cx+2) cy; p (cx+2) (cy+2); p cx (cy+2) |]

(* reference O(n²) build: same overlap test, same rel_of *)
let ref_pairs polys rel_of =
  let n = Array.length polys in
  let acc = ref [] in
  for i = 0 to n - 1 do
    for j = i + 1 to n - 1 do
      if Geom.convex_overlap polys.(i) polys.(j) then acc := (i, j, rel_of i j) :: !acc
    done
  done;
  List.sort compare !acc

let test_sap_matches_reference () =
  (* a spread-out grid of unit-ish squares, some overlapping, some not *)
  let polys =
    [| sq 0 0; sq 1 1; sq 5 0; sq 6 1; sq 0 5; sq 3 3; sq 10 10 |]
  in
  let rel_of i j = if (i + j) land 1 = 0 then L.Above else L.Below in
  let t = L.build polys rel_of in
  let got = ref [] in
  L.iter t (fun i j r -> got := (i, j, r) :: !got);
  let got = List.sort compare !got in
  Alcotest.(check bool) "SAP pairs == reference pairs" true
    (got = ref_pairs polys rel_of)

let test_get_and_absent () =
  let polys = [| sq 0 0; sq 1 1; sq 10 10 |] in
  let t = L.build polys (fun _ _ -> L.Above) in
  Alcotest.(check bool) "overlapping 0-1 present" true (L.get t 0 1 = L.Above);
  Alcotest.(check bool) "symmetric 1-0 negated" true (L.get t 1 0 = L.Below);
  Alcotest.(check bool) "non-overlapping 0-2 absent = Apart" true (L.get t 0 2 = L.Apart);
  Alcotest.(check bool) "self = Apart" true (L.get t 0 0 = L.Apart)

let test_apart_stored_for_overlap () =
  (* overlapping pair whose rel_of says Apart must be RETRIEVABLE as Apart
     (tortilla-tortilla case) and appear in iter *)
  let polys = [| sq 0 0; sq 1 1 |] in
  let t = L.build polys (fun _ _ -> L.Apart) in
  Alcotest.(check bool) "overlap-but-Apart via get" true (L.get t 0 1 = L.Apart);
  let seen = ref false in
  L.iter t (fun i j r -> if i = 0 && j = 1 && r = L.Apart then seen := true);
  Alcotest.(check bool) "overlap-but-Apart in iter" true !seen

let test_above_neighbors () =
  let polys = [| sq 0 0; sq 1 1; sq 0 1 |] in (* all three overlap *)
  let t = L.build polys (fun _ _ -> L.Above) in (* i<j Above ⇒ 0>1,0>2,1>2 *)
  Alcotest.(check (list int)) "above neighbours of 0" [ 1; 2 ]
    (List.sort compare (L.above_neighbors t 0));
  Alcotest.(check (list int)) "above neighbours of 2" []
    (List.sort compare (L.above_neighbors t 2))

let test_flip_remaps_and_negates () =
  let polys = [| sq 0 0; sq 1 1 |] in
  let t = L.build polys (fun _ _ -> L.Above) in (* get 0 1 = Above, get 1 0 = Below *)
  let f = L.flip t 2 in
  (* flip remaps k↦1-k and negates: old adj.(1)[0]=Below → new adj.(0)[1]=Above *)
  Alcotest.(check bool) "flip: new get 0 1 = Above" true (L.get f 0 1 = L.Above);
  Alcotest.(check bool) "flip: new get 1 0 = Below" true (L.get f 1 0 = L.Below)

let () =
  Alcotest.run "layer_order"
    [ ( "layer_order",
        [ Alcotest.test_case "SAP matches reference" `Quick test_sap_matches_reference;
          Alcotest.test_case "get and absent" `Quick test_get_and_absent;
          Alcotest.test_case "Apart stored for overlap" `Quick test_apart_stored_for_overlap;
          Alcotest.test_case "above neighbours" `Quick test_above_neighbors;
          Alcotest.test_case "flip remaps and negates" `Quick test_flip_remaps_and_negates ] ) ]
```

Add to `tests/dune`:

```
(test
 (name test_layer_order)
 (libraries beloch alcotest zarith))
```

- [ ] **Step 3: Verify Layer_order is exported**

`lib/beloch.ml` re-exports every submodule (`module X = X`). Add, in alphabetical position near the other `module` lines:

```ocaml
module Layer_order = Layer_order
```

- [ ] **Step 4: Run tests**

Run: `dune build 2>&1 | tail; dune exec tests/test_layer_order.exe 2>&1 | tail`
Expected: build clean; 5/5 cases PASS. (RED-first is optional here — the module and its tests land together; if you prefer strict TDD, stub `build` to `{n=0;adj=[||]}` first, watch the reference test fail, then fill in.)

- [ ] **Step 5: Commit**

```bash
git add lib/layer_order.ml lib/beloch.ml tests/test_layer_order.ml tests/dune
git commit -m "feat(layer_order): sparse sweep-and-prune layer order module"
```

---

### Task 2: Swap `Fold_state` (and `fold_emit`) onto `Layer_order`

Atomic: changing `order`'s type forces every consumer, so all edits land together, gated by byte-identical golden output. `flip` and `topmost_preimage` are hot-adjacent; `fold_emit` runs once and keeps its nested loop via `get`.

**Files:**
- Modify: `lib/fold_state.ml` (type, `negate`, `build_order`, `validity_error`, `init_square`, `subdivide`, `fold_with_records`, `topmost_preimage`, `flip`)
- Modify: `lib/fold_emit.ml` (`faceOrders` loop)

**Interfaces:**
- Consumes: all of `Layer_order` from Task 1.
- Produces: `Fold_state.t` with `order : Layer_order.t`; `Fold_state.rel = Layer_order.rel` re-exported so external references (`Fold_state.Above` etc.) keep working.

- [ ] **Step 1: Retype and re-export in `fold_state.ml`**

Replace the local `rel`/`negate` (currently `lib/fold_state.ml:8` and `:37`) and the `t` record (`:26`). Delete the old `type rel = Above | Below | Apart` and `let negate = ...`, and instead near the top:

```ocaml
type rel = Layer_order.rel = Above | Below | Apart
let negate = Layer_order.negate
```

Change the record (`:26`) to:

```ocaml
type t = { faces : face array; order : Layer_order.t; edges : edge array }
```

- [ ] **Step 2: Replace `build_order`**

Delete the whole `build_order` function (`lib/fold_state.ml:45-58`) and replace with a thin adapter that feeds table polygons to `Layer_order.build`:

```ocaml
(* table-space polygon of a face — unchanged helper, keep it *)
(* (table_poly_of already exists at ~:40) *)

let build_order (faces : face array) (rel_of : int -> int -> rel) : Layer_order.t =
  Layer_order.build (Array.map table_poly_of faces) rel_of
```

`table_poly_of` already exists (`:40`). Every current caller (`subdivide` `:328`, `fold_with_records` `:479`) passes exactly `(faces, rel_of)`, so they are unchanged.

- [ ] **Step 3: Rewrite `validity_error` on the sparse API**

Replace the body (`lib/fold_state.ml:66-109`). The cycle DFS walks `Above` neighbours; the tortilla check iterates stored pairs for `Apart` (overlap-but-undecided). No `convex_overlap` in validity anymore (build already decided overlaps):

```ocaml
let validity_error (st : t) : string option =
  let n = Array.length st.faces in
  let color = Array.make n 0 (* 0 white, 1 gray, 2 black *) in
  let cycle = ref None in
  let rec dfs i =
    color.(i) <- 1;
    List.iter
      (fun j ->
        if !cycle = None then
          if color.(j) = 1 then
            cycle := Some
              (Printf.sprintf
                 "layer ordering: stacking cycle through faces %d and %d (paper \
                  through paper)" i j)
          else if color.(j) = 0 then dfs j)
      (Layer_order.above_neighbors st.order i);
    color.(i) <- 2
  in
  for i = 0 to n - 1 do
    if color.(i) = 0 && !cycle = None then dfs i
  done;
  match !cycle with
  | Some _ as c -> c
  | None ->
      let bad = ref None in
      Layer_order.iter st.order (fun i j r ->
          if !bad = None && r = Apart then
            bad := Some
              (Printf.sprintf
                 "layer ordering: faces %d and %d overlap but have no order \
                  (tortilla-tortilla)" i j));
      !bad
```

Note the message wording is copied verbatim from the current code so existing error-path tests keep matching.

- [ ] **Step 4: `init_square` and `topmost_preimage`**

`init_square` (`:111-118`) currently sets `order = [| [| Apart |] |]`. Replace that field with a 1-face empty order:

```ocaml
    order = Layer_order.build [| [| p 0 0; p 1 0; p 1 1; p 0 1 |] |] (fun _ _ -> Apart);
```

(One face → no pairs → empty. `p` is the local helper already defined in `init_square`.)

`topmost_preimage` (`:519-520`) reads `st.order.(i).(j)`. Change the `is_top` predicate:

```ocaml
  let is_top (i, _) =
    List.for_all (fun (j, _) -> i = j || Layer_order.get st.order i j <> Below) !covering
  in
```

- [ ] **Step 5: `flip`**

In `flip` (`lib/fold_state.ml:559-565`), delete the manual `order = Array.make_matrix …; for … order.(i).(j) <- negate …` block and replace with:

```ocaml
    let order = Layer_order.flip st.order n in
```

(`n` and `rev`/`edges` are already computed around it; the returned record `{ faces = rev; order; edges }` is otherwise unchanged.)

- [ ] **Step 6: `fold_emit` faceOrders via `get`**

In `lib/fold_emit.ml`, the loop (`:126-140`) binds `let order = fd.Eval.state.Fold_state.order in` then matches `order.(fi).(gi)`. Keep the nested `for fi … for gi>fi …` structure (runs once at emit; byte-identical order for free) and read via `get`:

```ocaml
  let order = fd.Eval.state.Fold_state.order in
  let nfaces = Array.length fd.Eval.state.Fold_state.faces in
  let face_orders = ref [] in
  for fi = 0 to nfaces - 1 do
    for gi = fi + 1 to nfaces - 1 do
      match Layer_order.get order fi gi with
      | Fold_state.Apart -> ()
      | rel ->
          let fi_below = rel = Fold_state.Below in
          let s = if fi_below then -1 else 1 in
          face_orders := `List [ `Int fi; `Int gi; `Int s ] :: !face_orders
    done
  done;
```

Match the surrounding names exactly — read the current lines first; the only changes are the loop bounds source (`nfaces`) and `order.(fi).(gi)` → `Layer_order.get order fi gi`. Everything else (the `s` computation, the `List.rev`, the `("faceOrders", …)` assembly at `:151`) stays byte-for-byte.

- [ ] **Step 7: Build and run the full suite — byte-identical gate**

Run: `dune build 2>&1 | tail` — expect clean.
Run: `dune test 2>&1 | tail -30`
Expected: ALL suites green, **including `golden`**. The golden `.fold` outputs (faceOrders) must be byte-identical. If `golden` fails, a relation or emission order diverged — DO NOT edit the golden files; debug the order build/emit until byte-identical. Likely suspects: `rel_of` canonicalisation (`build` calls `rel_of (min i j) (max i j)` — confirm callers' `rel_of` is symmetric-consistent, i.e. `rel_of i j = negate (rel_of j i)`; the existing closures read `st.order.(pi).(pj)` which already is), or `iter`/`get` returning a pair the dense matrix didn't.

- [ ] **Step 8: Commit**

```bash
git add lib/fold_state.ml lib/fold_emit.ml
git commit -m "refactor(fold_state): sparse Layer_order backs the layer order (byte-identical)"
```

---

### Task 3: Scaling regression test + verification

Prove the win and lock it against regression.

**Files:**
- Modify: `tests/test_fold_state.ml` (add a `Slow` scaling case)

**Interfaces:**
- Consumes: `Fold_state.init_square`, `Fold_state.fold_with_records`.

- [ ] **Step 1: Add the scaling test**

A DISTRIBUTED pattern (not an all-overlapping stack): fold at N well-separated vertical lines so most face pairs are spatially apart. Assert that doubling the fold count stays well under the 4× a dense O(faces²) build would cost. Add to `tests/test_fold_state.ml` before its runner:

```ocaml
let test_layer_scaling_subquadratic () =
  (* precrease N well-separated vertical creases via subdivide (grows faces
     linearly, overlaps stay local) and time it for N and 2N; sparse build
     should keep total time far below the 4x a quadratic build implies. *)
  let build n =
    let st = ref Fold_state.init_square in
    for k = 1 to n do
      let x = Q.make (Z.of_int k) (Z.of_int (n + 1)) in
      let axis = { Geom.a = Num.one; b = Num.zero; c = Num.of_q x } in
      st := Fold_state.subdivide !st axis ~prov:None
    done;
    !st
  in
  let time f = let t0 = Unix.gettimeofday () in ignore (f ()); Unix.gettimeofday () -. t0 in
  let t1 = time (fun () -> build 200) in
  let t2 = time (fun () -> build 400) in
  (* linear-face, local-overlap subdivide: doubling N should be well under 4x.
     Generous bound to avoid flakiness; a quadratic build would blow past it. *)
  Alcotest.(check bool)
    (Printf.sprintf "subdivide 400 (%.3fs) < 3.5x subdivide 200 (%.3fs)" t2 t1)
    true (t2 < 3.5 *. t1 +. 0.05)
```

Register it in `test_fold_state.ml`'s `Alcotest.run` list as `` `Slow ``:

```ocaml
          Alcotest.test_case "layer scaling sub-quadratic" `Slow
            test_layer_scaling_subquadratic;
```

(Confirm `test_fold_state.ml` links `unix` in `tests/dune`; if not, add `unix` to its `(libraries …)`.)

- [ ] **Step 2: Run it**

Run: `dune exec tests/test_fold_state.exe 2>&1 | tail`
Expected: PASS. If it fails because `subdivide` overlaps aren't local (all faces share the full-height strip → they DO overlap in y), switch the pattern to `fold_with_records` half-folds at separated lines, or relax the pattern to horizontal+vertical grid creases so overlaps localise. The assertion is a guard, not a micro-benchmark — keep the bound generous.

- [ ] **Step 3: Full suite + commit**

Run: `dune test 2>&1 | tail -20` — everything green, golden included.

```bash
git add tests/test_fold_state.ml tests/dune
git commit -m "test(fold_state): sub-quadratic layer-ordering scaling guard"
```

---

## Self-Review

- **Spec coverage:** New module `lib/layer_order.ml` → Task 1. Sparse rep (overlapping pairs, absent-vs-Apart) → Task 1 (`build`/`get`/`iter`) + tests. Sweep-and-prune exact broad phase → Task 1 `build`. Consumers adapted (validity, topmost, subdivide/fold via build_order, flip, fold_emit) → Task 2. Byte-identical faceOrders → Task 2 Step 6/7 (get-based nested loop = same order) + golden gate. `Layer_order` unit tests → Task 1. Scaling test → Task 3. Golden byte-identical hard gate → Task 2 Step 7. All spec sections mapped.
- **Divergence from spec (intentional):** spec described `fold_emit` via `iter` + explicit sort; the plan keeps the existing nested `for fi/for gi` loop with `Layer_order.get`, which emits in the same `(fi,gi)` order with no sort and is trivially byte-identical. `fold_emit` runs once per program, so its one-time O(n²) is negligible next to the per-fold savings. Same requirement (byte-identical faceOrders), simpler mechanism.
- **Placeholder scan:** none — every code step carries full code. Task 3 names a concrete fallback if the chosen pattern's overlaps aren't local; that is a contingency with a concrete alternative, not a TODO.
- **Type consistency:** `rel = Above|Below|Apart` and `negate` defined in Task 1, re-exported as `Fold_state.rel = Layer_order.rel` in Task 2 Step 1 so `Fold_state.Above`/`Fold_state.Apart` in `fold_emit` still resolve. `build : Geom.point array array -> (int->int->rel) -> t` in Task 1 matches the `Fold_state.build_order` adapter in Task 2 Step 2. `get`/`iter`/`above_neighbors`/`flip` signatures match their Task 2 uses.
- **Risk flagged for the implementer:** the golden byte-identical gate (Task 2 Step 7) is the make-or-break; the plan names the likely divergence suspects (`rel_of` canonicalisation, iter/get pair set) so the implementer debugs rather than blesses.
