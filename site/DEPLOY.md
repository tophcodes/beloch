# Deploying the Beloch docs site

The site is a static Astro/Starlight build in `site/dist`. The in-browser
evaluator (`site/public/beloch/beloch-eval.js`) is a **committed artifact** — CI
does **not** need the OCaml/nix toolchain, only bun. Regenerate the bundle
manually with `site/scripts/build-eval.sh` when the evaluator changes.

Build command (from repo root): `cd site && bun install && bun run build`
→ output `site/dist`. Cloudflare Pages project name: **`beloch-docs`**
(see `site/wrangler.toml`).

## Status / prerequisites (not yet satisfied)

Wiring is prepared here but the deploy is **not live** — three things need your
account, none of which the automation could do safely:

1. **A Cloudflare token scoped for Pages.** The token in fleet
   (`secrets/cloudflare.env.age`) is `Zone:DNS:Edit` only — enough for DNS,
   **not** for `pages deploy`. Mint a token with **Account → Cloudflare Pages →
   Edit** (and note the **Account ID**).
2. **DNS for `beloch.toph.so`.** The `toph.so` zone ("l") in
   `fleet/tofu/cloudflare` still has a `TODO_toph_so_zone_id`. Add a `CNAME`
   `beloch` → `beloch-docs.pages.dev` (via the CF dashboard, or complete the
   tofu records for that zone).
3. **A `workflow`-scoped push** if you use the GitHub Actions path below — the
   current `gh` tokens lack `workflow` scope, so a `.github/workflows/*` file
   can't be pushed by the automation. Add it yourself, or connect the repo
   directly (recommended, no workflow file needed).

## Recommended: Cloudflare Pages Git integration (no secrets in repo)

CF Pages → Create project → Connect to Git → `tophcodes/beloch`. Build settings:

- **Production branch:** `main`
- **Build command:** `cd site && bun install && bun run build`
- **Build output directory:** `site/dist`
- **Root directory:** repo root (leave default)

CF pulls the repo and builds on every push to `main`. Then map the custom domain
`beloch.toph.so` in the project's **Custom domains** tab (creates/uses the CNAME
from prerequisite 2).

## Alternative: GitHub Actions + wrangler

Requires GitHub Actions secrets `CLOUDFLARE_API_TOKEN` (the Pages-scoped token)
and `CLOUDFLARE_ACCOUNT_ID`, and a `workflow`-scoped push. Drop this at
`.github/workflows/deploy.yml`:

```yaml
name: Deploy docs site

on:
  push:
    branches: [main]
    paths: ['site/**', 'render/**', '.github/workflows/deploy.yml']
  workflow_dispatch:

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - working-directory: site
        run: bun install && bun run build
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          workingDirectory: site
          command: pages deploy dist --project-name=beloch-docs --branch=main
```

## Manual one-off deploy (local)

With a Pages-scoped token exported as `CLOUDFLARE_API_TOKEN` (and
`CLOUDFLARE_ACCOUNT_ID`):

```sh
cd site && bun run build
bunx wrangler pages deploy dist --project-name=beloch-docs --branch=main
```

(`site/package.json` already has a `deploy` script for this.)
