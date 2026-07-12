#!/usr/bin/env bash
# Regenerates site/public/beloch/beloch-eval.js, the js_of_ocaml browser
# bundle for the evaluator (see web/beloch_web.ml). Run this MANUALLY after
# changing lib/ or web/ — the astro/bun site build does NOT invoke the nix
# OCaml toolchain, so the bundle is a committed build artifact (same pattern
# as site/public/grammar/tree-sitter-beloch.wasm).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$repo_root"
nix develop --command dune build web/ --profile release

cp \
  "$repo_root/_build/default/web/beloch_web.bc.js" \
  "$repo_root/site/public/beloch/beloch-eval.js"

echo "Wrote site/public/beloch/beloch-eval.js ($(du -h "$repo_root/site/public/beloch/beloch-eval.js" | cut -f1))"
