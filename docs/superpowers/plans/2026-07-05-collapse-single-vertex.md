# Single-Vertex Collapse (`@collapse`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `@collapse` — a multi-crease fold at one interior vertex that jumps from the precreased flat state to the flat folded state (rabbit ear, waterbomb).

**Architecture:** New AST statement + parser rules; a new pure kernel module `lib/collapse.ml` (vertex checks via exact reflection closure, per-sector isometries, layer-order enumeration reusing `Fold_state.validity_error`); wiring in `eval.ml` following the `FoldAlong` pattern. No new subdivision — collapse requires material precreases, so faces are already split along every fold line.

**Tech Stack:** OCaml, dune, menhir (parser.mly), sedlex (lexer.ml), alcotest; exact arithmetic via `Num`/qqbar. Spec: `docs/superpowers/specs/2026-07-05-collapse-single-vertex-design.md` (read it first).

## Global Constraints

- All geometry exact (`Num`), no floats anywhere.
- Redundancy is NEVER an error (redundant `over` = no-op); only contradiction errors.
- `standing` parses but the evaluator errors: `standing folds are not yet supported`.
- Error messages: lowercase start, name the operands via `lstr`/`fstr`, match spec §Errors wording.
- Conventional commits; each task commits.
- Run tests with `dune test` from repo root (`/home/toph/Projects/beloch`).
- Examples must be load-bearing and carry no redundant clauses.

---

### Task 1: Grammar front-end — lexer, AST, parser

**Files:**
- Modify: `lib/lexer.ml` (keyword table, after `"step" -> STEP`)
- Modify: `lib/ast.ml` (new types + stmt arm)
- Modify: `lib/parser.mly` (tokens + rules)
- Test: `tests/test_parse.ml` (append cases)

**Interfaces:**
- Produces AST types consumed by Task 3:
  ```ocaml
  type collapse_elem = { cline : line_operand; cdir : direction }
  (* in stmt: *)
  | Collapse of collapse_elem list * (flap_arg * flap_arg) list
              * flap_arg option * Error.span
    (* elements, over-pairs (upper, lower), standing flap *)
  ```

- [ ] **Step 1: Write failing parse tests** — append to `tests/test_parse.ml` (mirror the existing test style in that file; check how existing cases assert, e.g. via `Beloch.parse_string` and pattern-match):

```ocaml
let test_collapse_basic () =
  let prog = parse "paper square\n@collapse --a and --b and --c and --e mountain" in
  match List.rev prog with
  | Ast.Collapse (elems, [], None, _) :: _ ->
      Alcotest.(check int) "4 elements" 4 (List.length elems);
      let dirs = List.map (fun (e : Ast.collapse_elem) -> e.Ast.cdir) elems in
      Alcotest.(check bool) "last is mountain"
        true (List.nth dirs 3 = Ast.Mountain && List.nth dirs 0 = Ast.Valley)
  | _ -> Alcotest.fail "expected Collapse"

let test_collapse_parens_at_over_standing () =
  let prog = parse
    "paper square\n\
     @collapse --a at .a and (--e at (.o and --(.a .b)) mountain) \
     .b over .d standing .m" in
  match List.rev prog with
  | Ast.Collapse ([ _; e2 ], [ (_, _) ], Some _, _) :: _ ->
      Alcotest.(check bool) "parenthesized elem is mountain"
        true (e2.Ast.cdir = Ast.Mountain)
  | _ -> Alcotest.fail "expected Collapse with over + standing"
```

- [ ] **Step 2: Run to verify failure** — `dune test 2>&1 | head -30`. Expected: compile error (no `Collapse` constructor) — that counts as the failing state.

- [ ] **Step 3: Implement.**

`lib/lexer.ml` — add three keywords next to the existing ones:
```ocaml
  | "collapse" -> COLLAPSE
  | "over" -> OVER
  | "standing" -> STANDING
```

`lib/ast.ml` — after `type fold_spec`:
```ocaml
type collapse_elem = { cline : line_operand; cdir : direction }
```
and the new `stmt` arm as in Interfaces above (document: over-pair = (upper flap, lower flap)).

