# VSCode Extension Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the shared VSCode extension shell at `editors/vscode/` so three subsystems (highlighting, LSP, preview) can afterward be built in parallel in disjoint file sets.

**Architecture:** A bun + esbuild TypeScript extension. `extension.ts` activates and delegates to per-subsystem init. All contribution slots (grammar, command, config, activation) are declared once in `package.json` here so no later agent edits it. Binary discovery is centralized in one pure, unit-tested function.

**Tech Stack:** TypeScript, bun (package manager + test runner), esbuild (bundler), `vscode` extension API, `vscode-languageclient`.

## Global Constraints

- Extension lives at `editors/vscode/` with its own `package.json` and `node_modules` (separate from the root `beloch-tools` package).
- Package manager is **bun**; bundle with esbuild.
- Language id is `beloch`; file extension `.bel`.
- Beloch line comments start with `;`. `--` is the crease sigil and MUST NOT be treated as a comment.
- `resolveBeloch` order: setting `beloch.path` → `beloch` on `PATH` → dev fallback `dune exec beloch --`.
- `package.json` is frozen after this foundation; later subsystems fill their own files only.
- All commits on branch `vscode-extension-foundation`.

---

### Task 1: Scaffold, build pipeline, and activation entrypoint

**Files:**
- Create: `editors/vscode/package.json`
- Create: `editors/vscode/tsconfig.json`
- Create: `editors/vscode/.vscodeignore`
- Create: `editors/vscode/.gitignore`
- Create: `editors/vscode/esbuild.mjs`
- Create: `editors/vscode/src/extension.ts`

**Interfaces:**
- Produces: `activate(context: vscode.ExtensionContext): void` and `deactivate(): void` exported from `src/extension.ts`. `activate` calls `registerLsp(context)` (Task 5) and `registerPreview(context)` (Task 6).

- [ ] **Step 1: Create `package.json`**

```json
{
  "name": "beloch",
  "displayName": "Beloch",
  "description": "Language support and live preview for the Beloch origami language",
  "version": "0.0.1",
  "publisher": "toph",
  "private": true,
  "engines": { "vscode": "^1.90.0" },
  "categories": ["Programming Languages"],
  "main": "./dist/extension.js",
  "activationEvents": [],
  "contributes": {},
  "scripts": {
    "compile": "node esbuild.mjs",
    "watch": "node esbuild.mjs --watch",
    "test": "bun test"
  },
  "devDependencies": {
    "@types/vscode": "^1.90.0",
    "@types/node": "^22.0.0",
    "esbuild": "^0.24.0",
    "typescript": "^5.5.0"
  },
  "dependencies": {
    "vscode-languageclient": "^9.0.1"
  }
}
```

- [ ] **Step 2: Create `tsconfig.json`**

```json
{
  "compilerOptions": {
    "module": "Node16",
    "moduleResolution": "Node16",
    "target": "ES2022",
    "lib": ["ES2022"],
    "sourceMap": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist"
  },
  "include": ["src"]
}
```

- [ ] **Step 3: Create `.vscodeignore`**

```
.vscode/**
src/**
esbuild.mjs
tsconfig.json
**/*.map
**/*.ts
node_modules/**
!node_modules/vscode-languageclient/**
```

- [ ] **Step 4: Create `.gitignore`**

```
node_modules/
dist/
*.vsix
```

- [ ] **Step 5: Create `esbuild.mjs`**

```js
import * as esbuild from "esbuild";

const watch = process.argv.includes("--watch");

const ctx = await esbuild.context({
  entryPoints: ["src/extension.ts"],
  bundle: true,
  format: "cjs",
  platform: "node",
  target: "node18",
  outfile: "dist/extension.js",
  external: ["vscode"],
  sourcemap: true,
  logLevel: "info",
});

if (watch) {
  await ctx.watch();
} else {
  await ctx.rebuild();
  await ctx.dispose();
}
```

