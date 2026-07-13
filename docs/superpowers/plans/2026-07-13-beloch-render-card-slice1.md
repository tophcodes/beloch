# Beloch Render Card — Slice 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the docs `<Beloch>` component into a code | static-SVG card, evaluating the inline `.bel` with the native `beloch` binary at Astro build time, and migrate deploy to GitHub Actions.

**Architecture:** SSR-only for this slice. Astro component frontmatter (runs in Node at build) shells out to `beloch fold` → FOLD JSON → `@beloch/scene` `parseFold` → `@beloch/render-svg` `renderCP` → inline `<svg>` + an embedded `<script type="application/json">` FOLD blob (data source for Slice 2 hydration, unused in Slice 1). No client JS. Build now requires `beloch` on PATH, so deploy moves from Cloudflare Pages' bun-only builder to GitHub Actions (`nix build .#beloch` → `bun run build` → `wrangler pages deploy`).

**Tech Stack:** Astro/Starlight, TypeScript, bun, OCaml (`beloch` CLI via Nix), `@beloch/scene` + `@beloch/render-svg` (pure-TS, already aliased in `site/astro.config.mjs`), GitHub Actions, Cloudflare Wrangler.

## Global Constraints

- **Single source of truth:** inline `.bel` in Markdown is the only input. Nothing generated (`.fold`, baked SVG) is committed.
- **Native eval only:** `beloch fold` (native binary). Never use the js_of_ocaml bundle (`beloch-eval.js`) at build time.
- **Build fails on eval error:** a `<Beloch>` block whose source fails to parse/evaluate must break the build with beloch's stderr diagnostic (drift guard).
- **Builds run inside the Nix devShell** (or CI with `nix build .#beloch`) so `beloch` is on PATH. `beloch fold FILE.bel` emits FOLD JSON to stdout; errors → stderr, exit 1 (`bin/main.ml:19,127-128,44-48`).
- **render-svg is pure TS** — runs in bun at build; its only native dep (`@resvg/resvg-js`) is confined to `bin/fold2svg.ts`, not `src/index.ts`.
- German UI copy (site is in German).
- Conventional commits; end commit messages with the repo's Co-Authored-By trailer.
- Out of scope (Slice 2+): CP↔folded toggle, hover linking, `data-bel-name` provenance, any client-side JS, the Getting-Started content, Playground changes.

---

### Task 1: Clear old docs content to a minimal stub

Once Task 3 makes `<Beloch>` evaluate at build, every existing page using it (e.g. `guide/collapse.mdx`) must eval cleanly or the build breaks. The old content is slated for replacement in Slice 3, so clear the decks now to a stub, keeping only a placeholder index and the Playground page. This also fixes the sidebar config, which would otherwise `autogenerate` from now-empty directories.

**Files:**
- Delete: `site/src/content/docs/beispiele.mdx`, `site/src/content/docs/guide/collapse.mdx`, `site/src/content/docs/guide/das-faltmodell.mdx`, `site/src/content/docs/guide/zwei-frames.mdx`, `site/src/content/docs/reference/verben.mdx`
- Modify: `site/src/content/docs/index.mdx` (replace with a stub)
- Modify: `site/astro.config.mjs:61-82` (trim sidebar to existing pages only)
- Keep: `site/src/content/docs/playground.mdx` (uses `<Playground>`, unaffected)

**Interfaces:**
- Produces: a site whose `bun run build` succeeds with the current (code-only) `<Beloch>` and no dangling sidebar `autogenerate` entries.

- [ ] **Step 1: Replace `index.mdx` with a stub**

Overwrite `site/src/content/docs/index.mdx`:

```mdx
---
title: Beloch
description: Eine deklarative Sprache für Origami, gebaut auf den Huzita–Justin-Axiomen.
---

Beloch ist eine deklarative Sprache für Origami. Diese Dokumentation wird gerade
neu aufgebaut — der Getting-Started-Guide folgt in Kürze.

Bis dahin: probiere die Sprache direkt im [Playground](/playground/).
```

- [ ] **Step 2: Delete the old content pages**

```bash
git rm site/src/content/docs/beispiele.mdx \
       site/src/content/docs/guide/collapse.mdx \
       site/src/content/docs/guide/das-faltmodell.mdx \
       site/src/content/docs/guide/zwei-frames.mdx \
       site/src/content/docs/reference/verben.mdx
```

- [ ] **Step 3: Trim the sidebar config**

