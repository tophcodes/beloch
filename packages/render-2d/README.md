# render

Bun workspace for Beloch's SVG rendering: FOLD JSON in, labeled crease-pattern
or folded-occlusion diagrams out. The input contract is `docs/reference/FOLD.md`.

## Packages

- **`scene/`** (`@beloch/scene`): `parseFold` turns a raw FOLD document into
  a `FoldScene` (crease-pattern frame + folded-form steps + named
  points/lines), independent of any rendering backend.
- **`render-svg/`** (`@beloch/render-svg`): `renderCP` / `renderFolded` draw
  a `FoldScene` onto an `SvgDoc` (layered SVG builder: `paper` / `creases` /
  `annotations` / `hud`), originally ported line-for-line from the retired
  Rabbit Ear-based development tool this CLI replaced.
- **`yr/`** (`@beloch/yr`): the YR-style folding diagram (`decisions/annotations-pass-through-and-each-output-is-a-library`).
  `panels` selects one panel per step group, `foldMotion` reads what a fold
  moves and whether it is a valley, a mountain or a reverse fold from the
  standard FOLD, `turnOver` recognizes a `flip`, the primitives in `draw.ts`
  draw the lines and arrows of the notation, `existingCreaseSegments` the
  creases already in the paper, `rotationSymbol` the turn between two
  panels, and `renderYr` stacks the panels in one column, at a scale that
  grows as the model shrinks.
- **`cli/`** (`@beloch/render-cli`): the `beloch-render` command over the
  packages above. It sits in a package of its own so that every output
  library is a dependency of the command and none of another.

## CLI

`cli/bin/fold2svg.ts` is the flag-compatible successor to the retired
`tools/` Rabbit Ear-based renderer, built on the packages above (no
Rabbit Ear load-check; the OCaml emitter's own tests own FOLD validity):

```
bun packages/render-2d/cli/bin/fold2svg.ts <in.fold|-> [out.svg|out.png]
  [--title "..."] [--view cp|folded|yr] [--flip] [--hidden dashed|hide]
  [--labels "--v,.e"] [--step <label|N>] [--legend] [--plain]
```

`-`/missing input reads stdin; missing output writes SVG to stdout; a
`.png` output suffix renders via `@resvg/resvg-js` (white background,
fit-to-width). `--view folded` renders the folded state (2D); `--flip`
views it from the other side.

## Status

This CLI is the canonical renderer for the docs pipeline. The old
Rabbit Ear-based development tool it replaced reached parity and was removed.
