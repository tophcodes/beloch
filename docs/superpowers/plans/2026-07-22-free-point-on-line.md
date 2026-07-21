# Free point on a line — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `free on --l from .x at 2/5` point construction that lands a concrete exact rational point at parameter `t ∈ [0,1]` along a line's material bundle, tagged in FOLD output as `beloch:free`.

**Architecture:** The change lives almost entirely in the OCaml reference evaluator (`packages/core/lib`), which parses with Menhir (`parser.mly`) + sedlex (`lexer.ml`) — **not** the tree-sitter `grammar.js` (that is highlighting-only). A new `PsFree` AST variant flows through a new `eval.ml` arm that computes the bundle endpoints (`extreme_pair` over the line's material chords), places the point `P0 + t·(P1−P0)`, and records metadata for a new `beloch:free` FOLD field.

**Tech Stack:** OCaml, Menhir, sedlex, zarith (`Q.t` rationals), dune. Tests are inline-assertion `.bel` files under `packages/core/tests/cases/` run by `test_bel_assert.ml`.

## Global Constraints

- **Exact kernel untouched.** `free` is a *provenance tag*, not a kernel relaxation. The placed point is an ordinary exact `Num.t` point; no incidence/meet/axiom logic changes. (Spec §6 stays true.)
- **1-DOF, on-line only.** No region/2-DOF points. No sliders (that is issue #70). No symbolic-in-`t`.
- **Domain = one bundle.** The bundle is the pair of **furthest-out points** (`Geom.extreme_pair`) over the line's deduped material chords within the paper — in-between gaps bridged. Anchor `.x` must equal one of the two extreme points; it sets `t = 0`.
- **All paths under** `/home/toph/Projects/beloch/packages/core/`. Ignore any `.claude/worktrees/*` copies (stale).
- **Branch:** `feat/free-point-on-line` (already checked out). Run `git branch --show-current` before each commit.
- **Build/test:** `dune build` (regenerates the Menhir parser automatically), `dune runtest` (runs the `.bel` assertion suite). Menhir conflicts land in `_build/default/packages/core/lib/parser.conflicts`.

---

## File Structure

- `packages/core/lib/lexer.ml` — add keywords `free`/`on`/`from` and a `NUMBER` rational-literal token.
- `packages/core/lib/parser.mly` — declare new tokens; add the `free … from … at …` production.
- `packages/core/lib/ast.ml` — new `point_expr` variant `PsFree`.
- `packages/core/lib/geom.ml` — a small `material_bundle` helper (dedupe + `extreme_pair`).
- `packages/core/lib/eval.ml` — new eval arm; carry a `free_info` record into `Eval.folded`.
- `packages/core/lib/fold_emit.ml` — emit `beloch:free` custom property.
- `packages/core/tests/cases/construct/free-on-line*.bel` — assertion tests (auto-discovered).
- `spec/SPECIFICATION.md` — §3, new §4 subsection, §7, version bump.
- `packages/grammar/grammar.js` — *(optional)* keyword coloring for `free`/`on`/`from`.

---

## Task 1: Surface syntax + minimal eval (constructed line, default midpoint)

Vertical slice: parse `.p = free on --l from .x` and evaluate it for a **constructed (unmarked) line**, whose material is the whole paper square. Default `t = 1/2`. This proves the whole pipeline end-to-end with the simplest geometry.

**Files:**
- Modify: `packages/core/lib/lexer.ml` (keyword + NUMBER token)
- Modify: `packages/core/lib/parser.mly` (tokens + production)
- Modify: `packages/core/lib/ast.ml` (`point_expr` variant)
- Modify: `packages/core/lib/eval.ml` (new arm at the `Ast.Point` dispatch, ~line 1749)
- Test: `packages/core/tests/cases/construct/free-on-line.bel`

**Interfaces:**
- Produces AST: `PsFree of { line : line_operand; anchor : point_operand; t : Num.t option; span : Error.span }` in `ast.ml`.
- Consumes existing eval helpers (confirm exact signatures at cited lines before use):
  - `resolve_paper_line : ctx -> line_operand -> Geom.line * (Geom.point * Geom.point) list option` (`eval.ml:487-500`)
  - `resolve_point : ctx -> point_operand -> Geom.point` (`eval.ml:473-476`)
  - `bind_point : ctx -> string -> Error.span -> Geom.point -> unit` (`eval.ml:175-183`)
  - `Geom.clip_to_unit_square : Geom.line -> (Geom.point * Geom.point) option` (`geom.ml:180-199`)
  - `Error.fail : Error.span -> string -> 'a` (`error.ml:5-7`)
  - `Num.of_q`, `Num.add`, `Num.sub`, `Num.mul`, `Num.equal`, `Num.one` (`num.ml`)

- [ ] **Step 1: Write the failing test**

Create `packages/core/tests/cases/construct/free-on-line.bel`:

```
paper square
--diag = through .a .c
.m = free on --diag from .a
; assert .m = (1/2, 1/2)
; assert .m incident --diag
```

- [ ] **Step 2: Run it and confirm it fails to parse**

Run: `dune runtest 2>&1 | grep -A3 free-on-line`
Expected: a parse/lex error (the keyword `free` is unknown) — the case fails. This confirms the syntax does not exist yet.

- [ ] **Step 3: Add lexer keywords and the NUMBER token**

In `packages/core/lib/lexer.ml`, alongside the existing keyword arms (~lines 13-37), add rules mapping the identifiers to new tokens:

```ocaml
| "free" -> FREE
| "on"   -> ON
| "from" -> FROM
```

Add a rational-literal rule near the identifier rules (top of the token function, with the sedlex regexps at lines 6-7). zarith's `Q.of_string` parses both `"2/5"` and `"3"`:

```ocaml
let number = [%sedlex.regexp? Plus '0'..'9', Opt ('/', Plus '0'..'9')]
(* ... in the token match: *)
| number -> NUMBER (Q.of_string (Sedlexing.Utf8.lexeme lexbuf))
```

Confirm `Q` is in scope in `lexer.ml` (it is used throughout `num.ml`; add `module Q = ...` or open if needed — check how `num.ml` references it).

- [ ] **Step 4: Declare tokens and add the production in the parser**

In `packages/core/lib/parser.mly`, add to the `%token` block (lines 44-51):

```
%token FREE ON FROM
%token <Q.t> NUMBER
```

Add a new alternative to `point_expr` (currently `parser.mly:171-173`) plus an optional-t helper rule:

```
point_expr:
  | ... existing alternatives ...
  | FREE ON line_operand FROM point_operand at_frac_opt
      { PsFree { line = $3; anchor = $5; t = $6; span = $loc } }

at_frac_opt:
  |            { None }
  | AT NUMBER  { Some (Num.of_q $2) }
```

- [ ] **Step 5: Build and check for parser conflicts**

Run: `dune build 2>&1 | tail -20`
Then: `cat _build/default/packages/core/lib/parser.conflicts 2>/dev/null || echo "no conflicts"`
Expected: builds clean, "no conflicts". If `AT` produces a conflict (it is also used in `extent_opt` as `AT point_operand`, `parser.mly:141`), the contexts differ (fold/mark extent vs. free-point tail) so LR(1) should separate them; if a real conflict appears, replace the `AT` in `at_frac_opt` with a dedicated keyword token (e.g. `ATFRAC` lexed from a distinct word) and note it. Do not proceed until the build is clean.

- [ ] **Step 6: Add the AST variant**

In `packages/core/lib/ast.ml`, extend `point_expr` (currently `ast.ml:97-98`, one variant `PsExpr of point_operand`):

```ocaml
type point_expr =
  | PsExpr of point_operand
  | PsFree of {
      line : line_operand;
      anchor : point_operand;
      t : Num.t option;
      span : Error.span;
    }
```

- [ ] **Step 7: Build to confirm a non-exhaustive-match error surfaces the eval site**

Run: `dune build 2>&1 | grep -i "not matched\|PsFree" | head`
Expected: a warning/error pointing at the `Ast.Point` match in `eval.ml` (~line 1749). This is the spot to extend.

- [ ] **Step 8: Implement the minimal eval arm (constructed line, default midpoint)**

In `packages/core/lib/eval.ml`, at the `Ast.Point` dispatch (~line 1749), add a `PsFree` arm. For Task 1, handle only the unmarked-line case (`resolve_paper_line` returns `None` chords → clip to the paper square):

```ocaml
| Ast.Point (n, Ast.PsFree { line; anchor; t; span }, _) ->
    let (l, chords_opt) = resolve_paper_line ctx line in
    let (p0raw, p1raw) =
      match chords_opt with
      | None ->
          (match Geom.clip_to_unit_square l with
           | Some (a, b) -> (a, b)
           | None -> Error.fail span "the line does not cross the paper")
      | Some _ -> Error.fail span "free on a material line: not yet implemented"
          (* Task 3 replaces this branch *)
    in
    let ax = resolve_point ctx anchor in
    (* orient: t=0 at the anchor endpoint *)
    let (e0, e1) =
      if Geom.point_equal ax p0raw then (p0raw, p1raw)
      else if Geom.point_equal ax p1raw then (p1raw, p0raw)
      else Error.fail span "the anchor is not an endpoint of the line's material"
    in
    let tv = match t with Some v -> v | None -> Num.of_q (Q.of_string "1/2") in
    let px = Num.add e0.Geom.x (Num.mul tv (Num.sub e1.Geom.x e0.Geom.x)) in
    let py = Num.add e0.Geom.y (Num.mul tv (Num.sub e1.Geom.y e0.Geom.y)) in
    bind_point ctx n span { Geom.x = px; y = py }
```

Confirm `Geom.point_equal` exists; if not, compare fields with `Num.equal a.x b.x && Num.equal a.y b.y` inline (define a small local `point_equal`). Confirm the exact `resolve_paper_line` / `bind_point` signatures at their cited lines and adjust argument order to match.

- [ ] **Step 9: Run the test and confirm it passes**

Run: `dune runtest 2>&1 | grep -A3 free-on-line || echo "no failures reported"`
Expected: no failure for `free-on-line.bel`; `.m = (1/2,1/2)` and incidence hold.

- [ ] **Step 10: Commit**

```bash
git branch --show-current   # must be feat/free-point-on-line
git add packages/core/lib/lexer.ml packages/core/lib/parser.mly packages/core/lib/ast.ml packages/core/lib/eval.ml packages/core/tests/cases/construct/free-on-line.bel
git commit -m "feat(core): free point on a constructed line (default midpoint)"
```

---

## Task 2: Explicit `at <t>` parameter + range validation + orientation

Add the explicit rational parameter, validate `t ∈ [0,1]`, and prove orientation flips when the anchor is the other endpoint.

**Files:**
- Modify: `packages/core/lib/eval.ml` (the `PsFree` arm from Task 1)
- Test: `packages/core/tests/cases/construct/free-on-line-at.bel`, `free-on-line-range.bel`

**Interfaces:**
- Consumes `Num.sign : Num.t -> int` (`num.ml:216`), `Num.compare` (`num.ml:330`), `Num.one` (`num.ml:19`).

- [ ] **Step 1: Write the failing tests**

Create `packages/core/tests/cases/construct/free-on-line-at.bel`:

```
paper square
--diag = through .a .c
.q = free on --diag from .a at 1/4
.r = free on --diag from .c at 1/4
; assert .q = (1/4, 1/4)
; assert .r = (3/4, 3/4)
```

Create `packages/core/tests/cases/construct/free-on-line-range.bel`:

```
paper square
--diag = through .a .c
.bad = free on --diag from .a at 2/1
; expect error "out of range"
```

- [ ] **Step 2: Run and confirm failure**

Run: `dune runtest 2>&1 | grep -E "free-on-line-(at|range)"`
Expected: `free-on-line-range.bel` fails (no range check yet — it places a point instead of erroring). `free-on-line-at.bel` may already pass from Task 1 if `at` parsing works; confirm both are exercised.

- [ ] **Step 3: Add the range check to the eval arm**

In the `PsFree` arm (`eval.ml`), immediately after computing `tv`:

```ocaml
    let tv = match t with Some v -> v | None -> Num.of_q (Q.of_string "1/2") in
    if Num.sign tv < 0 || Num.compare tv Num.one > 0 then
      Error.fail span "t is out of range (must be between 0 and 1)";
```

- [ ] **Step 4: Run tests to confirm they pass**

Run: `dune runtest 2>&1 | grep -E "free-on-line-(at|range)" || echo "no failures"`
Expected: no failures — `.q`/`.r` correct (orientation flip works), and the `at 2/1` case raises an error containing "out of range".

- [ ] **Step 5: Commit**

```bash
git branch --show-current
git add packages/core/lib/eval.ml packages/core/tests/cases/construct/free-on-line-at.bel packages/core/tests/cases/construct/free-on-line-range.bel
git commit -m "feat(core): explicit at <t> for free points + range validation"
```

---

## Task 3: Material-line domain (bundle from folded/marked chords)

Generalize the domain from "constructed line ∩ square" to a real material line: dedupe its chords and take the furthest-out points (`extreme_pair`). Replace the Task 1 stub for the `Some chords` branch. Add the line-misses-material error.

**Files:**
- Modify: `packages/core/lib/geom.ml` (add `material_bundle` helper)
- Modify: `packages/core/lib/eval.ml` (`PsFree` arm — replace the stub branch)
- Test: `packages/core/tests/cases/construct/free-on-marked.bel`, `free-on-line-miss.bel`

**Interfaces:**
- Produces `Geom.material_bundle : (Geom.point * Geom.point) list -> (Geom.point * Geom.point) option` — dedupes endpoints and returns the two furthest-apart points; `None` if the input is empty.
- Consumes `Geom.extreme_pair : Geom.point list -> (Geom.point * Geom.point) option` (`geom.ml:160-178`).

- [ ] **Step 1: Write the failing tests**

Create `packages/core/tests/cases/construct/free-on-marked.bel` (a crease that is actually marked, so it carries material chords). Use an existing marked-crease pattern from the repo — confirm the exact `mark` syntax against a neighbouring case in `tests/cases/`:

```
paper square
mark --m = through .a .c
.mid = free on --m from .a
; assert .mid = (1/2, 1/2)
; assert .mid incident --m
```

Create `packages/core/tests/cases/construct/free-on-line-miss.bel` — a line whose material does not cross the paper. If a purely-off-paper line is hard to construct, assert the error via a line with no material chords; confirm the trigger against `resolve_paper_line`'s behaviour:

```
paper square
--edge = through .a .b
mark --m = through .c .d
.p = free on --m from .a
; expect error "not an endpoint"
```

*(The `.a` anchor is not on `--m`'s material `c–d`, so this exercises the bad-anchor path; keep it here as the negative case and add a dedicated line-miss case only if an off-paper material line is constructible in v0.0.)*

- [ ] **Step 2: Run and confirm failure**

Run: `dune runtest 2>&1 | grep -E "free-on-marked|free-on-line-miss"`
Expected: `free-on-marked.bel` hits the Task 1 stub error ("not yet implemented"); confirm.

- [ ] **Step 3: Add the `material_bundle` helper**

In `packages/core/lib/geom.ml`, near `extreme_pair` (`geom.ml:160-178`):

```ocaml
(* The furthest-out endpoint pair over a set of (possibly disjoint, possibly
   duplicated) collinear chords — the material "bundle" of a line. In-between
   gaps are bridged; [None] iff there are no chords. *)
let material_bundle (chords : (point * point) list) : (point * point) option =
  let pts = List.concat_map (fun (a, b) -> [a; b]) chords in
  extreme_pair pts
```

- [ ] **Step 4: Replace the stub branch in the eval arm**

In `eval.ml`, replace the `| Some _ -> Error.fail …` stub from Task 1:

```ocaml
      | Some chords ->
          (match Geom.material_bundle chords with
           | Some (a, b) -> (a, b)
           | None -> Error.fail span "the line has no material on the paper")
```

The rest of the arm (anchor orientation, `t` placement, range check) is unchanged and now serves both branches.

- [ ] **Step 5: Run tests to confirm they pass**

Run: `dune runtest 2>&1 | grep -E "free-on-marked|free-on-line-miss" || echo "no failures"`
Expected: `free-on-marked.bel` places `.mid` at the diagonal midpoint on the marked crease; the bad-anchor case raises "not an endpoint". Also re-run the full suite:
Run: `dune runtest 2>&1 | tail -5` — expected: no new failures beyond the known pre-existing reds noted in project memory (derive-5, collapse cases).

- [ ] **Step 6: Commit**

```bash
git branch --show-current
git add packages/core/lib/geom.ml packages/core/lib/eval.ml packages/core/tests/cases/construct/free-on-marked.bel packages/core/tests/cases/construct/free-on-line-miss.bel
git commit -m "feat(core): free point domain from a line's material bundle"
```

---

## Task 4: `beloch:free` FOLD emission

Record the placement metadata during eval and serialize it as a `beloch:free` custom property in the crease-pattern frame. No renderer consumes it (issue #70); emission is the only obligation.

**Files:**
- Modify: `packages/core/lib/eval.ml` (`Eval.folded` record + populate in the `PsFree` arm)
- Modify: `packages/core/lib/fold_emit.ml` (serialize `beloch:free`)
- Test: verification via CLI + `jq` (the `.bel` assertion harness does not inspect raw JSON)

**Interfaces:**
- Produces on `Eval.folded` (defined ~`eval.ml:37-49`): a new field `free_points : (string * free_info) list` where
  ```ocaml
  type free_info = {
    fi_t : Num.t;
    fi_p0 : Geom.point;   (* t = 0 endpoint (anchor) *)
    fi_p1 : Geom.point;   (* t = 1 endpoint *)
    fi_source_line : int;
  }
  ```
- Consumes `q_to_json` and the named-points emit block (`fold_emit.ml:362-374`, `fold_emit.ml:390-405`).

- [ ] **Step 1: Add the `free_info` type and record field**

In `eval.ml`, define `free_info` (above the `folded` type) and add `free_points : (string * free_info) list` to the `folded` record (~`eval.ml:37-49`). Initialize it empty where `folded` is constructed (~`eval.ml:2584`) and thread accumulation the same way `named_points` is collected (find how `named_points` is gathered and mirror it — a `ref` list or fold accumulator in the statement loop).

- [ ] **Step 2: Populate it in the `PsFree` arm**

In the `PsFree` arm (`eval.ml`), after computing `e0`, `e1`, `tv`, and before/after `bind_point`, record the info (using the same accumulator `named_points` uses):

```ocaml
    record_free_point n {
      fi_t = tv; fi_p0 = e0; fi_p1 = e1;
      fi_source_line = (fst span).Error.line;   (* confirm span/line accessor *)
    };
```

Confirm the source-line accessor against `Error.span`'s definition; mirror how `beloch:source_line` / `nsource_line` is derived elsewhere in `fold_emit.ml`.

- [ ] **Step 3: Write the emission**

In `fold_emit.ml`, in the crease-pattern frame `Assoc` (~`fold_emit.ml:390-405`, next to `beloch:named_points`), add a `beloch:free` entry: a JSON object keyed by point name, each value `{ "t": <q>, "endpoints": [[x0,y0],[x1,y1]], "source_line": n }`, using `q_to_json` for the `Num.t` scalars:

```ocaml
("beloch:free",
  `Assoc (List.map (fun (name, fi) ->
     (name, `Assoc [
        ("t", q_to_json fi.fi_t);
        ("endpoints", `List [
           `List [q_to_json fi.fi_p0.Geom.x; q_to_json fi.fi_p0.Geom.y];
           `List [q_to_json fi.fi_p1.Geom.x; q_to_json fi.fi_p1.Geom.y]]);
        ("source_line", `Int fi.fi_source_line);
      ]))
     folded.free_points));
```

Confirm the JSON library constructors (`` `Assoc ``/`` `List ``/`` `Int ``) match those already used in `fold_emit.ml`.

- [ ] **Step 4: Verify emission via CLI**

Run:
```bash
dune exec packages/core/bin/main.exe -- fold packages/core/tests/cases/construct/free-on-line.bel \
  | jq '.. | objects | ."beloch:free"? // empty'
```
Expected: an object like `{ "m": { "t": "1/2", "endpoints": [[0,0],[1,1]], "source_line": 3 } }` (exact frame path/keys depend on `fold_emit`; adjust the `jq` filter to the frame that carries `beloch:*`). Confirm the object is well-formed and the endpoints match `.a`→`.c`.

- [ ] **Step 5: Build clean and run the full suite**

Run: `dune build 2>&1 | tail -3 && dune runtest 2>&1 | tail -5`
Expected: clean build; no new `.bel` failures.

- [ ] **Step 6: Commit**

```bash
git branch --show-current
git add packages/core/lib/eval.ml packages/core/lib/fold_emit.ml
git commit -m "feat(core): emit beloch:free FOLD metadata for free points"
```

---

## Task 5: Specification updates

Document the construction in the language spec.

**Files:**
- Modify: `spec/SPECIFICATION.md` (§3, new §4 subsection, §7, version header)

- [ ] **Step 1: Read the current version header and §3/§4/§7 anchors**

Run: `rg -n "since v0\.|^## 3|^## 4|^### 4|^## 7|beloch:marks|beloch:named" spec/SPECIFICATION.md | head -40`
Note the current highest `-dev` version to pick the next one.

- [ ] **Step 2: Add the §3 note**

In §3 (Values, ~`spec/SPECIFICATION.md:157`), add a sentence: a point may also be a **free point on a line** — 1-DOF, position-not-load-bearing, but still an exact value (cross-ref the new §4 subsection and §6).

- [ ] **Step 3: Add the new §4 subsection**

Add a subsection near the meet operator (§4.3) or after the axioms, titled e.g. `### 4.x Free point on a line — `free on … from … at …` *(since v0.NN-dev)*`. Cover, in prose matching the surrounding style:
- Syntax `.p = free on --l from .x at <rational>` (`at` optional, defaults `1/2`).
- Domain: the furthest-out points of `--l`'s material chords in the current paper (bridged); `t ∈ [0,1]`, `t=0` at the anchor endpoint, `t=1` at the opposite end.
- `free` is provenance, not a kernel relaxation — the result is an ordinary exact point usable anywhere a point operand is (cross-ref §6).
- Errors: line has no material on the paper; anchor is not an endpoint of the material; `t` out of `[0,1]`.
- Forward note: symbolic-in-`t` and interactive sliders (issue #70) are out of scope.

- [ ] **Step 4: Add the §7 emission note**

In §7 (output / custom properties), document `beloch:free` as a custom property carrying `{ t, endpoints, source_line }` per free point, alongside the existing `beloch:*` list.

- [ ] **Step 5: Bump the version header**

Add a `**v0.NN-dev** (free point on a line — 1-DOF reference point along a line's material bundle; `beloch:free` emission)` entry to the version list at the top of §4 (mirror the existing dated entries).

- [ ] **Step 6: Commit**

```bash
git branch --show-current
git add spec/SPECIFICATION.md
git commit -m "docs(spec): free point on a line construction"
```

---

## Task 6 (optional): Editor highlighting

Color the new keywords in the tree-sitter grammar. Editor-only; does not affect evaluation. Skip if tree-sitter CLI is unavailable.

**Files:**
- Modify: `packages/grammar/grammar.js` (keyword list, `grammar.js:38-44`)
- Regenerate: `packages/grammar/src/*`, `tree-sitter-beloch.wasm`

- [ ] **Step 1: Add keywords**

Add `free`, `on`, `from` to the `keyword` list at `grammar.js:38-44`.

- [ ] **Step 2: Regenerate**

Run (from `packages/grammar/`): `tree-sitter generate && tree-sitter build --wasm`
Expected: `src/parser.c`, `src/grammar.json`, `src/node-types.json`, `tree-sitter-beloch.wasm` updated.

- [ ] **Step 3: Commit**

```bash
git branch --show-current
git add packages/grammar/grammar.js packages/grammar/src packages/grammar/tree-sitter-beloch.wasm
git commit -m "chore(grammar): highlight free/on/from keywords"
```

---

## Self-Review notes

- **Spec coverage:** domain (Task 3), orientation via anchor (Task 1), default+explicit `t` (Tasks 1–2), range/anchor/no-material errors (Tasks 2–3), `beloch:free` emission (Task 4), exact-kernel stance (no kernel change anywhere), non-goals (sliders → #70; symbolic-`t` → noted in Task 5). Covered.
- **Known unknowns to confirm during execution (do not guess — read the cited line first):** exact signatures of `resolve_paper_line`, `bind_point`, `clip_to_unit_square`; existence of `Geom.point_equal`; the `named_points` accumulation mechanism in `eval.ml`; `Error.span` line accessor; the JSON constructors in `fold_emit.ml`; the `AT` overload conflict outcome (Task 1 Step 5); the marked-crease `mark` syntax for the Task 3 test.
- **Pre-existing reds** (per project memory: derive-5, collapse cases 3/4/5) are unrelated — do not chase them.
