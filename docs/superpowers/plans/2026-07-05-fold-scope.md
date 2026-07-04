# Fold Scope (`moving`, `up to`, `@fold`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement fold scope per `docs/superpowers/specs/2026-07-05-fold-scope-design.md`: flap-typed `moving`, the `up to` range scope (some-layers simple folds), and the `@fold` statement for folding along existing material creases.

**Architecture:** Beloch is an OCaml evaluator: sedlex lexer → Menhir parser → `Ast` → `Eval.eval_folded` drives `Fold_state` (faces + sparse `Layer_order` + crease edges) → `Fold_emit` (FOLD JSON). The fold currently reflects *everything* on one side of the axis (`fold_with_records ~move_side`). This plan adds an explicit moving *face set*: a stack-walk selection in `Fold_state` (`select_scope`), flap-operand resolution in `Eval`, and a new `FoldAlong` statement that reuses the existing crease-resolution (`at`) machinery for the axis.

**Tech Stack:** OCaml (dune), Menhir, sedlex, Alcotest, golden FOLD files under `tests/golden/`.

## Global Constraints

- **Base:** branch `feat/fold-scope` off **`origin/main`** (commit `f35a6b5`). Local `main` has diverged and MUST NOT be the base (see Pre-flight). Origin/main contains the `at` operator (`Ast.LAt`, `Fold_state.crease_segments`) and taco checks this plan builds on.
- **Exact arithmetic only:** all geometry via `Num`/`Geom`; never floats.
- **Byte-stable goldens:** every existing `tests/golden/*.fold` must be byte-identical after every task. The all-layers default is the status quo.
- **Error style:** lowercase messages, name the candidates, suggest the missing constraint (ADR 0016). Existing message texts referenced below are load-bearing (tests grep substrings) — do not rephrase existing ones.
- **Commits:** conventional commits, concise subject, no bodies.
- **Verify command:** `dune build && dune test` (run from the worktree root; the flake env provides dune/FLINT — if `dune` is missing, use `nix develop -c dune ...`).
- References for prose/comments: [demaine2007, §14] simple-fold models; ADR 0016 (typed operands); ADR 0014 (crease = bundle).

## Pre-flight (once, by the orchestrator — NOT a subagent task)

