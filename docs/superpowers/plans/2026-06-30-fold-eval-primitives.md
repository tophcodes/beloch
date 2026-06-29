# Fold-Evaluator Primitives Implementation Plan (Plan B-2a)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the pure `Fold_state` and `Geom` primitives the fold evaluator needs — precrease subdivision, folding that returns per-crease mountain/valley records, material-point resolution, convex-polygon overlap, and on-segment containment — all unit-tested in isolation.

**Architecture:** Extends the existing `Fold_state` (B-1) with `subdivide` (split faces, no move) and `fold_with_records` (the B-1 fold, also returning the crease records it creates with derived M/V from the orientation-parity rule), plus `paper_preimages` for material-point resolution. Extends `Geom` with `convex_overlap` (for `faceOrders`) and `on_segment` (for the emit edge→record lookup). No evaluator/output wiring yet.

**Tech Stack:** OCaml, dune, `Num` (exact), `Isometry` + `Fold_state` (from B-1), alcotest.

## Slice decomposition (context)

This is **Plan B-2a** of the fold-evaluator slice (design: `docs/superpowers/specs/2026-06-29-fold-evaluator-output-design.md`). It ships the pure primitives (no user-facing change — `@` still raises "not yet implemented" in `eval`). **Plan B-2b** — the `Eval` refactor (state threading, reference resolution), the dual `creasePattern` + `foldedForm` `Fold_emit` output (built directly from the face set, with M/V from these records and `faceOrders` from `convex_overlap`), and the `beloch.ml` rewire + regression re-baseline — is written separately, against these landed primitives and after a fresh `refs/foldformat.md` read for the `faceOrders` sign convention and the dual-frame vertex sharing.

## Global Constraints

- Build with `dune build`; test with `dune test` (from repo root — e2e examples use a relative path). Warnings fatal in the dev profile — builds clean.
- ocamlformat-clean (`.ocamlformat`: 0.29.0, default profile) — `dune fmt` before each commit.
- **All geometry exact via `Num` — no floating point.** `Num` API: `add`/`sub`/`mul`/`div`/`neg`/`sign`/`compare`/`equal`/`zero`/`one`/`of_int`.
- New `Fold_state` members are reached via the existing `module Fold_state = Fold_state` re-export in `lib/beloch.ml` (already present from B-1); same for `module Geom`. No new re-export needed.
- Faces are convex CCW (`Geom.point array`). Existing B-1 types (do not redefine): `Fold_state.face = { paper : Geom.point array; iso : Isometry.t }`, `Fold_state.t = { faces : face array; layers : int array }`, `Fold_state.init_square`, `Fold_state.table_polygon : t -> int -> Geom.point array`, `Fold_state.simple_fold : t -> axis:Geom.line -> move_side:int -> valley:bool -> t`. `Geom.point = { x; y }`, `Geom.line = { a; b; c }`, `Geom.segment = point * point`, and (from B-1) `Geom.side_of_line`, `Geom.clip_convex_halfplane`, `Geom.in_convex_polygon`, `Geom.intersection`, `Geom.line_through`, `Geom.seg_param`, `Geom.point_equal`.
- Test helpers already in `tests/test_beloch.ml`: `let q = Num.of_int`, `let pt x y = { Geom.x = q x; y = q y }`, `let half = Num.of_q (Q.of_ints 1 2)`.
- Commits: Conventional Commits; end the body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: `Fold_state` — subdivide, fold-with-records, paper preimages

**Files:**
- Modify: `lib/fold_state.ml`
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Produces (`Fold_state`):
  - `type assign = M | V | U`
  - `type crease_record = { ra : Geom.point; rb : Geom.point; assign : assign }` (segment in paper coords)
  - `axis_segment_in_face : face -> Geom.line -> (Geom.point * Geom.point) option` — where `axis` (table coords) crosses the face interior, returned in the face's **paper** coords; `None` if it misses.
  - `subdivide : t -> Geom.line -> t * crease_record list` — split every crossing face into two (both keep their isometry, no reflect, no restack); records carry `assign = U`.
  - `fold_with_records : t -> axis:Geom.line -> move_side:int -> valley:bool -> t * crease_record list` — like `simple_fold` but also returns the crease records, each `assign` = `if (valley <> (det_sign face < 0)) then V else M`.
  - `simple_fold` is redefined as `fst (fold_with_records …)` (B-1 API + tests preserved).
  - `paper_preimages : t -> Geom.point -> Geom.point list` — distinct paper coordinates whose current table position equals the given table point (one per overlapping layer).

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_beloch.ml` (after the existing `fold_state` tests):

```ocaml
let count_assign a recs =
  List.length (List.filter (fun (r : Fold_state.crease_record) -> r.Fold_state.assign = a) recs)