In `site/astro.config.mjs`, replace the `sidebar: [ … ]` array (lines ~61-82) with only the surviving pages:

```js
			sidebar: [
				{
					label: "Einstieg",
					items: [{ label: "Einführung", link: "/" }],
				},
				{
					label: "Playground",
					items: [{ label: "Playground", link: "/playground/" }],
				},
			],
```

- [ ] **Step 4: Build to verify a clean, green site**

Run (inside the Nix devShell): `cd site && bun install && bun run build`
Expected: build completes; `Building search index` and `page(s) built`. No error about empty `autogenerate` directories. `site/dist/index.html` and `site/dist/playground/index.html` exist.

- [ ] **Step 5: Commit**

```bash
git add -A site/
git commit -m "docs(site): clear old content to a stub ahead of getting-started rebuild

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `evalBelToFold` build-time eval helper

A build-only TS helper that shells the native `beloch` binary to evaluate source into a FOLD object, throwing beloch's diagnostic on failure.

**Files:**
- Create: `site/src/lib/eval-bel.ts`
- Test: `site/src/lib/eval-bel.test.ts`

**Interfaces:**
- Produces: `export function evalBelToFold(source: string): unknown` — returns the parsed FOLD object; throws `Error` (message includes beloch's stderr) on eval failure or a clear "not on PATH" message if `beloch` is missing.

- [ ] **Step 1: Write the failing tests**

Create `site/src/lib/eval-bel.test.ts`:

```ts
import { test, expect } from "bun:test";
import { evalBelToFold } from "./eval-bel";

test("evaluates a simple program to a FOLD object", () => {
  const fold = evalBelToFold("paper square\nmark --d1 = through .a .c\n") as {
    vertices_coords?: unknown;
  };
  expect(typeof fold).toBe("object");
  expect(Array.isArray(fold.vertices_coords)).toBe(true);
});

