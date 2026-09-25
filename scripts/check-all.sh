#!/usr/bin/env bash
# Everything CI checks before it deploys: `check`, the API docs and the
# register, the README drawings against their programs, the script tests and
# the site build. CI runs this script, so the two cannot drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/check.sh
scripts/build-api-docs.sh
bash scripts/render-readme-figures.sh --check
bun test scripts
(cd packages/www && bun run build)