let test_fold_subdivide () =
  (* precrease the flat square along x=1/2: 2 faces, 1 crease record, assign U *)
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st, recs = Fold_state.subdivide Fold_state.init_square axis in
  Alcotest.(check int) "two faces after subdivide" 2 (Array.length st.Fold_state.faces);
  Alcotest.(check int) "one crease record" 1 (List.length recs);
  Alcotest.(check int) "subdivide records are U" 1 (count_assign Fold_state.U recs)

let test_fold_records_valley () =
  (* half fold valley: one V crease record *)
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let _, recs =
    Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1 ~valley:true
  in
  Alcotest.(check int) "one record" 1 (List.length recs);
  Alcotest.(check int) "the half fold is a valley" 1 (count_assign Fold_state.V recs);
  Alcotest.(check int) "no mountain" 0 (count_assign Fold_state.M recs)

let test_fold_records_accordion () =
  (* quarter fold: fold 1 (x=1/2) gives a stay face (det +1) and a moved face
     (det -1) both in the left half; fold 2 (y=1/2) cuts both -> one V and one M *)
  let axis1 = { Geom.a = q 1; b = q 0; c = half } in
  let st1 = Fold_state.simple_fold Fold_state.init_square ~axis:axis1 ~move_side:1 ~valley:true in
  let axis2 = { Geom.a = q 0; b = q 1; c = half } in
  let _, recs2 = Fold_state.fold_with_records st1 ~axis:axis2 ~move_side:1 ~valley:true in
  Alcotest.(check int) "two crease records from the second fold" 2 (List.length recs2);
  Alcotest.(check int) "one valley (accordion)" 1 (count_assign Fold_state.V recs2);
  Alcotest.(check int) "one mountain (accordion)" 1 (count_assign Fold_state.M recs2)

let test_fold_paper_preimages () =
  (* flat: a table point in the square has exactly one paper preimage.
     after a half fold, a point in the (overlapping) left half has two. *)
  let flat = Fold_state.paper_preimages Fold_state.init_square (fs_pt 1 0) in
  Alcotest.(check int) "one preimage when flat" 1 (List.length flat);
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold Fold_state.init_square ~axis ~move_side:1 ~valley:true in
  let folded = Fold_state.paper_preimages st { Geom.x = Num.of_q (Q.of_ints 1 4); y = q 0 } in
  Alcotest.(check int) "two preimages in the folded overlap" 2 (List.length folded)
```

Register in the existing `"fold_state"` group (append these four cases):

```ocaml
         Alcotest.test_case "subdivide" `Quick test_fold_subdivide;
         Alcotest.test_case "fold records valley" `Quick test_fold_records_valley;
         Alcotest.test_case "fold records accordion" `Quick test_fold_records_accordion;
         Alcotest.test_case "paper preimages" `Quick test_fold_paper_preimages;
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `Unbound … Fold_state.subdivide` (and friends).

- [ ] **Step 3: Implement in `lib/fold_state.ml`**

Add the types near the top (after the `face`/`t` definitions):

```ocaml
type assign = M | V | U
type crease_record = { ra : Geom.point; rb : Geom.point; assign : assign }
```

Add these functions (after `table_position`, before `simple_fold`):

