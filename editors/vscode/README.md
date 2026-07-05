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

## Running the extension

### Development (dev-host)

```bash
bun install
bun run compile
```

Then either press **F5** (repo root `.vscode/launch.json` has a "Run Beloch
Extension" launch config that starts an Extension Development Host with this
folder loaded — re-run `bun run compile` after edits, there's no
`preLaunchTask` wired up), or run manually:

```bash
code --extensionDevelopmentPath=$(pwd)
```

In the new window, open a `.bel` file (e.g. `examples/syntax/cube-root.bel`).

### Dogfooding (stable, installed)

To install the extension into your normal VSCode as a regular extension
(rather than an Extension Development Host window):

```bash
bun run dogfood
```

This packages `dist/extension.js` and friends into `beloch.vsix`
(`bun run package`, via `vsce package --no-dependencies` — dependencies
are bundled by esbuild, so vsce doesn't need to vendor `node_modules`) and
installs it with `code --install-extension beloch.vsix --force`. Re-run to
update after making changes.

The dogfooded extension needs a `beloch` binary. Either:

- set `beloch.path` in VSCode settings to a stable binary (e.g. the result of
  `direnv exec . dune build` — a standalone binary at
  `<repo>/_build/default/bin/main.exe`, RPATH-baked so it runs without
  direnv), or
- rely on the `dune exec beloch --` fallback, which only works if the
  workspace you open is the beloch repo itself with the flake devShell
  loaded (this repo's `.vscode/settings.json` does that via the direnv
  extension).

## Manual smoke test

Run the extension (dev-host or dogfooded), open `examples/syntax/cube-root.bel`, run
**Beloch: Show Preview**, and verify:

- the folded diagram appears;
- moving the cursor between `step` panels (sync on) changes the shown step;
- the CP/folded toggle switches between crease pattern and folded views;
- turning sync off lets prev/next step through manually;
- checking/unchecking a named construction in the checklist shows/hides its
  `.center`-style overlay;
- the current step's crease is highlighted;
- introducing a syntax error surfaces the diagnostic;
- placing the cursor before the first `step` shows the flat baseline frame.
