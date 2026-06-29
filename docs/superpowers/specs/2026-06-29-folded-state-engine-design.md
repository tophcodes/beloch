# Beloch — Folded-State Engine for Flat Folds (Design, Plan B)

- **Date:** 2026-06-29
- **Status:** Design — approved in brainstorming, pending implementation plan
- **Parent:** `docs/superpowers/specs/2026-06-29-action-model-folding-design.md` (the action-model pivot). This document designs the **algorithms** for that pivot's Plan B (the folded-state runtime); Plan A — the syntax — shipped in PR #7.
- **ADR:** `decisions/0011-action-model.md`

## 1. Scope

Execute the `@` fold modifier for **simple flat folds** (±180°) only, and emit the dual FOLD output (`creasePattern` + `foldedForm`). This is the first slice that actually folds paper.

**In:**
- A simple flat fold: reflect *all layers on one side* of a straight fold line, and restack.
- The folded-state runtime: faces + per-face 2D isometry + a global layer order.
- Material-point reference resolution against the current (folded) configuration.
- Dual FOLD output with derived mountain/valley.

**Out (deferred, hooks reserved):**
- Non-flat / constructible-angle folds; `flip` / `rotate`; `unfold`; named maneuvers.
- Layer selection / insert-between / a self-intersection validity check (simple folds are valid by construction).
- Re-projecting a named crease through later folds; using a folded (kinked) crease as an operand.
- FOLD `F` (creased-but-flat) assignment for unfolded precreases — they stay `U`.

## 2. Key insight — flat folds stay 2D + layers

A flat fold (±180°) is a reflection, whose axis is a **straight line**; you cannot flat-fold along a curve. So at every step the whole sheet lies in the table plane and the only "third dimension" is **stacking order**. Plan B therefore needs no 3D solver: the state is 2D isometries + an integer layer order. ("Exact 3D / constructible angles" is a later slice; the 2D→3D generalization is localized to the isometry type.)

### The "kink" — two representations of a crease

A straight table-space fold axis maps back to the *unfolded* paper through a **different isometry per layer**, so on the flat sheet one physical fold appears as a straight segment **per face**, joining at earlier creases — a polyline with kinks. This is correct origami (fold a folded stack, unfold, the crease bends at prior creases). It forces a clean split:

- **Fold axis** — the straight table-space line. This is what a `--name:` binding captures and what serves as an **operand** (`perp --l`, `cross`, `map … onto --l`). Always a single straight line → unambiguous.
- **Emitted crease** — the piecewise per-face projection onto the paper. Lives **only** in the `creasePattern` output, emitted as one edge per cut face; planarization already works in edges, so kinks fall out naturally.

Using a folded (kinked) crease *as an operand* is not expressible in Plan B (operands are straight table axes), so the ill-defined case never arises.

## 3. Data model

```
Isometry : { m00,m01,m10,m11 : Num ; tx,ty : Num }   (* 2x2 orthogonal, det ±1, + translation *)
  compose : Isometry -> Isometry -> Isometry
  apply_point : Isometry -> point -> point
  apply_line  : Isometry -> line -> line
  reflect_across_line : line -> Isometry            (* I − 2·n·nᵀ/(n·n), n=(a,b); no sqrt, exact *)
  det_sign : Isometry -> int                         (* orientation: +1 front, −1 back *)

Face  : { paper : point array (* CCW convex polygon, material identity *) ; iso : Isometry }
State : { faces : Face list ; layers : int list (* face indices, bottom→top *) ;
          precreases : (* unfolded fold axes, table-space, for CP output *) line list }
```

Faces stay **convex**: the square is convex, straight creases split convex polygons into convex parts, and reflection preserves convexity → exact half-plane clipping suffices (no general polygon machinery).

Reflection across `a·x + b·y = c` with `n=(a,b)`:
`reflect(p) = p − 2·((a·pₓ + b·p_y − c)/(a²+b²))·(a,b)` — all `Num`, no `sqrt`, so it stays in the constructible field even when the axis is an axiom-5 bisector (whose coefficients contain `sqrt`).

## 4. Reference resolution (current-state)

A material point is a **paper coordinate**. Its current table position = the isometry of the **face containing that paper coordinate** applied to it. The paper is partitioned into faces (every paper point lies in exactly one face), so the position is well-defined even though many faces stack at the same table location. Corners `.a`–`.d` are the paper coords `(0,0),(1,0),(1,1),(0,1)`.

Axioms compute in **table coordinates** against current positions: `map .a onto .b` → perpendicular bisector of the *current* table positions of a and b; `perp`, `through`, `cross` likewise. A `--name:` binding captures the resulting straight table-space line (a snapshot; not re-projected after later folds — a documented Plan B limitation).

