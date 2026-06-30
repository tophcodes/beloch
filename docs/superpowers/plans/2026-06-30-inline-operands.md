# Inline Anonymous Operands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow inline anonymous constructions at operand positions — `--(.a .b)` (line through two points) and `.(--a --b)` (point at two creases' intersection) — with full nesting, coexisting with `cross`/`through`.

**Architecture:** Operand positions become mutually-recursive `point_operand`/`line_operand` (a named leaf or an inline construction). Task 1 introduces the recursive AST + resolvers but the parser still only produces the named leaves (behaviour identical; the resolvers are already exercised by the `cross` statement, which becomes an inline-point internally). Task 2 adds the `--(`/`.(`/`)` lexer tokens and the inline grammar productions, making the brackets reachable.

**Tech Stack:** OCaml, dune, sedlex, menhir, `Num`/`Fold_state`, alcotest.

Design: `docs/superpowers/specs/2026-06-30-inline-operands-design.md`.

## Global Constraints

- Build `dune build`; test `dune test` (from repo root). Warnings fatal in dev — clean builds.
- ocamlformat-clean (0.29.0, default) — `dune fmt` before each commit.
- All geometry exact via `Num` — no floating point.
- Every lexer token is declared in `lib/parser.mly`.
- Backward compatible: a plain `.a`/`--l` parses to `PNamed`/`LNamed`; existing programs evaluate to byte-identical FOLD.
- Commits: Conventional Commits; end the body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

Existing leaf types kept: `Ast.point_ref = { name : string; span : Error.span }`, `Ast.crease_ref = { cname : string; cspan : Error.span }`. `Fold_state.{table_position, paper_preimages}`, `Geom.{intersection, line_through, point_equal, side_of_line, perpendicular_through, perpendicular_bisector, angle_bisectors, parallel_midline}`.

---

### Task 1: Recursive operand AST + resolvers (named leaves only)

Make operands recursive (`point_operand`/`line_operand`) and resolve them recursively in `eval`, but keep the parser producing only the named leaves. Behaviour is unchanged; the `cross` statement is re-expressed through the new point resolver.

**Files:**
- Modify: `lib/ast.ml`, `lib/parser.mly`, `lib/eval.ml`
- Test: `tests/test_beloch.ml` (migrate AST patterns)

**Interfaces:**
- Produces (AST):
  ```ocaml
  type point_operand = PNamed of point_ref | PCross of line_operand * line_operand * Error.span
  and  line_operand  = LNamed of crease_ref | LThrough of point_operand * point_operand * Error.span
  ```
  with `axiom` / `point_expr` / `fold_spec` carrying operands (see Step 1).

- [ ] **Step 1: Rewrite `lib/ast.ml`**

```ocaml
(** Abstract syntax for Beloch. Spans point into the source for diagnostics. *)

type point_ref = { name : string; span : Error.span }
type crease_ref = { cname : string; cspan : Error.span }

(* Operands are mutually recursive: a named leaf, or an inline construction.
   PCross = inline `cross` (point at two creases); LThrough = inline `through`
   (line through two points). A plain `.a` is PNamed; a plain `--l` is LNamed. *)
type point_operand =
  | PNamed of point_ref
  | PCross of line_operand * line_operand * Error.span

and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span

type axiom =
  | Through of point_operand * point_operand (* axiom 1 *)
  | MapPoints of point_operand * point_operand (* axiom 2 *)
  | Perp of point_operand * line_operand (* axiom 3: through .p, perp to --l *)
  | MapLines of line_operand * line_operand * point_operand option (* axiom 5 *)

type direction = Valley | Mountain
type fold_spec = { moving : point_operand option; direction : direction }
type point_expr = Cross of line_operand * line_operand (* the `.name:` binding RHS *)

type stmt =
  | Crease of string option * axiom * fold_spec option * Error.span
  | Point of string * point_expr * Error.span
  | Flip of Error.span

type program = stmt list
```

- [ ] **Step 2: Rewrite the operand rules in `lib/parser.mly`**

Replace the `axiom`, `point_expr`, `fold_clauses` rules and add the operand nonterminals (keep `point_ref`/`crease_ref` leaf rules as they are):

```ocaml
axiom:
  | THROUGH point_operand point_operand       { Through ($2, $3) }
  | MAP point_operand ONTO point_operand      { MapPoints ($2, $4) }
  | PERP line_operand THROUGH point_operand   { Perp ($4, $2) }
  | MAP line_operand ONTO line_operand                  { MapLines ($2, $4, None) }
  | MAP line_operand ONTO line_operand TOWARD point_operand { MapLines ($2, $4, Some $6) }

fold_clauses:
  |                               { { moving = None; direction = Valley } }
  | MOVING point_operand          { { moving = Some $2; direction = Valley } }
  | MOUNTAIN                      { { moving = None; direction = Mountain } }
  | MOVING point_operand MOUNTAIN { { moving = Some $2; direction = Mountain } }

point_expr:
  | CROSS line_operand line_operand { Cross ($2, $3) }

point_operand:
  | point_ref { PNamed $1 }

line_operand:
  | crease_ref { LNamed $1 }
```