```ocaml
(* The segment where the table-space line [axis] crosses face [f]'s interior,
   returned in [f]'s paper coordinates. None if the axis misses the interior
   (touches at most one boundary point). *)
let axis_segment_in_face (f : face) (axis : Geom.line) : (Geom.point * Geom.point) option =
  let table = Array.map (Isometry.apply_point f.iso) f.paper in
  let n = Array.length table in
  let pts = ref [] in
  let add p = if not (List.exists (Geom.point_equal p) !pts) then pts := p :: !pts in
  for i = 0 to n - 1 do
    let a = table.(i) and b = table.((i + 1) mod n) in
    let sa = Geom.side_of_line axis a and sb = Geom.side_of_line axis b in
    if sa = 0 then add a
    else if sb <> 0 && sa <> sb then
      match Geom.intersection axis (Geom.line_through a b) with
      | Some r -> add r
      | None -> ()
  done;
  match !pts with
  | [ p; q ] ->
      let inv = Isometry.inverse f.iso in
      Some (Isometry.apply_point inv p, Isometry.apply_point inv q)
  | _ -> None

(* Split every face crossing [axis] into its two halves (both keep their
   isometry; nothing moves). Returns the new state and one U crease record per
   face actually cut. *)
let subdivide (st : t) (axis : Geom.line) : t * crease_record list =
  let out = ref [] (* faces, accumulated top->bottom via prepend *) in
  let recs = ref [] in
  Array.iter
    (fun fi ->
      let f = st.faces.(fi) in
      let table = Array.map (Isometry.apply_point f.iso) f.paper in
      let inv = Isometry.inverse f.iso in
      let part keep =
        let sub = Geom.clip_convex_halfplane axis keep table in
        if Array.length sub >= 3 then
          Some { paper = Array.map (Isometry.apply_point inv) sub; iso = f.iso }
        else None
      in
      let plus = part 1 and minus = part (-1) in
      (match (plus, minus) with
       | Some _, Some _ -> (
           match axis_segment_in_face f axis with
           | Some (a, b) -> recs := { ra = a; rb = b; assign = U } :: !recs
           | None -> ())
       | _ -> ());
      List.iter
        (function Some face -> out := face :: !out | None -> ())
        [ plus; minus ])
    st.layers;
  let faces = Array.of_list (List.rev !out) in
  ({ faces; layers = Array.init (Array.length faces) (fun i -> i) }, !recs)

(* Like [simple_fold] but also returns the crease records created, each with its
   derived mountain/valley from the orientation-parity rule. *)
let fold_with_records (st : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) : t * crease_record list =
  let refl = Isometry.reflect_across_line axis in
  let stay = ref [] and mov = ref [] in
  let recs = ref [] in
  Array.iter
    (fun fi ->
      let f = st.faces.(fi) in
      let table = Array.map (Isometry.apply_point f.iso) f.paper in
      let inv = Isometry.inverse f.iso in
      let part keep iso =
        let sub = Geom.clip_convex_halfplane axis keep table in
        if Array.length sub >= 3 then
          Some { paper = Array.map (Isometry.apply_point inv) sub; iso }
        else None
      in
      let s = part (-move_side) f.iso in
      let m = part move_side (Isometry.compose refl f.iso) in
      (match (s, m) with
       | Some _, Some _ -> (
           match axis_segment_in_face f axis with
           | Some (a, b) ->
               let assign =
                 if valley <> (Isometry.det_sign f.iso < 0) then V else M
               in
               recs := { ra = a; rb = b; assign } :: !recs
           | None -> ())
       | _ -> ());
      (match s with Some face -> stay := face :: !stay | None -> ());
      match m with Some face -> mov := face :: !mov | None -> ())
    st.layers;
  let stationary = List.rev !stay in
  let moved = !mov in
  let ordered = if valley then stationary @ moved else moved @ stationary in
  let faces = Array.of_list ordered in
  ({ faces; layers = Array.init (Array.length faces) (fun i -> i) }, !recs)

(* Distinct paper coordinates whose current table position is [tp] (one per
   overlapping layer covering that table point). *)
let paper_preimages (st : t) (tp : Geom.point) : Geom.point list =
  let acc = ref [] in
  Array.iteri
    (fun i f ->
      if Geom.in_convex_polygon (table_polygon st i) tp then begin
        let pp = Isometry.apply_point (Isometry.inverse f.iso) tp in
        if not (List.exists (Geom.point_equal pp) !acc) then acc := pp :: !acc
      end)
    st.faces;
  List.rev !acc
```

Then **replace** the existing `simple_fold` body with a thin wrapper:

```ocaml
let simple_fold (st : t) ~(axis : Geom.line) ~(move_side : int) ~(valley : bool) :
    t =
  fst (fold_with_records st ~axis ~move_side ~valley)
```

- [ ] **Step 4: Run to verify they pass**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS — the four new cases plus the B-1 `fold_state` cases (which still use `simple_fold`) all green, build clean.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_state.ml tests/test_beloch.ml
git commit -m "feat(fold-state): subdivide, fold-with-records (M/V), paper preimages

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `Geom` — convex overlap and on-segment containment

**Files:**
- Modify: `lib/geom.ml` (append two functions)
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Produces:
  - `Geom.convex_overlap : point array -> point array -> bool` — true iff the two convex polygons share **positive** area (touching only at a shared edge/vertex is false). Separating-axis test over both polygons' edge normals.
  - `Geom.on_segment : segment -> point -> bool` — true iff `p` is collinear with the segment and lies within it (endpoints included).

- [ ] **Step 1: Write the failing tests**