- [ ] **Step 6: Create `src/extension.ts`**

```ts
import * as vscode from "vscode";
import { registerLsp } from "./lsp";
import { registerPreview } from "./preview";

export function activate(context: vscode.ExtensionContext): void {
  registerLsp(context);
  registerPreview(context);
}

export function deactivate(): void {}
```

Note: `./lsp` and `./preview` are created in Tasks 5 and 6. To keep this task's build green on its own, also create minimal placeholders now — they are overwritten later:

Create `editors/vscode/src/lsp.ts`:

```ts
import * as vscode from "vscode";

export function registerLsp(_context: vscode.ExtensionContext): void {}
```

Create `editors/vscode/src/preview.ts`:

```ts
import * as vscode from "vscode";

export function registerPreview(_context: vscode.ExtensionContext): void {}
```

- [ ] **Step 7: Install and build**

Run: `cd editors/vscode && bun install && bun run compile`
Expected: `bun install` completes; esbuild prints a line ending in `dist/extension.js` with no errors; `dist/extension.js` exists.

- [ ] **Step 8: Commit**

```bash
git add editors/vscode/package.json editors/vscode/tsconfig.json editors/vscode/.vscodeignore editors/vscode/.gitignore editors/vscode/esbuild.mjs editors/vscode/src/extension.ts editors/vscode/src/lsp.ts editors/vscode/src/preview.ts editors/vscode/bun.lock
git commit -m "feat(vscode): scaffold extension, build pipeline, activation entrypoint"
```

---

### Task 2: Language registration

**Files:**
- Modify: `editors/vscode/package.json` (add `contributes.languages`)
- Create: `editors/vscode/language-configuration.json`

**Interfaces:**
- Produces: a registered language id `beloch` bound to `.bel`, referenced by the grammar seam (Task 4) and the document selectors in Tasks 5 and 6.

- [ ] **Step 1: Create `language-configuration.json`**

```json
{
  "comments": {
    "lineComment": ";"
  },
  "brackets": [
    ["(", ")"],
    ["[", "]"]
  ],
  "autoClosingPairs": [
    ["(", ")"],
    ["[", "]"]
  ],
  "surroundingPairs": [
    ["(", ")"],
    ["[", "]"]
  ]
}
```

Note: no `--` block/line comment — `--` is the crease sigil in Beloch.

- [ ] **Step 2: Add the language to `package.json` `contributes`**

Replace `"contributes": {}` with:

```json
  "contributes": {
    "languages": [
      {
        "id": "beloch",
        "aliases": ["Beloch", "beloch"],
        "extensions": [".bel"],
        "configuration": "./language-configuration.json"
      }
    ]
  },
```

- [ ] **Step 3: Verify JSON validity**

Run: `cd editors/vscode && node -e "JSON.parse(require('fs').readFileSync('package.json','utf8')); JSON.parse(require('fs').readFileSync('language-configuration.json','utf8')); console.log('ok')"`
Expected: prints `ok`.

- [ ] **Step 4: Commit**

```bash
git add editors/vscode/package.json editors/vscode/language-configuration.json
git commit -m "feat(vscode): register the beloch language and comment/bracket config"
```

---

### Task 3: Centralized binary discovery (`resolveBeloch`)

**Files:**
- Create: `editors/vscode/src/beloch.ts`
- Create: `editors/vscode/src/beloch.test.ts`
- Modify: `editors/vscode/package.json` (add `contributes.configuration`)

**Interfaces:**
- Produces:
  - `resolveBelochArgv(deps: { configPath?: string; existsOnPath: (cmd: string) => boolean }): string[]` — pure, testable. Returns argv, e.g. `["beloch"]` or `["dune", "exec", "beloch", "--"]`.
  - `resolveBeloch(): string[]` — reads the `beloch.path` setting + does a real `PATH` check, then calls `resolveBelochArgv`. Consumers spawn `argv[0]` with `argv.slice(1)` plus their own subcommand (`lsp`, `fold`).

