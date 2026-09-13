#!/usr/bin/env bash
# Render every .bel program in the given corpus directories to normalised
# FOLD into OUTDIR (required first arg), for before/after diffing across a
# notation cutover. Corpus directories default to the whole corpus:
# examples/ and packages/core/tests/cases/. Runs dune through the flake
# devshell, so it works standalone (bare `dune` is not on PATH in this repo).
#
# Normalisation strips the source-position fields that carry no geometry:
# the "span" strings under beloch:edges and beloch:inspect, the
# beloch:source_line integer per frame, and every source_line integer
# (beloch:statements entries and beloch:free points alike). Everything
# else, including axiom provenance tags and sources name lists, must match
# across a syntax-only rewrite.
#
# Enters the devshell once for the whole corpus (not once per file): the
# shellHook's bun install/link steps make a fresh `nix develop -c` call
# expensive, so 89 separate invocations dominate the run time. `dune build`
# runs first, then every corpus file is folded with `dune exec --no-build`
# inside that same shell.
set -euo pipefail
out="${1:?usage: snapshot-fold.sh OUTDIR [CORPUS_DIR...]}"
shift
if [ "$#" -eq 0 ]; then
  set -- examples packages/core/tests/cases
fi
mkdir -p "$out"

nix develop -c bash -c '
  set -euo pipefail
  out="$1"; shift
  dune build 2>/dev/null
  find "$@" -name "*.bel" | while read -r f; do
    name="${f//\//__}"
    if dune exec --no-build beloch -- fold "$f" > "$out/$name.raw.fold" 2>"$out/$name.err"; then
      rm -f "$out/$name.err"
    else
      rm -f "$out/$name.raw.fold"
    fi
  done
' bash "$out" "$@"

normalize='
  walk(if type == "object"
       then with_entries(select(.key != "span"
                                 and .key != "beloch:source_line"
                                 and .key != "source_line"))
       else . end)
'

find "$out" -name '*.raw.fold' | while read -r raw; do
  jq "$normalize" "$raw" > "${raw%.raw.fold}.fold"
  rm -f "$raw"
done
echo "snapshotted $(find "$out" -name '*.fold' | wc -l) .fold and $(find "$out" -name '*.err' | wc -l) .err to $out"
