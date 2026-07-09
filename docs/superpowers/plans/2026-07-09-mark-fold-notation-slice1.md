# mark / fold notation — Slice 1 (surface + U→F) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `@`/bare-axiom crease notation with the write verbs
`mark`, `fold`, `collapse` and motions-as-values, and correct the FOLD
assignment of flat creases from `U` to `F` — behavior-preserving except that
intended `U`→`F` change.

**Architecture:** The current evaluator fuses "describe a crease line" and
"materialise it" into one act: a bare `axiom` statement subdivides (assignment
`U`), `@axiom` folds, `@fold`/`@collapse` act on existing creases. This slice
separates description from disposition at the *surface*: `map`/`through`/`perp`
become bindable line **values** (`--l = map .a onto .b`, no material effect);
`mark <motion>` is the flat crease (was a bare precrease, now emits `F`);
`fold <motion|--crease> …` is the fold (was `@map`/`@fold`); `collapse …` drops
its `@`. Internally `mark` still subdivides exactly as a precrease does today —
non-subdividing *partial* marks, snapping, and CP-frame M/V intent are Slice 2.

**Tech Stack:** OCaml, dune, Menhir (`lib/parser.mly`), sedlex
(`lib/lexer.ml`), Alcotest (`tests/`), golden FOLD fixtures
(`tests/test_golden.ml`, `tests/golden/`).

## Global Constraints

- Exact rational/algebraic geometry only; no float in evaluator logic (float
  appears only at JSON serialisation). This slice touches no numeric kernel.
- FOLD `edges_assignment` values Beloch emits after this slice: `B`, `M`, `V`,
  `F` only — never `U` (`refs/foldformat.md`: `F` = "present but not folded";
  `U` = direction unknown, which Beloch never is).
- Every task ends `dune build` + `dune test` green (except intermediate steps
  *within* the one notation-switch task, which is red until its final step).
- Conventional commits. Do not `git add -A` (repo has untracked `site/`,
  `.claude/worktrees/`); add named paths only.
- Work on branch `design/mark-fold-notation` (already checked out).

---

### Task 1: Characterization safety net — freeze current FOLD output

Capture every example's current FOLD output *before* any change, so the only
diffs later are the intended `U`→`F` and the notation rewrites.

**Files:**
- Create: `tests/golden/_pre_slice1/` (throwaway snapshot dir, git-ignored)
- Reference: `examples/**/*.bel`, `bin/main.ml` (the CLI entry)

**Interfaces:**
- Produces: a snapshot script `scripts/snapshot-fold.sh` reused in Task 7.

- [ ] **Step 1: Write the snapshot script**

Create `scripts/snapshot-fold.sh`:

```bash
#!/usr/bin/env bash
# Render every example to FOLD into $1 (default: a fresh temp dir), for
# before/after diffing across the notation cutover.
set -euo pipefail
out="${1:?usage: snapshot-fold.sh OUTDIR}"
mkdir -p "$out"
dune build 2>/dev/null
find examples -name '*.bel' | while read -r f; do
  name="${f#examples/}"; name="${name//\//__}"
  if dune exec --no-build bin/main.exe -- "$f" > "$out/$name.fold" 2>"$out/$name.err"; then
    rm -f "$out/$name.err"
  fi
done
echo "snapshotted $(find "$out" -name '*.fold' | wc -l) examples to $out"
```

- [ ] **Step 2: Run it against current `main`-notation source**

Run: `bash scripts/snapshot-fold.sh tests/golden/_pre_slice1`
Expected: prints "snapshotted N examples"; `.err` files only for examples
already known to fail (e.g. `through.bel` bench-slow — note them).

- [ ] **Step 3: Add the snapshot dir to .gitignore**

Add line `tests/golden/_pre_slice1/` to `.gitignore`.

- [ ] **Step 4: Commit the script**

```bash
git add scripts/snapshot-fold.sh .gitignore
git commit -m "test(notation): fold snapshot script for the mark/fold cutover"
```

---

### Task 2: Flat creases emit `F`, not `U`

Smallest real behavior change, isolated and golden-gated. Add an `F` case to the
assignment type, make `subdivide` tag precreases `F`, and map it in the emitter.

