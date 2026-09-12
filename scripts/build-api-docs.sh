#!/usr/bin/env bash
# Build the odoc HTML for packages/core and put it where the docs site serves it.
#
# `dune build @doc` writes _build/default/_doc/_html; this copies that tree into
# packages/www/public/api, so a page reaches an item at
# /api/beloch/Beloch/Fold_state/index.html#type-t. The directory is generated
# and gitignored.
#
# scripts/api-register.ts reads the same .mli sources and records these paths,
# so `.include` blocks in spec/ link into the pages this script publishes.
#
# Runs inside the flake devshell (odoc comes from there):
#   nix develop -c scripts/build-api-docs.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/packages/www/public/api"

dune build --root "$root" @doc

rm -rf "$dest"
mkdir -p "$dest"
cp -R "$root/_build/default/_doc/_html/." "$dest/"
echo "$dest"