`lib/parser.mly`:
```
%token COLLAPSE OVER STANDING
```
body_stmt arm:
```
  | AT COLLAPSE collapse_elems over_clauses standing_opt
      { Collapse ($3, $4, $5, $loc) }
```
rules:
```
collapse_elems:
  | collapse_elem                     { [ $1 ] }
  | collapse_elem AND collapse_elems  { $1 :: $3 }

collapse_elem:
  | LPAREN collapse_elem RPAREN { $2 }
  | line_operand mountain_opt
      { { cline = $1; cdir = (if $2 then Mountain else Valley) } }

over_clauses:
  |                                        { [] }
  | flap_arg OVER flap_arg over_clauses    { ($1, $3) :: $4 }

standing_opt:
  |                   { None }
  | STANDING flap_arg { Some $2 }
```

**Known risk:** menhir may report an LR(1) conflict between `over_clauses`' leading `flap_arg` (starts with `POINT`) and a following statement `POINT EQ …`. If it does: the fix is to key the clause on its keyword — swap to `OVER flap_arg ONTO flap_arg`? No — stay with the approved surface syntax and instead inline the pair into the collapse rule with explicit lookahead-friendly factoring:
```
over_clauses:
  |                                     { [] }
  | over_clause over_clauses            { $1 :: $2 }
over_clause:
  | flap_arg OVER flap_arg              { ($1, $3) }
```
(same language, gives menhir a smaller conflict surface). If a genuine conflict remains, report it in the task summary with the `.conflicts` excerpt — do NOT silently change the surface syntax; that needs a user decision.

- [ ] **Step 4: Run tests** — `dune test`. Expected: PASS (all suites).
- [ ] **Step 5: Commit** — `git add -A lib tests && git commit -m "feat(parser): @collapse statement — elements, over, standing"`

---

### Task 2: Kernel — `lib/collapse.ml` (vertex math + enumeration)

**Files:**
- Create: `lib/collapse.ml`
- Test: `tests/test_collapse.ml` (new suite; add to `tests/dune`)

**Interfaces:**
- Consumes: `Fold_state.t`, `Geom`, `Num`, `Isometry`, `Layer_order`.
- Produces (consumed by Task 3):
  ```ocaml
  type elem = {
    cid : int;                (* crease bundle id *)
    ea : Geom.point;          (* segment endpoints, TABLE space *)
    eb : Geom.point;
    valley : bool;
  }
  val collapse :
    Fold_state.t -> elem list -> over:(int * int) list ->
    (Fold_state.t, string) result
  (* over: (upper_face, lower_face) PRE-collapse face indices *)
  ```
  All failure modes return `Error msg` with the spec's message text; the caller attaches the span.

- [ ] **Step 1: Write failing unit tests** — `tests/test_collapse.ml`. Build tiny states directly with the evaluator (`Beloch.fold_string` is e2e; for unit level use `Fold_state.init_square` + `Fold_state.subdivide` along four lines through an interior point). Concrete first tests — waterbomb-like symmetric cross at the center (angles 45°, rational coordinates, no qqbar needed):

```ocaml
open Beloch

let q = Num.of_int
let half = Num.div Num.one (q 2)
let pt x y = { Geom.x; Geom.y }
let o = pt half half

(* the four full lines: two diagonals + horizontal + vertical through center *)
let lines = [
  Geom.line_through (pt (q 0) (q 0)) (pt (q 1) (q 1));
  Geom.line_through (pt (q 1) (q 0)) (pt (q 0) (q 1));
  Geom.line_through (pt (q 0) half) (pt (q 1) half);
  Geom.line_through (pt half (q 0)) (pt half (q 1));
]

let precreased () =
  List.fold_left
    (fun (st, cids) l ->
      let cid = Fold_state.fresh_crease_id () in
      (Fold_state.subdivide ~crease_id:cid st l ~prov:None, cid :: cids))
    (Fold_state.init_square, []) lines

(* 8 rays from center: elems for the waterbomb MV (verify the exact
   assignment empirically in Step 4 against Maekawa + enumeration;
   start with diagonal rays mountain, axis rays valley and iterate) *)
let test_closure_holds () = (* reflection product = identity for the 8 rays *) ...
let test_odd_count_rejected () = ...
let test_no_common_vertex_rejected () = ...
let test_kawasaki_rejected () =
  (* replace one axis line by a line through center at a non-mirrored angle:
     line through (1/2,1/2) and (1,1/4); closure must fail *) ...
let test_maekawa_rejected () = (* all-valley on the symmetric cross *) ...
```
Write each `...` as a real assertion against `Collapse.collapse` returning `Error`/`Ok` (message via `Alcotest.(check string)` prefix match with `Astring.String.is_prefix` or plain `String.length` slice — follow whatever test_fold_state.ml already uses for message checks).

