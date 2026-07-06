# Rendering groundwork: `@beloch/scene` + `@beloch/render-svg`

**Date:** 2026-07-06
**Status:** Draft

## Context

Beloch needs a reusable rendering engine. The full vision (brainstormed
2026-07-05/06): a typed scene model over FOLD-extended, with an SVG backend
(CPs, YR diagrams), a three.js backend (3D fold animation between
`beloch:step` frames), a semantic interaction layer, and a `<beloch-view>`
custom element. Decisions locked in during brainstorming:

- **three.js** for the future 3D backend; **no Rabbit Ear / Origami Simulator
  as libraries** (ADR 0009 keeps RE an optional consumer, not a foundation).
- **SVG is the 2D target** — in the browser SVG is live DOM (per-element
  pointer events, CSS), so "interactive diagram" needs no separate HTML canvas;
  HTML overlays can come later for tooltips.
- **Headless export is SVG→PNG only** (pure Node, no browser). 3D is
  browser-only and needs no export path.
- **TypeScript** (ADR 0001), framework-agnostic library first, web component
  later.

**This slice builds only the first two packages**: the dependency-free scene
model and the SVG backend. The goal is **parity with what we render today
(fold2svg) under our own library** — CP and folded form, no Rabbit Ear.
**YR diagrams are the next slice**, not a distant goal: the scene model's step
timeline and the SVG backend's layering must not preclude multi-panel step
layout and arrow annotations, but neither is built now. Everything further out
(3D, interaction, element) attaches later without rework.

## Package layout

New top-level `render/` directory in the beloch repo, a bun workspace:

```
render/
  package.json          # workspace root
  scene/                # @beloch/scene
  render-svg/           # @beloch/render-svg
```

Both packages are TypeScript, built/tested with bun (already in the devshell).
`@beloch/scene` has **zero runtime dependencies**. `@beloch/render-svg`
depends only on `@beloch/scene` (plus `@resvg/resvg-js` for the PNG path).

## `@beloch/scene`

Parses FOLD-extended as emitted by `beloch fold` into a typed, render-agnostic
scene model. Input fields consumed (real names from `lib/fold_emit.ml`):

- `file_frames`: frame 0 is `frame_classes: ["creasePattern"]`, subsequent
  frames are `foldedForm` frames carrying `faceOrders` and `beloch:step`.
- `vertices_coords`, `edges_vertices`, `edges_assignment`, `faces_vertices`.
- `beloch:named_points`, `beloch:named_lines` (+ `beloch:named_lines_frame`),
  `beloch:edges`, `beloch:faces_matrix`.

Output model (shape, not final signatures):

```ts
FoldScene {
  cp: Frame                  // crease pattern (frame 0)
  steps: Step[]              // one per beloch:step foldedForm frame
  namedPoints: NamedPoint[]  // name → coords (paper space)
  creases: Crease[]          // name → segment bundle (ADR 0014)
}
Frame { vertices, edges (with assignment class), faces, faceOrders? }
Step  { index, label, frame }
Crease { name, segments: Segment[] }
```

Rules:

- **Floats are fine.** Exactness lives in the OCaml core; the scene model
  consumes the serialized numbers as-is and does no geometry math beyond
  bounding boxes.
- Pure data + pure functions. No DOM, no I/O — callers hand in a parsed JSON
  object (or a string; `parseFold(json | string)` is the entry point).
- Malformed input → thrown `SceneError` with a message naming the missing/bad
  field. No recovery attempts.

Explicitly **not** in the model yet: fold angles, face hinge tree (3D
animation), interaction state.

## `@beloch/render-svg`

Renders a `FoldScene` to SVG. Two entry points:

```ts
renderCP(scene, opts)      // crease pattern: creases by class, named points/lines
renderFolded(scene, opts)  // folded occlusion view; opts.step picks the frame
```

Both return an `SvgDoc` with two serializations from one code path:

- `toString()` — for Node/headless (docs pipeline, PNG export).
- `toDOM(document)` — for the browser. Every semantic object gets stable
  `data-kind` / `data-name` attributes (e.g. `data-kind="crease"
  data-name="--d"`), which is the hook the future interaction layer binds to.

Visual scope of this slice (feature 1 of the brainstorm):

- Crease lines styled by assignment class (mountain/valley/border/flat).
- Partial-length crease segments (pinches) fall out of the segment-bundle
  model for free — a segment renders at whatever length it has.
- Named points highlighted, named lines drawn; both labeled.
- Folded-form silhouette honoring `faceOrders` (parity target: what
  `tools/fold2svg.mjs --folded` shows today).
- Axiom colour legend with current verbs, as fold2svg draws it — parity means
  the docs/PR-screenshot pipeline loses nothing in the switch.

Styling: presentation as inline SVG attributes (safe for resvg, whose CSS
support is limited) driven by a TS theme object (defaults = current fold2svg
palette), overridable via `opts.theme`. Semantic classes (`crease-M` etc.)
stay on the elements so DOM-mode CSS can restyle later; CSS-first theming
arrives with the interaction slice. No YR arrows, no step-sequence layout in
this slice.

### PNG export + CLI

Thin CLI (`render/render-svg/bin/`): `.fold` (file or stdin) → SVG or PNG
(`@resvg/resvg-js`), flag-compatible with today's usage:

```
beloch fold x.bel | bun render/render-svg/bin/fold2svg.ts - out.png [--folded]
```

`tools/fold2svg.mjs` (Rabbit Ear based) stays until the new CLI reaches
parity on the docs/PR-screenshot pipeline; deleting it is a follow-up, not
part of this slice.

## Testing

- **Scene:** unit tests parsing fixture `.fold` files regenerated from
  `examples/` via `dune exec beloch -- fold` (checked-in fixtures, plus a
  regen script).
- **render-svg:** golden SVG snapshots per fixture (string comparison);
  one PNG smoke test (resvg runs, non-empty output).
- Runner: `bun test`.

## Next slice: YR diagrams

Immediately after this slice: multi-panel step layout (one panel per
`beloch:step`) plus arrow/annotation primitives, rendered by the same SVG
backend from the same scene model. This slice prepares for it by keeping the
step timeline in `@beloch/scene` and by structuring `SvgDoc` output in layers
(paper / creases / annotations) so arrows slot in without restructuring.

## Non-goals (later slices)

three.js backend (`@beloch/render-3d`), interaction layer
(`@beloch/interact`), `<beloch-view>` element, GIF/animation export,
fold2svg.mjs deletion.