test("throws with a diagnostic on a broken program", () => {
  // `through .a .a` — no line through a single point (a known anti-example).
  expect(() => evalBelToFold("paper square\nmark through .a .a\n")).toThrow();
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run (inside the Nix devShell, so `beloch` is on PATH): `cd site && bun test src/lib/eval-bel.test.ts`
Expected: FAIL — `Cannot find module './eval-bel'` (or export not found).

- [ ] **Step 3: Write the implementation**

Create `site/src/lib/eval-bel.ts`:

```ts
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

/**
 * Evaluate Beloch source to a FOLD object using the native `beloch` binary.
 *
 * Build-time only — never import this into a client bundle. `beloch` must be on
 * PATH (the Nix devShell provides it in dev; `nix build .#beloch` in CI). Throws
 * an Error carrying beloch's stderr diagnostic if evaluation fails, so an
 * example that no longer parses/evaluates breaks the Astro build (drift guard).
 */
export function evalBelToFold(source: string): unknown {
  const dir = mkdtempSync(join(tmpdir(), "beloch-"));
  const file = join(dir, "snippet.bel");
  try {
    writeFileSync(file, source);
    let stdout: string;
    try {
      stdout = execFileSync("beloch", ["fold", file], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch (err) {
      const e = err as { code?: string; stderr?: Buffer | string; message?: string };
      if (e.code === "ENOENT") {
        throw new Error(
          "beloch: binary not found on PATH — run `nix develop` (or `nix build .#beloch` in CI).",
        );
      }
      const stderr = e.stderr?.toString() ?? "";
      throw new Error(`beloch fold failed:\n${stderr || e.message || String(err)}`);
    }
    return JSON.parse(stdout);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd site && bun test src/lib/eval-bel.test.ts`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/eval-bel.ts site/src/lib/eval-bel.test.ts
git commit -m "feat(site): build-time beloch eval helper (evalBelToFold)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `<Beloch>` renders code | static SVG

Wire the eval + render pipeline into the component: keep the highlighted code panel, add a diagram panel with the SSR'd SVG, and embed the FOLD JSON for later hydration.

**Files:**
- Modify: `site/src/components/Beloch.astro`
- Modify: `site/src/content/docs/index.mdx` (add one real `<Beloch>` example — doubles as the build verification and a first live demo)

**Interfaces:**
- Consumes: `evalBelToFold` (Task 2); `parseFold` from `@beloch/scene`; `renderCP` from `@beloch/render-svg` (returns an `SvgDoc` with `.toString(): string`, per `render/render-svg/src/svgdoc.ts:70`).
- Produces: a `<figure class="beloch-card">` containing `.beloch-code-panel`, `.beloch-diagram` (holding the SVG), and `<script type="application/json" class="beloch-fold">` (the FOLD blob).

- [ ] **Step 1: Update the component frontmatter**

Replace the frontmatter of `site/src/components/Beloch.astro` (currently lines 1-40) with:

```astro
---
// Code + statically-rendered SVG card for inline .bel source.
//
// The inline source (default slot) is evaluated at BUILD TIME with the native
// `beloch` binary (see ../lib/eval-bel.ts) into a FOLD object, then rendered to
// SVG via the pure-TS render pipeline. The FOLD is also embedded as a JSON
// <script> so a later hydration island (Slice 2) can drive CP↔folded + hover
// without changing this component's contract. No client JS in this slice.
import { highlightBel } from "../lib/highlight-bel";
import { evalBelToFold } from "../lib/eval-bel";
import { parseFold } from "@beloch/scene";
import { renderCP } from "@beloch/render-svg";

interface Props {
  title?: string;
}
const { title } = Astro.props;

// inline source is passed as the default slot's text
const inline = await Astro.slots.render("default").catch(() => "");
const source = stripHtml(inline);

if (!source || source.trim() === "") {
  throw new Error("<Beloch>: provide inline .bel source");
}

function stripHtml(s: string): string {
  return s
    .replace(/<[^>]*>/g, "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .trim();
}

const label = title ?? "inline";
const trimmed = source.trim();

// Syntax highlighting via the shared tree-sitter grammar (emits .bel-* spans).
const highlightedSource = await highlightBel(trimmed);

// Build-time evaluation + render. Any failure throws → the Astro build fails
// with beloch's diagnostic (drift guard).
const fold = evalBelToFold(trimmed);
const svg = renderCP(parseFold(fold as object)).toString();
const foldJson = JSON.stringify(fold);
---
```

- [ ] **Step 2: Update the component template**

Replace the template markup (currently `<figure class="beloch-card">…</figure>`, lines ~42-52) with:

```astro
<figure class="beloch-card">
  <div class="beloch-code-panel">
    <div class="beloch-mac-bar">
      <span class="mac-dot" style="background:#B5573C"></span>
      <span class="mac-dot" style="background:#C9A24B"></span>
      <span class="mac-dot" style="background:#5C8A5E"></span>
      <span class="beloch-filename">{label}</span>
    </div>
    <pre class="beloch-pre"><code set:html={highlightedSource} /></pre>
  </div>
  <div class="beloch-diagram" set:html={svg}></div>
  <script type="application/json" class="beloch-fold" set:html={foldJson}></script>
</figure>
```

- [ ] **Step 3: Update the component styles**

Replace the `.beloch-card` rule in the component's `<style>` block (currently ~lines 56-63) and add a diagram rule. The card becomes two columns on wide screens, stacked on narrow:

```css
  /* ── Card shell ─────────────────────────────────────────────────────────── */
  .beloch-card {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    margin: 1.5rem 0;
    border: 1px solid var(--beloch-border);
    border-radius: 14px;
    overflow: hidden;
    background: var(--beloch-panel);
  }
  @media (max-width: 720px) {
    .beloch-card { grid-template-columns: 1fr; }
  }

  /* ── Diagram panel ──────────────────────────────────────────────────────── */
  .beloch-diagram {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 18px 22px;
    background: var(--beloch-panel);
    overflow: auto;
  }
  .beloch-diagram :global(svg) {
    max-width: 100%;
    height: auto;
  }
```

(Leave the existing `.beloch-code-panel`, `.beloch-mac-bar`, `.mac-dot`, `.beloch-filename`, `.beloch-pre` rules unchanged.)

- [ ] **Step 4: Add a real example to the stub index**

Append to `site/src/content/docs/index.mdx` (after the intro prose), using the two-diagonals example (CP-only, deterministic):

```mdx
import Beloch from "../../components/Beloch.astro";

<Beloch title="diagonalen.bel">
paper square
mark --d1 = through .a .c
mark --d2 = through .b .d
</Beloch>
```

- [ ] **Step 5: Build and verify the SVG + FOLD embed land**

Run (inside the Nix devShell): `cd site && bun run build`
Expected: build succeeds.

Then verify the rendered output:

```bash
grep -c '<svg' site/dist/index.html                 # expect >= 1
grep -c 'class="beloch-fold"' site/dist/index.html   # expect 1
grep -o 'vertices_coords' site/dist/index.html | head -1  # expect the FOLD blob present
```
Expected: `<svg` count ≥ 1, `beloch-fold` script present, `vertices_coords` found.

- [ ] **Step 6: Verify the drift guard (build fails on a bad example)**

Temporarily change the index example's body to `paper square` + `mark through .a .a`, then:

Run: `cd site && bun run build`
Expected: build FAILS with a beloch diagnostic mentioning the single-point line error. Then revert the index back to the two-diagonals example from Step 4 and re-run `bun run build` to confirm green.

- [ ] **Step 7: Commit**

```bash
git add site/src/components/Beloch.astro site/src/content/docs/index.mdx
git commit -m "feat(site): <Beloch> renders code | build-time SVG + FOLD embed

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Migrate deploy to GitHub Actions

CF Pages' bun-only builder cannot run `beloch`. Build in Actions (Nix-built `beloch` on PATH), deploy the static `dist/` to CF Pages via Wrangler. This task's file cannot be pushed by automation (needs a `workflow`-scoped token) and its end-to-end verification needs account secrets — those steps are the user's.

**Files:**
- Create: `.github/workflows/deploy.yml`
- Modify: `site/DEPLOY.md` (make the Actions path canonical; note CF Git-integration is no longer viable)

**Interfaces:**
- Produces: a `push`-to-`main` workflow that builds with `beloch` available and deploys `site/dist`.

- [ ] **Step 1: Create the workflow**

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy docs site

on:
  push:
    branches: [main]
    paths:
      - 'site/**'
      - 'render/**'
      - 'lib/**'
      - 'bin/**'
      - 'flake.nix'
      - 'flake.lock'
      - '.github/workflows/deploy.yml'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main
      - name: Build beloch (native)
        run: nix build .#beloch
      - name: Put beloch on PATH
        run: echo "$PWD/result/bin" >> "$GITHUB_PATH"
      - uses: oven-sh/setup-bun@v2
      - name: Build site
        working-directory: site
        run: bun install && bun run build
      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          workingDirectory: site
          command: pages deploy dist --project-name=beloch-docs --branch=main
```

- [ ] **Step 2: Update DEPLOY.md**

In `site/DEPLOY.md`, make the GitHub Actions path canonical. Replace the "Recommended: Cloudflare Pages Git integration" section with a note that Git-integration is **no longer viable** — the build now shells the native `beloch` binary, which CF Pages' bun-only builder does not provide — and promote the Actions + Wrangler flow (referencing `.github/workflows/deploy.yml`) to the primary method. Keep the prerequisites list (Pages-scoped `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, DNS for `beloch.toph.so`) and the manual local-deploy section (note it too must run inside `nix develop`).

- [ ] **Step 3: Verify the workflow YAML parses**

Run: `cd /home/toph/Projects/beloch && python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/deploy.yml')); print('ok')"`
Expected: `ok` (no YAML syntax error). (Use the nix comma if `python3` is not on PATH: `, python3 -c ...`.)

- [ ] **Step 4: Commit (local; user pushes)**

```bash
git add .github/workflows/deploy.yml site/DEPLOY.md
git commit -m "ci(site): deploy docs via GitHub Actions with nix-built beloch

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: User-only handoff steps (cannot be automated)**

Document for the user (do not attempt automatically):
1. Add repo Actions secrets `CLOUDFLARE_API_TOKEN` (Pages-scoped) and `CLOUDFLARE_ACCOUNT_ID`.
2. If Cloudflare Pages Git-integration is connected to the repo, **disconnect it** so it stops building on push (it would fail bun-only). Pages now only receives Wrangler uploads.
3. Push the branch with a `workflow`-scoped token (current `gh` tokens lack it), or grant the scope.
4. Trigger once via `workflow_dispatch` and confirm a green run + a live deploy.

---

## Notes for the implementer

- **Always build inside `nix develop`** from Task 3 onward — `bun run build` now requires `beloch` on PATH. Outside the devShell the build fails with the "not found on PATH" message from `evalBelToFold`.
- `render/**`, `lib/**`, `bin/**` are outside `site/` but are already readable by the dev server via `server.fs.allow: [repoRoot]` (`site/astro.config.mjs:41-43`) and consumed via the `@beloch/scene` / `@beloch/render-svg` aliases (`:33-37`).
- Do not touch `src/lib/highlight-bel.ts`, the grammar, or `render/**` in this slice — provenance/`data-bel-name` work is Slice 2.
```
