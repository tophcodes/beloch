# 0015 — Flat folded states only (2D isometries); 3D is a goal, not a carried feature

## Status
Accepted (2026-07-03)

## Context
The action-model design doc
(`docs/superpowers/specs/2026-06-29-action-model-folding-design.md`) described the
runtime state as carrying a "per-face exact isometry into 3D" and asserted that
non-flat fold angles were "already carried" by that state. Neither is true of the
evaluator:

- `Isometry.t` is a strictly planar 2×2 orthogonal matrix + translation
  (`lib/isometry.ml` — its own docstring: "Exact 2D isometry … Used to place each
  face of the paper onto the table").
- `Geom.point` is 2D (`{ x; y }`, `lib/geom.ml`).
- The FOLD `foldedForm` emitter's vertex-dedup invariant self-documents that it
  holds *only* for flat folds and would break otherwise (`lib/fold_emit.ml`:
  "Partial or non-flat folds (a later slice) would break this — re-key per
  (face,vertex)").

So the current model produces **flat folded states**: every fold is a ±180°
reflection, the whole sheet stays in the table plane, and the only third dimension
is stacking order (`faceOrders`). This is the **all-layers simple-fold** model — the
most restricted class in the Demaine–O'Rourke simple-fold taxonomy (one-layer /
all-layers / some-layers) [demaine2007, §14.1.1].

Nothing in `decisions/` recorded this scope, and the design doc's "already carried"
phrasing invited building on a 3D guarantee that does not exist.

## Decision
Record flat-only as the **current, deliberate scope** of the evaluator: 2D
isometries, flat folded states, `faceOrders` for stacking.

3D folded states (non-flat dihedral angles) remain an **explicitly intended goal**,
not a rejected alternative. They are simply not expressible yet. Reaching them is a
type-level rework, not a switch to flip on the existing state:

- `Isometry.t` → 3D rigid motion (3×3 rotation + translation), with flat folds
  staying the reflection special case.
- `Geom.point` → 3D coordinates.
- Vertex identity → per-(face, vertex) coordinates, since a shared paper vertex no
  longer implies a shared table coordinate once faces leave the plane.

Until that rework lands, the honest statement is: **flat-only today, 3D is where
we're aiming** — the staging is fine, but the capability is not carried by the 2D
state.

## Alternatives considered
- **Claim 3D is already carried** (the status quo prose). Rejected: false, and it
  encourages downstream code to assume a 3D isometry that isn't there.
- **Drop 3D as a goal, commit to flat-only permanently.** Rejected: 3D folded output
  is explicitly wanted (animation, non-flat display angles, the own rendering
  engine). This ADR records a limitation, not a preference against 3D.

## Consequences
- The design doc is corrected to say flat-only / 2D isometries today, 3D as an
  intended follow-slice requiring the rework above.
- Any future non-flat slice must budget for the type-level changes; it cannot treat
  non-flat as a parameter on the existing state.
- For the paper: the current guarantee is the all-layers simple-fold model
  [demaine2007, §14.1.1], stated as such — no implied 3D generality.