```ocaml
let test_convex_overlap () =
  let unit = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let shifted_overlap = [| pt 0 0; pt 2 0; pt 2 2; pt 0 2 |] in
  (* the right half overlaps the unit square in positive area *)
  let right_half = [| { Geom.x = half; y = q 0 }; pt 1 0; pt 1 1; { Geom.x = half; y = q 1 } |] in
  Alcotest.(check bool) "unit overlaps a bigger square covering it" true
    (Geom.convex_overlap unit shifted_overlap);
  Alcotest.(check bool) "unit overlaps its right half" true
    (Geom.convex_overlap unit right_half);
  (* a square fully to the right (x in [2,3]) is disjoint *)
  let far = [| pt 2 0; pt 3 0; pt 3 1; pt 2 1 |] in
  Alcotest.(check bool) "disjoint squares do not overlap" false
    (Geom.convex_overlap unit far);
  (* a square sharing only the edge x=1 touches but has no positive overlap *)
  let touching = [| pt 1 0; pt 2 0; pt 2 1; pt 1 1 |] in
  Alcotest.(check bool) "edge-touching is not overlap" false
    (Geom.convex_overlap unit touching)

let test_on_segment () =
  let s = (pt 0 0, pt 2 2) in
  Alcotest.(check bool) "midpoint is on the segment" true (Geom.on_segment s (pt 1 1));
  Alcotest.(check bool) "endpoint is on the segment" true (Geom.on_segment s (pt 0 0));
  Alcotest.(check bool) "collinear but outside is not on" false (Geom.on_segment s (pt 3 3));
  Alcotest.(check bool) "off the line is not on" false (Geom.on_segment s (pt 1 0))
```

Register in a new `"fold_geom2"` group:

```ocaml
      ("fold_geom2",
       [ Alcotest.test_case "convex overlap" `Quick test_convex_overlap;
         Alcotest.test_case "on segment" `Quick test_on_segment ]);
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `Unbound value Geom.convex_overlap`.

- [ ] **Step 3: Implement in `lib/geom.ml`**

Append at the end of the file:

```ocaml
(* p collinear with segment (a,b) and within it (endpoints included). *)
let on_segment ((a, b) : segment) (p : point) : bool =
  let cross =
    Num.sub
      (Num.mul (Num.sub b.x a.x) (Num.sub p.y a.y))
      (Num.mul (Num.sub b.y a.y) (Num.sub p.x a.x))
  in
  if Num.sign cross <> 0 then false
  else
    let t = seg_param (a, b) p in
    Num.sign t >= 0 && Num.compare t Num.one <= 0

(* Two convex polygons share positive area? Separating-axis test over the edge
   normals of both: separated (no positive overlap) iff some axis's projections
   are disjoint or merely touching. *)
let convex_overlap (p : point array) (q : point array) : bool =
  let normals poly =
    let n = Array.length poly in
    List.init n (fun i ->
        let a = poly.(i) and b = poly.((i + 1) mod n) in
        (Num.sub a.y b.y, Num.sub b.x a.x))
  in
  let project poly (nx, ny) =
    let v i = Num.add (Num.mul nx poly.(i).x) (Num.mul ny poly.(i).y) in
    let lo = ref (v 0) and hi = ref (v 0) in
    for i = 1 to Array.length poly - 1 do
      let vi = v i in
      if Num.compare vi !lo < 0 then lo := vi;
      if Num.compare vi !hi > 0 then hi := vi
    done;
    (!lo, !hi)
  in
  let separated (nx, ny) =
    let alo, ahi = project p (nx, ny) and blo, bhi = project q (nx, ny) in
    Num.compare ahi blo <= 0 || Num.compare bhi alo <= 0
  in
  not (List.exists separated (normals p @ normals q))
```

- [ ] **Step 4: Run to verify they pass**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS, build clean.

- [ ] **Step 5: Commit**

```bash
git add lib/geom.ml tests/test_beloch.ml
git commit -m "feat(geom): exact convex-polygon overlap and on-segment test

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage** (against the B-2 design §3 evaluation needs, §5 M/V rule, §6 module responsibilities for `Fold_state`/`Geom`):
- `subdivide` (precrease split, U records) → Task 1.
- fold returning crease records with the parity-rule M/V (`valley XOR det<0`) and the accordion alternation → Task 1 (`fold_with_records` + the accordion test).
- material-point resolution / Q2-A ambiguity (one vs many preimages) → Task 1 (`paper_preimages`).
- `convex_overlap` for `faceOrders` → Task 2.
- `on_segment` for the emit edge→record lookup → Task 2.
- **Not in this plan (Plan B-2b):** the `Eval` refactor, the dual `Fold_emit` output (vertex sharing across frames, `faceOrders` sign per `refs/foldformat.md`, M/V lookup via `on_segment`), the `beloch.ml` rewire, the regression re-baseline, and the e2e fold examples. Intentional — built on these landed primitives.

**Placeholder scan:** none — every code step shows full function bodies and complete test cases.

**Type consistency:** `Fold_state.assign` (`M`/`V`/`U`) and `crease_record` (`ra`/`rb`/`assign`) are defined in Task 1 and used by its tests; `simple_fold` keeps its B-1 signature (now a wrapper) so the B-1 `fold_state` tests still compile. `fold_with_records` and `subdivide` both return `t * crease_record list`. `Geom.convex_overlap : point array -> point array -> bool` and `Geom.on_segment : segment -> point -> bool` match their test call sites. `fs_pt` in the `paper_preimages` test is the alias for `pt` already introduced in the B-1 `fold_state` tests.
