# shellcheck shell=bash
# Sourced by scripts/check.sh and scripts/check-all.sh: runs every step of a
# check to its end, even after an earlier step failed, and prints at the end
# which steps failed.
#
#   step <name> <command>...   run the command; a non-zero exit marks <name>
#                              failed and the run carries on
#   skip <name> <reason>       mark <name> skipped, e.g. after the build it
#                              needs has failed
#   finish <label>             print the summary; exit 1 if a step failed
#
# The caller runs without `set -e`, which would stop at the first failure.

steps_passed=()
steps_skipped=()
steps_failed=()

step() {
  local name=$1
  shift
  echo "==> $name"
  if "$@"; then
    steps_passed+=("$name")
    return 0
  fi
  steps_failed+=("$name")
  echo "==> $name: FAILED" >&2
  return 1
}

skip() {
  steps_skipped+=("$1 ($2)")
  echo "==> $1: skipped, $2" >&2
}

finish() {
  local label=$1 s
  echo
  echo "== $label summary"
  for s in "${steps_passed[@]}"; do echo "  passed   $s"; done
  for s in "${steps_skipped[@]}"; do echo "  skipped  $s"; done
  for s in "${steps_failed[@]}"; do echo "  FAILED   $s"; done
  if [ ${#steps_failed[@]} -gt 0 ] || [ ${#steps_skipped[@]} -gt 0 ]; then
    echo "$label: ${#steps_failed[@]} step(s) failed, ${#steps_skipped[@]} skipped"
    exit 1
  fi
  echo "$label: every step passed"
}
