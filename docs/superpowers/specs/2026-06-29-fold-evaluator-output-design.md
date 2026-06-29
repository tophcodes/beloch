# Beloch — Fold Evaluator & Dual Output (Design, Plan B-2)

- **Date:** 2026-06-29
- **Status:** Design — approved in brainstorming, pending implementation plan
- **Parent:** `docs/superpowers/specs/2026-06-29-folded-state-engine-design.md` (the folded-state engine). Plan B-1 — the pure geometric foundations (`Geom.reflect_point`/`side_of_line`/`clip_convex_halfplane`/`in_convex_polygon`, `Isometry`, `Fold_state` with `simple_fold`) — shipped in PR #8. This document designs B-2: wiring those into the evaluator and emitting the dual FOLD output.
- **ADR:** `decisions/0011-action-model.md`

## 1. Scope

Make `@` folds actually fold: thread a `Fold_state` through evaluation, execute simple flat folds, and emit both FOLD frames (`creasePattern` + `foldedForm`) with **derived mountain/valley**. This is the first slice that produces a real folded artifact a simulator can render.

**In:**
- One unified evaluation path through `Fold_state` (decision **C**): every program — folded or not — produces its output from the face set.
- `@` fold execution (simple flat fold) and bare-axiom precrease subdivision.
- Reference resolution against the current state, with the single-face rule for derived points (decision **Q2-A**).
- Dual FOLD output, both frames derived from the faces.
- Derived mountain/valley per crease edge (the accordion effect handled).

**Out (deferred):**
- `flip` / `rotate`; `unfold`; named maneuvers; non-flat / constructible-angle folds.
- The "topmost layer" reference semantics for points in overlapping regions (Q2-A errors instead).
- Re-projecting a named crease through later folds; folded (kinked) creases as operands.

## 2. Decisions locked in brainstorming

- **C — unified face-based pipeline.** The old crease-line `Planarize`/`Faces.extract` path is dropped from the emit path; the CP is built directly from the `Fold_state` faces. Existing regression tests are re-baselined to the new (geometrically equivalent) output.
- **Q2-A — single-face rule.** Corners, named precrease axes, and `cross`/derived points resolve against the current state; a derived point whose table location lies under more than one overlapping layer is a compile error ("ambiguous reference in a folded region"). Pre-fold `cross` works (one layer); post-fold `cross` works only in non-overlapping regions.
- **M/V in B-2** (not deferred), via a per-crease-edge parity rule (§5).

## 3. Evaluation pipeline (unified, decision C)

The evaluator threads a `Fold_state` (start `init_square`) and a name environment, in statement order:

- **Bare axiom** (precrease): compute the straight table-space axis from the axiom on current positions; **subdivide** the face set along it (split every crossing face into two faces, both keeping their isometry — no reflection, no restack). A `--name:` binds the table-space axis line. The crease edges this creates are unfolded → assignment `U`.
- **`@` axiom** (fold): compute the axis and the moving side; **fold** — split, reflect the moving side, restack (the `simple_fold` mechanism from B-1, extended per §5 to also return the crease records with derived M/V).
- **Point binding** (`cross`): intersect two table-space axis lines → a table point; resolve to a material paper coordinate via the *single* face containing it (error if zero or >1 distinct containing layers — Q2-A). Corners `.a`–`.d` are the fixed paper coordinates.
- **Reference resolution:** a point name → its stored paper coordinate → `Fold_state.table_position` (current). `moving .p` → `Geom.side_of_line axis (table_position p)`; error if `0` (on the axis). `moving` is required for the line-construction folds (`@map --l onto --m`, `@perp`, `@through`); for `@map .a onto .b` it defaults to the side of `.a`.

`subdivide` is new in B-2 (B-1 only has `simple_fold`); it is the no-reflect, no-restack split that precreases use to register crease edges for the CP.

## 4. Output — both frames from the face set

The planar graph is built directly from the `Fold_state` faces (no `Planarize`/`Faces.extract` on this path): every face is already one CP face. Build it once:

- Deduplicate all face-polygon vertices (paper coords) → a vertex index list.
- `faces_vertices` = each face's polygon as vertex indices (CCW).
- Edges = the deduplicated set of consecutive vertex pairs across all face polygons. An edge on the unit-square boundary is `B`; otherwise it is a crease.
- The faces tile the square and each crease line cuts every face along its full chord (no T-junctions), so shared crease segments coincide exactly and dedup is clean.

Then:

- **`creasePattern`** (frame 0, key frame): `vertices_coords` = paper coords; `edges_assignment` = `B` / derived M/V (§5) / `U` for unfolded precreases; `faces_vertices`; `beloch:edges` provenance as today.
- **`foldedForm`** (a `file_frames` entry with `frame_parent: 0`, `frame_inherit: true`): `vertices_coords` = table coords (each face's paper polygon through its isometry), `z = 0` (display-ε per layer is the renderer's job); `faceOrders` from the global layer total order, emitted only for face pairs whose table footprints overlap (a new exact convex-overlap predicate in `Geom`); inherits `edges_*`/`faces_vertices` from frame 0.

## 5. Derived mountain/valley (per crease edge)

M/V is a property of each crease **edge**, set when the fold that creates it runs. When `simple_fold` cuts a face `F` (current orientation `Isometry.det_sign F.iso`) along the axis, the resulting crease edge (the clipped axis segment, in `F`'s paper coordinates, shared by the stay and move halves) gets:

```
assignment = if (valley XOR (det_sign F < 0)) then Valley else Mountain
```

- valley command + `F` front-up (`det +1`) → Valley; + back-up (`det −1`) → Mountain. A mountain command flips both.

**The accordion effect falls out for free:** stacked layers have alternating `det_sign` (each reflection flips it), so a single fold through a stack produces crease edges with alternating M/V across the layers — correct origami. Within one face the crease is one straight edge with one M/V; the "different M/V sections along one line" are the distinct per-face edges, which the per-edge model represents directly.

**Data-model addition:** B-1's `simple_fold` returns only the new state. B-2 extends/wraps it so a fold also returns the **crease records** it created — `(paper-coordinate segment, assignment)` per cut face. These accumulate across all folds; at emit, a CP edge matching an accumulated crease record takes its M/V; precrease-subdivision edges are `U`; boundary edges are `B`. `edges_foldAngle` in the `foldedForm` frame follows the sign of M/V (`refs/foldformat.md`).

## 6. Module responsibilities

- **`Fold_state`** (extend): add `subdivide : t -> Geom.line -> t` (split faces, no move); change/​wrap the fold to return `t * crease_record list` where `crease_record = { seg : Geom.point * Geom.point; assign }`. Track accumulated crease records (either in `t` or threaded by the evaluator).
- **`Geom`** (extend): `convex_overlap : point array -> point array -> bool` (exact predicate for `faceOrders`).
- **`Eval`** (refactor): thread `Fold_state` + name env; resolve references against current state; execute precrease/fold/point statements; produce a result the emitter consumes (faces + crease assignments + layer order), not the old `crease list`.
- **`Fold_emit`** (refactor): build the planar graph from the face set; emit both frames; `file_creator` version bump.
- **`Planarize` / `Faces`**: no longer on the emit path. Keep the modules if other code references them, but the `beloch.ml` `fold_string` pipeline routes through the new path.
- **`beloch.ml`** (`fold_string`): rewire to `parse → eval (→ folded result) → emit`.

## 7. Errors (new)

- `moving` required for a line-construction `@` fold.
- `moving .p` resolves onto the fold axis (no side).
- `cross`/derived point in an overlapping (multi-layer) region (Q2-A).

## 8. Testing

- **Regression re-baseline:** every existing precrease-only example/e2e produces a geometrically equivalent CP through the unified path; update the exact vertex/edge/face-count and snapshot assertions to the new output and confirm by inspection they are equivalent (same faces, same creases).
- Half fold (`@map .a onto .b moving .a`): `foldedForm` has 2 faces, 2-layer `faceOrders`; the crease is one `V` edge; `.b` coincides with `.a` in table coords.
- Mountain variant: the crease is `M`.
- Quarter fold (two folds): 4 layers in the exact reverse-stacked order; the second fold's creases show the **alternating M/V** across the two layers (accordion); `faceOrders` for the overlapping pairs is correct.
- `cross` ambiguity: a `cross` resolving in a folded overlap region errors; the same `cross` before folding succeeds.
- `moving` errors: missing on a line fold; on-axis `moving .p`.
- Dual-frame structure: `frame_classes`, `file_frames`, `frame_inherit`, `faceOrders` present and well-formed.
- **B-1 carryover:** a direct two-distinct-reflections `Isometry.inverse` test; an on-line-vertex `clip_convex_halfplane` test; the quarter-fold integration above is the depth-2 coverage that exercises CW-table-polygon clipping.

## 9. Follow-ups (later slices)

`flip` / `rotate`; `unfold` + layer selection + validity check → maneuvers as sugar; non-flat constructible angles; the topmost-layer reference semantics; the bespoke style-controllable animation client; unifying/removing the now-unused crease-line `Planarize` path.
