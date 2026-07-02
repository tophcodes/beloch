# Def/Apply/Export/Step Implementation Plan (revised, per #29)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the revised step/macro design per `docs/superpowers/specs/2026-07-02-step-macros-design.md` — `=` bindings, shorthand RHS, `_`-temps, `def` (deferred, closed scope), `apply` (only execution form, retained instances), qualified access `.[$i m]`/`--[$i m]`, `export` (read-only, `!`/`as` validated), `step` panel markers, uniform no-silent-rebinding (#24).

**Architecture:** Reuse three commits from the abandoned `worktree-feat+step-macros` branch (syntax `:`→`=`, shorthand RHS, scope-stack refactor), then build the new model on top: a global def table (bodies never evaluated at definition), `apply` swaps the scope stack for a fresh closed scope and harvests non-temp bindings into a retained instance, `export` copies instance members with shadow validation, `step` markers thread a panel id through crease provenance into FOLD. The old branch's later commits (`ec95148` shadow validation, `633ea45` apply mechanics) are a quarry: read them with `git show`, copy what fits, never cherry-pick them.

**Tech Stack:** OCaml, Menhir (LALR), sedlex, Alcotest, Dune. Build: `dune build`. Test: `dune test`.

**Grammar reference:** `scratch/specparse/parser.mly` (gitignored, in the main checkout) is a conflict-free parse-only prototype of the full grammar; `scratch/specparse/examples/*.bel` are the 10 spec examples. Mirror its productions when extending `lib/parser.mly`.

## Global Constraints

- No new opam/library dependencies.
- No floating point anywhere.
- Identifiers are `[a-zA-Z0-9_]+` — never add `-` to `id_char`.
- All 7 axioms work after every task — `dune test` green before each commit.
- Conventional commits.
- Error messages follow existing style: lowercase, concrete, name the offending source text (see existing messages in `lib/eval.ml`).
- Every new eval error gets a test via the existing `expect_error` helper.

---

## File map

| File | Change |
|------|--------|
| `lib/lexer.ml` | Tokens: `DEF APPLY EXPORT STEP AS BANG LBRACE RBRACE LPAREN RBRACKET POINT_MEMBER_OPEN LINE_MEMBER_OPEN INSTANCE IDENT` (`EQ` arrives via cherry-pick) |
| `lib/parser.mly` | `def`/`apply`/`export`/`step` productions, member operands, body restriction |
| `lib/ast.ml` | `param`, `arg`, `export_entry`; `PMember`/`LMember` operands; `Def`/`Apply`/`Export`/`StepMark` stmts |
| `lib/eval.ml` | Scope-stack ctx (cherry-picked) + dup-binding errors, temps, def table, apply/instances, qualified access, export, panels |
| `lib/state.ml` | `provenance` gains `step : string option` |
| `lib/fold_emit.ml` | Emit `"step"` in per-edge provenance |
| `tests/test_parse.ml`, `tests/test_eval.ml`, `tests/test_e2e.ml` | New tests per task |
| `examples/*.bel` | `:`→`=` via cherry-pick; cube-root restructured; new def example |
| `README.md`, `spec/SPECIFICATION.md` | Syntax sync |

---

### Task 0: Branch and cherry-picks

**Files:**
- No new files; three cherry-picks with conflict resolution in `lib/eval.ml`.

**Interfaces:**
- Produces: branch `feat/step-defs` at main + 3 commits; `EQ` token; shorthand RHS productions; `scope`/`ctx` types in `lib/eval.ml` with `lookup_point ctx`, `lookup_crease ctx`, `bind_point ctx`, `bind_crease ctx`, extracted `eval_stmt`.

- [ ] **Step 1: Create branch from main**

```bash
git switch -c feat/step-defs main
```

- [ ] **Step 2: Cherry-pick the two syntax commits**

```bash
git cherry-pick 1ce7c31   # feat(syntax): change binding separator from `:' to `='
git cherry-pick 786e499   # feat(syntax): shorthand binding RHS
```

Conflicts unlikely (main only advanced in docs since). If `examples/` conflict, keep the `=` side.

- [ ] **Step 3: Run tests**

Run: `dune test`
Expected: all green.

- [ ] **Step 4: Cherry-pick the scope-stack refactor**

```bash
git cherry-pick 00f8549   # refactor(eval): scope-stack context
```

This commit references AST types from a dropped commit (`Ast.step_body`; possibly match arms on `Ast.StepBind`/`Ast.Export`/`Ast.Inline`/`Ast.Apply`). Whether or not git reports a textual conflict, `lib/eval.ml` will not compile until you:

1. In `type scope`, delete the `step_defs` field; delete its line in `make_scope`; delete `_bind_step_def`.
2. In `eval_stmt`, delete any arm matching the old constructors (`Ast.StepBind` etc.) — they don't exist on this branch.

The kept shape:

```ocaml
type scope = {
  points : (string, Geom.point) Hashtbl.t;
  lines  : (string, Geom.line) Hashtbl.t;
}

let make_scope () = { points = Hashtbl.create 8; lines = Hashtbl.create 8 }

type ctx = {
  mutable scopes : scope list; (* head = innermost *)
  state : Fold_state.t ref;
  recs : Fold_state.crease_record list ref;
}
```

- [ ] **Step 5: Build, test, finish the pick**

Run: `dune test`
Expected: green, including `test_scope_basic_lookup` from the picked commit.

```bash
git add lib/eval.ml
git cherry-pick --continue   # if the pick stopped on conflict
# or, if the pick had completed and you fixed compile errors after:
git commit --amend --no-edit
```

---

### Task 1: Tokens and AST types

**Files:**
- Modify: `lib/lexer.ml`
- Modify: `lib/ast.ml`
- Modify: `lib/parser.mly` (token declarations only)
- Modify: `lib/eval.ml` (placeholder match arms so warning-8-as-error passes)

**Interfaces:**
- Produces (in `Ast`):

```ocaml
type param = { pkind : [ `Point | `Line ]; pname : string; pspan : Error.span }
type arg = APoint of point_operand | ALine of line_operand
type export_entry = {
  ekind : [ `Point | `Line ];
  esrc : string;            (* member name in the instance *)
  eshadow : bool;           (* ! present *)
  erename : string option;  (* as-target, sans sigil *)
  espan : Error.span;
}
```

New operand constructors (inside the mutually recursive operand types): `PMember of string * string * Error.span` (instance, member) and `LMember of string * string * Error.span`.

New stmt constructors:

```ocaml
| Def of string * param list * stmt list * Error.span
| Apply of string option * string * arg list * Error.span
    (* Apply (Some "p1", "petal", args, span) = $p1 = apply petal(...)
       Apply (None, ...) = naked apply *)
| Export of export_entry list option * string * Error.span
    (* None = export-all; the string is the instance name *)
