#!/usr/bin/env bash
# Reusable kernel benchmark runner. Runs the whole corpus, each case in its own
# process under a timeout so a walling case doesn't block the rest. Re-run
# before and after an optimization and diff the CSV block.
#
#   bench/run.sh [per-case-timeout-seconds]   (default 60)
#
# Emits a human table (stderr) and a CSV block (stdout). To compare:
#   bench/run.sh > before.csv
#   ...apply optimization, rebuild...
#   bench/run.sh > after.csv
#   diff before.csv after.csv
set -u
TIMEOUT="${1:-60}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1

dune build packages/core/bench/bench_real_roots.exe 2>&1 || { echo "build failed" >&2; exit 1; }
EXE="$ROOT/_build/default/packages/core/bench/bench_real_roots.exe"

echo "# CSV,case,coeff_deg,total_s,merge_s,resultant_s,R_deg,roots_s,ncands,filter_s,nroots"
for case in $("$EXE" list); do
  line="$(timeout "$TIMEOUT" "$EXE" "$case" 2>/dev/null)"
  if [ $? -eq 124 ]; then
    echo "$(printf '%-12s' "$case") WALLS (> ${TIMEOUT}s)" >&2
    echo "CSV,$case,,WALL,,,,,,,"
  else
    echo "$line" | grep -v '^CSV' >&2   # human line to stderr
    echo "$line" | grep '^CSV'          # csv line to stdout
  fi
done
