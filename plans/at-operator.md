# `at` operator — crease-segment selection (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the `at` operator so a named crease (a *bundle* of segments) can be projected to a single segment by incidence — `--l at .p`, `--l at --a`, `--l at #(…)`, and the two-selector form `--l at (.p and --a)` — replacing the old `--( --d #(…) )` (`LRestrict`) escape hatch.

**Architecture:** A crease name already denotes one `crease_id` realised as a set of table-space segments (one edge per crossed face; [ADR 0014](../decisions/0014-crease-is-a-bundle-of-segments.md)). `at` is a **query over the existing subdivision**: enumerate the bundle's segments, keep the ones incident to every selector, require exactly one (singleton-target rule), and return its supporting line. No new state — `Fold_state` edges already carry `crease_id` + endpoints. Three layers: a `Fold_state.crease_segments` enumerator (Task 1), the grammar + AST + evaluator (Task 2), and example/spec migration (Task 3).

**Tech Stack:** OCaml, Menhir (`lib/parser.mly`), sedlex (`lib/lexer.ml`), Alcotest (`tests/`), dune. Geometry is exact (`Num` over a real-algebraic backend); never introduce floats.

## Global Constraints

- **Exact geometry only.** All coordinates/comparisons go through `Geom`/`Num`. No `float`, no epsilons.
- **Incidence, not proximity.** `at` selects a segment the selector lies *on* (`Geom.side_of_line … = 0` + param in `[0,1]`). This is distinct from `toward` (proximity, construction-time). Do not unify them.
- **Singleton-target rule.** `at` yields exactly one segment. `0` matches → error "no segment …"; `>1` → error "ambiguous … add a selector". Never silently pick one.
- **Two-selector cap = 2.** The conjunction is exactly `selector and selector`. No three-way form.
- **`at` reserves the keyword.** After this lands, `at` is a reserved word (like `toward`/`moving`); it cannot be a bare `def`/member identifier.
- **`--( … )` means only `LThrough` after this.** The `LRestrict` production is removed entirely; `--(` is line-through-two-points only.

---

## File Structure

- `lib/fold_state.ml` — **add** `type crease_segment` + `crease_segments : t -> int -> crease_segment list` (enumerate a bundle's table-space segments). Leaf; no other change.
- `lib/lexer.ml` — **add** `"at" -> AT_KW`.
- `lib/parser.mly` — **add** `AT_KW` token; **add** `LAt` productions + a `selector` nonterminal; **remove** the `LRestrict` production.
- `lib/ast.ml` — **replace** `LRestrict` with `LAt of crease_ref * selector list * Error.span`; **add** `selector` type.
- `lib/eval.ml` — **replace** the `LRestrict` arm of `resolve_line` with an `LAt` arm (incidence resolution); **replace** the `LRestrict` case of `lstr` and **add** `selstr`.
- `examples/crease-flap-restrict.bel` — migrate `--( --b #(.c .d) )` → `--b at #(.c .d)`.
- `spec/SPECIFICATION.md` — Appendix A grammar: add `at` to `line_operand` + a `selector` production; add a prose subsection §4.8; trim the Appendix B bullet.
- Tests: `tests/test_fold_state.ml` (Task 1), `tests/test_parse.ml` + `tests/test_eval.ml` (Task 2).

Only `lib/ast.ml` and `lib/eval.ml` reference `LRestrict` / match on `line_operand` (verified with `rg -ln "LRestrict|line_operand" lib/*.ml`), so removing `LRestrict` cannot break other modules.

---

### Task 1: `Fold_state.crease_segments` — enumerate a bundle's segments

**Files:**
- Modify: `lib/fold_state.ml` (add after `crease_table_endpoints`, ~`:271`)
- Test: `tests/test_fold_state.ml`

**Interfaces:**
- Produces:
  ```ocaml
  type crease_segment = { faces : int * int; ta : Geom.point; tb : Geom.point }
  val crease_segments : t -> int -> crease_segment list
  ```
  One entry per edge tagged `cid` with a real left face; `faces = (left, right)` (`right = -1` on the paper boundary); `ta`/`tb` are the segment's **table-space** endpoints via the left face's isometry. Degenerate (zero-length) edges are dropped.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_fold_state.ml` (reuse the file's existing `pt`/`q` helpers; if none, add `let pt x y = { Geom.x = Num.of_int x; y = Num.of_int y }`):

```ocaml
let test_crease_segments_diagonal () =
  let cid = Fold_state.fresh_crease_id () in
  let axis = Geom.line_through (pt 0 0) (pt 1 1) in
  let st = Fold_state.subdivide ~crease_id:cid Fold_state.init_square axis ~prov:None in
  match Fold_state.crease_segments st cid with
  | [ s ] ->
      let a = s.Fold_state.ta and b = s.Fold_state.tb in
      Alcotest.(check bool)
        "segment endpoints are the (0,0)-(1,1) diagonal" true
        ((Geom.point_equal a (pt 0 0) && Geom.point_equal b (pt 1 1))
        || (Geom.point_equal a (pt 1 1) && Geom.point_equal b (pt 0 0)))
  | other -> Alcotest.failf "expected exactly 1 segment, got %d" (List.length other)
```

Register it in this file's Alcotest test list (find the `("fold_state", [ … ])` list and add `Alcotest.test_case "crease_segments diagonal" `Quick test_crease_segments_diagonal;`).

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | head -40`
Expected: FAIL — `Unbound value Fold_state.crease_segments` (compile error).

- [ ] **Step 3: Implement `crease_segments`**

In `lib/fold_state.ml`, immediately after `crease_table_endpoints` (the `let crease_axis` currently follows it), add:

```ocaml
type crease_segment = { faces : int * int; ta : Geom.point; tb : Geom.point }

