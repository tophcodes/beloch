# Join selector `--[]` + notation cutover — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the join selector `--[c+]`, the point selector `.[l+]`, prelude
paper-edge names `--ab --bc --cd --da`, unify meet/join under one `Select` node
with `*` as pure binary sugar, migrate the whole corpus, and remove the legacy
`at` / `cross` / `--(` / `.(` / `#(` syntax and instance member access — per
`docs/superpowers/specs/2026-07-08-notation-by-state-change-design.md`.

**Architecture:** Additive-then-cutover on the sedlex lexer, menhir grammar,
AST, and evaluator. Add the new forms alongside the old (build stays green, old
`.bel` still parses), migrate every example + golden, then delete the old
tokens/rules in one compile-driven task. Only the sight-line rework (Task 6/7)
and the removal (Task 8) are breaking; everything before keeps `dune runtest`
green.

**Tech Stack:** OCaml, sedlex (`lib/lexer.ml`), menhir (`lib/parser.mly`),
`lib/ast.ml`, `lib/eval.ml`, alcotest (`tests/`), `tools/regen.ml` (golden
regeneration), zarith/FLINT number kernel (unchanged).

## Global Constraints

- **Exact arithmetic only** — no floats anywhere (ADR 0008/0012).
- **Pre-1.0 hard cutover** — no deprecated aliases; old syntax is removed, not
  kept alongside, once migration lands.
- **Reads are operators, writes are keywords** — no keyword for a pure read
  (meet, join, filter, diff, union); no operator for a write (`through`).
- **No sight-lines** — a named line is either a real crease/edge (selected with
  `--[]` / `--ab` / `*`) or a scored crease (`through`). `--[]` errors if no
  real crease or edge is incident to all its constraints.
- **INTERIM DECISION (2026-07-08):** the 20 `--(` sight-line operands — both the
  10 fold-targets and the 10 point-locating ones — become **full `through`
  creases now.** Point-locating landmarks (cube-root's thirds, inline-midpoint's
  centre) *should* be `pinch` marks, but pinch is unshipped, so we score full
  creases as interim and tag each with `; TODO(pinch): landmark — replace with
  pinch when shipped`. Their goldens legitimately move (new creases in the CP);
  `cube-root.bel` no longer byte-matches Messer's Figure 2 until the pinch pass.
  You cannot cross two undrawn lines — do NOT invent a virtual-line-meet read.
- **Granularity of `#[…]` stays context-typed** — reuse `face_of_points` /
  cluster resolution exactly as `#(…)` does today; no `face[]`/`flap[]` split.
- Run the suite with `dune runtest` from repo root. Regenerate goldens with
  `dune exec tools/regen.exe` (never hand-edit `.fold`).
- Every task is its own commit(s). Conventional-commit messages (personal repo).

---

## Baseline facts (read once — verified against the tree at plan time)

- **Corners** (`lib/eval.ml:4-11`): `a=(0,0) b=(1,0) c=(1,1) d=(0,1)`, seeded into
  `root_scope.points` at `:121`. The four paper edges are the adjacent-corner
  pairs: `ab bc cd da`. `a–c` and `b–d` are diagonals (NOT edges).
- **`crease_val`** (`:22-27`): `Material of int * Geom.line | Frozen of Geom.line
  | Bundle of Ast.line_operand`. This plan adds `Edge of string * string`.
- **Resolvers** (`lib/eval.ml`): `resolve_point :250`, `resolve_line :287`,
  `resolve_paper_line :326`, `material_cid :368`, `seg_incident :388`,
  `at_matches :404`, `span_of_line :411`, `bundle_segments :420`,
  `coerce_one_segment :449`. Printers `pstr/lstr/selstr` `:134-157`.
- **`Fold_state.crease_segment`** fields used here: `ta tb` (table-space
  endpoints), `pa pb` (paper-space endpoints), `faces` (int*int). Accessors:
  `Fold_state.crease_segments : t -> int -> crease_segment list`,
  `Fold_state.table_position : t -> Geom.point -> Geom.point`.
- **Geom**: `Geom.line_through : point -> point -> line`,
  `Geom.intersection : line -> line -> point option`,
  `Geom.point_equal`, `Geom.side_of_line`, `Geom.seg_param`.
- **Line-operand consumers** all funnel through `resolve_line` (table space) or
  `resolve_paper_line` (paper space, for `*`-meet operands). Fold-target slots
  (`map … onto <line>`, `@fold <line>`, collapse elements) call `resolve_line`.
- **Legacy corpus inventory (2026-07-08 audit)** — the migration targets:
  - `at` filter: 59 uses / 32 lines.
  - `cross`: 14. `.(`: 35. `#(`: 6.
  - `--(`: 92 code operands = **71 edge** + **20 sight-line** + **1 statement**.
    - Statement: `iteration/001.bel:19` `--crease = --(.o .rm)`.
    - Sight-line **Group 1 (fold-target, 10):** `iteration/{001,002,003,004}.bel:9-10`
      `map --(.a .b) onto --(.a .m)` (the `--(.a .m)`/`--(.b .m)` corner→apex
      second operand, 8) + `bisect-straddle.bel:2` (`--(.a .c)`, `--(.b .d)`, 2).
    - Sight-line **Group 2 (point-locating, 10):** `cube-root.bel:23,24,26,27`
      (`--(.a .c)`, `--(.d .b)`, and corner→midpoint `--(.d ._mb)` etc., 8) +
      `inline-midpoint.bel:3` (`--(.a .c)`, `--(.b .d)`, 2).
  - Member access `--[$…]`: 2, both in `def-diagonals.bel:14`
    (`.m = cross --[$d1 d] --[$d2 d]`). No `.[$…]`.
  - 30 distinct `.bel` files touched; no `.bel` under `tests/`.

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `lib/lexer.ml` | tokens | (tokens `& \ * [ #[` already exist) later remove `at` `cross` `--(` `.(` `#(` arms |
| `lib/parser.mly` | grammar + AST-build | add `--[]`/`.[]` select + `*`-join productions; later remove legacy rules |
| `lib/ast.ml` | AST types | add `LSelect`/`PSelect`; later remove `LThrough`/`LMember`/`LAt`/`Cross`/`PCross`/`PMember` |
| `lib/eval.ml` | resolution | add `Edge` crease_val, prelude edges, `select_line`/`select_point` resolvers, printers; later drop legacy arms |
| `examples/**/*.bel` | corpus | migrate (Tasks 5-7) |
| `tests/golden/**/*.fold` | goldens | regenerate (Tasks 6-7) |
| `tests/test_parse.ml`, `tests/test_eval.ml` | unit tests | per-construct tests |
| `spec/SPECIFICATION.md` | language spec | sync selector section (Task 8) |

