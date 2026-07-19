# packages/ Monorepo Layout — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every shippable component under a single `packages/` tree
(`core`, `eval-web`, `render-2d`, `www`, `grammar`, `vscode`) while keeping one
dune-project and one nix flake, so the repo root stops sprawling as new targets
(3D render, more libs) land.

**Architecture:** Pure directory reorganization via `git mv` (history preserved).
OCaml needs no source edits — dune resolves deps by library name, not path. Only
build-orchestration files (flake, CI, build scripts, test fixture-path plumbing)
carry hard-coded paths and must be re-pointed. Peripheral packages move first
behind cheap build gates; the OCaml core moves last behind a full green-tests gate.

**Tech Stack:** OCaml + dune + menhir + FLINT (nix), TypeScript + bun (render,
www), tree-sitter grammar, GitHub Actions → Cloudflare Pages.

## Global Constraints

- Every move is `git mv` — never delete+recreate (preserve history).
- Each package's path fixes land in the **same commit** as its move.
- `examples/` and project meta (`decisions/ notes/ paper/ spec/ docs/`) stay at
  root. `refs/ scratch/ learn/ spike/` are untouched as directories (their
  *contents* get path fixes only where noted).
- No internal package renames: `beloch` (opam), `beloch-render`,
  `@beloch/render-svg` keep their names; only directories move.
- Do NOT scaffold `packages/render-3d/` — it has no code yet (YAGNI).
- Spec: `docs/superpowers/specs/2026-07-19-packages-monorepo-layout-design.md`.
- Working in worktree `feat/packages-layout` (branched from `main` @ `36f6ae7`).
  Pre-existing uncommitted `site/` edits in the main checkout are out of scope —
  the user reconciles them at integration time.

---

### Task 1: Leaf packages — grammar + vscode

The two components with **no build-graph coupling**. `tree-sitter-beloch` is
referenced only by itself and by comments; `editors/vscode` only by
`.vscode/launch.json`.

**Files:**
- Move: `tree-sitter-beloch/ → packages/grammar/`
- Move: `editors/vscode/ → packages/vscode/` (then remove empty `editors/`)
- Modify: `.vscode/launch.json:9`

**Interfaces:**
- Produces: directories `packages/grammar/`, `packages/vscode/`. No downstream
  task depends on their new paths.

- [ ] **Step 1: Move the directories**

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p packages
git mv tree-sitter-beloch packages/grammar
git mv editors/vscode packages/vscode
rmdir editors 2>/dev/null || true
```

- [ ] **Step 2: Fix the VS Code extension debug path**

In `.vscode/launch.json` line 9:

```
- "--extensionDevelopmentPath=${workspaceFolder}/editors/vscode",
+ "--extensionDevelopmentPath=${workspaceFolder}/packages/vscode",
```

- [ ] **Step 3: Verify no stale references remain**

Run: `rg -n 'tree-sitter-beloch/|editors/vscode|editors/' -g '!_build' -g '!node_modules' -g '!*.md' -g '!docs/superpowers'`
Expected: no hits outside `packages/grammar` / `packages/vscode` internals.
(Markdown/doc mentions are cosmetic and handled in Task 6.)

- [ ] **Step 4: Confirm the tree still builds (unaffected)**

Run: `nix build .#beloch 2>&1 | tail -3`
Expected: builds green (neither dir is in the OCaml build graph).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(layout): move grammar + vscode under packages/"
```

---

### Task 2: render-2d

Moves the bun render workspace. Referenced by `flake.nix` (devShell shellHook),
CI path filter, the spike verify script, and doc comments.

**Files:**
- Move: `render/ → packages/render-2d/`
- Modify: `flake.nix:91-92` (and comments `72`? no — `81`, `84-85`)
- Modify: `.github/workflows/deploy.yml:8`
- Modify: `spike/render-fish-base.ts:16-17`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `packages/render-2d/` containing the `scene` + `render-svg` bun
  workspace unchanged (internal `workspaces: ["scene","render-svg"]` still valid).

- [ ] **Step 1: Move the directory**

```bash
cd "$(git rev-parse --show-toplevel)"
git mv render packages/render-2d
```

- [ ] **Step 2: Fix flake.nix shellHook paths**

`flake.nix` lines 91-92:

```
-            ( cd "$root/render" && bun install --silent ) >/dev/null 2>&1
-            ( cd "$root/render/render-svg" && bun link --silent ) >/dev/null 2>&1
+            ( cd "$root/packages/render-2d" && bun install --silent ) >/dev/null 2>&1
+            ( cd "$root/packages/render-2d/render-svg" && bun link --silent ) >/dev/null 2>&1
```

Also update the two comments for accuracy (line 81 `render/render-svg` →
`packages/render-2d/render-svg`; line 84-85 mention of `bin/main.ml` is fine).

- [ ] **Step 3: Fix CI path filter**

`.github/workflows/deploy.yml` line 8:

```
-      - 'render/**'
+      - 'packages/render-2d/**'
```

- [ ] **Step 4: Fix spike verify-script imports**

`spike/render-fish-base.ts` lines 16-17:

```
- import { parseFold } from "../render/scene/src/index";
- import { renderFolded, WEB_THEME } from "../render/render-svg/src/index";
+ import { parseFold } from "../packages/render-2d/scene/src/index";
+ import { renderFolded, WEB_THEME } from "../packages/render-2d/render-svg/src/index";
```

- [ ] **Step 5: Verify the render workspace installs at its new path**

Run: `cd packages/render-2d && bun install --silent && bun link --silent && cd -`
Expected: exits 0; `beloch-render` bin links.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(layout): move render bun workspace to packages/render-2d"
```