(* Every material segment of crease [cid], in table space. One entry per edge
   tagged [cid] with a real left face; endpoints via the left face isometry
   (the two faces coincide along the crease, so left is canonical). Degenerate
   edges are dropped. *)
let crease_segments (st : t) (cid : int) : crease_segment list =
  Array.fold_left
    (fun acc e ->
      if e.crease_id = cid && e.left >= 0 then
        let iso = st.faces.(e.left).iso in
        let ta = Isometry.apply_point iso e.ea
        and tb = Isometry.apply_point iso e.eb in
        if Geom.point_equal ta tb then acc
        else { faces = (e.left, e.right); ta; tb } :: acc
      else acc)
    [] st.edges
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dune test 2>&1 | head -40`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/fold_state.ml tests/test_fold_state.ml
git commit -m "feat(fold-state): enumerate a crease bundle's segments (#50)"
```

---

### Task 2: grammar + AST + evaluator — the `at` operator

**Files:**
- Modify: `lib/lexer.ml:16` area (keywords), `lib/parser.mly:5` (token) + `:103-107` (`line_operand`), `lib/ast.ml:24-31`, `lib/eval.ml:116-124` (`lstr`) + `:184-202` (`resolve_line`)
- Test: `tests/test_parse.ml`, `tests/test_eval.ml`

**Interfaces:**
- Consumes: `Fold_state.crease_segment`, `Fold_state.crease_segments` (Task 1); `Fold_state.flap_of_points`, `Fold_state.table_position` (existing); `Geom.{line_through,side_of_line,seg_param,intersection,point_equal}`; `Num.{compare,zero,one}`.
- Produces (AST):
  ```ocaml
  and line_operand =
    | LNamed of crease_ref
    | LThrough of point_operand * point_operand * Error.span
    | LMember of string * string * Error.span
    | LAt of crease_ref * selector list * Error.span
  and selector =
    | SelPoint of point_operand
    | SelLine of line_operand
    | SelFlap of flap_operand
  ```

- [ ] **Step 1: Write the failing parse + eval tests**

Add to `tests/test_parse.ml`:

```ocaml
let test_parse_at_one_selector () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--b = through .a .c\nperp --b at .a through .c\n"
  in
  match prog with
  | [ Ast.Crease (Some "b", _, _, _);
      Ast.Crease
        (None, Ast.Perp (_, Ast.LAt (_, [ Ast.SelPoint _ ], _)), _, _) ] -> ()
  | _ -> Alcotest.fail "expected LAt with one point selector"

let test_parse_at_two_selectors () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--b = through .a .c\nperp --b at (.a and --b) through .c\n"
  in
  match prog with
  | [ _;
      Ast.Crease
        ( None,
          Ast.Perp (_, Ast.LAt (_, [ Ast.SelPoint _; Ast.SelLine _ ], _)),
          _, _ ) ] -> ()
  | _ -> Alcotest.fail "expected LAt with two selectors"
```

Add to `tests/test_eval.ml`:

```ocaml
(* the migrated crease-flap-restrict scenario: select --b's piece on the upper
   flap with `at #(.c .d)` and cross it with --v — must evaluate cleanly. *)
let test_eval_at_flap () =
  ignore
    (Eval.eval_folded
       (Beloch.parse ~filename:"t.bel"
          "paper square\n\
           --b = through .a .c\n\
           --v = @map .c onto .b moving .c\n\
           .mid = cross --b at #(.c .d) --v\n\
           map .d onto .mid\n"))

(* a bare bent bundle still errors — that is what `at` exists to fix *)
let test_eval_bent_bundle_errors () =
  expect_error "no longer straight" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --b = through .a .c\n\
               --v = @map .c onto .b moving .c\n\
               .mid = cross --b --v\n\
               map .d onto .mid\n")))

(* a selector that lands on no segment of the bundle is the 0-match error *)
let test_eval_at_no_match () =
  expect_error "no segment" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --b = through .a .c\n\
               --v = @map .c onto .b moving .c\n\
               .mid = cross --b at .b --v\n\
               map .d onto .mid\n")))
```

Register all five in their files' Alcotest lists (`("parse", [ … ])` and `("eval", [ … ])`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `dune test 2>&1 | head -40`
Expected: FAIL — `Ast.LAt`/`Ast.SelPoint` unbound (compile error), because the AST/grammar do not exist yet.

- [ ] **Step 3: AST — replace `LRestrict` with `LAt` + `selector`**

In `lib/ast.ml`, edit the `line_operand` variant (currently `:24-31`). Replace the `LRestrict` constructor line with `LAt`, and add the `selector` type to the mutually-recursive block:

```ocaml
and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span
  | LMember of string * string * Error.span  (* instance, member *)
  | LAt of crease_ref * selector list * Error.span
    (* --l at S | --l at (S1 and S2): the unique segment of bundle --l
       incident to every selector (singleton-target rule) *)

and selector =
  | SelPoint of point_operand
  | SelLine of line_operand   (* grammar produces only LNamed / LThrough here *)
  | SelFlap of flap_operand

