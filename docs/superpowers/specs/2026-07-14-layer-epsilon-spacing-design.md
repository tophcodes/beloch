# Layer ε-Spacing (Exploded Folded View) — Design

**Date:** 2026-07-14
**Status:** Approved, ready for planning
**Scope:** `render/scene` (data model), `render/render-svg` (folded backend)

## Problem

In the folded SVG view (`render/render-svg/src/render-folded.ts`), faces are
painted back→front in `linearExtension` order, each with a fake `layerShadow`
drop-shadow (`dy: 1`) as the only depth cue. Coplanar stacked faces land at
exactly the same 2D coordinates, so a stack of N layers reads as a single flat
shape — you cannot see how many layers there are or their order. A folded spine
(where many layers meet) shows as one line instead of a stack.

We want real per-layer ε-offset so a stack fans slightly and reads as paper
thickness: the stacked edge (`Stapelkante`) becomes visible.

## Key insight: `faceOrders` *is* the overlap graph

FOLD's `faceOrders` records a stacking pair `[f, g, s]` only for faces that
**spatially overlap** — non-overlapping faces need no order and get no entry.
Therefore the "overlap DAG" needed to compute layer height requires **no new
polygon-intersection geometry**: it is exactly `faceOrders`, with each edge
oriented below→above by the existing `linearExtension` order.

**Assumption (noted in code):** a genuinely-stacked overlapping pair is always
present in `faceOrders`. If the evaluator ever omits one, `faceDepth` undercounts
at that spot. This matches FOLD semantics (a defined stacking order requires an
entry) and is acceptable.

## What a "layer" means

Not the global paint index (that would shear flat single-layer regions apart —
a 30-face model would push the top face 30·ε even where only 3 layers stack).
Instead: **local overlap depth** = longest chain of overlapping faces below a
face. Flat single-layer regions get depth 0 (stay put); only genuine stacks fan.

## Design

### Scene layer — `render/scene`

Add a per-face field to `Frame` (`render/scene/src/types.ts`):

```ts
export interface Frame {
  // ...existing...
  faceOrders: FaceOrder[];
  faceDepth: number[];   // physical layer height per face; parallel to facesVertices
}
```

Computed once during parse (`render/scene/src/parse.ts`), consumed by every
backend (2D SVG now, three.js later — see [[beloch-render-engine-design]]):

1. `order = linearExtension(faceOrders, F.length, faceUp)` (bottom→top), giving
   `pos[f]` = index in `order`.
2. For each `faceOrders` pair `{f, g}`, add a directed edge below→above by
   comparing `pos[f]` vs `pos[g]`.
3. DP over faces in ascending `pos`:
   `depth[f] = has-below ? 1 + max(depth[below]) : 0`.

`faceDepth` is `[]` on the CP frame (no `faceOrders`).

**Helper relocation:** `linearExtension`, `sideUp`, `signedArea` move from
`render-svg/geometry.ts` into `render/scene` (they are pure topology/orientation
and belong in the model, and `faceDepth` needs them). `render-svg` imports them
back from `@beloch/scene`. This keeps depth computation in a single home.
*(Rejected alternative: leave helpers in render-svg and reimplement ordering in
scene — needless duplication.)*

### SVG backend — `render/render-svg/src/render-folded.ts`

Add to `FoldedOptions`:

```ts
explode?: number;   // per-layer offset in px; default 1.5
```

**Default-on (1.5px).** This regenerates all existing folded goldens/snapshots
(intended — the fanned view is the new default). `explode: 0` restores the exact
previous byte-identical output.

When `explode > 0`:
- Each face and its incident creases/edges shift by
  `explode · faceDepth[fi] · (+1, −1)` — up-right, toward the shadow light so
  stagger and shadow agree.
- Implemented as a per-depth-band `<g transform="translate(dx, dy)">` wrapping
  each depth level's faces + creases, so creases stay glued to their face rather
  than detaching.
- Occlusion (`coveredIntervals`, visible-interval clipping) is still computed in
  **true (unshifted) coordinates**; at ε ≈ 1.5px the residual mismatch between
  clipped geometry and shifted paint is sub-pixel and visually nil.

`layerShadow`: keep, but set `dy` 0 — the real ε-offset now carries depth; the
shadow only softens edges.

## Data flow

```
OCaml evaluator → FOLD/JSON (faceOrders)
  → scene/parse.ts: Frame { ..., faceDepth[] }   ← depth computed here, once
    → render-folded.ts: explode · faceDepth[fi] · (+1,−1)   ← 2D fan today
    → (future) three.js: z = ε · faceDepth[fi]              ← same field, 3D later
```

## Testing

- **scene unit test:** assert `faceDepth` on a known multi-layer fixture
  (`render/scene/test/fixtures/fold-quarter.fold` → expected depths, e.g.
  0,1,2,3 for a quartered sheet). Deterministic.
- **render-svg snapshot:** folded render with `explode: 1.5` on the same fixture;
  visually verify the stagger fans up-right and the stacked edge is visible.
- Regenerate existing folded snapshots (default now on).

## Out of scope

- three.js / 3D backend (field is provisioned for it; not implemented here).
- CP view (no stacking).
- Scene-model `thickness`/units beyond a unitless per-face depth index.
