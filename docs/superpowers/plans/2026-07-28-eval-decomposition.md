# eval.ml Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `packages/core/lib/eval.ml` (2725 lines, of which one function
`eval_program` is 2416) into five modules with explicit interfaces, without
changing a single byte of evaluator output.

**Architecture:** Every mutable evaluator state already lives in the top-level
record type `ctx` (`eval.ml:140`); `rg -n '^  let [a-z_]+ = ref ' eval.ml`
returns zero hits. The nesting inside `eval_program` is therefore closure
convenience, not a data dependency: each nested helper can be lifted to
top-level by taking `ctx` as its first parameter — the pattern `lookup_point
ctx pr` already uses. The call graph across the intended cut is acyclic
(verified 2026-07-28): the resolve block calls nothing above it, `axis_of`
calls only `resolve_line`, `run_fold*` calls only resolve-block helpers, and
the flatten arm calls resolve-block helpers plus `Flatten`/`Collapse`.

```
Ctx  ←  Resolve  ←  Axiom
 ↑         ↑          ↑
 └──── Flatten_solve ─┘
 └──── Eval
```

**Tech Stack:** OCaml 5 / dune 3.21.1 / Menhir / sedlex / alcotest. The build
only works inside the repo's direnv environment — bare `dune build` fails with
`Library "sedlex.ppx" not found`. Always prefix: `direnv exec
/home/toph/Projects/beloch dune build`.

## Global Constraints

- **This is a pure move refactor. No behaviour change is permitted.** If a
  move seems to require a logic change, stop and report instead of changing it.
- **Verification gate after every task:** `bash /home/toph/.claude/jobs/7c90ec32/tmp/verify.sh`
  must print `VERIFY: GREEN`. It checks three things: build green, per-suite
  alcotest failures identical to the pre-refactor baseline, and all 71
  `beloch fold` outputs byte-identical by sha256.
- **Known pre-existing failures — do NOT fix, do NOT chase:** `test_bel_assert`
  cases 3/4/5 (`collapse/flatten-fish-pinned-unique.bel`,
  `collapse/flatten-opposite-ray-toward-b.bel`, `-toward-d.bel`), `test_e2e`
  `e2e 0 diagonals`, `test_eval` `fold_state 14`, `test_flatten` `derive 5`.
  The verify script treats these as the expected baseline; making them pass
  would also count as a DIFF and must be reported, not committed.
- **Public API of `Eval` must not change.** These names are consumed by
  `packages/core/lib/fold_emit.ml`, `packages/core/lib/session.ml`,
  `packages/core/lib/beloch.ml`, five test suites, and
  `packages/www/public/beloch/beloch-eval.js`:
  `Eval.eval_folded`, `Eval.eval_program`, `Eval.folded` and its fields
  (`state`, `named_points`, `named_lines`, `named_line_cids`, `frames`,
  `statements`, `free_points`), `Eval.snapshot`, `Eval.restore`,
  `Eval.stmt_log_entry` and its fields (`sl_kind`, `sl_span`, `sl_mark`,
  `sl_kept`, `sl_frame_index`), `Eval.free_info` and its fields (`fi_p`,
  `fi_t`, `fi_source_line`). Where a symbol moves to `Ctx`, re-export it from
  `eval.ml` as an alias (`type snapshot = Ctx.snapshot`, `let snapshot =
  Ctx.snapshot`) rather than editing the consumers.
- **Module order in `packages/core/lib/dune`:** dune infers dependency order
  automatically; no `(modules)` edit is needed unless the build reports a
  cycle. If it does, that is a real cycle — report it, do not paper over it.
- **Commit style:** conventional commits, concise subject, no body unless the
  "why" is non-obvious. Commit after every task.

---

### Task 1: Extract `Ctx`

**Files:**
- Create: `packages/core/lib/ctx.ml`
- Modify: `packages/core/lib/eval.ml:1-346`