`tests/dune` — append:
```
(test
 (name test_collapse)
 (libraries beloch alcotest zarith str))
```

- [ ] **Step 2: Run** — `dune test 2>&1 | head -30`. Expected: compile failure (`Collapse` module absent).

- [ ] **Step 3: Implement `lib/collapse.ml`.** Structure (write it complete; the geometry helpers below are the intended algorithms):

```ocaml
(** Single-vertex collapse: fold along n >= 4 material crease segments sharing
    one interior endpoint O — the flat end state of a multi-crease move
    (rabbit ear [hull2020, Thm 8.5]). Skips the 3D intermediate entirely:
    checks the end state exists (reflection closure = Kawasaki, Maekawa),
    assigns per-sector isometries, enumerates valid layer orders. *)

type elem = { cid : int; ea : Geom.point; eb : Geom.point; valley : bool }

(* 1. common vertex: a point equal to one endpoint of EVERY elem *)
let common_vertex (es : elem list) : Geom.point option = ...

(* 2. rays: (dir vector = other endpoint - O, elem). Sort CCW by exact
   angular comparator: half classification (sign of dy, then dx) first,
   then cross product within a half. *)
let sort_ccw (o : Geom.point) (es : elem list) : (Geom.point * elem) list = ...

(* 3. closure: with rays r1..rn CCW and Li = line through O along ri,
   the folded image of sector k is T_k = R(L1) ∘ R(L2) ∘ ... ∘ R(Lk),
   T_0 = identity. Flat-foldable at O  ⟺  T_n = identity.
   Test identity exactly: apply to two non-collinear probe points. *)
let sector_isometries (o : Geom.point) (rays : ...) : Isometry.t array = ...
let closure_ok (isos : Isometry.t array) : bool = ...

(* 4. sector membership of a face: interior representative = vertex average
   (convex ⇒ interior). After closure, every sector angle < π, so:
   in sector k  ⟺  cross(r_k, p−O) > 0 ∧ cross(r_{k+1}, p−O) ≥ 0 …
   handle the wrap and the boundary-on-ray case (faces adjacent to a ray:
   representative is strictly inside a sector because faces were subdivided
   along every ray — assert if a representative lands exactly on a ray). *)
let sector_of : ... = ...

(* 5. new faces: face f in sector k gets iso' = T_k ∘ f.iso.
   Within-sector pair rel: preserved if det(T_k) > 0 else negated.
   Cross-sector pair rel: from the candidate sector stacking. *)

(* 6. hinge constraints: for consecutive sectors k, k+1 folded onto each
   other across ray_{k+1}'s element: valley (as stated by the user,
   relative to the current up side of the LEFT face, i.e. the
   fold_with_records parity convention:
     effective_valley = elem.valley <> (Isometry.det_sign old_iso < 0))
   forces sector k+1 Above sector k near the hinge; mountain the reverse.
   These prune the enumeration. *)

(* 7. enumeration: permutations of the n sectors (n ≤ 8 realistic; prune
   with hinge constraints while building). For each candidate stacking,
   build the face-level order via Fold_state.build_order with the rel_of
   above and run Fold_state.validity_error. Collect ALL valid stackings. *)

(* 8. eassign upgrade: every edge of an elem's cid lying ON that elem's
   segment (both endpoints within [O, boundary-end], exact seg_param
   bounds) gets V/M by the parity rule from step 6; other segments of the
   same bundle stay untouched (U marks). *)

(* 9. normalization: after picking the stacking, find the bottom face's
   sector b and left-compose every face iso with (T_b)⁻¹ so the
   table-contact sector keeps the identity — deterministic placement. *)

let collapse (st : Fold_state.t) (es : elem list)
    ~(over : (int * int) list) : (Fold_state.t, string) result =
  (* order of checks = order of spec error table: *)
  (* common vertex (+ interior: Fold_state.on_paper strictly — reject O on
     the sheet boundary: every ray must have paper on both sides locally;
     simplest exact test: O must be interior to the union = not on the
     square boundary; use the paper polygon of any face containing O) *)
  (* n even >= 4 (n = 2 → "use @fold" hint; odd → Maekawa cannot hold) *)
  (* segment far-endpoints on the sheet boundary *)
  (* closure_ok → else "vertex is not flat-foldable: sector angles violate
     Kawasaki" *)
  (* Maekawa: |#M − #V| = 2 *)
  (* enumerate; 0 valid → "the mountain/valley assignment forces the paper
     to self-intersect"; filter by over-pairs (sector of upper Above sector
     of lower); 0 after filter → "over contradicts every valid stacking";
     > 1 → "ambiguous stacking (k valid orders); add `X over Y`";
     1 → build state, normalize, Ok *)
  ...
```

