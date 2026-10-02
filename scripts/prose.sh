#!/usr/bin/env bash
# Prose lint (.vale.ini) over the Markdown of the repository and the comments
# of its sources.
#
#   prose              every tracked .md, .mdx, .ml, .mli, .ts, .css, .lua,
#                      .astro, .typ and .sh file
#   prose <path>...    the named files or directories; a directory lints its
#                      Markdown only
#
# Extra Vale flags go before the paths, e.g. `prose --minAlertLevel=error`.
# Run inside the devshell, which puts vale on PATH and links the pinned
# styles into .vale/styles.
#
# Vale has no parser for OCaml. prose_mask (packages/core/tools) writes a copy
# of each .ml and .mli file into a temporary directory in which everything
# but the prose of the comments is blank, at the same line and column. Vale
# lints the copies as plain text, and the reported paths are rewritten to the
# source files. scripts/prose-mask.ts does the same for the TypeScript, CSS,
# Astro, Typst, Lua and shell sources, whose comments are checked for
# spelling only (.vale.ini).
set -euo pipefail
cd "$(dirname "$0")/.."

flags=()
while [ $# -gt 0 ] && [[ "$1" == -* ]]; do flags+=("$1"); shift; done

# The files jj tracks in the working copy, where there is one: a jj workspace
# has no .git of its own, and the index of the main checkout can lag behind
# it. CI checks out with git.
tracked() {
  if [ -d .jj ] && command -v jj >/dev/null; then jj file list; else git ls-files; fi
}

if [ $# -gt 0 ]; then
  targets=("$@")
else
  # Test fixtures and the license are not prose of the project. The brand
  # documents are left out until the lint has rules for German.
  # spec/SPECIFICATION.md is being dissolved into the other documents (ADR
  # 0032); its sections are linted where they move to.
  mapfile -t targets < <(tracked | grep -E '\.(md|mdx|ml|mli|ts|css|lua|astro|typ|sh)$' |
    grep -vE '^(LICENSE\.md$|packages/www/src/lib/fixtures/|docs/brand/|scripts/fixtures/|spec/SPECIFICATION\.md$)')
  # A failed file listing leaves the list empty; stop there, or the run
  # reports no alerts for a tree it never read.
  [ ${#targets[@]} -gt 0 ] || { echo "prose: no files listed" >&2; exit 1; }
fi

files=() ocaml=() code=()
for f in "${targets[@]}"; do
  case "$f" in
    *.ml | *.mli) ocaml+=("$f") ;;
    *.ts | *.css | *.lua | *.astro | *.typ | *.sh) code+=("$f") ;;
    *) files+=("$f") ;;
  esac
done

if [ ${#ocaml[@]} -gt 0 ] || [ ${#code[@]} -gt 0 ]; then
  masked=$(mktemp -d)
  trap 'rm -rf "$masked"' EXIT
  if [ ${#ocaml[@]} -gt 0 ]; then
    dune exec --display=quiet ./packages/core/tools/prose_mask.exe -- "$masked" "${ocaml[@]}"
  fi
  if [ ${#code[@]} -gt 0 ]; then
    bun scripts/prose-mask.ts "$masked" "${code[@]}"
  fi
  for f in "${ocaml[@]}" "${code[@]}"; do files+=("$masked/$f.txt"); done
  vale "${flags[@]}" "${files[@]}" | sed "s#$masked/\([^[:space:]\"]*\)\.txt#\1#g"
else
  exec vale "${flags[@]}" "${files[@]}"
fi
