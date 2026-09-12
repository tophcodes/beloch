#!/usr/bin/env bash
# Render spec/MODEL.md to a PDF with resolved citations.
#
# Citations use pandoc's syntax, `[@key, §3, p. 176]`, resolved against
# paper/references.bib. Math is `$...$` / `$$...$$`. The same source renders on
# the docs site (packages/www) through remark-math, rehype-katex and
# rehype-citation, so this script is only the offline, paginated view.
#
# Runs inside the flake devshell (pandoc and typst come from there):
#   nix develop -c scripts/render-model.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/_build/spec"
mkdir -p "$out"

pandoc "$root/spec/MODEL.md" \
  --from markdown \
  --citeproc \
  --bibliography "$root/paper/references.bib" \
  --csl "$root/paper/chicago-notes-bibliography.csl" \
  --pdf-engine typst \
  --variable mainfont="Libertinus Serif" \
  --metadata link-citations=true \
  --output "$out/model.pdf"

echo "$out/model.pdf"