**Interfaces:**
- Produces: module `Ctx` exposing types `stmt_kind`, `stmt_log_entry`,
  `free_info`, `crease_val`, `instance`, `scope`, `name_ctx`, `ctx`,
  `snapshot`; values `corners`, `make_scope`, `lookup_point`, `lookup_crease`,
  `lookup_instance`, `is_temp`, `intent_of`, `flap_lookup_result`,
  `bind_point`, `bind_crease`, `promote_crease`, `copy_instance`,
  `copy_instances`, `snapshot`, `restore_tbl`, `restore`, `push_frame`.
  All take `ctx` explicitly as their first parameter where they touch state.

- [ ] **Step 1: Read the source region**

Read `packages/core/lib/eval.ml` lines 1–346 in full, plus lines 309–346
(the head of `eval_program`, which contains `push_frame`).

- [ ] **Step 2: Create `ctx.ml` by moving these definitions verbatim**

Move, in this order, keeping bodies byte-identical apart from the `ctx`
parameter noted below:

| eval.ml line | symbol |
|---|---|
| 4 | `corners` |
| 13 | `type stmt_kind` |
| 15 | `type stmt_log_entry` |
| 37 | `type free_info` |
| 66 | `type crease_val` |
| 100 | `type instance` |
| 113 | `type scope` |
| 130 | `make_scope` |
| 138 | `type name_ctx` |
| 140 | `type ctx` |
| 155 | `lookup_point` |
| 160 | `lookup_crease` |
| 165 | `lookup_instance` |
| 172 | `is_temp` |
| 174 | `intent_of` |
| 182 | `flap_lookup_result` |
| 189 | `bind_point` |
| 199 | `bind_crease` |
| 212 | `promote_crease` |
| 222 | `type snapshot` |
| 240 | `copy_instance` |
| 247 | `copy_instances` |
| 256 | `snapshot` |
| 278 | `restore_tbl` |
| 286 | `restore` |
| 329 | `push_frame` |

**Do NOT move** `type folded` (line 44), `type ax5_pending` (line 84), or
`type axis_result` (line 96) — they stay in `eval.ml` for now and are handled
in Task 3.

`push_frame` is currently nested and closes over `ctx`. Lift it and give it an
explicit `ctx` first parameter. Current body at `eval.ml:329`:

```ocaml
  let push_frame (span : Error.span option) =
    ...
  in
```

becomes, in `ctx.ml`:

```ocaml
let push_frame (ctx : ctx) (span : Error.span option) =
  ...
```

with the body otherwise unchanged.

- [ ] **Step 3: Delete the moved definitions from `eval.ml` and add aliases**

At the top of `eval.ml`, after the module docstring, add:

```ocaml
open Ctx

(* Re-exported so the public [Eval] surface is unchanged for fold_emit,
   session, the test suites and packages/www/public/beloch/beloch-eval.js. *)
type snapshot = Ctx.snapshot
type stmt_kind = Ctx.stmt_kind = SFold | SMark
type stmt_log_entry = Ctx.stmt_log_entry
type free_info = Ctx.free_info
let snapshot = Ctx.snapshot
let restore = Ctx.restore
```

Use type equations (`type t = Ctx.t = { ... }`) where the consumers pattern
match on constructors or access record fields, so the fields stay reachable as
`Eval.sl_kind` etc. If the compiler reports a field or constructor as
unreachable through the alias, write the full equation with the constructor or
field list repeated.

Inside `eval_program`, replace every `push_frame (Some span)` with
`push_frame ctx (Some span)` — four call sites at lines 1693, 1731, 1781, 2653
of the pre-refactor file.

- [ ] **Step 4: Build**

Run: `direnv exec /home/toph/Projects/beloch dune build`
Expected: exit 0, no output.

- [ ] **Step 5: Verify against the baseline**

Run: `bash /home/toph/.claude/jobs/7c90ec32/tmp/verify.sh`
Expected: last line `VERIFY: GREEN`, and `all 71 outputs byte-identical`.

- [ ] **Step 6: Commit**

```bash
git add packages/core/lib/ctx.ml packages/core/lib/eval.ml
git commit -m "refactor(core): lift evaluator context out of eval.ml into Ctx"
```

