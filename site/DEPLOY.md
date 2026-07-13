# Deploying the Beloch docs site

The site is a static Astro/Starlight build in `site/dist`. Since the render-card
work, `<Beloch>` evaluates inline `.bel` at build time by shelling the native
`beloch` binary — the build now requires `beloch` on `PATH`, not just bun.
`site/public/beloch/beloch-eval.js` (the in-browser evaluator for the live
playground) remains a **committed artifact**; regenerate it manually with
`site/scripts/build-eval.sh` when the evaluator changes.

Build command (from repo root, **inside `nix develop`** — see below):
`cd site && bun install && bun run build` → output `site/dist`.
Cloudflare Pages project name: **`beloch-docs`** (see `site/wrangler.toml`).

## Status / prerequisites

1. **Cloudflare Actions secrets** — `CLOUDFLARE_API_TOKEN` (Pages-scoped:
   **Account → Cloudflare Pages → Edit**) and `CLOUDFLARE_ACCOUNT_ID` are set
   as repo Actions secrets.
2. **DNS for `beloch.toph.so`.** The `toph.so` zone ("l") in
   `fleet/tofu/cloudflare` still has a `TODO_toph_so_zone_id`. Add a `CNAME`
   `beloch` → `beloch-docs.pages.dev` (via the CF dashboard, or complete the
   tofu records for that zone).
3. **A `workflow`-scoped push.** The current `gh` tokens lack `workflow`
   scope, so `.github/workflows/deploy.yml` can't be pushed by automation —
   push it yourself, or grant the scope.

## Canonical: GitHub Actions + wrangler

CF Pages' Git-integration builder is **bun-only** and cannot shell out to a
native `beloch` binary — since the build now depends on `beloch` being on
`PATH`, Git-integration is **no longer a viable deploy path**. GitHub Actions
is the only supported route: it builds `beloch` from the flake with Nix, puts
it on `PATH`, then runs the bun build and uploads `site/dist` via Wrangler.

The workflow lives at `.github/workflows/deploy.yml` and runs on every push to
`main` that touches `site/**`, `render/**`, `lib/**`, `bin/**`, `flake.nix`,
`flake.lock`, or the workflow file itself (also triggerable manually via
`workflow_dispatch`). It uses the `CLOUDFLARE_API_TOKEN` /
`CLOUDFLARE_ACCOUNT_ID` secrets from prerequisite 1.

If a Cloudflare Pages project for this repo has Git-integration **connected**,
**disconnect it** — otherwise CF will also try to build on push and fail (no
`beloch` on its bun-only builder). Pages should only receive builds via the
Wrangler upload in the Actions job. Map the custom domain `beloch.toph.so` in
the Pages project's **Custom domains** tab (creates/uses the CNAME from
prerequisite 2) — that mapping is independent of which build path pushes to
the project.

After first pushing the workflow file, trigger it once via `workflow_dispatch`
(or a qualifying push) to confirm a green run and a live deploy.

## Manual one-off deploy (local)

Must run **inside `nix develop`** (for `beloch` on `PATH`) with a Pages-scoped
token exported as `CLOUDFLARE_API_TOKEN` (and `CLOUDFLARE_ACCOUNT_ID`):

```sh
nix develop
cd site && bun run build
bunx wrangler pages deploy dist --project-name=beloch-docs --branch=main
```

(`site/package.json` already has a `deploy` script for this.)