---

### Task 3: eval-web

Moves the js_of_ocaml browser eval bundle. Referenced by CI (bundle regen), the
spike wasm builder, and a flake comment.

**Files:**
- Move: `web/ → packages/eval-web/`
- Modify: `.github/workflows/deploy.yml:45-46`
- Modify: `spike/build.sh:128`
- Modify: `flake.nix:72` (comment)

**Interfaces:**
- Consumes: nothing.
- Produces: `packages/eval-web/`; dune target still `beloch_web` (built via
  `dune build packages/eval-web/`), output at
  `_build/default/packages/eval-web/beloch_web.bc.js`.

- [ ] **Step 1: Move the directory**

```bash
cd "$(git rev-parse --show-toplevel)"
git mv web packages/eval-web
```

- [ ] **Step 2: Fix CI bundle-regen step**

`.github/workflows/deploy.yml` lines 45-46:

```
-          nix develop --command dune build web/ --profile release
-          cp _build/default/web/beloch_web.bc.js site/public/beloch/beloch-eval.js
+          nix develop --command dune build packages/eval-web/ --profile release
+          cp _build/default/packages/eval-web/beloch_web.bc.js packages/www/public/beloch/beloch-eval.js
```

(The `packages/www/` destination is set once `site` moves in Task 4; ordering is
fine because CI only runs on `main`, not on this branch mid-migration.)

- [ ] **Step 3: Fix spike wasm builder WEB_DIR**

`spike/build.sh` line 128:

```
- WEB_DIR="$(cd "$SPIKE_DIR/../web" && pwd)"
+ WEB_DIR="$(cd "$SPIKE_DIR/../packages/eval-web" && pwd)"
```

- [ ] **Step 4: Fix flake comment (line 72)**

```
-            # js_of_ocaml spike (web/) — browser eval bundle, rational fragment
+            # js_of_ocaml (packages/eval-web/) — browser eval bundle, rational fragment
```

- [ ] **Step 5: Verify the bundle builds at its new path**