---

### Task 2: Extract `Resolve`

**Files:**
- Create: `packages/core/lib/resolve.ml`
- Modify: `packages/core/lib/eval.ml` (regions 347–937 and 1444–1570 of the
  pre-refactor file; line numbers will have shifted after Task 1 — locate by
  symbol name with `rg -n`, not by number)

**Interfaces:**
- Consumes: everything from `Ctx` (Task 1).
- Produces: module `Resolve` whose every stateful function takes `(ctx :
  Ctx.ctx)` as its first parameter. Exposed: `pstr`, `lstr`, `selstr`, `fstr`,
  `corner_point`, `materialize_crease`, `paper_line_of_crease`,
  `face_of_points`, `resolve_point`, `resolve_line`, `resolve_paper_line`,
  `material_cid`, `seg_line`, `point_on_seg`, `seg_incident`,
  `select_candidates`, `cand_incident`, `select_cand`, `select_line`,
  `select_point`, `span_of_line`, `bundle_segments`, `coerce_one_segment`,
  `table_of`, `faces_containing`, `resolve_flap_cluster`,
  `resolve_sector_face`, `side_of_flap_arg_res`, `side_of_flap_arg`,
  `anchor_faces`, `default_move_side`, `target_of`, `resolve_mark_extent`,
  `resolve_mark_flap`.

**Correction, found during Task 2 (2026-07-28):** `resolve_markable`
(pre-refactor 1444–1496) calls `axis_of`, `select_axiom5_bind` and
`select_axiom5_fold`, all of which live in the `Axiom` layer *above*
`Resolve`. Putting it in `Resolve` is a genuine dependency cycle, which the
build catches as `Error: Unbound value axis_of`. The pre-plan call-graph check
covered regions 501–937, 938–1115, 1116–1260, 1261–1443 and 2016–2653 but not
1444–1570, which is how it slipped through. `resolve_markable` therefore
**stays in `eval.ml`**, alongside `run_fold*`. `resolve_mark_extent` and
`resolve_mark_flap` call nothing above themselves and do move into `Resolve`.
The real layering is:

```
Ctx  ←  Resolve  ←  Axiom  ←  { resolve_markable, run_fold*, Flatten_solve }  ←  Eval
```

- [ ] **Step 1: Move the two regions into `resolve.ml`**

Move these symbol groups, preserving their order and their bodies:

1. The mutually recursive diagnostic printers — `let rec pstr` / `and lstr` /
   `and selstr` / `and fstr` (pre-refactor 347–377). These call `resolve_point`
   indirectly through nothing; check with `rg`. If they are self-contained,
   they need no `ctx`.
2. `corner_point`, `materialize_crease`, `paper_line_of_crease`,
   `face_of_points` (378–500).
3. **One `let rec … and …` chain, which must stay a single chain:**
   `resolve_point`, `resolve_line`, `resolve_paper_line`, `material_cid`,
   `seg_line`, `point_on_seg`, `seg_incident`, `select_candidates`,
   `cand_incident`, `select_cand`, `select_line`, `select_point`,
   `span_of_line`, `bundle_segments`, `coerce_one_segment` (501–732).
4. `table_of`, `faces_containing`, `resolve_flap_cluster`,
   `resolve_sector_face`, `side_of_flap_arg_res`, `side_of_flap_arg`,
   `anchor_faces`, `default_move_side`, `target_of` (733–937).
5. `resolve_markable`, `resolve_mark_extent`, `resolve_mark_flap`
   (1444–1570).

Each function that references `ctx` gains `(ctx : Ctx.ctx)` as its first
parameter, and every call site inside the module threads `ctx` through. Start
`resolve.ml` with `open Ctx` so the record fields and constructors resolve
without qualification.

- [ ] **Step 2: Replace the definitions in `eval.ml` with qualified calls**

Delete the moved regions. In `eval_program`, every remaining call becomes
`Resolve.<name> ctx <args>`. Do not add local shim bindings such as
`let resolve_point po = Resolve.resolve_point ctx po` — thread `ctx` at the
call site so the dependency stays visible.

