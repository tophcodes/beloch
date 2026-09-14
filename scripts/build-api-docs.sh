#!/usr/bin/env bash
# Build the odoc HTML for packages/core and put it where the docs site serves it.
#
# `dune build @doc` writes _build/default/_doc/_html; this copies that tree into
# packages/www/public/api, so a page reaches an item at
# /api/beloch/Beloch/Fold_state/index.html#type-t. The directory is generated
# and gitignored.
#
# scripts/api-register.ts reads the same .mli sources and records these paths
# in _build/api-register.json, which the `.include` blocks in spec/ read; it
# runs here as well so one command produces both.
#
# scripts/grammar-register.ts parses the grammar fragments of spec/ into
# _build/grammar.json, which the pandoc filter renders the PDF's grammar pages
# from and which the keyword cross-check reads; it runs here so one command
# still produces every generated input the spec documents read.
#
# scripts/render-figures.ts draws the `.figure` blocks of spec/ into
# _build/spec/figures, the other generated input both renderers of those
# documents read. It needs the `beloch` binary on PATH.
#
# packages/core/tools/blocks.exe evaluates the tagged `.bel` blocks of
# spec/BELOCH.md and writes _build/spec/blocks.json, which
# packages/www/src/lib/remark-bel.ts reads to render each block's outcome. It
# reads and writes paths relative to the repo root, hence the `cd`.
#
# Runs inside the flake devshell (odoc comes from there):
#   nix develop -c scripts/build-api-docs.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/packages/www/public/api"

dune build --root "$root" @doc
bun "$root/scripts/api-register.ts"
bun "$root/scripts/grammar-register.ts"
bun "$root/scripts/render-figures.ts"
(cd "$root" && dune exec packages/core/tools/blocks.exe)

rm -rf "$dest"
mkdir -p "$dest"
cp -R "$root/_build/default/_doc/_html/." "$dest/"
echo "$dest"