**Files:**
- Modify: `lib/fold_state.ml` (`type assign`, `subdivide`)
- Modify: `lib/fold_emit.ml` (`U` string cases ~:68 and ~:196; `edges_foldAngle`)
- Test: `tests/test_fold_emit.ml` (or the existing emit test module)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Fold_state.assign` gains constructor `F`; `subdivide` emits `F`.
  `Fold_emit` maps `F -> "F"` with fold angle `0`.

- [ ] **Step 1: Write a failing test — a bare precrease emits `F`**

In the emit test module add:

```ocaml
let test_precrease_is_F () =
  let fold = Beloch.fold_string "paper square\nmark map .a onto .c\n" in
  (* NOTE: uses Slice-1 `mark` syntax; if Task 4 not yet landed, temporarily
     use the pre-cutover source "map .a onto .c" and update in Task 4. *)
  let assigns = Test_util.edges_assignment fold in
  Alcotest.(check bool) "no U in output" false (List.mem "U" assigns);
  Alcotest.(check bool) "has an F crease" true (List.mem "F" assigns)
```

If `Test_util.edges_assignment` does not exist, add a small helper that parses
the emitted JSON and returns the `edges_assignment` string list.

- [ ] **Step 2: Run it — expect FAIL (still emits `U`)**

Run: `dune test 2>&1 | grep -A3 precrease_is_F`
Expected: FAIL — output contains `U`.

- [ ] **Step 3: Add `F` to the assignment type**

In `lib/fold_state.ml`:

```ocaml
type assign = M | V | F | U
```

(Keep `U` in the type for now; nothing will construct it after this task, but a
belt-and-suspenders emitter mapping stays valid.)

- [ ] **Step 4: Make `subdivide` tag `F`**

In `lib/fold_state.ml` `subdivide`, change the edge record assignment from
`eassign = U` to `eassign = F` (the single seed-edge construction site — search
for `eassign = U`).

- [ ] **Step 5: Map `F` in the emitter**

In `lib/fold_emit.ml`, both edge-collection sites (~:66 and ~:194), add the arm:

```ocaml
| Fold_state.F -> "F"
```

and in the `edges_foldAngle` match add `| "F" -> `Float 0.0` alongside the
existing `U` angle-0 case. Keep the `U -> "U"` arm as an unreachable fallback.

- [ ] **Step 6: Run the new test — expect PASS**

Run: `dune test 2>&1 | grep -A3 precrease_is_F`
Expected: PASS.

- [ ] **Step 7: Re-baseline goldens (U→F only)**

Run: `dune test 2>&1 | grep -i golden` to see which goldens now differ. For each
differing golden, confirm the *only* change is `"U"`→`"F"` in
`edges_assignment` (diff it), then regenerate:

```bash
# regenerate the goldens (see tests/test_golden.ml for the regen mechanism —
# typically a BELOCH_REGEN=1 env or a `dune exec` regen target)
BELOCH_REGEN=1 dune test 2>/dev/null || true
git diff --stat tests/golden
```

Manually inspect: `git diff tests/golden` must show *only* `U`→`F`.

- [ ] **Step 8: Commit**

```bash
git add lib/fold_state.ml lib/fold_emit.ml tests/ tests/golden
git commit -m "feat(fold): flat creases emit F not U (refs/foldformat.md)"
```

---

### Task 3: Lexer — add the `mark` keyword

**Files:**
- Modify: `lib/lexer.ml` (keyword table)
- Modify: `lib/parser.mly` (`%token` declaration)
- Test: `tests/test_lexer.ml` (if present) or fold into Task 4's parse tests

**Interfaces:**
- Produces: token `MARK`.

- [ ] **Step 1: Declare the token**

In `lib/parser.mly`, add `MARK` to the relevant `%token` line (near `FOLD_KW`,
`COLLAPSE`).

- [ ] **Step 2: Lex the keyword**

In `lib/lexer.ml`, add before the generic `id` arm:

```ocaml
  | "mark" -> MARK
```

- [ ] **Step 3: Build**

Run: `dune build`
Expected: succeeds (token declared and produced; not yet used in a rule —
Menhir warns about an unused token, which is fine until Task 4).

- [ ] **Step 4: Commit**

```bash
git add lib/lexer.ml lib/parser.mly
git commit -m "feat(lexer): mark keyword token"
```

---

### Task 4: The notation switch — AST, grammar, eval (one atomic task)

Grammar, AST, and eval are mutually dependent; this task is red between its steps
and green only at the end. Replace the `@`/bare-axiom statements with
`BindLine` / `Mark` / `Fold`, drop the `@` productions, keep `Collapse` but drop
its `@`.

