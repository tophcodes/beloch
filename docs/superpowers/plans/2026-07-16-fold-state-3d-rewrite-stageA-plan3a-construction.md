# Fold-state 3D rewrite — Stage A / Plan 3a: construction ops on the new core

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `Fold_graph` everything the old `Fold_state` construction layer does — surface metadata (crease ids, intent, provenance, marks), a whole-sheet base placement, and the state-evolving operations (`init_square`, `subdivide`, `subdivide_paper`, `fold`, `flip`, `add_mark`) — as pure graph transformations re-validated through `make`, with old-vs-new parity tests.

**Architecture:** Operations never compose isometries onto faces. A fold = cut the moving faces along the axis + set the new hinges' angle to 1 (toggling any on-axis existing hinge) + recompute the rank permutation; placements stay derived. One stored rigid motion `base` (the root face's placement) makes absolute table coordinates reproducible after pleats and flips without re-introducing per-face freedom.

**Tech Stack:** OCaml, dune, alcotest; exact arithmetic via `Num`; modules `lib/fold_graph.ml(i)`, `lib/isometry3.ml`, old `lib/fold_state.ml` kept alongside for parity tests (deleted in Plan 3c).

## Global Constraints

- Worktree `/home/toph/Projects/beloch-rewrite`, branch `feat/fold-state-invariants`. Verify with `git branch --show-current` before every commit.
- Build/test: `direnv exec /home/toph/Projects/beloch-rewrite dune build` and `direnv exec /home/toph/Projects/beloch-rewrite dune test`. Focused: `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`.
- PRE-EXISTING failures on this branch, IGNORE (stash-verified unrelated): `test_golden` rabbit-ear/swivel-rabbit "syntax error"; `test_eval` "found example files".
- Flat-first: hinge angles stay in {0, ±1} (× π). No floats. No new kernel.
- Old `Fold_state` / `Layer_order` are NOT touched in this plan (they die in Plan 3c).
- Stage explicit paths on commit; conventional commits.

## Design decisions (normative)

- **D1 — one `assign` type.** `type assign = M | V | F` replaces `type mv = M | V`. `mv : t -> int -> assign` becomes total: `F` iff the hinge's angle is 0, else the Plan-2c derived M/V. This is exactly the old `eassign`, now derived. Existing tests using `mv … = Some V` update to `= V`.
- **D2 — hinge metadata.** `hinge` gains `crease_id : int`, `intent : assign` (crease-pattern colour, the old `eintent` — stored, it is user intent, not geometry), `prov : State.provenance option`. There is NO stored `eassign` — that is `mv`.
- **D3 — marks.** The old `mark`/`mark_geom` types move verbatim onto the new module; `t` carries `marks : mark array` (paper-space, fold-invariant, no invariants to check). `make` takes them as optional `?marks`.
- **D4 — `base : Isometry3.t`.** Stored placement of the root face; `derive_isos` seeds the BFS with it instead of identity. Needed because after a pleat (fold, then fold moving the previously-stationary side) NO face keeps an identity placement, and `flip` moves everything. One whole-sheet rigid motion — no per-face freedom, tears stay unrepresentable. The closure/non-crossing checks are unaffected (a rigid motion of everything). `make` takes optional `?base` (default identity), so all existing call sites stay valid.
- **D5 — 2D access.** `face_iso2 : t -> int -> Isometry.t` extracts the in-plane block of the derived 3D placement (valid flat-first only; Stage B revisits). `rel : t -> int -> int -> rel` with `type rel = Above | Below | Apart` replaces `Layer_order.get`: `Apart` when the flat projections do not overlap (`Geom.convex_overlap`, winding-independent SAT), else by rank comparison.
- **D6 — ops via `make`.** Every operation builds new `faces/hinges/rank/root/base` arrays and constructs through `make`, so every invariant is re-checked at every step. A violation raises `Error.fail` with the provenance span (old `validity_error` behaviour).
- **D7 — carried hinges by re-attachment.** After a cut, an old hinge (p,q) is re-attached by enumerating child pairs (cp,cq) and keeping exactly those where `hinge_shared_segment` finds a positive-length shared segment on the hinge's line. No case analysis on which child sits where; degenerate pieces drop out automatically.
- **D8 — on-axis toggle.** For a fold along `axis`, an existing hinge whose table segment lies on the axis with exactly one side moving gets its angle TOGGLED (0↔1): motion algebra gives motion' = (half-turn about the hinge line) ∘ motion. 0→1 is the old F→M/V precrease upgrade (intent updated to the parity letter of the moved parent); 1→0 is a physical unfold, which the old stored-`eassign` model got wrong — the derived model is authoritative (accepted divergence; only observable through a folded-frame letter on a re-folded crease).
- **D9 — face-array order replicates the old model exactly** (subdivide: per parent, plus-child then minus-child; fold: stationary block then moved block for valley, moved then stationary for mountain, with the old list-accumulation order; flip: array reversed). FOLD emit iterates faces by index — goldens depend on it.
- **D10 — id minting moves.** `next_id` / `reset_ids` / `fresh_crease_id` get their own counter in `Fold_graph` (the old module keeps its own until Plan 3c).

File structure: everything lands in `lib/fold_graph.ml` + `lib/fold_graph.mli`; tests in `tests/test_fold_graph.ml`. No new files.

---

### Task 1: assign unification, hinge metadata, marks, base

**Files:**
- Modify: `lib/fold_graph.mli`
- Modify: `lib/fold_graph.ml`
- Modify: `tests/test_fold_graph.ml` (mechanical: hinge literals, mv expectations)

**Interfaces:**
- Consumes: `Isometry3` (Plan 1), existing `make` pipeline (Plan 2b/2c).
- Produces (later tasks build on these exact names):
  - `type assign = M | V | F`
  - `type hinge = { fa : int; fb : int; line : Geom.line; angle : Num.t; crease_id : int; intent : assign; prov : State.provenance option }`
  - `type mark_geom = MSeg of Geom.point * Geom.point | MPoint of Geom.point`
  - `type mark = { mgeom : mark_geom; mline : Geom.line; mintent : assign; mcrease_id : int; mprov : State.provenance option }`
  - `val make : ?base:Isometry3.t -> ?marks:mark array -> faces:face array -> hinges:hinge array -> root:int -> rank:int array -> (t, violation) result`
  - `val base : t -> Isometry3.t`, `val marks : t -> mark array`
  - `val mv : t -> int -> assign` (total; F ⟺ angle 0)
  - `val fresh_crease_id : unit -> int`, `val reset_ids : unit -> unit`

- [ ] **Step 1: Write failing tests**

Append to `tests/test_fold_graph.ml` (and add a hinge-literal helper near the top, then use it to shorten the EXISTING literals):

```ocaml
(* Task 1 helper: metadata-carrying hinge literal with defaults *)
let mkh ?(cid = -1) ?(intent = Fold_graph.F) ?(prov = None) fa fb line angle =
  { Fold_graph.fa; fb; line; angle; crease_id = cid; intent; prov }
```

