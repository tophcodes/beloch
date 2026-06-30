# Beloch — Inline anonymous operands `--(.a .b)` / `.(--a --b)` Design

- **Date:** 2026-06-30
- **Status:** Design — approved in brainstorming, pending implementation plan
- **Context:** general ergonomics. Today every constructed line or point used as an operand must first be bound to a name (`--e: through .b .c` then use `--e`; `.m: cross --d1 --d2` then use `.m`). This adds inline anonymous forms so a construction can be written directly where it's used. (Originally surfaced as a flip-axis convenience; `flip` is now bare, so this is a standalone operand-level feature.)

## 1. The feature

Two inline construction forms, usable **anywhere a `--name` / `.name` operand is expected**:

- **`--(.a .b)`** — the line through two points (an inline axiom 1).
- **`.(--a --b)`** — the point where two creases meet (an inline `cross`).

```
@map .(--d1 --d2) onto .c moving .(--d1 --d2)   ; fold a constructed point onto .c
perp --(.a .b) through .c                         ; perpendicular to an inline line
cross --(.a .c) --(.b .d)                         ; intersection of two inline lines
```

Brainstorm decisions:
- **Both** lines and points (symmetric — one mechanism).
- **Full nesting**, via mutually-recursive operand grammar: `--( .(--a --b) .c )` is the line through (the intersection of `--a`,`--b`) and `.c`.
- **Coexist** with `cross` / `through`: the keyword forms stay for named bindings and as the axiom/construction verbs; the bracket forms are **operand sugar at operand positions only** — they are *not* a binding right-hand side. So `--m: through .a .b` and `.x: cross --c --d` are unchanged; you may now write inline operands *inside* them (`through .(--a --b) .c`), but not `--m: --(.a .b)` (use `through`). Fully backward-compatible.

`flip` is bare and takes no operand — unaffected.

## 2. Grammar

Replace the leaf operand nonterminals at operand positions with mutually-recursive ones:

```
point_operand := POINT_NAME
              | ".(" line_operand line_operand ")"      ; inline cross
line_operand  := CREASE_NAME
              | "--(" point_operand point_operand ")"   ; inline through
```

These permeate every operand site:

```
axiom      := "through" point_operand point_operand
            | "map" point_operand "onto" point_operand
            | "perp" line_operand "through" point_operand
            | "map" line_operand "onto" line_operand [ "toward" point_operand ]
point_expr := "cross" line_operand line_operand          ; the .name: binding RHS
fold_spec  := … [ "moving" point_operand ] [ "mountain" ]
```

The statement **binding** heads are unchanged: `[ CREASE_NAME ":" ] axiom … | POINT_NAME ":" point_expr | "flip"`. Brackets appear only as operands, never as the binding RHS.

**Lexer** (`lib/lexer.ml`): three new tokens — `"--("` → `LINE_OPEN`, `".("` → `POINT_OPEN`, `')'` → `RPAREN`. `--(` / `.(` are unambiguous against the existing `--`*id* / `.`*id* rules (the char after `--`/`.` is `(`, not an id char).

## 3. AST (`lib/ast.ml`)

Introduce recursive operand types; keep the existing leaf records `point_ref = {name; span}` and `crease_ref = {cname; cspan}` as the named leaves:

```ocaml
type point_operand =
  | PNamed of point_ref
  | PCross of line_operand * line_operand * Error.span
and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span
```

Rewire the operand fields: `axiom` constructors carry `point_operand`/`line_operand` instead of `point_ref`/`crease_ref`; `point_expr = Cross of line_operand * line_operand`; `fold_spec.moving : point_operand option`. (A plain `.a` parses to `PNamed {name="a"}`, a plain `--l` to `LNamed {cname="l"}`, so existing programs map straight through — only the AST wrapper changes.)

## 4. Evaluation (`lib/eval.ml`)

Mutually-recursive resolution against the current folded state, replacing the flat `lookup_point`/`lookup_crease` calls at operand sites (the leaf cases still call them):

- `resolve_point : point_operand -> Geom.point` (a **paper** coordinate / material point):
  - `PNamed pr` → `lookup_point pr` (corner or previously-bound point).
  - `PCross (l1, l2, span)` → `resolve_line l1`, `resolve_line l2` → table-space intersection → the topmost layer's paper preimage (`paper_preimages`, Q2-B), exactly the `cross` statement's logic. Errors: parallel lines; off the paper.
- `resolve_line : line_operand -> Geom.line` (a **table** line):
  - `LNamed cr` → `lookup_crease cr` (the named table-axis snapshot).
  - `LThrough (p1, p2, span)` → current table positions of `resolve_point p1`/`p2` (via `table_position`) → `Geom.line_through`. Error: the two points are at the same place.

Axiom evaluation uses `table_position (resolve_point …)` where it currently uses `table_of pr`, and `resolve_line …` where it uses `lookup_crease`. Nesting resolves bottom-up; everything stays exact (`Num`).

## 5. Errors

No new error *kinds* — inline forms surface the existing ones during resolution: an inline `--(.a .a)` → "at the same place"; an inline `.(--p --q)` with parallel creases → "no intersection", or off the paper → "off the paper". Spans point at the inline sub-expression.

## 6. Scope

**In:** `--(.a .b)` and `.(--a --b)` as operands at every operand position, with full nesting; coexisting with `cross`/`through`; recursive eval resolution.

**Out:** brackets as a binding RHS (`--m: --(…)` / `.x: .(…)`) — use the keyword forms; other inline constructions (only through-line and cross-point are inline-able — `perp`/`map`-bisector inline forms are not, they stay named); `flip` is unaffected.

## 7. Testing

- Parse: `map .(--a --b) onto .c` → the `PCross` operand; `perp --(.a .b) through .c` → `LThrough` operand; nested `--( .(--a --b) .c )` parses.
- Eval equivalence: a program using inline operands produces byte-identical FOLD to the same program written with explicit named bindings (e.g. `.m: cross --d1 --d2 / map .m onto .c` vs `map .(--d1 --d2) onto .c`).
- Inline errors: `--(.a .a)` → same-place; inline cross off-paper / parallel.
- Backward compatibility: all existing programs/examples parse and emit unchanged (a bare `.a`/`--l` is just `PNamed`/`LNamed`).
- Migrate one example to inline form (e.g. `x-midpoint.bel`) as a worked demonstration, keeping its output identical.

## 8. Follow-ups

If wanted later: inline forms for the other constructions (`perp`, bisector); brackets as a binding RHS (probably never — redundant). Non-flat angles, maneuvers, etc. remain on the main roadmap.