- [ ] **Step 1: Write the failing test**

Create `src/beloch.test.ts`:

```ts
import { test, expect } from "bun:test";
import { resolveBelochArgv } from "./beloch";

test("prefers the configured path", () => {
  const argv = resolveBelochArgv({ configPath: "/opt/beloch", existsOnPath: () => true });
  expect(argv).toEqual(["/opt/beloch"]);
});

test("falls back to PATH when no config", () => {
  const argv = resolveBelochArgv({ configPath: undefined, existsOnPath: (c) => c === "beloch" });
  expect(argv).toEqual(["beloch"]);
});

test("falls back to dune exec when not on PATH", () => {
  const argv = resolveBelochArgv({ configPath: undefined, existsOnPath: () => false });
  expect(argv).toEqual(["dune", "exec", "beloch", "--"]);
});

test("ignores an empty config path", () => {
  const argv = resolveBelochArgv({ configPath: "", existsOnPath: () => false });
  expect(argv).toEqual(["dune", "exec", "beloch", "--"]);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd editors/vscode && bun test src/beloch.test.ts`
Expected: FAIL — cannot resolve `./beloch` / `resolveBelochArgv` is not exported.

- [ ] **Step 3: Write the implementation**

Create `src/beloch.ts`:

```ts
import * as vscode from "vscode";
import { execSync } from "node:child_process";

export interface ResolveDeps {
  configPath?: string;
  existsOnPath: (cmd: string) => boolean;
}

/** Pure resolution logic. Returns the argv prefix to invoke beloch. */
export function resolveBelochArgv(deps: ResolveDeps): string[] {
  if (deps.configPath && deps.configPath.length > 0) return [deps.configPath];
  if (deps.existsOnPath("beloch")) return ["beloch"];
  return ["dune", "exec", "beloch", "--"];
}

function onPath(cmd: string): boolean {
  try {
    execSync(process.platform === "win32" ? `where ${cmd}` : `command -v ${cmd}`, {
      stdio: "ignore",
    });
    return true;
  } catch {
    return false;
  }
}

/** Resolve the beloch invocation from the current workspace configuration. */
export function resolveBeloch(): string[] {
  const configPath = vscode.workspace.getConfiguration("beloch").get<string>("path");
  return resolveBelochArgv({ configPath, existsOnPath: onPath });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd editors/vscode && bun test src/beloch.test.ts`
Expected: PASS — 4 tests pass.

- [ ] **Step 5: Add the `beloch.path` setting to `package.json`**

Inside `contributes`, after the `languages` array, add:

```json
    "configuration": {
      "title": "Beloch",
      "properties": {
        "beloch.path": {
          "type": "string",
          "default": "",
          "description": "Path to the beloch executable. Empty = look up `beloch` on PATH, then fall back to `dune exec beloch --`."
        }
      }
    }
```

- [ ] **Step 6: Verify build still compiles**

Run: `cd editors/vscode && bun run compile`
Expected: esbuild succeeds, `dist/extension.js` regenerated.

- [ ] **Step 7: Commit**

```bash
git add editors/vscode/src/beloch.ts editors/vscode/src/beloch.test.ts editors/vscode/package.json
git commit -m "feat(vscode): centralized beloch binary discovery with config + PATH fallback"
```

---

### Task 4: Grammar seam (highlighting stub)

**Files:**
- Create: `editors/vscode/syntaxes/beloch.tmLanguage.json`
- Modify: `editors/vscode/package.json` (add `contributes.grammars`)

**Interfaces:**
- Produces: a registered TextMate grammar with scope `source.beloch` and empty `patterns`. The highlighting subsystem later fills `patterns` in this file only.

- [ ] **Step 1: Create the stub grammar**

Create `syntaxes/beloch.tmLanguage.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/martinring/tmlanguage/master/tmlanguage.json",
  "name": "Beloch",
  "scopeName": "source.beloch",
  "patterns": []
}
```