```ocaml
(* --- Plan 3a Task 1: metadata, marks, base ------------------------------- *)

let test_metadata_carried () =
  let faces = single_fold_faces () in
  let hinges = [| mkh ~cid:7 ~intent:Fold_graph.V 0 1 (vline 1) (q 1) |] in
  let g = mk ~faces ~hinges ~rank:[| 0; 1 |] () in
  let h = (Fold_graph.hinges g).(0) in
  Alcotest.(check int) "crease_id" 7 h.Fold_graph.crease_id;
  Alcotest.(check bool) "intent" true (h.Fold_graph.intent = Fold_graph.V)

let test_mv_total () =
  (* folded hinge derives M or V; flat hinge derives F *)
  let faces = single_fold_faces () in
  let folded = mk ~faces ~hinges:[| mkh 0 1 (vline 1) (q 1) |] ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "folded = V" true (Fold_graph.mv folded 0 = Fold_graph.V);
  let flat = mk ~faces ~hinges:[| mkh 0 1 (vline 1) (q 0) |] ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "flat = F" true (Fold_graph.mv flat 0 = Fold_graph.F)

let test_base_shifts_placements () =
  (* base = translation by (3,0): derived table coords shift; invariants hold *)
  let tr =
    { Isometry3.identity with Isometry3.tx = q 3 }
  in
  let faces = single_fold_faces () in
  let hinges = [| mkh 0 1 (vline 1) (q 1) |] in
  match Fold_graph.make ~base:tr ~faces ~hinges ~root:0 ~rank:[| 0; 1 |] with
  | Error v -> Alcotest.failf "base: %s" (Fold_graph.violation_to_string v)
  | Ok g ->
      Alcotest.(check bool) "base stored" true
        (Isometry3.equal (Fold_graph.base g) tr);
      let p = Isometry3.apply_point (Fold_graph.face_iso g 0) (p3 0 0 0) in
      Alcotest.(check bool) "root shifted" true (i3eq p (p3 3 0 0))

let test_marks_carried () =
  let m =
    { Fold_graph.mgeom = Fold_graph.MPoint (gp 0 0);
      mline = vline 0; mintent = Fold_graph.M; mcrease_id = 3; mprov = None }
  in
  let g =
    match
      Fold_graph.make ~marks:[| m |] ~faces:[| strip_face 0 2 |] ~hinges:[||]
        ~root:0 ~rank:[| 0 |]
    with
    | Ok g -> g
    | Error v -> Alcotest.failf "marks: %s" (Fold_graph.violation_to_string v)
  in
  Alcotest.(check int) "one mark" 1 (Array.length (Fold_graph.marks g))

let test_fresh_ids () =
  Fold_graph.reset_ids ();
  let a = Fold_graph.fresh_crease_id () in
  let b = Fold_graph.fresh_crease_id () in
  Alcotest.(check int) "0" 0 a;
  Alcotest.(check int) "1" 1 b;
  Fold_graph.reset_ids ();
  Alcotest.(check int) "reset" 0 (Fold_graph.fresh_crease_id ())
```

Register the five tests in the suite list. Update ALL existing hinge literals to `mkh` (or add the three fields) and every `mv` expectation from `Some M`/`Some V`/`None` to `M`/`V`/`F`.

- [ ] **Step 2: Run to verify failure**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune build`
Expected: type errors (unknown fields `crease_id` on hinge, `mv` arity/type) — the point is the suite does not compile until Step 3.

- [ ] **Step 3: Implement**

In `lib/fold_graph.ml`:

1. Add types after `type face` (BEFORE `hinge` so `intent` can use it):

```ocaml
type assign = M | V | F

type hinge = {
  fa : int;
  fb : int;
  line : Geom.line;
  angle : Num.t;
  crease_id : int;  (* internal identity; unique within a state, never serialized *)
  intent : assign;  (* crease-pattern colour (old eintent) — user intent, stored *)
  prov : State.provenance option;
}

type mark_geom = MSeg of Geom.point * Geom.point | MPoint of Geom.point

