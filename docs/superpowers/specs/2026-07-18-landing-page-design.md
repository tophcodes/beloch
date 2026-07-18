# Landing page with the playground as hero

**Date:** 2026-07-18
**Branch:** `spike/flint-wasm-playground`
**Status:** design — approved in shape

## Goal

Give Beloch a first-class landing page at `/` whose hook is the live playground.
Move the playground OUT of the docs (no `/playground/` docs page). No marketing
copy — factual, docs-voice prose only (see the site's teach-not-sell principle).

## Scope (trimmed by user)

IN: standalone landing at `/`, playground as hero, a functional example row that
loads samples into the playground, a plain footer nav.
OUT: feature/benefit strip ("why Beloch") — no marketing yet.

## Architecture

### Route ownership
- New `src/pages/index.astro` — a standalone Astro page, NOT a Starlight content
  page. It bypasses the Starlight shell (no sidebar), so it provides its own
  `<html>`/`<head>`: IBM Plex fonts, `src/styles/theme.css` tokens, the
  `data-theme` light/dark handling Starlight uses, and the `headSyncScript()`
  from `src/lib/paper-schemes.ts` (so paper-scheme swatch choice persists like
  elsewhere). Dark default.
- **Free up `/`:** the current docs home `src/content/docs/index.mdx` also maps
  to `/`. Relocate it to `src/content/docs/introduction.mdx` (route
  `/introduction/`). Update `astro.config.mjs` sidebar `{ label: "Introduction",
  link: "/introduction/" }` and any internal links that point at `/`.

### Hero — the playground, loaded lazily
The playground worker pulls a 5.7 MB wasm module on boot. On a landing hero that
would download on every visit. So:
- Render an **instant static SVG** of the hero program at build time (reuse the
  `<Beloch>` build-time eval path — native `beloch fold` → `@beloch/render-svg`),
  shown in the result pane immediately.
- Boot the **live worker + wasm lazily** on first user gesture (textarea focus/
  input, Run click, or an IntersectionObserver when the hero scrolls into view).
- Implement by extending `Playground.astro` with two optional props:
  - `seed?: string` — SVG markup to show in `.pg-result` initially.
  - `lazy?: boolean` — when true, do NOT create the Worker on mount; create it +
    run on the first gesture. Absent props → today's eager behavior (unaffected).
- Hero program: the incenter rabbit-ear that's proven to fold in-browser
  (`paper square` / `mark --diag = through .a .c` / `--ea`,`--eb`,`--ec` /
  `flatten (--ea & .a) (--ec & .c) (--eb & .b) {toward .a}`).

### Example row
A horizontal row of a few samples (fish base, kite, rabbit-ear). Each is a
labelled chip; clicking sets the playground textarea to that sample's source and
triggers a run (booting wasm if still lazy). Optional small static SVG thumbnail
per chip via a build-time `<Beloch>` render — keep it light; labels are enough if
thumbnails bloat the build. Sample sources live in an array in the page
frontmatter (or read from `examples/bases/*.bel`).

### Footer
Plain nav links: Introduction (`/introduction/`), Tutorials, GitHub. No copy.

### Remove docs playground
- Delete `src/content/docs/playground.mdx`.
- Redirect `/playground/` → `/` (Astro `redirects` in `astro.config.mjs`).
- Remove the "Playground" sidebar item; fix the index/introduction link that
  pointed at `/playground/` (point it at `/` or the hero anchor).

## Testing / verification
- `bun run build` succeeds (native `beloch` on PATH via nix for the build-time
  `<Beloch>` evals).
- Browser (headless Chromium, as in `spike/verify-playground.mjs`): load `/`,
  confirm the hero shows the static fold instantly; then focus/type in the
  editor → worker boots, wasm loads, a live fold renders (an `<svg>` in
  `.pg-result`, no console errors). Load `/playground/` → redirects to `/`.
  Load `/introduction/` → the old docs home renders.
- Screenshot the landing to `spike/landing.png`.

## Non-goals / defer
- wasm size tuning (still 5.7 MB; lazy-load makes it non-blocking for the hero).
- Any marketing/benefit copy.
- Deploy — gated on the stacked flatten branch landing (separate step).
