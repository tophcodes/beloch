#!/usr/bin/env bash
# The drawings README.md shows, rendered from their programs with
# `beloch render`. GitHub serves the README from the repository, so the SVGs
# are committed next to their .bel files.
#
#   render-readme-figures.sh           re-render them in place
#   render-readme-figures.sh --check   fail if a committed SVG differs from
#                                      what its program renders now
#
# Run inside the devshell, where `beloch` is on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

programs=(
  examples/crane.bel
  examples/bases/bird-base.bel
  examples/bases/fish-base.bel
  examples/bases/preliminary-reverse.bel
  examples/bases/swivel-rabbit.bel
)

out=.
if [[ "${1:-}" == "--check" ]]; then
  out=$(mktemp -d)
  trap 'rm -rf "$out"' EXIT
fi

stale=0
for bel in "${programs[@]}"; do
  for view in cp folded; do
    svg="${bel%.bel}-$view.svg"
    mkdir -p "$out/$(dirname "$svg")"
    beloch render "$bel" "$out/$svg" --view "$view" --legend
    if [[ "$out" != . ]] && ! cmp -s "$out/$svg" "$svg"; then
      echo "stale: $svg (run scripts/render-readme-figures.sh)" >&2
      stale=1
    fi
  done
done
exit "$stale"