| StepMark of string * Error.span
```

- [ ] **Step 1: Extend the lexer**

In `lib/lexer.ml`, add these rules. Keyword rules go with the existing keywords; the bracket-opens go next to `"--("`/`".("`; the bare `id -> IDENT` rule goes **after** every keyword rule (sedlex prefers earlier rules on equal-length matches):

```ocaml
  | "def" -> DEF
  | "apply" -> APPLY
  | "export" -> EXPORT
  | "step" -> STEP
  | "as" -> AS
  | '!' -> BANG
  | '{' -> LBRACE
  | '}' -> RBRACE
  | '(' -> LPAREN
  | ']' -> RBRACKET
  | "--[" -> LINE_MEMBER_OPEN
  | ".[" -> POINT_MEMBER_OPEN
  | '$', id ->
      let s = Sedlexing.Utf8.lexeme buf in
      INSTANCE (String.sub s 1 (String.length s - 1))
  | id -> IDENT (Sedlexing.Utf8.lexeme buf)
```

`id_char` stays `'a'..'z' | 'A'..'Z' | '0'..'9' | '_'` — no `-`.

- [ ] **Step 2: Extend the AST**

Apply the `Interfaces` block above to `lib/ast.ml`: `param` and `export_entry` after `crease_ref`; `PMember`/`LMember` in the operand types; `arg` after the operand types (it references them); the four stmt constructors at the end of `stmt`.

- [ ] **Step 3: Declare tokens in the parser**

In `lib/parser.mly`:

```
%token DEF APPLY EXPORT STEP AS BANG LBRACE RBRACE LPAREN RBRACKET
%token LINE_MEMBER_OPEN POINT_MEMBER_OPEN
%token <string> INSTANCE
%token <string> IDENT
```

Menhir warns about unused tokens until Tasks 2–4 — warnings, not errors.

- [ ] **Step 4: Placeholder arms in eval**

Dune's dev profile makes partial matches errors. In `lib/eval.ml`:

- In `pstr`: `| Ast.PMember (i, m, _) -> Printf.sprintf ".[$%s %s]" i m`
- In `lstr`: `| Ast.LMember (i, m, _) -> Printf.sprintf "--[$%s %s]" i m`
- In `resolve_point`: `| Ast.PMember (_, _, span) -> Error.fail span "qualified access not implemented yet"`
- In `resolve_line`: `| Ast.LMember (_, _, span) -> Error.fail span "qualified access not implemented yet"`
- In `eval_stmt`: `| Ast.Def (_, _, _, span) | Ast.Apply (_, _, _, span) | Ast.Export (_, _, span) | Ast.StepMark (_, span) -> Error.fail span "not implemented yet"`

- [ ] **Step 5: Build and test**

Run: `dune build && dune test`
Expected: builds; all existing tests green.

- [ ] **Step 6: Commit**

```bash
git add lib/lexer.ml lib/ast.ml lib/parser.mly lib/eval.ml
git commit -m "feat(ast): tokens and AST types for def/apply/export/step"
```

---

### Task 2: Parse `def`

**Files:**
- Modify: `lib/parser.mly`
- Test: `tests/test_parse.ml`

**Interfaces:**
- Consumes: Task 1 tokens/AST.
- Produces: `stmt`/`body_stmt`/`body_stmts`/`params` productions. `body_stmt` = everything a def body may contain (all current statements; `apply`/`export` join it in Tasks 3–4); `stmt = body_stmt | def` (`step` marker joins in Task 4). The grammar itself enforces "no def in def, no step marker in body".

- [ ] **Step 1: Write failing tests**

`tests/test_parse.ml` has no `expect_error` — copy the helper from the top of `tests/test_eval.ml` first. Then add:

```ocaml
let test_parse_def () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       def petal(.p .q --base) {\n\
      \  @map .p onto .q moving .p\n\
      \  .tip = cross --(.p .q) --base\n\
       }\n"
  in
  match prog with
  | [ Ast.Def ("petal", params, body, _) ] ->
      Alcotest.(check int) "3 params" 3 (List.length params);
      Alcotest.(check int) "2 body stmts" 2 (List.length body);
      let p0 = List.nth params 0 and p2 = List.nth params 2 in
      Alcotest.(check string) "p0 name" "p" p0.Ast.pname;
      Alcotest.(check bool) "p0 is point" true (p0.Ast.pkind = `Point);
      Alcotest.(check bool) "p2 is line" true (p2.Ast.pkind = `Line)
  | _ -> Alcotest.fail "expected a single Def"

let test_parse_def_zero_params () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\ndef thirds() {\n  --pq = through .x .y\n}\n"
  with
  | [ Ast.Def ("thirds", [], [ _ ], _) ] -> ()
  | _ -> Alcotest.fail "expected zero-param Def"

let test_parse_def_in_def_rejected () =
  expect_error "syntax error" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\ndef a() {\n  def b() {\n  }\n}\n")

let test_parse_step_in_body_rejected () =
  expect_error "syntax error" (fun () ->
      Beloch.parse ~filename:"t.bel" "paper square\ndef a() {\n  step x\n}\n")

let test_parse_kebab_rejected () =
  expect_error "unexpected character" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\n--foo-bar = through .a .b\n")
```

Register all five in the suite list at the bottom of the file.

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | tail -20`
Expected: FAIL (syntax errors on `def`, and/or unused-constructor build issues).

- [ ] **Step 3: Implement the grammar**

In `lib/parser.mly`, rename the current `stmt` productions to `body_stmt` and add:

