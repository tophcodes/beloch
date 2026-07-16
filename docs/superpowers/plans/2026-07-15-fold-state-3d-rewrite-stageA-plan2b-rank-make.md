# Fold_graph rank order + smart constructor — Implementation Plan (Stage A / Plan 2b)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** `Fold_graph.t` becomes abstract, gains a **rank permutation** (the layer order), and can only be built through `make`, which enforces every state invariant: structure, flat-first angle domain, hinge adjacency (half-plane + shared edge), **cycle closure** (tears along non-tree hinges), and the Justin/Hull non-crossing conditions (taco-tortilla, taco-taco) over the flat projection.

**Architecture:** `t` stays a record internally but is hidden behind `fold_graph.mli`; placements are derived once in `make` (memoized BFS) and cached in the abstract value, so nothing can desync them. Rank replaces the old `Layer_order` relation table — a permutation cannot cycle and decides every pair, so stacking cycles and tortilla-tortilla "undecided overlap" are *unrepresentable*; only the two residual non-crossing conditions need checking [hull2020 §6.5; hullzakharevich2023 §2.1]. The exact 2D predicates move from the old `Fold_state` into `Geom` for reuse (old module dies in Plan 3 anyway). The stored angle **sign** is not interpreted flat-first (±π give the same placement; M/V will be derived from rank in Plan 2c — no stored M/V, per spec).

**Tech Stack:** OCaml, `Num.t` exact, `Isometry3`, `Geom`, Alcotest. Build/test: `direnv exec /home/toph/Projects/beloch-rewrite dune build|exec`.

## Global Constraints

