# Beloch VSCode extension

Shared foundation. Three subsystems build on top, each in a disjoint file set.
`package.json` is frozen — its contribution slots are all declared. If a
subsystem needs a new command/setting, flag it back rather than editing
`package.json` in parallel. `src/extension.ts`, `src/beloch.ts`, and
`language-configuration.json` are likewise foundation-owned and frozen —
subsystem agents flag changes back rather than editing them in parallel.

## Layout

- `src/extension.ts` — activation; delegates to `registerLsp` / `registerPreview`.
- `src/beloch.ts` — `resolveBeloch()` binary discovery. Everyone calls this.
- `language-configuration.json` — `;` comments, brackets. (`--` is a crease sigil, not a comment.)

## Binary discovery

`resolveBeloch()` returns an argv prefix. Consumers must spawn it with `cwd`
set to the workspace folder — the `dune exec beloch --` dev fallback requires
it to resolve the project.

## Subsystem ownership

| Subsystem | Owns | Contribution slot (already declared) |
| --- | --- | --- |
| Highlighting | `syntaxes/beloch.tmLanguage.json` (`patterns`) | `contributes.grammars` |
| LSP | `src/lsp.ts` client caps + the OCaml `beloch lsp` server | `activationEvents`, client bootstrap |
| Preview | `src/preview.ts` rendering + cursor sync | `contributes.commands` `beloch.showPreview` |

## Dev

- `bun install`
- `bun run compile` (or `bun run watch`)
- `bun test`

Subsystems may extend `devDependencies` and `scripts` additively (each needs its
own test tooling); only the `contributes` blocks are frozen.
