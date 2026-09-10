#!/usr/bin/env bash
# Regenerates packages/www/public/beloch/beloch-eval.js, the js_of_ocaml browser
# bundle for the evaluator (see packages/eval-web/beloch_web.ml), and (if the
# FLINT-wasm prefix has been built) packages/www/public/beloch/qqbar-wasm.js,
# the FLINT-wasm qqbar backend packages/eval-web/qqbar_shim.js calls into.
# Run this MANUALLY after changing lib/ or eval-web/ — the astro/bun site build
# does NOT invoke the nix OCaml toolchain, so the bundle is a committed
# build artifact (same pattern as packages/www/public/grammar/tree-sitter-beloch.wasm).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

cd "$repo_root"
# --root: dune's workspace-root detection misresolves to a sibling git
# worktree's checkout when run from inside an in-repo worktree (the .git
# file here just points at .git/worktrees/<name>); pin it explicitly.
nix develop --command dune build packages/eval-web/ --profile release --root "$repo_root"

cp \
  "$repo_root/_build/default/packages/eval-web/beloch_web.bc.js" \
  "$repo_root/packages/www/public/beloch/beloch-eval.js"

echo "Wrote packages/www/public/beloch/beloch-eval.js ($(du -h "$repo_root/packages/www/public/beloch/beloch-eval.js" | cut -f1))"

if [ -f "$repo_root/packages/eval-web/.wasm-build/prefix/lib/libflint.a" ]; then
  "$repo_root/packages/eval-web/build-wasm.sh"
  echo "Wrote packages/www/public/beloch/qqbar-wasm.js ($(du -h "$repo_root/packages/www/public/beloch/qqbar-wasm.js" | cut -f1))"
else
  echo "FLINT-wasm prefix not built (run packages/eval-web/build-wasm.sh) — skipping qqbar-wasm.js" >&2
fi
