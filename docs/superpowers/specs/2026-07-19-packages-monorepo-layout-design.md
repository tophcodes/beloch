# Design: `packages/` monorepo layout

**Date:** 2026-07-19
**Status:** approved (brainstorming) — pending implementation plan
**Topic:** consolidate the scattered top-level components under a single `packages/`
tree, ahead of more moving targets (2D render, 3D render, more libs).

## Problem

The repo root mixes two toolchains (OCaml/dune and JS-TS/bun) as loose sibling
directories: `lib bin tests bench tools web` (OCaml) alongside `render site
tree-sitter-beloch editors` (JS/TS + grammar). As new deliverables land (3D
render, further libraries) the root sprawls further and it stops being obvious
what is a shippable component versus project meta.

Goal (chosen: **Mittelweg**): group the components under `packages/` and document
their interfaces, while keeping **one build graph** (one dune-project, one nix
flake). The structure prepares for a future hard split into independent packages
without forcing it today.

## Target layout

```
beloch/
  dune-project  dune  flake.nix  flake.lock  .envrc  .ocamlformat  .gitignore
  README.md  LICENSE.md  CLAUDE.md
  decisions/  notes/  paper/  spec/  docs/     # project meta — unchanged
  examples/                                    # shared .bel corpus — stays root
  refs/  scratch/  learn/  spike/              # gitignored + one-off — unchanged
  packages/
    core/       # was lib/ bin/ tests/ bench/ tools/  — opam package "beloch"
    eval-web/   # was web/   — js_of_ocaml browser eval bundle
    render-2d/  # was render/ — bun workspace (scene + render-svg)
    docs-site/  # was site/   — Astro docs + Playground UI
    grammar/    # was tree-sitter-beloch/
    vscode/     # was editors/vscode/  (editors/ removed)
```

`render-3d/` joins as an empty sibling only when it exists — do **not** scaffold
it now (YAGNI).

### Decisions taken

- **`web/` → `packages/eval-web/`.** It is the OCaml→JS eval engine, not the
  Playground UI (which lives in `docs-site`). Naming it `playground` would blur
  that boundary.
- **`examples/` stays at root.** It is a shared corpus consumed by the OCaml
  tests, `docs-site`, and the CLI, and is featured in the README as a showcase.
  It belongs to no single package, so it sits at root alongside `decisions/` and
  `notes/`. Keeping it put also avoids re-plumbing the test fixture paths twice.
- **Core stays one opam package.** `lib bin tests bench tools` all move under
  `packages/core/` but remain the single `beloch` package declared in the
  root `dune-project`. dune assigns sources to packages by declaration, not by
  directory, so the split across `packages/core` and `packages/eval-web` is fine.

## Key insight: almost no code churn

dune resolves dependencies by **library name** (`(libraries beloch)`), not file
path. OCaml source (`.ml`/`.mli`) is therefore **not edited**. Only
build-orchestration files need path fixes:

| File | Fix |
|---|---|
| `flake.nix` | `web/`→`packages/eval-web/`; `render/`→`packages/render-2d/`; `render/render-svg`→`packages/render-2d/render-svg` (both the build ref and the `bun install` / `bun link` shellHook paths) |
| `.github/workflows/deploy.yml` | path filters `site/**`,`render/**`; `dune build web/`; `cp _build/default/web/beloch_web.bc.js …`; `working-directory: site` and wrangler `workingDirectory: site` (both → `packages/docs-site`) |
| `packages/docs-site/scripts/build-eval.sh` | `dune build web/` → `dune build packages/eval-web/`; `_build/default/web/beloch_web.bc.js` → `_build/default/packages/eval-web/beloch_web.bc.js`; tree-sitter path |
| `packages/docs-site/src/lib/highlight-bel.ts` | tree-sitter-beloch path → `packages/grammar` |
| `packages/core/tests/dune`, `test_eval.ml`, `test_e2e.ml` | fixture plumbing (see risk) |

Unaffected:

- `bin/main.ml` execvp's `beloch-render` via PATH lookup — no repo-path
  dependency (only the nix `bun link` source path changes, in `flake.nix`).
- `render/` internal bun workspace (`workspaces: ["scene","render-svg"]`) and the
  `beloch-render` / `@beloch/render-svg` package names — the whole directory
  moves as one block, so all internal relative paths stay valid.
- `scratch/dune` uses `(libraries beloch)` — resolves by name, location-independent.

## Main risk: OCaml test fixture paths

The tests locate fixtures by **relative path with a fixed build-depth
assumption**:

- `tests/test_eval.ml` and `test_e2e.ml` fall back to `../../../examples` and
  `../../../tests/cases` (three levels up from `_build/default/tests/` to the
  repo root). They also honor an environment-provided source root first (the
  `#37` mechanism — "reads its own examples rather than the main checkout's").
- `tests/dune` declares `(deps (source_tree ../examples) (source_tree golden))`
  and `(deps (source_tree cases))`.

Moving `tests/` to `packages/core/tests/` deepens the build path
(`_build/default/packages/core/tests/`), so both the `../../../` fallbacks and
the `../examples` source_tree dep break and must be re-pointed. Since `examples/`
stays at root, `../examples` becomes `../../../examples` (relative to the new
`packages/core/tests` dune dir), and the runtime fallback constant grows by the
two added levels. Preferred fix: lean on the env-var source-root mechanism so the
constants stop being depth-fragile; adjust the `source_tree` relative paths to
match the new dune-file location.

This is the one place that needs care and a green-tests gate, and it is why the
core moves **last**.

## Migration plan (one slice, verifiable)

Each stage must be green before the next; every move is `git mv` (history
preserved); the CI/flake path fix lands in the **same commit** as its move.

1. **Peripheral packages** — `git mv` `tree-sitter-beloch → packages/grammar`,
   `render → packages/render-2d`, `web → packages/eval-web`, `site →
   packages/docs-site`, `editors/vscode → packages/vscode` (drop empty
   `editors/`). Fix `flake.nix`, `deploy.yml`, `build-eval.sh`, `highlight-bel.ts`.
   Gate: `nix build` green + `docs-site` build + eval bundle regenerates.
2. **Core** — `git mv` `lib bin tests bench tools → packages/core/`. Re-point the
   fixture plumbing. Gate: full `dune build` + `dune test` green (all alcotest
   suites + TS suites that read their own fixtures).
3. **Docs** — update `README.md` layout blurb and any `CLAUDE.md` path references
   to the new tree.

## Non-goals

- No hard package split (independent versioning/publishing) — that is a later
  step this layout merely enables.
- No `render-3d/` scaffold until the code exists.
- No renaming of internal package names (`beloch-render`, `@beloch/render-svg`,
  the `beloch` opam package) — directories move, names stay.
- No touching `scratch/ learn/ refs/ spike/` (gitignored or one-off).
