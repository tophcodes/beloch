#!/usr/bin/env bash
# Everything CI checks before it deploys: `check`, the API docs and the
# register, the script tests and the site build. CI runs this script, so the
# two cannot drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/check.sh
scripts/build-api-docs.sh
bun test scripts
(cd packages/www && bun run build)