**Files:**
- Modify: `lib/ast.ml` (statement constructors)
- Modify: `lib/parser.mly` (`body_stmt`, retire `AT` productions)
- Modify: `lib/eval.ml` (statement dispatch ~:1085–1420)
- Test: `tests/test_parse.ml`, `tests/test_eval.ml` (new-syntax cases)

**Interfaces:**
- Consumes: `Fold_state.subdivide` (emits `F`, Task 2); the existing `run_fold`
  helper (`lib/eval.ml`), `Collapse.collapse`, `bind_crease`, `bind_point`,
  `resolve_line`.
- Produces: AST `Ast.BindLine of string * axiom * span`,
  `Ast.Mark of string option * markable * span`,
  `Ast.Fold of string option * markable * fold_spec * span`, where
  `markable = MMotion of axiom | MLine of line_operand`. `Ast.Crease` and
  `Ast.FoldAlong` are **removed**; `Ast.Collapse` unchanged.

- [ ] **Step 1: Rewrite the AST statement constructors**

In `lib/ast.ml`, replace `Crease` and `FoldAlong` with:

```ocaml
(* a thing that can be creased/folded: a fresh motion, or an existing line *)
type markable =
  | MMotion of axiom          (* map/through/perp — a fresh crease line *)
  | MLine of line_operand     (* an existing material crease or bound value *)

type stmt =
  | BindLine of string * axiom * Error.span
      (* --l = map .a onto .b : bind a pure line VALUE; no material effect *)
  | Mark of string option * markable * Error.span
      (* mark <motion|--l> [= motion] : flat crease (subdivide, emits F).
         name_opt Some = `mark --l = <motion>` bind-and-materialise. *)
  | Fold of string option * markable * fold_spec * Error.span
      (* fold <motion|--l> [moving][up to][mountain] : fold. On a motion,
         subdivide+fold; on an existing --l, fold along it. *)
  | BindBundle of string * line_operand * Error.span
  | Point of string * point_expr * Error.span
  | Flip of Error.span
  | Def of string * param list * stmt list * Error.span
  | Apply of string option * string * arg list * Error.span
  | Export of export_entry list option * string * Error.span
  | StepMark of string * Error.span
  | Collapse of collapse_elem list * (flap_arg * flap_arg) list
                * flap_arg option * Error.span
```

- [ ] **Step 2: Rewrite the grammar productions**

In `lib/parser.mly` `body_stmt`, remove the four crease/fold lines
(`CREASE EQ axiom_stmt`, `axiom_stmt`, `AT FOLD_KW …`, `AT COLLAPSE …`) and the
`axiom_stmt`/`AT axiom` helper, and add:

```
  (* value binding: pure geometry, no material *)
  | CREASE EQ axiom                        { BindLine ($1, $3, $loc) }
  (* mark: flat crease *)
  | MARK markable                          { Mark (None, $2, $loc) }
  | MARK CREASE EQ axiom                   { Mark (Some $2, MMotion $4, $loc) }
  (* fold: motion-fold or fold-along *)
  | FOLD_KW markable fold_clauses          { Fold (None, $2, $3, $loc) }
  | FOLD_KW CREASE EQ axiom fold_clauses   { Fold (Some $2, MMotion $4, $5, $loc) }
  (* collapse: @ dropped *)
  | COLLAPSE collapse_items                { (* same body as today's AT COLLAPSE arm *) }

markable:
  | axiom        { MMotion $1 }
  | line_operand { MLine $1 }
```

Notes for the implementer:
- `axiom` already exists as a nonterminal (used by the old `axiom_stmt`); reuse
  it directly. `fold_clauses` (moving/up-to/mountain) is unchanged.
- FIRST-set check: `axiom` starts with `MAP`/`THROUGH`/`PERP`; `line_operand`
  starts with `CREASE`/`LINE_MEMBER_OPEN`/`POINT_MEMBER_OPEN`/`LBRACKET`/`.`…
  Disjoint, so `markable` is conflict-free. `MARK CREASE EQ` vs `MARK` +
  `line_operand` (`markable = MLine (LNamed …)`) differ by the following `EQ`;
  Menhir's LR(1) resolves this. Run `dune build` and inspect
  `lib/parser.conflicts` (gitignored) — there must be **0** conflicts.

- [ ] **Step 3: Rewrite eval dispatch**