- [ ] **Step 3: Build**

Run: `direnv exec /home/toph/Projects/beloch dune build`
Expected: exit 0.

If dune reports `Dependency cycle between modules`, stop and report — the
verified call graph says there is none, so a cycle means a symbol was
misclassified.

- [ ] **Step 4: Verify**

Run: `bash /home/toph/.claude/jobs/7c90ec32/tmp/verify.sh`
Expected: `VERIFY: GREEN`.

- [ ] **Step 5: Commit**

```bash
git add packages/core/lib/resolve.ml packages/core/lib/eval.ml
git commit -m "refactor(core): move name and selector resolution into Resolve"
```

---

### Task 3: Extract `Axiom`

**Files:**
- Create: `packages/core/lib/axiom.ml`
- Modify: `packages/core/lib/eval.ml` (pre-refactor regions 84–99, 938–1115,
  1261–1443; locate by symbol name)

**Interfaces:**
- Consumes: `Ctx` (Task 1), `Resolve` (Task 2).
- Produces: module `Axiom` exposing types `ax5_pending`, `axis_result`; values
  `axis_of`, `ax5_material`, `swing_rep`, `viable`, `ax5_filter`, `e2`, `e3`,
  `e5_head`, `select_axiom5_bind`, `select_axiom5_fold`.

- [ ] **Step 1: Move the type declarations**

Move `type ax5_pending` (pre-refactor line 84) and `type axis_result`
(line 96) from `eval.ml` into `axiom.ml`. They are shared between `axis_of`
and `eval_stmt`, and `Eval` depends on `Axiom`, so `Axiom` is their home.

- [ ] **Step 2: Move `axis_of`**

Move `axis_of` (938–1115). It calls `resolve_line` eight times; those become
`Resolve.resolve_line ctx lo`. Signature becomes:

```ocaml
let axis_of (ctx : Ctx.ctx) (span : Error.span) (ax : Ast.axiom) : axis_result =
```

- [ ] **Step 3: Move the axiom-5 group**

Move `ax5_material`, `swing_rep`, `viable`, `ax5_filter`, `e2`, `e3`,
`e5_head`, `select_axiom5_bind`, `select_axiom5_fold` (1261–1443). This block
uses `ctx` six times; thread it as the first parameter of the functions that
need it and leave the pure-geometry ones (`swing_rep`, `viable`, `in`-style
predicates) without a `ctx` parameter.

- [ ] **Step 4: Update `eval.ml` call sites**

Every `axis_of span ax` becomes `Axiom.axis_of ctx span ax`; every
`select_axiom5_bind`/`select_axiom5_fold` call is qualified likewise. Pattern
matches on `axis_result` constructors need the constructors in scope — add
`open Axiom` at the top of `eval.ml` if the qualified form gets noisy, but
prefer explicit qualification.

- [ ] **Step 5: Build**

Run: `direnv exec /home/toph/Projects/beloch dune build`
Expected: exit 0.

- [ ] **Step 6: Verify**

Run: `bash /home/toph/.claude/jobs/7c90ec32/tmp/verify.sh`
Expected: `VERIFY: GREEN`.

- [ ] **Step 7: Commit**

```bash
git add packages/core/lib/axiom.ml packages/core/lib/eval.ml
git commit -m "refactor(core): move axiom construction into Axiom"
```

---

### Task 4: Extract `Flatten_solve`

**Files:**
- Create: `packages/core/lib/flatten_solve.ml`
- Modify: `packages/core/lib/eval.ml` (pre-refactor 2016–2653, the
  `| Ast.Flatten (...)` match arm of `eval_stmt`)

**Interfaces:**
- Consumes: `Ctx`, `Resolve`, plus the existing `Flatten` and `Collapse`
  modules.
- Produces: `Flatten_solve.run : Ctx.ctx -> name_opt:string option ->
  elems:Ast.collapse_elem list -> overs:<the type of the `overs` argument in
  the match arm> -> staying_opt:<its type> -> toward_opt:<its type> ->
  Error.span -> unit`. Read the exact constructor payload types off
  `Ast.Flatten` in `packages/core/lib/ast.ml` and use them verbatim; do not
  invent names.