(* Paper-space, fold-invariant reference/pinch record (moved verbatim from the
   old Fold_state; see that module's doc comment). No invariants of its own. *)
type mark = {
  mgeom : mark_geom;
  mline : Geom.line;
  mintent : assign;
  mcrease_id : int;
  mprov : State.provenance option;
}
```

2. Extend `t` (and keep `segs` — Task 2 exposes it):

```ocaml
type t = {
  faces : face array;
  hinges : hinge array;
  root : int;
  rank : int array;
  base : Isometry3.t;  (* placement of the root face — ONE whole-sheet motion *)
  marks : mark array;
  isos : Isometry3.t array;
  segs : (Geom.point * Geom.point) array;  (* per-hinge shared paper segment *)
}
```

3. Id minting (module level):

```ocaml
(* Mints internal crease ids; reset per eval so ids are a deterministic
   function of the program. Own counter — the old Fold_state keeps its own
   until Plan 3c deletes it. *)
let next_id = ref 0
let reset_ids () = next_id := 0
let fresh_crease_id () =
  let id = !next_id in
  incr next_id;
  id
```

4. `derive_isos` seeds the root with `base`: add `~(base : I3.t)` parameter, replace `let iso = Array.make n I3.identity in` seeding by `iso.(root) <- base` right before the BFS push. (All checks downstream are unchanged — a uniform rigid motion drops out of the closure equation and only rigidly moves the flat projections.)

5. `make`:

```ocaml
let make ?(base = I3.identity) ?(marks = [||]) ~(faces : face array)
    ~(hinges : hinge array) ~(root : int) ~(rank : int array) :
    (t, violation) result =
```

Pass `~base` to `derive_isos`; keep the `segs` array computed by the adjacency check (it is already there as `segs`) and store it in the record along with `base` and `marks = Array.copy marks`.

6. Accessors + `mv` total:

```ocaml
let base (g : t) : I3.t = g.base
let marks (g : t) : mark array = Array.copy g.marks

let mv (g : t) (i : int) : assign =
  let h = g.hinges.(i) in
  if Num.sign h.angle = 0 then F
  else if above g h.fb h.fa = face_up g h.fa then V else M
```

Delete `type mv = M | V` and the old `mv` returning option.

7. Mirror everything in `lib/fold_graph.mli` (hinge/mark types concrete, `t` stays abstract, `make` with the two leading optionals, `base`/`marks` accessors, `val mv : t -> int -> assign`, id mint functions). Document `base` with the pleat/flip rationale from D4.

- [ ] **Step 4: Run tests**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`
Expected: PASS (29 existing updated + 5 new). Also `dune build` clean (no warnings).

- [ ] **Step 5: Commit**

```bash
git add lib/fold_graph.ml lib/fold_graph.mli tests/test_fold_graph.ml
git commit -m "feat(foldgraph): hinge metadata, marks, base placement, total mv"
```

---

### Task 2: 2D access layer — face_iso2, table polygons, rel, hinge segments, point queries

**Files:**
- Modify: `lib/fold_graph.ml`, `lib/fold_graph.mli`
- Test: `tests/test_fold_graph.ml`

**Interfaces:**
- Consumes: Task 1's `t` with `segs`/`base`.
- Produces:
  - `val face_iso2 : t -> int -> Isometry.t` (flat-first in-plane block)
  - `val table_polygon : t -> int -> Geom.point array`
  - `val table_polygon_ccw : t -> int -> Geom.point array`
  - `type rel = Above | Below | Apart` and `val rel : t -> int -> int -> rel`
  - `val hinge_segment : t -> int -> Geom.point * Geom.point` (paper)
  - `val hinge_table_segment : t -> int -> Geom.point * Geom.point`
  - `val table_position : t -> Geom.point -> Geom.point`
  - `val paper_preimages : t -> Geom.point -> Geom.point list`
  - `val on_paper : t -> Geom.point -> bool`

- [ ] **Step 1: Write failing tests**

```ocaml
(* --- Plan 3a Task 2: 2D access ------------------------------------------- *)

(* single fold: face1 = [1,2]x[0,1] folded across x=1 onto face0 = [0,1]x[0,1] *)
let folded_pair () =
  mk ~faces:(single_fold_faces ())
    ~hinges:[| mkh 0 1 (vline 1) (q 1) |] ~rank:[| 0; 1 |] ()

let test_face_iso2 () =
  let g = folded_pair () in
  (* face1's in-plane placement is the reflection across x=1: (2,0) ↦ (0,0) *)
  let p = Isometry.apply_point (Fold_graph.face_iso2 g 1) (gp 2 0) in
  Alcotest.(check bool) "reflected" true (Geom.point_equal p (gp 0 0));
  Alcotest.(check int) "det -1" (-1) (Isometry.det_sign (Fold_graph.face_iso2 g 1));
  Alcotest.(check int) "det +1" 1 (Isometry.det_sign (Fold_graph.face_iso2 g 0))

let test_table_polygon_and_rel () =
  let g = folded_pair () in
  let tp1 = Fold_graph.table_polygon g 1 in
  Alcotest.(check bool) "folded onto [0,1]^2" true
    (Array.for_all Geom.in_unit_square tp1);
  Alcotest.(check bool) "1 above 0" true (Fold_graph.rel g 1 0 = Fold_graph.Above);
  Alcotest.(check bool) "0 below 1" true (Fold_graph.rel g 0 1 = Fold_graph.Below);
  (* flat (unfolded) neighbours do not overlap -> Apart *)
  let flat =
    mk ~faces:(single_fold_faces ())
      ~hinges:[| mkh 0 1 (vline 1) (q 0) |] ~rank:[| 0; 1 |] ()
  in
  Alcotest.(check bool) "flat Apart" true (Fold_graph.rel flat 0 1 = Fold_graph.Apart)

let test_hinge_segments () =
  let g = folded_pair () in
  let a, b = Fold_graph.hinge_segment g 0 in
  Alcotest.(check bool) "paper seg on x=1" true
    (Num.equal a.Geom.x (q 1) && Num.equal b.Geom.x (q 1));
  let ta, tb = Fold_graph.hinge_table_segment g 0 in
  Alcotest.(check bool) "table seg on x=1" true
    (Num.equal ta.Geom.x (q 1) && Num.equal tb.Geom.x (q 1))

let test_point_queries () =
  let g = folded_pair () in
  (* paper (3/2, 1/2) lives on face1 -> table (1/2, 1/2) *)
  let half = Num.div Num.one (Num.of_int 2) in
  let three_half = Num.div (Num.of_int 3) (Num.of_int 2) in
  let tp = Fold_graph.table_position g { Geom.x = three_half; y = half } in
  Alcotest.(check bool) "table pos" true
    (Geom.point_equal tp { Geom.x = half; y = half });
  (* table (1/2,1/2) is covered by both layers -> two paper preimages *)
  let pre = Fold_graph.paper_preimages g { Geom.x = half; y = half } in
  Alcotest.(check int) "two layers" 2 (List.length pre);
  Alcotest.(check bool) "on paper" true
    (Fold_graph.on_paper g { Geom.x = three_half; y = half });
  Alcotest.(check bool) "off paper" false
    (Fold_graph.on_paper g { Geom.x = q 5; y = q 5 })
```

Register the four tests.

- [ ] **Step 2: Run to verify failure**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune build`
Expected: unbound `Fold_graph.face_iso2` etc.

- [ ] **Step 3: Implement**

In `lib/fold_graph.ml` (after the accessors):

```ocaml
(* In-plane 2D restriction of face [i]'s derived placement. Flat-first the
   motions keep z = 0 invariant (angles ∈ {0, ±1}), so the upper-left block +
   (tx, ty) IS the table placement as a 2D isometry. Stage B (partial angles)
   lifts faces off the plane and must not use this. *)
let face_iso2 (g : t) (i : int) : Isometry.t =
  let m = g.isos.(i) in
  { Isometry.m00 = m.I3.m00; m01 = m.I3.m01; m10 = m.I3.m10; m11 = m.I3.m11;
    tx = m.I3.tx; ty = m.I3.ty }

let table_polygon (g : t) (i : int) : Geom.point array =
  Array.map (Isometry.apply_point (face_iso2 g i)) g.faces.(i)

(* CCW-normalized (a reflected placement reverses winding); the clip/crossing
   helpers in Geom require CCW input. *)
let table_polygon_ccw' (g : t) (i : int) : Geom.point array =
  let tp = table_polygon g i in
  if Num.sign (Geom.signed_area tp) < 0 then begin
    let n = Array.length tp in
    Array.init n (fun k -> tp.(n - 1 - k))
  end
  else tp

type rel = Above | Below | Apart

(* Layer relation of two faces: rank order where the flat projections overlap
   (Geom.convex_overlap is SAT-based, winding-independent, strict — touching
   is not overlap, same as the old Layer_order), Apart otherwise. *)
let rel (g : t) (i : int) (j : int) : rel =
  if i = j then Apart
  else if Geom.convex_overlap (table_polygon g i) (table_polygon g j) then
    if g.rank.(i) > g.rank.(j) then Above else Below
  else Apart

let hinge_segment (g : t) (i : int) : Geom.point * Geom.point = g.segs.(i)

let hinge_table_segment (g : t) (i : int) : Geom.point * Geom.point =
  let a, b = g.segs.(i) in
  let iso = face_iso2 g g.hinges.(i).fa in
  (Isometry.apply_point iso a, Isometry.apply_point iso b)

(* Current table position of a material paper point: faces partition the paper
   and placements agree on shared hinges, so any containing face works. *)
let table_position (g : t) (paper : Geom.point) : Geom.point =
  let n = Array.length g.faces in
  let rec find i =
    if i >= n then invalid_arg "Fold_graph.table_position: point in no face"
    else if Geom.in_convex_polygon g.faces.(i) paper then
      Isometry.apply_point (face_iso2 g i) paper
    else find (i + 1)
  in
  find 0

(* Distinct paper coordinates whose current table position is [tp] (one per
   overlapping layer covering that table point). *)
let paper_preimages (g : t) (tp : Geom.point) : Geom.point list =
  let acc = ref [] in
  Array.iteri
    (fun i f ->
      let pp = Isometry.apply_point (Isometry.inverse (face_iso2 g i)) tp in
      if
        Geom.in_convex_polygon f pp
        && not (List.exists (Geom.point_equal pp) !acc)
      then acc := pp :: !acc)
    g.faces;
  List.rev !acc

let on_paper (g : t) (pp : Geom.point) : bool =
  Array.exists (fun f -> Geom.in_convex_polygon f pp) g.faces
```

Note: `make` already has an internal `table_polygon_ccw` over raw arrays; keep that one, name the new public accessor `table_polygon_ccw` in the `.mli` and reconcile the internal name (`table_polygon_ccw'` above, exported as `table_polygon_ccw`) — or rename the internal helper; implementer's choice, no behaviour change.

Mirror all signatures in `lib/fold_graph.mli` (with the Stage-B caveat on `face_iso2`).

- [ ] **Step 4: Run tests**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_graph.ml lib/fold_graph.mli tests/test_fold_graph.ml
git commit -m "feat(foldgraph): 2D access layer — face_iso2, rel, segments, point queries"
```

---

### Task 3: init_square, subdivide, subdivide_paper

**Files:**
- Modify: `lib/fold_graph.ml`, `lib/fold_graph.mli`
- Test: `tests/test_fold_graph.ml`

**Interfaces:**
- Consumes: Tasks 1–2 (`face_iso2`, `hinge_shared_segment`, `fresh_crease_id`, `rel`).
- Produces:
  - `val init_square : t`
  - `val subdivide : ?crease_id:int -> ?intent:assign -> ?keep_side:Geom.line * int -> t -> Geom.line -> prov:State.provenance option -> t`
  - `val subdivide_paper : ?crease_id:int -> ?intent:assign -> t -> Geom.line -> prov:State.provenance option -> t`
  - internal: `split_faces`, `reattach_hinges`, `densify_rank` (shared with Task 4's `fold`)

- [ ] **Step 1: Write failing tests** (parity against the OLD module)

```ocaml
(* --- Plan 3a Task 3: subdivision ------------------------------------------ *)

(* parity harness: compare a new state against an old Fold_state.t *)
let check_parity label (g : Fold_graph.t) (st : Fold_state.t) =
  let nf = Array.length (Fold_graph.faces g) in
  Alcotest.(check int) (label ^ ": face count") (Array.length st.Fold_state.faces) nf;
  for i = 0 to nf - 1 do
    let fp = (Fold_graph.faces g).(i) in
    let op = st.Fold_state.faces.(i).Fold_state.paper in
    Alcotest.(check int) (label ^ ": paper verts") (Array.length op) (Array.length fp);
    Array.iteri
      (fun k p ->
        Alcotest.(check bool)
          (Printf.sprintf "%s: face %d paper %d" label i k) true
          (Geom.point_equal p op.(k)))
      fp;
    let tp = Fold_graph.table_polygon g i in
    let ot = Fold_state.table_polygon st i in
    Array.iteri
      (fun k p ->
        Alcotest.(check bool)
          (Printf.sprintf "%s: face %d table %d" label i k) true
          (Geom.point_equal p ot.(k)))
      tp
  done;
  for i = 0 to nf - 1 do
    for j = 0 to nf - 1 do
      let nr = Fold_graph.rel g i j in
      let orl = Layer_order.get st.Fold_state.order i j in
      let same =
        match (nr, orl) with
        | Fold_graph.Above, Fold_state.Above
        | Fold_graph.Below, Fold_state.Below
        | Fold_graph.Apart, Fold_state.Apart -> true
        | _ -> false
      in
      Alcotest.(check bool) (Printf.sprintf "%s: rel %d %d" label i j) true same
    done
  done

let test_subdivide_parity () =
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let diag = { Geom.a = q 1; b = q 1; c = q 1 } in  (* diagonal x+y=1 *)
  let g = Fold_graph.subdivide Fold_graph.init_square diag ~prov:None in
  let st = Fold_state.subdivide Fold_state.init_square diag ~prov:None in
  check_parity "diag" g st;
  (* the new F hinge exists and carries the id/intent *)
  let hs = Fold_graph.hinges g in
  Alcotest.(check int) "one hinge" 1 (Array.length hs);
  Alcotest.(check bool) "flat" true (Num.sign hs.(0).Fold_graph.angle = 0)

let test_subdivide_carried_split () =
  (* two crossing subdivisions: the first crease's hinge splits into two *)
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let d1 = { Geom.a = q 1; b = q 1; c = q 1 } in
  let d2 = { Geom.a = q 1; b = q (-1); c = q 0 } in
  let g = Fold_graph.subdivide (Fold_graph.subdivide Fold_graph.init_square d1 ~prov:None) d2 ~prov:None in
  let st = Fold_state.subdivide (Fold_state.subdivide Fold_state.init_square d1 ~prov:None) d2 ~prov:None in
  check_parity "cross" g st;
  (* 4 faces; first crease now two hinge pieces sharing crease_id 0 *)
  let hs = Fold_graph.hinges g in
  let pieces_of cid =
    Array.to_list hs |> List.filter (fun h -> h.Fold_graph.crease_id = cid)
  in
  Alcotest.(check int) "crease 0 split in two" 2 (List.length (pieces_of 0));
  Alcotest.(check int) "crease 1 in two" 2 (List.length (pieces_of 1))

let test_subdivide_keep_side () =
  (* guard: perpendicular through (1/2,1/2); only the y>1/2 ray creases *)
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let axis = { Geom.a = q 1; b = q 0; c = half } in    (* x = 1/2 *)
  let guard = { Geom.a = q 0; b = q 1; c = half } in   (* y = 1/2 *)
  (* pre-split horizontally so the guard has faces on both sides *)
  let base_new = Fold_graph.subdivide Fold_graph.init_square guard ~prov:None in
  let base_old = Fold_state.subdivide Fold_state.init_square guard ~prov:None in
  let g = Fold_graph.subdivide base_new axis ~keep_side:(guard, 1) ~prov:None in
  let st = Fold_state.subdivide base_old axis ~keep_side:(guard, 1) ~prov:None in
  check_parity "keep_side" g st
```

Register the three tests. (Old and new id counters run independently — call `Fold_graph.reset_ids ()`/`Fold_state.reset_ids ()` in tandem at each test start; the parity harness never compares ids across models except where stated.) Note: `Fold_state.reset_ids ()` must be called too where old subdivides mint ids — add it alongside each `Fold_graph.reset_ids ()`.

- [ ] **Step 2: Run to verify failure**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune build`
Expected: unbound `Fold_graph.init_square` / `Fold_graph.subdivide`.

- [ ] **Step 3: Implement**

In `lib/fold_graph.ml`:

```ocaml
(* ------------------------------------------------------------------ *)
(* Construction operations (Plan 3a). Each op builds new arrays and    *)
(* re-validates through [make]; a violation raises [Error.fail] at the *)
(* provenance span. Faces never carry isometries — a fold only sets    *)
(* hinge angles and the rank.                                          *)
(* ------------------------------------------------------------------ *)

let fail_of_violation (prov : State.provenance option) (v : violation) : 'a =
  let span =
    match prov with
    | Some p -> p.State.span
    | None -> (Lexing.dummy_pos, Lexing.dummy_pos)
  in
  Error.fail span (violation_to_string v)

let init_square : t =
  let p x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  match
    make ~faces:[| [| p 0 0; p 1 0; p 1 1; p 0 1 |] |] ~hinges:[||] ~root:0
      ~rank:[| 0 |]
  with
  | Ok g -> g
  | Error _ -> assert false

(* The chord (in PAPER coordinates) where table-space [axis] crosses the
   interior of face [i]; None if it misses (touches at most a point).
   Port of the old Fold_state.axis_segment_in_face. *)
let axis_chord_in_face (g : t) (i : int) (axis : Geom.line) :
    (Geom.point * Geom.point) option =
  let iso2 = face_iso2 g i in
  let table = Array.map (Isometry.apply_point iso2) g.faces.(i) in
  let n = Array.length table in
  let pts = ref [] in
  let add p =
    if not (List.exists (Geom.point_equal p) !pts) then pts := p :: !pts
  in
  for k = 0 to n - 1 do
    let a = table.(k) and b = table.((k + 1) mod n) in
    let sa = Geom.side_of_line axis a and sb = Geom.side_of_line axis b in
    if sa = 0 then add a
    else if sb <> 0 && sa <> sb then
      match Geom.intersection axis (Geom.line_through a b) with
      | Some r -> add r
      | None -> ()
  done;
  match !pts with
  | [ p; q0 ] ->
      let inv = Isometry.inverse iso2 in
      Some (Isometry.apply_point inv p, Isometry.apply_point inv q0)
  | _ -> None

(* Re-attach the old hinges over a face split. [children_of p] lists the child
   indices of old face p (a single element when uncut). A candidate pair keeps
   the hinge iff its line still carries a positive shared boundary segment
   between the two children (D7) — degenerate pieces drop out here. *)
let reattach_hinges ~(faces' : face array) ~(children_of : int -> int list)
    (hinges : hinge array) : hinge list =
  Array.to_list hinges
  |> List.concat_map (fun h ->
         List.concat_map
           (fun cp ->
             List.filter_map
               (fun cq ->
                 let h' = { h with fa = cp; fb = cq } in
                 match hinge_shared_segment faces' h' with
                 | Some _ -> Some h'
                 | None -> None)
               (children_of h.fb))
           (children_of h.fa))

(* Dense rank over the children: children inherit their parent's height;
   within one parent, array order (plus-child first) breaks the tie. *)
let densify_rank ~(old_rank : int array) ~(parent : int array) : int array =
  let n' = Array.length parent in
  let idx = Array.init n' Fun.id in
  Array.sort
    (fun i j -> compare (old_rank.(parent.(i)), i) (old_rank.(parent.(j)), j))
    idx;
  let rank' = Array.make n' 0 in
  Array.iteri (fun h i -> rank'.(i) <- h) idx;
  rank'

(* Shared splitter for [subdivide] (table-space axis, optional ray guard) and
   [subdivide_paper] (paper-space line). [cut_of i] gives the PAPER-space
   chord to cut face i with, or None to keep it whole. Children order per
   parent: plus side first, then minus (D9 — matches the old face order). *)
let split_with_flat_hinges (g : t) ~(cid : int) ~(intent : assign)
    ~(prov : State.provenance option)
    ~(cut_of : int -> (Geom.point * Geom.point) option) : t =
  let out = ref [] in (* (paper_poly, parent) — prepended, reversed at the end *)
  let chords = ref [] in (* (parent, a, b) for each actually-cut face *)
  Array.iteri
    (fun fi f ->
      match cut_of fi with
      | None -> out := (f, fi) :: !out
      | Some (a, b) ->
          let line = Geom.line_through a b in
          let part k =
            let sub = Geom.clip_convex_halfplane line k f in
            if Array.length sub >= 3 then Some sub else None
          in
          (match (part 1, part (-1)) with
          | Some pp, Some pm ->
              chords := (fi, a, b) :: !chords;
              out := (pm, fi) :: (pp, fi) :: !out
          | Some pp, None -> out := (pp, fi) :: !out
          | None, Some pm -> out := (pm, fi) :: !out
          | None, None -> out := (f, fi) :: !out))
    g.faces;
  let arr = Array.of_list (List.rev !out) in
  let faces' = Array.map fst arr in
  let parent = Array.map snd arr in
  let children_of p =
    let acc = ref [] in
    Array.iteri (fun k pp -> if pp = p then acc := k :: !acc) parent;
    List.rev !acc
  in
  let new_hinges =
    List.rev_map
      (fun (fi, a, b) ->
        match children_of fi with
        | [ cp; cm ] ->
            { fa = cp; fb = cm; line = Geom.line_through a b; angle = Num.zero;
              crease_id = cid; intent; prov }
        | _ -> assert false)
      !chords
  in
  let carried = reattach_hinges ~faces' ~children_of g.hinges in
  let rank' = densify_rank ~old_rank:g.rank ~parent in
  let root' = List.hd (children_of g.root) in
  match
    make ~base:g.base ~marks:g.marks ~faces:faces'
      ~hinges:(Array.of_list (new_hinges @ carried)) ~root:root' ~rank:rank'
  with
  | Ok g' -> g'
  | Error v -> fail_of_violation prov v

let subdivide ?crease_id ?(intent = V) ?keep_side (g : t) (axis : Geom.line)
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let on_keep_side fi =
    match keep_side with
    | None -> true
    | Some (guard, keep) ->
        (* table centroid of the face, old on_keep_side *)
        let tp = table_polygon g fi in
        let n = Array.length tp in
        let sx = ref Num.zero and sy = ref Num.zero in
        Array.iter
          (fun (p : Geom.point) ->
            sx := Num.add !sx p.Geom.x;
            sy := Num.add !sy p.Geom.y)
          tp;
        let c =
          { Geom.x = Num.div !sx (Num.of_int n); y = Num.div !sy (Num.of_int n) }
        in
        Geom.side_of_line guard c = keep
  in
  let cut_of fi =
    if on_keep_side fi then axis_chord_in_face g fi axis else None
  in
  split_with_flat_hinges g ~cid ~intent ~prov ~cut_of

let subdivide_paper ?crease_id ?(intent = V) (g : t) (paper_axis : Geom.line)
    ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let cut_of fi = Geom.clip_line_to_convex paper_axis g.faces.(fi) in
  split_with_flat_hinges g ~cid ~intent ~prov ~cut_of
```

Mirror `init_square`, `subdivide`, `subdivide_paper` in the `.mli`.

Note for the implementer: `axis_chord_in_face` intentionally works in table space and maps back (exact port of the old geometry); `subdivide_paper`'s `cut_of` uses `Geom.clip_line_to_convex` on the paper polygon directly like the old `subdivide_paper` (positive-length check is inside `split_with_flat_hinges` via the two `part` clips).

- [ ] **Step 4: Run tests**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`
Expected: PASS, including the parity checks.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_graph.ml lib/fold_graph.mli tests/test_fold_graph.ml
git commit -m "feat(foldgraph): init_square + subdivide/subdivide_paper via make"
```

---

### Task 4: fold — the simple flat fold as a graph transformation

**Files:**
- Modify: `lib/fold_graph.ml`, `lib/fold_graph.mli`
- Test: `tests/test_fold_graph.ml`

**Interfaces:**
- Consumes: Task 3's splitter internals (`axis_chord_in_face`, `reattach_hinges`), Task 2's `face_iso2`/`rel`.
- Produces:
  - `val fold : ?crease_id:int -> ?moving_parents:bool array -> t -> axis:Geom.line -> move_side:int -> valley:bool -> prov:State.provenance option -> t`
  - `val simple_fold : t -> axis:Geom.line -> move_side:int -> valley:bool -> t`
  - internal `half_turn3_of_line : Geom.line -> Isometry3.t` (factored out of `hinge_motion`)

- [ ] **Step 1: Write failing tests** (parity against the old `fold_with_records`)

```ocaml
(* --- Plan 3a Task 4: fold -------------------------------------------------- *)

(* eassign parity: every folded hinge's derived mv must equal the old edge's
   stored eassign for the edge with the same paper endpoints *)
let check_assign_parity label (g : Fold_graph.t) (st : Fold_state.t) =
  let hs = Fold_graph.hinges g in
  Array.iteri
    (fun i (h : Fold_graph.hinge) ->
      let a, b = Fold_graph.hinge_segment g i in
      match
        Array.to_list st.Fold_state.edges
        |> List.find_opt (fun (e : Fold_state.edge) ->
               (Geom.point_equal e.Fold_state.ea a && Geom.point_equal e.Fold_state.eb b)
               || (Geom.point_equal e.Fold_state.ea b && Geom.point_equal e.Fold_state.eb a))
      with
      | None -> Alcotest.failf "%s: hinge %d has no old edge" label i
      | Some e ->
          let old_a =
            match e.Fold_state.eassign with
            | Fold_state.M -> Fold_graph.M
            | Fold_state.V -> Fold_graph.V
            | Fold_state.F -> Fold_graph.F
          in
          Alcotest.(check bool)
            (Printf.sprintf "%s: hinge %d assign (angle %s)" label i
               (if Num.sign h.Fold_graph.angle = 0 then "0" else "1"))
            true
            (Fold_graph.mv g i = old_a))
    hs

let vfold_new g ax = Fold_graph.fold g ~axis:ax ~move_side:1 ~valley:true ~prov:None
let vfold_old st ax = Fold_state.fold_with_records st ~axis:ax ~move_side:1 ~valley:true ~prov:None

let test_fold_parity_single () =
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g = vfold_new Fold_graph.init_square ax in
  let st = vfold_old Fold_state.init_square ax in
  check_parity "single fold" g st;
  check_assign_parity "single fold" g st

let test_fold_parity_mountain () =
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g = Fold_graph.fold Fold_graph.init_square ~axis:ax ~move_side:1
      ~valley:false ~prov:None in
  let st = Fold_state.fold_with_records Fold_state.init_square ~axis:ax
      ~move_side:1 ~valley:false ~prov:None in
  check_parity "mountain" g st;
  check_assign_parity "mountain" g st

let test_fold_parity_pleat () =
  (* second fold refolds the packet — movers include previously-moved AND
     previously-stationary material, so carried folded hinges move as a block
     (nontrivial base is exercised separately by the flip tests in Task 5) *)
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let quarter = Num.div Num.one (Num.of_int 4) in
  let ax1 = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let ax2 = { Geom.a = q 1; b = q 0; c = quarter } in
  (* fold right half left over x=1/2, then fold everything right of x=1/4
     back over x=1/4, moving the packet to the left *)
  let g = vfold_new (vfold_new Fold_graph.init_square ax1) ax2 in
  let st = vfold_old (vfold_old Fold_state.init_square ax1) ax2 in
  check_parity "pleat" g st;
  check_assign_parity "pleat" g st

let test_fold_precrease_upgrade () =
  (* subdivide (F) then fold on the same axis: the F hinge toggles to angle 1
     and the intent letter upgrades (old #27 upgrade path) *)
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g0 = Fold_graph.subdivide Fold_graph.init_square ax ~intent:Fold_graph.M ~prov:None in
  let st0 = Fold_state.subdivide Fold_state.init_square ax ~intent:Fold_state.M ~prov:None in
  let g = vfold_new g0 ax in
  let st = vfold_old st0 ax in
  check_parity "upgrade" g st;
  check_assign_parity "upgrade" g st;
  (* the upgraded hinge is folded and keeps its crease id 0 *)
  let hs = Fold_graph.hinges g in
  let folded =
    Array.to_list hs |> List.filter (fun h -> Num.sign h.Fold_graph.angle <> 0)
  in
  Alcotest.(check int) "one folded hinge" 1 (List.length folded);
  Alcotest.(check int) "kept id" 0 (List.hd folded).Fold_graph.crease_id

let test_fold_scoped_parity () =
  (* two layers via a book fold, then a scoped fold of ONLY the top layer's
     free edge: fold the material LEFT of x=1/4 back to the right (move_side
     -1). The mover's only hinge to the stationary material is the book crease
     at table x=1/2 — on the stay side, so the scoped fold is hinge-closed
     (folding the x>1/4 side instead would tear at that hinge). moving_parents
     is computed by the OLD select_scope and fed verbatim to both models. *)
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let ax1 = { Geom.a = q 1; b = q 0; c = half } in
  let g1 = vfold_new Fold_graph.init_square ax1 in
  let st1 = vfold_old Fold_state.init_square ax1 in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let ax2 = { Geom.a = q 1; b = q 0; c = quarter } in
  let top =
    (* face with the highest rank among those overlapping face 0 *)
    let n = Array.length (Fold_graph.faces g1) in
    let best = ref 0 in
    for i = 1 to n - 1 do
      if Fold_graph.rel g1 i !best = Fold_graph.Above then best := i
    done;
    !best
  in
  match
    Fold_state.select_scope st1 ~axis:ax2 ~move_side:(-1) ~valley:true
      ~anchor:top ~target:(Fold_state.TargetFace top)
  with
  | Error e -> Alcotest.fail e
  | Ok moving ->
      let g = Fold_graph.fold g1 ~axis:ax2 ~move_side:(-1) ~valley:true
          ~moving_parents:moving ~prov:None in
      let st = Fold_state.fold_with_records st1 ~axis:ax2 ~move_side:(-1)
          ~valley:true ~moving_parents:moving ~prov:None in
      check_parity "scoped" g st;
      check_assign_parity "scoped" g st
```

Register the five tests.

- [ ] **Step 2: Run to verify failure**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune build`
Expected: unbound `Fold_graph.fold`.

- [ ] **Step 3: Implement**

First factor the half-turn constructor out of `hinge_motion` (pure refactor, same math):

```ocaml
(* 3D half-turn about a 2D line embedded in z = 0. *)
let half_turn3_of_line (l : Geom.line) : I3.t =
  let on =
    if Num.sign l.Geom.a <> 0 then
      { I3.x = Num.div l.Geom.c l.Geom.a; y = Num.zero; z = Num.zero }
    else { I3.x = Num.zero; y = Num.div l.Geom.c l.Geom.b; z = Num.zero }
  in
  let dir = { I3.x = Num.neg l.Geom.b; y = l.Geom.a; z = Num.zero } in
  I3.half_turn_about_line ~on ~dir

let hinge_motion (h : hinge) : I3.t =
  if Num.sign h.angle = 0 then I3.identity else half_turn3_of_line h.line
```

Then the fold:

```ocaml
(* Simple flat fold as a graph transformation: cut the moving faces along
   [axis], give the cut hinges angle 1, toggle existing on-axis hinges with
   exactly one moving side (D8), restack via rank blocks. Placements are
   derived; nothing composes isometries onto faces. Raises [Error.fail] when
   the resulting state violates an invariant (old validity_error behaviour). *)
let fold ?crease_id ?moving_parents (g : t) ~(axis : Geom.line)
    ~(move_side : int) ~(valley : bool) ~(prov : State.provenance option) : t =
  let cid = match crease_id with Some c -> c | None -> fresh_crease_id () in
  let moves fi =
    match moving_parents with None -> true | Some m -> m.(fi)
  in
  (* the crease-pattern letter of the fold on parent face fi: the user's
     valley XOR the parent's orientation parity (old assign_of) *)
  let letter_of fi =
    if valley <> (Isometry.det_sign (face_iso2 g fi) < 0) then V else M
  in
  (* 1. split: stationary children (stay side + all non-movers) and moved
     children, in the OLD accumulation order (D9): stay list is reversed at
     the end, mov list is not. *)
  let stay = ref [] and mov = ref [] in (* (paper_poly, parent) *)
  let chords = ref [] in (* (parent, a, b) for each face actually cut *)
  Array.iteri
    (fun fi f ->
      if not (moves fi) then stay := (f, fi) :: !stay
      else begin
        let iso2 = face_iso2 g fi in
        let table = Array.map (Isometry.apply_point iso2) f in
        let inv = Isometry.inverse iso2 in
        let part k =
          let sub = Geom.clip_convex_halfplane axis k table in
          if Array.length sub >= 3 then
            Some (Array.map (Isometry.apply_point inv) sub)
          else None
        in
        let s = part (-move_side) and m = part move_side in
        (match (s, m) with
        | Some _, Some _ -> (
            match axis_chord_in_face g fi axis with
            | Some (a, b) -> chords := (fi, a, b) :: !chords
            | None -> ())
        | _ -> ());
        (match s with Some poly -> stay := (poly, fi) :: !stay | None -> ());
        match m with Some poly -> mov := (poly, fi) :: !mov | None -> ()
      end)
    g.faces;
  let stationary = List.rev !stay in
  let moved = !mov in
  let ordered = if valley then stationary @ moved else moved @ stationary in
  let arr = Array.of_list ordered in
  let faces' = Array.map fst arr in
  let parent = Array.map snd arr in
  let n_stay = List.length stationary in
  let moved_flag =
    if valley then Array.init (Array.length arr) (fun i -> i >= n_stay)
    else Array.init (Array.length arr) (fun i -> i < List.length moved)
  in
  let children_of p =
    let acc = ref [] in
    Array.iteri (fun k pp -> if pp = p then acc := k :: !acc) parent;
    List.rev !acc
  in
  (* 2. new folded hinges along the axis, one per cut parent *)
  let new_hinges =
    List.rev_map
      (fun (fi, a, b) ->
        let sc = ref (-1) and mc = ref (-1) in
        Array.iteri
          (fun k pp ->
            if pp = fi then if moved_flag.(k) then mc := k else sc := k)
          parent;
        { fa = !sc; fb = !mc; line = Geom.line_through a b; angle = Num.one;
          crease_id = cid; intent = letter_of fi; prov })
      !chords
  in
  (* 3. carried hinges: re-attach (D7), then toggle on-axis hinges with
     exactly one moving side (D8) *)
  let moved_parent = Array.make (Array.length g.faces) false in
  Array.iteri
    (fun k pp -> if moved_flag.(k) then moved_parent.(pp) <- true)
    parent;
  let on_axis_of_old = Array.make (Array.length g.hinges) false in
  Array.iteri
    (fun hi (_ : hinge) ->
      let ta, tb = hinge_table_segment g hi in
      on_axis_of_old.(hi) <-
        Geom.side_of_line axis ta = 0 && Geom.side_of_line axis tb = 0)
    g.hinges;
  let carried =
    Array.to_list g.hinges
    |> List.concat_map (fun (h : hinge) ->
           let hi =
             (* index of h in g.hinges — carry it alongside instead of
                searching: rewrite as a mapi-based fold *)
             let r = ref (-1) in
             Array.iteri (fun k h' -> if h' == h then r := k) g.hinges;
             !r
           in
           let toggled =
             on_axis_of_old.(hi)
             && moved_parent.(h.fa) <> moved_parent.(h.fb)
           in
           let h =
             if not toggled then h
             else if Num.sign h.angle = 0 then
               (* precrease upgrade: F -> folded, intent gets the live letter
                  of the MOVED parent (old assign_of_parent mf, #27) *)
               let mf = if moved_parent.(h.fa) then h.fa else h.fb in
               { h with angle = Num.one; intent = letter_of mf }
             else { h with angle = Num.zero } (* physical unfold *)
           in
           List.concat_map
             (fun cp ->
               List.filter_map
                 (fun cq ->
                   let h' = { h with fa = cp; fb = cq } in
                   match hinge_shared_segment faces' h' with
                   | Some _ -> Some h'
                   | None -> None)
                 (children_of h.fb))
             (children_of h.fa))
  in
  (* 4. rank blocks: stationaries keep their order; movers reversed; movers
     on top for valley, below for mountain (old rel_of semantics) *)
  let n' = Array.length faces' in
  let idx = Array.init n' Fun.id in
  let key i =
    let r = g.rank.(parent.(i)) in
    if moved_flag.(i) then (1, -r, i) else (0, r, i)
  in
  let block_first = if valley then 0 else 1 in
  Array.sort
    (fun i j ->
      let (bi, ki, ti) = key i and (bj, kj, tj) = key j in
      let bi = if bi = block_first then 0 else 1
      and bj = if bj = block_first then 0 else 1 in
      compare (bi, ki, ti) (bj, kj, tj))
    idx;
  let rank' = Array.make n' 0 in
  Array.iteri (fun h i -> rank'.(i) <- h) idx;
  (* 5. root + base: prefer a stationary child (its parent's placement is
     unchanged); if everything moved, reflect the base across the axis *)
  let root', base' =
    let stat = ref (-1) in
    (match children_of g.root with
    | cs -> List.iter (fun c -> if (not (moved_flag.(c))) && !stat < 0 then stat := c) cs);
    if !stat >= 0 then (!stat, g.isos.(g.root))
    else begin
      let first_stat = ref (-1) in
      Array.iteri
        (fun k m -> if (not m) && !first_stat < 0 then first_stat := k)
        moved_flag;
      if !first_stat >= 0 then (!first_stat, g.isos.(parent.(!first_stat)))
      else (0, I3.compose (half_turn3_of_line axis) g.isos.(parent.(0)))
    end
  in
  match
    make ~base:base' ~marks:g.marks ~faces:faces'
      ~hinges:(Array.of_list (List.rev_append (List.rev new_hinges) carried))
      ~root:root' ~rank:rank'
  with
  | Ok g' -> g'
  | Error v -> fail_of_violation prov v

let simple_fold (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) : t =
  fold g ~axis ~move_side ~valley ~prov:None
```

Implementation notes (for the implementer, binding):
- The `hi`-by-physical-equality search inside `carried` is ugly; rewrite the whole `carried` computation as `Array.to_list (Array.mapi (fun hi h -> …) g.hinges) |> List.concat` so `hi` is directly available. Behaviour as written above.
- `root'` when the root parent was cut: `children_of g.root` returns its (≤2) children; the STATIONARY child keeps the parent's placement, so `base' = g.isos.(g.root)` is exact. When the root moved entirely, any stationary face's parent placement serves as the new base (that face becomes root). Only when NOTHING is stationary (whole-sheet "fold", not physically meaningful but total) reflect the base.
- Note the `key` trick: movers sort by `-r` (descending old rank) — that is the old `negate` of moved-vs-moved relations; block order gives moved-vs-stationary Above/Below; stationaries ascending preserve their relations. This reproduces the old `rel_of` on every overlapping pair.

Mirror `fold` and `simple_fold` in the `.mli`.

- [ ] **Step 4: Run tests**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`
Expected: PASS — all five parity tests including pleat (base) and scoped.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_graph.ml lib/fold_graph.mli tests/test_fold_graph.ml
git commit -m "feat(foldgraph): fold as graph transformation — angle set/toggle + rank blocks + base"
```

---

### Task 5: flip and add_mark

**Files:**
- Modify: `lib/fold_graph.ml`, `lib/fold_graph.mli`
- Test: `tests/test_fold_graph.ml`

**Interfaces:**
- Consumes: Task 4's `half_turn3_of_line`; Task 1's `marks`.
- Produces:
  - `val flip : t -> t`
  - `val add_mark : t -> mark -> t`

- [ ] **Step 1: Write failing tests**

```ocaml
(* --- Plan 3a Task 5: flip + add_mark -------------------------------------- *)

let test_flip_parity () =
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g = Fold_graph.flip (vfold_new Fold_graph.init_square ax) in
  let st = Fold_state.flip (vfold_old Fold_state.init_square ax) in
  check_parity "flip" g st;
  check_assign_parity "flip" g st

let test_fold_after_flip_parity () =
  (* spec §4.7: a fold after flip inverts the letter relative to the front *)
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let ax1 = { Geom.a = q 1; b = q 0; c = half } in
  let ax2 = { Geom.a = q 0; b = q 1; c = half } in
  let g = vfold_new (Fold_graph.flip (vfold_new Fold_graph.init_square ax1)) ax2 in
  let st = vfold_old (Fold_state.flip (vfold_old Fold_state.init_square ax1)) ax2 in
  check_parity "fold after flip" g st;
  check_assign_parity "fold after flip" g st

let test_add_mark () =
  let m =
    { Fold_graph.mgeom = Fold_graph.MSeg (gp 0 0, gp 1 1);
      mline = { Geom.a = q 1; b = q (-1); c = q 0 };
      mintent = Fold_graph.V; mcrease_id = 9; mprov = None }
  in
  let g = Fold_graph.add_mark Fold_graph.init_square m in
  Alcotest.(check int) "one mark" 1 (Array.length (Fold_graph.marks g));
  (* marks ride through a fold *)
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g' = Fold_graph.fold g ~axis:ax ~move_side:1 ~valley:true ~prov:None in
  Alcotest.(check int) "mark carried" 1 (Array.length (Fold_graph.marks g'))
```

Register the three tests.

- [ ] **Step 2: Run to verify failure**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune build`
Expected: unbound `Fold_graph.flip` / `Fold_graph.add_mark`.

- [ ] **Step 3: Implement**

```ocaml
(* Turn the whole sheet over: reflect across the footprint's vertical
   centerline (cosmetic internal axis, as in the old model), reverse the face
   array (D9 — emit order), reverse the stack. base absorbs the reflection —
   the ONE whole-sheet motion. *)
let flip (g : t) : t =
  let n = Array.length g.faces in
  if n = 0 then g
  else begin
    let p0 = (table_polygon g 0).(0) in
    let lo = ref p0.Geom.x and hi = ref p0.Geom.x in
    for i = 0 to n - 1 do
      Array.iter
        (fun (q0 : Geom.point) ->
          if Num.compare q0.Geom.x !lo < 0 then lo := q0.Geom.x;
          if Num.compare q0.Geom.x !hi > 0 then hi := q0.Geom.x)
        (table_polygon g i)
    done;
    let cx = Num.div (Num.add !lo !hi) (Num.of_int 2) in
    let axis = { Geom.a = Num.one; b = Num.zero; c = cx } in
    let faces' = Array.init n (fun k -> g.faces.(n - 1 - k)) in
    let hinges' =
      Array.map
        (fun h -> { h with fa = n - 1 - h.fa; fb = n - 1 - h.fb })
        g.hinges
    in
    let rank' = Array.init n (fun k -> n - 1 - g.rank.(n - 1 - k)) in
    let root' = n - 1 - g.root in
    let base' = I3.compose (half_turn3_of_line axis) g.isos.(g.root) in
    match
      make ~base:base' ~marks:g.marks ~faces:faces' ~hinges:hinges'
        ~root:root' ~rank:rank'
    with
    | Ok g' -> g'
    | Error v -> fail_of_violation None v
  end

(* Marks carry no invariants; append without re-validation. *)
let add_mark (g : t) (m : mark) : t =
  { g with marks = Array.append g.marks [| m |] }
```

Mirror both in the `.mli`.

- [ ] **Step 4: Run tests**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_graph.ml lib/fold_graph.mli tests/test_fold_graph.ml
git commit -m "feat(foldgraph): flip via base reflection + add_mark"
```

---

### Task 6: cross-op parity battery

**Files:**
- Test: `tests/test_fold_graph.ml`

**Interfaces:**
- Consumes: everything from Tasks 1–5 plus the old `Fold_state` API.
- Produces: a replay harness later plans reuse when porting consumers.

- [ ] **Step 1: Write the battery** (these should PASS immediately if Tasks 3–5 are right; any failure is a real finding)

```ocaml
(* --- Plan 3a Task 6: cross-op parity battery ------------------------------- *)

type op =
  | OSub of Geom.line
  | OSubPaper of Geom.line
  | OFoldV of Geom.line * int
  | OFoldM of Geom.line * int
  | OFlip

let replay ops =
  Fold_graph.reset_ids (); Fold_state.reset_ids ();
  List.fold_left
    (fun (g, st) op ->
      match op with
      | OSub l ->
          (Fold_graph.subdivide g l ~prov:None,
           Fold_state.subdivide st l ~prov:None)
      | OSubPaper l ->
          (Fold_graph.subdivide_paper g l ~prov:None,
           Fold_state.subdivide_paper st l ~prov:None)
      | OFoldV (l, s) ->
          (Fold_graph.fold g ~axis:l ~move_side:s ~valley:true ~prov:None,
           Fold_state.fold_with_records st ~axis:l ~move_side:s ~valley:true
             ~prov:None)
      | OFoldM (l, s) ->
          (Fold_graph.fold g ~axis:l ~move_side:s ~valley:false ~prov:None,
           Fold_state.fold_with_records st ~axis:l ~move_side:s ~valley:false
             ~prov:None)
      | OFlip -> (Fold_graph.flip g, Fold_state.flip st))
    (Fold_graph.init_square, Fold_state.init_square)
    ops

let check_replay label ops =
  let g, st = replay ops in
  check_parity label g st;
  check_assign_parity label g st

let frac a b = Num.div (Num.of_int a) (Num.of_int b)
let vl c = { Geom.a = Num.one; b = Num.zero; c }
let hl c = { Geom.a = Num.zero; b = Num.one; c }

let test_battery () =
  (* book fold + cross fold *)
  check_replay "book+cross" [ OFoldV (vl (frac 1 2), 1); OFoldV (hl (frac 1 2), 1) ];
  (* mountain pleat, three panels *)
  check_replay "pleat3"
    [ OFoldV (vl (frac 2 3), 1); OFoldM (vl (frac 1 3), 1) ];
  (* precrease both directions, then fold one of them *)
  check_replay "precrease then fold"
    [ OSub (vl (frac 1 2)); OSub (hl (frac 1 2)); OFoldV (vl (frac 1 2), 1) ];
  (* flip sandwich: fold, flip, fold, flip *)
  check_replay "flip sandwich"
    [ OFoldV (vl (frac 1 2), 1); OFlip; OFoldV (hl (frac 1 2), 1); OFlip ];
  (* paper-space mark graduation path: subdivide_paper on a folded state *)
  check_replay "subdivide_paper folded"
    [ OFoldV (vl (frac 1 2), 1); OSubPaper (hl (frac 1 4)) ];
  (* diagonal on a folded packet *)
  check_replay "diag on packet"
    [ OFoldV (vl (frac 1 2), 1); OFoldV ({ Geom.a = Num.one; b = Num.one; c = frac 1 2 }, 1) ]
```

Register `test_battery`.

- [ ] **Step 2: Run**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`
Expected: PASS. If a case fails, STOP and report the diff (face order / rank / assign) — that is a design finding to review, not something to patch around.

- [ ] **Step 3: Full suite + ledger**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune test`
Expected: everything green except the two documented pre-existing failures.

Update `.superpowers/sdd/progress.md`: Plan 3a complete, commits, notable deviations.

- [ ] **Step 4: Commit**

```bash
git add tests/test_fold_graph.ml .superpowers/sdd/progress.md
git commit -m "test(foldgraph): cross-op old-vs-new parity battery"
```

---

## After this plan (context, not tasks)

- **Plan 3b — selector/helper surface + Collapse on the new core.** Port the pure query helpers eval uses (`crease_segments`, `crease_axis`, `crease_paper_axis`, `all_crease_ids`, `edge_boundary_segments`, `coplanar_clusters`, `cluster_of_points`/`flap_of_points`, `line_material_segments`, `line_cuts_paper`, `select_scope`, `scoped_fold_hinge_closed`, `mark_axis_current`/`mark_chords`/`mark_face`/`mark_rep_point`, `classify_mark_extent` + `mark_class`, `point_on_polygon_boundary`, `neighbors`, `edge_between`-equivalent) onto `Fold_graph.t`, and rewrite `Collapse` (sector fan → hinges with angle 1; `linear_extensions` feeds candidate ranks through `make`; the in-bounds anchor choice becomes the `base` choice).
- **Plan 3c — port consumers, delete, rename.** Port `eval.ml` (~140 sites), `fold_emit.ml` (mv/intent/prov + `face_iso2` matrix + `rel` faceOrders), tests; delete `fold_state.ml`/`layer_order.ml` + the parity tests' old halves; rename `Fold_graph` → `Fold_state`; goldens must be byte-identical (flip emit order preserved by D9).