- **Exact-only** `Num.t`; no floats anywhere.
- **`Fold_graph` stays self-contained + GREEN** — still no consumers; the old `Fold_state` is only touched by the mechanical predicate move (Task 1), nothing else.
- Placements **derived in `make`, cached in abstract `t`** — never settable from outside.
- Angle domain flat-first: `{0, ±1}` (units of π). Sign accepted but not interpreted (Stage B gives it meaning).
- Branch `feat/fold-state-invariants` (worktree `/home/toph/Projects/beloch-rewrite`); **verify branch with `git branch --show-current` before every commit**. Subagents: `cd /home/toph/Projects/beloch-rewrite` first — they start in the main checkout.
- Faces are convex, CCW, in sheet coordinates (same contract as today's `Fold_state`); not re-validated by `make`.

## File structure

| File | Responsibility |
|---|---|
| `lib/geom.ml` | gains `segment_crosses_interior`, `segments_overlap_collinear` (moved verbatim from `fold_state.ml`) |
| `lib/fold_state.ml` | loses the two predicates; call sites switch to `Geom.*` (no behaviour change) |
| `lib/isometry3.ml` | gains `equal` |
| `lib/fold_graph.ml` | `rank` + cached `isos` in `t`; `violation`; `make` with all checks; accessors |
| `lib/fold_graph.mli` (new) | abstract `t`; the full public surface |
| `tests/test_isometry3.ml` | `equal` tests |
| `tests/test_fold_graph.ml` | rewritten against `make`; rejection + closure + taco tests |

Interface reference (final `fold_graph.mli` surface, declared in full in Task 3):

```ocaml
type face = Geom.point array
type hinge = { fa : int; fb : int; line : Geom.line; angle : Num.t }
type t                                   (* abstract *)
type violation =
  | Bad_index of string | Bad_rank | Bad_angle of int | Disconnected of int
  | Hinge_not_shared of int | Hinge_not_closed of int
  | Taco_tortilla of { tortilla : int; hinge : int } | Taco_taco of int * int
val violation_to_string : violation -> string
val make : faces:face array -> hinges:hinge array -> root:int ->
           rank:int array -> (t, violation) result
val faces : t -> face array   val hinges : t -> hinge array
val root : t -> int           val rank : t -> int array
val above : t -> int -> int -> bool
val hinge_motion : hinge -> Isometry3.t
val face_isos : t -> Isometry3.t array
val face_iso : t -> int -> Isometry3.t
```

`rank.(i)` = stacking height of face `i`, **higher = above**, a permutation of `0..n-1`.

---

## Task 1: Move the exact segment predicates into Geom

**Files:**
- Modify: `lib/geom.ml` (append after `convex_overlap`, ~line 344)
- Modify: `lib/fold_state.ml:95-162` (delete the two functions), `lib/fold_state.ml:183` and `:212` (qualify call sites)

**Interfaces — Produces:** `Geom.segment_crosses_interior : point * point -> point array -> bool`, `Geom.segments_overlap_collinear : point * point -> point * point -> bool` (exact semantics unchanged).

This is a pure move (refactor): the existing `test_fold_state` taco suite is the safety net; no new tests.

- [ ] **Step 1: Append to `lib/geom.ml`** (directly after `convex_overlap`; note the `Geom.` prefixes and `.Geom.x` field paths from `fold_state.ml` are dropped — this code lives inside `Geom` now):

```ocaml
(* Does segment [pa]-[pb] pass through the *interior* of convex CCW [poly]? True
   iff the portion of the segment inside [poly] has positive length and its
   midpoint is strictly interior — a segment lying along a boundary edge (a crease
   bordering the face, i.e. a taco-taco situation) is excluded. Exact throughout:
   clip the parameter t∈[0,1] to every interior half-plane, then sign-test the
   midpoint. *)
let segment_crosses_interior ((pa, pb) : point * point) (poly : point array) :
    bool =
  if point_equal pa pb then false
  else begin
    let dx = Num.sub pb.x pa.x and dy = Num.sub pb.y pa.y in
    let n = Array.length poly in
    let lo = ref Num.zero and hi = ref Num.one and empty = ref false in
    for i = 0 to n - 1 do
      let e1 = poly.(i) and e2 = poly.((i + 1) mod n) in
      let ex = Num.sub e2.x e1.x and ey = Num.sub e2.y e1.y in
      (* interior of a CCW polygon is left of each edge: cross(e1→e2, p−e1) ≥ 0.
         Along the segment this is affine in t: f(t) = f0 + t·fd. *)
      let f0 =
        Num.sub (Num.mul ex (Num.sub pa.y e1.y)) (Num.mul ey (Num.sub pa.x e1.x))
      in
      let fd = Num.sub (Num.mul ex dy) (Num.mul ey dx) in
      match Num.sign fd with
      | 0 -> if Num.sign f0 < 0 then empty := true
      | s ->
          let t = Num.div (Num.neg f0) fd in
          if s > 0 then (if Num.compare t !lo > 0 then lo := t)
          else if Num.compare t !hi < 0 then hi := t
    done;
    if !empty || Num.compare !lo !hi >= 0 then false
    else begin
      let tm = Num.div (Num.add !lo !hi) (Num.of_int 2) in
      let m =
        { x = Num.add pa.x (Num.mul tm dx); y = Num.add pa.y (Num.mul tm dy) }
      in
      let strict = ref true in
      for i = 0 to n - 1 do
        let a = poly.(i) and b = poly.((i + 1) mod n) in
        let cross =
          Num.sub
            (Num.mul (Num.sub b.x a.x) (Num.sub m.y a.y))
            (Num.mul (Num.sub b.y a.y) (Num.sub m.x a.x))
        in
        if Num.sign cross <= 0 then strict := false
      done;
      !strict
    end
  end

(* Do two segments coincide over a sub-segment of positive length (i.e. the
   two creases strictly overlap under the folding map)? Collinear + overlapping
   parameter ranges. *)
let segments_overlap_collinear ((p1, q1) : point * point)
    ((p2, q2) : point * point) : bool =
  if point_equal p1 q1 || point_equal p2 q2 then false
  else
    let l = line_through p1 q1 in
    if side_of_line l p2 <> 0 || side_of_line l q2 <> 0 then false
    else
      let ta = seg_param (p1, q1) p2 and tb = seg_param (p1, q1) q2 in
      let tlo = if Num.compare ta tb <= 0 then ta else tb in
      let thi = if Num.compare ta tb <= 0 then tb else ta in
      let olo = if Num.compare tlo Num.zero > 0 then tlo else Num.zero in
      let ohi = if Num.compare thi Num.one < 0 then thi else Num.one in
      Num.compare olo ohi < 0
```

Ordering constraint: `signed_area`… not needed; but `line_through`, `side_of_line`, `seg_param`, `point_equal` must already be defined above the insertion point — they are (all < line 323).

- [ ] **Step 2: Delete from `lib/fold_state.ml`** the two definitions (`segment_crosses_interior`, lines 95–145, and `segments_overlap_collinear`, lines 147–162, including their doc comments), and qualify the two call sites:
  - line ~183: `segment_crosses_interior seg (table_polygon_ccw st c)` → `Geom.segment_crosses_interior seg (table_polygon_ccw st c)`
  - line ~212: `segments_overlap_collinear (edge_table_segment st e1) (edge_table_segment st e2)` → `Geom.segments_overlap_collinear (edge_table_segment st e1) (edge_table_segment st e2)`

- [ ] **Step 3: Build + run the safety net**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune build && direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_state.exe -- test taco-checks && direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_geom.exe`
Expected: build clean; all taco-check cases pass; geom tests pass.

- [ ] **Step 4: Full test suite** — `direnv exec /home/toph/Projects/beloch-rewrite dune test`. Expected: green.

- [ ] **Step 5: Commit**

```bash
git branch --show-current   # must print feat/fold-state-invariants
git add lib/geom.ml lib/fold_state.ml
git commit -m "refactor(geom): move exact segment predicates out of Fold_state"
```

---

## Task 2: Isometry3.equal

**Files:**
- Modify: `lib/isometry3.ml` (append)
- Test: `tests/test_isometry3.ml` (append test + register)

**Interfaces — Produces:** `Isometry3.equal : t -> t -> bool` (component-wise exact equality; used by the Task 5 closure check).

- [ ] **Step 1: Write the failing test** — append to `tests/test_isometry3.ml` (reuse the file's existing helpers for building isometries; it already constructs `half_turn_about_line` values — follow its local conventions for points):

```ocaml
let test_equal () =
  let axis_on = { Isometry3.x = Num.of_int 1; y = Num.zero; z = Num.zero } in
  let axis_dir = { Isometry3.x = Num.zero; y = Num.of_int 1; z = Num.zero } in
  let h = Isometry3.half_turn_about_line ~on:axis_on ~dir:axis_dir in
  Alcotest.(check bool) "identity = identity" true
    (Isometry3.equal Isometry3.identity Isometry3.identity);
  Alcotest.(check bool) "half-turn <> identity" false
    (Isometry3.equal h Isometry3.identity);
  Alcotest.(check bool) "involution: h∘h = identity" true
    (Isometry3.equal (Isometry3.compose h h) Isometry3.identity);
  Alcotest.(check bool) "inverse round-trip via equal" true
    (Isometry3.equal (Isometry3.compose h (Isometry3.inverse h)) Isometry3.identity)
```

Register in the file's run list: `Alcotest.test_case "equal" `Quick test_equal;`

- [ ] **Step 2: Run, verify it fails** — `direnv exec /home/toph/Projects/beloch-rewrite dune build tests/test_isometry3.exe 2>&1 | head`. Expected: `Unbound value Isometry3.equal`.

- [ ] **Step 3: Implement** — append to `lib/isometry3.ml`:

```ocaml
let equal (a : t) (b : t) : bool =
  Num.equal a.m00 b.m00 && Num.equal a.m01 b.m01 && Num.equal a.m02 b.m02
  && Num.equal a.m10 b.m10 && Num.equal a.m11 b.m11 && Num.equal a.m12 b.m12
  && Num.equal a.m20 b.m20 && Num.equal a.m21 b.m21 && Num.equal a.m22 b.m22
  && Num.equal a.tx b.tx && Num.equal a.ty b.ty && Num.equal a.tz b.tz
```

- [ ] **Step 4: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_isometry3.exe`. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git branch --show-current   # must print feat/fold-state-invariants
git add lib/isometry3.ml tests/test_isometry3.ml
git commit -m "feat(iso3): exact component-wise equality"
```

---

## Task 3: Abstract t, rank, memoized placements, structural checks

**Files:**
- Create: `lib/fold_graph.mli`
- Modify: `lib/fold_graph.ml` (restructure)
- Modify: `tests/test_fold_graph.ml` (rewrite constructions against `make`)

**Interfaces — Produces:** everything in the `.mli` (see File structure section). After this task `make` enforces `Bad_index` / `Bad_rank` / `Bad_angle` / `Disconnected`; the remaining `violation` constructors are declared (checks land in Tasks 4–6).

**Interfaces — Consumes:** `Isometry3.equal` not yet; `Geom` predicates not yet.

- [ ] **Step 1: Write the failing tests** — rewrite `tests/test_fold_graph.ml` in full:

```ocaml
open Beloch

let q = Num.of_int
let gp x y : Geom.point = { Geom.x = q x; y = q y }
let sq a b c d : Fold_graph.face = [| a; b; c; d |]

let i3eq (a : Isometry3.point) (b : Isometry3.point) =
  Num.equal a.Isometry3.x b.Isometry3.x
  && Num.equal a.Isometry3.y b.Isometry3.y
  && Num.equal a.Isometry3.z b.Isometry3.z

let p3 x y z : Isometry3.point = { Isometry3.x = q x; y = q y; z = q z }

(* line x = k : a=1,b=0,c=k *)
let vline k : Geom.line = { Geom.a = q 1; b = q 0; c = q k }
(* line y = k : a=0,b=1,c=k *)
let hline k : Geom.line = { Geom.a = q 0; b = q 1; c = q k }

let mk ?(root = 0) ~faces ~hinges ~rank () =
  match Fold_graph.make ~faces ~hinges ~root ~rank with
  | Ok g -> g
  | Error v -> Alcotest.failf "expected Ok, got: %s" (Fold_graph.violation_to_string v)

let expect_error label pred ~faces ~hinges ~root ~rank =
  match Fold_graph.make ~faces ~hinges ~root ~rank with
  | Ok _ -> Alcotest.fail (label ^ ": expected a violation, got Ok")
  | Error v ->
      Alcotest.(check bool)
        (label ^ ": " ^ Fold_graph.violation_to_string v)
        true (pred v)

(* strip of unit squares [k,k+1]x[0,1] *)
let strip_face k w = sq (gp k 0) (gp (k + w) 0) (gp (k + w) 1) (gp k 1)

(* SINGLE FOLD: square split at x=1; face1 folded across x=1 onto face0. *)
let single_fold_faces () = [| strip_face 0 1; strip_face 1 1 |]
let single_fold_hinges () =
  [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 } |]

let test_single_fold () =
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 0; 1 |] ()
  in
  let isos = Fold_graph.face_isos g in
  Alcotest.(check bool) "root at identity" true
    (i3eq (Isometry3.apply_point isos.(0) (p3 3 5 0)) (p3 3 5 0));
  Alcotest.(check bool) "face1 reflects across x=1" true
    (i3eq (Isometry3.apply_point isos.(1) (p3 2 0 0)) (p3 0 0 0));
  Alcotest.(check bool) "face1 above face0" true (Fold_graph.above g 1 0);
  Alcotest.(check bool) "face0 not above face1" false (Fold_graph.above g 0 1)

(* ACCORDION: strip [0,1],[1,2],[2,3]; hinges at x=1 and x=2, both folded. *)
let test_accordion () =
  let faces = [| strip_face 0 1; strip_face 1 1; strip_face 2 1 |] in
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 };
       { Fold_graph.fa = 1; fb = 2; line = vline 2; angle = q 1 } |]
  in
  let g = mk ~faces ~hinges ~rank:[| 0; 1; 2 |] () in
  let isos = Fold_graph.face_isos g in
  let half = Num.of_q (Q.of_ints 1 2) in
  Alcotest.(check bool) "face2 folds back to x=1/2" true
    (i3eq
       (Isometry3.apply_point isos.(2)
          { Isometry3.x = Num.of_q (Q.of_ints 5 2); y = half; z = q 0 })
       { Isometry3.x = half; y = half; z = q 0 })

let test_rejects_bad_angle () =
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = Num.of_q (Q.of_ints 1 2) } |]
  in
  expect_error "angle 1/2 outside flat-first domain"
    (function Fold_graph.Bad_angle 0 -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_bad_rank () =
  expect_error "duplicate rank"
    (function Fold_graph.Bad_rank -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:0 ~rank:[| 0; 0 |];
  expect_error "rank length mismatch"
    (function Fold_graph.Bad_rank -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:0 ~rank:[| 0 |]

let test_rejects_bad_index () =
  expect_error "hinge face out of range"
    (function Fold_graph.Bad_index _ -> true | _ -> false)
    ~faces:(single_fold_faces ())
    ~hinges:[| { Fold_graph.fa = 0; fb = 5; line = vline 1; angle = q 1 } |]
    ~root:0 ~rank:[| 0; 1 |];
  expect_error "root out of range"
    (function Fold_graph.Bad_index _ -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:7 ~rank:[| 0; 1 |]

let test_rejects_disconnected () =
  expect_error "two faces, no hinges"
    (function Fold_graph.Disconnected _ -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:[||] ~root:0 ~rank:[| 0; 1 |]

let () =
  Alcotest.run "fold_graph"
    [ ( "derive",
        [ Alcotest.test_case "single fold" `Quick test_single_fold;
          Alcotest.test_case "accordion path" `Quick test_accordion ] );
      ( "make-structure",
        [ Alcotest.test_case "bad angle" `Quick test_rejects_bad_angle;
          Alcotest.test_case "bad rank" `Quick test_rejects_bad_rank;
          Alcotest.test_case "bad index" `Quick test_rejects_bad_index;
          Alcotest.test_case "disconnected" `Quick test_rejects_disconnected ] ) ]
```

(`hline` is unused until Task 5 — OCaml does not warn on unused top-level `let`s in executables, it stays.)

- [ ] **Step 2: Run, verify it fails** — `direnv exec /home/toph/Projects/beloch-rewrite dune build tests/test_fold_graph.exe 2>&1 | head -20`. Expected: `Unbound value Fold_graph.make` (and friends).

- [ ] **Step 3: Create `lib/fold_graph.mli`:**

```ocaml
(** The 3D-native folded-state core (issue #48, spec
    2026-07-15-fold-state-3d-rewrite). [t] is abstract: a folded state exists
    only via [make], which enforces the state invariants — so a value of type
    [t] IS a legal folded state. Flat-first: hinge angles (dihedral/π) are
    restricted to {0, ±1}; general rπ is Stage B. *)

type face = Geom.point array
(** 2D paper polygon, sheet coordinates; convex, CCW (same contract as the
    construction kernel — not re-validated here). *)

type hinge = { fa : int; fb : int; line : Geom.line; angle : Num.t }
(** Crease between adjacent faces [fa] and [fb]. [angle] = dihedral/π. The
    sign does not affect a flat placement (±π half-turns coincide); M/V is
    derived from the rank (Plan 2c), never stored. *)

type t

type violation =
  | Bad_index of string
      (** root or a hinge's face index out of range, or fa = fb *)
  | Bad_rank  (** rank is not a permutation of 0..n-1 *)
  | Bad_angle of int  (** hinge i: angle outside {0, ±1} (flat-first) *)
  | Disconnected of int  (** face i unreachable from the root via hinges *)
  | Hinge_not_shared of int
      (** hinge i: its line is not a positive-length shared boundary edge
          between faces lying in opposite half-planes *)
  | Hinge_not_closed of int
      (** hinge i (a cycle edge): the derived placements contradict its
          motion — folding would tear the sheet *)
  | Taco_tortilla of { tortilla : int; hinge : int }
      (** face [tortilla] is stacked inside folded hinge [hinge]'s taco but
          crosses its crease [hullzakharevich2023 §2.1] *)
  | Taco_taco of int * int
      (** hinges i and j: creases coincide on the table and their face pairs
          interleave in the stack [hullzakharevich2023 §2.1] *)

val violation_to_string : violation -> string

val make :
  faces:face array ->
  hinges:hinge array ->
  root:int ->
  rank:int array ->
  (t, violation) result
(** The only constructor. [rank].(i) is face i's stacking height (higher =
    above), a permutation of 0..n-1. Checks in order: structure (indices,
    rank, angle domain), connectivity, hinge adjacency (half-plane + shared
    edge), cycle closure, then the non-crossing conditions (taco-tortilla,
    taco-taco) over the flat projection. Input arrays are copied. *)

val faces : t -> face array
val hinges : t -> hinge array
val root : t -> int

val rank : t -> int array
(** Accessors return copies; [t] cannot be mutated from outside. *)

val above : t -> int -> int -> bool
(** [above g i j]: face i stacked strictly above face j (rank comparison —
    meaningful for faces that overlap in the flat projection). *)

val hinge_motion : hinge -> Isometry3.t
(** The 3D motion a hinge applies in the sheet frame: identity when flat,
    else a half-turn about its crease line embedded in z=0. *)

val face_isos : t -> Isometry3.t array
(** Derived 3D placements (index = face), memoized at construction. *)

val face_iso : t -> int -> Isometry3.t
```

- [ ] **Step 4: Restructure `lib/fold_graph.ml`:**

Keep the module doc comment and `hinge_motion` as they are. Replace `type t`, `face_isos`, and `face_iso`; add the rest:

```ocaml
type t = {
  faces : face array;
  hinges : hinge array;
  root : int;
  rank : int array;  (* stacking height per face, higher = above; permutation *)
  isos : Isometry3.t array;  (* derived in [make] (memoized BFS); [t] abstract ⇒ cannot desync *)
}

type violation =
  | Bad_index of string
  | Bad_rank
  | Bad_angle of int
  | Disconnected of int
  | Hinge_not_shared of int
  | Hinge_not_closed of int
  | Taco_tortilla of { tortilla : int; hinge : int }
  | Taco_taco of int * int

let violation_to_string = function
  | Bad_index s -> "fold graph: index out of range: " ^ s
  | Bad_rank -> "fold graph: rank is not a permutation of the faces"
  | Bad_angle i ->
      Printf.sprintf "fold graph: hinge %d angle outside {0, ±1} (flat-first)" i
  | Disconnected i ->
      Printf.sprintf "fold graph: face %d is not connected to the root" i
  | Hinge_not_shared i ->
      Printf.sprintf
        "fold graph: hinge %d's line is not a shared edge of its two faces" i
  | Hinge_not_closed i ->
      Printf.sprintf "fold graph: hinge %d does not close — the sheet would tear"
        i
  | Taco_tortilla { tortilla; hinge } ->
      Printf.sprintf
        "layer ordering: face %d would pass through the crease of hinge %d — \
         taco-tortilla violation" tortilla hinge
  | Taco_taco (i, j) ->
      Printf.sprintf
        "layer ordering: creases of hinges %d and %d cross — taco-taco violation"
        i j

(* Derived placements: BFS from [root] over the hinge graph; crossing a hinge
   composes its motion onto the already-placed face's placement,
   iso.(other) = compose iso.(fi) (hinge_motion h). Half-turns are involutions,
   so crossing a hinge either direction uses the same motion (flat-first).
   [seen] doubles as the connectivity witness. *)
let derive_isos ~(faces : face array) ~(hinges : hinge array) ~(root : int) :
    I3.t array * bool array =
  let n = Array.length faces in
  let iso = Array.make n I3.identity in
  let seen = Array.make n false in
  let queue = Queue.create () in
  seen.(root) <- true;
  Queue.push root queue;
  while not (Queue.is_empty queue) do
    let fi = Queue.pop queue in
    Array.iter
      (fun h ->
        let step other =
          if not seen.(other) then begin
            seen.(other) <- true;
            iso.(other) <- I3.compose iso.(fi) (hinge_motion h);
            Queue.push other queue
          end
        in
        if h.fa = fi then step h.fb else if h.fb = fi then step h.fa)
      hinges
  done;
  (iso, seen)

exception V of violation

let check_structure ~(faces : face array) ~(hinges : hinge array) ~(root : int)
    ~(rank : int array) : unit =
  let n = Array.length faces in
  if root < 0 || root >= n then
    raise (V (Bad_index (Printf.sprintf "root %d" root)));
  Array.iteri
    (fun i (h : hinge) ->
      if h.fa < 0 || h.fa >= n || h.fb < 0 || h.fb >= n || h.fa = h.fb then
        raise (V (Bad_index (Printf.sprintf "hinge %d (%d|%d)" i h.fa h.fb)));
      if
        not
          (Num.equal h.angle Num.zero || Num.equal h.angle Num.one
          || Num.equal h.angle (Num.neg Num.one))
      then raise (V (Bad_angle i)))
    hinges;
  if Array.length rank <> n then raise (V Bad_rank);
  let hit = Array.make n false in
  Array.iter
    (fun r ->
      if r < 0 || r >= n || hit.(r) then raise (V Bad_rank) else hit.(r) <- true)
    rank

let make ~(faces : face array) ~(hinges : hinge array) ~(root : int)
    ~(rank : int array) : (t, violation) result =
  try
    check_structure ~faces ~hinges ~root ~rank;
    let isos, seen = derive_isos ~faces ~hinges ~root in
    Array.iteri (fun i s -> if not s then raise (V (Disconnected i))) seen;
    Ok
      {
        faces = Array.copy faces;
        hinges = Array.copy hinges;
        root;
        rank = Array.copy rank;
        isos;
      }
  with V v -> Error v

let faces (g : t) : face array = Array.copy g.faces
let hinges (g : t) : hinge array = Array.copy g.hinges
let root (g : t) : int = g.root
let rank (g : t) : int array = Array.copy g.rank
let above (g : t) (i : int) (j : int) : bool = g.rank.(i) > g.rank.(j)
let face_isos (g : t) : I3.t array = Array.copy g.isos
let face_iso (g : t) (i : int) : I3.t = g.isos.(i)
```

- [ ] **Step 5: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`. Expected: all pass. Then `direnv exec /home/toph/Projects/beloch-rewrite dune build` clean (the `.mli` must match).

- [ ] **Step 6: Commit**

```bash
git branch --show-current   # must print feat/fold-state-invariants
git add lib/fold_graph.ml lib/fold_graph.mli tests/test_fold_graph.ml
git commit -m "feat(foldgraph): abstract t, rank order, smart constructor (structural checks)"
```

---

## Task 4: Hinge adjacency — half-plane + shared-edge check

**Files:**
- Modify: `lib/fold_graph.ml`, `tests/test_fold_graph.ml`

**Interfaces — Produces:** `make` now rejects `Hinge_not_shared`; internal `hinge_shared_segment : face array -> hinge -> (Geom.point * Geom.point) option` (paper-space crease segment, reused by Task 6).

- [ ] **Step 1: Write the failing tests** — append to `tests/test_fold_graph.ml` and register a new `"make-adjacency"` suite in the run list:

```ocaml
let test_rejects_hinge_line_not_between () =
  (* line x=1/2 cuts face0 instead of separating the faces *)
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1;
         line = { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 1 2) };
         angle = q 1 } |]
  in
  expect_error "line cuts a face"
    (function Fold_graph.Hinge_not_shared 0 -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_gap () =
  (* faces [0,1]² and [2,3]²: opposite sides of x=3/2, but no shared edge *)
  let faces = [| strip_face 0 1; strip_face 2 1 |] in
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1;
         line = { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 3 2) };
         angle = q 1 } |]
  in
  expect_error "faces do not touch the line"
    (function Fold_graph.Hinge_not_shared 0 -> true | _ -> false)
    ~faces ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_vertex_touch () =
  (* [0,1]² and [1,2]×[1,2] share only the corner (1,1) on line x=1 *)
  let faces =
    [| strip_face 0 1; sq (gp 1 1) (gp 2 1) (gp 2 2) (gp 1 2) |]
  in
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 } |]
  in
  expect_error "zero-length shared boundary"
    (function Fold_graph.Hinge_not_shared 0 -> true | _ -> false)
    ~faces ~hinges ~root:0 ~rank:[| 0; 1 |]