- [ ] **Step 1: Move the arm body into a top-level function**

The arm currently reads:

```ocaml
     | Ast.Flatten (name_opt, elems, overs, staying_opt, toward_opt, span) ->
         <638 lines>
```

Move `<638 lines>` into `Flatten_solve.run` with the parameters above. The
arm-local helper `resolve_elem_candidates` (pre-refactor line 2046) is used
only here — it moves with the body and stays a local `let` inside `run`.

The body's tail (`bind_crease ctx n span cv` and `push_frame ctx (Some span)`)
uses `Ctx` functions, which is fine: `Flatten_solve` sits above `Ctx`.

Calls to resolve-block helpers become qualified: `Resolve.resolve_sector_face
ctx …`, `Resolve.resolve_point ctx …`, `Resolve.resolve_flap_cluster ctx …`,
`Resolve.bundle_segments ctx …`.

- [ ] **Step 2: Replace the arm with a one-line call**

```ocaml
     | Ast.Flatten (name_opt, elems, overs, staying_opt, toward_opt, span) ->
         Flatten_solve.run ctx ~name_opt ~elems ~overs ~staying_opt ~toward_opt span
```

- [ ] **Step 3: Build**

Run: `direnv exec /home/toph/Projects/beloch dune build`
Expected: exit 0.

- [ ] **Step 4: Verify**

Run: `bash /home/toph/.claude/jobs/7c90ec32/tmp/verify.sh`
Expected: `VERIFY: GREEN`. This is the highest-risk task — the flatten arm
carries the three known-red cases, so confirm the failure list is *identical*,
not merely non-empty.

- [ ] **Step 5: Commit**

```bash
git add packages/core/lib/flatten_solve.ml packages/core/lib/eval.ml
git commit -m "refactor(core): move the flatten solver arm into Flatten_solve"
```

---

### Task 5: Seal every new module with an `.mli`

**Files:**
- Create: `packages/core/lib/ctx.mli`, `resolve.mli`, `axiom.mli`,
  `flatten_solve.mli`, `eval.mli`

**Interfaces:**
- Consumes: all four new modules.
- Produces: explicit signatures. `fold_state.mli` is currently the only `.mli`
  in the core; match its documentation style (a module-level `(** … *)`
  docstring, then per-value doc comments for anything non-obvious).

- [ ] **Step 1: Generate a starting point per module**

For each module, dune can print the inferred signature:

```bash
direnv exec /home/toph/Projects/beloch dune build @packages/core/lib/ctx.mli-gen 2>/dev/null || true
direnv exec /home/toph/Projects/beloch ocamlfind ocamlc -package zarith -i \
  -I _build/default/packages/core/.beloch.objs/byte packages/core/lib/ctx.ml
```

If neither works in this environment, write the signature by hand from the
`.ml`. Do not skip a module because inference was awkward.

- [ ] **Step 2: Narrow each signature to what is actually used**

After writing the full inferred signature, delete every value that no other
module references. Find the real consumers with, e.g.:

```bash
rg -n 'Resolve\.[a-z_]+' packages/core/ --glob '!_build' | rg -o 'Resolve\.[a-z_]+' | sort -u
```

Keep types abstract only where nothing outside pattern matches on them — `ctx`
must stay a concrete record, because `Eval` reads its fields directly.

- [ ] **Step 3: `eval.mli` — the public surface**

`eval.mli` must expose exactly the names listed under "Public API of `Eval`"
in Global Constraints, and nothing else. Everything that is now internal
(`copy_instance`, `restore_tbl`, `ax5_pending`, …) must be absent.

- [ ] **Step 4: Build**

Run: `direnv exec /home/toph/Projects/beloch dune build`
Expected: exit 0. Signature mismatches surface here; each one is either a
missing entry in the `.mli` or a genuinely unused export that should be
deleted from the `.ml`.

- [ ] **Step 5: Verify**

