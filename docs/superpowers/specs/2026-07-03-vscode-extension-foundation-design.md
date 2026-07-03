# VSCode extension — foundation

**Status:** approved
**Date:** 2026-07-03

## Goal

Ship the shared shell for a Beloch VSCode extension so that three independent
subsystems — syntax highlighting, LSP features, live preview — can afterward be
specced and built in parallel by separate agents, each touching a disjoint set
of files. The foundation itself ships nothing user-visible beyond language
registration; its job is to nail the seams.

## Scope

**In:** extension scaffold, language registration, the shared binary-resolution
contract, and three pre-stamped contribution slots (grammar file, LSP client
bootstrap, preview webview stub).

**Out:** the real TextMate grammar, the OCaml `beloch lsp` server, and real
rendering / cursor sync. Each is a later subsystem with its own
spec → plan → build cycle.

## Location & toolchain

- Lives at `editors/vscode/` (new top-level, room for `editors/neovim/` etc.).
- Package manager: **bun** (repo already has `bun.lock`); bundle with esbuild.
- TypeScript, per [decision 0001](../../../decisions/0001-ocaml-core-typescript-edge.md)
  (tooling at the edges is TS).

## Components

### 1. Scaffold

- `package.json` — name `beloch`, publisher, `engines.vscode`, `main` pointing at
  the esbuild bundle, `activationEvents`.
- `tsconfig.json`, `.vscodeignore`, esbuild build script wired through bun.
- `src/extension.ts` — `activate()` / `deactivate()`, which call the three
  subsystem init functions (`registerLsp`, `registerPreview`; the grammar is
  declarative and needs no runtime init).

### 2. Language registration (final — no agent touches this)

- `contributes.languages`: id `beloch`, extension `.bel`, an alias.
- `language-configuration.json`:
  - **Line comment: `;`** (Beloch comments run `;` to end of line).
  - Brackets / autoclose for `( )` and `[ ]`.
  - **`--` is the crease sigil, NOT a comment.** Must not be configured as one.

### 3. Shared contract: `src/beloch.ts`

- `resolveBeloch(): string[]` (argv prefix) — resolution order:
  1. workspace setting `beloch.path`,
  2. `beloch` on `PATH`,
  3. dev fallback `dune exec beloch --`.
- Setting `beloch.path` declared in `contributes.configuration`.
- Single choke point; both the LSP client and the preview invoke only this.

### 4. Three pre-stamped seams

`package.json` is the one shared file. The foundation writes **all** contribution
slots up front; after that no agent edits `package.json`, so each agent works in a
disjoint file set and there are no merge collisions.

| Subsystem | Foundation stamps | Agent owns |
| --- | --- | --- |
| **1 Highlighting** | `contributes.grammars` → `syntaxes/beloch.tmLanguage.json` (stub: empty `patterns`) | the grammar JSON only |
| **2 LSP** | `activationEvents` + a minimal `LanguageClient` bootstrap in `src/lsp.ts` that spawns `resolveBeloch() lsp` | OCaml `beloch lsp` server + client capabilities |
| **3 Preview** | `contributes.commands` `beloch.showPreview` + a webview stub in `src/preview.ts` (placeholder content) | FOLD→SVG rendering (reuse `tools/fold2svg.mjs`) + cursor sync |

Both the LSP client bootstrap (seam 2) and the preview webview stub (seam 3) are
**foundation-owned**: each agent inherits a running shell rather than starting
from zero.

## What the foundation deliberately does not do

- No real grammar — `syntaxes/beloch.tmLanguage.json` ships with empty `patterns`.
- No LSP server — the OCaml `lsp` subcommand stays a stub; the TS client starts,
  attempts to connect, and tolerates the server not implementing anything yet.
- No real rendering — the webview shows a placeholder.

## Interface contracts (the seams that keep agents independent)

- **Binary:** everyone calls `resolveBeloch()`; nobody re-implements discovery.
- **Language id `beloch`:** all three subsystems key off the same document
  selector.
- **`package.json`:** frozen after the foundation. New commands/settings a
  subsystem needs are flagged back to the foundation, not edited in parallel.
- **File ownership:** grammar → `syntaxes/`; LSP → `src/lsp.ts` + OCaml
  `bin`/`lib`; preview → `src/preview.ts` + assets. No overlap.

## Related

- [#42](https://git.toph.so/toph/beloch/issues/42) — per-step folded frames for
  interpolation; the folded-preview driver for subsystem 3.
- [#31](https://git.toph.so/toph/beloch/issues/31) — exact coords + per-face
  isometries in `beloch:*`; prerequisite for exact interpolation.
- [decision 0004](../../../decisions/0004-menhir-then-treesitter.md) — TextMate
  grammar is the accepted stopgap before a hand-written Tree-sitter grammar.
