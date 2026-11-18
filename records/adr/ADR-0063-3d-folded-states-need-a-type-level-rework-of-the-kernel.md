---
id: ADR-0063
title: "3D folded states need a type-level rework of the kernel"
date: 2026-11-18
status: accepted
---

# ADR-0063: 3D folded states need a type-level rework of the kernel

This record holds the architecture part of [[BEP-0015]], which decided both kinds.

## Context

The action-model design doc described the runtime state as carrying a "per-face exact isometry into 3D" and asserted that
non-flat fold angles were "already carried" by that state. Neither is true of the
evaluator:

<!-- vale Prose.EmDash = NO -->

- `Isometry.t` is a strictly planar 2×2 orthogonal matrix + translation
  (`lib/isometry.ml`; its own docstring: "Exact 2D isometry … Used to place each
  face of the paper onto the table").
- `Geom.point` is 2D (`{ x; y }`, `lib/geom.ml`).
- The FOLD `foldedForm` emitter's vertex-dedup invariant self-documents that it
  holds *only* for flat folds and would break otherwise (`lib/fold_emit.ml`:
  "Partial or non-flat folds (a later slice) would break this — re-key per
  (face,vertex)").

<!-- vale Prose.EmDash = YES -->

## Decision

3D folded states (non-flat dihedral angles) remain an **explicitly intended goal**,
not a rejected alternative. They are not expressible yet. Reaching them is a
type-level rework, not a switch to flip on the existing state:

- `Isometry.t` → 3D rigid motion (3×3 rotation + translation), with flat folds
  staying the reflection special case.
- `Geom.point` → 3D coordinates.
- Vertex identity → per-(face, vertex) coordinates, since a shared paper vertex no
  longer implies a shared table coordinate once faces leave the plane.

## Alternatives considered

- **Claim 3D is already carried** (the status quo prose). Rejected: false, and it
  encourages downstream code to assume a 3D isometry that isn't there.

## Consequences

- The design doc is corrected to say flat-only / 2D isometries today, 3D as an
  intended follow-slice requiring the rework above.
- Any future non-flat slice must budget for the type-level changes; it cannot treat
  non-flat as a parameter on the existing state.
