# render

Bun workspace for Beloch's SVG rendering: FOLD JSON in, labeled crease-pattern
or folded-occlusion diagrams out. The input contract is `spec/FOLD.md`.

## Packages

- **`scene/`** (`@beloch/scene`): `parseFold` turns a raw FOLD document into
  a `FoldScene` (crease-pattern frame + folded-form steps + named
  points/lines), independent of any rendering backend.
- **`render-svg/`** (`@beloch/render-svg`): `renderCP` / `renderFolded` draw
  a `FoldScene` onto an `SvgDoc` (layered SVG builder: `paper` / `creases` /
  `annotations` / `hud`), originally ported line-for-line from the retired
  Rabbit Ear-based development tool this CLI replaced.
- **`yr/`** (`@beloch/yr`): the YR-style folding diagram (ADR 0029).
  `panels` selects one panel per step group, `foldMotion` reads what a fold
  moves from the standard FOLD, the primitives in `draw.ts` draw the lines
  and arrows of the notation, and `renderYr` stacks the panels in one column.

## CLI

`render-svg/bin/fold2svg.ts` is the flag-compatible successor to the retired
`tools/` Rabbit Ear-based renderer, built on the two packages above (no
Rabbit Ear load-check; the OCaml emitter's own tests own FOLD validity):

```
bun packages/render-2d/render-svg/bin/fold2svg.ts <in.fold|-> [out.svg|out.png]
  [--title "..."] [--view cp|folded] [--flip] [--hidden dashed|hide]
  [--labels "--v,.e"] [--step <label|N>] [--legend] [--plain]
```

`-`/missing input reads stdin; missing output writes SVG to stdout; a
`.png` output suffix renders via `@resvg/resvg-js` (white background,
fit-to-width). `--view folded` renders the folded state (2D); `--flip`
views it from the other side.

## Status

This CLI is the canonical renderer for the docs pipeline. The old
Rabbit Ear-based development tool it replaced reached parity and was removed.