Run: `bash /home/toph/.claude/jobs/7c90ec32/tmp/verify.sh`
Expected: `VERIFY: GREEN`.

- [ ] **Step 6: Commit**

```bash
git add packages/core/lib/*.mli
git commit -m "refactor(core): seal Ctx, Resolve, Axiom, Flatten_solve and Eval with interfaces"
```

---

### Task 6: Record the decision as ADR 0018 with the repo's first executable check

**Files:**
- Create: `decisions/0018-core-module-boundaries.md`
- Modify: `decisions/README.md` (index)

**Interfaces:**
- Consumes: the finished decomposition.
- Produces: an ADR whose `checks:` frontmatter is executable by `arch-check`.
  There are currently 17 records and zero checks in the repo, so this is the
  first one — the syntax to match is documented in `decisions/README.md`.

- [ ] **Step 1: Write the record**

Frontmatter, matching the format in `decisions/README.md`:

```yaml
---
id: "0018"
title: "Core module boundaries: Ctx, Resolve, Axiom, Flatten_solve, Eval"
date: 2026-07-28
status: accepted
checks:
  - desc: Every module in packages/core/lib has an .mli
    run: 'for f in packages/core/lib/*.ml; do case "$f" in *parser.ml) continue;; esac; [ -f "${f}i" ] || exit 1; done'
  - desc: eval.ml stays under 900 lines
    run: '[ "$(wc -l < packages/core/lib/eval.ml)" -lt 900 ]'
---
```

Note: the first check will fail today, because the pre-existing modules
(`geom.ml`, `num.ml`, `collapse.ml`, …) have no `.mli`. Either scope the check
to the five modules this ADR creates, or state the ratchet explicitly in the
record. Choose the scoped version — a check that is red on the day it lands
teaches everyone to ignore checks:

```yaml
  - desc: The five decomposed core modules each have an .mli
    run: 'for m in ctx resolve axiom flatten_solve eval; do [ -f "packages/core/lib/$m.mli" ] || exit 1; done'
```

Prose sections: **Context** (eval_program was 2416 lines in one function;
iteration cost was rising because every slice landed in the same file),
**Decision** (the five modules and the dependency order), **Alternatives
considered** (leave as-is; a functor over the context; splitting by statement
kind instead of by phase), **Consequences** (interfaces now constrain
refactors; `Flatten_solve` may absorb more of `Flatten`'s caller-side logic
later; `run_fold*` deliberately stayed in `Eval` and is a candidate for a
sixth module).

- [ ] **Step 2: Add the index line**

In `decisions/README.md`, under `## Index`, after the 0017 line:

```markdown
- [0018](0018-core-module-boundaries.md) — Core module boundaries
```

- [ ] **Step 3: Run the check**

Run: `arch-check --json`
Expected: `"checked":2` (or however many checks the record declares),
`"violated":0`, `"broken":0`.

- [ ] **Step 4: Commit**

```bash
git add decisions/0018-core-module-boundaries.md decisions/README.md
git commit -m "docs(decisions): record core module boundaries as ADR 0018"
```

---

## Self-Review

**Spec coverage.** A = one go: Tasks 1–4 are one branch, one PR, committed
per module for bisectability. B = the proposed cut: Tasks 1–4 produce exactly
`Ctx`/`Resolve`/`Axiom`/`Flatten_solve` with `run_fold*` left in `Eval` as
agreed. C = `.mli`: Task 5. The ADR (Task 6) was not requested but closes the
"17 records, zero checks" gap this review surfaced; it is separable and can be
dropped without affecting Tasks 1–5.

**Not covered, deliberately.** `fold_run.ml` as a sixth module (flagged, left
out of scope). The `Mark`/`Fold`/`Apply`/`Export` arms of `eval_stmt`
(103/96/90/66 lines) stay where they are. The pre-existing `.mli`-less modules
(`geom`, `num`, `collapse`, `fold_emit`, …) are untouched.

**Risk.** Task 4 is the dangerous one: 638 lines carrying three known-red
cases. Its verification must compare the failure *list*, not the count.