- [ ] **Step 2: Register the grammar in `package.json`**

Inside `contributes`, after `configuration`, add:

```json
    "grammars": [
      {
        "language": "beloch",
        "scopeName": "source.beloch",
        "path": "./syntaxes/beloch.tmLanguage.json"
      }
    ]
```

- [ ] **Step 3: Verify JSON validity**

Run: `cd editors/vscode && node -e "JSON.parse(require('fs').readFileSync('syntaxes/beloch.tmLanguage.json','utf8')); JSON.parse(require('fs').readFileSync('package.json','utf8')); console.log('ok')"`
Expected: prints `ok`.

- [ ] **Step 4: Commit**

```bash
git add editors/vscode/syntaxes/beloch.tmLanguage.json editors/vscode/package.json
git commit -m "feat(vscode): grammar seam for the highlighting subsystem (empty stub)"
```

---

### Task 5: LSP client bootstrap seam

**Files:**
- Modify: `editors/vscode/src/lsp.ts` (replace the placeholder from Task 1)
- Modify: `editors/vscode/package.json` (add `activationEvents`)

**Interfaces:**
- Consumes: `resolveBeloch()` from `./beloch` (Task 3).
- Produces: `registerLsp(context: vscode.ExtensionContext): void` — starts a `LanguageClient` that spawns `beloch lsp`, scoped to `beloch` documents, and tolerates the server not yet existing (no crash, no error dialog).

- [ ] **Step 1: Replace `src/lsp.ts`**

```ts
import * as vscode from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind,
} from "vscode-languageclient/node";
import { resolveBeloch } from "./beloch";

let client: LanguageClient | undefined;

export function registerLsp(context: vscode.ExtensionContext): void {
  const argv = resolveBeloch();
  const serverOptions: ServerOptions = {
    command: argv[0],
    args: [...argv.slice(1), "lsp"],
    transport: TransportKind.stdio,
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: "file", language: "beloch" }],
    // The server is a stub today; do not surface its failures to the user.
    errorHandler: {
      error: () => ({ action: 1 /* Continue */ }),
      closed: () => ({ action: 1 /* DoNotRestart */ }),
    },
  };

  client = new LanguageClient("beloch", "Beloch Language Server", serverOptions, clientOptions);
  client.start();
  context.subscriptions.push({ dispose: () => client?.stop() });
}
```

Note on the error-handler magic numbers: `vscode-languageclient` exposes `ErrorAction.Continue = 1` and `CloseAction.DoNotRestart = 1`. Import and use the named enums instead of literals if the version in `node_modules` exports them cleanly; the literals are the documented fallback.

- [ ] **Step 2: Add `activationEvents` in `package.json`**

Replace `"activationEvents": []` with:

```json
  "activationEvents": ["onLanguage:beloch"],
```

- [ ] **Step 3: Build**

Run: `cd editors/vscode && bun run compile`
Expected: esbuild succeeds. `vscode-languageclient/node` bundles without error.

- [ ] **Step 4: Manual smoke test**

Run: `cd editors/vscode && code --extensionDevelopmentPath=$(pwd)` (if `code` CLI is available; otherwise note this as a manual step for the reviewer).
Open any `.bel` file. Expected: the extension activates, no error dialog appears even though `beloch lsp` is a stub. (If `code` CLI is unavailable, verify instead that `dist/extension.js` contains the string `Beloch Language Server` via `grep -q "Beloch Language Server" dist/extension.js && echo ok`.)

- [ ] **Step 5: Commit**

```bash
git add editors/vscode/src/lsp.ts editors/vscode/package.json
git commit -m "feat(vscode): LSP client bootstrap seam spawning beloch lsp"
```

---

### Task 6: Preview webview stub seam