In `lib/eval.ml`, replace the `Ast.Crease` and `Ast.FoldAlong` arms
(~:1085 and ~:1272) with `BindLine`, `Mark`, `Fold`. Factor the shared
axis-resolution (today inside the `Crease` arm) into a helper:

```ocaml
(* resolve a markable to (axis, prov, cid, side_override, implied) — the
   axis-of logic lifted verbatim from the old Crease arm, plus the MLine case
   which resolves an existing/bound line to its supporting line. *)
let resolve_markable ctx span (m : Ast.markable) ~(fold_opt : Ast.fold_spec option)
    ~(name_opt : string option) =
  match m with
  | Ast.MMotion ax ->
      let cid = Fold_state.fresh_crease_id () in
      let prov_name = (* … the exact prov_name block from the old Crease arm … *) in
      let axis, axiom, sources, side_override =
        match axis_of span ax with
        | Axis (axis, axiom, sources) -> (axis, axiom, sources, None)
        | Ax5 p ->
            let axis, so = match fold_opt with
              | None -> (select_axiom5_bind span p, None)
              | Some fs -> select_axiom5_fold span p ~fs in
            (axis, "axiom5", p.sources, so)
      in
      let prov = Some { State.axiom; sources; span; name = prov_name; step = ctx.panel } in
      let implied = match ax with
        | Ast.MapPoints (p,_) | Ast.MapThrough (p,_,_,_) | Ast.MapBoth (p,_,_,_,_) -> Some p
        | _ -> None in
      `Fresh (cid, axis, prov, side_override, implied)
  | Ast.MLine lo ->
      (* fold along an existing material crease — the old FoldAlong path *)
      `Existing lo
```

Then the arms:

```ocaml
| Ast.BindLine (n, ax, span) ->
    (* pure value: resolve the axiom to a line, bind Frozen, DO NOT subdivide *)
    let axis = match axis_of span ax with
      | Axis (axis, _, _) -> axis
      | Ax5 p -> select_axiom5_bind span p in
    bind_crease ctx n span (Frozen axis)

| Ast.Mark (name_opt, m, span) -> (
    match resolve_markable ctx span m ~fold_opt:None ~name_opt with
    | `Fresh (cid, axis, prov, _so, _impl) ->
        ctx.state := Fold_state.subdivide !(ctx.state) axis ~crease_id:cid ~prov;
        (match name_opt with
         | Some n -> bind_crease ctx n span (Material (cid, axis))
         | None -> ())
    | `Existing lo ->
        (* mark an already-bound value line: subdivide along it *)
        let axis = resolve_line lo in
        let cid = Fold_state.fresh_crease_id () in
        ctx.state := Fold_state.subdivide !(ctx.state) axis ~crease_id:cid ~prov:None)

| Ast.Fold (name_opt, m, fs, span) -> (
    match resolve_markable ctx span m ~fold_opt:(Some fs) ~name_opt with
    | `Fresh (cid, axis, prov, side_override, implied) ->
        run_fold ~span ~axis ~fs ~implied ~side_override ~crease_id:cid ~prov;
        (match name_opt with
         | Some n -> bind_crease ctx n span (Material (cid, axis))
         | None -> ())
    | `Existing lo ->
        (* the old FoldAlong body — verbatim from the removed arm at ~:1272 *)
        (* … resolve lo to a material crease, then run_fold along it … *)
        ())
```

Port the removed `FoldAlong` arm's body into the `` `Existing `` case verbatim.
`Collapse` arm is unchanged.

- [ ] **Step 4: Write parse + eval tests for the new syntax**

In `tests/test_parse.ml` / `tests/test_eval.ml`:

```ocaml
let ok src = ignore (Beloch.fold_string src)  (* raises on failure *)

let test_mark_precrease () = ok "paper square\nmark map .a onto .c\n"
let test_named_mark ()     = ok "paper square\nmark --d = map .a onto .c\n"
let test_value_binding ()  = ok "paper square\n--l = map .a onto .c\n"  (* no material *)
let test_fold_motion ()    = ok "paper square\nfold map .a onto .c moving .a\n"
let test_fold_along ()     =
  ok "paper square\n--d = map .a onto .c\nmark --d\nfold --d moving .a\n"
let test_collapse ()       = (* copy an existing @collapse example body, drop the @ *)
  ok "paper square\n… collapse … \n"
let test_at_is_gone ()     =
  Alcotest.check_raises "@ retired" (Failure "…")
    (fun () -> ok "paper square\n@map .a onto .c moving .a\n")
```

