#!/usr/bin/env bash
# Render spec/MODEL.md and spec/KERNEL.md to PDFs with resolved citations.
#
# Statements and terms are pandoc fenced divs, `::: {.definition #id …}`;
# scripts/model-blocks.lua numbers them and generates the cross-reference lines
# and the Terms glossary. packages/www/src/lib/remark-model-blocks.ts is the
# docs-site counterpart.
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

for doc in MODEL KERNEL; do
  lower=$(echo "$doc" | tr "[:upper:]" "[:lower:]")
  pandoc "$root/spec/$doc.md" \
    --from markdown \
    --lua-filter "$root/scripts/model-blocks.lua" \
    --citeproc \
    --bibliography "$root/paper/references.bib" \
    --csl "$root/paper/chicago-notes-bibliography.csl" \
    --pdf-engine typst \
    --variable mainfont="Libertinus Serif" \
    --metadata link-citations=true \
    --output "$out/$lower.pdf"
  echo "$out/$lower.pdf"
done