**Files:**
- Modify: `editors/vscode/src/preview.ts` (replace the placeholder from Task 1)
- Modify: `editors/vscode/package.json` (add `contributes.commands`)

**Interfaces:**
- Produces: `registerPreview(context: vscode.ExtensionContext): void` — registers command `beloch.showPreview` that opens a webview panel beside the editor with placeholder content. The preview subsystem later fills rendering + cursor sync in this file.

- [ ] **Step 1: Replace `src/preview.ts`**

```ts
import * as vscode from "vscode";

export function registerPreview(context: vscode.ExtensionContext): void {
  const cmd = vscode.commands.registerCommand("beloch.showPreview", () => {
    const panel = vscode.window.createWebviewPanel(
      "belochPreview",
      "Beloch Preview",
      vscode.ViewColumn.Beside,
      { enableScripts: true },
    );
    panel.webview.html = `<!doctype html><html><body>
      <p>Beloch preview — rendering not implemented yet.</p>
    </body></html>`;
  });
  context.subscriptions.push(cmd);
}
```

- [ ] **Step 2: Register the command in `package.json`**

Inside `contributes`, after `grammars`, add:

```json
    "commands": [
      {
        "command": "beloch.showPreview",
        "title": "Beloch: Show Preview"
      }
    ]
```

- [ ] **Step 3: Build**

Run: `cd editors/vscode && bun run compile`
Expected: esbuild succeeds.

- [ ] **Step 4: Verify the command is wired**

Run: `cd editors/vscode && grep -q "beloch.showPreview" dist/extension.js && echo ok`
Expected: prints `ok`.

- [ ] **Step 5: Commit**

```bash
git add editors/vscode/src/preview.ts editors/vscode/package.json
git commit -m "feat(vscode): preview webview stub seam with beloch.showPreview command"
```

---

### Task 7: Foundation README (seam handoff doc)

**Files:**
- Create: `editors/vscode/README.md`

**Interfaces:**
- Produces: the handoff contract the three parallel subsystem agents read before starting — which files they own, what `package.json` already declares, and that they must not edit `package.json`.

- [ ] **Step 1: Create `README.md`**

```markdown
# Beloch VSCode extension

Shared foundation. Three subsystems build on top, each in a disjoint file set.
`package.json` is frozen — its contribution slots are all declared. If a
subsystem needs a new command/setting, flag it back rather than editing
`package.json` in parallel.

## Layout

- `src/extension.ts` — activation; delegates to `registerLsp` / `registerPreview`.
- `src/beloch.ts` — `resolveBeloch()` binary discovery. Everyone calls this.
- `language-configuration.json` — `;` comments, brackets. (`--` is a crease sigil, not a comment.)

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
```

- [ ] **Step 2: Commit**

```bash
git add editors/vscode/README.md
git commit -m "docs(vscode): foundation README + subsystem handoff contract"
```

---

## Self-Review

**Spec coverage:**
- Scaffold + build → Task 1. ✓
- Language registration (`;` comment, `--` not a comment, brackets) → Task 2. ✓
- `resolveBeloch()` + `beloch.path` setting + resolution order → Task 3. ✓
- Grammar seam (empty `patterns`) → Task 4. ✓
- LSP client bootstrap seam (foundation-owned, tolerates stub server) → Task 5. ✓
- Preview webview stub seam (foundation-owned, `beloch.showPreview`) → Task 6. ✓
- Frozen `package.json` + file-ownership handoff → Task 7 README. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. The intentional
placeholders in `src/lsp.ts`/`src/preview.ts` (Task 1) are explicitly overwritten in
Tasks 5/6 and exist only to keep Task 1's build green.

**Type consistency:** `resolveBeloch()` returns `string[]` (argv) in Task 3; consumed as
argv in Task 5 (`argv[0]`, `argv.slice(1)`). `registerLsp`/`registerPreview` signatures match
between Task 1 (placeholder), Tasks 5/6 (real), and their call sites in `extension.ts`.
