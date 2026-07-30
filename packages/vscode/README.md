# Beloch VSCode extension

Scaffolding plus syntax highlighting. Nothing else: the extension contributes
the `beloch` language id, its TextMate grammar and its bracket/comment
configuration, and `activate()` registers nothing. Editor integration beyond
highlighting (live preview, language server) is to be built on the
`packages/www` playground — the same CodeMirror editor, worker-hosted
evaluator and SVG rendering the docs site already runs — rather than on a
spawned `beloch` binary.

## Layout

- `package.json` — the manifest: language id, grammar, activation.
- `src/extension.ts` — activation seam; currently empty.
- `language-configuration.json` — `;` comments, brackets. (`--` is a crease sigil, not a comment.)
- `syntaxes/beloch.tmLanguage.json` — the TextMate grammar.
- `test/grammar/*.bel` — grammar assertions, run by `vscode-tmgrammar-test`.

## Dev

- `bun install`
- `bun run compile` (or `bun run watch`)
- `bun run test` (grammar assertions — `bun test` is bun's own runner and finds nothing here)

## Running the extension

Press **F5** — the repo root `.vscode/launch.json` has a "Run Beloch Extension"
config that starts an Extension Development Host with this folder loaded
(re-run `bun run compile` after edits, there's no `preLaunchTask` wired up).
Or manually:

```bash
code --extensionDevelopmentPath=$(pwd)
```

In the new window, open a `.bel` file (e.g. `examples/bases/kite.bel`) and
check that it is highlighted.

To install into your normal VSCode instead of a dev host:

```bash
bun run dogfood
```

This packages the extension into `beloch.vsix` (`vsce package
--no-dependencies` — esbuild bundles everything, so vsce need not vendor
`node_modules`) and installs it with `code --install-extension`.
