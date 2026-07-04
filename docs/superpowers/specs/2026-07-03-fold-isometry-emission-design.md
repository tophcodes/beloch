# Emit per-face isometries and declare the named-line frame

For [#31](https://git.toph.so/toph/beloch/issues/31).

## Problem

`fold2svg` renders a named construction line onto the folded form by
reconstructing each face's paper→table transform from float vertex pairs, with
reflection detected via a shoelace signed-area comparison (`applyIso` + `sa2`,
`tools/fold2svg.mjs:353-366`). The exact core already holds that transform in
`face.iso` (`Isometry.t`) but `fold_emit.ml` never emits it, so the renderer
guesses it back in JS floats. The bug is **non-emission, not precision** — the
guessing keeps sprouting epsilons.

Exactness is not the fix here. Vertex coincidence and layer order are decided
exactly in the kernel *before* floating (`fold_emit.ml:15` dedups via
`Geom.point_equal`; `faceOrders` is exact) and are carried as integers, so the
emitted floats hold positions only, never a decision. Emitting the isometry —
in float — removes the reconstruction outright.

## Design

### Emit per-face isometry

Add `beloch:faces_matrix` to the folded frame (`file_frames[0]`), parallel to
`faces_vertices`. One flat 6-float row per face, in `Isometry.t` field order,
the paper→table map:

```json
"beloch:faces_matrix": [ [m00, m01, m10, m11, tx, ty], ... ]
```

Consumer applies `table = (m00·px + m01·py + tx, m10·px + m11·py + ty)`. The
reflection is carried in the matrix's determinant sign — no detection.

Flat (not `{m, t}`) because FOLD's idiom is flat number arrays, the row maps
1:1 to `Isometry.t`, and every consumer destructures immediately.

### Declare the named-line frame

A named line crosses several faces, so it has no single table image — it is
inherently paper-frame. `beloch:named_lines` stays `[a, b, c]`; the renderer
clips per-face in paper space and maps the endpoints through that face's
`beloch:faces_matrix` row. Declare the frame explicitly with a sibling key:

```json
"beloch:named_lines_frame": "creasePattern"
```

`beloch:named_points` already tags `paper` + `table` per entry — unchanged.

### Port fold2svg

Replace the `applyIso(papPoly, tabPoly, …)` reconstruction with a direct matrix
apply from `beloch:faces_matrix[fi]`; the folded-view loop now needs the face
index. Delete `applyIso` and `sa2` (each has exactly one caller). The per-face
clip (`clipLineToPoly`) is unchanged.

## Components & boundaries

- `lib/fold_emit.ml` — add the `beloch:faces_matrix` row per face (reuse the
  `faces` array already iterated for `faces_vertices`) and the
  `beloch:named_lines_frame` key. Emit-only; no kernel change.
- `tools/fold2svg.mjs` — consume `beloch:faces_matrix`; delete the
  reconstruction. Rendering-only.

The two sides share one contract: `beloch:faces_matrix[fi]` is the paper→table
isometry of face `fi`, and `beloch:named_lines` coefficients are in the
`creasePattern` (paper) frame.

## Verification

- **Golden `.fold` fixtures** (`tests/golden/*.fold`) gain the two new keys →
  regenerate the successful goldens. The two ERROR goldens (`dup-point`,
  `parallel`) are unaffected. `dune test` green.
- **fold2svg output** — a folded example with a named line (e.g.
  `multiple-folds`, `bisect-*`) renders visually identical to the current
  output, minus the reconstruction epsilons. Diff the SVG for the construction
  overlay before/after.

## Out of scope

Exact coordinates (rational strings / minimal polynomial + isolating interval).
Rendering lands on float regardless, and nothing verifies exactness today.
Revisit only if a verification or round-trip consumer appears — and then decide
FOLD extension vs. a Beloch-native sidecar.
