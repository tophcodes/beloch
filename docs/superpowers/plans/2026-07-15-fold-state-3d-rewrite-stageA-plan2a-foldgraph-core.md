# Fold_graph core + derived face placements — Implementation Plan (Stage A / Plan 2a)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The new 3D-native folded-state core `Fold_graph`: faces + hinges (the face-adjacency graph), with each face's 3D placement **derived** (a reflection/half-turn path product from a root face over `Isometry3`), not stored — so a "torn" state is unrepresentable.

**Architecture:** `Fold_graph` coexists with the old `Fold_state` during the port (a later plan renames it to `Fold_state` once the old is deleted). Flat-first: hinge dihedral angles are `Num.t` in units of π, restricted to `{0, ±1}` for now; `|angle| = 1` folds via `Isometry3.half_turn_about_line` (= the 2D reflection on z=0), `0` is a flat crease. General `rπ` angles are Stage B and untouched here.

**Tech Stack:** OCaml, `Num.t` exact, `Isometry3` (from Plan 1), `Geom.line`, Alcotest. Build/test: `direnv exec /home/toph/Projects/beloch-rewrite dune build|exec`.

## Global Constraints
- **Exact-only** `Num.t`; no floats.
- **`Fold_graph` is self-contained + GREEN** — no consumers yet; it does not touch the old `Fold_state`.
- Placements are **derived**, never stored per-face — the whole point (tears unrepresentable).
- Branch `feat/fold-state-invariants` (worktree `/home/toph/Projects/beloch-rewrite`); verify before committing. Commit `feat(foldgraph): …`.
- Mirror the re-export pattern: add `module Fold_graph = Fold_graph` to `lib/beloch.ml`.

## File structure
| File | Responsibility |
|---|---|
| `lib/fold_graph.ml` (new) | `face`, `hinge`, `t`; `hinge_motion`; `face_isos`/`face_iso` (derived placements) |
| `tests/test_fold_graph.ml` (new) | derivation tests: single fold + accordion (multi-hinge path) |
| `tests/dune` | add `test_fold_graph` stanza |
| `lib/beloch.ml` | add `module Fold_graph = Fold_graph` |

---

## Task 1: Fold_graph types + derived face placements

**Files:** Create `lib/fold_graph.ml`, `tests/test_fold_graph.ml`; modify `tests/dune`, `lib/beloch.ml`.

**Interfaces — Produces:**
- `type face = Geom.point array` (2D paper polygon, sheet coords)
- `type hinge = { fa : int; fb : int; line : Geom.line; angle : Num.t }` (angle = dihedral/π; flat-first `{0, ±1}`)
- `type t = { faces : face array; hinges : hinge array; root : int }`
- `hinge_motion : hinge -> Isometry3.t`
- `face_isos : t -> Isometry3.t array` (index i = derived 3D placement of face i)
- `face_iso : t -> int -> Isometry3.t`

- [ ] **Step 1: Write the failing tests** (`tests/test_fold_graph.ml`)

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

(* SINGLE FOLD: square split at x=1 into face0=[0,1]×[0,1], face1=[1,2]×[0,1];
   one hinge at x=1, folded (angle=1). root=0. face1's placement = reflect across
   x=1, so a face1 point (2,y) lands at (0,y). *)
let test_single_fold () =
  let g = {
    Fold_graph.root = 0;
    faces = [| sq (gp 0 0) (gp 1 0) (gp 1 1) (gp 0 1);
               sq (gp 1 0) (gp 2 0) (gp 2 1) (gp 1 1) |];
    hinges = [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 } |];
  } in
  let isos = Fold_graph.face_isos g in
  Alcotest.(check bool) "root at identity" true
    (i3eq (Isometry3.apply_point isos.(0) (p3 3 5 0)) (p3 3 5 0));
  Alcotest.(check bool) "face1 reflects across x=1" true
    (i3eq (Isometry3.apply_point isos.(1) (p3 2 0 0)) (p3 0 0 0))

(* ACCORDION: strip [0,1],[1,2],[2,3]; hinges at x=1 and x=2, both folded.
   root=0. A face2 point (2.5,y) → half_turn x=2 → (1.5,y) → half_turn x=1 →
   (0.5,y). Proves the multi-hinge PATH product. *)
let test_accordion () =
  let g = {
    Fold_graph.root = 0;
    faces = [| sq (gp 0 0) (gp 1 0) (gp 1 1) (gp 0 1);
               sq (gp 1 0) (gp 2 0) (gp 2 1) (gp 1 1);
               sq (gp 2 0) (gp 3 0) (gp 3 1) (gp 2 1) |];
    hinges = [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 };
                { Fold_graph.fa = 1; fb = 2; line = vline 2; angle = q 1 } |];
  } in
  let isos = Fold_graph.face_isos g in
  let half = Num.of_q (Q.of_ints 1 2) in
  Alcotest.(check bool) "face2 folds back to x=1/2" true
    (i3eq (Isometry3.apply_point isos.(2)
             { Isometry3.x = Num.of_q (Q.of_ints 5 2); y = half; z = q 0 })
          { Isometry3.x = half; y = half; z = q 0 })

