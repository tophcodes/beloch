# render

Bun workspace for Beloch's SVG rendering: FOLD JSON in, labelled crease-pattern
or folded-occlusion diagrams out. Spec:
`docs/superpowers/specs/2026-07-06-render-scene-svg-design.md`.

## Packages

- **`scene/`** (`@beloch/scene`) — `parseFold`: turns a raw FOLD document into
  a `FoldScene` (crease-pattern frame + folded-form steps + named
  points/lines), independent of any rendering backend.
- **`render-svg/`** (`@beloch/render-svg`) — `renderCP` / `renderFolded`: draw
  a `FoldScene` onto an `SvgDoc` (layered SVG builder: paper / creases /
  annotations / hud), originally ported line-for-line from the retired
  Rabbit Ear-based dev tool this CLI replaced.

## CLI

`render-svg/bin/fold2svg.ts` is the flag-compatible successor to the retired
`tools/` Rabbit Ear-based renderer, built on the two packages above (no
Rabbit Ear load-check — the OCaml emitter's own tests own FOLD validity):

```
bun render/render-svg/bin/fold2svg.ts <in.fold|-> [out.svg|out.png]
  [--title "..."] [--folded] [--view top|bottom] [--hidden dashed|hide]
  [--constructions "--v,.e"] [--step <label>]
```

`-`/missing input reads stdin; missing output writes SVG to stdout; a
`.png` output suffix renders via `@resvg/resvg-js` (white background,
fit-to-width). `--folded` is shorthand for `--view top`.

## Status

This CLI is the canonical renderer for the docs pipeline. The old
Rabbit Ear-based dev tool it replaced reached parity and was removed.
