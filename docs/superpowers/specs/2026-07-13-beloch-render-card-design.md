# `<Beloch>` render card — Slice 1: build-time eval + static SSR

**Date:** 2026-07-13
**Status:** design, approved for planning
**Scope of THIS spec:** Slice 1 only (static SSR render + build-time native eval +
deploy migration). Slices 2–3 are framed but not specified here.

## Problem

The docs site's `<Beloch>` component currently renders a **code panel only** —
no diagram (`site/src/components/Beloch.astro:1-9` says the render pipeline "come[s]
later"). Only the interactive `<Playground>` renders SVG, client-side via a
js_of_ocaml worker. We want doc examples to show the folded/crease result next to
their source, evaluated from the *same* inline `.bel` a reader sees.

## Overall architecture (framing — spans all three slices)

**Single source of truth:** the `.bel` a reader sees IS the `.bel` that gets
rendered. Source lives **inline** in the Markdown (the component's default slot).
Nothing generated is committed to git (no `.fold`, no baked SVG in source).

**SSR + hydration:**

- **Build time (SSR):** for each `<Beloch>` block, evaluate the inline source with
  the **native `beloch` binary** → FOLD JSON → `@beloch/render-svg` (pure TS) →
  static SVG inlined into the HTML, plus the FOLD JSON embedded as a
  `<script type="application/json">` sibling.
- **Client (hydration, lazy — Slice 2):** a vanilla Web Component reads the
  embedded FOLD and drives interactions (CP↔folded toggle, code↔diagram hover
  link) by re-rendering in-browser with the same `render-svg` lib. The static SVG
  is the no-JS / instant-paint fallback.

The render lib runs in **both** environments (Node/bun at build, browser at
hydrate). Evaluation for these cards happens **only** at build time; the browser
never needs js_of_ocaml for `<Beloch>` cards (that's the Playground's job, last).

**Slice roadmap:**

| Slice | Delivers | Status |
|---|---|---|
| **1 (this spec)** | static SSR render (CP) + build-time native eval + deploy migration | now |
| 2 | hydration island: CP↔folded toggle, code↔diagram hover link, `data-bel-name` provenance groundwork | next |
| 3 | Getting-Started content guide using the cards | after |
| (later) | Playground upgrades | last |

**Implementation note:** delegate mechanical implementation to Sonnet subagents
where possible; reserve Opus for design/hard reasoning.

## Slice 1 — scope

Turn `<Beloch>` into a **code | static-SVG** card. No hover, no toggle, no client
JS. Default view is the crease pattern (CP); folded rendering is wired only insofar
as `render-svg` already supports it, but the card renders **CP only** in Slice 1
(the toggle that surfaces folded is Slice 2).

### Data flow (build time)

```
<Beloch> inline source
  → write to temp .bel
  → execFileSync("beloch", ["fold", tmpfile])   # native, on PATH
  → FOLD JSON (stdout)          | on exit≠0: fail the build with beloch's stderr
  → parseFold()  (@beloch/scene)
  → renderCP(scene)  (@beloch/render-svg, pure TS)
  → inline SVG into the card + embed FOLD as <script type="application/json">
```

`beloch fold FILE.bel` is the confirmed CLI (`bin/main.ml:19,127-128`): reads a
file path, emits pretty FOLD JSON to stdout; evaluator errors go to stderr as
source-context diagnostics with exit 1 (`bin/main.ml:44-48`).

`render-svg/src` is pure TS — its only native dep (`@resvg/resvg-js`) is a dynamic
import confined to `bin/fold2svg.ts`, not reachable from `src/index.ts` — so it
runs in bun at Astro build with no extra toolchain (already aliased in
`site/astro.config.mjs:27-37`).

### `<Beloch>` component changes (`site/src/components/Beloch.astro`)

- Keep the existing code panel (tree-sitter highlight via `highlightBel`).
- Add, in frontmatter (runs at build in Node): evaluate the inline source and
  render SVG (per data flow above), via a small helper module (see below).
- Emit structure:
  ```
  <figure class="beloch-card">
    <div class="beloch-code-panel">…highlighted code…</div>
    <div class="beloch-diagram">{staticSvg}</div>
    <script type="application/json" class="beloch-fold">{foldJson}</script>
  </figure>
  ```
  The `<script>` embed lands now (cheap) so Slice 2 hydration has its data source
  without re-touching the component contract.
- Layout: code and diagram side by side on wide screens, stacked on narrow
  (mirror `.beloch-playground`'s grid at `Playground.astro:40-51`). Diagram panel
  uses `--beloch-panel`; SVG scales with `max-width:100%` (reuse the
  `.pg-result :global(svg)` rule idea).
- **File-backed vs inline:** inline source stays the only input (matches the
  approved "inline in Markdown" decision). The existing `src=` prop path is
  dropped or left unused; all rendered examples are inline.

### Build-eval helper (`site/src/lib/eval-bel.ts`, new)

A build-only module (never imported into client bundles):

```ts
export function evalBelToFold(source: string): unknown  // FOLD object
```

- Writes `source` to a temp file (`os.tmpdir()`), runs
  `execFileSync("beloch", ["fold", tmp])`, parses stdout JSON, cleans up.
- On non-zero exit: throw with beloch's stderr text so the Astro build fails
  loudly, naming the offending block. This is the example-discipline guarantee:
  an example that no longer parses/evaluates breaks the build.
- Resolves `beloch` from PATH; in dev the Nix devShell shim provides it
  (`flake.nix:84-98`), in CI `nix build .#beloch` puts it on PATH (see deploy).

### Deploy migration

CF Pages' native builder is bun-only and cannot run `beloch`. Move the build to
**GitHub Actions**; CF Pages becomes host-only (direct upload via wrangler).

New `.github/workflows/deploy.yml` (extends the sketch in `site/DEPLOY.md`):

```yaml
name: Deploy docs site
on:
  push:
    branches: [main]
    paths: ['site/**', 'render/**', 'lib/**', 'bin/**', '.github/workflows/deploy.yml']
  workflow_dispatch:
permissions: { contents: read }
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main   # cache FLINT/OCaml build
      - run: nix build .#beloch
      - run: echo "$PWD/result/bin" >> "$GITHUB_PATH"           # beloch on PATH
      - uses: oven-sh/setup-bun@v2
      - working-directory: site
        run: bun install && bun run build                       # astro build shells beloch
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          workingDirectory: site
          command: pages deploy dist --project-name=beloch-docs --branch=main
```

Prerequisites (carry over from `site/DEPLOY.md`, user-only actions):
- GH Actions secrets `CLOUDFLARE_API_TOKEN` (Pages-scoped) + `CLOUDFLARE_ACCOUNT_ID`.
- If CF Pages Git-integration is currently connected, **disconnect it** so it
  stops trying to build (bun-only) on push; Pages now only receives wrangler
  uploads.
- A `workflow`-scoped push to land the workflow file (current `gh` tokens lack it
  — Toph pushes it, or grants scope).

Update `site/DEPLOY.md` to make the Actions path canonical and note the CF
Git-integration path is no longer viable (build needs `beloch`).

CI cost: `nix build .#beloch` compiles OCaml + FLINT 3.6 on a cold cache; the
magic-nix-cache keeps warm builds fast. Acceptable per the "no committed
artifacts" decision.

## Error handling

- **beloch eval error** (parse/type/eval): build fails; surface the file/block and
  beloch's stderr diagnostic. Non-negotiable — this is the drift guard.
- **render error** (`parseFold`/`renderCP` throws): build fails with the block
  identifier and the JS error.
- **`beloch` not on PATH:** build fails early with a clear message pointing at
  `nix build .#beloch` / `nix develop` (mirror `bin/main.ml:33-34`'s wording).

## Testing / verification

- `cd site && bun run build` succeeds with at least two throwaway `<Beloch>`
  example blocks (one CP-only like two diagonals, one that also produces folded
  frames), and the built HTML contains a non-empty `<svg>` and a
  `<script class="beloch-fold">` with valid FOLD JSON for each.
- A deliberately broken block (e.g. `through .a .a`) makes the build fail with a
  beloch diagnostic — confirms the drift guard.
- Verify `beloch` is invoked as native (not jsoo): the build works with the nix
  binary on PATH and does NOT import `beloch-eval.js`.
- Deploy workflow: dry-run via `workflow_dispatch` once secrets exist (user step).

## Out of scope (later slices)

- CP↔folded toggle and any client-side JS / Web Component (Slice 2).
- Code↔diagram hover linking + `data-bel-name` provenance in
  OCaml/scene/render-svg/highlighter (Slice 2).
- Getting-Started content (Slice 3).
- Playground changes (last).
- Extracting the interaction lib into its own package — stays site-local, vanilla,
  cleanly encapsulated; extract when mature.

## Risks / open questions

- **jsoo bundle at build:** we deliberately do NOT use it; native `beloch` only.
  Confirm nothing in the astro build path pulls `beloch-eval.js` for the cards.
- **Temp-file eval per block:** fine for the handful of examples; if block count
  grows large, batch or add a `beloch fold -` stdin mode later (not now).
- **FOLD size in `<script>`:** examples are small; no concern. Revisit if a card's
  FOLD gets large.
- **CI cold-cache time** for `nix build .#beloch` — mitigated by magic-nix-cache;
  measure on first run.
```
