# Prefix-to-Anchor Default Fold Scope — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change the default scope of a `fold` (no `up to`) from "every layer on the anchor's side" to "the outside-contiguous prefix of layers down to and including the flap(s) carrying the anchor operand", so folding a tip (e.g. `fold map .b onto .o`) moves only that flap's stack instead of half the model.

**Architecture:** A new pure-geometry `Fold_state.default_scope` computes the outside-prefix moving set from a seed of anchor faces (mirroring `select_scope`'s layer walk, minus the anchor/buried checks). The evaluator's `up_to = None` branch is rewritten to resolve the anchor operand to its carrying faces (union — no shared-crease error, this is design option (a)), derive the moving side, call `default_scope`, run the existing tear check `scoped_fold_hinge_closed`, then fold the resulting moving set. Explicit `up to` is untouched.

**Tech Stack:** OCaml, dune 3.21, Alcotest. Real-algebraic exact kernel (`Num`). Tests: `packages/core/tests/test_fold_state.ml` (unit), `packages/core/tests/cases/**.bel` (inline-assertion, run by `test_bel_assert`), `packages/core/tests/golden/bases/*.fold` (golden, run by `test_golden`).

## Global Constraints

- Design doc: `notes/2026-07-20-default-fold-scope.md` (verbatim source of truth for semantics).
- Flap selector token is `#[...]` (lexer.ml:49 `"#[" -> FLAP_BRACKET`). `#(...)` is NOT a token; every user-facing message must say `#[...]`.
- `moving` names the **deepest** flap of the outside-anchored moving prefix (top for valley, bottom for mountain) — not a "start" anchor.
- Shared-crease anchor = design **option (a)**: a point on N contiguous flaps seeds **all** of them; the default-scope path must NOT raise `lies on a crease shared by N flaps`.
- Exact kernel only — no floats in geometry; reuse `Geom.*` and `Num.*`.
- All source comments and doc prose in English (repo convention).
- Build: `dune build`. Tests: `dune runtest packages/core`. `dune` is on PATH via direnv in this repo.

---

### Task 1: `Fold_state.default_scope` (pure geometry + unit test)

**Files:**
- Modify: `packages/core/lib/fold_state.ml` (add function after `select_scope`, ~line 1205)
- Modify: `packages/core/lib/fold_state.mli` (add signature after `select_scope`, ~line 351)
- Test: `packages/core/tests/test_fold_state.ml`

**Interfaces:**
- Produces: `Fold_state.default_scope : t -> axis:Geom.line -> move_side:int -> valley:bool -> seed:int list -> bool array`
  - Returns a `bool array` of length `Array.length (faces g)`: `true` at face `i` iff `i` is in the moving set. The moving set = the faces in `seed` that have a piece on `move_side`, plus every candidate face that is **outside** (above for valley, below for mountain) some moving face over the crease region, plus every candidate in the same coplanar cluster as a moving face — grown to a fixpoint. No anchor-inclusion check, no buried-anchor check (those belong to `up to`).

- [ ] **Step 1: Write the failing unit test**

Add to `packages/core/tests/test_fold_state.ml` (reuses `single_fold_faces`/`single_fold_hinges`/`mk`/`vline` already defined in the file; place after `test_accordion`):

```ocaml
(* DEFAULT SCOPE: single fold gives face0 (rank 0) under face1 (rank 1), both
   overlapping [0,1]x[0,1]. Axis x=1/2 cuts both; move_side = +1 (x>1/2 side).
   Seed on the bottom flap grows to the whole stack; seed on the top flap stays
   a singleton — the outside-prefix-down-to-anchor rule. *)
let test_default_scope () =
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 0; 1 |] ()
  in
  let axis = vline_half in
  let scope seed =
    Fold_state.default_scope g ~axis ~move_side:1 ~valley:true ~seed
    |> Array.to_list
  in
  Alcotest.(check (list bool)) "seed bottom flap -> whole stack moves"
    [ true; true ] (scope [ 0 ]);
  Alcotest.(check (list bool)) "seed top flap -> only it moves"
    [ false; true ] (scope [ 1 ])
```

Add the half-axis helper near the other line helpers (top of file, after `vline`):

```ocaml
(* line x = 1/2 *)
let vline_half : Geom.line = { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 1 2) }
```

Register the case in the test's `Alcotest.run` suite list. The suites are named groups; add it to the group that already holds `"select_scope parity"` (test_fold_state.ml ~1506–1512), as a sibling `test_case`:

```ocaml
          Alcotest.test_case "default_scope" `Quick test_default_scope;
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `dune runtest packages/core 2>&1 | grep -A3 default_scope`
Expected: FAIL — `Unbound value Fold_state.default_scope` (compile error) or a missing-function error.

- [ ] **Step 3: Implement `default_scope`**

In `packages/core/lib/fold_state.ml`, immediately after `select_scope` ends (before the `scoped_fold_hinge_closed` comment at ~line 1207), add:

```ocaml
(* Default (no `up to`) moving set: the outside-contiguous prefix of layers
   down to and including the seed flap(s). "Outside" is top for valley, bottom
   for mountain. Seed = the faces carrying the anchor operand (possibly several,
   when the operand point lies on a shared crease — design option (a)). Unlike
   [select_scope] there is no anchor-inclusion or buried check: the seed is the
   *deepest* included layer and everything outside it moves with it. *)
let default_scope (g : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ~(seed : int list) : bool array =
  let n = Array.length g.faces in
  let tp = Array.init n (table_polygon g) in
  let piece =
    Array.init n (fun i ->
        let sub = Geom.clip_convex_halfplane axis move_side tp.(i) in
        if Array.length sub >= 3 then Some sub else None)
  in
  let cand i = piece.(i) <> None in
  let overlap i j =
    match (piece.(i), piece.(j)) with
    | Some a, Some b -> Geom.convex_overlap a b
    | _ -> false
  in
  let rel_m i j =
    if i = j then Apart
    else if Geom.convex_overlap tp.(i) tp.(j) then
      if g.rank.(i) > g.rank.(j) then Above else Below
    else Apart
  in
  (* gi is outside m: overlaps m and sits on the outer side (Above for valley) *)
  let outer gi m =
    overlap gi m && rel_m gi m = (if valley then Above else Below)
  in
  let cl = coplanar_clusters g in
  let inm = Array.make n false in
  List.iter (fun s -> if cand s then inm.(s) <- true) seed;
  let changed = ref true in
  while !changed do
    changed := false;
    for gi = 0 to n - 1 do
      if (not inm.(gi)) && cand gi then
        for m = 0 to n - 1 do
          if inm.(m) && (not inm.(gi)) && (outer gi m || cl.(gi) = cl.(m)) then begin
            inm.(gi) <- true;
            changed := true
          end
        done
    done
  done;
  inm
```

Note: `Above`/`Below`/`Apart` are the existing constructors used by `select_scope` in this module (same file); `coplanar_clusters`, `table_polygon`, `g.faces`, `g.rank` are already in scope. If `Above`/`Below`/`Apart` are defined below this point in the file, move `default_scope` to just after their definition (search `type rel` / `Above` in the file); it must follow both that type and `coplanar_clusters`.

- [ ] **Step 4: Add the signature to `fold_state.mli`**

In `packages/core/lib/fold_state.mli`, after the `select_scope` block (~line 351), add:

```ocaml
val default_scope :
  t ->
  axis:Geom.line ->
  move_side:int ->
  valley:bool ->
  seed:int list ->
  bool array
(** Default (no [up to]) moving set: the outside-contiguous prefix of layers
    down to and including the [seed] flap(s). "Outside" is top for valley,
    bottom for mountain. [seed] is the faces carrying the anchor operand — more
    than one when the operand point lies on a crease shared by several flaps
    (design option (a)). Unlike {!select_scope} there is no anchor-inclusion or
    buried-anchor check: the seed is the deepest included layer, and every
    candidate outside it (or coplanar with a mover) moves too. Non-seed folds
    still need {!scoped_fold_hinge_closed} — a strict subset can tear. *)
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `dune runtest packages/core 2>&1 | grep -A3 default_scope`
Expected: PASS (the `default_scope` case and the whole `fold_state` suite green).

- [ ] **Step 6: Commit**

```bash
git add packages/core/lib/fold_state.ml packages/core/lib/fold_state.mli packages/core/tests/test_fold_state.ml
git commit -m "feat(core): Fold_state.default_scope — outside-prefix-to-anchor moving set"
```

---

### Task 2: Rewrite the `up_to = None` branch to use `default_scope`

**Files:**
- Modify: `packages/core/lib/eval.ml` (helpers near `resolve_flap_cluster` ~line 731; branch at 1085–1099)
- Test: `packages/core/tests/cases/fold/ear-default-scope.bel` (create), `packages/core/tests/cases/fold/default-stops-at-anchor.bel` (create)

**Interfaces:**
- Consumes: `Fold_state.default_scope` (Task 1), existing `faces_containing`, `resolve_point`, `resolve_flap_cluster`, `Fold_state.scoped_fold_hinge_closed`, `Fold_state.fold ~moving_parents`, `side_of_flap_arg_res`.
- Produces: new local helpers (visible only inside the evaluator) —
  - `anchor_faces : Ast.flap_arg -> Error.span -> int list` — the faces carrying the operand, as a **union** (no shared-crease ambiguity error).
  - `default_move_side : Geom.line -> Ast.flap_arg -> Error.span -> int` — the moving side for the default branch, derived from the operand's point(s) when it carries points, else from the flap cluster.

- [ ] **Step 1: Write the failing behavioral tests**

Create `packages/core/tests/cases/fold/ear-default-scope.bel`:

```
paper square

mark --diag = through .a .c
mark --ea = map --ab onto --diag
mark --eb = map --ab onto --bc
mark --ec = map --bc onto --diag

.o = --ea * --eb
flatten (--ea & .a) (--ec & .c) (--eb & .b) {toward .a}
mark --l = map .d onto .b

fold map .b onto .o

; assert faces = PIN_ME
```

Create `packages/core/tests/cases/fold/default-stops-at-anchor.bel` — a two-layer case where the old all-layers default and the new prefix default differ observably:

```
paper square
fold --half = map .b onto .a moving .b   ; fold right half onto left: 2 layers over left half
fold --q = map .a onto .d moving .a      ; fold only the top flap's a-corner region

; assert faces = PIN_ME
```

`PIN_ME` is filled in Step 4 (see note there). For now, put a deliberately wrong value (`0`) so the assertion fails.

- [ ] **Step 2: Run to verify they fail**

Run: `dune runtest packages/core 2>&1 | grep -A2 -E 'ear-default-scope|default-stops-at-anchor'`
Expected: FAIL — `faces` assertion mismatch (got some N, expected 0). Record the *actual* N reported for each — this is the OLD (all-layers) behavior baseline.

- [ ] **Step 3: Add the two helpers**

In `packages/core/lib/eval.ml`, after `resolve_flap_cluster` ends (~line 791), add:

```ocaml
(* Default-scope anchor: the faces carrying the operand, as a UNION — a point on
   a crease shared by several flaps seeds all of them (design option (a)), so no
   ambiguity error here (unlike resolve_flap_cluster). *)
let anchor_faces (fa : Ast.flap_arg) (span : Error.span) : int list =
  match fa with
  | Ast.FlapPoint po -> (
      match faces_containing (resolve_point po) with
      | [] -> Error.fail span (Printf.sprintf "%s is not on the paper" (fstr fa))
      | fs -> fs)
  | Ast.FlapSpec (Ast.FByPoints (pts, _)) -> (
      let per_pt = List.map (fun p -> faces_containing (resolve_point p)) pts in
      match per_pt with
      | [] -> Error.fail span "empty flap selector"
      | first :: rest ->
          (match List.fold_left (fun acc l -> List.filter (fun f -> List.mem f l) acc) first rest with
           | [] -> Error.fail span (Printf.sprintf "%s is not on the paper" (fstr fa))
           | fs -> fs))
  | Ast.FlapLine _ -> resolve_flap_cluster fa span

(* Moving side for the default branch. Operands carrying explicit point(s) take
   the point's side (a shared-crease flap straddles the axis, but the tip's side
   is unambiguous — the point-anchor rule). A line operand falls back to the
   cluster extent via side_of_flap_arg_res. *)
