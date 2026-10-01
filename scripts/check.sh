#!/usr/bin/env bash
# The checks to run before a push: every test suite and the prose lint at
# level error, without the site build. `check-all` adds what the deploy job
# adds on top. Run inside the devshell, where both are on PATH.
#
# Every step runs even when an earlier one failed, so a red kernel suite does
# not hide a red bun suite. The summary at the end names the failed steps,
# and the exit status is 1 if any failed. Only the kernel suites wait for the
# build: after a failed `dune build` they would repeat its errors.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
source scripts/steps.sh

bun_suite() {
  (cd "packages/$1" && bun install --silent --frozen-lockfile && bun test)
}

if step "dune build" dune build; then
  step "kernel suites" bash scripts/run-ocaml-tests.sh
else
  skip "kernel suites" "dune build failed"
fi
step "bun test packages/render-2d" bun_suite render-2d
step "bun test packages/runtime" bun_suite runtime
step "bun test packages/www" bun_suite www
step "prose lint at level error" bash scripts/prose.sh --minAlertLevel=error

finish check
