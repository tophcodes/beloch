# Action-Model Syntax Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the surface syntax of the action model — rename the superposition axioms to `map … onto …`, and parse the `@` fold modifier with `moving`/`mountain` clauses — without yet executing folds.

**Architecture:** Pure parse/AST-layer change. Bare axioms remain precreases with identical evaluation; the new `@`-prefixed statements parse into an AST `fold_spec` that evaluation rejects with a clear "not yet implemented" error. The folded-state engine that consumes `fold_spec` is a separate, later plan.

**Tech Stack:** OCaml, dune, sedlex (lexer), menhir (parser), alcotest (tests), zarith/`Num` (exact arithmetic).

## Slice 1 decomposition (context)

Slice 1 of the action-model pivot (design: `docs/superpowers/specs/2026-06-29-action-model-folding-design.md`) is too large for one no-placeholder plan. It splits into:

- **Plan A — this document:** action-model *syntax* (`map` rename + `@`/`moving`/`mountain` parsing).
- **Plan B — folded-state runtime + flat-fold semantics + `foldedForm` output.** Algorithmically deep (3D reflection isometries, splitting faces along a fold line, the layer stack, mapping the folded state back to a crease pattern). **Needs its own algorithm-design pass before it can be written without placeholders** — do not attempt it from this plan.

This plan ships working, testable software on its own: every existing precrease program works identically under the new verbs; `@…` parses and fails cleanly pending Plan B.

## Global Constraints