Implementation notes for the engineer:
- `Geom.line_through`, `Geom.side_of_line`, `Geom.seg_param`, `Geom.point_equal`, `Num.sign/compare/sub/mul` exist — read `lib/geom.ml` before writing.
- `Isometry.reflect_across_line`, `compose`, `identity`, `inverse`, `det_sign`, `apply_point` exist (see `lib/isometry.ml`).
- Redundant `over` (consistent with the unique stacking) must be a silent no-op — filter, don't count.
- Permutation enumeration: `n!` at n=8 is 40320 — fine. Prune with hinge constraints during generation, not after.

- [ ] **Step 4: Run tests, iterate** — `dune test 2>&1 | tail -20`. The waterbomb M/V test is *empirical*: if the initial guess fails Maekawa/enumeration, adjust the test's assignment until the checks pass, and cross-check the final assignment against [hull2020, ch. 5] (`rg -n "Maekawa" refs/hull2020.txt`). Record the verified assignment in a comment.
- [ ] **Step 5: Commit** — `git add lib/collapse.ml tests && git commit -m "feat(kernel): single-vertex collapse — closure, Maekawa, order enumeration"`

---

### Task 3: Evaluator wiring — `@collapse` in `eval.ml`

**Files:**
- Modify: `lib/eval.ml` (new `eval_stmt` arm after `Ast.FoldAlong`)
- Test: `tests/test_eval.ml` (error cases), reuses Task 2's kernel

**Interfaces:**
- Consumes: `Collapse.collapse`, `Collapse.elem`, Task 1's AST.
- Produces: working end-to-end `@collapse` for Task 4's examples.