and flap_operand = FByPoints of point_operand list * Error.span
  (* #(.a .b .c): the unique current flat flap containing all listed points *)
```

(Keep `flap_operand` — it now feeds `SelFlap`. Delete the old `LRestrict` line and its comment.)

- [ ] **Step 4: Lexer — reserve `at`**

In `lib/lexer.ml`, add among the keywords (e.g. right after `| "and" -> AND` at `:16`):

```ocaml
  | "at" -> AT_KW
```

- [ ] **Step 5: Parser — token, `LAt` productions, `selector`, drop `LRestrict`**

In `lib/parser.mly`:

Add `AT_KW` to the token declaration at `:5` (append to that `%token` line):

```
%token PAPER SQUARE THROUGH MAP ONTO CROSS EQ EOF PERP TOWARD AT MOVING MOUNTAIN FLIP LINE_OPEN POINT_OPEN FLAP_OPEN RPAREN AND AT_KW
```

Replace the `line_operand` rule (`:103-107`) with:

```
line_operand:
  | crease_ref { LNamed $1 }
  | LINE_OPEN point_operand point_operand RPAREN { LThrough ($2, $3, $loc) }
  | crease_ref AT_KW selector { LAt ($1, [ $3 ], $loc) }
  | crease_ref AT_KW LPAREN selector AND selector RPAREN { LAt ($1, [ $4; $6 ], $loc) }
  | LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET { LMember ($2, $3, $loc) }

selector:
  | point_operand { SelPoint $1 }
  | crease_ref    { SelLine (LNamed $1) }
  | LINE_OPEN point_operand point_operand RPAREN { SelLine (LThrough ($2, $3, $loc)) }
  | flap_operand  { SelFlap $1 }
```

The old `| LINE_OPEN crease_ref flap_operand RPAREN { LRestrict … }` line is deleted. `flap_operand` (`:109-110`) stays — it now feeds `selector`.

Why this is conflict-free: `AT_KW ∉ FOLLOW(line_operand)`, so after `crease_ref` a lookahead of `AT_KW` has only the shift action (into `LAt`); every other lookahead reduces to `LNamed`. The two-selector `and` sits between `LPAREN … RPAREN`, so it never competes with axiom 7's `and` (the bare one-selector form is never followed by `and` inside an `LAt`).

- [ ] **Step 6: Evaluator — `lstr`/`selstr` and the `LAt` arm**

In `lib/eval.ml`, in the `let rec pstr … and lstr … in` block (`:110-124`), replace the `LRestrict` case of `lstr` and add `selstr` to the same recursive group:

```ocaml
  and lstr (lo : Ast.line_operand) : string =
    match lo with
    | Ast.LNamed cr -> "--" ^ cr.Ast.cname
    | Ast.LThrough (p1, p2, _) -> Printf.sprintf "--(%s %s)" (pstr p1) (pstr p2)
    | Ast.LMember (i, m, _) -> Printf.sprintf "--[$%s %s]" i m
    | Ast.LAt (cr, sels, _) -> Printf.sprintf "--%s at %s" cr.Ast.cname (selstr sels)
  and selstr (sels : Ast.selector list) : string =
    let one = function
      | Ast.SelPoint po -> pstr po
      | Ast.SelLine lo -> lstr lo
      | Ast.SelFlap (Ast.FByPoints (pts, _)) ->
          Printf.sprintf "#(%s)" (String.concat " " (List.map pstr pts))
    in
    match sels with
    | [ s ] -> one s
    | ss -> Printf.sprintf "(%s)" (String.concat " and " (List.map one ss))
  in
```

Then replace the `LRestrict` arm of `resolve_line` (`:184-202`) with:

```ocaml
    | Ast.LAt (cr, sels, span) ->
        let cid =
          match lookup_crease ctx cr with
          | Material (cid, _) -> cid
          | Frozen _ ->
              Error.fail cr.Ast.cspan
                (Printf.sprintf
                   "--%s is not a physical crease, so it has no segments to \
                    select" cr.Ast.cname)
        in
        let segs = Fold_state.crease_segments !(ctx.state) cid in
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
              match
                Fold_state.flap_of_points !(ctx.state)
                  (List.map resolve_point pts)
              with
              | `Face fi ->
                  let l, r = s.Fold_state.faces in
                  l = fi || r = fi
              | `Zero -> Error.fail fspan "those points aren't all on one flap"
              | `Ambiguous -> Error.fail fspan "ambiguous flap; add another point")
        in
        let matches =
          List.filter
            (fun s -> List.for_all (fun sel -> incident sel s) sels)
            segs
        in
        (match matches with
         | [ s ] -> seg_line s
         | [] ->
             Error.fail span
               (Printf.sprintf "no segment of --%s matches %s" cr.Ast.cname
                  (selstr sels))
         | many ->
             Error.fail span
               (Printf.sprintf
                  "--%s at %s is ambiguous: %d segments match; add a selector"
                  cr.Ast.cname (selstr sels) (List.length many)))
```

- [ ] **Step 7: Build — verify no new parser conflicts**

Run: `dune build 2>&1 | head -40`
Expected: clean build, **no** menhir conflict warnings. If menhir reports a shift/reduce on `AT_KW` or `AND`, stop — the grammar shape above is designed to be conflict-free; a warning means a typo (most likely `selector` still allowing a bare `line_operand` that can be `LAt`). Fix before proceeding.

- [ ] **Step 8: Run tests to verify they pass**

Run: `dune test 2>&1 | head -60`
Expected: PASS for all five new tests, and no regression in the rest.

- [ ] **Step 9: Commit**

```bash
git add lib/ast.ml lib/lexer.ml lib/parser.mly lib/eval.ml tests/test_parse.ml tests/test_eval.ml
git commit -m "feat(lang): at operator — select a crease segment by incidence (#50)

Replaces the --( --d #(...) ) restrict escape hatch. One selector bare
(--l at .p), two parenthesised (--l at (.p and --a)); point/line/flap
selectors, singleton-target rule with 0/>1 errors."
```

---

### Task 3: migrate all old-syntax users + spec

**Files:**
- Modify: `examples/crease-flap-restrict.bel`
- Modify: `tests/test_e2e.ml` (the "flap restriction resolves" case still uses the removed `--( --d #(…) )` source syntax)
- Verify (do NOT hand-edit): `tests/golden/crease-flap-restrict.fold` — should stay byte-identical after migration
- Modify: `spec/SPECIFICATION.md` (Appendix A grammar `:687-689`; new §4.8; Appendix B bullet `:721-726`)

**Context — three currently-red tests this task clears.** Task 2 removed the `--( --d #(…) )` production, so three tests that still use that *source syntax* fail: `fold_state 15` ("all examples evaluate" — iterates `examples/*.bel`), `e2e 23` ("flap restriction resolves" — a `.bel` string in `tests/test_e2e.ml`), and `golden examples 5` ("crease-flap-restrict.bel FOLD unchanged"). The `LRestrict` OCaml constructor is gone from the code, but these three carry the syntax in `.bel` text. All three must be green at the end of this task.

- [ ] **Step 1: Find every remaining old-syntax user**

Run: `rg -n "#\( *--|--\( *--" examples/ tests/`
Expected: `examples/crease-flap-restrict.bel` and a `.bel` string inside `tests/test_e2e.ml`. Migrate both. (The golden `.fold` is data, not source — do not grep-migrate it; it is validated in Step 4.)

- [ ] **Step 2: Migrate the example**

Edit `examples/crease-flap-restrict.bel`. Replace the restrict line and refresh the comment (keep the filename — golden output is byte-identical since `--b at #(.c .d)` resolves to the same segment as `--( --b #(.c .d) )`):

```
; status: works — a diagonal precrease then a half fold that BENDS it.
; Bare --b would error "no longer straight"; select its folded-flap SEGMENT
; (upper flap, corners .c/.d) with `at` and cross that with --v (#50).
paper square
--b = through .a .c
--v = @map .c onto .b moving .c
.mid = cross --b at #(.c .d) --v
map .d onto .mid
```

- [ ] **Step 3: Migrate the e2e test**

Open `tests/test_e2e.ml`, find the "flap restriction resolves" case (its `.bel` string contains `--( --b #(.c .d) )` or similar). Replace the `--( --<crease> #(…) )` construct with the equivalent `--<crease> at #(…)` form, keeping the rest of the program and every assertion identical — the migration is source-syntax only; the resolved geometry is unchanged, so the test's expected values must not change. If the test's title/comment names "restriction", you may leave it or reword to "at flap selection"; do not alter its assertions.

- [ ] **Step 4: Verify the migrated example + e2e + golden**

Run: `dune build 2>&1 | tail -3 && dune test 2>&1 | rg -i "fail|examples|e2e|golden" | head -20`
Expected: `fold_state 15`, `e2e 23`, and `golden examples 5` now pass; no new failures. The golden fixture (`tests/golden/crease-flap-restrict.fold`) must pass **without regeneration** — the migration changes only source syntax, so the emitted FOLD is byte-identical. If the golden test fails on a content diff (not a syntax error), STOP and report: a changed FOLD means the migration altered geometry, which is a bug — do not regenerate the golden to paper over it.

- [ ] **Step 5: Spec — Appendix A grammar**

In `spec/SPECIFICATION.md`, in the Appendix A grammar block, replace the `line_operand` production (`:687-688`) with the `at` forms and add a `selector` production directly below it:

```
line_operand  := CREASE_NAME | "--(" point_operand point_operand ")" ; named, or inline through
               | "--[" INSTANCE_NAME ident "]"                       ; qualified member (since v0.16-dev)
               | CREASE_NAME "at" selector                            ; crease segment by incidence (since v0.17-dev)
               | CREASE_NAME "at" "(" selector "and" selector ")"     ; two-selector disambiguation
selector      := point_operand | CREASE_NAME
               | "--(" point_operand point_operand ")" | "#(" point_operand+ ")"
```

- [ ] **Step 6: Spec — add §4.8 prose**

Add a new subsection after §4.7 (before Appendix or the next top-level section — find §4.7's end and insert):

```markdown
### 4.8 Selecting a crease segment: `at` *(since v0.17-dev)*

A crease name is a **bundle**: one crease realised as a set of segments — one per
layer the crease line crossed, further split by later creases. The segments are
collinear only in the folded moment of creation; once (un)folding scatters them
they point every which way in the crease pattern. So a crease name is not a single
line.

`--l at <selector>` projects the bundle down to the **one** segment incident to the
selector, and yields that segment's current supporting line (usable anywhere a line
operand is). Selectors, by incidence:

- `--l at .p` — the segment the point `.p` lies on.
- `--l at --a` — the segment whose span contains `--a`'s crossing of `--l`.
- `--l at #(.a .b …)` — the segment lying on that flap.

Selection is **incidence**, distinct from `toward`'s proximity (§4): `at` picks the
segment the selector is *on*; `toward` picks the construction nearer a point off the
result. `at` binds tighter than the axiom keywords: `perp --l at --a through .b`
reads as `perp (--l at --a) through .b`.

The result must be a **single** segment. No match is an error ("no segment of `--l`
matches …"); more than one is an error asking for a second selector. When one point
sits on a crease crossing (two adjacent segments share it), disambiguate with the
two-selector form `--l at (.p and --a)` — the unique segment incident to *both*.

`at` supersedes the earlier `--( --l #(…) )` restrict form. Creating a single
segment (rather than selecting one) is `pinch`, still forthcoming (Appendix B).
```

- [ ] **Step 7: Spec — trim Appendix B**

In `spec/SPECIFICATION.md` Appendix B (`:721-726`), edit the crease-segment bullet so only `pinch` remains deferred. Replace the parenthetical:

```
crease-segment *creation* (`pinch` — materialise one segment; the `at` selection
operator landed in v0.17-dev, [ADR 0014](../decisions/0014-crease-is-a-bundle-of-segments.md)) ·
```

- [ ] **Step 8: Full build + test**

Run: `dune build 2>&1 | head -20 && dune test 2>&1 | tail -20`
Expected: clean build, **all** tests pass — the three previously-red tests included, zero failures.

- [ ] **Step 9: Commit**

```bash
git add examples/crease-flap-restrict.bel tests/test_e2e.ml spec/SPECIFICATION.md
git commit -m "docs(spec): document the at operator; migrate restrict users (#50)"
```
(If the golden `.fold` legitimately did not change, it will not appear in `git status` — do not add it. If it did change, revisit Step 4: that is a bug, not a commit.)

---

## Self-Review notes

- **Spec coverage.** ADR 0014's `at` half — bundle model, singleton-target rule, incidence selection, point/line/flap selectors, two-selector disambiguation, supersedes-restrict — each maps to a task (grammar+eval in Task 2, prose in Task 3). The `pinch` half and the tooling slice (ambiguity enumeration / reachability / renderer highlight) are **out of scope** for this plan by design — separate slices of #50.
- **Deferred within `at`:** the ambiguity **error enumeration** (listing candidate segments with distinguishing attributes) from the at-operator note is the tooling slice, not this one. Here `>1` returns a count + "add a selector"; that is sufficient and honest.
- **Type consistency.** `crease_segment` fields (`faces`, `ta`, `tb`) are referenced identically in Task 1 (definition), its test, and Task 2's evaluator. `LAt`/`SelPoint`/`SelLine`/`SelFlap` names match across ast.ml, parser.mly, eval.ml, and both test files.
- **No placeholders.** Every code step carries the full text to write.
