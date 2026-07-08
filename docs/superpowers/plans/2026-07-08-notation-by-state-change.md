# Notation-by-state-change Implementation Plan

> **STATUS (2026-07-08):** Tasks 1–5 (additive read operators `* & \ #[] []` +
> bundle binding) are **implemented and committed**. Tasks 6–8 (migration + old-
> syntax removal) are **superseded** — executing Task 6 surfaced that ~72
> `--(.a .b)` operand uses are *reads* (references to existing lines, mostly
> edges), which the spec now handles with a `--[.a .b]` **join selector**, prelude
> edge names, instance-access removal, and per-example **sight-line rework** (see
> the revised design doc's *Join*, *Migration*, and *Status* sections). A fresh
> plan for that slice is needed; the Task 6–8 steps below are stale.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Beloch's selector/construction notation so reads are symbols
(`* & \ #[] []`) and writes are keyword verbs, per the state-change law in
`docs/superpowers/specs/2026-07-08-notation-by-state-change-design.md`.

**Architecture:** Churn the sedlex lexer, menhir grammar, AST, and evaluator
together. Strategy is **additive-then-cutover**: first add the new tokens and
grammar rules *alongside* the old ones (build stays green, old `.bel` still
parses), prove the new forms with unit tests, migrate every example + golden in
one task, then delete the old tokens/rules in one task. Only two tasks (migrate,
remove) are breaking; everything before them keeps `dune runtest` green.

**Tech Stack:** OCaml, sedlex (`lib/lexer.ml`), menhir (`lib/parser.mly`),
alcotest (`tests/`), `tools/regen.ml` (golden regeneration), zarith/FLINT number
kernel (unchanged).

## Global Constraints

- **Exact arithmetic only** — no floats introduced anywhere (ADR 0008/0012).
- **Pre-1.0 hard cutover** — no deprecated aliases; old syntax is removed, not
  kept alongside, once migration lands.
- **Reads are operators, writes are keywords** — do not add any keyword for a
  pure read (meet, filter, diff, union) or any operator for a write.
- **Meet produces a point; filter/diff/union produce line bundles.** Meet never
  enters `line_operand`; filter/union never enter `point_operand`.
- **Granularity of `#[…]` stays context-typed** — reuse `face_of_points` /
  `resolve_flap_cluster` exactly as `#(…)` does today; no `face[]`/`flap[]` split.
- Run the whole suite with `dune runtest` from the repo root. Regenerate goldens
  with `dune exec tools/regen.exe` (never hand-edit `.fold` files).
- Every task is its own commit(s). Conventional-commit messages (personal repo).

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `lib/lexer.ml` | tokens | add `&` `\` `*` `[` `#[`; later remove `at` `cross` `--(` `.(` `#(` |
| `lib/parser.mly` | grammar + AST-build | add meet/filter/diff/union productions; later remove `at`/`.()`/`--(`/`#(` |
| `lib/ast.ml` | AST types | add `LFilter`/`LUnion`/`filter_elt`; later remove `LThrough`/`LAt` |
| `lib/eval.ml` | resolution | generalize `at_matches` → `bundle_segments`; update printers; wire meet/filter/union/bind |
| `examples/**/*.bel` | corpus | migrate to new syntax (Task 6) |
| `tests/golden/**/*.fold` | golden outputs | regenerate (Task 6) |
| `tests/test_parse.ml`, `tests/test_eval.ml` | unit tests | add per-construct tests |
| `spec/SPECIFICATION.md` | language spec | sync §4.8 (selectors), point/line operands (Task 8) |

## Notes for the implementer (read once)

- **Meet grammar, conflict-free.** Meet yields a *point*. Two spots:
  - statement RHS `point_expr` — unambiguous after `POINT EQ`, so
    `line_operand STAR line_operand` needs no parens.
  - inline `point_operand` — a bare leading `crease_ref` there would be
    ambiguous with `line_operand` in `arg`/`flap_arg` slots, so the inline form
    is **parenthesized**: `LPAREN line_operand STAR line_operand RPAREN`. This is
    exactly what freeing `()` (retiring `.(`/`--(`) buys us.
- **Filter/diff/union grammar.** Left-recursive on `line_operand`:
  `line_operand AMP selector` / `line_operand BACKSLASH selector` /
  `LBRACKET line_list RBRACKET`. `&`/`\` bind tighter than `*` *for free* — in
  `point_expr`, the first `line_operand` greedily absorbs its filters before the
  `STAR` is seen. No `%left`/`%prec` needed; confirm with `--dump`.
- **`--[` and `.[` are taken** (instance-member open, `LINE_MEMBER_OPEN` /
  `POINT_MEMBER_OPEN`). Union uses a **bare `[`** (new `LBRACKET`), closed by the
  existing `]` (`RBRACKET`). `#[` is a new maximal-munch opener; there is no bare
  `#`, so `#[` vs `[` never collide.
- **The filter engine already exists.** `at_matches` (`lib/eval.ml:351-381`) does
  incidence filtering; you will generalize it to a recursive `bundle_segments`
  that also handles `Drop` and `LUnion`. Keep the `incident`/`point_on_seg`
  helpers verbatim.

---

## Task 1: Add the new tokens (additive, no rules yet)

**Files:**
- Modify: `lib/lexer.ml:37-49` (token table)
- Modify: `lib/parser.mly:14-17` (`%token` decls)
- Test: `tests/test_parse.ml`

**Interfaces:**
- Produces: tokens `AMP`, `BACKSLASH`, `STAR`, `LBRACKET`, and `FLAP_BRACKET`
  (the `#[` opener). No grammar uses them yet.

- [ ] **Step 1: Add the lexer rules.** In `lib/lexer.ml`, add these arms
  (order matters: `#[` before any single-char rule; keep existing arms):

```ocaml
  | '&' -> AMP
  | '\\' -> BACKSLASH
  | '*' -> STAR
  | '[' -> LBRACKET
  | "#[" -> FLAP_BRACKET
```

  (Place `"#["` next to the other multi-char openers at lines 44-48; place the
  single-char arms next to `'(' -> LPAREN`.)

- [ ] **Step 2: Declare the tokens.** In `lib/parser.mly:15`, extend the second
  `%token` line:

```
%token DEF APPLY EXPORT STEP AS BANG LBRACE RBRACE LPAREN RBRACKET AMP BACKSLASH STAR LBRACKET FLAP_BRACKET
```

- [ ] **Step 3: Build to verify tokens compile.** Menhir will warn that the new
  tokens are unused — that is expected at this step.

Run: `dune build 2>&1 | head -20`
Expected: builds; warnings like `Warning: the token AMP is unreachable`.

- [ ] **Step 4: Commit.**

```bash
git add lib/lexer.ml lib/parser.mly
git commit -m "feat(lexer): add & \\ * [ #[ tokens (unused; grammar follows)"
```

---

## Task 2: Meet operator `*` (additive alongside `.()`/`cross`)

**Files:**
- Modify: `lib/parser.mly:137-143` (`point_expr`, `point_operand`)
- Test: `tests/test_parse.ml`

**Interfaces:**
- Consumes: `STAR` (Task 1), existing `Cross`/`PCross` AST (`lib/ast.ml:21,77`).
- Produces: `.o = --x * --y` parses to `Point (_, Cross (LNamed, LNamed), _)`;
  `(--x * --y)` as a point operand parses to `PCross (…)`. Old `.()`/`cross`
  still parse (removed in Task 7).

- [ ] **Step 1: Write the failing tests.** Add to `tests/test_parse.ml`:

```ocaml
let test_parse_meet_stmt () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d1 = through .a .b\n--d2 = through .c .d\n.o = --d1 * --d2\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.Cross (Ast.LNamed a, Ast.LNamed b), _) :: _ ->
      Alcotest.(check string) "lhs" "d1" a.Ast.cname;
      Alcotest.(check string) "rhs" "d2" b.Ast.cname
  | _ -> Alcotest.fail "expected .o = Cross(d1, d2)"

let test_parse_meet_inline () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d1 = through .a .b\n--d2 = through .c .d\n\
       map (--d1 * --d2) onto .e\n"
  in
  match List.rev prog with
  | Ast.Crease (None, Ast.MapPoints (Ast.PCross _, Ast.PNamed _), _, _) :: _ -> ()
  | _ -> Alcotest.fail "expected map (PCross) onto .e"
```

  Register both in the parse test list at the bottom of the file (follow the
  existing `("parse …", `Quick, test_…)` pattern).

- [ ] **Step 2: Run to verify they fail.**

Run: `dune runtest 2>&1 | grep -A3 meet`
Expected: FAIL (syntax error — `*` has no rule yet).

- [ ] **Step 3: Add the grammar.** In `lib/parser.mly`, add to `point_expr`
  (after line 139):

```
  | line_operand STAR line_operand                { Cross ($1, $3) }
```

  and to `point_operand` (after line 143):

```
  | LPAREN line_operand STAR line_operand RPAREN  { PCross ($2, $4, $loc) }
```

- [ ] **Step 4: Check for grammar conflicts.**

Run: `menhir --explain lib/parser.mly 2>&1 | grep -i conflict || echo "no conflicts"`
Expected: `no conflicts`. If a conflict appears in `arg`/`flap_arg`, it means the
inline meet was added without the `LPAREN … RPAREN` guard — re-check Step 3.

- [ ] **Step 5: Run the tests.**

Run: `dune runtest 2>&1 | grep -A3 meet`
Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add lib/parser.mly tests/test_parse.ml
git commit -m "feat(parse): meet operator * (point = line * line), additive"
```

---

## Task 3: Flap bracket `#[…]` (additive alongside `#(…)`)

**Files:**
- Modify: `lib/parser.mly:162-163` (`flap_operand`)
- Test: `tests/test_parse.ml`

**Interfaces:**
- Consumes: `FLAP_BRACKET` (Task 1), `RBRACKET`, existing `FByPoints`.
- Produces: `#[.a .b]` parses to the same `FByPoints` node as `#(.a .b)`.

- [ ] **Step 1: Write the failing test.**

```ocaml
let test_parse_flap_bracket () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmap .p onto .q moving #[.a .b]\n"
  in
  match prog with
  | [ Ast.Crease (None, _, Some { moving = Some (Ast.FlapSpec
        (Ast.FByPoints (pts, _))); _ }, _) ] ->
      Alcotest.(check int) "two constraint points" 2 (List.length pts)
  | _ -> Alcotest.fail "expected moving #[.a .b]"
```

  Register it in the test list.

- [ ] **Step 2: Run to verify it fails.**

Run: `dune runtest 2>&1 | grep -A3 flap_bracket`
Expected: FAIL (syntax error at `#[`).

- [ ] **Step 3: Add the grammar.** In `lib/parser.mly`, extend `flap_operand`:

```
flap_operand:
  | FLAP_OPEN point_operand_list RPAREN     { FByPoints ($2, $loc) }
  | FLAP_BRACKET point_operand_list RBRACKET { FByPoints ($2, $loc) }
```

- [ ] **Step 4: Run the test.**

Run: `dune runtest 2>&1 | grep -A3 flap_bracket`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/parser.mly tests/test_parse.ml
git commit -m "feat(parse): #[…] flap bracket (additive alongside #())"
```

---

## Task 4: Filter `&`, diff `\`, union `[…]` — AST + grammar + eval

This is the core task. It adds `line_operand` forms and generalizes the filter
engine. Old `at` still works.

**Files:**
- Modify: `lib/ast.ml:24-35` (`line_operand`, new `filter_elt`)
- Modify: `lib/parser.mly:149-160` (`line_operand`, `line_list`, `selector`)
- Modify: `lib/eval.ml:136-157` (printers), `:293-381` (`at_matches` →
  `bundle_segments`, `resolve_line`, `resolve_paper_line`)
- Test: `tests/test_parse.ml`, `tests/test_eval.ml`

**Interfaces:**
- Consumes: `AMP`, `BACKSLASH`, `LBRACKET`, `RBRACKET`, `selector`.
- Produces:
  - AST `LFilter of line_operand * filter_elt * Error.span` and
    `LUnion of line_operand list * Error.span`; `filter_elt = Keep of selector |
    Drop of selector`.
  - eval `bundle_segments : Ast.line_operand -> int option *
    Fold_state.crease_segment list` (segments of any bundle expression).
  - `--l & .p` resolves (at a singleton slot) to the one incident segment's line,
    same coercion errors as `at` today.

- [ ] **Step 1: Add the AST.** In `lib/ast.ml`, extend `line_operand` (keep
  `LThrough`/`LAt` for now — removed in Task 7) and add `filter_elt`:

```ocaml
and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span
  | LMember of string * string * Error.span
  | LAt of crease_ref * selector list * Error.span
  | LFilter of line_operand * filter_elt * Error.span
    (* bundle & sel  (Keep) | bundle \ sel  (Drop): segments of the bundle
       incident / not incident to sel *)
  | LUnion of line_operand list * Error.span
    (* [a b …]: union of same-typed crease bundles *)

and filter_elt = Keep of selector | Drop of selector
```

- [ ] **Step 2: Write the failing parse tests.**

```ocaml
let test_parse_filter_chain () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .b\nmap .p onto .q up to --l & .c & --m\n"
  in
  match prog with
  | [ _; Ast.Crease (None, _, Some { up_to = Some (Ast.FlapLine
        (Ast.LFilter (Ast.LFilter (Ast.LNamed _, Ast.Keep _, _),
                      Ast.Keep _, _))); _ }, _) ] -> ()
  | _ -> Alcotest.fail "expected up to --l & .c & --m (nested LFilter, Keep)"

let test_parse_diff () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .b\nmap .p onto .q up to --l \\ .c\n"
  in
  match prog with
  | [ _; Ast.Crease (None, _, Some { up_to = Some (Ast.FlapLine
        (Ast.LFilter (Ast.LNamed _, Ast.Drop _, _))); _ }, _) ] -> ()
  | _ -> Alcotest.fail "expected up to --l \\ .c (LFilter Drop)"

let test_parse_union () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--x = through .a .b\n--y = through .c .d\n\
       map .p onto .q up to [--x --y]\n"
  in
  match prog with
  | [ _; _; Ast.Crease (None, _, Some { up_to = Some (Ast.FlapLine
        (Ast.LUnion ([ Ast.LNamed _; Ast.LNamed _ ], _))); _ }, _) ] -> ()
  | _ -> Alcotest.fail "expected up to [--x --y] (LUnion of 2)"
```

  Register all three.

- [ ] **Step 3: Run to verify they fail.**

Run: `dune runtest 2>&1 | grep -A3 -e filter_chain -e parse_diff -e parse_union`
Expected: FAIL (syntax errors).

- [ ] **Step 4: Add the grammar.** In `lib/parser.mly`, extend `line_operand`
  (keep existing arms) and add `line_list`:

```
line_operand:
  | crease_ref { LNamed $1 }
  | LINE_OPEN point_operand point_operand RPAREN { LThrough ($2, $3, $loc) }
  | crease_ref AT_KW selector { LAt ($1, [ $3 ], $loc) }
  | crease_ref AT_KW LPAREN selector AND selector RPAREN { LAt ($1, [ $4; $6 ], $loc) }
  | LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET { LMember ($2, $3, $loc) }
  | line_operand AMP selector       { LFilter ($1, Keep $3, $loc) }
  | line_operand BACKSLASH selector { LFilter ($1, Drop $3, $loc) }
  | LBRACKET line_list RBRACKET     { LUnion ($2, $loc) }

line_list:
  | line_operand           { [ $1 ] }
  | line_operand line_list { $1 :: $2 }
```

- [ ] **Step 5: Check for grammar conflicts.**

Run: `menhir --explain lib/parser.mly 2>&1 | grep -i conflict || echo "no conflicts"`
Expected: `no conflicts`. The left-recursive `line_operand AMP selector` is a
standard LR shift; if menhir reports a conflict it is between `LBRACKET`-led
`LUnion` and nothing else (there is no other `[`-led rule) — investigate the
`.parser.conflicts` dump.

- [ ] **Step 6: Run parse tests.**

Run: `dune runtest 2>&1 | grep -A3 -e filter_chain -e parse_diff -e parse_union`
Expected: PASS.

- [ ] **Step 7: Generalize the filter engine.** In `lib/eval.ml`, replace
  `at_matches` (lines 351-381) with `bundle_segments`, keeping the
  `seg_line`/`point_on_seg`/`incident` helpers verbatim. `incident` takes a
  single selector; add a recursive walk:

```ocaml
  and bundle_segments (lo : Ast.line_operand) :
      int option * Fold_state.crease_segment list =
    let seg_line (s : Fold_state.crease_segment) =
      Geom.line_through s.Fold_state.ta s.Fold_state.tb
    in
    let point_on_seg (tp : Geom.point) (s : Fold_state.crease_segment) =
      Geom.side_of_line (seg_line s) tp = 0
      &&
      let t = Geom.seg_param (s.Fold_state.ta, s.Fold_state.tb) tp in
      Num.compare t Num.zero >= 0 && Num.compare t Num.one <= 0
    in
    let incident (sel : Ast.selector) (s : Fold_state.crease_segment) : bool =
      match sel with
      | Ast.SelPoint po ->
          point_on_seg
            (Fold_state.table_position !(ctx.state) (resolve_point po)) s
      | Ast.SelLine lo -> (
          match Geom.intersection (resolve_line lo) (seg_line s) with
          | Some ip -> point_on_seg ip s
          | None -> false)
      | Ast.SelFlap (Ast.FByPoints (pts, fspan)) -> (
          match face_of_points (List.map resolve_point pts) with
          | `Face fi -> let l, r = s.Fold_state.faces in l = fi || r = fi
          | `Zero -> Error.fail fspan "those points aren't all on one flap"
          | `Ambiguous -> Error.fail fspan "ambiguous flap; add another point")
    in
    match lo with
    | Ast.LNamed cr -> (Some (material_cid cr),
                        Fold_state.crease_segments !(ctx.state) (material_cid cr))
    | Ast.LMember _ -> Error.fail (span_of_line lo)
        "instance line members are not yet selectable as bundles"
    | Ast.LThrough _ -> Error.fail (span_of_line lo)
        "a line through two points is not a segment bundle"
    | Ast.LAt (cr, sels, _) ->
        let cid = material_cid cr in
        (Some cid,
         List.filter
           (fun s -> List.for_all (fun sel -> incident sel s) sels)
           (Fold_state.crease_segments !(ctx.state) cid))
    | Ast.LFilter (b, elt, _) ->
        let cid, segs = bundle_segments b in
        let keep = match elt with Ast.Keep _ -> true | Ast.Drop _ -> false in
        let sel = match elt with Ast.Keep s | Ast.Drop s -> s in
        (cid, List.filter (fun s -> incident sel s = keep) segs)
    | Ast.LUnion (los, _) ->
        (None, List.concat_map (fun l -> snd (bundle_segments l)) los)
  ```

  Add a helper `span_of_line` if none exists (returns the `Error.span` carried by
  each `line_operand` variant; `LNamed`/`LMember` use `.cspan`/their span).

- [ ] **Step 8: Route the coercion sites through `bundle_segments`.** In
  `resolve_line` (lines 293-305) and `resolve_paper_line` (lines 328-342),
  replace the `LAt` arm with arms for `LFilter`/`LUnion` (leave `LAt` calling the
  same singleton logic for now). Extract the singleton coercion into a helper so
  all three share it:

```ocaml
  and coerce_one ~what (segs : Fold_state.crease_segment list) span =
    match segs with
    | [ s ] -> s
    | [] -> Error.fail span (Printf.sprintf "no segment of %s matches" what)
    | many -> Error.fail span
        (Printf.sprintf "%s is ambiguous: %d segments match; add a selector"
           what (List.length many))
```

  Then in `resolve_line`:

```ocaml
    | (Ast.LFilter _ | Ast.LUnion _) as b ->
        let s = coerce_one ~what:(lstr b) (snd (bundle_segments b)) (span_of_line b) in
        Geom.line_through s.Fold_state.ta s.Fold_state.tb
```

  and the paper-space analogue in `resolve_paper_line` (using `s.pa`/`s.pb` and
  returning the chord as at line 331-333).

- [ ] **Step 9: Update the printers.** In `lib/eval.ml:136-157`, add `lstr`
  arms:

```ocaml
    | Ast.LFilter (b, Ast.Keep s, _) ->
        Printf.sprintf "%s & %s" (lstr b) (selstr [ s ])
    | Ast.LFilter (b, Ast.Drop s, _) ->
        Printf.sprintf "%s \\ %s" (lstr b) (selstr [ s ])
    | Ast.LUnion (bs, _) ->
        Printf.sprintf "[%s]" (String.concat " " (List.map lstr bs))
```

- [ ] **Step 10: Write the eval test.** Add to `tests/test_eval.ml` a test that
  a filtered bundle resolves to the right segment. Use an example with a crease
  split by a crossing so `&` disambiguates (mirror
  `examples/crease-at-flap.bel`). Assert the folded output equals the `at`
  equivalent:

```ocaml
let test_filter_equiv_at () =
  let src_at =
    "paper square\n--a = through .p1 .p3\n--b = through .p2 .p4\n\
     ; … a construction where --a is split by --b …\n\
     map .x onto .y up to --a at .p1\n" in
  let src_amp = Str.global_replace (Str.regexp_string "at .p1") "& .p1" src_at in
  Alcotest.(check string) "& matches at"
    (Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" src_at))
    (Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" src_amp))
```

  (Fill the construction from a real split-crease example in `examples/syntax/`;
  do not ship a placeholder `; …` — copy a working body.)

- [ ] **Step 11: Run the suite.**

Run: `dune runtest 2>&1 | tail -20`
Expected: all green (old `at` untouched; new forms pass).

- [ ] **Step 12: Commit.**

```bash
git add lib/ast.ml lib/parser.mly lib/eval.ml tests/test_parse.ml tests/test_eval.ml
git commit -m "feat: filter & / diff \\ / union [] over crease bundles (additive)"
```

---

## Task 5: Bind a filter/union result to a crease name

**Files:**
- Modify: `lib/parser.mly:44-49` (`body_stmt`)
- Modify: `lib/eval.ml` (crease-binding path for a bundle RHS)
- Test: `tests/test_parse.ml`, `tests/test_eval.ml`

**Interfaces:**
- Consumes: `LFilter`/`LUnion` (Task 4).
- Produces: `--seg = --l & .p` binds `seg` to the segment bundle; referencing
  `--seg` later behaves as the filtered bundle (render pre-selection case).

- [ ] **Step 1: Verify the crease-value model.** Read `lib/eval.ml` around
  `materialize_crease` (line 159) and the `crease_val` type (`Material (cid,…)` /
  `Frozen …`, seen at line 344-346). Confirm how a bound name maps to a `cid` +
  optional segment restriction. If binding a *sub-bundle* needs a new
  `crease_val` case (a cid plus a segment predicate), add it here; if a bound
  name can already carry a segment subset, reuse it. Write a one-line note in the
  commit message stating which.

- [ ] **Step 2: Write the failing test.**

```ocaml
let test_bind_filter () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .b\n--seg = --l & .c\n"
  in
  match List.rev prog with
  | Ast.Crease (Some "seg", _, _, _) :: _ -> ()   (* or the dedicated bind node *)
  | _ -> Alcotest.fail "expected --seg bound to a filtered bundle"
```

  Adjust the expected AST to whatever binding node you choose in Step 3.

- [ ] **Step 3: Add the grammar.** In `lib/parser.mly` `body_stmt`, add a bind
  form for a bundle RHS (disambiguated from `axiom_stmt` by the first token —
  `CREASE`/`LBRACKET`/`LINE_MEMBER_OPEN` start a `line_operand`, whereas
  `THROUGH`/`MAP`/`PERP`/`AT` start an axiom):

```
  | CREASE EQ line_operand { Crease (Some $1, (* wrap as a bundle-bind axiom or
      a new stmt variant *) …, None, $loc) }
```

  Prefer a new `stmt` variant `BindBundle of string * line_operand * Error.span`
  over overloading `Crease`, so eval keeps bundle-binding separate from axiom
  construction. Add it to `ast.ml` `stmt` and handle it in eval.

- [ ] **Step 4: Check conflicts.**

Run: `menhir --explain lib/parser.mly 2>&1 | grep -i conflict || echo "no conflicts"`
Expected: `no conflicts`. If `CREASE EQ line_operand` conflicts with
`CREASE EQ LINE_OPEN …` or `CREASE EQ axiom_stmt`, it is a first-token overlap —
`LINE_OPEN` (`--(`) is removed in Task 7, and axioms are keyword-led, so the only
real overlap is `CREASE EQ CREASE` (aliasing). Decide: allow the alias
(harmless), or require the RHS to contain at least one `&`/`\`/`[`. Simplest:
allow it.

- [ ] **Step 5: Implement eval.** Handle `BindBundle` — resolve
  `bundle_segments` at bind time is wrong (state changes later); instead bind the
  *expression* (store the `line_operand`) or a cid+predicate that re-resolves on
  use. Follow whatever `Frozen`/`Material` reuse Step 1 established. Add an eval
  test that a bound bundle folds identically to inlining it:

```ocaml
let test_bind_roundtrip () =
  let inl = "paper square\n--l = through .a .b\n… fold up to --l & .c …\n" in
  let bnd = "paper square\n--l = through .a .b\n--s = --l & .c\n… fold up to --s …\n" in
  Alcotest.(check string) "bound == inline"
    (Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" inl))
    (Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" bnd))
```

  (Replace the `…` with a real split-crease body — no placeholders in the shipped
  test.)

- [ ] **Step 6: Run the suite.**

Run: `dune runtest 2>&1 | tail -20`
Expected: green.

- [ ] **Step 7: Commit.**

```bash
git add lib/ast.ml lib/parser.mly lib/eval.ml tests/test_parse.ml tests/test_eval.ml
git commit -m "feat: bind a filter/union bundle to a crease name"
```

---

## Task 6: Migrate all examples + regenerate goldens (breaking)

**Files:**
- Modify: every `.bel` under `examples/` using old syntax (`at`, `.()`, `--(`,
  `#(`, `cross`) — per the design's migration table (14 `at`, 9 `.(`, 6 `#(`,
  20 `--(`, plus `cross` sites).
- Modify: `tests/golden/**/*.fold` (regenerated).

**Interfaces:**
- Consumes: all new syntax (Tasks 2-5). Produces: a corpus that uses only the new
  notation, with goldens proving output is byte-identical to before.

- [ ] **Step 1: Migrate mechanically, file by file.** Apply, per file:
  - `--l at <sel>` → `--l & <sel>`
  - `--l at (S1 and S2)` → `--l & S1 & S2`
  - `#(…)` → `#[…]`
  - `.(--x --y)` → `--x * --y`
  - `cross --x --y` → `--x * --y`
  - `--d = --(.a .b)` (statement) → `--d = through .a .b`
  - `--(.a .b)` as an operand → introduce a named crease first (`--e = through
    .a .b`), then reference `--e` (or `--e` in a `*`). See the design's
    "inline line-construction is gone" note.

  Do NOT batch-sed blindly across the whole tree — the `--(` operand cases need a
  named crease inserted and are per-file judgement. Work one file, rebuild, move
  on.

- [ ] **Step 2: Confirm every example still parses.**

Run: `dune build && dune exec beloch -- check examples/**/*.bel 2>&1 | tail`
(or the project's parse-check entrypoint; if none, a small loop over
`Beloch.parse`). Expected: no syntax errors.

- [ ] **Step 3: Regenerate goldens.**

Run: `dune exec tools/regen.exe`
Then inspect the diff: `git diff --stat tests/golden/`
Expected: **only span/whitespace-free** changes — the FOLD geometry must be
identical. If a `.fold` changes geometry, a migration changed meaning (likely an
`--(` operand that used to score vs now references) — fix the `.bel`, not the
golden.

- [ ] **Step 4: Run the golden suite.**

Run: `dune runtest 2>&1 | grep -A3 golden`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add examples tests/golden
git commit -m "refactor(examples): migrate to & / * / #[] / [] notation"
```

---

## Task 7: Remove the old syntax (breaking)

**Files:**
- Modify: `lib/lexer.ml` (drop `at`, `cross`, `--(`, `.(`, `#(` arms)
- Modify: `lib/parser.mly` (drop `AT_KW`, `CROSS`, `LINE_OPEN`, `POINT_OPEN`,
  `FLAP_OPEN` decls + rules)
- Modify: `lib/ast.ml` (drop `LThrough`, `LAt`)
- Modify: `lib/eval.ml` (drop `LThrough`/`LAt` arms + old printer arms)
- Test: `tests/test_parse.ml` (drop/adjust old-syntax tests)

**Interfaces:**
- Produces: a grammar where reads are only `* & \ #[] []` and the old tokens no
  longer exist.

- [ ] **Step 1: Remove lexer arms.** Delete lines for `"at"`, `"cross"`,
  `"--(" -> LINE_OPEN`, `".(" -> POINT_OPEN`, `"#(" -> FLAP_OPEN` in
  `lib/lexer.ml`.

- [ ] **Step 2: Remove parser tokens + rules.** In `lib/parser.mly`: drop
  `AT_KW`, `CROSS`, `LINE_OPEN`, `POINT_OPEN`, `FLAP_OPEN` from `%token`; delete
  the productions at old lines 45 (`CREASE EQ LINE_OPEN …`), 138
  (`CROSS line line`), 139 (`POINT_OPEN …`), 143 (`POINT_OPEN …`), 151
  (`LINE_OPEN …`), 152-153 (`AT_KW` filter), 159 (selector inline `LINE_OPEN`),
  163 (`FLAP_OPEN …`).

- [ ] **Step 3: Remove AST variants.** In `lib/ast.ml`, delete `LThrough` and
  `LAt` from `line_operand`, and the `SelLine` comment that references them.
  Update the `selector` doc comment.

- [ ] **Step 4: Fix eval fallout.** Remove the `LThrough`/`LAt` arms in
  `resolve_line`, `resolve_paper_line`, `bundle_segments`, and the printers
  (`lstr` `LThrough`/`LAt`, `selstr` — the `and`-joined form is dead; keep
  `selstr` for single selectors used by the `&` printer). Compile-driven: the
  OCaml exhaustiveness checker will flag every site.

Run: `dune build 2>&1 | head -30`
Expected: after edits, builds clean (no non-exhaustive-match warnings).

- [ ] **Step 5: Delete stale old-syntax tests.** Remove `test_parse_named_and_anon`'s
  `.center = cross …` line (change to `*`), and any test asserting `LAt`/`LThrough`.
  Keep the meet/filter/union tests.

- [ ] **Step 6: Full suite.**

Run: `dune runtest 2>&1 | tail -20`
Expected: all green. Goldens unchanged (Task 6 already migrated the corpus).

- [ ] **Step 7: Commit.**

```bash
git add lib tests
git commit -m "refactor: remove at / cross / --( / .( / #( — new notation only"
```

---

## Task 8: Spec sync + freed-paren guard test

**Files:**
- Modify: `spec/SPECIFICATION.md` (selector section §4.8, point/line operands)
- Test: `tests/test_parse.ml`

**Interfaces:** none downstream — documentation + a regression guard.

- [ ] **Step 1: Add a grouping guard test.** Prove `()` is pure grouping and
  precedence works:

```ocaml
let test_group_precedence () =
  (* (--l & .p) * --s : filter binds before meet *)
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .b\n--s = through .c .d\n\
       .o = (--l & .p) * --s\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.Cross (Ast.LFilter _, Ast.LNamed _), _) :: _ -> ()
  | _ -> Alcotest.fail "expected Cross(LFilter, LNamed)"
```

- [ ] **Step 2: Run it.**

Run: `dune runtest 2>&1 | grep -A3 group_precedence`
Expected: PASS.

- [ ] **Step 3: Update `spec/SPECIFICATION.md`.** In the selector section
  (search `at ` and `#(`), replace the surface grammar with `& \ #[] [] *`; add
  the state-change-law framing (one paragraph, link the design doc); note meet is
  a read-operator and line-through-points is the axiom keyword. Remove the
  `.(…)`/`cross`/`--(…)` prose.

- [ ] **Step 4: Commit.**

```bash
git add spec/SPECIFICATION.md tests/test_parse.ml
git commit -m "docs(spec): notation §4.8 — reads as operators, writes as keywords"
```

---

## Self-review checklist (run after writing, before executing)

- **Spec coverage:** `&` (T4), `\` (T4), `[]` union (T4), `#[]` (T3), meet `*`
  (T2), no `--[]` / line-through-points-as-keyword (T6/T7), filter results bind
  (T5), context-typed granularity (T4 reuse of `face_of_points`), freed `()` +
  precedence (T8), migration (T6). ✅ every spec section maps to a task.
- **Placeholder scan:** the only `…` are in Task 4/5 test bodies with an explicit
  instruction to copy a real split-crease body before shipping — the implementer
  must fill them from an existing `examples/syntax/` file, not ship the ellipsis.
- **Type consistency:** `bundle_segments` returns `int option *
  crease_segment list` and is used by `resolve_line`/`resolve_paper_line`/binding
  consistently; `filter_elt = Keep | Drop`; `LFilter`/`LUnion` names match across
  T4/T5/T7.
```
