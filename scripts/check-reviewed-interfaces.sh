#!/usr/bin/env bash
# The interfaces the maintainer has reviewed keep the form he reviewed
# (ADR-0080). packages/core/reviewed.sha256 lists one SHA-256 hash per
# reviewed .mli, in the format `sha256sum` prints; lines that start with `#`
# are comments. The script fails when a listed file is gone or no longer
# matches its hash, and names each such file.
#
#   check-reviewed-interfaces.sh [ROOT]
#
# ROOT defaults to the repository. Only the maintainer writes the list: to
# approve a reviewed interface, he runs `sha256sum <path>` from the
# repository root and puts its line into the list.
set -uo pipefail
cd "${1:-$(dirname "$0")/..}" || exit 1

list=packages/core/reviewed.sha256
[ -f "$list" ] || { echo "check-reviewed-interfaces: $list is missing" >&2; exit 1; }

entries=$(grep -v -e '^#' -e '^[[:space:]]*$' "$list")
[ -n "$entries" ] || exit 0

failed=0
while read -r hash path; do
  if [ ! -f "$path" ]; then
    echo "$path: reviewed interface is gone"
    failed=1
  elif [ "$(sha256sum "$path" | cut -d' ' -f1)" != "$hash" ]; then
    echo "$path: changed since the maintainer reviewed it"
    failed=1
  fi
done <<< "$entries"
exit $failed