Local `main` (3 docs commits: pinch notes, ADR 0016, fold-scope design) and `origin/main` (taco #62, at-operator #63, pinch notes duplicate) have diverged, and the design doc + ADR 0016 exist only locally. The working tree also has an uncommitted examples/ reorg (files moved to `examples/syntax/`) that must survive untouched.

```bash
cd /home/toph/Projects/beloch
git stash push -u -m "examples reorg + vscode settings (pre fold-scope rebase)"
git rebase origin/main          # duplicate pinch-notes commit auto-drops
git push origin main
git stash pop
```

Expected: `main` = origin/main + 2 docs commits (ADR 0016, fold-scope design), pushed; reorg back in the tree. If the rebase conflicts, stop and ask the user.

Then create the worktree for execution (in-repo worktrees work; `test_golden` anchors to `DUNE_SOURCEROOT`):

```bash
git worktree add ../beloch-fold-scope -b feat/fold-scope main
cd ../beloch-fold-scope && dune build && dune test   # must be green before Task 1
```

---

## File Structure

- `lib/ast.ml` — add `flap_arg`, extend `fold_spec` with `up_to`, add `FoldAlong` stmt.
- `lib/lexer.ml` — keywords `up`, `to`, `fold`.
- `lib/parser.mly` — tokens `UP TO FOLD_KW`; rewrite `fold_clauses` as three optional slots; `flap_arg` rule; `@fold` statement.
- `lib/fold_state.ml` — `scope_target`, `select_scope` (stack-walk + outer-prefix closure), `fold_with_records ?moving_parents` (scoped cut+reflect; non-moving faces stay uncut), on-axis edges keep `U` when nothing incident moves.
- `lib/eval.ml` — flap resolution (`resolve_flap_face`, `side_of_flap_arg`, `target_of`), shared `run_fold`, `FoldAlong` evaluation, `at_matches` refactor (shared by `resolve_line` and flap resolution).
- `tests/test_parse.ml`, `tests/test_eval.ml`, `tests/test_fold_state.ml` — unit tests per task.
- `examples/fold-top-flap.bel`, `examples/fold-top-two.bel`, `examples/fold-along.bel`, `examples/crease-all-fold-some.bel` + goldens (regen via `dune exec tools/regen.exe`).
- `spec/SPECIFICATION.md` — §4.6 rewrite + grammar (§ around line 674).

Note: the user's uncommitted examples-reorg (`examples/syntax/`) lives only in the main checkout; the worktree uses origin/main's flat `examples/` layout. New examples go to flat `examples/` — the user's reorg will move them later.

---

### Task 1: Syntax — `up to`, flap operands, `@fold`

**Files:**
- Modify: `lib/ast.ml`
- Modify: `lib/lexer.ml`
- Modify: `lib/parser.mly`
- Modify: `lib/eval.ml` (compile-green adaptation; full semantics land in Tasks 3–4)
- Test: `tests/test_parse.ml`

**Interfaces:**
- Consumes: existing `Ast.point_operand`, `Ast.line_operand`, `Ast.flap_operand`.
- Produces (used by Tasks 3–4):
  - `Ast.flap_arg = FlapPoint of point_operand | FlapLine of line_operand | FlapSpec of flap_operand`
  - `Ast.fold_spec = { moving : flap_arg option; up_to : flap_arg option; direction : direction }`
  - `Ast.stmt` gains `FoldAlong of line_operand * fold_spec * Error.span`
  - `Eval` helper `fstr : Ast.flap_arg -> string` (source-text rendering for errors)

- [ ] **Step 1: Write failing parse tests**

Append to `tests/test_parse.ml` (before the runner) and register the three cases in the existing `Alcotest.run` list under the parse suite:

```ocaml
let test_parse_up_to () =
  match
    Beloch.parse ~filename:"t.bel" "paper square\n@map .c onto .d up to .c\n"
  with
  | [
   Ast.Crease
     ( None,
       Ast.MapPoints _,
       Some
         {
           moving = None;
           up_to = Some (Ast.FlapPoint (Ast.PNamed { name = "c"; _ }));
           direction = Ast.Valley;
         },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected an up-to fold_spec"

let test_parse_flap_forms () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n@perp --d through .p moving #(.a .b) up to --d mountain\n"
  with
  | [
   Ast.Crease
     ( None,
       Ast.Perp _,
       Some
         {
           moving = Some (Ast.FlapSpec _);
           up_to = Some (Ast.FlapLine (Ast.LNamed { cname = "d"; _ }));
           direction = Ast.Mountain;
         },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected flap-spec moving + crease up-to + mountain"

let test_parse_fold_along () =
  match Beloch.parse ~filename:"t.bel" "paper square\n@fold --m moving .c\n" with
  | [
   Ast.FoldAlong
     ( Ast.LNamed { cname = "m"; _ },
       { moving = Some (Ast.FlapPoint _); up_to = None; direction = Ast.Valley },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "expected an @fold statement"
```

- [ ] **Step 2: Run to verify failure**

Run: `dune build 2>&1 | head -30`
Expected: FAIL — `Unbound constructor FlapPoint` / record field errors (the tests reference not-yet-existing AST).

- [ ] **Step 3: AST changes**

In `lib/ast.ml`, after the `type arg = ...` line, replace the current `direction`/`fold_spec` block:

```ocaml
type direction = Valley | Mountain

(* A flap-typed operand slot (ADR 0016). A point is sugar for "the flap
   carrying the point"; a line for "the flap hinged on the crease/segment"
   (usually a multi-match for `moving`, resolvable for `up to`); #(...) lists
   explicit incidence constraints. *)
type flap_arg =
  | FlapPoint of point_operand
  | FlapLine of line_operand
  | FlapSpec of flap_operand

type fold_spec = {
  moving : flap_arg option;
  up_to : flap_arg option;
  direction : direction;
}
```

Add to `stmt`:

```ocaml
  | FoldAlong of line_operand * fold_spec * Error.span
      (* @fold <crease> [moving f] [up to f] [mountain]: fold along existing
         material; the operand must resolve to a material crease *)
```

- [ ] **Step 4: Lexer keywords**

In `lib/lexer.ml`, next to the other keywords:

```ocaml
  | "up" -> UP
  | "to" -> TO
  | "fold" -> FOLD_KW
```

(sedlex longest-match keeps `toward` and `through` intact.)

- [ ] **Step 5: Parser**

In `lib/parser.mly`: add `UP TO FOLD_KW` to the first `%token` line. Replace the `fold_clauses` rule:

```
fold_clauses:
  | moving_opt upto_opt mountain_opt
      { { moving = $1; up_to = $2;
          direction = (if $3 then Mountain else Valley) } }

moving_opt:
  |                 { None }
  | MOVING flap_arg { Some $2 }

upto_opt:
  |                { None }
  | UP TO flap_arg { Some $3 }

mountain_opt:
  |          { false }
  | MOUNTAIN { true }

flap_arg:
  | point_operand { FlapPoint $1 }
  | line_operand  { FlapLine $1 }
  | flap_operand  { FlapSpec $1 }
```

Add to `body_stmt`:

```
  | AT FOLD_KW line_operand fold_clauses { FoldAlong ($3, $4, $loc) }
```

Menhir must report no new conflicts (`dune build` fails on them by default).

- [ ] **Step 6: Eval compile-green adaptation**

In `lib/eval.ml`:

(a) Add `fstr` to the `pstr`/`lstr`/`selstr` mutually recursive group:

```ocaml
  and fstr (fa : Ast.flap_arg) : string =
    match fa with
    | Ast.FlapPoint po -> pstr po
    | Ast.FlapLine lo -> lstr lo
    | Ast.FlapSpec (Ast.FByPoints (pts, _)) ->
        Printf.sprintf "#(%s)" (String.concat " " (List.map pstr pts))
```

(b) In the `Ast.Crease (..., Some fs)` branch, the old `fs.Ast.moving` was a `point_operand option`; now it is `flap_arg option`. Interim semantics (exact status quo for points; the rest lands in Task 3):

```ocaml
        | Some fs ->
            (match fs.Ast.up_to with
            | Some _ ->
                Error.fail span "`up to` is not implemented yet" (* Task 3 *)
            | None -> ());
            let move_side =
              match fs.Ast.moving with
              | Some (Ast.FlapPoint po) ->
                  let s = Geom.side_of_line axis (table_of po) in
                  if s = 0 then
                    Error.fail span "the moving point lies on the fold axis";
                  s
              | Some fa ->
                  Error.fail span
                    (Printf.sprintf
                       "flap operand %s for `moving` is not implemented yet"
                       (fstr fa)) (* Task 3 *)
              | None -> (
                  match ax with
                  | Ast.MapPoints (p, _)
                  | Ast.MapThrough (p, _, _, _)
                  | Ast.MapBoth (p, _, _, _, _) ->
                      let s = Geom.side_of_line axis (table_of p) in
                      if s = 0 then
                        Error.fail span "the moving point lies on the fold axis";
                      s
                  | _ ->
                      Error.fail span
                        "this fold needs `moving .p` to choose the side")
            in
            ...
```

(c) Add a `FoldAlong` arm to `eval_stmt`:

```ocaml
    | Ast.FoldAlong (_, _, span) ->
        Error.fail span "@fold is not implemented yet" (* Task 4 *)
```

The three "not implemented yet" failures are removed in Tasks 3 and 4 — they exist only so each task ships green.

- [ ] **Step 7: Run tests**

Run: `dune build && dune test`
Expected: PASS, including the three new parse tests and all goldens byte-stable.

- [ ] **Step 8: Commit**

```bash
git add lib/ast.ml lib/lexer.ml lib/parser.mly lib/eval.ml tests/test_parse.ml
git commit -m "feat(parse): fold_spec grows up to; flap operands; @fold statement"
```

---

### Task 2: Fold_state — scoped fold machinery

**Files:**
- Modify: `lib/fold_state.ml`
- Test: `tests/test_fold_state.ml`

**Interfaces:**
- Consumes: `Geom.clip_convex_halfplane`, `Geom.convex_overlap`, `Layer_order.get`, existing `fold_with_records` internals.
- Produces (used by Task 3):
  - `type scope_target = TargetFace of int | TargetHinged of (int -> bool)`
  - `val select_scope : t -> axis:Geom.line -> move_side:int -> valley:bool -> anchor:int -> target:scope_target -> (bool array, string) result` — `Ok m` with `m.(fi) = true` iff pre-fold face `fi`'s move-side piece folds; `Error msg` for spec-listed failures (no spans here; Eval attaches the span).
  - `fold_with_records` gains `?moving_parents:bool array`. `None` (default) = status quo (all move-side pieces move, every straddling face is cut). `Some m` = only faces with `m.(fi)` are cut/reflected; all others stay whole and uncut.

**Semantics being implemented** (from the design doc): the moving set is the *outer-contiguous prefix* of layers over the crease region ending at the target — computed as the closure of the target under "some candidate lies outside you over the region" (outer = Above for valley, Below for mountain). By construction no stationary flap can cover the range; the two remaining error cases are (a) the anchor is not in the closure (target unreachable / wrong side) and (b) the closure contains a flap outside the *anchor* (buried anchor).

- [ ] **Step 1: Write failing unit tests**

Append to `tests/test_fold_state.ml` (register in its runner; follow the file's existing helpers for building points/lines — it already builds states via `Fold_state.simple_fold`/`fold_with_records` for the taco tests):

```ocaml
(* two-layer stack: unit square valley-folded along y=1/2, top half moved down *)
let two_layer () =
  Fold_state.simple_fold Fold_state.init_square
    ~axis:{ Geom.a = Num.zero; b = Num.one; c = Num.of_q (Q.of_ints 1 2) }
    ~move_side:1 ~valley:true

let vline_half = { Geom.a = Num.one; b = Num.zero; c = Num.of_q (Q.of_ints 1 2) }

(* the top face of the 2-layer stack = the moved one (index found via order) *)
let top_face (st : Fold_state.t) =
  let n = Array.length st.Fold_state.faces in
  let is_top i =
    List.for_all
      (fun j -> i = j || Layer_order.get st.Fold_state.order i j <> Layer_order.Below)
      (List.init n Fun.id)
  in
  match List.find_opt is_top (List.init n Fun.id) with
  | Some i -> i
  | None -> Alcotest.fail "no top face"

let test_select_scope_top_only () =
  let st = two_layer () in
  let top = top_face st in
  match
    Fold_state.select_scope st ~axis:vline_half ~move_side:1 ~valley:true
      ~anchor:top ~target:(Fold_state.TargetFace top)
  with
  | Ok m ->
      Alcotest.(check int) "exactly one moving parent" 1
        (Array.fold_left (fun a b -> if b then a + 1 else a) 0 m);
      Alcotest.(check bool) "it is the top face" true m.(top)
  | Error e -> Alcotest.fail e

let test_select_scope_buried_anchor () =
  let st = two_layer () in
  let top = top_face st in
  let bottom = 1 - top in
  match
    Fold_state.select_scope st ~axis:vline_half ~move_side:1 ~valley:true
      ~anchor:bottom ~target:(Fold_state.TargetFace bottom)
  with
  | Ok _ -> Alcotest.fail "expected a buried-anchor error"
  | Error e ->
      Alcotest.(check bool) "mentions covering" true
        (try
           ignore (Str.search_forward (Str.regexp_string "cover") e 0);
           true
         with Not_found -> false)

let test_scoped_fold_leaves_others_uncut () =
  let st = two_layer () in
  let top = top_face st in
  let m = Array.init (Array.length st.Fold_state.faces) (fun i -> i = top) in
  let st' =
    Fold_state.fold_with_records st ~moving_parents:m ~axis:vline_half
      ~move_side:1 ~valley:true ~prov:None
  in
  (* top face splits in two, bottom stays whole: 3 faces, not 4 *)
  Alcotest.(check int) "three faces" 3 (Array.length st'.Fold_state.faces)

let test_unscoped_fold_unchanged () =
  let st = two_layer () in
  let st' =
    Fold_state.fold_with_records st ~axis:vline_half ~move_side:1 ~valley:true
      ~prov:None
  in
  Alcotest.(check int) "all-layers cuts both: four faces" 4
    (Array.length st'.Fold_state.faces)
```

(If `tests/dune` for `test_fold_state` lacks the `str` library, add it.)

- [ ] **Step 2: Run to verify failure**

Run: `dune build 2>&1 | head -20`
Expected: FAIL — `Unbound constructor Fold_state.TargetFace`, unknown label `moving_parents`.

- [ ] **Step 3: Implement `select_scope`**

In `lib/fold_state.ml`, after `table_polygon`:

```ocaml
type scope_target = TargetFace of int | TargetHinged of (int -> bool)

(* Moving-set selection for a scoped ("up to") simple fold: the outer-contiguous
   prefix of layers over the crease region ending at the target — the static
   shadow of a collision-free 180° rotation [demaine2007, §14.1]. "Outer" is
   top for valley, bottom for mountain. Candidates are the faces with a piece
   on the moving side; overlap is judged between those pieces (depth may vary
   along the crease). Errors are messages; the caller attaches the span. *)
let select_scope (st : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ~(anchor : int) ~(target : scope_target) :
    (bool array, string) result =
  let n = Array.length st.faces in
  let piece =
    Array.init n (fun i ->
        let sub =
          Geom.clip_convex_halfplane axis move_side (table_polygon st i)
        in
        if Array.length sub >= 3 then Some sub else None)
  in
  let cand i = piece.(i) <> None in
  let overlap i j =
    match (piece.(i), piece.(j)) with
    | Some a, Some b -> Geom.convex_overlap a b
    | _ -> false
  in
  (* i lies strictly outside j over the crease region *)
  let outer i j =
    overlap i j
    && Layer_order.get st.order i j = (if valley then Above else Below)
  in
  let find_targets () : (int list, string) result =
    match target with
    | TargetFace t ->
        if not (cand t) then
          Error "`up to`: the target flap is not on the moving side of the fold"
        else Ok [ t ]
    | TargetHinged pred ->
        if pred anchor then Ok [ anchor ]
        else begin
          (* walk inward from the anchor, one stack level at a time; the first
             level containing a hinged flap ends the range (inclusive) *)
          let visited = Array.make n false in
          visited.(anchor) <- true;
          let result = ref None in
          while !result = None do
            let frontier = ref [] in
            for g = 0 to n - 1 do
              if (not visited.(g)) && cand g then begin
                let inward = ref false in
                for v = 0 to n - 1 do
                  if visited.(v) && outer v g then inward := true
                done;
                if !inward then frontier := g :: !frontier
              end
            done;
            match List.filter pred !frontier with
            | [] ->
                if !frontier = [] then
                  result :=
                    Some
                      (Error
                         "`up to`: no flap hinged on that crease is reachable \
                          from the anchor over the crease region")
                else List.iter (fun g -> visited.(g) <- true) !frontier
            | hits -> result := Some (Ok hits)
          done;
          Option.get !result
        end
  in
  match find_targets () with
  | Error e -> Error e
  | Ok targets ->
      let inm = Array.make n false in
      List.iter (fun t -> inm.(t) <- true) targets;
      (* closure: any candidate outside a moving flap over the region must
         move too — the moving set is an outer prefix by construction *)
      let changed = ref true in
      while !changed do
        changed := false;
        for g = 0 to n - 1 do
          if (not inm.(g)) && cand g then
            for m = 0 to n - 1 do
              if inm.(m) && (not inm.(g)) && outer g m then begin
                inm.(g) <- true;
                changed := true
              end
            done
        done
      done;
      if not inm.(anchor) then
        Error
          "`up to`: the target is not reachable from the anchor over the \
           crease region"
      else begin
        let buried = ref None in
        for m = 0 to n - 1 do
          if !buried = None && inm.(m) && m <> anchor && outer m anchor then
            buried := Some m
        done;
        match !buried with
        | Some m ->
            Error
              (Printf.sprintf
                 "a simple fold cannot move a buried flap: face %d covers the \
                  anchor in the crease region — include the covering flap \
                  (anchor the fold there) or fold less" m)
        | None -> Ok inm
      end
```

- [ ] **Step 4: Scope `fold_with_records`**

Change the signature to `let fold_with_records ?crease_id ?moving_parents (st : t) ~axis ~move_side ~valley ~prov : t =` and add right after `refl`:

```ocaml
  let moves fi =
    match moving_parents with None -> true | Some m -> m.(fi)
  in
```

Wrap the per-face body of the first `Array.iteri`: a non-moving face is carried whole and uncut:

```ocaml
  Array.iteri
    (fun fi f ->
      if not (moves fi) then stay := (f, fi) :: !stay
      else begin
        (* ... existing body: part / edge_seeds / stay / mov ... *)
      end)
    st.faces;
```

Then, in the `carried` edge mapping, change the on-axis branch (`sa = 0 && sb = 0`) so an on-axis precrease keeps its `U` when nothing incident moves — required for crease-all-fold-some; #27's upgrade only applies to the crease actually being folded:

```ocaml
        if sa = 0 && sb = 0 then begin
          let moving_face =
            if has_moved_child e.left then Some e.left
            else if e.right >= 0 && has_moved_child e.right then Some e.right
            else None
          in
          match moving_face with
          | Some mf ->
              [
                {
                  e with
                  left = child_on e.left sa;
                  right = child_on e.right sa;
                  eassign = assign_of_parent mf;
                };
              ]
          | None ->
              [ { e with left = child_on e.left sa; right = child_on e.right sa } ]
        end
```

Also update `simple_fold`'s call site if the compiler complains (it passes no `moving_parents`, so no change should be needed).

- [ ] **Step 5: Run tests**

Run: `dune test`
Expected: PASS — the four new fold_state tests, and **all goldens byte-identical** (the default path must not change; if any golden differs, the scoping leaked into the default path — fix before committing).

- [ ] **Step 6: Commit**

```bash
git add lib/fold_state.ml tests/test_fold_state.ml tests/dune
git commit -m "feat(fold): scoped moving set — select_scope walk, moving_parents, U kept on unmoved precreases"
```

---

### Task 3: Evaluator — flap resolution and `up to` wiring

**Files:**
- Modify: `lib/eval.ml`
- Test: `tests/test_eval.ml`
- Create: `examples/fold-top-flap.bel`, `examples/fold-top-two.bel` + goldens

**Interfaces:**
- Consumes: `Fold_state.select_scope`, `Fold_state.scope_target`, `fold_with_records ?moving_parents`, `Fold_state.crease_segments`, `Ast.flap_arg`.
- Produces (used by Task 4): inside `eval_folded`,
  - `at_matches : Ast.crease_ref -> Ast.selector list -> Error.span -> int * Fold_state.crease_segment list` (cid + matching segments; refactored out of the `LAt` arm)
  - `material_cid : Ast.crease_ref -> int`
  - `resolve_flap_face : Ast.flap_arg -> Error.span -> int`
  - `side_of_flap_arg : Geom.line -> Ast.flap_arg -> Error.span -> int`
  - `target_of : Ast.flap_arg -> Error.span -> Fold_state.scope_target`
  - `run_fold : span:Error.span -> axis:Geom.line -> fs:Ast.fold_spec -> implied:Ast.point_operand option -> crease_id:int -> prov:State.provenance option -> unit`

- [ ] **Step 1: Write failing eval tests**

Append to `tests/test_eval.ml` (register in the runner):

```ocaml
(* up to = anchor: only the top flap of a 2-layer stack folds → 3 faces *)
let test_eval_up_to_top_flap () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .d onto .a\n@map .c onto .d up to .c\n")
  in
  Alcotest.(check int) "3 faces" 3 (Array.length fd.Eval.state.Fold_state.faces)

(* same fold without up to: all-layers cuts both → 4 faces *)
let test_eval_all_layers_differs () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .d onto .a\n@map .c onto .d\n")
  in
  Alcotest.(check int) "4 faces" 4 (Array.length fd.Eval.state.Fold_state.faces)

(* four-layer stack, fold the top two: 6 faces (all-layers would be 8).
   --l/--bot are boundary reference creases and MUST be bound before the folds
   (afterwards .a/.b and .a/.d coincide on the table → "same place" error) *)
let quarter_stack_prefix =
  "paper square\n\
   --l = through .a .d\n\
   --bot = through .a .b\n\
   --v = @map .b onto .a\n\
   --h = @map .d onto .a\n\
   .p = cross --l --h\n\
   .q = cross --v --bot\n"

let test_eval_up_to_range () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         (quarter_stack_prefix ^ "@through .p .q moving .d up to .c\n"))
  in
  Alcotest.(check int) "6 faces" 6 (Array.length fd.Eval.state.Fold_state.faces)

(* anchoring below a covering flap is a buried-anchor error *)
let test_eval_buried_anchor () =
  expect_error "cover" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              (quarter_stack_prefix ^ "@through .p .q moving .c up to .b\n"))))

(* target flap entirely off the moving side *)
let test_eval_up_to_wrong_side () =
  expect_error "not on the moving side" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --h = @map .d onto .a\n\
               --v = @map .c onto .d up to .c\n\
               --bot = through .a .b\n\
               .m = cross --v --bot\n\
               @map .b onto .m up to .c\n")))

(* up to --crease with no reachable hinged flap *)
let test_eval_up_to_crease_unreachable () =
  expect_error "no flap hinged" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n--l = through .a .d\n@map .d onto .a up to --l\n")))

(* up to --crease: the anchor itself is hinged on it → range = anchor alone *)
let test_eval_up_to_crease_target () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         (quarter_stack_prefix ^ "@through .p .q moving .d up to --h\n"))
  in
  Alcotest.(check int) "5 faces (top flap only)" 5
    (Array.length fd.Eval.state.Fold_state.faces)

(* moving --d: a hinge has two sides → multi-match error *)
let test_eval_moving_line_multimatch () =
  expect_error "flaps" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n--d = map .b onto .a\n@through .a .c moving --d\n")))

(* an explicit flap that straddles the axis cannot anchor *)
let test_eval_moving_flap_straddles () =
  expect_error "straddles" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n@map .b onto .a moving #(.a .b)\n")))
```

- [ ] **Step 2: Run to verify failure**

Run: `dune exec tests/test_eval.exe 2>&1 | tail -20` (or `dune test`)
Expected: FAIL — the `up to`/flap cases hit Task 1's "not implemented yet" errors.

- [ ] **Step 3: Refactor `LAt` resolution into `at_matches`**

In `eval_folded`, extract the body of the `Ast.LAt` arm of `resolve_line` into a sibling function in the same recursive group (keep behavior and error texts identical):

```ocaml
  and material_cid (cr : Ast.crease_ref) : int =
    match lookup_crease ctx cr with
    | Material (cid, _) -> cid
    | Frozen _ ->
        Error.fail cr.Ast.cspan
          (Printf.sprintf
             "--%s is not a physical crease, so it has no segments to select"
             cr.Ast.cname)

  and at_matches (cr : Ast.crease_ref) (sels : Ast.selector list)
      (_span : Error.span) : int * Fold_state.crease_segment list =
    let cid = material_cid cr in
    let segs = Fold_state.crease_segments !(ctx.state) cid in
    (* seg_line / point_on_seg / incident: moved verbatim from the LAt arm *)
    ...
    (cid, List.filter (fun s -> List.for_all (fun sel -> incident sel s) sels) segs)
```

and the `LAt` arm becomes:

```ocaml
    | Ast.LAt (cr, sels, span) -> (
        let _cid, matches = at_matches cr sels span in
        match matches with
        | [ s ] -> Geom.line_through s.Fold_state.ta s.Fold_state.tb
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

Run `dune test` — everything must still pass (pure refactor; `crease-at-flap` golden proves it).

- [ ] **Step 4: Flap resolution helpers**

Add after `table_of` in `eval_folded`:

```ocaml
  (* faces whose PAPER polygon contains material point [pp] *)
  let faces_containing (pp : Geom.point) : int list =
    let st = !(ctx.state) in
    let acc = ref [] in
    Array.iteri
      (fun i (f : Fold_state.face) ->
        if Geom.in_convex_polygon f.Fold_state.paper pp then acc := i :: !acc)
      st.Fold_state.faces;
    List.rev !acc
  in
  (* resolve a flap operand to the unique current face (ADR 0016: slots demand
     uniqueness, errors name the candidates) *)
  let resolve_flap_face (fa : Ast.flap_arg) (span : Error.span) : int =
    match fa with
    | Ast.FlapPoint po -> (
        match faces_containing (resolve_point po) with
        | [ i ] -> i
        | [] ->
            Error.fail span
              (Printf.sprintf "%s is not on the paper" (fstr fa))
        | many ->
            Error.fail span
              (Printf.sprintf
                 "%s lies on a crease shared by %d flaps; name the flap with \
                  #(...)"
                 (fstr fa) (List.length many)))
    | Ast.FlapSpec (Ast.FByPoints (pts, fspan)) -> (
        match
          Fold_state.flap_of_points !(ctx.state) (List.map resolve_point pts)
        with
        | `Face fi -> fi
        | `Zero -> Error.fail fspan "those points aren't all on one flap"
        | `Ambiguous -> Error.fail fspan "ambiguous flap; add another point")
    | Ast.FlapLine lo -> (
        let candidates =
          match lo with
          | Ast.LAt (cr, sels, aspan) -> (
              match at_matches cr sels aspan with
              | _, [ s ] ->
                  let l, r = s.Fold_state.faces in
                  l :: (if r >= 0 then [ r ] else [])
              | _, [] ->
                  Error.fail aspan
                    (Printf.sprintf "no segment of --%s matches %s"
                       cr.Ast.cname (selstr sels))
              | _, many ->
                  Error.fail aspan
                    (Printf.sprintf
                       "--%s at %s is ambiguous: %d segments match; add a \
                        selector"
                       cr.Ast.cname (selstr sels) (List.length many)))
          | Ast.LNamed cr ->
              let cid = material_cid cr in
              Fold_state.crease_segments !(ctx.state) cid
              |> List.concat_map (fun (s : Fold_state.crease_segment) ->
                     let l, r = s.Fold_state.faces in
                     l :: (if r >= 0 then [ r ] else []))
              |> List.sort_uniq compare
          | _ ->
              Error.fail span
                (Printf.sprintf
                   "%s is not a physical crease, so it names no flap" (lstr lo))
        in
        match candidates with
        | [ i ] -> i
        | [] ->
            Error.fail span (Printf.sprintf "%s touches no flap" (fstr fa))
        | many ->
            Error.fail span
              (Printf.sprintf "%s touches %d flaps; add a point, e.g. #(.p)"
                 (fstr fa) (List.length many)))
  in
  (* which side of [axis] a flap anchor moves; point sugar keeps the existing
     side-of-the-point semantics (and its on-axis error) *)
  let side_of_flap_arg (axis : Geom.line) (fa : Ast.flap_arg)
      (span : Error.span) : int =
    match fa with
    | Ast.FlapPoint po ->
        let s = Geom.side_of_line axis (table_of po) in
        if s = 0 then Error.fail span "the moving point lies on the fold axis";
        s
    | _ -> (
        let fi = resolve_flap_face fa span in
        let poly = Fold_state.table_polygon !(ctx.state) fi in
        let pos = Array.exists (fun p -> Geom.side_of_line axis p > 0) poly in
        let neg = Array.exists (fun p -> Geom.side_of_line axis p < 0) poly in
        match (pos, neg) with
        | true, true ->
            Error.fail span
              (Printf.sprintf
                 "%s straddles the fold axis; anchor with a point instead"
                 (fstr fa))
        | true, false -> 1
        | false, true -> -1
        | false, false ->
            Error.fail span
              (Printf.sprintf "%s lies on the fold axis" (fstr fa)))
  in
  let target_of (fa : Ast.flap_arg) (span : Error.span) :
      Fold_state.scope_target =
    match fa with
    | Ast.FlapPoint _ | Ast.FlapSpec _ ->
        Fold_state.TargetFace (resolve_flap_face fa span)
    | Ast.FlapLine lo -> (
        match lo with
        | Ast.LNamed cr ->
            let cid = material_cid cr in
            let st = !(ctx.state) in
            Fold_state.TargetHinged
              (fun f ->
                Array.exists
                  (fun (e : Fold_state.edge) ->
                    e.Fold_state.crease_id = cid
                    && (e.Fold_state.left = f || e.Fold_state.right = f))
                  st.Fold_state.edges)
        | Ast.LAt (cr, sels, aspan) -> (
            match at_matches cr sels aspan with
            | _, [ s ] ->
                let l, r = s.Fold_state.faces in
                Fold_state.TargetHinged (fun f -> f = l || f = r)
            | _, [] ->
                Error.fail aspan
                  (Printf.sprintf "no segment of --%s matches %s" cr.Ast.cname
                     (selstr sels))
            | _, many ->
                Error.fail aspan
                  (Printf.sprintf
                     "--%s at %s is ambiguous: %d segments match; add a \
                      selector"
                     cr.Ast.cname (selstr sels) (List.length many)))
        | _ ->
            Error.fail span
              (Printf.sprintf
                 "%s is not a physical crease, so it names no flap" (lstr lo)))
  in
```

- [ ] **Step 5: Shared `run_fold` and Crease wiring**

Add after the helpers:

```ocaml
  let run_fold ~(span : Error.span) ~(axis : Geom.line) ~(fs : Ast.fold_spec)
      ~(implied : Ast.point_operand option) ~(crease_id : int)
      ~(prov : State.provenance option) : unit =
    let anchor_arg =
      match (fs.Ast.moving, implied) with
      | Some fa, _ -> fa
      | None, Some p -> Ast.FlapPoint p
      | None, None ->
          Error.fail span "this fold needs `moving .p` to choose the side"
    in
    let move_side = side_of_flap_arg axis anchor_arg span in
    let valley = fs.Ast.direction = Ast.Valley in
    match fs.Ast.up_to with
    | None ->
        ctx.state :=
          Fold_state.fold_with_records !(ctx.state) ~axis ~move_side ~valley
            ~crease_id ~prov
    | Some tgt -> (
        let anchor = resolve_flap_face anchor_arg span in
        let target = target_of tgt span in
        match
          Fold_state.select_scope !(ctx.state) ~axis ~move_side ~valley ~anchor
            ~target
        with
        | Error msg -> Error.fail span msg
        | Ok moving_parents ->
            ctx.state :=
              Fold_state.fold_with_records !(ctx.state) ~moving_parents ~axis
                ~move_side ~valley ~crease_id ~prov)
  in
```

Replace the entire `Some fs` branch of the `Ast.Crease` arm (deleting Task 1's interim code and the old inline `move_side` computation) with:

```ocaml
        | Some fs ->
            let implied =
              match ax with
              | Ast.MapPoints (p, _)
              | Ast.MapThrough (p, _, _, _)
              | Ast.MapBoth (p, _, _, _, _) ->
                  Some p
              | _ -> None
            in
            run_fold ~span ~axis ~fs ~implied ~crease_id:cid ~prov);
```

(The `FoldAlong` arm keeps its Task 1 stub until Task 4.)

- [ ] **Step 6: Run the new tests**

Run: `dune test`
Expected: PASS. If `test_eval_up_to_range`/`test_eval_up_to_crease_target` face counts disagree, print the FOLD output (`Beloch.fold_string`) for the program and recount — fix the *code*, not the number, unless the recount shows the expected geometry (then fix the expectation and note why in the test name).

- [ ] **Step 7: Load-bearing examples + goldens**

Create `examples/fold-top-flap.bel`:

```
; status: works — `up to` the anchor folds exactly one flap: the bottom layer
; stays uncut (3 faces; the all-layers default would cut it too: 4)
paper square
@map .d onto .a
@map .c onto .d up to .c
```

Create `examples/fold-top-two.bel`:

```
; status: works — a some-layers simple fold: on a four-layer stack, fold the
; top two flaps (anchor .d, up to .c); the bottom two stay uncut.
; --l/--bot are boundary reference creases, bound before the folds collapse
; the corners onto each other
paper square
--l = through .a .d
--bot = through .a .b
--v = @map .b onto .a
--h = @map .d onto .a
.p = cross --l --h
.q = cross --v --bot
@through .p .q moving .d up to .c
```

Regenerate goldens and check nothing else moved:

```bash
dune exec tools/regen.exe
git status --short tests/golden/
```

Expected: exactly two new files `tests/golden/fold-top-flap.fold`, `tests/golden/fold-top-two.fold`; zero modified existing goldens. Run `dune test` again — PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/eval.ml tests/test_eval.ml examples/fold-top-flap.bel examples/fold-top-two.bel tests/golden/fold-top-flap.fold tests/golden/fold-top-two.fold
git commit -m "feat(fold): flap-typed moving and up-to scope"
```

---

### Task 4: `@fold` — fold along existing material

**Files:**
- Modify: `lib/eval.ml` (replace the `FoldAlong` stub)
- Test: `tests/test_eval.ml`
- Create: `examples/fold-along.bel`, `examples/crease-all-fold-some.bel` + goldens

**Interfaces:**
- Consumes: `run_fold`, `material_cid`, `at_matches`, `materialize_crease` (Task 3), `Fold_state.crease_segments`.
- Produces: evaluation of `Ast.FoldAlong`; provenance `axiom = "fold"`, `sources = [lstr lo]`. `@fold` passes the **existing crease's id** to `fold_with_records`, so segments minted by cutting new layers join the same bundle (ADR 0014: splits stay inside the name).

- [ ] **Step 1: Write failing tests**

Append to `tests/test_eval.ml`:

```ocaml
(* @fold --d ≡ re-stating the axiom: same faces, same M/V, no stale U (#27) *)
let test_fold_along_matches_restatement () =
  let via_fold =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n--d = map .b onto .a\n@fold --d moving .b\n")
  in
  let via_axiom =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nmap .b onto .a\n@map .b onto .a moving .b\n")
  in
  Alcotest.(check int) "same face count"
    (Array.length via_axiom.Eval.state.Fold_state.faces)
    (Array.length via_fold.Eval.state.Fold_state.faces);
  Alcotest.(check int) "same V count"
    (count_assign Fold_state.V via_axiom.Eval.state)
    (count_assign Fold_state.V via_fold.Eval.state);
  Alcotest.(check int) "no stale U" 0
    (count_assign Fold_state.U via_fold.Eval.state)

(* crease all layers, @fold some: the unmoved layer keeps its flat U mark *)
let test_crease_all_fold_some () =
  let scoped =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          @map .d onto .a\n\
          --m = map .c onto .d\n\
          @fold --m moving .c up to .c\n")
  in
  Alcotest.(check int) "unmoved layer keeps U" 1
    (count_assign Fold_state.U scoped.Eval.state);
  Alcotest.(check int) "4 faces" 4
    (Array.length scoped.Eval.state.Fold_state.faces);
  let all_layers =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          @map .d onto .a\n\
          --m = map .c onto .d\n\
          @fold --m moving .c\n")
  in
  Alcotest.(check int) "all-layers upgrades every U" 0
    (count_assign Fold_state.U all_layers.Eval.state)

let test_fold_along_needs_moving () =
  expect_error "needs `moving" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n--d = map .b onto .a\n@fold --d\n")))

let test_fold_along_not_material () =
  expect_error "existing crease" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n@fold --(.a .c) moving .b\n")))

(* globally bent bundle without `at` → the existing PR2/at error *)
let test_fold_along_bent () =
  expect_error "no longer straight" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --b = through .a .c\n\
               --v = @map .c onto .b\n\
               @fold --b moving .a\n")))

(* bent under the moving set: axis picked via `at`, but a moving flap carries
   an off-axis segment of the same bundle *)
let test_fold_along_bent_under_moving () =
  expect_error "bent under" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --b = through .a .c\n\
               --v = @map .c onto .b\n\
               @fold --b at #(.c .d) moving .a\n")))
```

Note on the last test: the intent is a moving set that contains the flap carrying the *lower* (off-axis) segment of `--b`. If `moving .a` turns out not to include that flap for this geometry, adjust the anchor (`.b` or a `#(...)`) until the error fires — verify by printing the fold output of the same program without the `@fold` line.

- [ ] **Step 2: Run to verify failure**

Run: `dune test 2>&1 | tail -20`
Expected: FAIL — `@fold is not implemented yet`.

- [ ] **Step 3: Implement `FoldAlong`**

Replace the Task 1 stub arm in `eval_stmt`:

```ocaml
    | Ast.FoldAlong (lo, fs, span) ->
        let cid, axis =
          match lo with
          | Ast.LNamed cr ->
              let cid = material_cid cr in
              (cid, resolve_line lo)
          | Ast.LAt (cr, _, _) ->
              let cid = material_cid cr in
              (cid, resolve_line lo)
          | _ ->
              Error.fail span
                "@fold folds along an existing crease; give a crease name, \
                 e.g. @fold --d or @fold --d at .p"
        in
        (* per-flap material check: every segment of the bundle carried by a
           moving flap must lie on the axis — a crease bent under the moving
           set cannot fold (#28) *)
        let check_straight (moves : int -> bool) =
          List.iter
            (fun (s : Fold_state.crease_segment) ->
              let l, r = s.Fold_state.faces in
              if
                (moves l || (r >= 0 && moves r))
                && (Geom.side_of_line axis s.Fold_state.ta <> 0
                   || Geom.side_of_line axis s.Fold_state.tb <> 0)
              then
                Error.fail span
                  "the crease is bent under the moving flaps; select a \
                   straight segment with `at` or move fewer flaps")
            (Fold_state.crease_segments !(ctx.state) cid)
        in
        let prov : State.provenance option =
          Some
            {
              State.axiom = "fold";
              sources = [ lstr lo ];
              span;
              name = None;
              step = ctx.panel;
            }
        in
        run_fold_checked ~span ~axis ~fs ~implied:None ~crease_id:cid ~prov
          ~check:check_straight
```

To support the check, generalize `run_fold` (Task 3) minimally: rename it to `run_fold_checked` with an extra labeled argument `~check:(int -> bool) -> unit` variant — concretely:

```ocaml
  let run_fold_checked ~span ~axis ~(fs : Ast.fold_spec) ~implied ~crease_id
      ~prov ~(check : ((int -> bool) -> unit) option) : unit =
    ... (* identical to run_fold, plus: *)
    match fs.Ast.up_to with
    | None ->
        (match check with
        | Some k ->
            (* default scope: a face moves iff it has a piece on move_side *)
            let st = !(ctx.state) in
            k (fun fi ->
                Array.length
                  (Geom.clip_convex_halfplane axis move_side
                     (Fold_state.table_polygon st fi))
                >= 3)
        | None -> ());
        ctx.state := Fold_state.fold_with_records ... (* as before *)
    | Some tgt -> (
        ...
        | Ok moving_parents ->
            (match check with
            | Some k -> k (fun fi -> moving_parents.(fi))
            | None -> ());
            ctx.state := Fold_state.fold_with_records ~moving_parents ...)
  in
  let run_fold ~span ~axis ~fs ~implied ~crease_id ~prov : unit =
    run_fold_checked ~span ~axis ~fs ~implied ~crease_id ~prov ~check:None
  in
```

(The `Ast.Crease` arm keeps calling `run_fold`; `FoldAlong` calls `run_fold_checked ~check:(Some check_straight)`.)

- [ ] **Step 4: Run tests**

Run: `dune test`
Expected: PASS, goldens byte-stable. `test_fold_along_matches_restatement` proves the on-axis U-upgrade works with the bundle's own cid (no new edges minted along the existing crease).

- [ ] **Step 5: Load-bearing examples + goldens**

Create `examples/fold-along.bel`:

```
; status: works — precrease, then fold along the material crease itself:
; no axiom re-statement (compare precrease-fold.bel), the U mark upgrades to V
paper square
--d = map .b onto .a
@fold --d moving .b
```

Create `examples/crease-all-fold-some.bel`:

```
; status: works — the bare bind creases BOTH layers flat; @fold with `up to`
; folds only the top-right flap, the bottom layer keeps its flat U mark
paper square
@map .d onto .a
--m = map .c onto .d
@fold --m moving .c up to .c
```

```bash
dune exec tools/regen.exe
git status --short tests/golden/
```

Expected: exactly `fold-along.fold` and `crease-all-fold-some.fold` new, nothing modified. `dune test` → PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/eval.ml tests/test_eval.ml examples/fold-along.bel examples/crease-all-fold-some.bel tests/golden/fold-along.fold tests/golden/crease-all-fold-some.fold
git commit -m "feat(fold): @fold — fold along an existing material crease"
```

---

### Task 5: Spec §4.6 rewrite + grammar

**Files:**
- Modify: `spec/SPECIFICATION.md` (§4.6 and the grammar block around line 674)

**Interfaces:** none (docs). Source material: `docs/superpowers/specs/2026-07-05-fold-scope-design.md` and ADR 0016 (both on `main` after pre-flight — if missing in the worktree, `git merge main` or rebase the branch first).

- [ ] **Step 1: Rewrite §4.6**

Keep the existing precrease-vs-`@` framing, folded-state and derived-M/V paragraphs; replace the `moving` bullet block with the four-ingredient model. Must cover, with one example each:

1. **Ingredients table** — axis (axiom or material via `@fold`), anchor (implied on map folds / `moving`), scope (all-layers default / `up to`), direction (`mountain`).
2. **Anchor** — `moving` takes a *flap operand*: a point (the flap carrying it), a line (the flap hinged on it — usually ambiguous, error names the candidates), or `#(...)`. Map folds imply the anchor from the moved point; line-construction folds require `moving` (unchanged error).
3. **Scope** — no `up to`: all layers on the anchor's side (status quo, examples keep meaning). `up to <flap>`: the contiguous range from the anchor through the target, inclusive, in the stack order over the crease region; `up to` the anchor = exactly one flap. `up to --d`: the first flap hinged on a segment of `--d` in the walk ends the range.
4. **Validity** — a `@`/`@fold` statement is a *simple fold* [demaine2007, §14.1]: the moving set must be an outer-contiguous prefix in the crease region (top for valley, bottom for mountain); a buried anchor is an error; motion outside the crease region is not checked (cross-ref taco checks).
5. **`@fold`** — syntax, `moving` always required, bundle resolution per flap (`at` for bent bundles), bent-under-the-moving-set error, "crease all layers, fold some" example:

```
--d = map .b onto .a          ; bare bind: subdivides ALL layers
@fold --d moving .b up to .c  ; fold only flaps .b through .c along it
```

6. Cross-link ADR 0016 and ADR 0014 at the end of the section.

- [ ] **Step 2: Update the grammar block**

In the EBNF near line 674, replace the crease-statement production and add:

```
               | [ CREASE_NAME "=" ] [ "@" ] axiom [ fold_spec ]
               | "@" "fold" line_operand fold_spec

fold_spec      = [ "moving" flap_operand ] [ "up" "to" flap_operand ] [ "mountain" ]
flap_operand   = point_operand | line_operand | "#(" point_operand+ ")"
```

Also update the prose near line 709 ("The `@` prefix performs the fold (§4.6); `moving`/`mountain` describe it.") to mention `up to`.

- [ ] **Step 3: Verify + commit**

Run: `dune test` (docs only — still must be green) and `rg -n "moving" spec/SPECIFICATION.md | head` to confirm no stale "flap containing material point" wording survives outside §4.6 history notes.

```bash
git add spec/SPECIFICATION.md
git commit -m "docs(spec): §4.6 fold scope — flap operands, up to, @fold"
```

---

## Final verification (orchestrator)

- [ ] `dune build && dune test` green in the worktree.
- [ ] `git diff main --stat` touches only the files listed in this plan.
- [ ] Existing goldens byte-identical: `git diff main -- tests/golden/ --stat` shows only the four new `.fold` files.
- [ ] Render the four new examples with `tools/fold2svg.mjs` for the PR screenshots (per the repo's PR convention), open the PR on the Forgejo remote as `toph` (not the bot), linking the design doc and ADR 0016.

## Self-review notes (already checked against the spec)

- Non-contiguous flap sets: nothing to implement — `and` stays constraint conjunction; no set syntax added.
- Redundant `moving .a` lint is #64, LSP lifetime hints #65 — out of scope here.
- `toward`/`up to` keyword bikeshed resolved as `up to` (spec "working choice").
- Renaming `@map` → `@fold` explicitly not done; `@fold` is reserved for material creases.
