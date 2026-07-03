# VSCode Highlighting (TextMate grammar) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill the foundation's stub grammar `editors/vscode/syntaxes/beloch.tmLanguage.json` with a rich, contextual TextMate grammar mapped onto standard scopes, tested with `vscode-tmgrammar-test`.

**Architecture:** One grammar JSON built as a `repository` of named rule groups, included from top-level `patterns` in precedence order. Each task adds one rule group plus inline-assertion test fixtures, TDD. Grammar precedence is controlled by the order of `#include`s in top-level `patterns` and by pattern specificity within a group.

**Tech Stack:** TextMate grammar (Oniguruma regex), `vscode-tmgrammar-test` (backed by `vscode-textmate` + `vscode-oniguruma` WASM), bun.

## Global Constraints

- The grammar lives only in `editors/vscode/syntaxes/beloch.tmLanguage.json`; `scopeName` stays `source.beloch`.
- Scopes are the standard-scope map from the spec — copy scope names verbatim.
- Beloch line comment is `;`. `--` is the crease sigil and `--(` a line-construction opener — NEVER a comment.
- Beloch has no numeric literals — no number scope.
- `package.json` edits are additive only: add `vscode-tmgrammar-test` to `devDependencies` and a `test:grammar` script. Do NOT touch any `contributes` block.
- All commits on branch `vscode-highlighting`.
- Test invocation: `bunx vscode-tmgrammar-test -g syntaxes/beloch.tmLanguage.json "test/grammar/**/*.bel"` run from `editors/vscode/`.

---

### Task 1: Test harness + comments

**Files:**
- Modify: `editors/vscode/package.json` (additive: devDep + script)
- Modify: `editors/vscode/syntaxes/beloch.tmLanguage.json` (repository skeleton + comments rule)
- Create: `editors/vscode/test/grammar/comments.bel`

**Interfaces:**
- Produces: the `repository` skeleton every later task extends, and the pinned test command. Top-level `patterns` will hold includes in this final order (later tasks fill the missing groups): `#comments`, `#definitions`, `#openers`, `#keywords`, `#entities`, `#operators`, `#punctuation`.

- [ ] **Step 1: Add the dev dependency and script**

Run: `cd editors/vscode && bun add -d vscode-tmgrammar-test`

Then in `editors/vscode/package.json` add to `scripts` (after `"test"`):

```json
    "test:grammar": "vscode-tmgrammar-test -g syntaxes/beloch.tmLanguage.json \"test/grammar/**/*.bel\""
```

- [ ] **Step 2: Write the failing test fixture**

Create `editors/vscode/test/grammar/comments.bel`:

```
; SYNTAX TEST "source.beloch"

; a comment line
; <- comment.line.semicolon.beloch
```

