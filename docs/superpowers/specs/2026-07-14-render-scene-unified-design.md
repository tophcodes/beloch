# Unified renderer: `renderScene` — design

**Status:** approved (brainstorm 2026-07-14)
**Goal:** collapse the two divergent SVG render paths (`renderCP`, `renderFolded`)
into a single `renderScene` whose geometry (**isometry**) and decorations
(**texture**) are independently controllable, with a small set of composable
**primitives** (faces, lines, dots, labels, highlight). Fixes three visible
problems along the way: no labels in the folded view, overlapping labels
(cube-root `.a/.b/.c/.d` collapse onto one pixel), and the confusing 1-based
stepper counter (flat sheet reads "1/2", should read step 0).

## Why

`render-cp.ts` and `render-folded.ts` are ~90% the same shape (shared
`makeLayout`, `appendConstructions`, `appendLegend`, `SvgDoc` layers) but
diverge in face drawing and in what they decorate. They are really two *presets*
of one renderer: CP = flat geometry + all creases; folded step k = step-k
geometry + creases up to k. Treating them as one path removes the drift (labels
present in CP but not folded), and unlocks two compositions the tutorials want:
"ghost" future creases on folded geometry, and progressive creases on the flat
sheet.

## Core model

Geometry comes from a `Frame`; decorations are **paper-space** features projected
through that frame's per-face isometries (`facesMatrix`, paper→table). This is
the whole trick — every `Frame` already carries faces, `facesMatrix`,
`faceOrders`, and vertices.

```ts
renderScene(scene, {
  isometry: { kind: "flat" } | { kind: "step", index: k },
  texture:  { upToStep: number | "all",
              creases: boolean, marks: boolean, points: boolean, lines: boolean,
              faces: "none" | "outline" | "filled" },
  primitives: { labels?: LabelOpts, highlight?: { names: string[] } },
  // plus existing: theme, title, legend, view ("top"|"bottom"), hidden
})
```

- `isometry.flat` → single-face paper (`init_square`, identity isometry).
  `isometry.step k` → `scene.steps[k].frame` (folded faces, layer occlusion).
- `texture.upToStep` filters features by **step provenance**, **orthogonally** to
  `isometry`. The four required compositions:
  | composition        | isometry | texture.upToStep |
  |--------------------|----------|------------------|
  | CP                 | flat     | "all"            |
  | folded (step k)    | step k   | k                |
  | ghost future       | step k   | j > k            |
  | progressive flat   | flat     | k                |
- Projection: each paper-space line/point is clipped per face and mapped through
  `facesMatrix`. The existing per-face pullback in `geometry.ts` /
  `constructions.ts` is reused, restructured under `texture.ts`.

## Modules & pipeline

```
render-scene.ts     orchestrator (renderScene)
  isometry.ts       resolve Frame → face polygons, layout (paper bbox), occlusion order
  texture.ts        collect features with step ≤ upToStep, project onto faces
  primitives/
    faces.ts        draw paper: "filled"(+occlusion) | "outline" | "none"
    lines.ts        creases / marks / named lines, with highlight
    dots.ts         named points, with highlight
    labels.ts       deterministic declutter + coincidence clustering
  layout.ts         unchanged (paper-footprint scaling, already fixed)
```

Data flow: **isometry → draw faces → collect+project texture → lines/dots →
labels declutter → highlight → HUD (legend/title)**.

`constructions.ts` and the annotation blocks in `render-cp.ts`/`render-folded.ts`
migrate into `texture.ts` + `primitives/*`. `render-cp.ts` and `render-folded.ts`
survive as **thin preset wrappers** so the CLI (`fold2svg.ts`), the render/scene
tests, and the docs `<Beloch>` figure keep their current call sites.

## Presets

- `renderCP(scene, opts)` = `renderScene` with `isometry:flat`,
  `texture:{ upToStep:"all", creases, marks, points, lines, faces:"outline" }`,
  `primitives:{ labels }`.
- `renderFolded(scene, { step:k })` = `isometry:{step:k}`,
  `texture:{ upToStep:k, …, faces:"filled" }`, `primitives:{ labels }`.
- Ghost / progressive-flat are `renderScene` calls with a shifted `upToStep`,
  exposed as an opt-in attribute on the `<Beloch>` component; default stays
  CP/folded.

## Label declutter (primitives/labels.ts)

Deterministic, byte-stable for snapshots:
1. Coincidence clustering: anchors within ε merge into one cluster label
   (`.a,.b,.c,.d`) at the shared point. Fixes the cube-root collapse.
2. Greedy placement: per anchor try a fixed candidate-offset ring
   (SW, S, SE, W, E, NW, N, NE…); take the first whose label bbox does not
   overlap an already-placed label or a face/dot it should not cover.
3. No solver, no randomness → golden snapshots stay stable.

## Stepper numbering (docs figure)

0-based step index: the flat sheet is **step 0**, step k is the k-th fold.
Counter reads "k / N−1" (or "Step k"), not "1/N". `beloch-figure.ts` already
holds a 0-based internal index; only the label string and the numeric `--step`
(already 0-based from the prior slice) need to agree.

## Emitter: step provenance on named constructions

`NamedPoint`/`NamedLine` currently lack a step, so `texture.upToStep` cannot
filter freely-constructed intermediate points. Fix at the source:
- `fold_emit.ml` attaches `step` to `beloch:named_points` / `beloch:named_lines`.
- `render/scene/parse.ts` reads it; `NamedPoint`/`NamedLine` gain
  `step: string | null`.
- `texture.upToStep` then filters **every** feature type exactly.

## Testing

- Keep existing CP/folded snapshots byte-identical through the presets where
  possible; where the rewrite legitimately changes output (labels now in folded,
  declutter), re-baseline those snapshots once, reviewing the diff.
- New tests: one per composition (CP / folded / ghost / progressive-flat) and a
  declutter test (coincident + dense anchors) — deterministic, so stable.
- Emitter field change → regenerate `.fold` fixtures + golden bases again; update
  the handful of scene-parse assertions that enumerate named points/lines.
- Golden `.fold` topology is otherwise unaffected (renderer-only changes).

## Delivery slices (for the plan)

- **A — Emitter provenance:** `step` on named points/lines; parse; fixtures/golden
  regen; scene assertions.
- **B — `renderScene` core:** new modules + pipeline; `renderCP`/`renderFolded`
  become presets (byte-compat target); labels in folded + declutter.
- **C — Compositions & stepper:** ghost / progressive-flat opt-in on `<Beloch>`;
  0-based stepper numbering; wire the reflecting/tutorial pages.

## Out of scope (YAGNI)

Animation / isometry interpolation between steps (the decoupling enables it, but
it is not built). Force-directed label layout. Any 3D / three.js backend.
