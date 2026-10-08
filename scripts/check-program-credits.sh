#!/usr/bin/env bash
# The credits every program in the repository states (decisions/a-program-states-its-author-design-and-sources): each .bel
# file carries an `@author` annotation, and each program in examples/ carries
# `@design` and at least one `@source`. A source cites in the bracket form of
# the repository, `@source "[ida2020, Fig. 7.19]"`, and every cite key in its
# brackets names an entry of bibliography/references.bib. The kernel checks
# where these annotations stand and what they take; this script checks that
# they are there and that the cite keys resolve.
#
#   check-program-credits.sh [ROOT]
#
# ROOT defaults to the repository. The script prints one line per missing
# credit and exits 1 if it printed one.
set -uo pipefail
cd "${1:-$(dirname "$0")/..}" || exit 1

# The files jj tracks in the working copy, where there is one: a jj workspace
# has no .git of its own. CI checks out with git.
tracked() {
  if [ -d .jj ] && command -v jj >/dev/null; then jj file list; else git ls-files; fi
}

mapfile -t files < <(tracked | grep -E '\.bel$')
# A failed file listing leaves the list empty; stop there, or the run passes
# a tree it never read.
[ ${#files[@]} -gt 0 ] || { echo "check-program-credits: no .bel files listed" >&2; exit 1; }

bib=bibliography/references.bib
failed=0
missing() {
  echo "$1: $2"
  failed=1
}

# the lines of a file that open with the annotation, at any indent
annotation_lines() { grep -E "^[[:space:]]*@$1([[:space:]]|$)" "$2"; }

for f in "${files[@]}"; do
  annotation_lines author "$f" >/dev/null || missing "$f" "no @author"
  [[ "$f" =~ ^examples/[^/]+\.bel$ ]] || continue
  annotation_lines design "$f" >/dev/null || missing "$f" "no @design"
  sources=$(annotation_lines source "$f")
  [ -n "$sources" ] || missing "$f" "no @source"
  # the cite keys of the brackets: [key], [key, locator], [key1; key2]
  keys=$(grep -oE '\[[^]]*\]' <<<"$sources" | tr -d '[]' | tr ';' '\n' |
    sed -E 's/^[[:space:]]*([A-Za-z0-9_:-]+).*/\1/')
  for key in $keys; do
    grep -qF "{$key," "$bib" 2>/dev/null || missing "$f" "@source cites $key, which is not in $bib"
  done
done

exit "$failed"
