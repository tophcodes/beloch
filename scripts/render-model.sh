#!/usr/bin/env bash
# Render the four docs/reference/ documents (MODEL, KERNEL, the language, FOLD) to PDFs with resolved citations.
#
# Statements and terms are pandoc fenced divs, `::: {.definition #id …}`;
# scripts/model-blocks.lua numbers them and generates the cross-reference lines
# and the Terms glossary. packages/www/src/lib/remark-model-blocks.ts is the
# docs-site counterpart.
#
# The ```grammar fragments of the grammar page are rendered by
# scripts/grammar-blocks.lua from _build/grammar.json, which the script
# regenerates first; packages/www/src/lib/remark-grammar.ts is its counterpart.
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
out="$root/_build/reference"
mkdir -p "$out"

# typst reads a figure's SVG through a path rooted at the directory pandoc runs
# in, so run from the repo root.
cd "$root"

# The PDF renders the grammar fragments from _build/grammar.json, so the parse
# can never be stale against the documents this loop reads.
bun "$root/scripts/grammar-register.ts"

# The id links between documents (ADR 0054) resolve against the index of
# _build/id-links.json through scripts/id-links.lua.
bun "$root/scripts/id-links.ts" >/dev/null

# The language is one PDF of its pages, in the order of the site's sidebar.
# The pages go to pandoc as copies under $out/language/docs/reference/, where
# grammar-blocks.lua still finds the grammar page's register entry by its
# path. A page after the first loses its front matter, since pandoc keeps the
# title of the last one, and opens with its title as a level-1 heading
# instead. The References headings leave the pages and one ends the last page,
# where citeproc puts the bibliography.
lang="$out/language"
rm -rf "$lang"
mkdir -p "$lang/docs/reference"
pages=()
for page in docs/reference/BELOCH.md docs/reference/BELOCH-WRITES.md docs/reference/BELOCH-CONSTRUCTIONS.md docs/reference/BELOCH-ANNOTATIONS.md docs/reference/BELOCH-GRAMMAR.md; do
  copy="$lang/$page"
  if [ ${#pages[@]} -eq 0 ]; then
    grep -vx '## References' "$page" > "$copy"
  else
    title=$(sed -n '2,/^---$/s/^title: //p' "$page")
    { printf '# %s\n' "$title"; awk 'NR == 1 && /^---$/ { skip = 1; next } skip && /^---$/ { skip = 0; next } !skip' "$page" | grep -vx '## References'; } > "$copy"
  fi
  pages+=("$copy")
done
printf '\n## References\n' >> "${pages[-1]}"

render() {
  local name=$1
  shift
  pandoc "$@" \
    --from markdown+wikilinks_title_after_pipe \
    --lua-filter "$root/scripts/id-links.lua" \
    --lua-filter "$root/scripts/model-blocks.lua" \
    --lua-filter "$root/scripts/grammar-blocks.lua" \
    --citeproc \
    --bibliography "$root/bibliography/references.bib" \
    --csl "$root/bibliography/chicago-notes-bibliography.csl" \
    --pdf-engine typst \
    --include-in-header "$root/scripts/typst-compat.typ" \
    --variable mainfont="Libertinus Serif" \
    --metadata link-citations=true \
    --output "$out/$name.pdf"
  echo "$out/$name.pdf"
}

render model "$root/docs/reference/MODEL.md"
render kernel "$root/docs/reference/KERNEL.md"
render beloch "${pages[@]}"
render fold "$root/docs/reference/FOLD.md"
