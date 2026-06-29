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
```

Output is a 512×512 image (unit-square viewBox); boundary edges are black,
creases (currently all unassigned) are coloured by Rabbit Ear.
