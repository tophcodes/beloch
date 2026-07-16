# Fold-state 3D rewrite — Stage A / Plan 3b: selector surface + Collapse on the new core

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the query/selector helper surface the evaluator consumes (`crease_segments`, `coplanar_clusters`, `select_scope`, `classify_mark_extent`, …) from the old `Fold_state` onto `Fold_graph`, and rewrite the single-vertex `Collapse` kernel against the new core — leaving Plan 3c a mechanical consumer port.

**Architecture:** All helpers are pure functions over the abstract `t`, ported with a fixed substitution dictionary (see below). Collapse becomes: pre-checks (unchanged geometry) → set `angle = 1` + intent on the ray hinges → enumerate sector stackings (`linear_extensions`, unchanged) expanded to face ranks → filter candidates through `make` → dedup by observable stacking signature → `over` filter → anchor choice becomes the root/base choice (the anchor sector's faces keep their pre-collapse placement). No sector isometries are composed onto faces — placements stay derived; Kawasaki closure is re-checked structurally by `make`'s cycle-closure over the fan.

**Tech Stack:** OCaml, dune, alcotest; exact `Num`; `lib/fold_graph.ml(i)` (helpers), `lib/collapse.ml` (additive: new `collapse_graph` sharing the old file's pure helpers; old `collapse` untouched until 3c).

## Global Constraints

- Worktree `/home/toph/Projects/beloch-rewrite`, branch `feat/fold-state-invariants`. `git branch --show-current` before every commit.
- Build/test: `direnv exec /home/toph/Projects/beloch-rewrite dune build` / `… dune exec tests/test_fold_graph.exe` (57 green at start) / `… dune exec tests/test_collapse_graph.exe` (new, Task 5).
- PRE-EXISTING failures elsewhere, IGNORE: `test_golden` rabbit-ear/swivel-rabbit "syntax error"; `test_eval` "found example files".
- Old `Fold_state`/`Layer_order`/old `Collapse.collapse` are NOT modified (parity baselines; deleted in 3c). Adding `collapse_graph` + sharing helpers inside `collapse.ml` is allowed; changing old behaviour is not.
- No floats. `make` calls end with `()`. `t` stays abstract.
- Keep `fold_graph.ml` single-file (final-review guidance: a sibling module could only reach internals through copying accessors); add a `(* {1 Selectors} *)` section.

## Substitution dictionary (normative for every port)

| Old (`Fold_state`) | New (`Fold_graph`) |
|---|---|
| `st.faces.(i).paper` | `g.faces.(i)` (internal) / `(faces g).(i)` |
| `st.faces.(i).iso` | `face_iso2 g i` |
| `st.edges` (crease records) | `g.hinges` + `g.segs` (index-aligned) |
| `e.ea`/`e.eb` (paper endpoints) | `hinge_segment g i` = `g.segs.(i)` |
| `e.left`/`e.right` | `h.fa`/`h.fb` (pair order carries no meaning) |
| `e.eassign = F` | `Num.sign h.angle = 0` |
| `e.eassign` (M/V/F letter) | `mv g i` |
| `e.eintent` | `h.intent` |
| `e.crease_id` / `e.eprov` | `h.crease_id` / `h.prov` |
| `Layer_order.get st.order i j` | `rel g i j` |
| `Isometry.det_sign f.iso < 0` | `not (face_up g i)` |
| `table_poly_of f` | `table_polygon g i` |
| edge/`crease_segments` list ORDER | **unspecified** — consumers may not rely on it (documented 3a decision) |

## Carry-ins from Plan 3a's final review (owned by this plan)

- (T3) scoped fold where BOTH sides of an on-axis hinge move: old upgraded `eassign`, new no-ops (correct per D8). Needs a direct test once `select_scope` exists.
- (T3) `hinge_table_segment` fa/fb-side ambiguity: add an asymmetric-placement test.
- (T3) memoize table polygons inside `select_scope` (naive `rel` port would rebuild polygons O(n³)).
- (T6) simplify `fold`'s `List.rev_append (List.rev new_hinges) carried` → `new_hinges @ carried`; deduplicate `subdivide`'s double table-polygon computation.

---

### Task 1: crease/bundle query surface

**Files:**
- Modify: `lib/fold_graph.ml`, `lib/fold_graph.mli`
- Test: `tests/test_fold_graph.ml`

**Interfaces (Produces):**
```ocaml
val neighbors : t -> int -> int list
val hinge_between : t -> int -> Geom.point -> Geom.point -> int option
(** index of the hinge incident to face [i] whose paper segment equals (pa,pb)
    in either order — the old [edge_between], returning an index so callers can
    reach [mv]/[intent]/[prov]. *)
val all_crease_ids : t -> int list
type crease_segment = {
  faces : int * int;
  ta : Geom.point; tb : Geom.point;   (* table space *)
  pa : Geom.point; pb : Geom.point;   (* paper space *)
}
val crease_segments : t -> int -> crease_segment list
val edge_boundary_segments : t -> Geom.line -> crease_segment list
val crease_axis : t -> int -> Geom.line -> [ `Line of Geom.line | `Bent | `Empty ]
val crease_paper_axis : t -> int -> [ `Line of Geom.line | `Bent | `Empty ]
```

- [ ] **Step 1: Write failing tests**

```ocaml
(* --- Plan 3b Task 1: crease queries --------------------------------------- *)

(* build matched old/new states with one precrease + one fold *)
let pair_precrease_fold () =
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let vhalf = { Geom.a = q 1; b = q 0; c = half } in
  let hhalf = { Geom.a = q 0; b = q 1; c = half } in
  let g = Fold_graph.fold
      (Fold_graph.subdivide Fold_graph.init_square hhalf ~prov:None)
      ~axis:vhalf ~move_side:1 ~valley:true ~prov:None in
  let st = Fold_state.fold_with_records
      (Fold_state.subdivide Fold_state.init_square hhalf ~prov:None)
      ~axis:vhalf ~move_side:1 ~valley:true ~prov:None in
  (g, st)

(* order-insensitive comparison of segment lists: multiset over
   (unordered table endpoints, unordered paper endpoints) *)
let check_segments label (news : Fold_graph.crease_segment list)
    (olds : Fold_state.crease_segment list) =
  Alcotest.(check int) (label ^ ": count") (List.length olds) (List.length news);
  let key_eq (nta, ntb, npa, npb) (ota, otb, opa, opb) =
    let seg_eq (a1, b1) (a2, b2) =
      (Geom.point_equal a1 a2 && Geom.point_equal b1 b2)
      || (Geom.point_equal a1 b2 && Geom.point_equal b1 a2)
    in
    seg_eq (nta, ntb) (ota, otb) && seg_eq (npa, npb) (opa, opb)
  in
  let used = Array.make (List.length olds) false in
  List.iteri
    (fun ni (n : Fold_graph.crease_segment) ->
      let hit = ref false in
      List.iteri
        (fun oi (o : Fold_state.crease_segment) ->
          if (not !hit) && (not used.(oi))
             && key_eq (n.Fold_graph.ta, n.Fold_graph.tb, n.Fold_graph.pa, n.Fold_graph.pb)
                  (o.Fold_state.ta, o.Fold_state.tb, o.Fold_state.pa, o.Fold_state.pb)
          then begin used.(oi) <- true; hit := true end)
        olds;
      if not !hit then
        Alcotest.failf "%s: new segment %d has no old match" label ni)
    news

let test_crease_segments_parity () =
  let g, st = pair_precrease_fold () in
  let ids_new = List.sort compare (Fold_graph.all_crease_ids g) in
  let ids_old = List.sort compare (Fold_state.all_crease_ids st) in
  Alcotest.(check (list int)) "crease ids" ids_old ids_new;
  List.iter
    (fun cid ->
      check_segments (Printf.sprintf "cid %d" cid)
        (Fold_graph.crease_segments g cid)
        (Fold_state.crease_segments st cid))
    ids_new

let test_crease_axes_parity () =
  let g, st = pair_precrease_fold () in
  let string_of = function `Line _ -> "line" | `Bent -> "bent" | `Empty -> "empty" in
  List.iter
    (fun cid ->
      (* table axis: same classification; when both are `Line, same point set
         satisfies both (compare via two probe points of the old line) *)
      let n = Fold_graph.crease_axis g cid { Geom.a = q 1; b = q 0; c = q 0 } in
      let o = Fold_state.crease_axis st cid { Geom.a = q 1; b = q 0; c = q 0 } in
      Alcotest.(check string) (Printf.sprintf "axis class cid %d" cid)
        (string_of o) (string_of n);
      let np = Fold_graph.crease_paper_axis g cid in
      let op = Fold_state.crease_paper_axis st cid in
      Alcotest.(check string) (Printf.sprintf "paper axis class cid %d" cid)
        (string_of op) (string_of np))
    (List.sort compare (Fold_graph.all_crease_ids g))

let test_boundary_segments_parity () =
  let g, st = pair_precrease_fold () in
  (* the sheet's bottom edge y = 0 *)
  let bottom = { Geom.a = q 0; b = q 1; c = q 0 } in
  check_segments "boundary y=0"
    (Fold_graph.edge_boundary_segments g bottom)
    (Fold_state.edge_boundary_segments st bottom)

let test_neighbors_hinge_between () =
  let g, _ = pair_precrease_fold () in
  let n = Array.length (Fold_graph.faces g) in
  (* every hinge appears in both endpoints' neighbor lists, and
     hinge_between finds it from its segment *)
  Array.iteri
    (fun i (h : Fold_graph.hinge) ->
      Alcotest.(check bool) (Printf.sprintf "nb fa %d" i) true
        (List.mem h.Fold_graph.fb (Fold_graph.neighbors g h.Fold_graph.fa));
      let a, b = Fold_graph.hinge_segment g i in
      match Fold_graph.hinge_between g h.Fold_graph.fa a b with
      | Some j -> Alcotest.(check int) (Printf.sprintf "hb %d" i) i j
      | None -> Alcotest.failf "hinge_between missed hinge %d" i)
    (Fold_graph.hinges g);
  ignore n
```

Note for the axis test: when the crease's pieces still lie on the ORIGINAL table line, old `crease_axis` returns that line byte-stably; classification parity (line/bent/empty) is the load-bearing check here, since coefficients may differ by a positive scalar between models only when reconstructed — if you want, additionally assert both returned lines contain both old table endpoints (side_of_line = 0), which is representation-independent. Do that.

- [ ] **Step 2: Run to verify failure** — `dune build`; expect unbound values.

- [ ] **Step 3: Implement** (in the new `(* {1 Selectors} *)` section; all are direct ports via the substitution dictionary — reference `lib/fold_state.ml` for the originals)

```ocaml
(* Face ids sharing a hinge with face [i]. *)
let neighbors (g : t) (i : int) : int list =
  Array.fold_left
    (fun acc (h : hinge) ->
      if h.fa = i then h.fb :: acc
      else if h.fb = i then h.fa :: acc
      else acc)
    [] g.hinges

(* The hinge incident to face [i] whose paper segment equals (pa,pb) in either
   order (old [edge_between], as an index). *)
let hinge_between (g : t) (i : int) (pa : Geom.point) (pb : Geom.point) :
    int option =
  let n = Array.length g.hinges in
  let rec go k =
    if k >= n then None
    else
      let h = g.hinges.(k) in
      let a, b = g.segs.(k) in
      if (h.fa = i || h.fb = i)
         && ((Geom.point_equal a pa && Geom.point_equal b pb)
            || (Geom.point_equal a pb && Geom.point_equal b pa))
      then Some k
      else go (k + 1)
  in
  go 0

let all_crease_ids (g : t) : int list =
  let seen = Hashtbl.create 16 in
  Array.iter
    (fun (h : hinge) ->
      if h.crease_id >= 0 then Hashtbl.replace seen h.crease_id ())
    g.hinges;
  Hashtbl.fold (fun k () acc -> k :: acc) seen []

type crease_segment = {
  faces : int * int;
  ta : Geom.point;
  tb : Geom.point;
  pa : Geom.point;
  pb : Geom.point;
}

(* Every material segment of crease [cid]. Degenerate pieces cannot exist in
   the new model ([make] rejects them), so no positive-length filter is
   needed. List order is unspecified. *)
let crease_segments (g : t) (cid : int) : crease_segment list =
  let acc = ref [] in
  Array.iteri
    (fun i (h : hinge) ->
      if h.crease_id = cid then begin
        let pa, pb = g.segs.(i) in
        let ta, tb = hinge_table_segment g i in
        acc := { faces = (h.fa, h.fb); ta; tb; pa; pb } :: !acc
      end)
    g.hinges;
  !acc

(* table-space endpoints of every piece of crease [cid] *)
let crease_table_endpoints (g : t) (cid : int) : Geom.point list =
  List.concat_map (fun s -> [ s.ta; s.tb ]) (crease_segments g cid)

(* Boundary pieces of a paper edge [line]: walk every face's polygon sides on
   [line] not paired with a neighbor across a hinge (port of the old function;
   see its doc comment in fold_state.ml). *)
let edge_boundary_segments (g : t) (line : Geom.line) : crease_segment list =
  let acc = ref [] in
  Array.iteri
    (fun fi f ->
      let m = Array.length f in
      let iso2 = face_iso2 g fi in
      for k = 0 to m - 1 do
        let pa = f.(k) and pb = f.((k + 1) mod m) in
        if
          Geom.side_of_line line pa = 0
          && Geom.side_of_line line pb = 0
          && hinge_between g fi pa pb = None
        then
          let ta = Isometry.apply_point iso2 pa
          and tb = Isometry.apply_point iso2 pb in
          if not (Geom.point_equal ta tb) then
            acc := { faces = (fi, -1); ta; tb; pa; pb } :: !acc
      done)
    g.faces;
  List.rev !acc

let rec pick_two_distinct = function
  | a :: rest -> (
      match List.find_opt (fun b -> not (Geom.point_equal a b)) rest with
      | Some b -> Some (a, b)
      | None -> pick_two_distinct rest)
  | [] -> None

let crease_axis (g : t) (cid : int) (l_orig : Geom.line) :
    [ `Line of Geom.line | `Bent | `Empty ] =
  match crease_table_endpoints g cid with
  | [] -> `Empty
  | pts ->
      if List.for_all (fun p -> Geom.side_of_line l_orig p = 0) pts then
        `Line l_orig
      else (
        match pick_two_distinct pts with
        | None -> `Empty
        | Some (a, b) ->
            let l = Geom.line_through a b in
            if List.for_all (fun p -> Geom.side_of_line l p = 0) pts then
              `Line l
            else `Bent)

let crease_paper_axis (g : t) (cid : int) :
    [ `Line of Geom.line | `Bent | `Empty ] =
  let pts = ref [] in
  Array.iteri
    (fun i (h : hinge) ->
      if h.crease_id = cid then begin
        let a, b = g.segs.(i) in
        pts := a :: b :: !pts
      end)
    g.hinges;
  match pick_two_distinct !pts with
  | None -> `Empty
  | Some (a, b) ->
      let l = Geom.line_through a b in
      if List.for_all (fun p -> Geom.side_of_line l p = 0) !pts then `Line l
      else `Bent
```

Mirror all signatures + the `crease_segment` type in the `.mli` (document list order unspecified).

- [ ] **Step 4: Run tests** — expect PASS.
- [ ] **Step 5: Commit** — `feat(foldgraph): crease/bundle query surface — segments, axes, neighbors`

---

### Task 2: cluster/flap surface

**Files:** `lib/fold_graph.ml`, `lib/fold_graph.mli`, `tests/test_fold_graph.ml`

**Interfaces (Produces):**
```ocaml
val coplanar_clusters : t -> int array
val cluster_of_points : t -> Geom.point list -> [ `Cluster of int list | `Zero | `Ambiguous ]
val flap_of_points : t -> Geom.point list -> [ `Cluster of int list | `Zero | `Ambiguous ]
```

- [ ] **Step 1: Write failing tests**

```ocaml
(* --- Plan 3b Task 2: clusters/flaps ---------------------------------------- *)

let test_clusters_parity () =
  let g, st = pair_precrease_fold () in
  let cn = Fold_graph.coplanar_clusters g in
  let co = Fold_state.coplanar_clusters st in
  (* cluster ids are representatives — compare the PARTITION, not the ids *)
  let n = Array.length cn in
  Alcotest.(check int) "length" (Array.length co) n;
  for i = 0 to n - 1 do
    for j = 0 to n - 1 do
      Alcotest.(check bool) (Printf.sprintf "same-cluster %d %d" i j)
        (co.(i) = co.(j)) (cn.(i) = cn.(j))
    done
  done

let test_flap_of_points_parity () =
  let g, st = pair_precrease_fold () in
  let string_of = function
    | `Cluster fs -> "cluster:" ^ String.concat "," (List.map string_of_int (List.sort compare fs))
    | `Zero -> "zero"
    | `Ambiguous -> "ambiguous"
  in
  let probe pts label =
    Alcotest.(check string) label
      (string_of (Fold_state.flap_of_points st pts))
      (string_of (Fold_graph.flap_of_points g pts))
  in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let three_q = Num.div (Num.of_int 3) (Num.of_int 4) in
  probe [ { Geom.x = quarter; y = quarter } ] "interior stationary";
  probe [ { Geom.x = three_q; y = quarter } ] "interior moved flap";
  probe [ { Geom.x = quarter; y = quarter }; { Geom.x = three_q; y = quarter } ]
    "spanning two flaps";
  probe [ { Geom.x = q 5; y = q 5 } ] "off paper"
```

- [ ] **Step 2: verify failure.**

- [ ] **Step 3: Implement** — direct ports (substitution dictionary; originals `fold_state.ml:353-403`):

```ocaml
(* Component id per face: F-adjacency (hinges with angle 0) union-find.
   Same-flap iff separated only by flat hinges (ADR 0017). *)
let coplanar_clusters (g : t) : int array =
  let n = Array.length g.faces in
  let parent = Array.init n Fun.id in
  let rec find i =
    if parent.(i) = i then i
    else begin
      let r = find parent.(i) in
      parent.(i) <- r;
      r
    end
  in
  let union a b =
    let ra = find a and rb = find b in
    if ra <> rb then parent.(ra) <- rb
  in
  Array.iter
    (fun (h : hinge) -> if Num.sign h.angle = 0 then union h.fa h.fb)
    g.hinges;
  Array.init n (fun i -> find i)

let cluster_of_points (g : t) (pts : Geom.point list) :
    [ `Cluster of int list | `Zero | `Ambiguous ] =
  let cl = coplanar_clusters g in
  let n = Array.length g.faces in
  let ids_of_point p =
    let s = ref [] in
    for i = 0 to n - 1 do
      if Geom.in_convex_polygon g.faces.(i) p && not (List.mem cl.(i) !s) then
        s := cl.(i) :: !s
    done;
    !s
  in
  match pts with
  | [] -> `Zero
  | p0 :: rest ->
      let common =
        List.fold_left
          (fun acc p -> List.filter (fun id -> List.mem id (ids_of_point p)) acc)
          (ids_of_point p0) rest
      in
      (match common with
       | [ id ] ->
           `Cluster (List.filter (fun i -> cl.(i) = id) (List.init n Fun.id))
       | [] -> `Zero
       | _ -> `Ambiguous)

let flap_of_points = cluster_of_points
```

Mirror in `.mli`.

- [ ] **Step 4: tests PASS.**
- [ ] **Step 5: Commit** — `feat(foldgraph): coplanar clusters + flap resolution`

---

### Task 3: line material + scoped-fold surface (and the 3a carry-in tests)

**Files:** `lib/fold_graph.ml`, `lib/fold_graph.mli`, `tests/test_fold_graph.ml`

**Interfaces (Produces):**
```ocaml
val line_material_segments : t -> Geom.line -> (Geom.point * Geom.point) list
val line_cuts_paper : t -> Geom.line -> bool
type scope_target = TargetFace of int | TargetHinged of (int -> bool)
val select_scope :
  t -> axis:Geom.line -> move_side:int -> valley:bool -> anchor:int ->
  target:scope_target -> (bool array, string) result
val scoped_fold_hinge_closed :
  t -> axis:Geom.line -> move_side:int -> moving_parents:bool array ->
  (unit, Geom.point * Geom.point) result
```

- [ ] **Step 1: Write failing tests**

```ocaml
(* --- Plan 3b Task 3: line material + scope ---------------------------------- *)

let test_line_material_parity () =
  let g, st = pair_precrease_fold () in
  let l = { Geom.a = q 0; b = q 1; c = Num.div Num.one (Num.of_int 4) } in
  let news = Fold_graph.line_material_segments g l in
  let olds = Fold_state.line_material_segments st l in
  Alcotest.(check int) "count" (List.length olds) (List.length news);
  Alcotest.(check bool) "cuts" (Fold_state.line_cuts_paper st l)
    (Fold_graph.line_cuts_paper g l)

(* select_scope parity on a 3-layer state (pleat then check scoping) *)
let test_select_scope_parity () =
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let frac a b = Num.div (Num.of_int a) (Num.of_int b) in
  let vl c = { Geom.a = Num.one; b = Num.zero; c } in
  (* book fold then fold the packet edge back: 3 overlapping layers on part
     of the sheet *)
  let g = Fold_graph.fold
      (vfold_new Fold_graph.init_square (vl (frac 1 2)))
      ~axis:(vl (frac 1 4)) ~move_side:(-1) ~valley:true ~prov:None in
  let st = Fold_state.fold_with_records
      (vfold_old Fold_state.init_square (vl (frac 1 2)))
      ~axis:(vl (frac 1 4)) ~move_side:(-1) ~valley:true ~prov:None in
  check_parity "scope pre" g st;
  (* the top face over x in (1/4,1/2) *)
  let top =
    let n = Array.length (Fold_graph.faces g) in
    let best = ref (-1) in
    for i = 0 to n - 1 do
      if Array.exists
           (fun (p : Geom.point) ->
             Num.compare p.Geom.x (frac 1 4) > 0
             && Num.compare p.Geom.x (frac 1 2) < 0)
           (Fold_graph.table_polygon g i)
      then if !best < 0 || Fold_graph.rel g i !best = Fold_graph.Above then best := i
    done;
    !best
  in
  let axis = vl (frac 3 8) in
  let n = Fold_state.select_scope st ~axis ~move_side:(-1) ~valley:true
      ~anchor:top ~target:(Fold_state.TargetFace top)
  and m = Fold_graph.select_scope g ~axis ~move_side:(-1) ~valley:true
      ~anchor:top ~target:(Fold_graph.TargetFace top) in
  match (n, m) with
  | Ok a, Ok b ->
      Alcotest.(check (array bool)) "moving sets equal" a b
  | Error e1, Error e2 -> Alcotest.(check string) "same error" e1 e2
  | Ok _, Error e -> Alcotest.failf "new errored: %s" e
  | Error e, Ok _ -> Alcotest.failf "old errored: %s" e

let test_scoped_hinge_closed_parity () =
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let frac a b = Num.div (Num.of_int a) (Num.of_int b) in
  let vl c = { Geom.a = Num.one; b = Num.zero; c } in
  let g = vfold_new Fold_graph.init_square (vl (frac 1 2)) in
  let st = vfold_old Fold_state.init_square (vl (frac 1 2)) in
  let top = if Fold_graph.rel g 0 1 = Fold_graph.Above then 0 else 1 in
  let moving = Array.make 2 false in
  moving.(top) <- true;
  (* legal: axis through the mover's free region *)
  let ok_new = Fold_graph.scoped_fold_hinge_closed g ~axis:(vl (frac 1 4))
      ~move_side:(-1) ~moving_parents:moving in
  let ok_old = Fold_state.scoped_fold_hinge_closed st ~axis:(vl (frac 1 4))
      ~move_side:(-1) ~moving_parents:moving in
  Alcotest.(check bool) "legal both" (Result.is_ok ok_old) (Result.is_ok ok_new);
  (* tear: moving the +1 side lifts the mover off its book hinge *)
  let bad_new = Fold_graph.scoped_fold_hinge_closed g ~axis:(vl (frac 1 4))
      ~move_side:1 ~moving_parents:moving in
  let bad_old = Fold_state.scoped_fold_hinge_closed st ~axis:(vl (frac 1 4))
      ~move_side:1 ~moving_parents:moving in
  Alcotest.(check bool) "tear both" (Result.is_error bad_old) (Result.is_error bad_new)

(* 3a carry-in: on-axis hinge with BOTH sides moving must NOT toggle (D8);
   old model upgraded eassign here — accepted divergence, so assert the NEW
   behaviour directly, no parity *)
let test_both_sides_moving_no_toggle () =
  Fold_graph.reset_ids ();
  let frac a b = Num.div (Num.of_int a) (Num.of_int b) in
  let vl c = { Geom.a = Num.one; b = Num.zero; c } in
  let hl c = { Geom.a = Num.zero; b = Num.one; c } in
  (* book fold about x=1/2 (folded hinge ON x=1/2), then fold BOTH layers
     along y=1/2: the book hinge's segment lies on... it does NOT lie on the
     new axis, so instead construct: subdivide y=1/2 (flat hinge along y=1/2),
     then a scoped fold along y=1/2 moving BOTH faces above? They ARE the
     movers and the hinge is between two movers only if a third face exists.
     Simplest concrete construction: subdivide x=1/2 AND y=1/2 -> 4 faces;
     scoped fold along y=1/2 moving ONLY the two top faces: the top faces'
     mutual hinge (on x=1/2, crossing the moving region) is between two
     movers and OFF-axis (carried, fine); the two on-axis hinges (top|bottom
     pairs) have exactly one moving side -> toggle. To hit BOTH-sides-moving
     ON-AXIS, fold along x=1/2 moving the two top faces: their mutual hinge
     lies ON x=1/2 with both sides moving -> must stay angle 0. *)
  let g0 = Fold_graph.subdivide
      (Fold_graph.subdivide Fold_graph.init_square (vl (frac 1 2)) ~prov:None)
      (hl (frac 1 2)) ~prov:None in
  (* faces: identify the two with y > 1/2 *)
  let movers = Array.make (Array.length (Fold_graph.faces g0)) false in
  Array.iteri
    (fun i f ->
      if Array.for_all
           (fun (p : Geom.point) -> Num.compare p.Geom.y (frac 1 2) >= 0) f
      then movers.(i) <- true)
    (Fold_graph.faces g0) |> ignore;
  let g = Fold_graph.fold g0 ~axis:(vl (frac 1 2)) ~move_side:1 ~valley:true
      ~moving_parents:movers ~prov:None in
  (* the top pair's mutual hinge (paper seg on x=1/2, y in [1/2,1]) must be
     angle 0 still; the y=1/2 hinges of the moved side... find by segment *)
  let hs = Fold_graph.hinges g in
  let on_x_half_top i =
    let a, b = Fold_graph.hinge_segment g i in
    Num.equal a.Geom.x (frac 1 2) && Num.equal b.Geom.x (frac 1 2)
    && Num.compare (Num.add a.Geom.y b.Geom.y) Num.one > 0
  in
  Array.iteri
    (fun i (_ : Fold_graph.hinge) ->
      if on_x_half_top i then
        Alcotest.(check bool) (Printf.sprintf "no toggle %d" i) true
          (Num.sign hs.(i).Fold_graph.angle = 0))
    hs

(* 3a carry-in: hinge_table_segment must use the fa-side placement — build a
   state where fa and fb sides map the shared paper segment DIFFERENTLY…
   impossible for a real hinge (they agree on the crease). Instead pin the
   fa-usage observationally: on a folded hinge the table segment must equal
   the OLD edge's table segment (computed via left face) — already covered by
   check_segments in Task 1 (ta/tb compared). Add only a comment, no test. *)
```

CORRECTION to the both-sides test sketch: `Array.iteri … |> ignore` is wrong (`Array.iteri` returns unit); write the loop as a plain statement. The scoped fold moving the two top faces along `x=1/2` with `move_side:1` moves their `x>1/2` halves — both top faces get CUT (each has material on both sides of x=1/2? No: each top face is a quarter, one wholly x≤1/2, one wholly x≥1/2). So the mover set = both top quarters; the axis x=1/2 passes along their mutual hinge; the x≥1/2 top quarter lies wholly on the move side (uncut, reflects), the x≤1/2 top quarter lies wholly on the stay side of the axis — but it is marked moving with NO material on the move side, so it contributes nothing to `mov` and stays whole in `stay`. Then the mutual hinge has exactly ONE moved side after all and WILL toggle 0→1 — the sketch's scenario does not reach both-sides-moving. Building a genuine both-sides-moving on-axis hinge requires both incident faces to have material strictly on the move side while sharing a hinge ON the axis — impossible for faces on opposite sides of the axis; possible only when the hinge is FOLDED (angle 1) and both layers lie on the move side. Concrete: book fold about x=1/2 (packet on x≤1/2, folded hinge ON x=1/2), then scoped fold moving BOTH layers along the same axis x=1/2 — but both layers lie on side −1, so `move_side:-1` moves both; the on-axis folded hinge has both sides moving → must NOT toggle (stays angle 1; the packet reflects rigidly to x≥1/2). Assert: after the fold, the hinge still has `Num.sign angle <> 0` and the two faces' table polys lie in x≥1/2. That construction is:

```ocaml
let test_both_sides_moving_no_toggle () =
  Fold_graph.reset_ids ();
  let frac a b = Num.div (Num.of_int a) (Num.of_int b) in
  let vl c = { Geom.a = Num.one; b = Num.zero; c } in
  let g1 = vfold_new Fold_graph.init_square (vl (frac 1 2)) in
  let movers = Array.make (Array.length (Fold_graph.faces g1)) true in
  let g = Fold_graph.fold g1 ~axis:(vl (frac 1 2)) ~move_side:(-1)
      ~valley:true ~moving_parents:movers ~prov:None in
  let hs = Fold_graph.hinges g in
  Alcotest.(check int) "one hinge" 1 (Array.length hs);
  Alcotest.(check bool) "still folded (no toggle)" true
    (Num.sign hs.(0).Fold_graph.angle <> 0);
  Array.iteri
    (fun i _ ->
      Alcotest.(check bool) (Printf.sprintf "face %d at x>=1/2" i) true
        (Array.for_all
           (fun (p : Geom.point) -> Num.compare p.Geom.x (frac 1 2) >= 0)
           (Fold_graph.table_polygon g i)))
    (Fold_graph.faces g)
```

Use THIS version, not the 4-face sketch.

- [ ] **Step 2: verify failure.**

- [ ] **Step 3: Implement.** Ports with the substitution dictionary; `select_scope` gets the memoized-polygon treatment (carry-in):

```ocaml
let line_material_segments (g : t) (l : Geom.line) :
    (Geom.point * Geom.point) list =
  List.filter_map
    (fun i -> Geom.clip_line_to_convex l (table_polygon_ccw g i))
    (List.init (Array.length g.faces) Fun.id)

let line_cuts_paper (g : t) (l : Geom.line) : bool =
  List.exists
    (fun i -> Geom.line_cuts_polygon l (table_polygon_ccw g i))
    (List.init (Array.length g.faces) Fun.id)

type scope_target = TargetFace of int | TargetHinged of (int -> bool)

(* Port of the old select_scope (see fold_state.ml:429-538 for the algorithm
   commentary) with memoized table polygons: [tp] is built once; [rel_m]
   replaces Layer_order.get. Error strings verbatim from the old module. *)
let select_scope (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ~(anchor : int) ~(target : scope_target) :
    (bool array, string) result =
  let n = Array.length g.faces in
  let cl = coplanar_clusters g in
  let tp = Array.init n (table_polygon g) in
  let rel_m i j =
    if i = j then Apart
    else if Geom.convex_overlap tp.(i) tp.(j) then
      if g.rank.(i) > g.rank.(j) then Above else Below
    else Apart
  in
  let piece =
    Array.init n (fun i ->
        let sub = Geom.clip_convex_halfplane axis move_side tp.(i) in
        if Array.length sub >= 3 then Some sub else None)
  in
  let cand i = piece.(i) <> None in
  let overlap i j =
    match (piece.(i), piece.(j)) with
    | Some a, Some b -> Geom.convex_overlap a b
    | _ -> false
  in
  let outer i j =
    overlap i j && rel_m i j = (if valley then Above else Below)
  in
  if not (cand anchor) then
    Error "the moving flap has no material on the moving side of the fold axis"
  else
    let find_targets () : (int list, string) result =
      match target with
      | TargetFace t ->
          if not (cand t) then
            Error "`up to`: the target flap is not on the moving side of the fold"
          else Ok [ t ]
      | TargetHinged pred ->
          if pred anchor then Ok [ anchor ]
          else begin
            let visited = Array.make n false in
            visited.(anchor) <- true;
            let result = ref None in
            while !result = None do
              let frontier = ref [] in
              for gi = 0 to n - 1 do
                if (not visited.(gi)) && cand gi then begin
                  let inward = ref false in
                  for v = 0 to n - 1 do
                    if visited.(v) && outer v gi then inward := true
                  done;
                  if !inward then frontier := gi :: !frontier
                end
              done;
              match List.filter pred !frontier with
              | [] ->
                  if !frontier = [] then
                    result :=
                      Some
                        (Error
                           "`up to`: no flap hinged on that crease is \
                            reachable from the anchor over the crease region")
                  else List.iter (fun gi -> visited.(gi) <- true) !frontier
              | hits -> result := Some (Ok hits)
            done;
            Option.get !result
          end
    in
    match find_targets () with
    | Error e -> Error e
    | Ok targets ->
        let inm = Array.make n false in
        List.iter (fun t -> inm.(t) <- true) targets;
        let changed = ref true in
        while !changed do
          changed := false;
          for gi = 0 to n - 1 do
            if (not inm.(gi)) && cand gi then
              for m = 0 to n - 1 do
                if inm.(m) && (not inm.(gi)) && (outer gi m || cl.(gi) = cl.(m))
                then begin
                  inm.(gi) <- true;
                  changed := true
                end
              done
          done
        done;
        if not inm.(anchor) then
          Error
            "`up to`: the target is not reachable from the anchor over the \
             crease region"
        else begin
          let buried = ref None in
          for m = 0 to n - 1 do
            if !buried = None && inm.(m) && m <> anchor && outer m anchor then
              buried := Some m
          done;
          match !buried with
          | Some m ->
              Error
                (Printf.sprintf
                   "a simple fold cannot move a buried flap: face %d covers \
                    the anchor in the crease region — include the covering \
                    flap (anchor the fold there) or fold less" m)
          | None -> Ok inm
        end

(* A scoped moving set is hinge-closed iff every crease segment separating a
   moving face from a stationary face lies on the fold axis with no endpoint
   strictly on the move side (see the old module's doc comment). *)
let scoped_fold_hinge_closed (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(moving_parents : bool array) : (unit, Geom.point * Geom.point) result =
  let n = Array.length moving_parents in
  let rec check = function
    | [] -> Ok ()
    | cid :: rest ->
        let rec check_segs = function
          | [] -> check rest
          | (s : crease_segment) :: more ->
              let l, r = s.faces in
              if
                l < n && r >= 0 && r < n
                && moving_parents.(l) <> moving_parents.(r)
                && (Geom.side_of_line axis s.ta = move_side
                   || Geom.side_of_line axis s.tb = move_side)
              then Error (s.ta, s.tb)
              else check_segs more
        in
        check_segs (crease_segments g cid)
  in
  check (all_crease_ids g)
```

Also do the two mechanical 3a carry-ins in this task (they touch `fold`/`subdivide` internals):
- `lib/fold_graph.ml` in `fold`: replace `Array.of_list (List.rev_append (List.rev new_hinges) carried)` with `Array.of_list (new_hinges @ carried)`.
- `lib/fold_graph.ml` in `subdivide`'s `cut_of`: compute `table` once and reuse it for the chord instead of calling `axis_chord_in_face` (which rebuilds it) — inline the chord computation on the already-built `table`/`inv`, or change nothing if the refactor risks behaviour; if you inline, the existing 57 tests are the guard. Prefer the minimal version: keep `axis_chord_in_face` but pass it nothing extra — SKIP this item if it cannot be done without changing observable behaviour, and note it.

Mirror new signatures + `scope_target` in `.mli`.

- [ ] **Step 4: tests PASS (incl. 57 existing).**
- [ ] **Step 5: Commit** — `feat(foldgraph): line material + select_scope + hinge closure (memoized)`

---

### Task 4: mark surface

**Files:** `lib/fold_graph.ml`, `lib/fold_graph.mli`, `tests/test_fold_graph.ml`

**Interfaces (Produces):**
```ocaml
val mark_rep_point : mark -> Geom.point
val mark_chords : t -> int -> (Geom.point * Geom.point) list
val mark_axis_current : t -> int -> [ `Line of Geom.line | `Bent | `Empty ]
val mark_face : t -> mark -> int option
val point_on_polygon_boundary : Geom.point array -> Geom.point -> bool
type mark_class =
  | CSubdivide of Geom.point * Geom.point
  | CRecord of mark_geom
  | CCrossesFold of Geom.point * Geom.point
val classify_mark_extent :
  t -> flap:int list -> axis:Geom.line -> extent_geom:mark_geom -> mark_class
val axis_chord_in_face : t -> int -> Geom.line -> (Geom.point * Geom.point) option
(** expose the existing internal helper — eval's mark machinery uses it *)
```

- [ ] **Step 1: Write failing tests** — parity on the classification outcomes:

```ocaml
(* --- Plan 3b Task 4: marks -------------------------------------------------- *)

let mclass_str = function
  | `Sub -> "subdivide" | `Rec -> "record" | `Cross -> "crossesfold"

let test_classify_parity () =
  let g, st = pair_precrease_fold () in
  (* flap = the moved packet cluster: probe from a point on it *)
  let three_q = Num.div (Num.of_int 3) (Num.of_int 4) in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let flap_new =
    match Fold_graph.flap_of_points g [ { Geom.x = three_q; y = quarter } ] with
    | `Cluster fs -> fs | _ -> Alcotest.fail "flap (new)"
  in
  let flap_old =
    match Fold_state.flap_of_points st [ { Geom.x = three_q; y = quarter } ] with
    | `Cluster fs -> fs | _ -> Alcotest.fail "flap (old)"
  in
  let case label axis geom_new geom_old =
    let simplify_new = function
      | Fold_graph.CSubdivide _ -> `Sub
      | Fold_graph.CRecord _ -> `Rec
      | Fold_graph.CCrossesFold _ -> `Cross
    in
    let simplify_old = function
      | Fold_state.CSubdivide _ -> `Sub
      | Fold_state.CRecord _ -> `Rec
      | Fold_state.CCrossesFold _ -> `Cross
    in
    Alcotest.(check string) label
      (mclass_str (simplify_old
        (Fold_state.classify_mark_extent st ~flap:flap_old ~axis
           ~extent_geom:geom_old)))
      (mclass_str (simplify_new
        (Fold_graph.classify_mark_extent g ~flap:flap_new ~axis
           ~extent_geom:geom_new)))
  in
  (* full chord across the moved packet: subdivide *)
  let a = { Geom.x = Num.div Num.one (Num.of_int 2); y = quarter }
  and b = { Geom.x = Num.one; y = quarter } in
  case "full chord" { Geom.a = q 0; b = q 1; c = quarter }
    (Fold_graph.MSeg (a, b)) (Fold_state.MSeg (a, b));
  (* stub ending mid-face: record *)
  let mid = { Geom.x = three_q; y = quarter } in
  case "stub" { Geom.a = q 0; b = q 1; c = quarter }
    (Fold_graph.MSeg (a, mid)) (Fold_state.MSeg (a, mid));
  (* point: record *)
  case "point" { Geom.a = q 0; b = q 1; c = quarter }
    (Fold_graph.MPoint mid) (Fold_state.MPoint mid)

let test_mark_axis_current_parity () =
  let g, st = pair_precrease_fold () in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let mnew = { Fold_graph.mgeom = Fold_graph.MSeg
                  ({ Geom.x = q 0; y = quarter }, { Geom.x = q 1; y = quarter });
               mline = { Geom.a = q 0; b = q 1; c = quarter };
               mintent = Fold_graph.V; mcrease_id = 77; mprov = None } in
  let mold = { Fold_state.mgeom = Fold_state.MSeg
                  ({ Geom.x = q 0; y = quarter }, { Geom.x = q 1; y = quarter });
               mline = { Geom.a = q 0; b = q 1; c = quarter };
               mintent = Fold_state.V; mcrease_id = 77; mprov = None } in
  let g = Fold_graph.add_mark g mnew in
  let st = Fold_state.add_mark st mold in
  let str = function `Line _ -> "line" | `Bent -> "bent" | `Empty -> "empty" in
  Alcotest.(check string) "mark axis class"
    (str (Fold_state.mark_axis_current st 77))
    (str (Fold_graph.mark_axis_current g 77))
```

NOTE: the mark in `test_mark_axis_current_parity` spans the WHOLE sheet across a fold — the horizontal chord is bent by the vertical book fold ONLY if its paper midpoint maps off the straight table chord; with the book fold, paper (0,¼)→table (0,¼)? No: paper x∈[½,1] is the moved half, so table(1,¼) = (0,¼) = table(0,¼) — the chord's table endpoints COINCIDE → old returns `Empty`. That is itself a fine parity case (expect "empty" = "empty"); keep it and add a second, genuinely bent case if cheap: mark from (0,¼) to (¾,¼) — table endpoints (0,¼) and (¼,¼), midpoint paper (3/8,¼) maps to (3/8,¼) which is ON the chord... also not bent. Getting a `Bent` needs a diagonal fold; don't force it — classification parity over these two cases (`empty`, `line`) is enough here; `Bent` handling is pinned by eval-level tests in 3c.

- [ ] **Step 2: verify failure.**

- [ ] **Step 3: Implement** — ports (originals `fold_state.ml:591-823`): `mark_rep_point`, `mark_chords` (over `g.marks`), `mark_axis_current` (uses `table_position`), `mark_face`, `point_on_polygon_boundary`, `polygon_edge_at` (internal), `is_flap_boundary_at` (internal; `edge_between … eassign <> F` becomes `hinge_between … |> function Some hi -> Num.sign g.hinges.(hi).angle <> 0 | None -> true`), `strictly_interior_to_flap_face` (internal), `endpoint_is_flap_boundary` (internal), `flap_face_overlap` (internal; `Geom.clip_line_to_convex axis g.faces.(fi)` + `Geom.seg_param`), `classify_seg` (internal), `classify_mark_extent`, and expose `axis_chord_in_face` in the `.mli`. Every function is the old body with the substitution dictionary applied; where the old reads `st.faces.(fi).paper` inside flap logic, the new reads `g.faces.(fi)`.

- [ ] **Step 4: tests PASS.**
- [ ] **Step 5: Commit** — `feat(foldgraph): mark surface — chords, current axis, extent classification`

---

### Task 5: Collapse on the new core

**Files:**
- Modify: `lib/collapse.ml` (ADDITIVE: new `collapse_graph`; refactor shared pure helpers to be state-agnostic ONLY where they already are — `common_vertex`, `far_of`, `sort_ccw`, `has_duplicate_ray`, `closure_ok`, `linear_extensions`, `on_unit_boundary`, `strictly_interior`, `cross`, error strings: all already take no `Fold_state.t`; reuse as-is)
- Test: NEW `tests/test_collapse_graph.ml` + stanza in `tests/dune`

**Interfaces (Produces):**
```ocaml
(* in collapse.ml *)
val collapse_graph :
  Fold_graph.t -> elem list -> over:(int * int) list ->
  (Fold_graph.t, string) result
(* elem is the existing type {cid; ea; eb; valley} — ea/eb TABLE-space *)
```

**Algorithm (normative).** The old kernel composes per-face sector isometries; the new one only sets angles and rank — placements derive. Mapping:

1. **Pre-checks, verbatim:** common vertex + strictly interior; `n >= 4` even; every far tip on the unit boundary; `sort_ccw`; `has_duplicate_ray`; `closure_ok` (Kawasaki); Maekawa (|nm − nv| = 2). Same error strings, same order (`e_no_vertex`, `e_count`, `e_midpaper`, `e_dup_ray`, `e_kawasaki`, `e_maekawa`).
2. **Sector machinery, kept but placement-free:** `sector_isometries o rays` (2D, table frame) is still computed — NOT to place faces, but for (a) `effective_valley` parity letters and (b) sector membership + the anchor's in-bounds check, exactly as old. `sector_of` is reworked to take the polygon + its 2D placement: `sector_of o rays (poly, iso2)` with `iso2 = Fold_graph.face_iso2 g i` (body identical to old, reading `poly`/`iso2` instead of `f.paper`/`f.iso`).
3. **sector_iso per sector:** first face found in each sector contributes `face_iso2 g i` (old used `f.iso`).
4. **Hinge constraints** (per ray j, left sector l = (j−1+n) mod n): `eff = effective_valley e.valley tsec.(l) sector_iso.(l)`; `eff ⇒ (j Above l)` — verbatim.
5. **Candidate face ranks:** for each sector stacking `srank` from `linear_extensions n constraints`, build a TOTAL face rank: sort face indices by `(srank.(sec.(i)), intra i)` where `intra i = g.rank.(i)` if `Isometry.det_sign tsec.(sec.(i)) > 0` else `- g.rank.(i)` (old rel_of: same-sector base order, negated in reflected sectors), tiebreak by index (cannot fire: `g.rank` is a permutation). Densify to heights.
6. **New hinges:** copy `g.hinges`, and for every hinge whose crease matches a ray (same test as old `edges_final`: `elem.cid = h.crease_id` && both its TABLE endpoints — `hinge_table_segment` — lie `Geom.on_segment (o, far)`), set `angle = Num.one` and `intent = ray letter` (`ray_assign.(j)` from `eff_of_ray`, mapped to `Fold_graph.V`/`M`). Hinges NOT on a ray keep angle/intent.
   **Precondition (old model implicit):** the state was subdivided along every ray before collapse (eval does this); if a ray hinge is missing the closure check in `make` will reject — surface that as `e_kawasaki`? NO — pre-check 1 already guarantees rays exist as elems built FROM crease segments; missing hinges are impossible from the eval path. Do not add handling.
7. **Candidate filtering:** for each candidate rank, `Fold_graph.make ~base:g.base ~marks:(Fold_graph.marks g) ~faces:(Fold_graph.faces g) ~hinges:new_hinges ~root:(Fold_graph.root g) ~rank ()` — WAIT: root/base here are the PRE-collapse root; its placement changes if the root face's sector is not the eventual anchor. For filtering validity, any root/base works (validity is placement-relative-invariant? NO — taco checks run on flat projections, which shift rigidly with base: overlap/crossing relations are rigid-motion invariant, so validity IS base-independent). Use root = `Fold_graph.root g`, base = the root face's POST-collapse placement in the temporary anchor-free frame: `Isometry3` of… simpler: root = any face of sector 0 with base = compose (embed3 tsec.(0)) (isos of that face)? To avoid 3D-embedding arithmetic here, use this construction: pick `rep0` = any face index with `sec.(rep0) = s0` where `s0` is ANY orientation-PRESERVING sector under `tsec` composed with its face parity… **Simplification (binding):** since validity is rigid-motion invariant, build candidates with `root = rep` and `base = Fold_graph.face_iso g rep` where `rep` = the first face whose sector `sec.(rep)` has `Isometry.det_sign tsec.(sec.(rep)) > 0` — i.e. a proper sector: its faces keep orientation, and the fan closure (Kawasaki, verified in pre-check 1) guarantees `make`'s cycle closure holds with the ray hinges at angle 1 regardless of which rep anchors. `Ok` candidates survive; `Error _` candidates are dropped. If none survive → `Error e_selfint`.
8. **Dedup by signature** (old behaviour): overlaps are the same for all candidates (placements do not depend on rank) — compute the folded table polygons ONCE from any surviving candidate's `make` result; `signature rank = [(i, j, rank.(i) > rank.(j)) | (i,j) overlapping]`; keep the first candidate per distinct signature. >1 distinct → `Error (e_ambig k)`; 0 → `e_selfint` (unreachable).
9. **`over` filter** (before dedup, as old): `rank.(sec-expanded)`… old filters on SECTOR ranks: `over_ok srank = ∀(up,lo): sec.(up) = sec.(lo) || srank.(sec.(up)) > srank.(sec.(lo))`. Keep at the sector level, applied to the sector stackings BEFORE face-rank expansion (matches old order: valid → over → dedup). Empty after filter → `Error e_contra`.
10. **Anchor / fold sense:** proper sectors sorted by ascending `srank` (of the winning stacking); `default_b` = first. For a candidate anchor `bb`: root = first face with `sec.(i) = bb`, base = `Fold_graph.face_iso g root` (its pre-collapse placement — anchoring means that sector does not move). Build the final graph via `make` with the winning face rank; in-bounds check = every derived `table_polygon` vertex `Geom.in_unit_square`. Prefer `default_b` if in-bounds, else first in-bounds proper sector (old preference order), else `Error e_out_of_paper`.
11. Marks pass through (`make ~marks`).

**Why the derived placements equal the old `tbi ∘ tsec ∘ iso`:** anchoring at rep face r (sector b) seeds BFS with r's pre-collapse placement; a path from r to face f crosses ray hinges exactly as the sector fan dictates, and each angle-1 ray hinge contributes the half-turn about its PAPER line conjugated into place — which is precisely the old reflection product `tsec` relation `T_k = T_{k-1} ∘ R(L_k)` re-rooted at sector b (`tbi ∘ tsec.(k)`), plus f's own pre-collapse placement. Plan 2c's waterbomb tests validated this correspondence for the fan; the parity tests below re-validate it end-to-end.

- [ ] **Step 1: Write failing tests** — NEW file `tests/test_collapse_graph.ml`, dune stanza `(test (name test_collapse_graph) (libraries beloch alcotest zarith))`. Mirror the old `tests/test_collapse.ml`'s rabbit-ear setup (read it first; reuse its geometry constants) as old-vs-new parity:

```ocaml
open Beloch

(* Build the rabbit-ear pre-state in BOTH models: subdivide along the three
   bisector rays + the ear ray (same lines the old test uses), then collapse
   with the same elems/over and compare. Transcribe the exact pre-state
   construction from tests/test_collapse.ml — the lines, cids, and elems must
   be IDENTICAL between old and new (reset both id counters first, mint cids
   via each model's fresh_crease_id in the same order). *)

(* check_parity / check_assign_parity: copy the two harness functions from
   tests/test_fold_graph.ml verbatim (they are test-local; a shared test
   library is not worth the dune plumbing at this stage — note the
   duplication for 3c cleanup). *)

let test_rabbit_ear_collapse_parity () = (* … per the pattern above … *)
  ...

let test_collapse_errors_parity () =
  (* n=2 -> e_count; off-vertex -> e_no_vertex; wrong M/V mix -> e_maekawa:
     drive BOTH kernels with the same bad elem lists on the same pre-state
     and assert identical error strings *)
  ...

let test_collapse_over_parity () =
  (* the ambiguous-stacking case from test_collapse.ml: without `over` both
     return e_ambig k with the SAME k; with `over` both return Ok and parity
     holds *)
  ...
```

The implementer transcribes the concrete geometry from `tests/test_collapse.ml` (do not invent new geometry — the old test file's setups are the certified fixtures). Every `Ok` outcome runs `check_parity` + `check_assign_parity`; every `Error` outcome compares strings exactly.

- [ ] **Step 2: verify failure** (`collapse_graph` unbound).
- [ ] **Step 3: Implement `collapse_graph`** per the normative algorithm above (in `collapse.ml`, after the old kernel; shares its helpers).
- [ ] **Step 4: tests PASS.** Any parity mismatch: STOP — report the failing observable (this is where a genuine old/new model divergence would surface; the controller must adjudicate).
- [ ] **Step 5: Commit** — `feat(collapse): collapse_graph — single-vertex collapse on the hinge-graph core`

---

### Task 6: battery extension + ledger

**Files:** `tests/test_fold_graph.ml`, `.superpowers/sdd/progress.md` (untracked)

- [ ] **Step 1:** Extend the Task-6 (3a) battery ops with `OMark of Fold_graph.mark * Fold_state.mark` (add_mark both sides) and one new sequence exercising mark-then-fold-then-`mark_axis_current`; plus a `select_scope`-driven scoped fold sequence: compute the moving set via each model's OWN `select_scope` (not shared), assert the sets equal, then fold with them and `check_parity`. This closes the loop old-select→old-fold vs new-select→new-fold.
- [ ] **Step 2:** Full `dune build` + both test suites green.
- [ ] **Step 3:** Ledger: `Plan 3b: COMPLETE — selector surface + collapse_graph, parity across the board.` List any accepted divergences discovered.
- [ ] **Step 4:** Commit — `test(foldgraph): battery — marks, scope-driven scoped fold`

---

## After this plan (Plan 3c preview, context only)

Port `eval.ml` (~140 sites via the substitution dictionary; `Collapse.collapse` → `collapse_graph`), `fold_emit.ml` (`eassign` → `mv`, `eintent` → `intent`, `faces_matrix` → `face_iso2` matrix entries, `faceOrders` → `rel` + `face_up` for the sign, `table_position`/`init_square`/`subdivide_paper` already exist), tests (`test_fold_state.ml` largely superseded by the new suites; `test_eval`/`test_collapse`/`test_e2e`/`test_bel_assert`/`test_flatten` mechanical), delete `fold_state.ml`/`layer_order.ml`/old collapse kernel + parity halves, rename `Fold_graph` → `Fold_state`, goldens byte-identical.