- [ ] **Step 5: Build and run — expect PASS**

Run: `dune build && dune test 2>&1 | tail -20`
Expected: build clean (0 parser conflicts), new tests PASS. **Existing** eval/
golden tests still use old syntax and will FAIL here — that is expected; they
are migrated in Task 5. Verify only the *new* tests pass and failures are
confined to old-syntax fixtures.

- [ ] **Step 6: Commit**

```bash
git add lib/ast.ml lib/parser.mly lib/eval.ml tests/test_parse.ml tests/test_eval.ml
git commit -m "feat(notation): mark/fold/collapse verbs replace @/bare-axiom"
```

---

### Task 5: Migrate the corpus, examples, embedded test sources, and spec

Mechanical find-replace-with-judgment across all `.bel` and embedded `.bel`
strings and the spec. This is the #24 method: dispatch parallel subagents over
disjoint file sets. Transformation rules:

| old | new |
|---|---|
| `map … onto …` / `through …` / `perp …` (bare, precrease) | `mark <same>` |
| `--d = map …` (named precrease) | `mark --d = map …` |
| `@map … moving m [mountain]` | `fold map … moving m [mountain]` |
| `--d = @map … moving m` | `fold --d = map … moving m` |
| `@fold --d moving m [up to u] [mountain]` | `fold --d moving m [up to u] [mountain]` |
| `@collapse …` | `collapse …` |

**Files:**
- Modify: `examples/**/*.bel` (all)
- Modify: any `.ml` test with embedded `.bel` source strings (grep
  `paper square` in `tests/` and `lib/`)
- Modify: `spec/SPECIFICATION.md` (§4.6 `@`/verbs, §4.9 `@collapse`, §4.10
  read/write law, §5 statement grammar, grammar Appendix A, bump to `v0.21-dev`)
- Reference: `docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md`

**Interfaces:**
- Consumes: the Task-4 grammar (source must parse under it).

- [ ] **Step 1: Inventory the files**

Run:
```bash
find examples -name '*.bel' | sort
rg -l 'paper square' tests lib --type ml
rg -n '@(map|fold|collapse)|^\s*(map|through|perp) |= (map|through|perp|@)' spec/SPECIFICATION.md | head
```
Record the list; split into ~3 disjoint groups for parallel migration.

- [ ] **Step 2: Migrate examples (dispatch subagents, disjoint groups)**

Dispatch one subagent per group with the transformation table above and this
rule: **a `mark`/`fold` must parse and the example must still render** — after
rewriting a file, run `dune exec --no-build bin/main.exe -- <file>` and confirm
it produces FOLD (or the same known error as before). Do not change geometry.

- [ ] **Step 3: Migrate embedded test sources**

Rewrite every `paper square\n…` string literal in `tests/`/`lib/` to the new
verbs (same table). These feed `Beloch.fold_string`.

- [ ] **Step 4: Migrate the spec**

Update `spec/SPECIFICATION.md`: rename the verbs in §4.6/§4.9, rewrite §4.10 to
state the completed law (motions read, `mark`/`fold`/`collapse` write; `@`
retired), fix the §5 statement examples and Appendix A grammar, bump version to
`v0.21-dev`. Add a short "since v0.21-dev" note on `F` for flat creases in §7.

- [ ] **Step 5: Build + full suite**

Run: `dune build && dune test 2>&1 | tail -20`
Expected: build clean; all eval/parse tests green. Golden tests may still differ
(notation rewrite can reorder/rename provenance) — handled in Task 7.

- [ ] **Step 6: Commit**

```bash
git add examples tests lib spec/SPECIFICATION.md
git commit -m "refactor(notation): migrate corpus, tests, and spec to mark/fold"
```

---

### Task 6: Retire dead `@`/`U` scaffolding

Remove what the cutover orphaned.

**Files:**
- Modify: `lib/parser.mly` (`AT` token if now unused by any production),
  `lib/lexer.ml` (`'@' -> AT` if `AT` fully unused)
- Modify: `lib/fold_state.ml` / `lib/fold_emit.ml` (drop the `U` constructor only
  if nothing references it)

**Interfaces:** none.

- [ ] **Step 1: Check whether `AT` is still used**

Run: `rg -n '\bAT\b' lib/parser.mly`
If `AT` appears in no production, remove the `AT` `%token` entry and the
`'@' -> AT` lexer arm. If any production still uses it (none should after Task
4), leave it and note why.