```
stmt:
  | body_stmt  { $1 }
  | DEF IDENT LPAREN params RPAREN LBRACE body_stmts RBRACE
      { Def ($2, $4, $7, $loc) }

body_stmts:
  | { [] }
  | body_stmt body_stmts { $1 :: $2 }

body_stmt:
  | CREASE EQ LINE_OPEN point_operand point_operand RPAREN
      { Crease (Some $1, Ast.Through ($4, $5), None, $loc) }
  | CREASE EQ axiom_stmt { let (a, fs) = $3 in Crease (Some $1, a, fs, $loc) }
  | axiom_stmt           { let (a, fs) = $1 in Crease (None, a, fs, $loc) }
  | POINT EQ point_expr  { Point ($1, $3, $loc) }
  | FLIP                 { Flip $loc }

params:
  | { [] }
  | param params { $1 :: $2 }

param:
  | POINT  { { pkind = `Point; pname = $1; pspan = $loc } }
  | CREASE { { pkind = `Line;  pname = $1; pspan = $loc } }
```

- [ ] **Step 4: Run tests**

Run: `dune test`
Expected: PASS. `dune build` output must show no Menhir conflicts.

- [ ] **Step 5: Commit**

```bash
git add lib/parser.mly tests/test_parse.ml
git commit -m "feat(parser): parse def with sigil-typed params and restricted body"
```

---

### Task 3: Parse `apply` and qualified member operands

**Files:**
- Modify: `lib/parser.mly`
- Test: `tests/test_parse.ml`

**Interfaces:**
- Consumes: Task 2 `body_stmt`.
- Produces: `Apply` stmts (bound + naked); `PMember`/`LMember` usable anywhere operands are.

- [ ] **Step 1: Write failing tests**

```ocaml
let test_parse_apply_bound () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n$p1 = apply petal(.b .d --(.a .c))\n"
  with
  | [ Ast.Apply (Some "p1", "petal", [ _; _; _ ], _) ] -> ()
  | _ -> Alcotest.fail "expected bound Apply with 3 args"

let test_parse_apply_naked () =
  match Beloch.parse ~filename:"t.bel" "paper square\napply thirds()\n" with
  | [ Ast.Apply (None, "thirds", [], _) ] -> ()
  | _ -> Alcotest.fail "expected naked zero-arg Apply"

let test_parse_member_operands () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       @map .[$p1 tip] onto .[$p2 tip]\n\
       .x = cross --[$p1 pq] --[$p2 pq]\n"
  with
  | [
      Ast.Crease (None, Ast.MapPoints (Ast.PMember ("p1", "tip", _), _), _, _);
      Ast.Point ("x", Ast.Cross (Ast.LMember ("p1", "pq", _), _), _);
    ] ->
      ()
  | _ -> Alcotest.fail "expected member operands"
```

Register in the suite.

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | tail -10`
Expected: FAIL with syntax error.

- [ ] **Step 3: Implement**

Add to `body_stmt`:

```
  | INSTANCE EQ APPLY IDENT LPAREN args RPAREN { Apply (Some $1, $4, $6, $loc) }
  | APPLY IDENT LPAREN args RPAREN             { Apply (None, $2, $4, $loc) }
```

New nonterminals:

```
args:
  | { [] }
  | arg args { $1 :: $2 }

arg:
  | point_operand { APoint $1 }
  | line_operand  { ALine $1 }
```

Extend the operands:

```
point_operand:
  | point_ref { PNamed $1 }
  | POINT_OPEN line_operand line_operand RPAREN { PCross ($2, $3, $loc) }
  | POINT_MEMBER_OPEN INSTANCE IDENT RBRACKET   { PMember ($2, $3, $loc) }

line_operand:
  | crease_ref { LNamed $1 }
  | LINE_OPEN point_operand point_operand RPAREN { LThrough ($2, $3, $loc) }
  | LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET     { LMember ($2, $3, $loc) }
```

- [ ] **Step 4: Run tests**

Run: `dune test`
Expected: PASS, no Menhir conflicts.

- [ ] **Step 5: Commit**

```bash
git add lib/parser.mly tests/test_parse.ml
git commit -m "feat(parser): parse apply and qualified member operands"
```

---

### Task 4: Parse `export` and `step` markers

**Files:**
- Modify: `lib/parser.mly`
- Test: `tests/test_parse.ml`

**Interfaces:**
- Consumes: Tasks 2–3.
- Produces: `Export` stmts (selective with `!`/`as`, export-all); `StepMark` stmts (top level only). A kind-changing rename (`.x as --y`) errors at parse time with "export rename must keep the kind".

- [ ] **Step 1: Write failing tests**

```ocaml
let test_parse_export_selective () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\nexport { .tip as .left_tip --pq .s! } $t\n"
  with
  | [ Ast.Export (Some [ e1; e2; e3 ], "t", _) ] ->
      Alcotest.(check string) "e1 src" "tip" e1.Ast.esrc;
      Alcotest.(check bool) "e1 renamed" true (e1.Ast.erename = Some "left_tip");
      Alcotest.(check bool) "e2 is line" true (e2.Ast.ekind = `Line);
      Alcotest.(check bool) "e3 shadow" true e3.Ast.eshadow
  | _ -> Alcotest.fail "expected selective Export with 3 entries"

let test_parse_export_all () =
  match Beloch.parse ~filename:"t.bel" "paper square\nexport $t\n" with
  | [ Ast.Export (None, "t", _) ] -> ()
  | _ -> Alcotest.fail "expected export-all"

let test_parse_export_kind_mismatch_rename () =
  expect_error "keep the kind" (fun () ->
      Beloch.parse ~filename:"t.bel"
        "paper square\nexport { .m as --m2 } $t\n")

let test_parse_step_marker () =
  match Beloch.parse ~filename:"t.bel" "paper square\nstep thirds\nflip\n" with
  | [ Ast.StepMark ("thirds", _); Ast.Flip _ ] -> ()
  | _ -> Alcotest.fail "expected StepMark then Flip"
```

Register in the suite.

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | tail -10`
Expected: FAIL with syntax error.

- [ ] **Step 3: Implement**

Add to `body_stmt`:

```
  | EXPORT LBRACE export_entries RBRACE INSTANCE { Export (Some $3, $5, $loc) }
  | EXPORT INSTANCE                              { Export (None, $2, $loc) }
```

Add to `stmt` (top level only):

```
  | STEP IDENT { StepMark ($2, $loc) }
```

New nonterminals:

```
export_entries:
  | export_entry                { [ $1 ] }
  | export_entry export_entries { $1 :: $2 }

export_entry:
  | export_name bang_opt as_opt
      { let (k, n) = $1 in
        (match $3 with
         | Some (k', _) when k' <> k ->
             Error.fail $loc "export rename must keep the kind"
         | _ -> ());
        { ekind = k; esrc = n; eshadow = $2;
          erename = Option.map snd $3; espan = $loc } }

export_name:
  | POINT  { (`Point, $1) }
  | CREASE { (`Line, $1) }

bang_opt:
  |      { false }
  | BANG { true }

as_opt:
  |                { None }
  | AS export_name { Some $2 }
```

`Error.fail` raises `Error.Beloch_error` (`lib/error.ml`) — fine from a semantic action; it propagates out of `Beloch.parse` like any Beloch error.

- [ ] **Step 4: Run tests**

Run: `dune test`
Expected: PASS, no Menhir conflicts.

- [ ] **Step 5: Commit**

```bash
git add lib/parser.mly tests/test_parse.ml
git commit -m "feat(parser): parse export entries and step panel markers"
```

---

### Task 5: Uniform no-silent-rebinding + temps (#24)

**Files:**
- Modify: `lib/eval.ml`
- Test: `tests/test_eval.ml`

**Interfaces:**
- Consumes: Task 0 `bind_point`/`bind_crease`.
- Produces: `is_temp : string -> bool`; `bind_point : ctx -> string -> Error.span -> Geom.point -> unit` and `bind_crease : ctx -> string -> Error.span -> Geom.line -> unit` (note the added span) erroring on non-temp duplicates in the innermost scope; `eval_folded` output (`named_points`/`named_lines`) excludes temps; temp creases get provenance `name = None`.

- [ ] **Step 1: Write failing tests**

Add to `tests/test_eval.ml` (and a small local helper):

```ocaml
let eval_src src =
  Eval.eval_folded (Beloch.parse ~filename:"t.bel" ("paper square\n" ^ src))

let test_eval_dup_crease_error () =
  expect_error "already bound" (fun () ->
      eval_src "--x = through .a .b\n--x = through .a .c\n")

let test_eval_dup_point_error () =
  expect_error "already bound" (fun () ->
      eval_src
        "--h = through .a .b\n--v = through .a .d\n.x = cross --h --v\n\
         .x = cross --h --v\n")

let test_eval_corner_rebind_error () =
  expect_error "already bound" (fun () ->
      eval_src "--h = through .a .b\n--v = through .a .d\n.a = cross --h --v\n")

let test_eval_temp_rebind_ok () =
  let fd =
    eval_src
      "--h = through .a .b\n--v = through .a .d\n._x = cross --h --v\n\
       ._x = cross --v --h\n"
  in
  Alcotest.(check bool)
    "temp not in named_points" true
    (not (List.mem_assoc "_x" fd.Eval.named_points))

let test_eval_temp_crease_unnamed () =
  let fd = eval_src "--_t = through .a .c\n" in
  Alcotest.(check bool)
    "temp line not in named_lines" true
    (not (List.mem_assoc "_t" fd.Eval.named_lines));
  Alcotest.(check bool)
    "temp crease provenance unnamed" true
    (List.for_all
       (fun (r : Fold_state.crease_record) ->
         match r.Fold_state.prov with
         | Some p -> p.State.name = None
         | None -> true)
       fd.Eval.creases)
```

Register all.

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | tail -20`
Expected: FAIL (silent rebinding currently succeeds; temps land in named_points).

- [ ] **Step 3: Implement**

In `lib/eval.ml`:

```ocaml
let is_temp (n : string) = String.length n > 0 && n.[0] = '_'

let bind_point (ctx : ctx) (name : string) (span : Error.span) (p : Geom.point) =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.points name then
    Error.fail span
      (Printf.sprintf "point .%s is already bound; only _-prefixed temps rebind"
         name);
  Hashtbl.replace s.points name p

let bind_crease (ctx : ctx) (name : string) (span : Error.span) (l : Geom.line) =
  let s = List.hd ctx.scopes in
  if (not (is_temp name)) && Hashtbl.mem s.lines name then
    Error.fail span
      (Printf.sprintf
         "crease --%s is already bound; only _-prefixed temps rebind" name);
  Hashtbl.replace s.lines name l
```

Update the two call sites in `eval_stmt` (`Crease` and `Point` arms) to pass the stmt span. In the `Crease` arm, temp names stay out of provenance:

```ocaml
let prov_name =
  match name_opt with Some n when not (is_temp n) -> Some n | _ -> None
in
let prov : State.provenance option =
  Some { State.axiom; sources; span; name = prov_name }
in
```

Result assembly filters temps:

```ocaml
let named_points =
  Hashtbl.fold
    (fun k v acc -> if is_temp k then acc else (k, v) :: acc)
    root_scope.points []
in
let named_lines =
  Hashtbl.fold
    (fun k v acc -> if is_temp k then acc else (k, v) :: acc)
    root_scope.lines []
in
```

- [ ] **Step 4: Run tests; fix casualties**

Run: `dune test`
Any pre-existing test or example that silently rebound a name now fails — it was relying on the #24 bug; rename the second binding there. Expected after fixes: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/eval.ml tests/test_eval.ml
git commit -m "feat(eval): error on silent rebinding; _-temps rebind and stay unnamed (#24)"
```

---

### Task 6: Evaluate `def` and `apply`

**Files:**
- Modify: `lib/eval.ml`
- Test: `tests/test_eval.ml`

**Interfaces:**
- Consumes: Task 5 `is_temp`/`bind_*`; Task 1 AST.
- Produces:

```ocaml
type instance = {
  ipoints : (string, Geom.point) Hashtbl.t;
  ilines : (string, Geom.line) Hashtbl.t;
}
(* scope gains: instances : (string, instance) Hashtbl.t *)
type name_ctx = Root | InInstance of string | Anon
(* ctx gains: mutable name_ctx : name_ctx;
              mutable cur_def_idx : int option;  (* Some k while running def k's body *)
              defs : (string, int * Ast.param list * Ast.stmt list) Hashtbl.t
              (* int = definition index, for the earlier-defs-only rule *) *)
val lookup_instance : ctx -> string -> Error.span -> instance  (* walks scopes *)
```

The definition index enforces spec §4 "a body only sees *earlier* defs": without it, a global table would let `def d() { apply d() }` recurse infinitely.

FOLD provenance names: root crease `--pq` → `Some "pq"`; inside `$p1 = apply` → `Some "p1.pq"`; inside naked `apply` → `None`; temps → `None`.

- [ ] **Step 1: Write failing tests**

```ocaml
let test_eval_def_never_runs () =
  let fd = eval_src "def bad() {\n  --x = through .a .a\n}\n" in
  Alcotest.(check int) "no creases" 0 (List.length fd.Eval.creases)

let test_eval_apply_closed_scope () =
  expect_error "undefined point .a" (fun () ->
      eval_src "def d() {\n  --x = through .a .b\n}\napply d()\n")

let test_eval_apply_binds_params () =
  let fd =
    eval_src
      "def diag(.p .q) {\n  --d = through .p .q\n}\n$i = apply diag(.a .c)\n"
  in
  Alcotest.(check int) "one crease" 1 (List.length fd.Eval.creases)

let test_eval_apply_arity_error () =
  expect_error "argument" (fun () ->
      eval_src "def diag(.p .q) {\n  --d = through .p .q\n}\napply diag(.a)\n")

let test_eval_apply_kind_error () =
  expect_error "point argument" (fun () ->
      eval_src
        "def d(.p) {\n  --x = perp --(.a .b) through .p\n}\n\
         apply d(--(.a .b))\n")

let test_eval_apply_undefined_def () =
  expect_error "undefined def" (fun () -> eval_src "apply nope()\n")

let test_eval_dup_def_error () =
  expect_error "already defined" (fun () ->
      eval_src "def d() {\n}\ndef d() {\n}\n")

let test_eval_dup_param_error () =
  expect_error "duplicate parameter" (fun () ->
      eval_src "def d(.p .p) {\n}\n")

let test_eval_dup_instance_error () =
  expect_error "already bound" (fun () ->
      eval_src
        "def d(.p .q) {\n  --x = through .p .q\n}\n\
         $i = apply d(.a .c)\n$i = apply d(.b .d)\n")

let prov_names fd =
  List.filter_map
    (fun (r : Fold_state.crease_record) ->
      match r.Fold_state.prov with Some p -> p.State.name | None -> None)
    fd.Eval.creases

let test_eval_instance_fold_names () =
  let fd =
    eval_src "def d(.p .q) {\n  --x = through .p .q\n}\n$i = apply d(.a .c)\n"
  in
  Alcotest.(check bool) "crease named i.x" true
    (List.mem "i.x" (prov_names fd))

let test_eval_naked_apply_unnamed () =
  let fd =
    eval_src "def d(.p .q) {\n  --x = through .p .q\n}\napply d(.a .c)\n"
  in
  Alcotest.(check int) "no named provenance" 0 (List.length (prov_names fd))

let test_eval_self_recursion_rejected () =
  expect_error "not defined before" (fun () ->
      eval_src "def d() {\n  apply d()\n}\napply d()\n")

let test_eval_later_def_invisible () =
  expect_error "not defined before" (fun () ->
      eval_src
        "def outer() {\n  apply inner()\n}\n\
         def inner(.p) {\n}\n\
         apply outer()\n")

let test_eval_earlier_def_visible () =
  let fd =
    eval_src
      "def inner(.p .q) {\n  --l = through .p .q\n}\n\
       def outer(.p .q) {\n  apply inner(.p .q)\n}\n\
       apply outer(.a .c)\n"
  in
  Alcotest.(check int) "one crease" 1 (List.length fd.Eval.creases)
```

Note `test_eval_apply_kind_error`: `perp LINE through POINT` is the axiom-3 shape (`Perp`), so `--x = perp --(.a .b) through .p` is valid inside the body — the error must come from the argument kind, not the body. Register all.

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | tail -20`
Expected: FAIL with "not implemented yet".

- [ ] **Step 3: Implement**

Quarry: `git show 633ea45 -- lib/eval.ml` — the arg-binding shape transfers; the dynamic-scope part must not.

1. Types (place `instance` before `scope`):

```ocaml
type instance = {
  ipoints : (string, Geom.point) Hashtbl.t;
  ilines : (string, Geom.line) Hashtbl.t;
}

type scope = {
  points : (string, Geom.point) Hashtbl.t;
  lines : (string, Geom.line) Hashtbl.t;
  instances : (string, instance) Hashtbl.t;
}

let make_scope () =
  {
    points = Hashtbl.create 8;
    lines = Hashtbl.create 8;
    instances = Hashtbl.create 4;
  }

type name_ctx = Root | InInstance of string | Anon

type ctx = {
  mutable scopes : scope list;
  mutable name_ctx : name_ctx;
  mutable cur_def_idx : int option; (* Some k while running def k's body *)
  mutable next_def_idx : int;
  defs : (string, int * Ast.param list * Ast.stmt list) Hashtbl.t;
  state : Fold_state.t ref;
  recs : Fold_state.crease_record list ref;
}
```

Initialize in `eval_folded`: `name_ctx = Root; cur_def_idx = None; next_def_idx = 0; defs = Hashtbl.create 4`.

2. Instance lookup:

```ocaml
let lookup_instance (ctx : ctx) (name : string) (span : Error.span) : instance =
  match
    List.find_map (fun s -> Hashtbl.find_opt s.instances name) ctx.scopes
  with
  | Some i -> i
  | None -> Error.fail span (Printf.sprintf "undefined instance $%s" name)
```

3. Extend Task 5's `prov_name` in the `Crease` arm:

```ocaml
let prov_name =
  match name_opt with
  | Some n when not (is_temp n) -> (
      match ctx.name_ctx with
      | Root -> Some n
      | InInstance i -> Some (i ^ "." ^ n)
      | Anon -> None)
  | _ -> None
in
```

4. Make `eval_stmt` recursive (`let rec eval_stmt`) and replace the placeholder arms for `Def`/`Apply`:

```ocaml
| Ast.Def (name, params, body, span) ->
    if Hashtbl.mem ctx.defs name then
      Error.fail span (Printf.sprintf "def %s is already defined" name);
    let seen = Hashtbl.create 4 in
    List.iter
      (fun (p : Ast.param) ->
        if Hashtbl.mem seen p.Ast.pname then
          Error.fail p.Ast.pspan
            (Printf.sprintf "duplicate parameter %s" p.Ast.pname);
        Hashtbl.replace seen p.Ast.pname ())
      params;
    Hashtbl.replace ctx.defs name (ctx.next_def_idx, params, body);
    ctx.next_def_idx <- ctx.next_def_idx + 1
| Ast.Apply (bind_opt, defname, args, span) ->
    let def_idx, params, body =
      match Hashtbl.find_opt ctx.defs defname with
      | Some d -> d
      | None -> Error.fail span (Printf.sprintf "undefined def %s" defname)
    in
    (match ctx.cur_def_idx with
    | Some k when def_idx >= k ->
        Error.fail span
          (Printf.sprintf "def %s is not defined before this body" defname)
    | _ -> ());
    if List.length args <> List.length params then
      Error.fail span
        (Printf.sprintf "def %s takes %d argument(s), got %d" defname
           (List.length params) (List.length args));
    (* resolve args in the CALLER scope, then swap in the closed scope *)
    let body_scope = make_scope () in
    List.iter2
      (fun (p : Ast.param) (a : Ast.arg) ->
        match (p.Ast.pkind, a) with
        | `Point, Ast.APoint po ->
            Hashtbl.replace body_scope.points p.Ast.pname (resolve_point po)
        | `Line, Ast.ALine lo ->
            Hashtbl.replace body_scope.lines p.Ast.pname (resolve_line lo)
        | `Point, Ast.ALine _ ->
            Error.fail span
              (Printf.sprintf "parameter .%s of %s needs a point argument"
                 p.Ast.pname defname)
        | `Line, Ast.APoint _ ->
            Error.fail span
              (Printf.sprintf "parameter --%s of %s needs a line argument"
                 p.Ast.pname defname))
      params args;
    let saved_scopes = ctx.scopes
    and saved_nctx = ctx.name_ctx
    and saved_def_idx = ctx.cur_def_idx in
    ctx.scopes <- [ body_scope ];
    ctx.cur_def_idx <- Some def_idx;
    (ctx.name_ctx <-
       (match (bind_opt, saved_nctx) with
       | None, _ -> Anon
       | Some _, Anon -> Anon
       | Some i, Root -> InInstance i
       | Some i, InInstance outer -> InInstance (outer ^ "." ^ i)));
    List.iter eval_stmt body;
    ctx.scopes <- saved_scopes;
    ctx.name_ctx <- saved_nctx;
    ctx.cur_def_idx <- saved_def_idx;
    (match bind_opt with
    | None -> ()
    | Some iname ->
        let cur = List.hd ctx.scopes in
        if (not (is_temp iname)) && Hashtbl.mem cur.instances iname then
          Error.fail span
            (Printf.sprintf
               "instance $%s is already bound; only _-prefixed temps rebind"
               iname);
        let inst = { ipoints = Hashtbl.create 8; ilines = Hashtbl.create 8 } in
        Hashtbl.iter
          (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ipoints k v)
          body_scope.points;
        Hashtbl.iter
          (fun k v -> if not (is_temp k) then Hashtbl.replace inst.ilines k v)
          body_scope.lines;
        Hashtbl.replace cur.instances iname inst)
```

Closed scope means body errors surface naturally (`.a` inside a body → "undefined point .a").

- [ ] **Step 4: Run tests**

Run: `dune test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/eval.ml tests/test_eval.ml
git commit -m "feat(eval): def table and apply with closed scope and retained instances"
```

---

### Task 7: Evaluate qualified access

**Files:**
- Modify: `lib/eval.ml`
- Test: `tests/test_eval.ml`

**Interfaces:**
- Consumes: Task 6 `lookup_instance`.
- Produces: `PMember`/`LMember` resolution in `resolve_point`/`resolve_line`.

- [ ] **Step 1: Write failing tests**

```ocaml
let test_eval_member_point_access () =
  let fd =
    eval_src
      "--h = through .a .b\n\
       def d(.p .q --base) {\n\
      \  --l = through .p .q\n\
      \  .m = cross --l --base\n\
       }\n\
       $i = apply d(.d .b --h)\n\
       --thru = through .[$i m] .c\n"
  in
  Alcotest.(check bool) "crease thru exists" true
    (List.mem_assoc "thru" fd.Eval.named_lines)

let test_eval_member_line_access () =
  let fd =
    eval_src
      "def d(.p .q) {\n  --l = through .p .q\n}\n\
       $i = apply d(.a .c)\n\
       .x = cross --[$i l] --(.a .b)\n"
  in
  Alcotest.(check bool) "point x exists" true
    (List.mem_assoc "x" fd.Eval.named_points)

let test_eval_member_unknown () =
  expect_error "no point member" (fun () ->
      eval_src
        "def d(.p .q) {\n  --l = through .p .q\n}\n\
         $i = apply d(.a .c)\n--z = through .[$i nope] .b\n")

let test_eval_member_kind_mismatch () =
  expect_error "no point member" (fun () ->
      eval_src
        "def d(.p .q) {\n  --l = through .p .q\n}\n\
         $i = apply d(.a .c)\n--z = through .[$i l] .b\n")

let test_eval_member_undefined_instance () =
  expect_error "undefined instance" (fun () ->
      eval_src "--z = through .[$ghost m] .b\n")
```

(`test_eval_member_point_access` geometry: `d`/`b` diagonal crosses the bottom edge `--h` outside the segment but on the line — `cross` intersects lines, and the intersection `(?, 0)`-ish must lie on paper; the `.d .b` diagonal meets `y=0` at `(1, 0)` = corner `.b`, on the paper. Fine.) Register all.

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | tail -10`
Expected: FAIL with "qualified access not implemented yet".

- [ ] **Step 3: Implement**

Replace the Task-1 placeholders:

```ocaml
(* in resolve_point *)
| Ast.PMember (iname, mem, span) -> (
    let inst = lookup_instance ctx iname span in
    match Hashtbl.find_opt inst.ipoints mem with
    | Some p -> p
    | None ->
        Error.fail span
          (Printf.sprintf "instance $%s has no point member %s" iname mem))

(* in resolve_line *)
| Ast.LMember (iname, mem, span) -> (
    let inst = lookup_instance ctx iname span in
    match Hashtbl.find_opt inst.ilines mem with
    | Some l -> l
    | None ->
        Error.fail span
          (Printf.sprintf "instance $%s has no line member %s" iname mem))
```

Temps were excluded at instance-build time (Task 6), so `.[$i _tmp]` is automatically "no point member".

- [ ] **Step 4: Run tests**

Run: `dune test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/eval.ml tests/test_eval.ml
git commit -m "feat(eval): qualified member access on instances"
```

---

### Task 8: Evaluate `export`

**Files:**
- Modify: `lib/eval.ml`
- Test: `tests/test_eval.ml`

**Interfaces:**
- Consumes: Task 6 instances; Task 5 `is_temp`.
- Produces: `Export` arm — selective + export-all, `!` validated both ways, `as` rename, per-name landing collision checks (uniform with #24). Landing onto a temp target always allowed (temps are marked-mutable).

- [ ] **Step 1: Write failing tests**

Shared fixture (body creates two lines and a point; `.m` = intersection of the `a`–`c` diagonal with the `c`–`b` edge = corner `.c`, on paper):

```ocaml
let def_d =
  "def d(.p .q .r) {\n\
  \  --l1 = through .p .q\n\
  \  --l2 = through .p .r\n\
  \  .m = cross --l1 --(.q .r)\n\
   }\n\
   $i = apply d(.a .c .b)\n"

let test_eval_export_selective () =
  let fd = eval_src (def_d ^ "export { .m --l1 } $i\n") in
  Alcotest.(check bool) "m landed" true
    (List.mem_assoc "m" fd.Eval.named_points);
  Alcotest.(check bool) "l1 landed" true
    (List.mem_assoc "l1" fd.Eval.named_lines);
  Alcotest.(check bool) "l2 not landed" true
    (not (List.mem_assoc "l2" fd.Eval.named_lines))

let test_eval_export_all () =
  let fd = eval_src (def_d ^ "export $i\n") in
  Alcotest.(check bool) "l2 landed too" true
    (List.mem_assoc "l2" fd.Eval.named_lines)

let test_eval_export_rename () =
  let fd = eval_src (def_d ^ "export { .m as .mid } $i\n") in
  Alcotest.(check bool) "mid landed" true
    (List.mem_assoc "mid" fd.Eval.named_points);
  Alcotest.(check bool) "m not landed" true
    (not (List.mem_assoc "m" fd.Eval.named_points))

let test_eval_export_collision_needs_bang () =
  expect_error "use ! to shadow" (fun () ->
      eval_src ("--l1 = through .a .b\n" ^ def_d ^ "export { --l1 } $i\n"))

let test_eval_export_bang_shadows () =
  let fd =
    eval_src ("--l1 = through .a .b\n" ^ def_d ^ "export { --l1! } $i\n")
  in
  Alcotest.(check bool) "l1 present" true
    (List.mem_assoc "l1" fd.Eval.named_lines)

let test_eval_export_bang_without_conflict () =
  expect_error "nothing to shadow" (fun () ->
      eval_src (def_d ^ "export { --l1! } $i\n"))

let test_eval_export_unknown_member () =
  expect_error "no point member" (fun () ->
      eval_src (def_d ^ "export { .ghost } $i\n"))

let test_eval_export_all_collision () =
  expect_error "use ! to shadow" (fun () ->
      eval_src (def_d ^ "$j = apply d(.a .c .b)\nexport $i\nexport $j\n"))
```

Register all.

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | tail -20`
Expected: FAIL with "not implemented yet".

- [ ] **Step 3: Implement**

Quarry for the validation shape: `git show ec95148 -- lib/eval.ml` — the `!`-table logic transfers; the step/inline plumbing does not.

```ocaml
| Ast.Export (entries_opt, iname, span) ->
    let inst = lookup_instance ctx iname span in
    let cur = List.hd ctx.scopes in
    let land_name ~(kind : [ `Point | `Line ]) ~(shadow : bool)
        ~(espan : Error.span) (src : string) (target : string) =
      let target_exists, sigil =
        match kind with
        | `Point -> (Hashtbl.mem cur.points target, ".")
        | `Line -> (Hashtbl.mem cur.lines target, "--")
      in
      (if not (is_temp target) then
         match (target_exists, shadow) with
         | true, false ->
             Error.fail espan
               (Printf.sprintf "%s%s exists; use ! to shadow" sigil target)
         | false, true ->
             Error.fail espan
               (Printf.sprintf "nothing to shadow with %s%s; remove !" sigil
                  target)
         | _ -> ());
      match kind with
      | `Point -> (
          match Hashtbl.find_opt inst.ipoints src with
          | Some v -> Hashtbl.replace cur.points target v
          | None ->
              Error.fail espan
                (Printf.sprintf "instance $%s has no point member %s" iname src))
      | `Line -> (
          match Hashtbl.find_opt inst.ilines src with
          | Some v -> Hashtbl.replace cur.lines target v
          | None ->
              Error.fail espan
                (Printf.sprintf "instance $%s has no line member %s" iname src))
    in
    (match entries_opt with
    | Some entries ->
        List.iter
          (fun (e : Ast.export_entry) ->
            land_name ~kind:e.Ast.ekind ~shadow:e.Ast.eshadow ~espan:e.Ast.espan
              e.Ast.esrc
              (Option.value e.Ast.erename ~default:e.Ast.esrc))
          entries
    | None ->
        Hashtbl.iter
          (fun k _ -> land_name ~kind:`Point ~shadow:false ~espan:span k k)
          inst.ipoints;
        Hashtbl.iter
          (fun k _ -> land_name ~kind:`Line ~shadow:false ~espan:span k k)
          inst.ilines)
```

- [ ] **Step 4: Run tests**

Run: `dune test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/eval.ml tests/test_eval.ml
git commit -m "feat(eval): export instance members with shadow and rename validation"
```

---

### Task 9: Step panels in provenance and FOLD

**Files:**
- Modify: `lib/state.ml`, `lib/eval.ml`, `lib/fold_emit.ml`
- Test: `tests/test_eval.ml`

**Interfaces:**
- Consumes: Task 6 ctx.
- Produces: `State.provenance` gains `step : string option`; ctx gains `mutable panel : string option` and `panels : (string, unit) Hashtbl.t`; FOLD per-edge provenance objects gain a `"step"` field.

- [ ] **Step 1: Write failing tests**

```ocaml
let prov_steps fd =
  List.filter_map
    (fun (r : Fold_state.crease_record) ->
      match r.Fold_state.prov with Some p -> p.State.step | None -> None)
    fd.Eval.creases

let test_eval_panel_tags_creases () =
  let fd =
    eval_src
      "step first\n--x = through .a .c\nstep second\n--y = through .b .d\n"
  in
  Alcotest.(check bool) "first tagged" true (List.mem "first" (prov_steps fd));
  Alcotest.(check bool) "second tagged" true
    (List.mem "second" (prov_steps fd))

let test_eval_before_first_panel_untagged () =
  let fd = eval_src "--x = through .a .c\nstep p\n--y = through .b .d\n" in
  Alcotest.(check int) "one tagged" 1 (List.length (prov_steps fd))

let test_eval_dup_panel_error () =
  expect_error "already used" (fun () -> eval_src "step a\nstep a\n")

let test_eval_apply_folds_land_in_panel () =
  let fd =
    eval_src
      "def d(.p .q) {\n  --l = through .p .q\n}\n\
       step body\n$i = apply d(.a .c)\n"
  in
  Alcotest.(check bool) "tagged body" true (List.mem "body" (prov_steps fd))
```

Register all.

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | tail -10`
Expected: build FAIL (`State.step` unknown field).

- [ ] **Step 3: Implement**

`lib/state.ml`:

```ocaml
type provenance = {
  axiom : string;
  sources : string list;
  span : Error.span;
  name : string option;
  step : string option;
}
```

`lib/eval.ml`: ctx gains `mutable panel : string option; panels : (string, unit) Hashtbl.t` (init `panel = None; panels = Hashtbl.create 4`). The provenance record construction adds `step = ctx.panel`. New arm:

```ocaml
| Ast.StepMark (id, span) ->
    if Hashtbl.mem ctx.panels id then
      Error.fail span (Printf.sprintf "step id %s is already used" id);
    Hashtbl.replace ctx.panels id ();
    ctx.panel <- Some id
```

`apply` must NOT touch `ctx.panel` — body folds land in the panel open at the apply site automatically.

`lib/fold_emit.ml`: in the per-edge provenance `Assoc` (next to the existing `"name"` field, around line 123):

```ocaml
( "step",
  match pr.State.step with Some s -> `String s | None -> `Null );
```

- [ ] **Step 4: Run tests**

Run: `dune test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/state.ml lib/eval.ml lib/fold_emit.ml tests/test_eval.ml
git commit -m "feat(eval): step panel markers tagged into crease provenance and FOLD"
```

---

### Task 10: Examples, e2e, spec corpus

**Files:**
- Modify: `examples/cube-root.bel` (restructure with panels + temps; keep the header comment)
- Create: `examples/def-diagonals.bel`
- Test: `tests/test_e2e.ml`, `tests/test_parse.ml`

**Interfaces:**
- Consumes: everything.
- Produces: living examples matching spec §12; e2e coverage; the 10 spec-example programs pinned as parse tests.

- [ ] **Step 1: Restructure cube-root.bel**

Keep the existing header comment block verbatim; replace the program (same geometry, new syntax — scaffolding becomes temps, phases become panels):

```beloch
paper square

step vertical_middle
--vm = map .a onto .b                ; vertical midline x=1/2 (axiom 2)

step thirds
._mb  = .(--vm --(.a .b))            ; (1/2, 0)
._mt  = .(--vm --(.d .c))            ; (1/2, 1)
._pq1 = cross --(.d ._mb) --(.a .c)  ; (1/3, 1/3)
._pq2 = cross --(.a ._mt) --(.d .b)  ; (1/3, 2/3)
--pq  = through ._pq1 ._pq2          ; left third line PQ : x = 1/3
._rs1 = cross --(.c ._mb) --(.d .b)  ; (2/3, 1/3)
._rs2 = cross --(.b ._mt) --(.a .c)  ; (2/3, 2/3)
--rs  = through ._rs1 ._rs2          ; right third line RS : x = 2/3
.s    = .(--rs --(.d .c))            ; S = (2/3, 1), top of RS

step beloch_fold
@map .c onto --(.a .b) and .s onto --pq   ; fold C onto AB, S onto PQ → AC/CB = ∛2
```

- [ ] **Step 2: Create examples/def-diagonals.bel**

Construction-only def demo (no physical folds — it demos the def machinery):

```beloch
; status: works — def/apply demo: one def constructs the line between two
; corners; applied twice, the diagonals cross in the centre via qualified access.
paper square

def diagonal(.p .q) {
  --d = through .p .q
}

step diagonals
$d1 = apply diagonal(.a .c)
$d2 = apply diagonal(.b .d)

step centre
.m = cross --[$d1 d] --[$d2 d]
```

- [ ] **Step 3: E2e and corpus tests**

Add to `tests/test_e2e.ml`:

```ocaml
let test_e2e_cube_root_restructured () =
  ignore
    (Beloch.fold_string ~filename:"cube-root.bel"
       (read_example "cube-root.bel"))

let test_e2e_def_diagonals () =
  let json =
    Beloch.fold_string ~filename:"def-diagonals.bel"
      (read_example "def-diagonals.bel")
  in
  let open Yojson.Safe.Util in
  let pts = json |> member "beloch:named_points" |> to_assoc in
  Alcotest.(check bool) "centre named" true (List.mem_assoc "m" pts)

let test_e2e_cube_root_temps_hidden () =
  let json =
    Beloch.fold_string ~filename:"cube-root.bel" (read_example "cube-root.bel")
  in
  let open Yojson.Safe.Util in
  let pts = json |> member "beloch:named_points" |> to_assoc in
  Alcotest.(check bool) "no temp points in FOLD" true
    (not (List.exists (fun (k, _) -> String.length k > 0 && k.[0] = '_') pts))
```

Add to `tests/test_parse.ml` a corpus test pinning all 10 spec-example programs (parse-only fixtures — several reference undefined names by design; do not eval them):

```ocaml
let spec_corpus =
  [
    ( "01_eq_binding",
      "paper square\n--rs = through .rs1 .rs2\n.s   = cross --rs --(.d .c)\n" );
    ( "02_shorthand_rhs",
      "paper square\n.s  = .(--rs --(.d .c))\n--e = --(.p1 .p2)\n" );
    ( "03_def_petal",
      "paper square\ndef petal(.p .q --base) {\n\
      \  @map .p onto .q moving .p\n\
      \  .tip = cross --(.p .q) --base\n\
       }\n" );
    ( "04_apply",
      "paper square\n$p1 = apply petal(.k1 .k2 --(.k1 .k3))\n\
       apply petal(.k2 .k4 --(.k2 .k1))\n" );
    ( "05_qualified",
      "paper square\n@map .[$p1 tip] onto .[$p2 tip]\n\
       --d = through .[$p1 tip] .[$p2 tip]\n\
       .x  = cross --[$p1 pq] --[$p2 pq]\n" );
    ( "06_export",
      "paper square\nexport { .tip --pq } $t\n\
       export { .tip as .left_tip } $t\nexport { .s! } $t\nexport $t\n" );
    ( "07_panels",
      "paper square\nstep thirds\n._mb = .(--vm --(.a .b))\n\
       --pq = through ._pq1 ._pq2\n\nstep beloch_fold\n\
       @map .c onto --(.a .b) and .s onto --pq\n" );
    ( "08_cube_root",
      "paper square\n\nstep vertical_middle\n--vm = map .a onto .b\n\n\
       step thirds\n._mb  = .(--vm --(.a .b))\n._mt  = .(--vm --(.d .c))\n\
       ._pq1 = cross --(.d ._mb) --(.a .c)\n\
       ._pq2 = cross --(.a ._mt) --(.d .b)\n--pq  = through ._pq1 ._pq2\n\
       ._rs1 = cross --(.c ._mb) --(.d .b)\n\
       ._rs2 = cross --(.b ._mt) --(.a .c)\n--rs  = through ._rs1 ._rs2\n\
       .s    = .(--rs --(.d .c))\n\nstep beloch_fold\n\
       @map .c onto --(.a .b) and .s onto --pq\n" );
    ( "09_petal_full",
      "paper square\n\ndef petal(.p .q --base) {\n\
      \  @map .p onto .q moving .p\n\
      \  .tip = cross --(.p .q) --base\n\
       }\n\nstep petal_folds\n$left  = apply petal(.a .c --(.b .d))\n\
       $right = apply petal(.b .d --(.a .c))\n\nstep join\n\
       @map .[$left tip] onto .[$right tip]\n" );
    ( "10_zero_params",
      "paper square\ndef thirds() {\n\
      \  ._mb = .(--vm --(.a .b))\n\
      \  --pq = through ._mb .x\n\
       }\n$t = apply thirds()\nexport $t\n" );
  ]

let test_parse_spec_corpus () =
  List.iter
    (fun (name, src) ->
      try ignore (Beloch.parse ~filename:(name ^ ".bel") src)
      with Error.Beloch_error (_, m) ->
        Alcotest.fail (Printf.sprintf "%s failed to parse: %s" name m))
    spec_corpus
```

- [ ] **Step 4: Run everything and render a sanity check**

Run: `dune test`
Expected: PASS.

```bash
node tools/fold2svg.mjs --help 2>&1 | head -5
```

Render `examples/cube-root.bel` with whatever invocation the tool documents; eyeball that the folded state matches the pre-restructure render (`cube-root.svg` in the repo root is the reference).

- [ ] **Step 5: Commit**

```bash
git add examples/ tests/test_e2e.ml tests/test_parse.ml
git commit -m "feat(examples): cube-root with panels and temps; def demo; spec corpus"
```

---

### Task 11: Docs sync

**Files:**
- Modify: `README.md` (quick example uses `--d1: …` — switch to `=`)
- Modify: `spec/SPECIFICATION.md` (binding syntax, provenance `"name"` note at §~444, new construct section)

**Interfaces:**
- Consumes: final language shape.
- Produces: no stale syntax anywhere greppable.

- [ ] **Step 1: Find stale syntax**

```bash
rg -n '\-\-[a-z0-9_]+:' README.md spec/ blog/ 2>/dev/null
rg -n '\.[a-z0-9_]+: ' README.md spec/ 2>/dev/null
```

- [ ] **Step 2: Fix README** — quick example bindings `:` → `=`. If the rendered SVGs embed source text, re-render them with `tools/fold2svg.mjs`.

- [ ] **Step 3: Update spec/SPECIFICATION.md**

- Binding separator section: `:` → `=`, note the shorthand RHS forms.
- Provenance section (~line 444): `"name"` now also carries qualified `p1.pq` names for instance creases and `null` for temps/naked applies; document the new `"step"` field.
- New section "Defs, instances, steps": one evaluation path (`def` never runs, `apply` only execution form, `export` reads only, `step` = display panel), closed scope = params + earlier defs, `$` = instance only, `_`-temps rebind and stay invisible. Link `docs/superpowers/specs/2026-07-02-step-macros-design.md` for rationale.

- [ ] **Step 4: Verify and commit**

Run: `dune test` then re-run the Step 1 greps.
Expected: tests green; greps silent (modulo table-formatting false positives like `|:---:|`).

```bash
git add README.md spec/SPECIFICATION.md
git commit -m "docs: sync README and language spec with def/apply/export/step"
```

---

### Task 12: Finish

- [ ] **Step 1: Full verification**

```bash
dune build 2>&1 | head -5    # expect: silent
dune test                    # expect: all green
```

Check `examples/README.md` — if it catalogs examples, add `def-diagonals.bel` and note the cube-root restructure.

- [ ] **Step 2: Use superpowers:finishing-a-development-branch**

PR to `main` on Forgejo via `tea`, authored as **toph** (not the charlie bot — memory note "Forgejo PR author identity"). Attach rendered PNGs (CP + folded) of `examples/cube-root.bel` and `examples/def-diagonals.bel` via the Forgejo assets API (memory note "FOLD rendering & PR screenshots"). PR description links `docs/superpowers/specs/2026-07-02-step-macros-design.md` and says `resolves #29, resolves #24`.
