#!/usr/bin/env bash
# The checks to run before a push: every test suite, without the site build.
# `check-all` adds what CI adds on top. Run inside the devshell, where both
# are on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

dune build
bash scripts/run-ocaml-tests.sh
(cd packages/runtime && bun install --silent --frozen-lockfile && bun test)
(cd packages/www && bun install --silent --frozen-lockfile && bun test)
