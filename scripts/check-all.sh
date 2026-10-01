#!/usr/bin/env bash
# Everything the deploy job checks before it publishes the site: `check`, the
# API docs and the register, the README drawings against their programs, the
# script tests and the site build. The deploy job runs this script, so the two
# cannot drift apart.
#
# Like `check`, it runs every step even after one failed and ends with a
# summary, so one run in CI reports every red step at once. The site build
# reads what the API docs step generates and can fail in its wake; the summary
# then names both.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
source scripts/steps.sh

step "check" bash scripts/check.sh
step "API docs and register" scripts/build-api-docs.sh
step "README figures" bash scripts/render-readme-figures.sh --check
step "bun test scripts" bun test scripts
step "site build" bash -c 'cd packages/www && bun run build'

finish check-all
