#!/usr/bin/env bash
# Regenerates site/public/beloch/beloch-eval.js, the js_of_ocaml browser
# bundle for the evaluator (see web/beloch_web.ml), and (if the Phase 0/1
# wasm prefix has been built — see spike/build.sh) site/public/beloch/
# qqbar-wasm.js, the FLINT-wasm qqbar backend web/qqbar_shim.js calls into.
# Run this MANUALLY after changing lib/ or web/ — the astro/bun site build
# does NOT invoke the nix OCaml toolchain, so the bundle is a committed
# build artifact (same pattern as site/public/grammar/tree-sitter-beloch.wasm).
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

if [ -f "$repo_root/spike/prefix/lib/libflint.a" ]; then
  "$repo_root/spike/build.sh"
  echo "Wrote packages/www/public/beloch/qqbar-wasm.js ($(du -h "$repo_root/packages/www/public/beloch/qqbar-wasm.js" | cut -f1))"
else
  echo "spike/prefix not built (run spike/build.sh) — skipping qqbar-wasm.js" >&2
fi