The `; <-` line asserts that column 0 of the line above (the `;`) has scope `comment.line.semicolon.beloch`.

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd editors/vscode && bunx vscode-tmgrammar-test -g syntaxes/beloch.tmLanguage.json "test/grammar/**/*.bel"`
Expected: FAIL — the stub grammar has empty `patterns`, so the `;` token has no `comment.line.semicolon.beloch` scope.

(If the exact CLI flag form differs in the installed version, resolve it here so the `test:grammar` script and all later tasks use the working form; report what you settled on.)

- [ ] **Step 4: Add the repository skeleton + comments rule**

Replace the whole `editors/vscode/syntaxes/beloch.tmLanguage.json` with:

```json
{
  "$schema": "https://raw.githubusercontent.com/martinring/tmlanguage/master/tmlanguage.json",
  "name": "Beloch",
  "scopeName": "source.beloch",
  "patterns": [
    { "include": "#comments" }
  ],
  "repository": {
    "comments": {
      "patterns": [
        {
          "match": ";.*$",
          "name": "comment.line.semicolon.beloch"
        }
      ]
    }
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd editors/vscode && bun run test:grammar`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add editors/vscode/package.json editors/vscode/bun.lock editors/vscode/syntaxes/beloch.tmLanguage.json editors/vscode/test/grammar/comments.bel
git commit -m "feat(vscode): grammar test harness + comment highlighting"
```

---

### Task 2: Keywords

**Files:**
- Modify: `editors/vscode/syntaxes/beloch.tmLanguage.json` (add `#keywords` group + include)
- Create: `editors/vscode/test/grammar/keywords.bel`

**Interfaces:**
- Consumes: the repository skeleton from Task 1.
- Produces: the `#keywords` group (fold verbs, flip, modifiers, mountain, paper, square, apply/export/as, and a bare `def`/`step` fallback). `def NAME` / `step NAME` name-capturing is Task 4's `#definitions` (included earlier so it wins); this bare fallback only colors a lone `def`/`step`.

- [ ] **Step 1: Write the failing test fixture**

Create `editors/vscode/test/grammar/keywords.bel`:

```
; SYNTAX TEST "source.beloch"

paper square
; <- keyword.control.paper.beloch
;     ^^^^^^ constant.language.shape.beloch

map perp cross through flip
; <- keyword.control.fold.beloch
;   ^^^^ keyword.control.fold.beloch
;                       ^^^^ keyword.control.flip.beloch

onto and toward moving mountain
; <- keyword.operator.word.beloch
;               ^^^^^^ keyword.operator.word.beloch
;                      ^^^^^^^^ keyword.other.direction.beloch

apply export as
; <- keyword.control.import.beloch
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd editors/vscode && bun run test:grammar`
Expected: FAIL on `keywords.bel` (no keyword scopes yet).

- [ ] **Step 3: Add the keywords group**

In `beloch.tmLanguage.json`, add `{ "include": "#keywords" }` to the top-level `patterns` array (after `#comments`), and add this entry to `repository`:

```json
    "keywords": {
      "patterns": [
        { "match": "\\b(map|perp|cross|through)\\b", "name": "keyword.control.fold.beloch" },
        { "match": "\\b(flip)\\b", "name": "keyword.control.flip.beloch" },
        { "match": "\\b(onto|and|toward|moving)\\b", "name": "keyword.operator.word.beloch" },
        { "match": "\\b(mountain)\\b", "name": "keyword.other.direction.beloch" },
        { "match": "\\b(paper)\\b", "name": "keyword.control.paper.beloch" },
        { "match": "\\b(square)\\b", "name": "constant.language.shape.beloch" },
        { "match": "\\b(apply|export|as)\\b", "name": "keyword.control.import.beloch" },
        { "match": "\\b(def|step)\\b", "name": "storage.type.beloch" }
      ]
    }
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd editors/vscode && bun run test:grammar`
Expected: PASS (both `comments.bel` and `keywords.bel`).

- [ ] **Step 5: Commit**

```bash
git add editors/vscode/syntaxes/beloch.tmLanguage.json editors/vscode/test/grammar/keywords.bel
git commit -m "feat(vscode): keyword highlighting"
```

---

### Task 3: Entities and openers (the crease-not-comment guard)

**Files:**
- Modify: `editors/vscode/syntaxes/beloch.tmLanguage.json` (add `#openers` and `#entities` groups + includes)
- Create: `editors/vscode/test/grammar/entities.bel`

**Interfaces:**
- Consumes: repository skeleton + keywords.
- Produces: `#openers` (`--(`, `--[`, `.(`, `.[`) scoped as punctuation, and `#entities` (`$instance`, `--crease`, `._temp`, `.point`). Openers are included BEFORE entities and matched as whole tokens so `--(` is never read as a crease or a comment; `._temp` precedes `.point` so the leading-underscore case wins.

- [ ] **Step 1: Write the failing test fixture**

Create `editors/vscode/test/grammar/entities.bel`:

```
; SYNTAX TEST "source.beloch"

--pq through ._mb .s
; <- variable.other.crease.beloch
;              ^^^^ variable.other.point.temp.beloch
;                   ^^ variable.other.point.beloch

.x .(--vm --(.a .b))
; <- variable.other.point.beloch
;    ^^ punctuation.section.point.begin.beloch
;         ^^^ punctuation.section.line.begin.beloch

apply $t
;     ^^ variable.other.instance.beloch
```

Note: no `=` assertion here — the `=` operator scope is added in Task 4, so this fixture stays entities/openers-only and passes on completion of Task 3. The implementer aligns each `^` caret to the exact column of its token in the line above (tmgrammar-test is column-precise); the columns shown here are indicative.

- [ ] **Step 2: Run to verify it fails**

Run: `cd editors/vscode && bun run test:grammar`
Expected: FAIL on `entities.bel`.

- [ ] **Step 3: Add openers and entities**

In top-level `patterns`, add `{ "include": "#openers" }` and `{ "include": "#entities" }` — place `#openers` BEFORE `#entities`, and both BEFORE `#keywords` is not required, but `#openers` MUST come before `#entities`. Final top-level order so far: `#comments`, `#openers`, `#keywords`, `#entities`. Add to `repository`:

```json
    "openers": {
      "patterns": [
        { "match": "--\\(", "name": "punctuation.section.line.begin.beloch" },
        { "match": "--\\[", "name": "punctuation.section.member.begin.beloch" },
        { "match": "\\.\\(", "name": "punctuation.section.point.begin.beloch" },
        { "match": "\\.\\[", "name": "punctuation.section.member.begin.beloch" }
      ]
    },
    "entities": {
      "patterns": [
        { "match": "\\$[A-Za-z0-9_]+", "name": "variable.other.instance.beloch" },
        { "match": "--[A-Za-z0-9_]+", "name": "variable.other.crease.beloch" },
        { "match": "\\.(_[A-Za-z0-9_]+)", "name": "variable.other.point.temp.beloch" },
        { "match": "\\.[A-Za-z0-9_]+", "name": "variable.other.point.beloch" }
      ]
    }
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd editors/vscode && bun run test:grammar`
Expected: PASS. In particular `--(` is scoped `punctuation.section.line.begin.beloch`, never a comment or crease.

- [ ] **Step 5: Commit**

```bash
git add editors/vscode/syntaxes/beloch.tmLanguage.json editors/vscode/test/grammar/entities.bel
git commit -m "feat(vscode): point/crease/instance entities + construction openers"
```

---

### Task 4: Operators, punctuation, and definition sites

**Files:**
- Modify: `editors/vscode/syntaxes/beloch.tmLanguage.json` (add `#definitions`, `#operators`, `#punctuation` groups + includes)
- Create: `editors/vscode/test/grammar/contextual.bel`

**Interfaces:**
- Consumes: everything so far.
- Produces: `#definitions` (`def NAME` / `step NAME` capturing both keyword and name), `#operators` (`@` commit-fold, `!` shadow, `=` assignment), `#punctuation` (closing/standalone brackets). `#definitions` is included BEFORE `#keywords` so `def NAME` captures the name rather than the bare `def` fallback firing.

- [ ] **Step 1: Write the failing test fixture**

Create `editors/vscode/test/grammar/contextual.bel`:

```
; SYNTAX TEST "source.beloch"

def diagonals
; <- storage.type.beloch
;   ^^^^^^^^^ entity.name.function.beloch

step thirds
; <- storage.type.beloch
;    ^^^^^^ entity.name.section.beloch

@map .a onto .b
; <- keyword.control.fold.commit.beloch
;    ^^^ keyword.control.fold.beloch

export { .s! } $t
;          ^ keyword.operator.shadow.beloch
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd editors/vscode && bun run test:grammar`
Expected: FAIL on `contextual.bel`.

- [ ] **Step 3: Add definitions, operators, punctuation**

Update the top-level `patterns` to this final order:

```json
  "patterns": [
    { "include": "#comments" },
    { "include": "#definitions" },
    { "include": "#openers" },
    { "include": "#keywords" },
    { "include": "#entities" },
    { "include": "#operators" },
    { "include": "#punctuation" }
  ],
```

Add to `repository`:

```json
    "definitions": {
      "patterns": [
        {
          "match": "\\b(def)\\s+([A-Za-z0-9_]+)",
          "captures": {
            "1": { "name": "storage.type.beloch" },
            "2": { "name": "entity.name.function.beloch" }
          }
        },
        {
          "match": "\\b(step)\\s+([A-Za-z0-9_]+)",
          "captures": {
            "1": { "name": "storage.type.beloch" },
            "2": { "name": "entity.name.section.beloch" }
          }
        }
      ]
    },
    "operators": {
      "patterns": [
        { "match": "@", "name": "keyword.control.fold.commit.beloch" },
        { "match": "!", "name": "keyword.operator.shadow.beloch" },
        { "match": "=", "name": "keyword.operator.assignment.beloch" }
      ]
    },
    "punctuation": {
      "patterns": [
        { "match": "[(){}\\]]", "name": "punctuation.section.group.beloch" }
      ]
    }
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd editors/vscode && bun run test:grammar`
Expected: PASS (all four fixtures).

- [ ] **Step 5: Commit**

```bash
git add editors/vscode/syntaxes/beloch.tmLanguage.json editors/vscode/test/grammar/contextual.bel
git commit -m "feat(vscode): @-commit / ! / = operators and def/step definition names"
```

---

### Task 5: Full-program fixture + README ownership update

**Files:**
- Create: `editors/vscode/test/grammar/cube-root.bel`
- Modify: `editors/vscode/README.md` (ownership-note refinement)

**Interfaces:**
- Consumes: the complete grammar.
- Produces: an end-to-end regression fixture over a real program, and the documented contract refinement (devDeps/scripts are additively extendable).

- [ ] **Step 1: Write the full-program fixture**

Create `editors/vscode/test/grammar/cube-root.bel` by copying the body of the repo's `examples/cube-root.bel`, then add a `; SYNTAX TEST "source.beloch"` first line and a handful of spot assertions on representative tokens (do NOT assert every token — pick one of each: a `;` comment, `paper`, `step` + its name, `--vm` crease, `._mb` temp point, `@map` commit, `cross`, `onto`). Example head:

```
; SYNTAX TEST "source.beloch"
; status: works — Peter Messer's cube-root-of-two construction
; <- comment.line.semicolon.beloch

paper square
; <- keyword.control.paper.beloch

step vertical_middle
;    ^^^^^^^^^^^^^^^ entity.name.section.beloch

--vm = map .a onto .b
; <- variable.other.crease.beloch
;      ^^^ keyword.control.fold.beloch
```

Include enough of the real program body (through the `@map ... and ... onto` cubic line) that any future grammar regression on a real file is caught. Add a spot assertion on the `@` of the final `@map`:

```
@map .c onto --(.a .b) and .s onto --pq
; <- keyword.control.fold.commit.beloch
```

- [ ] **Step 2: Run to verify it passes**

Run: `cd editors/vscode && bun run test:grammar`
Expected: PASS. No token in a real program falls through to an unexpected scope; the assertions hold.

- [ ] **Step 3: Update the README ownership note**

In `editors/vscode/README.md`, under the frozen-`package.json` note, add:

```markdown
Subsystems may extend `devDependencies` and `scripts` additively (each needs its
own test tooling); only the `contributes` blocks are frozen.
```

- [ ] **Step 4: Commit**

```bash
git add editors/vscode/test/grammar/cube-root.bel editors/vscode/README.md
git commit -m "feat(vscode): full-program grammar regression fixture + contract note"
```

---

## Self-Review

**Spec coverage:**
- Token→scope map (all rows) → Tasks 1 (comments), 2 (keywords + paper/square/mountain/import), 3 (point/temp/crease/instance + openers), 4 (`@`/`!`/`=` + brackets). ✓
- Contextual rule 1 `@`-commit → Task 4. ✓
- Contextual rule 2 temp points → Task 3. ✓
- Contextual rule 3 `def`/`step` names → Task 4 `#definitions`. ✓
- Contextual rule 4 `!` shadow → Task 4. ✓
- `--(` never a comment → Task 3 (openers before entities) with explicit assertion. ✓
- LHS/RHS dropped → not implemented, correct. ✓
- Standard scopes verbatim → all tasks use the spec's scope names. ✓
- Testing via `vscode-tmgrammar-test` inline assertions + real-program fixture → Tasks 1–5. ✓
- Additive `package.json` (devDep + script, no `contributes` touch) → Task 1. ✓
- README refinement → Task 5. ✓

**Placeholder scan:** No TBD/TODO. Every grammar rule is complete JSON; every fixture is concrete. Task 5 Step 1 asks the implementer to copy a real example and add spot assertions — the shape and required assertions are enumerated, not left vague.

**Type/precedence consistency:** Top-level `patterns` include order converges to `#comments, #definitions, #openers, #keywords, #entities, #operators, #punctuation` (stated in Task 4 Step 3 and matching the Task 1 interface note). `#definitions` before `#keywords` (name capture wins over bare `def`/`step`), `#openers` before `#entities` (`--(` not read as crease), `._temp` pattern before `.point` within `#entities`. Scope names are identical across plan and spec.

**Task independence:** each task's fixture passes on that task's completion — Task 3's `entities.bel` deliberately carries no `=` assertion (the `=` operator lands in Task 4). No fixture asserts a scope its task hasn't added yet.