(The `MAP point_operand …` / `MAP line_operand …` ambiguity is resolved by the first token: `point_operand` begins with `POINT`, `line_operand` with `CREASE` — disjoint, so LR(1) is conflict-free. `dune build` will report a conflict if not.)

- [ ] **Step 3: Rewrite the resolvers + `axis_of` in `lib/eval.ml`**

Inside `eval_folded`, after `lookup_crease` (currently lines ~31–37) and **before** `axis_of`, add the recursive source-printers and resolvers, and a new `table_of` over operands:

```ocaml
  (* render an operand back to source text for provenance + error messages *)
  let rec pstr (po : Ast.point_operand) : string =
    match po with
    | Ast.PNamed pr -> "." ^ pr.Ast.name
    | Ast.PCross (l1, l2, _) -> Printf.sprintf ".(%s %s)" (lstr l1) (lstr l2)
  and lstr (lo : Ast.line_operand) : string =
    match lo with
    | Ast.LNamed cr -> "--" ^ cr.Ast.cname
    | Ast.LThrough (p1, p2, _) -> Printf.sprintf "--(%s %s)" (pstr p1) (pstr p2)
  in
  (* resolve a point operand to its material PAPER coordinate, a line operand to
     its TABLE-space line; mutually recursive for nesting. *)
  let rec resolve_point (po : Ast.point_operand) : Geom.point =
    match po with
    | Ast.PNamed pr -> lookup_point pr
    | Ast.PCross (l1, l2, span) -> (
        let a = resolve_line l1 and b = resolve_line l2 in
        match Geom.intersection a b with
        | None -> Error.fail span "creases are parallel; no intersection"
        | Some tp -> (
            match Fold_state.paper_preimages !state tp with
            | [] ->
                Error.fail span (Printf.sprintf "%s is off the paper" (pstr po))
            | ps -> List.nth ps (List.length ps - 1)))
  and resolve_line (lo : Ast.line_operand) : Geom.line =
    match lo with
    | Ast.LNamed cr -> lookup_crease cr
    | Ast.LThrough (p1, p2, span) ->
        let pp = Fold_state.table_position !state (resolve_point p1)
        and qq = Fold_state.table_position !state (resolve_point p2) in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf
               "%s and %s are at the same place, so there is no line through them"
               (pstr p1) (pstr p2));
        Geom.line_through pp qq
  in
  let table_of (po : Ast.point_operand) : Geom.point =
    Fold_state.table_position !state (resolve_point po)
  in
```

Then **replace the whole `axis_of` function** with the operand version:

```ocaml
  let axis_of (span : Error.span) (ax : Ast.axiom) :
      Geom.line * string * string list =
    match ax with
    | Ast.Through (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf
               "%s and %s are at the same place, so there is no line through them"
               (pstr p) (pstr q));
        (Geom.line_through pp qq, "axiom1", [ pstr p; pstr q ])
    | Ast.MapPoints (p, q) ->
        let pp = table_of p and qq = table_of q in
        if Geom.point_equal pp qq then
          Error.fail span
            (Printf.sprintf "%s and %s are already at the same place" (pstr p)
               (pstr q));
        (Geom.perpendicular_bisector pp qq, "axiom2", [ pstr p; pstr q ])
    | Ast.Perp (p, l) ->
        ( Geom.perpendicular_through (resolve_line l) (table_of p),
          "axiom3",
          [ pstr p; lstr l ] )
    | Ast.MapLines (l1, l2, p_opt) -> (
        let la = resolve_line l1 and lb = resolve_line l2 in
        let base = [ lstr l1; lstr l2 ] in
        let eval_at (l : Geom.line) (pt : Geom.point) : Num.t =
          Num.sub
            (Num.add (Num.mul l.Geom.a pt.Geom.x) (Num.mul l.Geom.b pt.Geom.y))
            l.Geom.c
        in
        match Geom.angle_bisectors la lb with
        | None ->
            let k =
              if Num.sign la.Geom.a <> 0 then Num.div lb.Geom.a la.Geom.a
              else Num.div lb.Geom.b la.Geom.b
            in
            if Num.equal lb.Geom.c (Num.mul k la.Geom.c) then
              Error.fail span "lines are identical";
            (Geom.parallel_midline la lb, "axiom5", base)
        | Some (bis_eq, bis_opp) -> (
            match p_opt with
            | None -> Error.fail span "bisector is ambiguous; add `toward .p`"
            | Some po ->
                let p = table_of po in
                let s1 = Num.sign (eval_at la p)
                and s2 = Num.sign (eval_at lb p) in
                if s1 = 0 || s2 = 0 then
                  Error.fail span
                    "reference point on a fold line; bisector ambiguous";
                ( (if s1 = s2 then bis_eq else bis_opp),
                  "axiom5",
                  base @ [ pstr po ] )))
  in
```

