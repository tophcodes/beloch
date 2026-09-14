#!/usr/bin/env bash
# Run every alcotest suite through dune and hold the result against
# scripts/known-failures.txt.
#
# The suite is not green: issue #51 (flatten tier pooling) leaves four cases
# red, and they stay red until that slice lands. A plain `dune runtest` in CI
# would therefore fail on every push and guard nothing. This compares the
# failure count per suite against a recorded baseline instead, so a new
# failure anywhere still fails the build, and a suite that becomes greener
# than its baseline fails it too, as the signal to shrink the baseline.
#
# The suites run under `dune runtest`, never as bare executables: dune sets
# DUNE_SOURCEROOT and the working directory each suite expects, and a suite
# run without them can pass while reading an empty corpus.
#
# Run from the repository root, inside the devshell.
set -uo pipefail
cd "$(dirname "$0")/.."

baseline=scripts/known-failures.txt

actual=$(mktemp)
expected=$(mktemp)
log=$(mktemp)
trap 'rm -f "$actual" "$expected" "$log"' EXIT

# --force so a cached pass still reports its result. dune carries on past a
# failing suite by default, which is what lets the baseline cover all of them.
dune runtest --force > "$log" 2>&1
sed -i 's/\x1b\[[0-9;]*m//g' "$log"

# Each suite prints "Full test results in `…/_tests/<name>'" and then either
# "Test Successful in …" or "N failures! in …".
awk '
  match($0, /_tests\/[A-Za-z0-9_-]+/) {
    suite = substr($0, RSTART + 7, RLENGTH - 7)
  }
  /^[> ]*[0-9]+ failures?! / {
    for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { n = $i; break }
    if (suite != "") print suite, n
  }
' "$log" | sort -u > "$actual"

grep -vE '^\s*(#|$)' "$baseline" | sort > "$expected"

if diff -u "$expected" "$actual" > /dev/null; then
  if [ -s "$actual" ]; then
    echo "OK: only the failures recorded in $baseline"
    cat "$actual"
  else
    echo "OK: every suite green"
  fi
  exit 0
fi

echo "Test results differ from $baseline (left: recorded, right: this run):"
diff -u "$expected" "$actual" || true
echo
echo "A suite on the right only, or a larger count: a new failure, fix it."
echo "A suite on the left only, or a smaller count: it got fixed, take it out of $baseline."
echo
echo "Full output:"
cat "$log"
exit 1