## Notes for the implementer (read once)

- **The tokens `AMP BACKSLASH STAR LBRACKET FLAP_BRACKET` already exist** (shipped
  in the prior slice), as do `LFilter`/`LUnion`/`Bundle`/`BindBundle` and the
  `bundle_segments` engine. This plan is the *second* slice: selectors + cutover.
- **`--[` and `.[` are still taken** by `LINE_MEMBER_OPEN` / `POINT_MEMBER_OPEN`
  (instance member access). The new `--[c+]`/`.[l+]` productions are added
  **alongside** the member-access productions — they are LR-distinguishable
  because member access is `LINE_MEMBER_OPEN INSTANCE …` (leading `INSTANCE`
  token) while a select constraint list never starts with `INSTANCE`. Member
  access is removed in Task 8, which also deletes the 1 file that uses it.
- **Paper edges resolve LIVE through their corners**, not as a fixed line: an
  edge moves under folding. `Edge("a","b")` resolves in table space via
  `table_position` of both corners, in paper space via the raw corner
  coordinates with `None` marks — byte-identical to how the old `--(.a .b)`
  operand resolved an edge (`LThrough` table arm `:293` / paper arm `:333`).
- **`--[c+]` is a global incidence search**, not a line-through-two-points: it
  scans all material crease segments PLUS the four paper edges for the unique one
  incident to every constraint, and errors on 0 or >1. Reuse the existing
  `seg_incident` (`:388`) for the crease side; add edge candidates from
  `corners`.
- **`.[l+]` is n-ary meet:** intersect the resolved lines pairwise and require
  concurrency (every line passes through the common point). Binary `--x * --y` is
  the 2-line case.
- **`*` is pure sugar** over the Select nodes: `line * line` → `PSelect [l1;l2]`
  (meet, a point); `point * point` → `LSelect [SelPoint p1; SelPoint p2]` (join,
  a line). `Cross`/`PCross` (the shipped meet nodes) are retired into `PSelect`.

---

## Task 1: Paper-edge prelude — `Edge` crease_val + resolvers + `--ab --bc --cd --da`

Additive. Adds the four edge names and teaches the resolvers to handle an `Edge`
value. No grammar change. Keeps the suite green.

**Files:**
- Modify: `lib/eval.ml` (`crease_val` `:22`, prelude bind near `:121`,
  `materialize_crease` `:165`, `paper_line_of_crease` `:190`, `resolve_line`
  `:287`, `resolve_paper_line` `:326`, `lstr` printer — no change needed for
  Edge since edges print via their bound name)
- Test: `tests/test_eval.ml`

**Interfaces:**
- Produces: `crease_val = … | Edge of string * string`. Root scope binds
  `--ab --bc --cd --da` to `Edge` values. `resolve_line (LNamed {cname="ab"})`
  returns the live table-space bottom edge; `resolve_paper_line` returns
  `(paper edge line, None)`.

- [ ] **Step 1: Add the `Edge` constructor.** In `lib/eval.ml:22-27`:

```ocaml
type crease_val =
  | Material of int * Geom.line
  | Frozen of Geom.line
  | Bundle of Ast.line_operand
  | Edge of string * string
      (* a paper boundary edge, named by its two corners; resolves live
         (the edge moves under folding) through the current corner positions *)
```

- [ ] **Step 2: Bind the four edges in the root scope.** In `eval_folded`, right
  after the corners are seeded (`lib/eval.ml:121`), add:

```ocaml
  List.iter
    (fun (n, a, b) -> Hashtbl.replace root_scope.lines n (Edge (a, b)))
    [ ("ab", "a", "b"); ("bc", "b", "c"); ("cd", "c", "d"); ("da", "d", "a") ];
```

- [ ] **Step 3: Add a corner-lookup helper.** Near the other resolver helpers
  inside `eval_folded` (e.g. just above `resolve_point` at `:250`), add:

```ocaml
  let corner_point (n : string) : Geom.point =
    match List.assoc_opt n corners with
    | Some p -> p
    | None -> assert false (* Edge is only built from a,b,c,d *)
  in
```

- [ ] **Step 4: Handle `Edge` in the four resolvers.** Add an `Edge` arm to each:

  In `materialize_crease` (`:167`, the `match cv with` — table space, live):

```ocaml
    | Edge (a, b) ->
        let pa = Fold_state.table_position !(ctx.state) (corner_point a)
        and pb = Fold_state.table_position !(ctx.state) (corner_point b) in
        Geom.line_through pa pb
```

  In `paper_line_of_crease` (`:192` — paper space, no marks):

```ocaml
    | Edge (a, b) ->
        (Geom.line_through (corner_point a) (corner_point b), None)
```

  `resolve_line`/`resolve_paper_line` route `LNamed` through those two functions
  already (`:289-292`, `:329-332`), so no change is needed there once the `Edge`
  arms exist. Confirm `material_cid` (`:368`) errors sensibly on `Edge` — add:

```ocaml
    | Edge _ ->
        Error.fail cr.Ast.cspan
          (Printf.sprintf "--%s is a paper edge, not a crease with segments"
             cr.Ast.cname)
```

- [ ] **Step 5: Write the eval test.** Add to `tests/test_eval.ml`:

```ocaml
let test_edge_fold_equiv () =
  (* folding up to the named edge == folding up to --(.a .b) today *)
  let old_ = "paper square\nmap .d onto .a up to --(.a .b)\n" in
  let new_ = "paper square\nmap .d onto .a up to --ab\n" in
  Alcotest.(check string) "--ab == --(.a .b)"
    (Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" old_))
    (Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" new_))
```

  Register it in the test list (follow the existing `(name, `Quick, fn)`
  pattern). If `Beloch.fold_string` is named differently, grep `test_eval.ml`
  for the existing fold-to-JSON helper and match it.

- [ ] **Step 6: Run.**

Run: `dune runtest 2>&1 | tail -20`
Expected: green, including `test_edge_fold_equiv`.

- [ ] **Step 7: Commit.**

```bash
git add lib/eval.ml tests/test_eval.ml
git commit -m "feat(eval): paper-edge prelude names --ab --bc --cd --da (Edge crease_val)"
```

---

## Task 2: Select nodes — `--[c+]` line select + `.[l+]` point select

Additive. New AST nodes `LSelect`/`PSelect`, grammar alongside member access, and
the incidence resolvers. `*` is retargeted in Task 3.

**Files:**
- Modify: `lib/ast.ml` (`point_operand` `:19`, `line_operand` `:24`)
- Modify: `lib/parser.mly` (`point_operand` `:143`, `line_operand` `:152`, new
  `select_constraints` / `line_operand_list` lists)
- Modify: `lib/eval.ml` (`resolve_point`, `resolve_line`, `resolve_paper_line`,
  `span_of_line`, `bundle_segments`, printers)
- Test: `tests/test_parse.ml`, `tests/test_eval.ml`

**Interfaces:**
- Produces:
  - AST `PSelect of line_operand list * Error.span`,
    `LSelect of selector list * Error.span`.
  - `--[.a .b]` → `LSelect [SelPoint (PNamed a); SelPoint (PNamed b)]`, resolves
    to the paper edge `ab`; `.[--x --y]` → `PSelect [LNamed x; LNamed y]`,
    resolves to the meet point; both error if 0 or >1 real crease/edge / no
    concurrency.

- [ ] **Step 1: Add the AST nodes.** In `lib/ast.ml`, extend `point_operand`
  (`:19`, keep `PCross`/`PMember` for now) and `line_operand` (`:24`, keep
  `LThrough`/`LMember`/`LAt` for now):

```ocaml
type point_operand =
  | PNamed of point_ref
  | PCross of line_operand * line_operand * Error.span
  | PMember of string * string * Error.span
  | PSelect of line_operand list * Error.span
    (* .[l+] and --x * --y: the point incident to all listed lines
       (n-ary meet; the lines must be concurrent) *)

and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span
  | LMember of string * string * Error.span
  | LAt of crease_ref * selector list * Error.span
  | LFilter of line_operand * filter_elt * Error.span
  | LUnion of line_operand list * Error.span
  | LSelect of selector list * Error.span
    (* --[c+] and .a * .b: the unique existing crease/edge incident to all
       constraints; errors on none or ambiguity (no sight-lines) *)
```

- [ ] **Step 2: Write the failing parse tests.** Add to `tests/test_parse.ml`:

```ocaml
let test_parse_line_select () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmap .d onto .a up to --[.a .b]\n"
  in
  match prog with
  | [ Ast.Crease (None, _, Some { up_to = Some (Ast.FlapLine
        (Ast.LSelect ([ Ast.SelPoint _; Ast.SelPoint _ ], _))); _ }, _) ] -> ()
  | _ -> Alcotest.fail "expected up to --[.a .b] (LSelect of 2 points)"

let test_parse_point_select () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--x = through .a .b\n--y = through .c .d\n\
       .o = .[--x --y]\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.PsExpr (Ast.PSelect ([ Ast.LNamed _; Ast.LNamed _ ], _)), _) :: _ -> ()
  | _ -> Alcotest.fail "expected .o = .[--x --y] (PSelect of 2 lines)"
