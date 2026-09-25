#!/usr/bin/env bash
# Render the four spec/ documents (MODEL, KERNEL, BELOCH, FOLD) to PDFs with resolved citations.
#
# Statements and terms are pandoc fenced divs, `::: {.definition #id …}`;
# scripts/model-blocks.lua numbers them and generates the cross-reference lines
# and the Terms glossary. packages/www/src/lib/remark-model-blocks.ts is the
# docs-site counterpart.
#
# The ```grammar fragments of BELOCH.md are rendered by
# scripts/grammar-blocks.lua from _build/grammar.json, which the line above the
# loop regenerates; packages/www/src/lib/remark-grammar.ts is its counterpart.
#
# Citations use pandoc's syntax, `[@key, §3, p. 176]`, resolved against
# bibliography/references.bib. Math is `$...$` / `$$...$$`. The same source renders on
# the docs site (packages/www) through remark-math, rehype-katex and
# rehype-citation, so this script is only the offline, paginated view.
#
# Runs inside the flake devshell (pandoc and typst come from there):
#   nix develop -c scripts/render-model.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/_build/spec"
mkdir -p "$out"

# typst reads a figure's SVG through a path rooted at the directory pandoc runs
# in, so run from the repo root.
cd "$root"

# The PDF renders the grammar fragments from _build/grammar.json, so the parse
# can never be stale against the documents this loop reads.
bun "$root/scripts/grammar-register.ts"

for doc in MODEL KERNEL BELOCH FOLD; do
  lower=$(echo "$doc" | tr "[:upper:]" "[:lower:]")
  pandoc "$root/spec/$doc.md" \
    --from markdown \
    --lua-filter "$root/scripts/model-blocks.lua" \
    --lua-filter "$root/scripts/grammar-blocks.lua" \
    --citeproc \
    --bibliography "$root/bibliography/references.bib" \
    --csl "$root/bibliography/chicago-notes-bibliography.csl" \
    --pdf-engine typst \
    --include-in-header "$root/scripts/typst-compat.typ" \
    --variable mainfont="Libertinus Serif" \
    --metadata link-citations=true \
    --output "$out/$lower.pdf"
  echo "$out/$lower.pdf"
done