- [ ] **Step 2: Decide on the `U` constructor**

Run: `rg -n 'Fold_state.U|\bU\b' lib/*.ml`
`U` should be constructed nowhere after Task 2. Keep the `U -> "U"` emitter arm
as a defensive fallback (harmless), OR remove the constructor if the compiler
confirms it is unconstructed and you prefer a tighter type. Either is fine;
prefer keeping the type total and dropping only if it is genuinely dead.

- [ ] **Step 3: Build + test**

Run: `dune build && dune test 2>&1 | tail -5`
Expected: green.

- [ ] **Step 4: Commit**

```bash
git add lib/parser.mly lib/lexer.ml lib/fold_state.ml lib/fold_emit.ml
git commit -m "chore(notation): retire the @ marker and unused U path"
```

---

### Task 7: Golden re-baseline + before/after audit

Prove the cutover is behavior-preserving modulo `U`→`F` and provenance renames.

**Files:**
- Modify: `tests/golden/**` (regenerated)
- Reference: `tests/golden/_pre_slice1/` (Task 1 snapshot)

**Interfaces:** none.

- [ ] **Step 1: Snapshot the post-cutover output**

Run: `bash scripts/snapshot-fold.sh /tmp/post_slice1`

- [ ] **Step 2: Diff geometry, ignoring assignment + provenance strings**

For each example, diff pre vs post `vertices_coords` and `faces_vertices`
(these must be **identical** — geometry unchanged), and confirm
`edges_assignment` differs only by `U`→`F`:

```bash
for f in tests/golden/_pre_slice1/*.fold; do
  b="$(basename "$f")"
  jq -S '{vertices_coords, faces_vertices}' "$f" > /tmp/a.json
  jq -S '{vertices_coords, faces_vertices}' "/tmp/post_slice1/$b" > /tmp/b.json
  diff -q /tmp/a.json /tmp/b.json || echo "GEOMETRY CHANGED: $b"
done
```
Expected: **no** "GEOMETRY CHANGED" lines. Investigate any that appear — a
geometry change means the migration altered a fold, not just its notation.

- [ ] **Step 3: Regenerate goldens**

Run: `BELOCH_REGEN=1 dune test 2>/dev/null || true`
Then inspect `git diff tests/golden`: assignment `U`→`F` and any provenance
`name`/`axiom` string updates are expected; coordinates and face topology are
not.

- [ ] **Step 4: Full suite green**

Run: `dune test 2>&1 | tail -5`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add tests/golden
git commit -m "test(notation): re-baseline goldens (U→F, verb rename)"
```

---

## Self-Review notes

- **Spec coverage.** This slice implements the design doc's §3 (motion=read,
  `mark`/`fold` writes), §4 surface (full extent only), §6 (`F` assignment), and
  §4-migration table. Deliberately **out of scope** (design §8/§10, planned as
  Slice 2+): partial marks / non-subdividing records / `between`/`at`, snapping,
  dir-on-`mark` + CP-frame M/V intent, layer `#[…]` selection for marks, history,
  and everything 3D/numeric. Slice 1 keeps `mark` = today's subdividing precrease
  so no marks-as-records machinery is needed.
- **Right-sizing.** Task 4 is deliberately one atomic task (grammar+AST+eval are
  mutually dependent; a partial switch does not build). Its internal steps are
  red until Step 5. All other tasks are independently green.
- **Follow-ups for Slice 2:** non-subdividing partial marks (the `marks` record,
  `between .a .b` / `at .p`), snapping, `mark … valley/mountain` → CP intent,
  `#[…]` layer selection, and the terse `.a onto .b` motion sugar (Slice 1 keeps
  the explicit `map`/`through`/`perp` keyword on motions).

## References

- Design: `docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md`
- `refs/foldformat.md` (`edges_assignment` `F`/`U`, `edges_foldAngle`)
- Current grammar/AST/eval: `lib/parser.mly` (`body_stmt`, `axiom`,
  `fold_clauses`), `lib/ast.ml` (`stmt`, `axiom`, `markable` to add),
  `lib/eval.ml` (`Crease` :1085, `FoldAlong` :1272, `Collapse` :1318),
  `lib/fold_state.ml` (`assign`, `subdivide`), `lib/fold_emit.ml` (`U` :68/:196).
- Prior cutover method (parallel-subagent migration): PR #24 (notation cutover).
