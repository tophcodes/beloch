#!/usr/bin/env bash
# Prints the section of one release from the changelog, without its heading.
#
#   changelog-section.sh <version> [<changelog>]
#
# <version> is 0.5.0 or the tag name v0.5.0. <changelog> defaults to
# CHANGELOG.md at the repository root. A section runs from its heading
# `## [<version>] - <date>` to the next `## ` heading or to the link
# definitions at the end of the file. Leading and trailing blank lines are
# dropped. Exits 1 when the changelog has no section for the version.
#
# The release workflow passes the output to `gh release create --notes-file`,
# so the GitHub release mirrors the changelog.
set -euo pipefail

version=${1#v}
file=${2:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/CHANGELOG.md"}

body=$(awk -v heading="## [$version]" '
  index($0, heading) == 1 { inside = 1; found = 1; next }
  inside && (/^## / || /^\[[^]]+\]: /) { exit }
  inside { print }
  END { if (!found) exit 1 }
' "$file") || { echo "changelog-section: no section for $version in $file" >&2; exit 1; }

# $(...) strips the trailing blank lines, and the filter drops the leading ones.
printf '%s\n' "$body" | sed '/./,$!d'