Run: `nix develop --command dune build packages/eval-web/ --profile release --root "$(git rev-parse --show-toplevel)" 2>&1 | tail -5`
Expected: green; `_build/default/packages/eval-web/beloch_web.bc.js` exists.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(layout): move js_of_ocaml eval bundle to packages/eval-web"
```

---

### Task 4: www

Moves the public web frontend (landing + docs + Playground). Carries its own
`scripts/build-eval.sh` (whose repo-root computation deepens by one level), and
is referenced by CI working-dirs and the spike output path.

**Files:**
- Move: `site/ → packages/www/`
- Modify: `packages/www/scripts/build-eval.sh:11,17,20,21,23,27`
- Modify: `.github/workflows/deploy.yml:7,49,56`
- Modify: `spike/build.sh:129`
- Modify: `spike/render-fish-base.ts:40,45`

**Interfaces:**
- Consumes: eval bundle from Task 3 (`_build/default/packages/eval-web/...`).
- Produces: `packages/www/`; site build reads its own `src/grammar/*` (internal,
  no change) and the committed `public/beloch/*` artifacts.

- [ ] **Step 1: Move the directory**

```bash
cd "$(git rev-parse --show-toplevel)"
git mv site packages/www
```

- [ ] **Step 2: Fix build-eval.sh repo-root depth + build paths**

`packages/www/scripts/build-eval.sh`:

Line 11 (script is now two levels deeper: `packages/www/scripts` → repo root is 3 up):

```
- repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
+ repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
```

Line 17:

```
- nix develop --command dune build web/ --profile release --root "$repo_root"
+ nix develop --command dune build packages/eval-web/ --profile release --root "$repo_root"
```

Lines 19-23 (source + destination):

```
- cp \
-   "$repo_root/_build/default/web/beloch_web.bc.js" \
-   "$repo_root/site/public/beloch/beloch-eval.js"
-
- echo "Wrote site/public/beloch/beloch-eval.js ($(du -h "$repo_root/site/public/beloch/beloch-eval.js" | cut -f1))"
+ cp \
+   "$repo_root/_build/default/packages/eval-web/beloch_web.bc.js" \
+   "$repo_root/packages/www/public/beloch/beloch-eval.js"
+
+ echo "Wrote packages/www/public/beloch/beloch-eval.js ($(du -h "$repo_root/packages/www/public/beloch/beloch-eval.js" | cut -f1))"
```

Line 27 (the qqbar-wasm echo):

```
-   echo "Wrote site/public/beloch/qqbar-wasm.js ($(du -h "$repo_root/site/public/beloch/qqbar-wasm.js" | cut -f1))"
+   echo "Wrote packages/www/public/beloch/qqbar-wasm.js ($(du -h "$repo_root/packages/www/public/beloch/qqbar-wasm.js" | cut -f1))"
```

- [ ] **Step 3: Fix CI path filter + working dirs**

`.github/workflows/deploy.yml`:

```
Line 7:   -      - 'site/**'          →  +      - 'packages/www/**'
Line 49:  -        working-directory: site   →  +        working-directory: packages/www
Line 56:  -          workingDirectory: site  →  +          workingDirectory: packages/www
```

- [ ] **Step 4: Fix spike output path (OUT_DIR)**

`spike/build.sh` line 129:

```
- OUT_DIR="$(cd "$SPIKE_DIR/.." && pwd)/site/public/beloch"
+ OUT_DIR="$(cd "$SPIKE_DIR/.." && pwd)/packages/www/public/beloch"
```

- [ ] **Step 5: Fix spike verify-script artifact paths**

`spike/render-fish-base.ts` lines 40 and 45:

```
- ...path.join(repoRoot, "site/public/beloch/qqbar-wasm.js")...
+ ...path.join(repoRoot, "packages/www/public/beloch/qqbar-wasm.js")...
- loadAsScript(path.join(repoRoot, "site/public/beloch/beloch-eval.js"));
+ loadAsScript(path.join(repoRoot, "packages/www/public/beloch/beloch-eval.js"));
```

- [ ] **Step 6: Verify the site builds and the bundle regenerates**

Run:
```bash
packages/www/scripts/build-eval.sh 2>&1 | tail -3
cd packages/www && bun install --silent && bun run build 2>&1 | tail -5 && cd -
```
Expected: build-eval writes `packages/www/public/beloch/beloch-eval.js`;
`bun run build` produces `packages/www/dist` green.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(layout): move site to packages/www (landing+docs+playground)"
```

---

### Task 5: core (lib + bin + tests + bench + tools)

The OCaml core. No `.ml`/`.mli` source edits (dune resolves by library name).
Only CI path filters, `bench/run.sh`, and the test fixture-path plumbing change.
This is the highest-risk task — gate on the full test suite.

**Files:**
- Move: `lib/ bin/ tests/ bench/ tools/ → packages/core/`
- Modify: `.github/workflows/deploy.yml:9-10`
- Modify: `packages/core/bench/run.sh:15,18,19`
- Modify: `packages/core/tests/dune:36`
- Modify: `packages/core/tests/test_eval.ml:613`
- Modify: `packages/core/tests/test_e2e.ml:13,23,24`
- Modify: `packages/core/tests/test_bel_assert.ml:10,11`
- Modify: `packages/core/tests/test_golden.ml:10`

**Interfaces:**
- Consumes: nothing from prior tasks (independent of render/www).
- Produces: `packages/core/{lib,bin,tests,bench,tools}`; the `beloch` library
  and `beloch` executable keep their names, discoverable from anywhere in the
  dune project.

- [ ] **Step 1: Move the directories**

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p packages/core
git mv lib packages/core/lib
git mv bin packages/core/bin
git mv tests packages/core/tests
git mv bench packages/core/bench
git mv tools packages/core/tools
```

- [ ] **Step 2: Fix CI path filters**

`.github/workflows/deploy.yml` lines 9-10:

```
-      - 'lib/**'
-      - 'bin/**'
+      - 'packages/core/lib/**'
+      - 'packages/core/bin/**'
```

- [ ] **Step 3: Fix bench/run.sh depth + dune paths**

`packages/core/bench/run.sh`:

Line 15 (now three levels deep: `packages/core/bench` → repo root is 3 up):

```
- ROOT="$(cd "$(dirname "$0")/.." && pwd)"
+ ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
```

Lines 18-19:

```
- dune build bench/bench_real_roots.exe 2>&1 || { echo "build failed" >&2; exit 1; }
- EXE="$ROOT/_build/default/bench/bench_real_roots.exe"
+ dune build packages/core/bench/bench_real_roots.exe 2>&1 || { echo "build failed" >&2; exit 1; }
+ EXE="$ROOT/_build/default/packages/core/bench/bench_real_roots.exe"
```

- [ ] **Step 4: Fix the `examples` source_tree dep in tests/dune**

`packages/core/tests/dune` line 36 (dune file is now at
`packages/core/tests/`, so repo-root `examples/` is 3 up):

```
-  (deps (source_tree ../examples) (source_tree golden)))
+  (deps (source_tree ../../../examples) (source_tree golden)))
```

Contingency: if dune rejects the `../../../examples` climb above the package
dir, drop `(source_tree ../../../examples)` entirely (leave `(source_tree
golden)`). test_golden reads `examples/` at runtime via the absolute
`DUNE_SOURCEROOT` path (Step 6), not from the copied build tree, so the dep is
only a rebuild trigger.

- [ ] **Step 5: Fix the runtime fixture roots (5 spots across 4 files)**

`examples/` stays at root, so every `DUNE_SOURCEROOT`-branch that concatenates
`"examples"` is ALREADY CORRECT and must NOT change. Only (a) the `"tests/cases"`
concatenations (tests moved under `packages/core/`) and (b) the `None` fallbacks
(build depth grew by two levels: `../../../` → `../../../../../`) change.

`packages/core/tests/test_eval.ml` line 613:

```
-  | None -> "../../../examples"
+  | None -> "../../../../../examples"
```

`packages/core/tests/test_golden.ml` line 10:

```
-   | None -> "../../../examples")
+   | None -> "../../../../../examples")
```

`packages/core/tests/test_e2e.ml` — examples fallback (line 13) and cases (lines 23-24):

```
Line 13:  -  | None -> "../../../examples"
          +  | None -> "../../../../../examples"
Line 23:  -  | Some root -> Filename.concat root "tests/cases"
          +  | Some root -> Filename.concat root "packages/core/tests/cases"
Line 24:  -  | None -> "../../../tests/cases"
          +  | None -> "../../../../../packages/core/tests/cases"
```

`packages/core/tests/test_bel_assert.ml` lines 10-11:

```
Line 10:  -   | Some root -> Filename.concat root "tests/cases"
          +   | Some root -> Filename.concat root "packages/core/tests/cases"
Line 11:  -   | None -> "../../../tests/cases")
          +   | None -> "../../../../../packages/core/tests/cases")
```

- [ ] **Step 6: Verify the full build and test suite are green**

Run:
```bash
dune build 2>&1 | tail -5
dune test 2>&1 | tail -20
```
Expected: build green; every alcotest suite passes — in particular
`test_golden`, `test_bel_assert`, `test_eval` (the `test_layer_all_examples_valid`
walker), and `test_e2e` (which read the moved/relocated fixtures).

- [ ] **Step 7: Verify the nix check output too**

Run: `nix flake check 2>&1 | tail -10`
Expected: green (same derivation with `doCheck = true`).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(layout): move OCaml core (lib/bin/tests/bench/tools) to packages/core"
```

---

### Task 6: Docs + cosmetic reference sweep

Update the human-facing structure descriptions and stale doc comments. No build
impact — group all cosmetic path mentions here so the functional tasks stayed
tight.

**Files:**
- Modify: `README.md` (structure blurb, ~lines 50-60)
- Modify: `packages/core/tools/README.md` (render path mentions)
- Modify: `packages/core/bin/main.ml` (doc-comment path mentions, lines 34, 92)
- Modify: `CLAUDE.md` only if it references a moved path (verify first)

- [ ] **Step 1: Update README structure blurb**

In `README.md`, re-point the component lines to the new tree. Replace the
`lib/`, `bin/` entries and add the `packages/` grouping, e.g.:

```
- lib/          evaluator core (OCaml library)
- bin/          the `beloch` CLI
+ packages/core/   evaluator core + `beloch` CLI (OCaml)
+ packages/render-2d/  FOLD→SVG render engine (bun)
+ packages/www/        landing + docs + Playground site
+ packages/eval-web/   js_of_ocaml browser eval bundle
+ packages/grammar/    tree-sitter grammar
+ packages/vscode/     editor extension
```
Keep the existing `spec/ decisions/ notes/ examples/ paper/` lines as-is (they
did not move).

- [ ] **Step 2: Fix doc references to render/**

`packages/core/tools/README.md`: replace every `render/render-svg/` with
`packages/render-2d/render-svg/` and `render/README.md` with
`packages/render-2d/README.md`.

`packages/core/bin/main.ml`: in the doc comments, `render/render-svg` →
`packages/render-2d/render-svg` (line ~34) and `render/README.md` →
`packages/render-2d/README.md` (line ~92).

- [ ] **Step 3: Check CLAUDE.md**

Run: `rg -n '\blib/|\bbin/|\bsite/|\brender/|\bweb/|tree-sitter-beloch|editors/' CLAUDE.md`
Expected: no functional path refs (it points at `decisions/ notes/ refs/ paper/`
which did not move). If any moved path appears, update it; otherwise no change.

- [ ] **Step 4: Final full grep for stragglers**

Run:
```bash
rg -n "(^|[^./\w])(site|render|web|lib|bin|tests|bench|tools|editors)/" \
  -g '!_build' -g '!node_modules' -g '!packages/**' -g '!docs/superpowers/**' \
  -g '!notes/**' -g '!decisions/**' -g '!paper/**' -g '!spec/**'
```
Expected: only intentional root residents (`examples/`, `scratch/`, `spike/`,
`refs/`, `.github/`, `.direnv/`). Any moved-package path outside `packages/` is a
straggler — fix it.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs(layout): update structure blurb + stale path references"
```

---

## Self-review notes

- **Spec coverage:** every file in the spec's fix table maps to a task (flake→T2/T3,
  deploy.yml→T2/T3/T4/T5, build-eval.sh→T4, fixture plumbing→T5). Spec's
  `highlight-bel.ts` entry was dropped after verification — it reads
  `siteDir/src/grammar/` internally and moves as a block (no edit). Extra refs
  the spec missed are covered: `bench/run.sh`, `spike/build.sh`,
  `spike/render-fish-base.ts`, `.vscode/launch.json`, CI `lib/**`+`bin/**`.
- **Ordering:** peripheral (T1-T4) before core (T5); each task self-gated. CI edits
  reference `packages/www` before Task 4 creates it, which is safe — CI runs only
  on `main`, never on this branch mid-migration.
- **Risk:** T5 Step 4 carries a dune-source_tree-climb contingency; T5 Steps 6-7
  are the hard green-tests gate.