In the statement loop, **the `moving` default arm** still special-cases `MapPoints`; update its pattern to the operand form and use `table_of`:

```ocaml
                | None -> (
                    match ax with
                    | Ast.MapPoints (p, _) ->
                        let s = Geom.side_of_line axis (table_of p) in
                        if s = 0 then
                          Error.fail span
                            "the moving point lies on the fold axis";
                        s
                    | _ ->
                        Error.fail span
                          "this fold needs `moving .p` to choose the side")
```

(The `Some pr -> … table_of pr …` moving arm already calls `table_of`; since `table_of` now takes a `point_operand` and `fs.moving` is a `point_operand option`, it type-checks unchanged.)

Finally, **replace the `cross` statement arm** to go through `resolve_point` (it is an inline point):

```ocaml
      | Ast.Point (n, Ast.Cross (l1, l2), span) ->
          Hashtbl.replace points n (resolve_point (Ast.PCross (l1, l2, span)))
```

- [ ] **Step 4: Migrate the AST-matching parse tests in `tests/test_beloch.ml`**

`test_parse_perp` — the `Perp` operands are now wrapped:

```ocaml
   Ast.Crease (None, Ast.Perp ({ name = "b"; _ }, { cname = "d"; _ }), _, _);
```
becomes
```ocaml
   Ast.Crease
     ( None,
       Ast.Perp (Ast.PNamed { name = "b"; _ }, Ast.LNamed { cname = "d"; _ }),
       _, _ );
```

`test_parse_bisect` — the `MapLines` operands:
```ocaml
      Ast.MapLines
        ({ cname = "v"; _ }, { cname = "h"; _ }, Some { name = "a"; _ }),
```
becomes
```ocaml
      Ast.MapLines
        ( Ast.LNamed { cname = "v"; _ },
          Ast.LNamed { cname = "h"; _ },
          Some (Ast.PNamed { name = "a"; _ }) ),
```

`test_parse_fold_action` — the `moving` operand:
```ocaml
      Some { moving = Some { name = "a"; _ }; direction = Ast.Mountain },
```
becomes
```ocaml
      Some { moving = Some (Ast.PNamed { name = "a"; _ }); direction = Ast.Mountain },
```

(`test_parse_named_and_anon`, `test_parse_fold_valley_default`, `test_parse_precrease_no_foldspec` match `Ast.MapPoints _` / `moving = None` and need no change.)

- [ ] **Step 5: Format, build, run the suite**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: build clean (no menhir conflict, no warnings); all tests PASS — behaviour is unchanged (every program still parses to named operands and evaluates identically). If `dune build` reports a shift/reduce conflict, the operand FIRST sets overlap — recheck Step 2.

- [ ] **Step 6: Commit**

```bash
git add lib/ast.ml lib/parser.mly lib/eval.ml tests/test_beloch.ml
git commit -m "refactor(ast): recursive point/line operands + resolvers (named leaves only)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Inline bracket syntax `--(.a .b)` / `.(--a --b)`

Add the lexer tokens and the inline grammar productions so the brackets are reachable; the eval resolvers from Task 1 already handle `PCross`/`LThrough`.

**Files:**
- Modify: `lib/lexer.ml`, `lib/parser.mly`
- Create: `examples/inline-midpoint.bel`
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Consumes: the `point_operand`/`line_operand` AST + resolvers (Task 1).
- Produces: `--(point point)` and `.(line line)` parse to `LThrough`/`PCross` and evaluate via the Task-1 resolvers.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_beloch.ml`:

