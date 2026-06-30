# Beloch documentation site — design (Slice 1)

**Date:** 2026-06-30
**Status:** Approved (brainstorm)
**Worktree branch:** `feat/docs-site`

## Goal

An MDX-based documentation site that (a) specifies the Beloch language and (b)
teaches it via a guide, with Beloch embedded **as a renderer** so `.bel` source
turns into living folding diagrams inline. Architecture is laid out for a
**hybrid** renderer: static build-time rendering now, an in-browser live
renderer (js_of_ocaml) as a later slice — behind the same component API.

## Decisions (from brainstorm)

| Question | Decision |
|---|---|
| Renderer integration | **Hybrid** — static build-time now; js_of_ocaml playground later, same API |
| Host framework | **Astro + Starlight** |
| Slice scope | Scaffold + pipeline + **spec migrated** + **guide skeleton** |
| Build-time coupling | **Live at site build** — runs `beloch fold` + fold2svg during `astro build` (dev shell provides OCaml/dune) |
| Site directory | `site/` |
| Spec source of truth | **Site becomes canon** — `spec/SPECIFICATION.md` reduced to a pointer stub; MDX spec pages are authoritative |
| Example source | **Both** — `<Beloch>` accepts `src=` path (e.g. `examples/*.bel`) **or** inline code |

## Architecture

### Layers

```
.bel source ──> beloch fold (OCaml CLI) ──> FOLD JSON ──> fold2svg ──> SVG
   (MDX / examples/)        │                              │
                            └────── render boundary ───────┘
                                  site/src/lib/beloch-render.ts
                                            │
                                  <Beloch> Astro component
                                            │
                                       MDX pages
```

### Render boundary — `site/src/lib/beloch-render.ts`

The **single** place that turns `.bel` into a diagram. Everything that needs a
diagram goes through here, so the renderer implementation can be swapped (static
→ live js_of_ocaml) without touching component or content.

Responsibilities:
- Accept Beloch source (string) + a filename label (for error messages).
- Spawn `beloch fold` on the source, capture FOLD JSON from stdout.
- Pipe FOLD to `tools/fold2svg.mjs` (reuse the existing renderer): once for the
  crease pattern (frame 0), once with `--folded` for the folded form, as needed.
- Return `{ creaseSvg?, foldedSvg? }` strings.
- **Errors are loud:** if `beloch fold` exits non-zero, throw with the filename
  + Beloch's stderr message so `astro build` fails pointing at the offending
  snippet. No silent broken diagram.

Binary resolution (in order): explicit `BELOCH_BIN` env → built
`../result/bin/beloch` / `../_build/.../beloch` → `dune exec beloch --` from repo
root → `beloch` on PATH. The dev shell (flake) provides the toolchain; this is
the documented build prerequisite.

fold2svg reuse: invoke `tools/fold2svg.mjs` via Bun, piping FOLD over stdin
(`-`) and reading SVG from stdout (it already supports `-`/stdin and `--folded`).
No fork of the renderer.

### `<Beloch>` component — `site/src/components/Beloch.astro`

Hybrid-ready, stable prop API:

| Prop | Type | Default | Meaning |
|---|---|---|---|
| `src` | string | — | path to a `.bel` file (repo-relative, e.g. `examples/fold-half.bel`) |
| `code` (slot) | string | — | inline `.bel` source (alternative to `src`) |
| `view` | `"crease" \| "folded" \| "both"` | `"both"` | which diagram(s) to show |
| `showCode` | boolean | `true` | render the source alongside the diagram |
| `title` | string | derived | caption / label |

- Exactly one of `src` / inline code must be given (error otherwise).
- Slice 1 renders static SVG via the boundary at build time, source + diagram(s)
  side by side.
- Future `live` path (js_of_ocaml) slots in behind the same props; MDX authors
  don't change anything.

Optional convenience: a remark plugin mapping ```` ```beloch ```` fenced blocks
to `<Beloch>` with inline code. **Deferred** unless trivial — the component is
the primary interface (YAGNI; add the fence sugar only if it falls out cheaply).

### Content — Starlight sidebar

```
index.mdx                         Landing
Guide/
  getting-started.mdx             real: install + first run
  installation.mdx                real
  first-fold.mdx                  real: living diagram(s)
  axioms-tour.mdx                 stub (one worked axiom example)
Specification/
  <pages split from SPECIFICATION.md>   migrated, living diagrams at examples
```

- Spec pages are authored as MDX, split from the current `spec/SPECIFICATION.md`
  along its existing structure. Living `<Beloch>` diagrams replace prose-only
  examples where one exists.
- `spec/SPECIFICATION.md` is reduced to a short pointer stub ("the canonical
  specification now lives in the site, see `site/`"). Git history preserves the
  old text.

### Tooling

- `site/package.json` (Bun): `dev`, `build`, `preview` scripts (astro).
- Build prerequisite: Beloch binary buildable (`dune build` / nix) — documented
  in `site/README.md`.
- Root `tools/fold2svg.mjs` reused as-is (no changes expected).

## Error handling

- Missing/failed binary → boundary throws a clear "Beloch binary not found / set
  BELOCH_BIN" message.
- Snippet fails to evaluate → build fails with file + Beloch error span.
- Both `src` and inline code, or neither → component throws at build.

## Testing / verification

1. `cd site && bun run build` exits 0.
2. Boundary unit test: feed a known `examples/*.bel`, assert returned SVG
   contains `<svg` and the expected number of `beloch:`/edge markers (headless,
   no browser).
3. Built pages contain the diagrams (spot check; reuse the PR-screenshot
   workflow to attach renders to the PR).
4. Intentionally-broken snippet makes the build fail loudly (negative test).

## Out of scope (this slice)

- js_of_ocaml live renderer / playground (later slice; API reserved).
- Deploy to beloch.toph.so / beloch.dev (later; build is deploy-agnostic).
- Search tuning, versioning, i18n beyond Starlight defaults.
- Auto-sync between `spec/SPECIFICATION.md` and MDX (the stub removes the need).
- remark ```beloch fence sugar unless trivial.

## Follow-ups

- js_of_ocaml renderer behind `<Beloch live>`.
- Deploy pipeline (CI builds in the nix dev shell).
- Blog section (`blog/` already exists) once the guide settles.
