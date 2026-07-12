# Beloch Docs Site — Design (v1)

**Date:** 2026-07-13
**Status:** approved, implementing
**Branch:** `feat/docs-starlight`

## Goal

A browsable, searchable documentation site for Beloch with a **live playground**
that runs the real evaluator in the browser. Immediate driver: make dense
concepts (starting with `collapse`) legible — to the language's own designer
first. Supersedes the dead `forgejo/feat/docs-site` branch (Astro Starlight,
156 commits behind, content predates mark/fold, collapse, fold-scope, toward —
scaffolding ideas salvageable, content discarded).

## Architecture — three pieces + glue

### 1. Site (`site/`)
Astro + Starlight. MDX content under `site/src/content/docs/`. Syntax
highlighting via the `tree-sitter-beloch` grammar (ported from the old branch;
grammar + `.wasm` are tool-independent assets). Dark/light theme.

### 2. Eval bundle — `Beloch.fold_string` → JS
A new js_of_ocaml build target compiling the `beloch` library's entry point so
the **real evaluator** runs client-side.

- **zarith** → `zarith_stubs_js` (pure-JS GMP bignums).
- **sedlex / menhirLib / yojson** → pure OCaml, compile as-is.
- **qqbar / FLINT** → cannot compile (C stubs). Provide a js_of_ocaml **runtime
  shim** implementing the `external`s in `lib/qqbar.ml`. Every shimmed op raises
  a dedicated exception (`Needs_native` — new, or reuse `Beloch_error` with a
  stable marker) so the JS side can distinguish "irrational, needs native" from
  a genuine program error.
- **Output:** `belochFoldString(src): string` returning FOLD JSON, exported to
  JS. Bundled into `site/`.

**Why this works:** the entire rational fragment — reflections, midpoints,
point-onto-point bisectors — never constructs a `Num.Qq`, so it never calls a
shimmed external. That fragment includes the whole crane path (waterbomb,
preliminary, collapse are pure reflections). Programs that hit √ (axiom-5
point-onto-line) or ∛ (axiom-6) trip `Needs_native` and degrade gracefully.

**This is the load-bearing risk** and is spiked before the rest of the plan:
the `beloch` lib currently declares `(foreign_stubs …qqbar_stubs)` and
`(c_library_flags -lflint -lgmp -lmpfr)`; the JS target must exclude those and
inject the shim. Prove one rational program round-trips in a headless JS runtime
before fanning out.

### 3. Render — FOLD JSON → SVG, in-browser
Reuse the existing TS pipeline, both browser-safe:
- `@beloch/scene` (`render/scene`) — zero deps, parses FOLD → scene model.
- `@beloch/render-svg` (`render/render-svg`) — builds the SVG node tree via a
  passed-in `document` (no Node import); `@resvg/resvg-js` (PNG) lives only in
  the CLI `bin/fold2svg.ts` and is excluded from the browser bundle.

### 4. Playground component
Editor (textarea or CodeMirror) + tree-sitter highlight + **Run** →
`belochFoldString` → `@beloch/scene` → `@beloch/render-svg` → inject SVG. On
`Needs_native`, render a "run natively" notice instead of crashing. Embeddable
in MDX so doc pages carry live examples.

## Content (v1) — scope-disciplined

- **Flagship:** the `collapse` explainer (port the published artifact page) with
  an **embedded live playground** on the waterbomb example.
- **Minimal frame:** intro / "what is Beloch"; the **two-frames** page
  (crease-pattern vs folded, the M/V-parity idea); a verbs quick-reference stub.
- **Examples gallery:** the rational bases (waterbomb, kite, rabbit-ear) as live
  playgrounds, each labelled rational (runs) vs native-only.

### Non-goals (v1)
Full `SPECIFICATION.md` migration; three.js / 3-D; live eval of irrational
(√/∛) programs; search tuning. These grow later.

## Deploy
Cloudflare Pages via `wrangler`. Bootstrap `beloch.toph.so`; `beloch.dev`
registered later. Deploy wiring is the last, deferrable step.

## Open items to resolve during planning
- **Enumerate** which committed `examples/**.bel` are pure-rational (run
  in-browser) vs native-only; label each in the gallery. Do not guess —
  classify by evaluating or by static inspection of the motions used.
- Editor choice: plain textarea + tree-sitter overlay (lighter) vs CodeMirror
  (richer). Default to the lighter option unless the spike shows friction.
- Exact exception contract between the OCaml shim and the JS caller.

## Build / execution notes
- Feature branch `feat/docs-starlight` off `main`; PR to `main` (origin =
  github.com/tophcodes/beloch). Verify `git branch --show-current` before every
  commit (shared checkout).
- Mechanical work delegated to Sonnet subagents; the js_of_ocaml spike is
  verified first because it gates the playground.
