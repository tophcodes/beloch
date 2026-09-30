#!/usr/bin/env bash
# Prose lint (.vale.ini) over the Markdown of the repository.
#
#   prose              every tracked .md and .mdx file
#   prose <path>...    the named files or directories
#
# Extra Vale flags go before the paths, e.g. `prose --minAlertLevel=error`.
# Run inside the devshell, which puts vale on PATH and links the pinned
# styles into .vale/styles.
set -euo pipefail
cd "$(dirname "$0")/.."

flags=()
while [ $# -gt 0 ] && [[ "$1" == -* ]]; do flags+=("$1"); shift; done

if [ $# -gt 0 ]; then
  exec vale "${flags[@]}" "$@"
fi
# Test fixtures and the license are not prose of the project. The brand
# documents are left out until the lint has rules for German.
mapfile -t files < <(git ls-files '*.md' '*.mdx' ':!:LICENSE.md' ':!:packages/www/src/lib/fixtures/**' ':!:docs/brand/**')
exec vale "${flags[@]}" "${files[@]}"