```ocaml
let test_parse_inline_line () =
  match
    Beloch.parse ~filename:"t.bel" "paper square\nperp --(.a .b) through .c\n"
  with
  | [ Ast.Crease (None, Ast.Perp (Ast.PNamed { name = "c"; _ }, Ast.LThrough _), _, _) ] -> ()
  | _ -> Alcotest.fail "expected an inline-line Perp operand"

let test_parse_inline_point_nested () =
  (* nested: a line through an inline cross-point and a named point *)
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d1: through .a .c\n--d2: through .b .d\nperp --( .(--d1 --d2) .a ) through .b\n"
  with
  | [ _; _; Ast.Crease (None, Ast.Perp (_, Ast.LThrough (Ast.PCross _, Ast.PNamed _, _)), _, _) ] -> ()
  | _ -> Alcotest.fail "expected a nested inline operand"

let test_e2e_inline_equiv () =
  (* inline operands produce the same FOLD as the named-binding equivalent *)
  let named =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\n--d1: through .a .c\n--d2: through .b .d\n.m: cross --d1 --d2\nmap .a onto .m\n"
  in
  let inline =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\n--d1: through .a .c\n--d2: through .b .d\nmap .a onto .(--d1 --d2)\n"
  in
  Alcotest.(check bool) "inline cross-point matches the named binding" true
    (Yojson.Safe.equal named inline)

let test_e2e_inline_error () =
  (* an inline line through one repeated point has no direction *)
  expect_error "same place" (fun () ->
      Beloch.fold_string ~filename:"t.bel"
        "paper square\nperp --(.a .a) through .b\n")
```

Register in the `"parse"` group:

```ocaml
          Alcotest.test_case "inline line operand" `Quick test_parse_inline_line;
          Alcotest.test_case "nested inline operand" `Quick test_parse_inline_point_nested;
```

and in the `"e2e"` group:

```ocaml
          Alcotest.test_case "inline equals named" `Quick test_e2e_inline_equiv;
          Alcotest.test_case "inline off-paper errors" `Quick test_e2e_inline_error;
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `--(` / `.(` are not lexed (unexpected character) / no grammar rule.

- [ ] **Step 3: Add lexer tokens in `lib/lexer.ml`**

After the `| '@' -> AT` line (before the `"--", id` rule), add:

```ocaml
  | "--(" -> LINE_OPEN
  | ".(" -> POINT_OPEN
  | ')' -> RPAREN
```

- [ ] **Step 4: Add parser tokens + inline productions in `lib/parser.mly`**

Add the tokens to the `%token` line:

```ocaml
%token PAPER SQUARE THROUGH MAP ONTO CROSS COLON EOF PERP TOWARD AT MOVING MOUNTAIN FLIP
```
becomes
```ocaml
%token PAPER SQUARE THROUGH MAP ONTO CROSS COLON EOF PERP TOWARD AT MOVING MOUNTAIN FLIP LINE_OPEN POINT_OPEN RPAREN
```

Extend the operand nonterminals with the inline alternatives:

```ocaml
point_operand:
  | point_ref { PNamed $1 }
  | POINT_OPEN line_operand line_operand RPAREN { PCross ($2, $3, $loc) }

line_operand:
  | crease_ref { LNamed $1 }
  | LINE_OPEN point_operand point_operand RPAREN { LThrough ($2, $3, $loc) }
```

- [ ] **Step 5: Create `examples/inline-midpoint.bel`**

```
; status: works — inline line + cross: fold .a onto the centre, no named bindings
paper square
map .a onto .( --(.a .c) --(.b .d) )
```

- [ ] **Step 6: Format, build, run the suite**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: all tests PASS (inline parse + nested + equivalence + off-paper error), build clean.

- [ ] **Step 7: Commit**

```bash
git add lib/lexer.ml lib/parser.mly examples/inline-midpoint.bel tests/test_beloch.ml
git commit -m "feat(syntax): inline anonymous operands --(.a .b) / .(--a --b)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage** (against the inline-operands design):
- Recursive `point_operand`/`line_operand`, both lines and points → Task 1 AST.
- Full nesting → Task 2 grammar (mutually-recursive nonterminals); `test_parse_inline_point_nested` exercises it.
- Coexist with `cross`/`through` (keywords stay; brackets are operand-only) → `point_expr`/`axiom` keep their keywords, operands accept brackets; `cross` statement re-uses `resolve_point`.
- Recursive eval resolution (point→paper, line→table, cross→topmost, through→current positions) → Task 1 resolvers (exercised in Task 1 via the `cross` statement; via brackets in Task 2).
- Backward compatibility → Task 1 keeps named-only parsing; `test_e2e_inline_equiv` proves inline ≡ named output.
- Errors surface existing kinds with operand source strings → `pstr`/`lstr`; `test_e2e_inline_error`.

**Placeholder scan:** none — full code in every step.

**Type consistency:** `point_operand`/`line_operand` (`PNamed`/`PCross`/`LNamed`/`LThrough`) defined in Task 1 Step 1; used by the parser (Task 1 named, Task 2 inline), the resolvers, and the migrated/added tests. `axis_of` returns `Geom.line * string * string list` unchanged. `table_of : point_operand -> Geom.point`, `resolve_line : line_operand -> Geom.line`, `resolve_point : point_operand -> Geom.point` consistent across eval. The `cross` statement and `PCross` share `resolve_point`.
