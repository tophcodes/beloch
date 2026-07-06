# Beloch dev tools

## Rendering FOLD to SVG/PNG

FOLD→SVG/PNG rendering lives in `render/render-svg/bin/fold2svg.ts` (the
`@beloch/render-svg` package) — see `render/README.md`. The old Rabbit
Ear-based dev tool that used to live here has been retired now that the
render engine's own SVG backend has reached parity.

Setup (once; `bun` is in the Nix devshell):

```sh
cd render && bun install
```

Use:

```sh
# a .bel straight to a PNG
nix develop --command dune exec beloch -- fold examples/syntax/bisect-a.bel \
  | bun render/render-svg/bin/fold2svg.ts - bisect-a.png

# or from a .fold file; omit the output path for SVG on stdout
bun render/render-svg/bin/fold2svg.ts out.fold out.svg

# render the FOLDED state (the foldedForm frame) instead of the crease pattern
dune exec beloch -- fold examples/syntax/fold-quarter.bel \
  | bun render/render-svg/bin/fold2svg.ts - folded.png --folded
```

By default fold2svg draws **frame 0 — the crease pattern** (the flat sheet with
its crease lines). Pass `--folded` to draw the **`foldedForm` frame** instead —
the paper in its folded position. Flat folds stack layers in the same plane, so
`--folded` shows the silhouette (the individual layers are not separated — a
proper layered/exploded view is left to the future dedicated render engine). The
axiom colour legend uses the current verbs (`map onto`, etc.).
