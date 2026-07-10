#!/usr/bin/env bash
# Render every example to FOLD into OUTDIR (required arg), for before/after
# diffing across a notation cutover. Runs dune through the flake devshell, so
# it works standalone (bare `dune` is not on PATH in this repo).
set -euo pipefail
out="${1:?usage: snapshot-fold.sh OUTDIR}"
mkdir -p "$out"
nix develop -c dune build 2>/dev/null
find examples -name '*.bel' | while read -r f; do
  name="${f#examples/}"; name="${name//\//__}"
  if nix develop -c dune exec --no-build bin/main.exe -- fold "$f" > "$out/$name.fold" 2>"$out/$name.err"; then
    rm -f "$out/$name.err"
  fi
done
echo "snapshotted $(find "$out" -name '*.fold' | wc -l) examples to $out"
