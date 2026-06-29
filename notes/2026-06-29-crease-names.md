# 2026-06-29 — crease names in FOLD output + diagram labels

`beloch:edges` now carries a `"name"` key per crease entry: the bound crease
name (e.g. `"d1"`) when the statement was named (`--d1: …`), or `null` for an
anonymous crease.

## What shipped

- `State.Provenance.name : string option` — set during eval from the binding
  name in each crease statement.
- `beloch:edges` `name` key (`string | null`) — emitted by `fold_emit`
  alongside the existing `axiom`, `sources`, and `span` fields.
- `tools/fold2svg.mjs` — labels named creases on the diagram: text placed on
  the line, ~18% in from one end, with a white halo so it never collides with
  the corner labels.

## Why on-line, not at the boundary exit

The original idea was to place labels just outside the paper at the point where
the crease exits the boundary. That collides with the existing corner labels for
any crease that exits at a corner (e.g. the two diagonals of a square both exit
at corners). Placing the label on the line itself, inset from one end, sidesteps
the collision entirely and is legible for all crease orientations.

## Relationship to other in-flight work

This is additive (stock FOLD consumers ignore unknown keys) and does not touch
the axiom set, geometry, or version string. It was built on `main` as its own
PR, with PR #3 (axiom-5 prep) to rebase on top afterwards. No version bump.