```

Register:

```ocaml
      ( "make-adjacency",
        [ Alcotest.test_case "line cuts a face" `Quick
            test_rejects_hinge_line_not_between;
          Alcotest.test_case "gap between faces" `Quick test_rejects_hinge_gap;
          Alcotest.test_case "vertex touch only" `Quick
            test_rejects_hinge_vertex_touch ] );
```

- [ ] **Step 2: Run, verify it fails** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe 2>&1 | tail -20`. Expected: the three new cases FAIL ("expected a violation, got Ok"); old cases pass.

- [ ] **Step 3: Implement** — in `lib/fold_graph.ml`, add above `exception V`:

```ocaml
(* Parameter of an on-line point along [l]'s direction (-b, a); monotone along
   the line — used to order and intersect on-line vertex intervals. *)
let line_param (l : Geom.line) (p : Geom.point) : Num.t =
  Num.sub (Num.mul l.Geom.a p.Geom.y) (Num.mul l.Geom.b p.Geom.x)

(* The positive-length sub-segment of [h.line] shared by the boundaries of
   [h.fa] and [h.fb], provided the two faces lie in opposite closed half-planes
   — i.e. [h] really hinges adjacent faces. Paper space. None otherwise. *)
let hinge_shared_segment (faces : face array) (h : hinge) :
    (Geom.point * Geom.point) option =
  let fa = faces.(h.fa) and fb = faces.(h.fb) in
  let sides f = Array.map (fun p -> Geom.side_of_line h.line p) f in
  let sa = sides fa and sb = sides fb in
  let all_ge s = Array.for_all (fun x -> x >= 0) s
  and all_le s = Array.for_all (fun x -> x <= 0) s in
  if not ((all_ge sa && all_le sb) || (all_le sa && all_ge sb)) then None
  else
    (* a convex face meets the line in at most one boundary edge: the interval
       of its on-line vertices, ordered by [line_param] *)
    let interval f =
      let on =
        Array.to_list f
        |> List.filter (fun p -> Geom.side_of_line h.line p = 0)
        |> List.map (fun p -> (line_param h.line p, p))
      in
      match on with
      | [] | [ _ ] -> None
      | tp :: tps ->
          let lo =
            List.fold_left
              (fun a b -> if Num.compare (fst b) (fst a) < 0 then b else a)
              tp tps
          in
          let hi =
            List.fold_left
              (fun a b -> if Num.compare (fst b) (fst a) > 0 then b else a)
              tp tps
          in
          if Num.compare (fst lo) (fst hi) < 0 then Some (lo, hi) else None
    in
    match (interval fa, interval fb) with
    | Some (la, ha), Some (lb, hb) ->
        let lo = if Num.compare (fst la) (fst lb) >= 0 then la else lb in
        let hi = if Num.compare (fst ha) (fst hb) <= 0 then ha else hb in
        if Num.compare (fst lo) (fst hi) < 0 then Some (snd lo, snd hi)
        else None
    | _ -> None
```

And in `make`, after the `Disconnected` check, before `Ok { … }`:

```ocaml
    (* hinge adjacency: each hinge's line must carry a positive-length shared
       boundary segment between its faces (paper space); the segments feed the
       non-crossing checks (Task 6) *)
    let (_ : (Geom.point * Geom.point) array) =
      Array.mapi
        (fun i h ->
          match hinge_shared_segment faces h with
          | Some s -> s
          | None -> raise (V (Hinge_not_shared i)))
        hinges
    in
```

- [ ] **Step 4: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`. Expected: all pass (old positives prove real hinges still construct).

- [ ] **Step 5: Commit**

```bash
git branch --show-current   # must print feat/fold-state-invariants
git add lib/fold_graph.ml tests/test_fold_graph.ml
git commit -m "feat(foldgraph): hinge adjacency check — half-plane + shared edge"
```

---

## Task 5: Cycle closure check — tears along non-tree hinges

**Files:**
- Modify: `lib/fold_graph.ml`, `tests/test_fold_graph.ml`

**Interfaces — Produces:** `make` now rejects `Hinge_not_closed`.
**Interfaces — Consumes:** `Isometry3.equal` (Task 2).

Background for the implementer: `derive_isos`'s BFS fixes a spanning tree; tree hinges satisfy `iso(fb) = iso(fa) ∘ motion` by construction. A hinge *closing a cycle* (e.g. the fourth crease around an interior vertex) got no say in the placements — if the equation fails for it, the two faces it hinges are placed incompatibly: folding would tear the sheet there. This is exactly the failure the old model could not even express structurally (issue #48). Flat-first motions are involutions, so the equation is direction-symmetric and can be checked for every hinge uniformly.

- [ ] **Step 1: Write the failing tests** — append + register suite `"make-closure"`:

```ocaml
(* Quadrants of [0,2]²: f0=[0,1]², f1=[1,2]×[0,1], f2=[1,2]×[1,2], f3=[0,1]×[1,2].
   Hinges form a 4-cycle around the interior vertex (1,1). *)
let quadrant_faces () =
  [| sq (gp 0 0) (gp 1 0) (gp 1 1) (gp 0 1);
     sq (gp 1 0) (gp 2 0) (gp 2 1) (gp 1 1);
     sq (gp 1 1) (gp 2 1) (gp 2 2) (gp 1 2);
     sq (gp 0 1) (gp 1 1) (gp 1 2) (gp 0 2) |]

let quadrant_hinges ~last_angle =
  [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 };
     { Fold_graph.fa = 1; fb = 2; line = hline 1; angle = q 1 };
     { Fold_graph.fa = 2; fb = 3; line = vline 1; angle = q 1 };
     { Fold_graph.fa = 3; fb = 0; line = hline 1; angle = last_angle } |]

let test_cycle_closes_fold_in_quarters () =
  (* all four creases folded: reflections compose to identity around the
     vertex — the classic fold-in-quarters; rank = physical stacking *)
  let g =
    mk ~faces:(quadrant_faces ()) ~hinges:(quadrant_hinges ~last_angle:(q 1))
      ~rank:[| 0; 1; 2; 3 |] ()
  in
  let isos = Fold_graph.face_isos g in
  Alcotest.(check bool) "far corner (2,2) lands on (0,0)" true
    (i3eq (Isometry3.apply_point isos.(2) (p3 2 2 0)) (p3 0 0 0))

let test_cycle_tear_rejected () =
  (* only 3 of the 4 creases at an interior vertex folded: the cycle cannot
     close — the sheet would tear along the remaining hinge *)
  expect_error "3-of-4 folded tears"
    (function Fold_graph.Hinge_not_closed _ -> true | _ -> false)
    ~faces:(quadrant_faces ())
    ~hinges:(quadrant_hinges ~last_angle:(q 0))
    ~root:0 ~rank:[| 0; 1; 2; 3 |]
```

Register:

```ocaml
      ( "make-closure",
        [ Alcotest.test_case "fold-in-quarters cycle closes" `Quick
            test_cycle_closes_fold_in_quarters;
          Alcotest.test_case "3-of-4 folded at a vertex tears" `Quick
            test_cycle_tear_rejected ] );
```

(The `Hinge_not_closed` index depends on BFS visit order — assert the constructor, not the index. These graphs also exercise the `fb = fi` BFS branch flagged as untested in Plan 2a's review.)

- [ ] **Step 2: Run, verify it fails** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe 2>&1 | tail -20`. Expected: "3-of-4 folded tears" FAILS (got Ok); the quarters case may already pass (it must construct Ok both before and after).

- [ ] **Step 3: Implement** — in `make`, directly after the hinge-adjacency block:

```ocaml
    (* cycle closure: the BFS fixed a spanning tree; every hinge must agree
       with the placements — for non-tree (cycle) hinges this is the real
       tear check. Tree hinges hold by construction; checking all is uniform
       (flat-first motions are involutions, so direction is irrelevant). *)
    Array.iteri
      (fun i h ->
        if
          not
            (I3.equal isos.(h.fb) (I3.compose isos.(h.fa) (hinge_motion h)))
        then raise (V (Hinge_not_closed i)))
      hinges;
```

- [ ] **Step 4: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git branch --show-current   # must print feat/fold-state-invariants
git add lib/fold_graph.ml tests/test_fold_graph.ml
git commit -m "feat(foldgraph): cycle-closure check — tears along non-tree hinges rejected"
```

---

## Task 6: Non-crossing checks — taco-tortilla + taco-taco over the flat projection

**Files:**
- Modify: `lib/fold_graph.ml`, `tests/test_fold_graph.ml`

**Interfaces — Produces:** `make` now rejects `Taco_tortilla` / `Taco_taco` — the full constructor per spec.
**Interfaces — Consumes:** `Geom.segment_crosses_interior`, `Geom.segments_overlap_collinear` (Task 1), `hinge_shared_segment` (Task 4).

Soundness note for the implementer (also goes in the code comment): rank orders *all* faces, including spatially-apart ones where comparison is physically meaningless. The checks stay sound because each one first establishes geometric coincidence — a face crossing a crease-segment's interior necessarily overlaps both taco faces near that segment (they carry interior on both sides along their shared edge after folding), and two collinear-overlapping crease segments make all four hinged faces share that neighbourhood. Only then are ranks compared. This replaces the old model's "relation defined only for overlapping pairs" precondition [hullzakharevich2023 §2.1].

- [ ] **Step 1: Write the failing tests** — append + register suite `"non-crossing"`:

```ocaml
(* Wide-middle accordion: f0=[0,2] (double width), f1=[2,3], f2=[3,4]; both
   hinges folded. Table: f0=[0,2], f1=[1,2], f2=[1,2]; hinge1's crease maps to
   table x=1 — which f0 straddles. Whether f0 crosses it depends on the rank. *)
let tortilla_faces () = [| strip_face 0 2; strip_face 2 1; strip_face 3 1 |]

let tortilla_hinges () =
  [| { Fold_graph.fa = 0; fb = 1; line = vline 2; angle = q 1 };
     { Fold_graph.fa = 1; fb = 2; line = vline 3; angle = q 1 } |]

let test_taco_tortilla_fires () =
  (* f0 stacked between the taco (f1|f2) whose crease it straddles *)
  expect_error "tortilla sandwiched in the taco"
    (function
      | Fold_graph.Taco_tortilla { tortilla = 0; hinge = 1 } -> true
      | _ -> false)
    ~faces:(tortilla_faces ()) ~hinges:(tortilla_hinges ())
    ~root:0 ~rank:[| 1; 0; 2 |]

let test_taco_tortilla_ok_outside () =
  (* f0 below the whole taco — legal *)
  let g =
    mk ~faces:(tortilla_faces ()) ~hinges:(tortilla_hinges ())
      ~rank:[| 0; 1; 2 |] ()
  in
  ignore g

let test_taco_tortilla_fires_reflected_root () =
  (* same geometry, root=1: f0 is now placed by a REFLECTION (CW table
     winding). The check must normalize winding or it is blind on most real
     folded states — regression for the CCW normalization. *)
  expect_error "reflected tortilla sandwiched in the taco"
    (function
      | Fold_graph.Taco_tortilla { tortilla = 0; hinge = 1 } -> true
      | _ -> false)
    ~faces:(tortilla_faces ()) ~hinges:(tortilla_hinges ())
    ~root:1 ~rank:[| 1; 0; 2 |]

(* Fold-in-quarters strip: f0..f3 = [k,k+1]×[0,1], hinges at x=1,2,3, all
   folded. All faces stack on [0,1]; hinge0's and hinge2's creases both map to
   table x=1 — a taco-taco configuration decided by the rank. *)
let quarters_faces () =
  [| strip_face 0 1; strip_face 1 1; strip_face 2 1; strip_face 3 1 |]

let quarters_hinges () =
  [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 };
     { Fold_graph.fa = 1; fb = 2; line = vline 2; angle = q 1 };
     { Fold_graph.fa = 2; fb = 3; line = vline 3; angle = q 1 } |]

let test_taco_taco_fires () =
  (* f2 inside taco (f0|f1), f3 outside: the pairs interleave — the paper
     would have to pass through itself at table x=1 *)
  expect_error "interleaved tacos"
    (function Fold_graph.Taco_taco (0, 2) -> true | _ -> false)
    ~faces:(quarters_faces ()) ~hinges:(quarters_hinges ())
    ~root:0 ~rank:[| 1; 3; 2; 0 |]

let test_taco_taco_ok_nested () =
  (* taco (f2|f3) nests entirely inside taco (f0|f1) — legal wrap *)
  let g =
    mk ~faces:(quarters_faces ()) ~hinges:(quarters_hinges ())
      ~rank:[| 0; 3; 2; 1 |] ()
  in
  ignore g

let test_taco_taco_ok_separated () =
  (* zigzag accordion: taco (f0|f1) entirely below taco (f2|f3) — legal *)
  let g =
    mk ~faces:(quarters_faces ()) ~hinges:(quarters_hinges ())
      ~rank:[| 0; 1; 2; 3 |] ()
  in
  ignore g
```

Register:

```ocaml
      ( "non-crossing",
        [ Alcotest.test_case "taco-tortilla fires when sandwiched" `Quick
            test_taco_tortilla_fires;
          Alcotest.test_case "taco-tortilla silent outside the taco" `Quick
            test_taco_tortilla_ok_outside;
          Alcotest.test_case "taco-tortilla fires on reflected (CW) tortilla"
            `Quick test_taco_tortilla_fires_reflected_root;
          Alcotest.test_case "taco-taco fires when pairs interleave" `Quick
            test_taco_taco_fires;
          Alcotest.test_case "taco-taco silent when nested" `Quick
            test_taco_taco_ok_nested;
          Alcotest.test_case "taco-taco silent when separated" `Quick
            test_taco_taco_ok_separated ] );
```

- [ ] **Step 2: Run, verify it fails** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe 2>&1 | tail -30`. Expected: the three "fires" cases FAIL (got Ok); the three "ok" cases pass already.

- [ ] **Step 3: Implement** — in `lib/fold_graph.ml`, add helpers above `exception V`:

```ocaml
let to3 (p : Geom.point) : I3.point = { I3.x = p.Geom.x; y = p.Geom.y; z = Num.zero }
let to2 (p : I3.point) : Geom.point = { Geom.x = p.I3.x; y = p.I3.y }

(* Flat projection of face [i] under its derived placement, normalized to CCW:
   a reflected placement reverses the winding, and
   [Geom.segment_crosses_interior] requires CCW input. *)
let table_polygon_ccw (faces : face array) (isos : I3.t array) (i : int) :
    Geom.point array =
  let tp = Array.map (fun p -> to2 (I3.apply_point isos.(i) (to3 p))) faces.(i) in
  if Num.sign (Geom.signed_area tp) < 0 then begin
    let n = Array.length tp in
    Array.init n (fun k -> tp.(n - 1 - k))
  end
  else tp

(* Is [c]'s rank strictly between [a]'s and [b]'s? *)
let rank_between (rank : int array) (a : int) (c : int) (b : int) : bool =
  (rank.(a) < rank.(c) && rank.(c) < rank.(b))
  || (rank.(b) < rank.(c) && rank.(c) < rank.(a))
```

In `make`: change the Task-4 binding `let (_ : (Geom.point * Geom.point) array) = …` to `let segs = …`, then after the closure check insert:

```ocaml
    (* Non-crossing [hull2020 §6.5; hullzakharevich2023 §2.1] over the flat
       projection. Rank decides every pair, so tortilla-tortilla and stacking
       cycles are unrepresentable; these two residual conditions remain. Rank
       comparison is sound here because each check first establishes geometric
       coincidence (interior crossing / collinear overlap), so the compared
       faces genuinely overlap where they are compared. *)
    let n = Array.length faces in
    let tseg i =
      let p, q = segs.(i) in
      let place = isos.(hinges.(i).fa) in
      (to2 (I3.apply_point place (to3 p)), to2 (I3.apply_point place (to3 q)))
    in
    (* taco-tortilla: a folded hinge's faces coincide after the fold (they
       share the crease edge and fold to the same side), forming a taco; no
       face ranked between them may cross the crease's interior *)
    Array.iteri
      (fun i h ->
        if Num.sign h.angle <> 0 then begin
          let seg = tseg i in
          for c = 0 to n - 1 do
            if
              c <> h.fa && c <> h.fb
              && rank_between rank h.fa c h.fb
              && Geom.segment_crosses_interior seg
                   (table_polygon_ccw faces isos c)
            then raise (V (Taco_tortilla { tortilla = c; hinge = i }))
          done
        end)
      hinges;
    (* taco-taco: two folded hinges over disjoint face pairs whose crease
       segments coincide on the table must not interleave in the stack *)
    let m = Array.length hinges in
    for i = 0 to m - 1 do
      for j = i + 1 to m - 1 do
        let h1 = hinges.(i) and h2 = hinges.(j) in
        let a = h1.fa and b = h1.fb and c = h2.fa and d = h2.fb in
        if
          Num.sign h1.angle <> 0 && Num.sign h2.angle <> 0
          && a <> c && a <> d && b <> c && b <> d
          && Geom.segments_overlap_collinear (tseg i) (tseg j)
          && rank_between rank a c b <> rank_between rank a d b
        then raise (V (Taco_taco (i, j)))
      done
    done;
```

(Unlike the old `Fold_state` check there is no `crease_id <> crease_id` guard: two hinges carrying the same crease have disjoint segments along the same line, and `segments_overlap_collinear` requires positive-length overlap, so they can never trip the check.)

- [ ] **Step 4: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`. Expected: all suites pass.

- [ ] **Step 5: Full suite + commit**

Run: `direnv exec /home/toph/Projects/beloch-rewrite dune test` — expected green (old `Fold_state` untouched since Task 1).

```bash
git branch --show-current   # must print feat/fold-state-invariants
git add lib/fold_graph.ml tests/test_fold_graph.ml
git commit -m "feat(foldgraph): non-crossing checks — taco-tortilla + taco-taco over flat projection"
```

---

## Self-review

- **Spec coverage:** rank permutation replaces the relation table (cycles + undecided overlaps unrepresentable) ✓; `make : … -> (t, violation) result` with non-crossing + half-plane/consistency + angle-domain checks ✓; abstract `t` via `.mli` ⇒ no unchecked states ✓; placements memoized at construction (spec's "memoized BFS") ✓; `above` derived from rank ✓. Cycle closure (`Hinge_not_closed`) is the consistency check the spec's tear-unrepresentability claim needs on non-tree hinges — BFS derivation covers only the spanning tree. Derived MV is Plan 2c; construction from crease patterns + consumer port is Plan 3.
- **Placeholder scan:** none — complete OCaml in every step. ✓
- **Type consistency:** `violation` constructors identical in `.mli` (Task 3) and `.ml`; `hinge_shared_segment` (Task 4) consumed by `tseg` (Task 6) with matching `(Geom.point * Geom.point) array`; `Isometry3.equal` (Task 2) used in Task 5; `Geom.segment_crosses_interior` / `segments_overlap_collinear` (Task 1) used in Task 6 with the moved signatures. `rank` convention (higher = above) consistent across `above`, `rank_between`, tests. ✓
- **Geometry hand-checks (done while planning):** quarters cycle closes (4 reflections about x=1,y=1 compose to identity); tortilla example: hinge 1's crease (paper x=3) maps through `iso f1` = reflect(x=2) to table x=1, which f0=[0,2] straddles; quarters taco-taco: hinge 2's crease (paper x=3) maps through `iso f2` = reflect(x=1)∘reflect(x=2) to table x=1, coinciding with hinge 0's. Rank `[|1;3;2;0|]` puts f2 (rank 2) inside taco (f0@1, f1@3) and f3 (rank 0) outside → interleave. ✓

## Next plans (after this lands)

- **Plan 2c — derived MV + invariant tests:** `mv : t -> hinge index (or crease id) -> mv` from placements + rank; rabbit-ear/waterbomb hinge-graph constructions asserting closure + parity with today's flat coordinates.
- **Plan 3 — construction + port + delete:** build the hinge graph from a crease pattern; rewrite `Collapse`; port consumers (~159 sites); delete old `Fold_state`/`Layer_order`; rename `Fold_graph` → `Fold_state`.
