# Design: Dogfooding blog tooling (`build`)

**Date:** 2026-06-28
**Status:** approved (brainstorming) — pending implementation plan

## Problem

While developing Beloch, the author wants to write a development blog whose
posts (a) narrate what happened across git history, specs, and ADRs, and (b)
contain `.bel` code examples that **compile to images**, so Beloch dogfoods
itself in its own write-up. Beloch emits FOLD JSON today but has no image
renderer (`beloch render` is a stub).

## Decisions made during brainstorming

| Question | Decision |
|---|---|
| Narrator | An **agent** (Claude) reads git/specs/examples and writes the prose. No prose-generation code. |
| Renderer | **Rabbit Ear** (JS lib) directly: FOLD JSON → SVG. No own renderer in the OCaml core. |
| Blog host | **Markdown in the repo** under `blog/`; generated SVGs alongside. SSG-agnostic, publishable later. |
| Post unit | **Free / thematic** — the agent decides scope, references commits/files manually. |
| Session logs | **Out of scope for v1.** git + specs + `.bel` examples only. |
| Example embedding | **Both** inline ` ```bel ` fences *and* referenced `.bel` files. |
| Tool | A single deterministic command, **`build`** (preprocessor + renderer). The agent is the scaffold; no `new`/scaffold command. |
| Agent docs | **`blog/README.md`** — the single source of truth for conventions. |

## Architecture

A small TypeScript edge tool (per [ADR 0001](../../../decisions/0001-ocaml-core-typescript-edge.md)),
living at `tools/blog/`. One user-facing command, `build`, plus an internal
`fold2svg` module.

### Pipeline

```
.bel ──(beloch fold, subprocess)──▶ .fold JSON ──(Rabbit Ear)──▶ .svg
```

The renderer is FOLD-generic: it draws whatever the FOLD contains. Today that is
crease patterns; when Beloch later emits folded states, the same path renders
them with no change here.

### Components (each one clear purpose)

1. **`fold2svg`** (internal module) — input: FOLD JSON; output: SVG string, via
   Rabbit Ear. Knows nothing about Markdown or git. Unit-testable in isolation
   against FOLD fixtures.

2. **`build`** (the command) — Markdown preprocessor over `blog/*.md`:
   - Finds inline ` ```bel ` fenced blocks **and** `bel:<path>` file references.
   - For each: runs `beloch fold` (subprocess) → `fold2svg` → SVG.
   - Writes SVGs to `blog/assets/<post-slug>/<n>.svg`.
   - Emits processed Markdown with an `![](…svg)` image link inserted directly
     under the source block.
   - **Idempotent:** re-running produces the same output; regenerates stale SVGs.

### Layout

```
blog/
  README.md            conventions (fence syntax, bel: refs, asset location, how to build)
  <post>.md            post source (hand-written prose + bel examples)
  assets/<post>/*.svg  generated images
tools/blog/
  package.json
  src/
    build.ts           the command
    fold2svg.ts        FOLD → SVG (Rabbit Ear)
```

### Embedding syntax (to be finalized in `blog/README.md`)

- **Inline:** a fenced block tagged `bel` — its source is rendered and an image
  inserted below it. Source stays visible (literate style); single source of
  truth, cannot drift from the image.
- **Referenced:** a marker like `bel:examples/diagonals.bel` (exact form settled
  during implementation) — renders that file and inserts the image; used for
  shared/larger examples that live as real files.

## Output / format

SVG (Rabbit Ear native). Crease patterns now; folded states automatically once
Beloch emits them.

## Out of scope (v1)

Session-log mining, SSG/frontmatter integration, RDF/Aleph Garden, autonomous
prose generation, an OCaml-native renderer, a `new`/scaffold command.

## Testing

- `fold2svg`: FOLD fixtures → snapshot SVG.
- `build`: a minimal post fixture containing one inline block and one `bel:`
  reference → assert SVGs written and image links inserted; assert idempotency.
- Integration: build a real post against the existing `examples/*.bel`.

## Open implementation details (for the plan)

- Exact `bel:` reference marker syntax.
- Node toolchain choice (plain tsc / tsx / bun) and how it's wired into the Nix
  devshell.
- Whether `build` edits posts in place or writes to a separate output dir.
- Rabbit Ear SVG styling defaults (stroke per assignment M/V/B/U, size).
