# Beloch dev tools

## `fold2svg.mjs` — render FOLD to SVG/PNG via Rabbit Ear

Renders Beloch's FOLD output with [Rabbit Ear](https://rabbitear.org) — the
intended downstream consumer (see `decisions/0009-relationship-to-rabbit-ear.md`).
Doubles as a sanity check that our FOLD is RE-loadable.

Setup (once; `bun` is in the Nix devshell):

```sh
bun install
```

Use:

```sh
# a .bel straight to a PNG
nix develop --command dune exec beloch -- fold examples/bisect-a.bel \
  | bun tools/fold2svg.mjs - bisect-a.png

# or from a .fold file; omit the output path for SVG on stdout
bun tools/fold2svg.mjs out.fold out.svg

# render the FOLDED state (the foldedForm frame) instead of the crease pattern
dune exec beloch -- fold examples/fold-quarter.bel \
  | bun tools/fold2svg.mjs - folded.png --folded
```

By default fold2svg draws **frame 0 — the crease pattern** (the flat sheet with
its crease lines). Pass `--folded` to draw the **`foldedForm` frame** instead —
the paper in its folded position. Flat folds stack layers in the same plane, so
`--folded` shows the silhouette (the individual layers are not separated — a
proper layered/exploded view is left to the future dedicated render engine). The
axiom colour legend uses the current verbs (`map onto`, etc.).