```

  NOTE: `.o = .[…]` binds a point via the `POINT EQ point_expr` rule. Until Task
  3 unifies `point_expr`, add a temporary `point_expr` arm producing the
  `PSelect`. If `point_expr` is still the `Cross`-only variant, wrap: change the
  Point test to assert against whatever `point_expr` shape you choose in Step 4.
  Simplest and forward-compatible: in this task, make `point_expr` carry a
  `point_operand` (see Step 4) so `.[…]` and (Task 3) `*` both flow through it.

- [ ] **Step 3: Run to verify they fail.**

Run: `dune runtest 2>&1 | grep -A3 -e line_select -e point_select`
Expected: FAIL (syntax errors at `--[`/`.[`).

- [ ] **Step 4: Add the grammar.** In `lib/parser.mly`:

  Change `point_expr` (`:138`) to carry a point_operand and add the `.[` arm.
  First, in `ast.ml`, replace the `point_expr` type (`:83-84`):

```ocaml
type point_expr = PsExpr of point_operand
```

  and update the `Point` stmt eval (see below) accordingly. Then grammar:

```
point_expr:
  | CROSS line_operand line_operand               { PsExpr (PCross ($2, $3, $loc)) }
  | POINT_OPEN line_operand line_operand RPAREN   { PsExpr (PCross ($2, $3, $loc)) }
  | line_operand STAR line_operand                { PsExpr (PCross ($1, $3, $loc)) }
  | POINT_MEMBER_OPEN line_operand_list RBRACKET  { PsExpr (PSelect ($2, $loc)) }
```

  (The `*` arm still builds `PCross` here — Task 3 retargets it to `PSelect`.)
  Add the `.[` select to `point_operand` (`:143`, alongside the member arm):

```
point_operand:
  | point_ref { PNamed $1 }
  | POINT_OPEN line_operand line_operand RPAREN { PCross ($2, $3, $loc) }
  | LPAREN line_operand STAR line_operand RPAREN { PCross ($2, $4, $loc) }
  | POINT_MEMBER_OPEN INSTANCE IDENT RBRACKET   { PMember ($2, $3, $loc) }
  | POINT_MEMBER_OPEN line_operand_list RBRACKET { PSelect ($2, $loc) }
```

  Add the `--[` select to `line_operand` (`:152`, alongside the member arm):

```
line_operand:
  | crease_ref { LNamed $1 }
  | LINE_OPEN point_operand point_operand RPAREN { LThrough ($2, $3, $loc) }
  | crease_ref AT_KW selector { LAt ($1, [ $3 ], $loc) }
  | crease_ref AT_KW LPAREN selector AND selector RPAREN { LAt ($1, [ $4; $6 ], $loc) }
  | LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET     { LMember ($2, $3, $loc) }
  | LINE_MEMBER_OPEN select_constraints RBRACKET { LSelect ($2, $loc) }
  | line_operand AMP selector       { LFilter ($1, Keep $3, $loc) }
  | line_operand BACKSLASH selector { LFilter ($1, Drop $3, $loc) }
  | LBRACKET line_list RBRACKET     { LUnion ($2, $loc) }
```

  Add the two list nonterminals (near `line_list` `:162`):

```
select_constraints:
  | selector                    { [ $1 ] }
  | selector select_constraints { $1 :: $2 }

line_operand_list:
  | line_operand                   { [ $1 ] }
  | line_operand line_operand_list { $1 :: $2 }
```

- [ ] **Step 5: Check for grammar conflicts.**

Run: `menhir --explain lib/parser.mly 2>&1 | grep -i conflict || echo "no conflicts"`
Expected: `no conflicts`. `LINE_MEMBER_OPEN INSTANCE …` vs `LINE_MEMBER_OPEN
select_constraints …` disambiguate on the token after the opener (`INSTANCE`
vs `POINT`/`CREASE`/`POINT_OPEN`/`LINE_OPEN`/`FLAP_OPEN`/`FLAP_BRACKET`/`--[`).
If menhir reports a conflict, read `.parser.conflicts`; the fix is that
`select_constraints`' first set must not include `INSTANCE` (it doesn't —
`selector` → `point_operand`/`crease_ref`/`flap_operand`, none `INSTANCE`-led).

- [ ] **Step 6: Run parse tests.**

Run: `dune runtest 2>&1 | grep -A3 -e line_select -e point_select`
Expected: PASS.

- [ ] **Step 7: Implement the resolvers.** In `lib/eval.ml`, add two mutually
  recursive resolvers alongside the existing ones (inside the `let rec …`
  resolver block, e.g. after `at_matches` `:410`). Reuse `seg_incident` for
  crease incidence and add the four edges as candidates.

```ocaml
  (* every existing straight line the selector may name: each material crease's
     segments (already split per ADR 0014) plus the four paper edges, as a
     (line, table-space endpoints) pair for incidence + concurrency checks *)
  and select_candidates () : (Geom.line * (Geom.point * Geom.point)) list =
    let edges =
      List.map
        (fun (a, b) ->
          let pa = Fold_state.table_position !(ctx.state) (corner_point a)
          and pb = Fold_state.table_position !(ctx.state) (corner_point b) in
          (Geom.line_through pa pb, (pa, pb)))
        [ ("a", "b"); ("b", "c"); ("c", "d"); ("d", "a") ]
    in
    let crease_segs =
      List.concat_map
        (fun cid ->
          List.map
            (fun (s : Fold_state.crease_segment) ->
              ( Geom.line_through s.Fold_state.ta s.Fold_state.tb,
                (s.Fold_state.ta, s.Fold_state.tb) ))
            (Fold_state.crease_segments !(ctx.state) cid))
        (Fold_state.all_crease_ids !(ctx.state))
    in
    edges @ crease_segs
  (* incidence of a whole candidate line+segment against a select constraint:
     a point on the segment, or a line crossing it within the segment *)
  and cand_incident (sel : Ast.selector)
      ((l, (ta, tb)) : Geom.line * (Geom.point * Geom.point)) : bool =
    let on t = Num.compare t Num.zero >= 0 && Num.compare t Num.one <= 0 in
    match sel with
    | Ast.SelPoint po ->
        let tp = Fold_state.table_position !(ctx.state) (resolve_point po) in
        Geom.side_of_line l tp = 0 && on (Geom.seg_param (ta, tb) tp)
    | Ast.SelLine lo -> (
        match Geom.intersection (resolve_line lo) l with
        | Some ip -> on (Geom.seg_param (ta, tb) ip)
        | None -> false)
    | Ast.SelFlap (Ast.FByPoints (_, fspan)) ->
        Error.fail fspan "a flap is not a valid --[…] constraint; use & to filter"
  and select_line (sels : Ast.selector list) (span : Error.span) : Geom.line =
    match List.filter (fun c -> List.for_all (fun s -> cand_incident s c) sels)
            (select_candidates ()) with
    | [ (l, _) ] -> l
    | [] ->
        Error.fail span
          (Printf.sprintf "no crease or edge is incident to all of %s"
             (selstr sels))
    | many ->
        Error.fail span
          (Printf.sprintf
             "--[…] is ambiguous: %d creases/edges match %s; add a constraint"
             (List.length many) (selstr sels))
  and select_point (los : Ast.line_operand list) (span : Error.span) : Geom.point =
    match los with
    | [] | [ _ ] -> Error.fail span ".[…] needs at least two lines to meet"
    | first :: rest ->
        let l0 = resolve_line first in
        let ls = List.map resolve_line rest in
        (* meet of the first two, then require every other line through it *)
        let p =
          match ls with
          | l1 :: _ -> (
              match Geom.intersection l0 l1 with
              | Some p -> p
              | None -> Error.fail span "those lines are parallel; no meet point")
          | [] -> assert false
        in
        List.iter
          (fun l ->
            if Geom.side_of_line l p <> 0 then
              Error.fail span "the lines are not concurrent; no common point")
          (l0 :: ls);
        p
```

  If `Fold_state.all_crease_ids` does not exist, grep `lib/fold_state.ml` for the
  crease registry (there is one behind `crease_segments`); add a trivial accessor
  that returns the list of live crease ids, or fold the iteration into whatever
  existing "for each crease" helper the module exposes. Match the module's style.

- [ ] **Step 8: Wire the resolvers into the operand resolvers.** Add arms:

  `resolve_point` (`:250`, the `match po with`):

```ocaml
    | Ast.PSelect (los, span) -> select_point los span
```

  `resolve_line` (`:287`):

```ocaml
    | Ast.LSelect (sels, span) -> select_line sels span
```

  `resolve_paper_line` (`:326`) — an `--[]` result is an existing crease/edge, so
  its paper mark is that line with `None` (the meet/incidence already ran in table
  space; for `*`-join paper use, return the table line as paper — edges/creases
  don't move *within* the sheet, matching the `LThrough` paper arm):

```ocaml
    | Ast.LSelect (sels, span) -> (select_line sels span, None)
```

  `span_of_line` (`:411`): add `Ast.LSelect (_, s)` to the span-carrying group.
  `bundle_segments` (`:420`): `--[]` is a single selected line, not a base
  bundle — add `| Ast.LSelect _ -> Error.fail (span_of_line lo) "a --[…] result
  is a single line, not a segment bundle; filter a named crease instead"`.

- [ ] **Step 9: Update the printers.** In `lib/eval.ml`, add to `pstr` (`:134`)
  and `lstr` (`:139`):

```ocaml
    (* pstr *)
    | Ast.PSelect (los, _) ->
        Printf.sprintf ".[%s]" (String.concat " " (List.map lstr los))
    (* lstr *)
    | Ast.LSelect (sels, _) -> Printf.sprintf "--[%s]" (selstr sels)
```

- [ ] **Step 10: Fix the `Point`-stmt eval for the new `point_expr`.** At
  `lib/eval.ml:1161`, replace the `Cross`-specific arm with:

```ocaml
    | Ast.Point (n, Ast.PsExpr po, span) ->
        bind_point ctx n span (resolve_point po)
```

- [ ] **Step 11: Write the eval tests.**

```ocaml
let test_select_edge () =
  (* --[.a .b] selects the same bottom edge as --ab *)
  let a = "paper square\nmap .d onto .a up to --ab\n" in
  let b = "paper square\nmap .d onto .a up to --[.a .b]\n" in
  Alcotest.(check string) "--[.a .b] == --ab"
    (Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" a))
    (Yojson.Safe.to_string (Beloch.fold_string ~filename:"t.bel" b))

let test_select_no_sightline () =
  (* --[.a .c] has no real crease/edge on the diagonal → error *)
  Alcotest.check_raises "diagonal select errors"
    (Error.Beloch_error ("", ("", 0, 0), ("", 0, 0)))  (* match your Error shape *)
    (fun () ->
      ignore (Beloch.fold_string ~filename:"t.bel"
        "paper square\nmap .d onto .a up to --[.a .c]\n"))
```

  For `test_select_no_sightline`, match the project's actual exception
  constructor — grep `lib/error.ml` for `exception` and use `Alcotest.check_raises`
  with a predicate (`fun e -> match e with Error.Beloch_error _ -> true | _ ->
  false`) if the payload can't be spelled literally. Assert only that it raises a
  Beloch error mentioning "incident".

- [ ] **Step 12: Run the suite.**

Run: `dune runtest 2>&1 | tail -20`
Expected: green.

- [ ] **Step 13: Commit.**

```bash
git add lib/ast.ml lib/parser.mly lib/eval.ml tests/test_parse.ml tests/test_eval.ml
git commit -m "feat: --[c+] line select + .[l+] point select over existing creases/edges"
```

---

## Task 3: `*` becomes sugar over Select; retire `Cross`/`PCross`

`*` currently builds `PCross`. Make meet `--x * --y` build `PSelect [x;y]`, add
join `.a * .b` → `LSelect [SelPoint a; SelPoint b]`, and delete `Cross`/`PCross`
(they exist only for the shipped `*`/`.(`/`cross` — no corpus yet). `.(`/`cross`
keep building `PCross`?? No — they must build `PSelect` too so `PCross` can go.

**Files:**
- Modify: `lib/parser.mly` (`point_expr` `*` arm, `point_operand` inline `*` arm,
  add join `*` to `line_operand`; retarget `.(`/`cross`/`POINT_OPEN` arms to
  `PSelect`)
- Modify: `lib/ast.ml` (delete `PCross`; delete `point_expr = Cross` remnants)
- Modify: `lib/eval.ml` (delete `PCross` arm in `resolve_point`; the printer
  `pstr` `PCross` arm; `ax5_material`/apply sites reference `LThrough` not
  `PCross`, unaffected)
- Test: `tests/test_parse.ml`

**Interfaces:**
- Produces: `--x * --y` → `PsExpr (PSelect [LNamed x; LNamed y])`;
  `(--x * --y)` operand → `PSelect [...]`; `.a * .b` → `LSelect [SelPoint (PNamed
  a); SelPoint (PNamed b)]`.

- [ ] **Step 1: Write the failing tests.**

```ocaml
let test_meet_is_select () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--x = through .a .c\n--y = through .b .d\n.o = --x * --y\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.PsExpr (Ast.PSelect ([ Ast.LNamed _; Ast.LNamed _ ], _)), _) :: _ -> ()
  | _ -> Alcotest.fail "expected .o = PSelect[--x --y]"

let test_join_is_select () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmap .d onto .a up to .a * .b\n"
  in
  match prog with
  | [ Ast.Crease (None, _, Some { up_to = Some (Ast.FlapLine
        (Ast.LSelect ([ Ast.SelPoint _; Ast.SelPoint _ ], _))); _ }, _) ] -> ()
  | _ -> Alcotest.fail "expected up to .a * .b (LSelect join)"
```

- [ ] **Step 2: Run to verify `test_join_is_select` fails** (`.a * .b` has no
  rule yet) and `test_meet_is_select` fails (still `PCross`).

Run: `dune runtest 2>&1 | grep -A3 -e meet_is_select -e join_is_select`
Expected: FAIL.

- [ ] **Step 3: Retarget meet + add join in the grammar.** In `lib/parser.mly`,
  set every meet arm to `PSelect` and add the join arm:

```
point_expr:
  | line_operand STAR line_operand                { PsExpr (PSelect ([ $1; $3 ], $loc)) }

point_operand:
  | point_ref { PNamed $1 }
  | LPAREN line_operand STAR line_operand RPAREN { PSelect ([ $2; $4 ], $loc) }
  | POINT_MEMBER_OPEN INSTANCE IDENT RBRACKET   { PMember ($2, $3, $loc) }
  | POINT_MEMBER_OPEN line_operand_list RBRACKET { PSelect ($2, $loc) }

line_operand:
  | crease_ref { LNamed $1 }
  | crease_ref AT_KW selector { LAt ($1, [ $3 ], $loc) }
  | crease_ref AT_KW LPAREN selector AND selector RPAREN { LAt ($1, [ $4; $6 ], $loc) }
  | LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET     { LMember ($2, $3, $loc) }
  | LINE_MEMBER_OPEN select_constraints RBRACKET { LSelect ($2, $loc) }
  | point_operand STAR point_operand { LSelect ([ SelPoint $1; SelPoint $3 ], $loc) }
  | line_operand AMP selector       { LFilter ($1, Keep $3, $loc) }
  | line_operand BACKSLASH selector { LFilter ($1, Drop $3, $loc) }
  | LBRACKET line_list RBRACKET     { LUnion ($2, $loc) }
```

  NOTE: keep the legacy `CROSS`/`POINT_OPEN`/`LINE_OPEN` arms for now (removed in
  Task 8) but retarget the two that built `PCross` to `PSelect`:
  `CROSS line_operand line_operand { PsExpr (PSelect ([$2;$3], $loc)) }` and
  `POINT_OPEN line_operand line_operand RPAREN { PSelect ([$2;$3], $loc) }` /
  its `point_expr` twin. This lets `PCross` be deleted now.

- [ ] **Step 4: Resolve the `line * line` vs `point * point` conflict.** Both
  `line_operand STAR line_operand` (meet) and `point_operand STAR point_operand`
  (join) exist. They are distinguished by the leading token: a `line_operand`
  starts with `CREASE`/`--[`/`(`/… ; a `point_operand` with `POINT`/`.[`/`(`.
  The shared `(` (grouping) is the risk.

Run: `menhir --explain lib/parser.mly 2>&1 | grep -i conflict || echo "no conflicts"`
Expected: `no conflicts`. If a shift/reduce appears around `STAR`, apply the
same guard the shipped inline meet uses — require the *point*-producing `*` in a
`point_operand` context to be parenthesized, and keep join `*` only where a
`line_operand` is expected (fold-target/`up to` slots). Document the resolution
in `.parser.conflicts` follow-up. Do NOT add `%prec` hacks without recording why.

- [ ] **Step 5: Delete `PCross`.** In `lib/ast.ml:21`, remove the `PCross` line
  from `point_operand`. Compile-driven: fix the `resolve_point` `PCross` arm
  (`lib/eval.ml:253-279`) — delete it — and the `pstr` `PCross` arm (`:137`).
  The `Point`/`Cross` remnant in `ast.ml:83` is already `PsExpr`; ensure no
  `Cross`-constructor references remain (`rg 'PCross|Ast.Cross' lib tests`).

- [ ] **Step 6: Build + run.**

Run: `dune build 2>&1 | head -30 && dune runtest 2>&1 | tail -20`
Expected: clean build (no non-exhaustive warnings), green tests.

- [ ] **Step 7: Commit.**

```bash
git add lib/ast.ml lib/parser.mly lib/eval.ml tests/test_parse.ml
git commit -m "refactor: * is sugar over Select (meet+join); retire Cross/PCross"
```

---

## Task 4: Migrate the mechanical corpus (no goldens move)

Rewrite every legacy read form that maps 1:1 to new syntax, leaving the 20
sight-lines and the 1 statement-bind for Tasks 5-7. Geometry is unchanged, so
goldens must not move.

**Files:**
- Modify: the ~28 `.bel` files with `at`/`cross`/`.(`/`#(`/edge-`--(` (see the
  baseline inventory). Do NOT touch the sight-line lines listed in Group 1/2.
- No golden changes expected.

**Per-file mechanical rules:**
- `--l at <sel>` → `--l & <sel>`
- `--l at (S1 and S2)` → `--l & S1 & S2`
- `#(…)` → `#[…]`
- `.( --x --y )` → `--x * --y` (both operands real: named creases or edge names)
- `cross --x --y` → `--x * --y`
- edge `--(.a .b)` (adjacent corners) → the prelude name `--ab`/`--bc`/`--cd`/`--da`
  (order-independent: `--(.d .c)` → `--cd`, `--(.a .d)` → `--da`).

- [ ] **Step 1: Migrate the pure-`at` collapse/fold files first** (no `--(`
  sight-lines): `collapse-all-valley`, `collapse-standing`, `collapse-kawasaki`,
  `collapse-ambiguous`, `collapse-ambiguous-over`, `collapse-midpaper`,
  `collapse-duplicate-ray`, `crease-at-flap`, `multiple-folds`, `waterbomb`,
  and the `iteration/00x` `@collapse`/`@fold` lines (`at` → `&`, `#(` → `#[`,
  edge `--(` → prelude names). Work one file, rebuild after each.

Run (after each file): `dune build 2>&1 | head`
Expected: parses.

- [ ] **Step 2: Migrate the `cross`/`.(` point constructions** where operands are
  real (named creases or edges): `complex-fold`, `parallel`, `x-midpoint`,
  `through`, `fold-top-two`, `project`, and the edge-only `.(`/`cross` lines in
  `iteration/00x` and `cube-root` (e.g. `.(--vm --(.a .b))` → `--vm * --ab`).
  Leave `cube-root:23-27` and `inline-midpoint:3` (Group 2) untouched here.

- [ ] **Step 3: Confirm every example still parses.**

Run: `dune build && for f in (fd -e bel . examples); dune exec beloch -- check $f; end 2>&1 | rg -i error || echo "all parse"`
(Adjust to the project's parse-check entrypoint; if none, a small OCaml loop over
`Beloch.parse` in a scratch test.) Expected: no errors, except the intentionally
still-legacy sight-line files if `check` also folds — those still use valid
(legacy) syntax, so they pass too.

- [ ] **Step 4: Regenerate goldens and verify ZERO geometry change.**

Run: `dune exec tools/regen.exe && git diff --stat tests/golden/`
Expected: **empty diff** (or only provenance/printer-text changes, never FOLD
geometry). If a `.fold`'s geometry changed, a rewrite changed meaning — fix the
`.bel`, not the golden.

- [ ] **Step 5: Run the golden suite.**

Run: `dune runtest 2>&1 | grep -A3 golden`
Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add examples tests/golden
git commit -m "refactor(examples): migrate at/cross/.()/#() and paper edges to & * #[] --ab"
```

---

## Task 5: Sight-line rework — Group 1 (fold-targets) → `through`

The 10 fold-target sight-lines become real creases. Goldens move; each file
needs a render check.

**Files:**
- Modify: `iteration/001.bel`, `002.bel`, `003.bel`, `004.bel`
  (`map --(.a .b) onto --(.a .m)` / `--(.b .a) onto --(.b .m)`),
  `syntax/bisect-straddle.bel` (`@map --(.a .c) onto --(.b .d) …`).
- Modify: their goldens (regenerated).

- [ ] **Step 1: Rewrite the iteration angle-bisector sources.** In each of
  `iteration/00{1,2,3,4}.bel`, the two bisector lines currently read:

```
--ba = map --(.a .b) onto --(.a .m)   ; angle bisector at a
--bb = map --(.b .a) onto --(.b .m)   ; angle bisector at b
```

  Score the corner→apex creases first, then fold onto them, and migrate the edge
  operand `--(.a .b)`→`--ab`:

```
--am = through .a .m   ; TODO(pinch): landmark — replace with pinch when shipped
--bm = through .b .m   ; TODO(pinch): landmark — replace with pinch when shipped
--ba = map --ab onto --am   ; angle bisector at a
--bb = map --ab onto --bm   ; angle bisector at b
```

  (`--(.b .a)` is the same edge `--ab`.) Keep the rest of each file as migrated
  in Task 4.

- [ ] **Step 2: Rewrite `bisect-straddle.bel`.** `@map --(.a .c) onto --(.b .d)
  toward .b moving .c` folds one diagonal onto the other — both must be creased:

```
--ac = through .a .c   ; TODO(pinch): landmark — replace with pinch when shipped
--bd = through .b .d   ; TODO(pinch): landmark — replace with pinch when shipped
@map --ac onto --bd toward .b moving .c
```

- [ ] **Step 3: Rebuild + regenerate the affected goldens only.**

Run: `dune build && dune exec tools/regen.exe && git diff --stat tests/golden/`
Expected: only the 5 affected `.fold` files change (new creases add geometry).

- [ ] **Step 4: Render-review each changed example.** For each of the 5, render
  the folded state + CP and eyeball that the base is still the intended shape
  (the added creases are the bisector-construction lines, nothing spurious). Use
  the project's `tools/fold2svg.mjs` (see memory: FOLD rendering). Note in the
  commit which goldens moved and why.

Run: `node tools/fold2svg.mjs tests/golden/iteration/001.fold /tmp/it001.svg` (or
the documented render entrypoint), inspect.

- [ ] **Step 5: Run the suite.**

Run: `dune runtest 2>&1 | tail -20`
Expected: green (goldens regenerated to match).

- [ ] **Step 6: Commit.**

```bash
git add examples tests/golden
git commit -m "refactor(examples): score Group-1 fold-target sight-lines with through (goldens move)"
```

---

## Task 6: Sight-line rework — Group 2 (point-locating) → `through` [interim]

The 10 point-locating sight-lines become full creases as an interim (see Global
Constraints; pinch later). Goldens move; `cube-root` stops matching Messer's
figure until the pinch pass.

**Files:**
- Modify: `syntax/cube-root.bel` (the thirds construction, `:23-27`),
  `syntax/inline-midpoint.bel` (`:3`), and `iteration/001.bel:19`
  (`--crease = --(.o .rm)` statement-bind).
- Modify: their goldens.

- [ ] **Step 1: Rewrite `cube-root.bel` thirds.** The four `cross --(…) --(…)`
  lines locate the thirds by crossing diagonals / corner→midpoint lines. Score
  each construction line, tag it, then meet:

```
._mb = --vm * --ab            ; (1/2, 0)   (edge meet, already migrated)
._mt = --vm * --cd            ; (1/2, 1)
--d_mb = through .d ._mb      ; TODO(pinch): landmark — replace with pinch
--ac   = through .a .c        ; TODO(pinch): landmark — replace with pinch
._pq1 = --d_mb * --ac         ; (1/3, 1/3)
--a_mt = through .a ._mt      ; TODO(pinch): landmark — replace with pinch
--db   = through .d .b        ; TODO(pinch): landmark — replace with pinch
._pq2 = --a_mt * --db         ; (1/3, 2/3)
--c_mb = through .c ._mb      ; TODO(pinch): landmark — replace with pinch
._rs1 = --c_mb * --db         ; (2/3, 1/3)   (--db reused)
--b_mt = through .b ._mt      ; TODO(pinch): landmark — replace with pinch
._rs2 = --b_mt * --ac         ; (2/3, 2/3)   (--ac reused)
```

  Reuse a scored crease where the same line recurs (`--ac`, `--db`). Keep
  `--pq = through ._pq1 ._pq2` and `--rs = through ._rs1 ._rs2` as-is. The final
  `@map .c onto --ab and .s onto --pq` is unchanged.

- [ ] **Step 2: Rewrite `inline-midpoint.bel`.** `map .a onto .( --(.a .c)
  --(.b .d) )` finds the centre by crossing the two diagonals, then folds `.a`
  onto it:

```
--ac = through .a .c   ; TODO(pinch): landmark — replace with pinch when shipped
--bd = through .b .d   ; TODO(pinch): landmark — replace with pinch when shipped
map .a onto --ac * --bd
```

  (`--ac * --bd` is the centre point; `map point onto point` is axiom 2.)

- [ ] **Step 3: Rewrite the `iteration/001.bel:19` statement-bind.**
  `--crease = --(.o .rm)` constructs a line through the incenter and a rim point
  — it is a genuine construction, so it is just the `through` keyword:

```
--crease = through .o .rm
```

- [ ] **Step 4: Rebuild + regenerate goldens.**

Run: `dune build && dune exec tools/regen.exe && git diff --stat tests/golden/`
Expected: `cube-root`, `inline-midpoint`, `iteration/001` goldens change.

- [ ] **Step 5: Render-review.** Render `cube-root` folded + CP; confirm the
  cube-root landing ratio (AC/CB = ∛2) is preserved — the *fold* is unchanged,
  only extra reference creases were added. The `.s`/thirds landmarks must still
  sit at (1/3,·)/(2/3,·). Note in the commit that cube-root's CP now carries
  interim reference creases and no longer byte-matches Messer Fig. 2 (pinch pass
  will restore it).

- [ ] **Step 6: Run the suite.**

Run: `dune runtest 2>&1 | tail -20`
Expected: green.

- [ ] **Step 7: Commit.**

```bash
git add examples tests/golden
git commit -m "refactor(examples): score Group-2 point-locating sight-lines with through (interim; pinch TODO)"
```

---

## Task 7: Remove legacy syntax + instance member access

Compile-driven deletion. After this, reads are only `* & \ #[] [] --[] .[]` and
the write is `through`.

**Files:**
- Modify: `syntax/def-diagonals.bel` (the only member-access user) → `export`.
- Modify: `lib/lexer.ml` (drop `at`/`cross`/`--(`/`.(`/`#(`/`--[`/`.[` arms).
- Modify: `lib/parser.mly` (drop the legacy tokens + productions).
- Modify: `lib/ast.ml` (drop `LThrough`/`LMember`/`LAt`/`PMember`).
- Modify: `lib/eval.ml` (drop the corresponding arms + printers).
- Modify: `tests/test_parse.ml` (drop/rewrite legacy-syntax tests).

- [ ] **Step 1: Migrate `def-diagonals.bel` off member access.** It reads
  `.m = cross --[$d1 d] --[$d2 d]` (the `d` member line of two diagonal
  instances). Rewrite to `export` the needed members into the caller scope, then
  meet by name. Read the file's `def`/`apply` structure first; the shape is:

```
export { --d as --d1line } $d1
export { --d as --d2line } $d2
.m = --d1line * --d2line
```

  Match the file's actual instance names + the `export` syntax in
  `parser.mly:54-55`. Rebuild to confirm it parses and folds.

- [ ] **Step 2: Remove lexer arms.** In `lib/lexer.ml`, delete the arms for
  `"at" -> AT_KW` (`:17`), `"cross" -> CROSS` (`:27`), `"--(" -> LINE_OPEN`
  (`:48`), `".(" -> POINT_OPEN` (`:49`), `"#(" -> FLAP_OPEN` (`:50`),
  `"--[" -> LINE_MEMBER_OPEN` (`:52`), `".[" -> POINT_MEMBER_OPEN` (`:53`). Add
  the freed brackets back as the select openers — but they are multi-char
  (`--[`, `.[`); re-add them mapping to NEW openers `LINE_SELECT_OPEN` /
  `POINT_SELECT_OPEN`, OR (simpler) keep the token names `LINE_MEMBER_OPEN`/
  `POINT_MEMBER_OPEN` and only delete the member-access *grammar* production. The
  latter is less churn: keep `:52-53` lexer arms, keep the token, remove only the
  `LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET` productions. Prefer the rename for
  clarity if cheap; otherwise keep the token name and just drop the member rule.

- [ ] **Step 3: Remove parser tokens + productions.** In `lib/parser.mly`: drop
  `AT_KW`, `CROSS`, `LINE_OPEN`, `POINT_OPEN`, `FLAP_OPEN` from `%token` (`:14`);
  delete the productions: `CREASE EQ LINE_OPEN …` (`:45`), `CROSS …`/`POINT_OPEN
  …` in `point_expr` (`:139-140`), `POINT_OPEN …` in `point_operand` (`:145`),
  `LINE_OPEN …` in `line_operand` (`:154`), the two `AT_KW` filter arms
  (`:155-156`), `LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET` (`:157`), the
  `POINT_MEMBER_OPEN INSTANCE IDENT RBRACKET` arm (`:147`), the `LINE_OPEN …`
  arm in `selector` (`:179`), `FLAP_OPEN …` in `flap_operand` (`:183`), and the
  `LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET` arm in `bundle_expr` (`:171`).

- [ ] **Step 4: Remove AST variants.** In `lib/ast.ml`: delete `LThrough`,
  `LMember`, `LAt` from `line_operand`, `PMember` from `point_operand`, and fix
  the `selector` doc comment (`:41`). `filter_elt`/`LFilter`/`LUnion`/`LSelect`
  stay.

- [ ] **Step 5: Fix eval fallout (compile-driven).** The OCaml exhaustiveness
  checker flags every site. Delete: the `LThrough`/`LMember`/`LAt` arms in
  `resolve_line` (`:293,303,310`), `resolve_paper_line` (`:333,342,349`), the
  `PMember` arm in `resolve_point` (`:280`), the `LThrough`/`LMember`/`LAt` arms
  in `bundle_segments` (`:429,443,446`) and `span_of_line` (`:414-416`), the
  `LMember`/`LThrough`/`LAt` arms in `ax5_material` (`:930,941,954`) and the
  Apply arg path (`:1205,1213`), and the `pstr` `PMember` (`:138`) / `lstr`
  `LThrough`/`LMember`/`LAt` (`:142-144`) printer arms. In the Apply `LNamed |
  … -> Frozen (resolve_line lo)` fallback (`:1213`), the remaining non-`LNamed`
  cases are `LSelect`/`LFilter`/`LUnion` — they still `Frozen (resolve_line lo)`,
  so update the pattern list to those constructors.

Run: `dune build 2>&1 | head -40`
Expected: after edits, builds clean — no non-exhaustive-match warnings.

- [ ] **Step 6: Delete/rewrite stale tests.** In `tests/test_parse.ml`, remove or
  rewrite any test asserting `LThrough`/`LAt`/`PCross`/`PMember`/`LMember` or
  using `at`/`cross`/`.(`/`--(`/`#(` source. Keep the meet/join/select/filter
  tests.

- [ ] **Step 7: Full suite + golden stability.**

Run: `dune runtest 2>&1 | tail -20`
Expected: all green. Goldens unchanged from Tasks 4-6 (removal is syntax-only).

- [ ] **Step 8: Commit.**

```bash
git add lib tests examples/syntax/def-diagonals.bel
git commit -m "refactor: remove at/cross/--(/.(/#( + instance member access — new notation only"
```

---

## Task 8: Spec sync + guard tests

**Files:**
- Modify: `spec/SPECIFICATION.md` (selector section; point/line operands).
- Test: `tests/test_parse.ml`.

- [ ] **Step 1: Add a grouping/precedence guard test.** Prove `()` is pure
  grouping and `&` binds tighter than `*`:

```ocaml
let test_group_precedence () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l = through .a .b\n--s = through .c .d\n\
       .o = (--l & .p) * --s\n"
  in
  match List.rev prog with
  | Ast.Point ("o", Ast.PsExpr (Ast.PSelect
      ([ Ast.LFilter _; Ast.LNamed _ ], _)), _) :: _ -> ()
  | _ -> Alcotest.fail "expected PSelect[LFilter, LNamed]"
```

- [ ] **Step 2: Add a no-sight-line guard test** (if not already covered by
  `test_select_no_sightline` from Task 2 — keep one canonical version).

Run: `dune runtest 2>&1 | grep -A3 group_precedence`
Expected: PASS.

- [ ] **Step 3: Update `spec/SPECIFICATION.md`.** In the selector section (search
  `at ` / `#(` / `cross` / `--(`): replace the surface grammar with
  `--[c+] .[l+] #[c+] * & \ []`; state the state-change law (one paragraph, link
  the design doc); note `--[]`/`*`-join select existing creases/edges and error
  on no-match (no sight-lines), meet `*`/`.[]` is a read, and `through` is the
  only line-construction write. Document the prelude edges `--ab --bc --cd --da`.
  Add a one-line note that point-locating landmarks are currently full `through`
  creases pending `pinch` (link the interim decision).

- [ ] **Step 4: Commit.**

```bash
git add spec/SPECIFICATION.md tests/test_parse.ml
git commit -m "docs(spec): selectors — --[] .[] join/meet as reads, through as the write"
```

---

## Self-review checklist (run after writing, before executing)

- **Spec coverage:** `--[c+]` (T2), `.[l+]` (T2), prelude edges (T1), `*` meet+join
  sugar (T3), retire Cross/PCross (T3), migrate reads (T4), sight-lines →
  `through` — Group 1 (T5) + Group 2 interim (T6), remove `at`/`cross`/`--(`/`.(`/
  `#(` + member access (T7), spec + guards (T8). Every spec §maps to a task. ✅
- **Interim decision honored:** all 20 sight-lines scored as full creases; each
  tagged `TODO(pinch)`; goldens regenerated + render-reviewed (T5/T6). ✅
- **Placeholder scan:** the only judgement-call steps (T2 Step 7 `all_crease_ids`
  fallback, T3 Step 4 conflict resolution, T7 Step 1 export shape, error-payload
  literal in tests) each name the exact file to read and the concrete fallback —
  no bare TODO/TBD. ✅
- **Type consistency:** `LSelect of selector list * span`, `PSelect of
  line_operand list * span`, `point_expr = PsExpr of point_operand`,
  `Edge of string * string`, `select_line : selector list -> span -> Geom.line`,
  `select_point : line_operand list -> span -> Geom.point` — names identical
  across T1-T8. ✅
</content>