let () =
  Alcotest.run "fold_graph"
    [ ("derive",
       [ Alcotest.test_case "single fold" `Quick test_single_fold;
         Alcotest.test_case "accordion path" `Quick test_accordion ]) ]
```

- [ ] **Step 2: Run, verify it fails** — `direnv exec /home/toph/Projects/beloch-rewrite dune build tests/test_fold_graph.exe 2>&1 | head`. Expected: `Unbound module Fold_graph`.

- [ ] **Step 3: Implement `lib/fold_graph.ml`**

```ocaml
(** The 3D-native folded-state core (issue #48, spec 2026-07-15-fold-state-3d-
    rewrite). Faces = 2D paper polygons; hinges = the face-adjacency graph. A
    face's 3D placement is DERIVED as the product of hinge motions along a path
    from the root — so adjacent faces differ by exactly their hinge's motion and
    a torn state cannot be written down. Flat-first: hinge angle (dihedral/π) ∈
    {0, ±1}; |angle|=1 folds via a half-turn about the crease line (= the 2D
    reflection on z=0), reproducing today's flat folds. General rπ is Stage B. *)

module I3 = Isometry3

type face = Geom.point array

type hinge = { fa : int; fb : int; line : Geom.line; angle : Num.t }

type t = { faces : face array; hinges : hinge array; root : int }

(* 3D motion a folded hinge applies (in the sheet frame): a half-turn about the
   crease line embedded in the z=0 plane. Flat crease (angle=0) → identity.
   Flat-first: |angle|=1 → half-turn; the sign (M vs V) does NOT change the flat
   placement (±π about the same axis coincide) — M/V is the layer order. *)
let hinge_motion (h : hinge) : I3.t =
  if Num.sign h.angle = 0 then I3.identity
  else
    let l = h.line in
    let on =
      if Num.sign l.Geom.a <> 0 then
        { I3.x = Num.div l.Geom.c l.Geom.a; y = Num.zero; z = Num.zero }
      else { I3.x = Num.zero; y = Num.div l.Geom.c l.Geom.b; z = Num.zero }
    in
    let dir = { I3.x = Num.neg l.Geom.b; y = l.Geom.a; z = Num.zero } in
    I3.half_turn_about_line ~on ~dir

(* Derived placements: BFS from [root] over the hinge graph; crossing a hinge
   composes its motion onto the already-placed face's placement,
   iso.(other) = compose iso.(fi) (hinge_motion h). half-turns are involutions,
   so crossing a hinge either direction uses the same motion (flat-first). *)
let face_isos (g : t) : I3.t array =
  let n = Array.length g.faces in
  let iso = Array.make n I3.identity in
  let seen = Array.make n false in
  let queue = Queue.create () in
  seen.(g.root) <- true;
  Queue.push g.root queue;
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
      g.hinges
  done;
  iso

let face_iso (g : t) (i : int) : I3.t = (face_isos g).(i)
```

Add to `tests/dune`:
```
(test
 (name test_fold_graph)
 (libraries beloch alcotest zarith))
```
Add to `lib/beloch.ml` (next to the other `module X = X` re-exports): `module Fold_graph = Fold_graph`.

- [ ] **Step 4: Run, verify pass** — `direnv exec /home/toph/Projects/beloch-rewrite dune exec tests/test_fold_graph.exe`. Expected: `Test Successful` (2 cases). `dune build` clean.

- [ ] **Step 5: Commit** — `git add lib/fold_graph.ml tests/test_fold_graph.ml tests/dune lib/beloch.ml && git commit -m "feat(foldgraph): hinge-graph core + derived face placements (flat-first)"`

---

## Self-review
- **Spec coverage:** delivers the hinge-graph core with *derived* placements (spec model A, flat-first via `Isometry3.half_turn`); coexists with old `Fold_state` (green, no consumers). Rank order + smart constructor + derived MV are Plan 2b/2c; hinge-graph *construction* from a crease pattern is Plan 3. ✓
- **Placeholder scan:** none — complete OCaml. ✓
- **Type consistency:** `face`/`hinge`/`t` fields (`fa/fb/line/angle`, `faces/hinges/root`) used identically in tests and impl; `face_isos`/`hinge_motion` signatures match. ✓
- **Derived, not stored:** placements come only from `face_isos` (BFS path product); there is no per-face stored isometry. ✓

## Next plans (after this lands)
- **Plan 2b — rank order + smart constructor `make`:** `rank : int array` in `t`; `above`/`below` derived; `make : … -> (t, violation) result` running taco-taco/taco-tortilla (over the flat projection) + a half-plane/consistency assertion + angle-domain check ({0,±1}); abstract `t` in `fold_graph.mli`.
- **Plan 2c — derived MV + invariant tests:** `mv : t -> crease_id -> mv` (from placements + rank); full invariant tests (rabbit ear, waterbomb) constructed as hinge graphs, asserting closure + parity with today's flat coordinates.
- **Plan 3 — construction + port + delete:** build the hinge graph from a crease pattern (replacing `subdivide`/`fold_with_records`); rewrite `Collapse`; port `eval`/`flatten`/`fold_emit`/render/tests (~159 sites); delete old `Fold_state`, `Layer_order` table, MV upgrade passes; rename `Fold_graph` → `Fold_state`.