## 5. Fold algorithm — `@map … [moving .p] [mountain]`

1. **Axis** L = the straight table-space fold line from the axiom on current positions.
2. **Moving half-plane** H = the side of L containing the current table position of the moving point (`moving .p`; defaulted to the moved point for `map .a onto .b`).
3. **Per face f** (every layer):
   - Classify f against H by exact `Num` sign tests on its vertices: entirely outside H (stays), entirely inside (moves whole), or crossing.
   - Crossing → exact half-plane clip into `f_stay` (outside H) and `f_move` (inside H).
   - `f_move.iso ← compose (reflect_across_line L) f_move.iso`.
4. **Restack** (global total order): take the moving faces in current bottom→top order, **reverse** them, and place them **above** all stationary faces (valley) or **below** all stationary faces (mountain); renumber the layer list. (Justification: a uniform simple fold of a connected flap forces moved layers to wrap in reverse over/under the stationary stack — interpenetration-free and globally unambiguous.)
5. **Validity:** none needed — a simple fold (all layers on one side) is realizable by construction; the validity-check slot is reserved for the later layer-selection slice.

Errors: `moving` is required for line-construction axioms (`@map --l1 onto --l2`, `@perp`, `@through`) which have no natural moving side; `@map .a onto .b` defaults the moving side to the flap containing `.a`. A `moving .p` whose current position lies *on* L (no side) is an error.

## 6. Output — dual FOLD

- **`creasePattern`** (frame 0, the key frame so dumb consumers see a sensible flat pattern): subdivide each face's paper polygon by the precrease axes that cross it (mapped into the face's paper coords) and by the fold creases on its boundary; planarize the union into one simple planar graph. Internal shared edges = creases — **derived M/V** for folded edges, `U` for unfolded precreases; the four square-boundary edges = `B`. Kinks are represented as the per-face segments meeting at earlier creases.
- **`foldedForm`** (a `file_frames` entry, `frame_parent`/`frame_inherit` from frame 0 so it shares topology and overrides only coordinates): each face's paper polygon mapped through its isometry into table coords; `vertices_coords` carry `z = 0` (a display-only ε per layer is the renderer's job, not baked here); `faceOrders` derived from the global total order, emitted only for face pairs whose table footprints overlap.
- **Derived M/V**: a crease's assignment follows the direction of the fold that created it (valley/mountain) combined with the orientation parity (`det_sign` of the adjacent face's isometry — front vs back as seen from +z). `edges_foldAngle` sign matches (`refs/foldformat.md`).
- Action provenance (the fold that made each crease, the moving flap, the direction) rides in the existing `beloch:` custom namespace.

## 7. Reuse vs new

- **Reuse:** `Geom.intersection`, `signed_area`, `ccw_compare`, `clip_to_unit_square`, `point_equal`; `Faces.extract` (half-edge traversal) to derive the CP planar graph from edges; `State` vertex dedup; `Num` throughout.
- **New:** `Geom.reflect_point` + a convex-polygon half-plane clip; an `Isometry` module; a folded-state `Fold_state` module (faces + layers); the fold evaluator that consumes `Ast.fold_spec` (currently rejected by `eval` with "not yet implemented"); the dual-frame emitter extension in `Fold_emit`.

## 8. Testing

Exact coordinates make assertions crisp (no float tolerance):

- Half a square (`@map .a onto .b moving .a` along x=1/2): 2 faces, 2 layers, `.a` lands exactly on `.b`; folded footprint is the half-square; `faceOrders` puts the moved face on top (valley).
- Mountain variant: moved face goes underneath.
- Diagonal fold (`@map .a onto .c`): exact reflected coordinates; one crease edge along the diagonal.
- Double fold (quarter): 4 layers in the exact reverse-stacked order; verify the full `faceOrders` set.
- Through-layers kink: fold once, precrease across the folded stack, unfold (conceptually via the CP output) → the CP crease is piecewise with a kink at the first crease.
- `reflect_across_line` unit tests: involution (`reflect∘reflect = id`), preserves the axis pointwise, `det_sign = −1`.
- Error cases: `moving` required for line-axiom folds; `moving .p` on the axis.
- Regression: all precrease-only programs (no `@`) emit byte-identical `creasePattern` output to today.

## 9. Open follow-ups (later slices)

Non-flat constructible angles (the isometry generalizes to 3D); `flip`/`rotate`; `unfold`; layer selection + insert-between + validity check → reverse/squash/sink/petal as sugar; re-projecting named creases through folds; the bespoke style-controllable animation/rendering client.