let default_move_side (axis : Geom.line) (fa : Ast.flap_arg) (span : Error.span) : int =
  let side_of_point po =
    let s = Geom.side_of_line axis (table_of po) in
    if s = 0 then Error.fail span "the moving point lies on the fold axis" else s
  in
  match fa with
  | Ast.FlapPoint po -> side_of_point po
  | Ast.FlapSpec (Ast.FByPoints (pts, _)) -> (
      match pts with
      | po :: _ -> side_of_point po
      | [] -> Error.fail span "empty flap selector")
  | Ast.FlapLine _ -> side_of_flap_arg axis fa span
```

Note: `faces_containing`, `resolve_point`, `table_of`, `fstr`, `side_of_flap_arg` are all already defined earlier in the same `let`-scope in eval.ml; `anchor_faces`/`default_move_side` must be placed after all of them (after `side_of_flap_arg`, ~line 854, is safest — move the two definitions there if `side_of_flap_arg` is defined below `resolve_flap_cluster`).

- [ ] **Step 4: Rewrite the `up_to = None` branch**

Replace the `move_side` computation and the `up_to = None` arm. The current code (eval.ml ~1075–1099):

```ocaml
    let move_side =
      match side_override with
      | Some s -> s
      | None -> (
          match anchor_arg with
          | Some fa -> side_of_flap_arg axis fa span
          | None ->
              Error.fail span "this fold needs `moving .p` to choose the side")
    in
    let valley = fs.Ast.direction = Ast.Valley in
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
        ctx.state :=
          Fold_state.fold !(ctx.state) ~axis ~move_side ~valley
            ~crease_id ~prov
    | Some tgt -> (
```

becomes:

```ocaml
    let valley = fs.Ast.direction = Ast.Valley in
    match fs.Ast.up_to with
    | None ->
        (* Default scope: the outside-contiguous prefix down to the flap(s)
           carrying the anchor operand — not every layer on the side. *)
        let move_side =
          match side_override with
          | Some s -> s
          | None -> (
              match anchor_arg with
              | Some fa -> default_move_side axis fa span
              | None ->
                  Error.fail span "this fold needs `moving .p` to choose the side")
        in
        let seed =
          match anchor_arg with
          | Some fa -> anchor_faces fa span
          | None -> Error.fail span "this fold needs `moving .p` to choose the side"
        in
        let moving_parents =
          Fold_state.default_scope !(ctx.state) ~axis ~move_side ~valley ~seed
        in
        (match
           Fold_state.scoped_fold_hinge_closed !(ctx.state) ~axis ~move_side
             ~moving_parents
         with
        | Ok () -> ()
        | Error (ta, tb) ->
            Error.fail span
              (Printf.sprintf
                 "the moving flap is joined to a stationary layer along a \
                  segment ((%g,%g)-(%g,%g)) that is not on the fold axis — it \
                  cannot fold on its own without tearing the paper. Move those \
                  layers too, or fold along a crease on the axis."
                 (Num.to_float ta.Geom.x) (Num.to_float ta.Geom.y)
                 (Num.to_float tb.Geom.x) (Num.to_float tb.Geom.y)));
        (match check with
        | Some k -> k (fun fi -> moving_parents.(fi))
        | None -> ());
        ctx.state :=
          Fold_state.fold !(ctx.state) ~moving_parents ~axis ~move_side ~valley
            ~crease_id ~prov
    | Some tgt -> (
        let move_side =
          match side_override with
          | Some s -> s
          | None -> (
              match anchor_arg with
              | Some fa -> side_of_flap_arg axis fa span
              | None ->
                  Error.fail span "this fold needs `moving .p` to choose the side")
        in
```

i.e. the `let move_side = ...` that used to precede the `match` is **removed** from the shared position and re-bound inside each arm (default arm uses `default_move_side`; `up to` arm keeps `side_of_flap_arg`). The rest of the `Some tgt` arm (anchor resolution, `select_scope`, tear check, fold) is unchanged.

- [ ] **Step 5: Build and pin the assertions**

Run: `dune build 2>&1 | tail -5` — Expected: clean build.

Pin the two `PIN_ME` values:

```bash
dune exec beloch -- fold packages/core/tests/cases/fold/ear-default-scope.bel 2>&1 | \
  grep -c '"frame_parent"' ; echo "--- or count faces via render/inspection ---"
```

Better: read the face count directly from the evaluator the same way the assertion does — run the case through the test once with a placeholder and read the "got N" in the failure. Update each `; assert faces = PIN_ME` to the actual N the NEW evaluator produces. Then **manually verify the ear case is correct, not merely green**:

```bash
dune exec beloch -- render packages/core/tests/cases/fold/ear-default-scope.bel /tmp/ear.svg --view folded
```

Open `/tmp/ear.svg`: it must show the model with **only the b-ear folded** (or a legitimate tear error — see note), NOT the whole sheet flipped up-and-out-of-frame. If `beloch fold` on the ear case raises the tear error instead ("joined to a stationary layer … cannot fold without tearing"), that is an **acceptable** outcome (folding b onto o alone may be physically invalid without a petal fold); in that case change the ear case's trailing assertion to `; expect error "cannot fold on its own without tearing"` and note it in the file with a `; ` comment. Decide based on what the render/eval actually shows.

- [ ] **Step 6: Run the case tests to verify they pass**

Run: `dune runtest packages/core 2>&1 | grep -A2 -E 'ear-default-scope|default-stops-at-anchor'`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/core/lib/eval.ml packages/core/tests/cases/fold/ear-default-scope.bel packages/core/tests/cases/fold/default-stops-at-anchor.bel
git commit -m "feat(core): default fold scope = outside-prefix to anchor flap, not all layers"
```

---

### Task 3: Fix stale `#(...)` → `#[...]` in user-facing messages

**Files:**
- Modify: `packages/core/lib/eval.ml` (messages at ~395, 407, 454, 745–746, 789, 807–808, 1463–1464)

**Interfaces:** none (string-only change).

- [ ] **Step 1: Write the failing test**

Add a case asserting the shared-crease message now suggests `#[...]`. Create `packages/core/tests/cases/fold/shared-crease-hint.bel`:

```
paper square
fold --v = map .b onto .a moving .b
fold --h = map .d onto .a moving .d
; folding onto a point that sits on the shared crease between two flaps,
; via `up to`, must suggest the correct bracket token in its error.
fold map .a onto .c up to .a

; expect error "#["
```

(The `expect error SUBSTR` matcher is a substring test — `test_bel_assert.ml:176`. `.a` after two folds lands on the shared corner; `up to .a` routes through `target_of`/`resolve_flap_cluster` which raises the shared-crease message. If `.a` is not shared in this exact setup, adjust to a point that is — verify in Step 2 that the error text actually contains `shared by` before the fix.)

- [ ] **Step 2: Run to verify it fails**

Run: `dune runtest packages/core 2>&1 | grep -A3 shared-crease-hint`
Expected: FAIL — the raised error contains `#(...)`, not `#[`, so the `expect error "#["` substring is absent. Confirm the failure output shows the `... shared by N flaps; name the flap with #(...)` text (proving the case reaches that message).

- [ ] **Step 3: Replace the token in all occurrences**

Run:

```bash
cd packages/core && sed -i 's/#(\.\.\.)/#[...]/g; s/#(\.p)/#[.p]/g; s/#(\.a \.b \.c)/#[.a .b .c]/g' lib/eval.ml
```

Then grep for any survivors and fix by hand:

```bash
grep -n '#(' lib/eval.ml
```

Expected after: no `#(` remaining in user-facing strings in `eval.ml`. (Leave code/comments that legitimately use parens alone — only the `#(` selector spellings change. The three sed patterns cover the known forms `#(...)`, `#(.p)`, `#(.a .b .c)`; hand-fix anything else grep surfaces.)

- [ ] **Step 4: Run to verify it passes**

Run: `dune build 2>&1 | tail -3 && dune runtest packages/core 2>&1 | grep -A2 shared-crease-hint`
Expected: build clean; `shared-crease-hint` PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/core/lib/eval.ml packages/core/tests/cases/fold/shared-crease-hint.bel
git commit -m "fix(core): flap-selector hint says #[...] not #(...) (matches lexer token)"
```

---

### Task 4: Update the spec prose

**Files:**
- Modify: `spec/SPECIFICATION.md` (§fold scope, ~575–655; version-history line ~47)

**Interfaces:** none (docs).

- [ ] **Step 1: Rewrite the Scope section**

In `spec/SPECIFICATION.md`, the `**Scope.**` block (~613–630) currently reads that "No `up to` (default): every layer on the anchor's side moves". Replace the first bullet with:

```markdown
- **No `up to`** (default): the moving set is the **outside-contiguous prefix**
  of the layer order over the crease region — top for valley, bottom for
  mountain — down to **and including** the flap(s) carrying the anchor operand.
  The anchor operand is `moving` when present, or the implied source point on a
  map fold (`fold map .b onto .o` → `.b`). It is *not* every layer on the
  anchor's side: deeper layers below the anchor flap stay. A point on a crease
  shared by several flaps seeds **all** of them (the whole contiguous run), so
  the tip you would physically grab is a valid anchor. On a single-layer region
  (e.g. a first fold on flat paper) the prefix is that one flap — identical to
  the pre-change behaviour.
```

Update the **Anchor** paragraph (~581–585, the table row and the "anchor — the flap that starts the moving set" line) so `moving`/anchor is described as the **deepest** flap of the prefix, not the "start": in the ingredients table (~581) change the `anchor` row's "What" to `the deepest flap of the moving prefix` and its "Source" stays `implied on map folds, or moving`.

In the **Validity — outer-contiguous prefix** paragraph (~632–644), change the sentence "The all-layers default satisfies the prefix trivially" to:

```markdown
The default scope is itself an outer-contiguous prefix by construction (it grows
outward from the anchor flap), so it satisfies the prefix rule; a genuine tear
(the anchor flap hinged to a stationary layer off the axis) is caught by the
same hinge-closure check the `up to` path uses.
```

- [ ] **Step 2: Update the version-history line**

In the `**v0.19-dev**` / version list (~47) — find the current top `-dev` entry and prepend a note for the next dev version:

```markdown
**v0.22-dev** (default fold scope is the outside-prefix down to the anchor flap,
not all layers on the side; a shared-crease tip seeds the whole contiguous run;
`up to` unchanged as the interim way to fold deeper);
```

(Use the actual next version number — check the highest `vN-dev` already present and increment; the design note calls it "next `-dev`". If unsure, match the version string already emitted by `beloch --version` / `file_creator`.)

- [ ] **Step 3: Verify the spec references are consistent**

Run: `grep -n 'every layer on the anchor' spec/SPECIFICATION.md`
Expected: no matches remain that describe the *default* as all-layers (the `up to`-context mentions may stay if they describe the old behavior historically — verify each; there should be none claiming it is the current default).

- [ ] **Step 4: Commit**

```bash
git add spec/SPECIFICATION.md
git commit -m "docs(spec): default fold scope is prefix-to-anchor, not all layers"
```

---

### Task 5: Render-verify the base examples (do NOT touch goldens)

**User decision (option a):** the golden suite is **already pre-existing-broken**
on this branch (all 3 bases fail with large structural drift, 54–466 lines,
unrelated to this feature — a prior session marked it "don't chase"). Do **not**
regenerate or edit any golden `.fold` file in this task — that drift is a separate
cleanup. This task only confirms the scope change didn't visually break the bases.

**Files:**
- Possibly modify: `examples/bases/kite.bel` (and/or fish-base, swivel-rabbit)
  ONLY if a base renders wrong and needs an explicit `up to <flap>` to restore it.
- Do NOT touch `packages/core/tests/golden/**`.

**Interfaces:** none.

- [ ] **Step 1: Render each base's folded form after the scope change**

```bash
cd /home/toph/Projects/beloch
for b in kite fish-base swivel-rabbit; do
  direnv exec /home/toph/Projects/beloch dune exec beloch -- render examples/bases/$b.bel /tmp/$b.svg --view folded 2>&1 | tail -1
done
```

Expected: three SVGs written, no evaluation errors. If any base now raises a
`fold` error (e.g. a later fold that used to catch all layers now can't reach a
layer it needs), that base's later `fold` needs an explicit `up to <deeper-flap>`
— add it to the `.bel` and re-render until clean.

- [ ] **Step 2: Eyeball each SVG against the finished model**

Open `/tmp/kite.svg`, `/tmp/fish-base.svg`, `/tmp/swivel-rabbit.svg`. Each must
still look like its finished base (kite / fish base / swivel-rabbit rabbit-ear),
NOT a half-flipped or under-folded sheet. Compare against the pre-change baseline
folds saved at `$CLAUDE_JOB_DIR/tmp/golden-baseline/<base>.fold` if a structural
question arises (those are the pre-change `beloch fold` outputs, basename spans).
If a base folds too little (a layer that should move now stays), fix that base's
later fold with an explicit `up to <flap>` and re-render.

- [ ] **Step 3: Commit (only if a base .bel was edited)**

If Step 1/2 required editing a base `.bel`, commit just that:

```bash
git add examples/bases   # NOT tests/golden
git commit -m "fix(examples): scope <base>'s fold with `up to` under prefix-default"
```

If no base needed editing, this task produces no commit — record in the ledger
that all three bases render correctly unchanged, and move on. Do not stage or
commit any golden file.

---

## Self-Review

**Spec coverage** (against `notes/2026-07-20-default-fold-scope.md`):
- Default scope = outside-prefix to anchor → Task 1 (`default_scope`) + Task 2 (wiring). ✓
- `moving` names deepest flap → Task 2 semantics + Task 4 prose. ✓
- Shared-crease option (a), no ambiguity error → Task 2 `anchor_faces` union. ✓
- Straddle dissolves (point side) → Task 2 `default_move_side`. ✓
- First folds unchanged → Task 1 single-layer degenerates to that flap; Task 5 confirms unaffected goldens. ✓
- Deeper via explicit `up to` untouched → Task 2 leaves `Some tgt` arm intact. ✓
- Tear check on the new default → Task 2 `scoped_fold_hinge_closed`. ✓
- Nit `#(...)`→`#[...]` → Task 3. ✓
- Out of scope (dedicated "fold more", option (b)) → not implemented. ✓

**Placeholder scan:** The only intentional deferred value is `PIN_ME` in Task 2, with an explicit step (2 → record baseline; 5 → pin new value + render-verify) to resolve it before the task's commit. No `TODO`/`TBD` in shipped code.

**Type consistency:** `default_scope : … -> seed:int list -> bool array` used identically in Task 1 (def/mli) and Task 2 (call). `anchor_faces`/`default_move_side` signatures match their call sites in the rewritten branch. `scoped_fold_hinge_closed` / `Fold_state.fold ~moving_parents` reuse the exact signatures already used by the `Some tgt` arm.

**Risk note:** If Task 2 Step 5 shows the ear case raises the tear error rather than folding, that is expected-and-acceptable (the `expect error` fallback is specified). The plan does not assume the ear is foldable — only that it stops flipping the whole sheet.