- [ ] **Step 1: Failing eval tests** — append to `tests/test_eval.ml` (follow its existing `expect_error` helper style; read the file's head first):

```ocaml
(* standing → unsupported *)
"paper square\n--d = --(.a .c)\n@collapse --d and --d standing .a"
  → error prefix "standing folds are not yet supported"
(* n = 2 → hint *)
… → error containing "use @fold"
(* constructed line operand → not material *)
"@collapse --(.a .c) and …" → error "collapse folds along existing creases"
```
(Three `Alcotest` cases with real programs; the n=2 case needs two real material creases through one point — two diagonals of the square, `--d1 = --(.a .c)` `--d2 = --(.b .d)`, then `@collapse --d1 at .a and --d2 at .b` — 2 elements → count error.)

- [ ] **Step 2: Run** — expect compile failure (non-exhaustive match on `Ast.Collapse`).

- [ ] **Step 3: Implement the arm** in `eval_stmt`:

```ocaml
| Ast.Collapse (elems, overs, standing_opt, span) ->
    (match standing_opt with
    | Some _ -> Error.fail span "standing folds are not yet supported"
    | None -> ());
    (* each element must resolve to exactly ONE material segment *)
    let resolve_elem (el : Ast.collapse_elem) : Collapse.elem =
      let fail_not_material () =
        Error.fail span
          (Printf.sprintf
             "collapse folds along existing creases; %s is not a material \
              crease" (lstr el.Ast.cline))
      in
      match el.Ast.cline with
      | Ast.LAt (cr, sels, aspan) -> (
          match at_matches cr sels aspan with
          | cid, [ s ] ->
              { Collapse.cid; ea = s.Fold_state.ta; eb = s.Fold_state.tb;
                valley = (el.Ast.cdir = Ast.Valley) }
          | _, [] -> Error.fail aspan (…no-segment message, reuse wording…)
          | _, many -> Error.fail aspan (…ambiguous message, reuse wording…))
      | Ast.LNamed cr -> (
          let cid = material_cid cr in
          match Fold_state.crease_segments !(ctx.state) cid with
          | [ s ] -> { Collapse.cid; ea = s.Fold_state.ta;
                       eb = s.Fold_state.tb;
                       valley = (el.Ast.cdir = Ast.Valley) }
          | [] -> Error.fail span (Printf.sprintf
                    "--%s has no material segment" cr.Ast.cname)
          | segs -> Error.fail span (Printf.sprintf
                    "--%s has %d segments; select one with `at`"
                    cr.Ast.cname (List.length segs)))
      | _ -> fail_not_material ()
    in
    let es = List.map resolve_elem elems in
    let over =
      List.map (fun (u, l) ->
          (resolve_flap_face u span, resolve_flap_face l span)) overs
    in
    (match Collapse.collapse !(ctx.state) es ~over with
    | Ok st -> ctx.state := st
    | Error msg -> Error.fail span msg)
```
(The exact reused messages: copy the `at_matches` empty/ambiguous wording from `resolve_line`'s `LAt` arm — same strings, one place each.)

- [ ] **Step 4: Run** — `dune test`. Expected: PASS.
- [ ] **Step 5: Commit** — `git add lib/eval.ml tests/test_eval.ml && git commit -m "feat(eval): wire @collapse — element resolution, over, standing guard"`

---

### Task 4: Rabbit-ear example + goldens (incl. error goldens)

**Files:**
- Create: `examples/bases/rabbit-ear.bel`
- Create: `examples/syntax/collapse-errors-*.bel` (one per error case worth a golden: `collapse-kawasaki.bel`, `collapse-all-valley.bel`, `collapse-standing.bel`)
- Create: matching `tests/golden/bases/rabbit-ear.fold`, `tests/golden/syntax/collapse-*.fold`

**Interfaces:** none new — proves Tasks 1–3 end-to-end.

- [ ] **Step 1: Write `examples/bases/rabbit-ear.bel`** (starting point — the `toward` selectors are validated empirically in Step 2):

```
paper square

; triangle .a .b .m — .m = midpoint of the top edge
--v = map .a onto .b
.m = .(--v --(.d .c))

step precrease
--ba = map --(.a .b) onto --(.a .m) toward .m   ; bisector at .a
--bb = map --(.b .a) onto --(.b .m) toward .m   ; bisector at .b
.o = .(--ba --bb)                               ; incenter
--bm = --(.m .o)                                ; third bisector (Rabbit-Ear Thm)
--e = perp --(.a .b) through .o                 ; ear crease

step collapse
@collapse --ba at .a and --bb at .b and --bm at .m
  and (--e at (.o and --(.a .b)) mountain)
```

- [ ] **Step 2: Run it and iterate** — build a quick driver: `dune exec bin/… -- examples/bases/rabbit-ear.bel` (check `bin/` for the CLI entrypoint name first; `rg -n "fold_string" bin/`). Iterate until it evaluates cleanly:
  - axiom-5 binds may need different/no `toward` (paper-incidence filter may already disambiguate — if a bare bind works, DROP the `toward`: no redundant clauses);
  - the `at` selectors on `--ba`/`--bb`: if the bundle has only one segment on the triangle side, `at .a` may be redundant → then drop it (but the far side beyond `.o` exists by construction, so `at` should be load-bearing — verify, don't assume);
  - if the collapse reports ambiguous stacking, add the minimal `over` and note WHICH orders were offered in the example comment.
- [ ] **Step 3: Render and eyeball** — `node tools/fold2svg.mjs examples/bases/rabbit-ear.bel /tmp/claude-1000/…/rabbit-ear.svg` (check the tool's actual CLI args in its header first). The folded form must show the classic rabbit ear: kite-like silhouette, ear flap lying flat to one side. If the ear points the wrong way or a flap order looks impossible, debug BEFORE freezing goldens — `superpowers:systematic-debugging`.
- [ ] **Step 4: Error examples** — three tiny `.bel` files that fail with the new messages (Kawasaki: four creases through the center at non-Kawasaki angles, e.g. both diagonals + vertical + a line through center and `(1, 1/4)`… simplest: diagonals + vertical + horizontal is VALID, so instead use diagonals + vertical only at wrong MV for `collapse-all-valley.bel`; for `collapse-kawasaki.bel` replace the horizontal by `--(.(cross …) …)` through an off-angle boundary point). Each file header-comments its intent (`; status: errors — <which check>`).
- [ ] **Step 5: Freeze goldens** — the golden test names the regen mechanism (`run the regen step`): `rg -n "regen" tests/ Justfile justfile Makefile 2>/dev/null` and use the project's regen command; verify `dune test` passes afterward and `git diff --stat` shows ONLY new goldens.
- [ ] **Step 6: Commit** — `git add examples tests/golden && git commit -m "feat(examples): rabbit-ear base + collapse error goldens"`

---

### Task 5: Waterbomb example (n = 8, `over` if load-bearing)

**Files:**
- Create: `examples/bases/waterbomb.bel`
- Create: `tests/golden/bases/waterbomb.fold`

- [ ] **Step 1: Write it** — both diagonals + both center lines precreased (all axiom-1/2 binds), then `@collapse` of the 8 rays at the center with the M/V assignment verified in Task 2 Step 4. Use `at`-selectors per ray (each full line contributes 2 rays = 2 elements, selected by corner/edge-midpoint incidence).
- [ ] **Step 2: Iterate empirically** exactly as Task 4 Step 2. If stacking is ambiguous, the minimal `over` chain IS the load-bearing demo — keep it and comment the alternative it excludes. If it's unique, waterbomb ships without `over` and the `over` grammar stays covered by parse tests only (fine for v1 — note it in the PR text).
- [ ] **Step 3: Render, freeze golden, `dune test`.**
- [ ] **Step 4: Commit** — `git commit -m "feat(examples): waterbomb base — n=8 collapse"`

---

### Task 6: Spec + docs

**Files:**
- Modify: `spec/SPECIFICATION.md` (new §: `@collapse`, version headline → v0.20-dev with one-line summary, matching the existing per-version pattern in line 18)
- Modify: `docs/superpowers/specs/2026-07-05-collapse-single-vertex-design.md` (only if implementation deviated — record deviations, don't rewrite)

- [ ] **Step 1:** Write the spec section: syntax grammar block, resolution rules, check order, error table, `over`/`standing` clauses, the all-layers rule, the sector-block enumeration limitation (no tucking between another sector's layers — follow-up), lint-not-error rule for redundant `over`. Cite [hull2020, Thm 8.5; ch. 5; §6.6 Thm 6.17] and [demaine2007, §14.1.1].
- [ ] **Step 2:** `dune test` still green (spec is prose, but goldens catch accidental example edits).
- [ ] **Step 3: Commit** — `git commit -m "docs(spec): @collapse — single-vertex collapse (v0.20-dev)"`

---

### Task 7: Branch hygiene + PR

- [ ] **Step 1:** All work should have happened on branch `collapse-single-vertex` (create at Task 1 start: `git checkout -b collapse-single-vertex` — if you are reading this at Task 1, do it NOW before the first commit).
- [ ] **Step 2:** `dune test` full green; `git log --oneline main..` shows the task commits.
- [ ] **Step 3:** Render PR images (rabbit-ear CP + folded, waterbomb folded) per the screenshot discipline: inline `.bel` code next to images, load-bearing contrast. Push assets via the `assets/pr-*` branch pattern (GitHub origin — see memory note: blob URL + `?raw=true`).
- [ ] **Step 4:** `gh pr create` with the writing-style guide loaded (`~/.claude/WRITING_STYLE.md`); body: what/why, spec link, error table, the sector-block limitation, follow-ups list from the spec.

---

## Self-Review (done at write time)

- **Spec coverage:** syntax ✓ (T1), resolution ✓ (T3), checks ✓ (T2), enumeration + over ✓ (T2/T3), standing guard ✓ (T3), all-layers — *implicit* in T2 (faces classified per sector regardless of layer; congruence enforced by "every ray must be material through the region"; if T2 finds this under-specified, the check is: every face overlapping the vertex region in table space must be bounded by material edges on the rays — add it then), examples ✓ (T4/T5), errors table ✓ (T2/T3/T4), spec §  ✓ (T6), lint — NOT implemented (no #64 infra yet; spec notes it as TODO; deliberate).
- **Placeholders:** the `...` bodies in Task 2 are algorithm-annotated stubs — the annotations ARE the algorithm (comparator, closure, membership, parity rule, enumeration+prune). Deviation from "complete code" is deliberate: exact OCaml against unread `Geom` internals would be fiction; the notes pin every decision that matters. Same for Task 4's empirical `toward` iteration — the spec's example discipline forbids freezing unverified clauses.
- **Type consistency:** `Collapse.elem` fields (`cid`/`ea`/`eb`/`valley`) match between T2 definition and T3 use ✓; `Ast.collapse_elem` (`cline`/`cdir`) between T1 and T3 ✓; over-pair order (upper, lower) stated in both ✓.