- Language: OCaml; build with `dune build`; test with `dune test`. (Copied from `dune-project`: `(lang dune 3.0)`, `(using menhir 2.1)`.)
- All geometry exact via `Num`/zarith — **no floating point in the core** (floats only at JSON serialization). This plan adds no geometry.
- Errors are `Error.fail span "<message>"` (raises `Error.Beloch_error`), first match wins, process exits non-zero.
- Lexer keyword set is authoritative in `lib/lexer.ml`; every token the lexer emits **must** be declared in `lib/parser.mly` (`%token …`) or the build fails.
- **Warnings are fatal in the dev profile** (since #6) — `dune build` must be clean (no unused variables/constructors). The `_fold_opt` underscore name in Task 1 is deliberate to avoid an unused-variable warning.
- **Code must be ocamlformat-clean** (`.ocamlformat`: version 0.29.0, profile default). Run `dune fmt` before committing; `dune build` must show no formatting diff.
- Commits: Conventional Commits; end the commit body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: Rename superposition axioms to `map … onto …`

Breaking rename of the surface verbs: `fold .x to .y` → `map .x onto .y` (axiom 2), `bisect --a --b [toward .p]` → `map --a onto --b [toward .p]` (axiom 5). The AST constructors are renamed to match (`FoldOnto`→`MapPoints`, `Bisect`→`MapLines`) — keeping a constructor named `FoldOnto` for what is now a *precrease* would re-introduce exactly the confusion the surface change removes. The `Crease` statement also gains a final `fold_spec option` field (always `None` from the parser in this task) so its arity is final before Task 2.

**Files:**
- Modify: `lib/ast.ml`
- Modify: `lib/lexer.ml`
- Modify: `lib/parser.mly`
- Modify: `lib/eval.ml`
- Modify: `examples/x-midpoint.bel`, `examples/bisect-parallel.bel`, `examples/bisect-a.bel`, `examples/bisect-b.bel`, `examples/bisect-intermediate.bel`
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Produces (AST, consumed by Task 2 and Plan B):
  ```ocaml
  type axiom =
    | Through of point_ref * point_ref
    | MapPoints of point_ref * point_ref                       (* axiom 2 *)
    | Perp of point_ref * crease_ref                           (* axiom 3 *)
    | MapLines of crease_ref * crease_ref * point_ref option   (* axiom 5 *)
  type direction = Valley | Mountain
  type fold_spec = { moving : point_ref option; direction : direction }
  type stmt =
    | Crease of string option * axiom * fold_spec option * Error.span
    | Point of string * point_expr * Error.span
  ```

- [ ] **Step 1: Rewrite `lib/ast.ml`**

Replace the whole file with:

```ocaml
(** Abstract syntax for Beloch. Spans point into the source for diagnostics. *)

type point_ref = { name : string; span : Error.span }
type crease_ref = { cname : string; cspan : Error.span }

type axiom =
  | Through of point_ref * point_ref   (* axiom 1: line through two points *)
  | MapPoints of point_ref * point_ref (* axiom 2: place point .x onto point .y *)
  | Perp of point_ref * crease_ref     (* axiom 3: through .p, perpendicular to --l *)
  | MapLines of crease_ref * crease_ref * point_ref option  (* axiom 5: line onto line *)

type direction = Valley | Mountain

(* present iff the statement was prefixed with `@` (perform the fold, keep folded) *)
type fold_spec = { moving : point_ref option; direction : direction }

type point_expr = Cross of crease_ref * crease_ref  (* intersection of two creases *)

type stmt =
  | Crease of string option * axiom * fold_spec option * Error.span
  | Point of string * point_expr * Error.span

type program = stmt list
```

- [ ] **Step 2: Update lexer keywords in `lib/lexer.ml`**

Replace these lines:

```ocaml
  | "through" -> THROUGH
  | "fold" -> FOLD
  | "perp" -> PERP
  | "bisect" -> BISECT
  | "toward" -> TOWARD
  | "to" -> TO
  | "cross" -> CROSS
```

with:

```ocaml
  | "through" -> THROUGH
  | "map" -> MAP
  | "onto" -> ONTO
  | "perp" -> PERP
  | "toward" -> TOWARD
  | "cross" -> CROSS
```

(`fold`, `to`, `bisect` keywords are removed; `MAP`/`ONTO` added. `@`/`moving`/`mountain` arrive in Task 2.)

- [ ] **Step 3: Update parser tokens and grammar in `lib/parser.mly`**

Replace the token line:

```ocaml
%token PAPER SQUARE THROUGH FOLD TO CROSS COLON EOF PERP BISECT TOWARD
```

with:

```ocaml
%token PAPER SQUARE THROUGH MAP ONTO CROSS COLON EOF PERP TOWARD
```

Replace the `stmt` and `axiom` rules:

```ocaml
stmt:
  | CREASE COLON axiom    { Crease (Some $1, $3, $loc) }
  | axiom                 { Crease (None, $1, $loc) }
  | POINT COLON point_expr { Point ($1, $3, $loc) }

axiom:
  | THROUGH point_ref point_ref  { Through ($2, $3) }
  | FOLD point_ref TO point_ref  { FoldOnto ($2, $4) }
  | PERP crease_ref THROUGH point_ref { Perp ($4, $2) }
  | BISECT crease_ref crease_ref         { Bisect ($2, $3, None) }
  | BISECT crease_ref crease_ref TOWARD point_ref  { Bisect ($2, $3, Some $5) }
```

with:

```ocaml
stmt:
  | CREASE COLON axiom    { Crease (Some $1, $3, None, $loc) }
  | axiom                 { Crease (None, $1, None, $loc) }
  | POINT COLON point_expr { Point ($1, $3, $loc) }

axiom:
  | THROUGH point_ref point_ref       { Through ($2, $3) }
  | MAP point_ref ONTO point_ref      { MapPoints ($2, $4) }
  | PERP crease_ref THROUGH point_ref { Perp ($4, $2) }
  | MAP crease_ref ONTO crease_ref                  { MapLines ($2, $4, None) }
  | MAP crease_ref ONTO crease_ref TOWARD point_ref { MapLines ($2, $4, Some $6) }
```

- [ ] **Step 4: Update `lib/eval.ml` for the renamed constructors and new arity**

In `eval_axiom`, change the `Ast.FoldOnto` branch header:

```ocaml
    | Ast.FoldOnto (p, q) ->
```

to:

```ocaml
    | Ast.MapPoints (p, q) ->
```

and the `Ast.Bisect` branch header:

```ocaml
    | Ast.Bisect (c1, c2, p_opt) ->
```

to:

```ocaml
    | Ast.MapLines (c1, c2, p_opt) ->
```

(Leave the branch bodies — including the `"axiom2"` / `"axiom5"` provenance strings — unchanged.)

In the `List.iter`, change the `Crease` pattern:

```ocaml
      | Ast.Crease (name_opt, ax, span) ->
```

to (the fold field is ignored in this task — always `None`):

```ocaml
      | Ast.Crease (name_opt, ax, _fold_opt, span) ->
```

- [ ] **Step 5: Migrate the example `.bel` files**

`examples/x-midpoint.bel` — replace `fold .a to .center` with `map .a onto .center`.

`examples/bisect-parallel.bel` — replace `bisect --l --r` with `map --l onto --r`.

`examples/bisect-a.bel` — replace:
- `--v: fold .a to .b` → `--v: map .a onto .b`
- `--h: fold .b to .c` → `--h: map .b onto .c`
- `bisect --v --h toward .a` → `map --v onto --h toward .a`

`examples/bisect-b.bel` — replace:
- `--v: fold .a to .b` → `--v: map .a onto .b`
- `--h: fold .b to .c` → `--h: map .b onto .c`
- `bisect --v --h toward .b` → `map --v onto --h toward .b`

`examples/bisect-intermediate.bel` — replace:
- `--v: fold .a to .b` → `--v: map .a onto .b`
- `--h: fold .b to .c` → `--h: map .b onto .c`
- `--quartered: bisect --v --left` → `--quartered: map --v onto --left`
- `bisect --v --h toward .int` → `map --v onto --h toward .int`

- [ ] **Step 6: Migrate `tests/test_beloch.ml` source strings and AST patterns**

`test_parse_named_and_anon` — change source `fold .b to .d` → `map .b onto .d`, and the match arm:

```ocaml
  | [ Ast.Crease (Some "d1", Ast.Through _, _);
      Ast.Crease (None, Ast.FoldOnto _, _);
      Ast.Point ("center", Ast.Cross _, _) ] -> ()
```

to:

```ocaml
  | [ Ast.Crease (Some "d1", Ast.Through _, _, _);
      Ast.Crease (None, Ast.MapPoints _, _, _);
      Ast.Point ("center", Ast.Cross _, _) ] -> ()
```

`test_parse_syntax_error` — change source `"paper square\nfold .a\n"` → `"paper square\nmap .a\n"`.

`test_parse_perp` — change the match arm:

```ocaml
  | [ Ast.Crease (Some "d", Ast.Through _, _);
      Ast.Crease (None, Ast.Perp ({ name = "b"; _ }, { cname = "d"; _ }), _) ] -> ()
```

to:

```ocaml
  | [ Ast.Crease (Some "d", Ast.Through _, _, _);
      Ast.Crease (None, Ast.Perp ({ name = "b"; _ }, { cname = "d"; _ }), _, _) ] -> ()
```

`test_eval_counts_creases` — source `fold .b to .d` → `map .b onto .d`.

`test_eval_cross_ok` — source `fold .a to .m` → `map .a onto .m`.

`test_eval_undefined_point` — source `fold .a to .z` → `map .a onto .z`.

`test_parse_bisect` — change source to:

```ocaml
      "paper square\n--v: map .a onto .b\n--h: map .b onto .c\nmap --v onto --h toward .a\n"
```

and the match arm:

```ocaml
  | [ _; _; Ast.Crease (None, Ast.Bisect ({ cname = "v"; _ }, { cname = "h"; _ }, Some { name = "a"; _ }), _) ] -> ()
```

to:

```ocaml
  | [ _; _; Ast.Crease (None, Ast.MapLines ({ cname = "v"; _ }, { cname = "h"; _ }, Some { name = "a"; _ }), _, _) ] -> ()
```

`test_eval_bisect_select` — in the `prog` helper, change the prefix
`"paper square\n--v: fold .a to .b\n--h: fold .b to .c\n"` →
`"paper square\n--v: map .a onto .b\n--h: map .b onto .c\n"`, and the two appended
selectors `"bisect --v --h toward .a"` → `"map --v onto --h toward .a"` and
`"bisect --v --h toward .b"` → `"map --v onto --h toward .b"`.

`test_eval_bisect_errors` — change the three sources:
- `"paper square\n--x: through .a .c\n--y: through .a .c\nbisect --x --y toward .b\n"` → `"paper square\n--x: through .a .c\n--y: through .a .c\nmap --x onto --y toward .b\n"`
- `"paper square\n--v: fold .a to .b\n--h: fold .b to .c\nbisect --v --h\n"` → `"paper square\n--v: map .a onto .b\n--h: map .b onto .c\nmap --v onto --h\n"`
- `"paper square\n--d: through .a .c\n--h: fold .b to .c\nbisect --d --h toward .a\n"` → `"paper square\n--d: through .a .c\n--h: map .b onto .c\nmap --d onto --h toward .a\n"`

- [ ] **Step 7: Format, build, and run the full test suite**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: build succeeds (warnings are fatal — must be clean); all existing test cases PASS (the suite is unchanged in count — only syntax migrated). If the build reports an undefined constructor or token, a rename site was missed above.

- [ ] **Step 8: Commit**

```bash
git add lib/ast.ml lib/lexer.ml lib/parser.mly lib/eval.ml examples tests/test_beloch.ml
git commit -m "feat(syntax)!: rename superposition axioms to 'map … onto …'

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Parse the `@` fold modifier (`moving` / `mountain`)

Add the fold-action surface: `@axiom [moving .p] [mountain]` parses into `Some fold_spec`; a bare axiom stays `None`. Evaluation rejects any `@` statement with a clear "not yet implemented" error (the executor — Plan B — is not built yet). Default direction is valley; `moving` is optional here at the grammar level (Plan B enforces it for line-construction axioms).

**Files:**
- Modify: `lib/lexer.ml`
- Modify: `lib/parser.mly`
- Modify: `lib/eval.ml`
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Consumes: the `axiom` / `fold_spec` / `direction` / `Crease` types from Task 1.
- Produces: parser now yields `Crease (_, _, Some { moving; direction }, _)` for `@` statements; `eval` raises `Error.Beloch_error` with message containing `"not yet implemented"` on any such statement.

- [ ] **Step 1: Write the failing parse tests**

Add to `tests/test_beloch.ml` (after `test_parse_bisect`):

```ocaml
let test_parse_fold_action () =
  let prog = Beloch.parse ~filename:"t.bel" "paper square\n@map .a onto .c moving .a mountain\n" in
  match prog with
  | [ Ast.Crease (None, Ast.MapPoints _,
                  Some { moving = Some { name = "a"; _ }; direction = Ast.Mountain }, _) ] -> ()
  | _ -> Alcotest.fail "unexpected AST for @map fold action"

let test_parse_fold_valley_default () =
  let prog = Beloch.parse ~filename:"t.bel" "paper square\n@map .a onto .c\n" in
  match prog with
  | [ Ast.Crease (None, Ast.MapPoints _,
                  Some { moving = None; direction = Ast.Valley }, _) ] -> ()
  | _ -> Alcotest.fail "default fold is valley with no moving"

let test_parse_precrease_no_foldspec () =
  let prog = Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .c\n" in
  match prog with
  | [ Ast.Crease (None, Ast.MapPoints _, None, _) ] -> ()
  | _ -> Alcotest.fail "bare axiom must carry no fold_spec"

let test_eval_fold_not_implemented () =
  expect_error "not yet implemented" (fun () -> eval_src "paper square\n@map .a onto .c\n")
```

Register them — in the `"parse"` group add:

```ocaml
         Alcotest.test_case "fold action parses" `Quick test_parse_fold_action;
         Alcotest.test_case "fold valley default" `Quick test_parse_fold_valley_default;
         Alcotest.test_case "bare axiom has no fold_spec" `Quick test_parse_precrease_no_foldspec;
```

and in the `"eval"` group add:

```ocaml
         Alcotest.test_case "fold not yet implemented" `Quick test_eval_fold_not_implemented;
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `dune test 2>&1`
Expected: build FAILS (lexer has no `@`/`moving`/`mountain`; parser has no rule) — i.e. the new syntax does not parse yet.

- [ ] **Step 3: Add lexer tokens in `lib/lexer.ml`**

Add these branches (e.g. after `| "toward" -> TOWARD`):

```ocaml
  | "moving" -> MOVING
  | "mountain" -> MOUNTAIN
```

and add an `@` branch (e.g. after the `':' -> COLON` line):

```ocaml
  | '@' -> AT
```

- [ ] **Step 4: Add parser tokens and the fold grammar in `lib/parser.mly`**

Change the token line:

```ocaml
%token PAPER SQUARE THROUGH MAP ONTO CROSS COLON EOF PERP TOWARD
```

to:

```ocaml
%token PAPER SQUARE THROUGH MAP ONTO CROSS COLON EOF PERP TOWARD AT MOVING MOUNTAIN
```

Replace the `stmt` rule:

```ocaml
stmt:
  | CREASE COLON axiom    { Crease (Some $1, $3, None, $loc) }
  | axiom                 { Crease (None, $1, None, $loc) }
  | POINT COLON point_expr { Point ($1, $3, $loc) }
```

with:

```ocaml
stmt:
  | CREASE COLON axiom_stmt { let (a, fs) = $3 in Crease (Some $1, a, fs, $loc) }
  | axiom_stmt             { let (a, fs) = $1 in Crease (None, a, fs, $loc) }
  | POINT COLON point_expr { Point ($1, $3, $loc) }

axiom_stmt:
  | axiom                 { ($1, None) }
  | AT axiom fold_clauses { ($2, Some $3) }

fold_clauses:
  |                           { { moving = None; direction = Valley } }
  | MOVING point_ref          { { moving = Some $2; direction = Valley } }
  | MOUNTAIN                  { { moving = None; direction = Mountain } }
  | MOVING point_ref MOUNTAIN { { moving = Some $2; direction = Mountain } }
```

- [ ] **Step 5: Guard `@` in `lib/eval.ml`**

Change the `Crease` arm header (from Task 1):

```ocaml
      | Ast.Crease (name_opt, ax, _fold_opt, span) ->
```

to:

```ocaml
      | Ast.Crease (name_opt, ax, fold_opt, span) ->
          (match fold_opt with
           | Some _ -> Error.fail span "folding (@) is not yet implemented"
           | None -> ());
```

(The existing body of the arm — `let line, axiom, sources = eval_axiom span ax in …` — follows unchanged.)

- [ ] **Step 6: Format, build, and run the tests**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: all tests PASS, including the four new cases.

- [ ] **Step 7: Commit**

```bash
git add lib/lexer.ml lib/parser.mly lib/eval.ml tests/test_beloch.ml
git commit -m "feat(syntax): parse '@' fold modifier with moving/mountain (eval pending)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Spec, ADR, and example documentation

Bring the prose artifacts in line with the syntax: update `spec/SPECIFICATION.md` (verbs + grammar), record the pivot in an ADR, and fix example header comments that still say "fold".

**Files:**
- Modify: `spec/SPECIFICATION.md`
- Create: `decisions/0011-action-model.md`
- Modify: `examples/x-midpoint.bel` (header comment), `examples/bisect-a.bel`, `examples/bisect-b.bel`, `examples/bisect-intermediate.bel`, `examples/bisect-parallel.bel` (header comments mentioning `fold`/`bisect`)

**Interfaces:** none (documentation only).

- [ ] **Step 1: Update `spec/SPECIFICATION.md` §4.2 (axiom 2)**

Replace the `### 4.2` code block `fold .x to .y` with `map .x onto .y`, and in the prose replace "fold one point onto another" usages of the *verb* with `map … onto …`. Keep the axiom **number** (2) and the bisector math unchanged. Add at the end of §4.2: "*(since v0.6-dev: verb is `map … onto …`; was `fold … to …`.)*"

- [ ] **Step 2: Update `spec/SPECIFICATION.md` §4.5 (axiom 5)**

Replace `bisect --l1 --l2 toward .p` with `map --l1 onto --l2 toward .p` in the code block and prose. Add: "*(since v0.6-dev: verb is `map … onto …`; was `bisect …`.)*"

- [ ] **Step 3: Update Appendix A grammar in `spec/SPECIFICATION.md`**

Replace the `axiom` and `crease_stmt` productions with:

```
crease_stmt := [ CREASE_NAME ":" ] [ "@" ] axiom [ "moving" point_ref ] [ "mountain" ]
axiom       := "through" point_ref point_ref            ; axiom 1
             | "map" point_ref "onto" point_ref         ; axiom 2
             | "perp" crease_ref "through" point_ref     ; axiom 3
             | "map" crease_ref "onto" crease_ref [ "toward" point_ref ]  ; axiom 5
```

Add a sentence: "A bare statement is a *precrease* (computes a crease line, paper stays flat). The `@` prefix marks an actual fold (`moving`/`mountain` describe it); fold **evaluation** is not yet implemented — `@` statements currently raise a compile error."

- [ ] **Step 4: Add §8 error and Appendix B notes in `spec/SPECIFICATION.md`**

In §8 (Errors), add a bullet: "`@` fold statement — folding is not yet implemented." In Appendix B, note that mountain/valley direction is now *derived* from fold actions (see the action-model design), and that the `map`/`@` surface has landed.

- [ ] **Step 5: Write the ADR `decisions/0011-action-model.md`**

```markdown
# 0011 — Beloch is an action model (folding), not only crease-pattern construction

## Status
Accepted (2026-06-29)

## Context
Beloch v0.0–v0.4 was a crease-pattern *construction* language: Huzita-Justin axioms
on the flat sheet, evaluated order-independently into a flat crease pattern. The
planned mountain/valley *annotation* slice exposed two facts: (1) there is no mountain
fold on a flat desk — M/V is relative to a side, not intrinsic to the act of folding;
(2) the original intent was to describe the *actions* performed on real paper, including
folding through all layers of an already-folded stack.

A landscape check (2026-06-29) found the combination unoccupied: a textual action
sequence + exact constructible arithmetic through the fold + action-derived layer
ordering + dual FOLD (`creasePattern` + `foldedForm`) output. The nearest "competitor"
(Kleinlaut) is fabricated AI content; the Haskell axiom eDSL overlaps only the axiom
layer.

## Decision
Beloch is an **action model**: a `.bel` program is an imperative sequence of folding
actions on a stateful sheet. The flat crease pattern and mountain/valley become *derived*
outputs. The Huzita-Justin axioms remain the "where is the crease" primitive. Geometry
stays exact (`Num`); arbitrary/animated fold angles use constructible-rational
approximation. The folded state is the standard FOLD `foldedForm` (faces + per-face
isometry + an addressable layer stack). Surface syntax: bare axiom = precrease;
`@axiom [moving .p] [mountain]` = fold; superposition axioms 2 & 5 unify under
`map … onto …`.

Full design and the staged "ladder" (simple fold → layer selection → unfold/maneuvers):
`docs/superpowers/specs/2026-06-29-action-model-folding-design.md`.

## Consequences
- Breaking syntax change (`fold`/`bisect` → `map … onto …`); acceptable pre-1.0.
- The mountain/valley *annotation* slice is obsolete.
- Engineering/rigid-panel thickness is out of scope; thickness is a display-only offset.
- The folded-state runtime and its output land in a later, separately-designed plan.
```

- [ ] **Step 6: Fix example header comments**

In each of `examples/x-midpoint.bel`, `examples/bisect-a.bel`, `examples/bisect-b.bel`, `examples/bisect-intermediate.bel`, `examples/bisect-parallel.bel`, update any `;`-comment that still uses the words "fold … to" / "bisect" *as the verb* to read `map … onto` / `map … onto … toward` so the prose matches the code. (Functional lines were already migrated in Task 1.)

- [ ] **Step 7: Verify the suite still builds and passes (docs shouldn't break it)**

Run: `dune build 2>&1 && dune test 2>&1`
Expected: all tests PASS (no code changed; this guards against an accidental edit to a `.bel` example consumed by an e2e test).

- [ ] **Step 8: Commit**

```bash
git add spec/SPECIFICATION.md decisions/0011-action-model.md examples
git commit -m "docs: spec + ADR for action-model syntax (map verb, @ fold modifier)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage** (against the design doc's syntax section §4 + verb-set §4.2):
- `map … onto …` rename (axioms 2 & 5), type-dispatched → Task 1.
- `through` / `perp` keep their verbs → unchanged (Task 1 grammar retains them).
- `@` fold modifier, `moving .p`, `mountain` (default valley) → Task 2.
- Precrease = bare axiom; `@` = fold → Task 1 (`None`) + Task 2 (`Some`).
- Fold *execution* (folded-state runtime, `foldedForm`, derived M/V, dual FOLD) → **explicitly deferred to Plan B**; Task 2 guards it with a "not yet implemented" error. This is intentional scope, not a gap.

**Placeholder scan:** no "TBD"/"handle appropriately" — every step shows exact old/new code or exact `.bel` line replacements.

**Type consistency:** `MapPoints`/`MapLines`/`fold_spec`/`direction`/`Crease`-arity-4 are defined in Task 1 Step 1 and used identically in Task 1 (eval, tests) and Task 2 (grammar actions, tests, eval guard). The eval `Crease` arm is `_fold_opt` in Task 1 and becomes `fold_opt` + guard in Task 2 — consistent.
