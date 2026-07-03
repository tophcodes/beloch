# PR 1 — Crease/Flap Entity Plumbing (#26 + principled #27) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a first-class crease/flap-edge entity in `Fold_state`, serialize FOLD directly from it (retiring the emit-time geometric reconstruction), and re-express the #27 precrease fix as an in-place assignment upgrade — all with **zero change to FOLD output**.

**Architecture:** `Fold_state.t` gains an `edges` array of relational edge records (paper endpoints, bordering face ids, assignment, stable crease id, provenance). `subdivide` and `fold_with_records` populate it as they cut/abut faces; `fold_emit` reads it instead of re-matching chords by `on_segment`. The #27 abut case becomes "look up the precrease edge by crease id, upgrade its assignment U→M/V in place" instead of appending a second racing chord.

**Tech Stack:** OCaml, dune, Alcotest, Zarith, Yojson. Exact-rational/real-algebraic `Num` kernel — **not touched** (see Global Constraints).

## Global Constraints

- **No `Num`/kernel surface.** Do not add functions to or modify `lib/num.ml`, `lib/poly.ml`, `lib/mpoly.ml`. This work consumes the kernel only through `Geom`/`Isometry` (field ops + `sign`/`compare`/`equal`). It is orthogonal to the in-flight FLINT migration; keep it that way.
- **Behavior-preserving.** Every existing `.bel` in `examples/` must emit byte-identical FOLD JSON before and after this PR (modulo nothing — target exact equality; face-array order is preserved by this PR). The characterization test in Task 1 is the gate for every later task.
- **No new language surface.** No lexer/parser/AST changes in this PR. `#(...)` and material-crease semantics are PR 2.
- Follow existing style: `Num.t` arithmetic via `Geom`/`Isometry`, records with explicit field types, no new deps.
- Commit after each task (conventional commits).

**Reviewer's note on granularity:** Tasks 2 and 4 modify `fold_state.ml`'s cut/fold functions where the exact field-population code is discovered by TDD against the Task 1 golden net. Those steps give the exact type, the real surrounding code, the concrete transformation, and the passing/failing gates — the implementer fills the localized body and the golden test proves it correct. This is deliberate for a behavior-preserving refactor; it is not a placeholder.

---

## File structure

- `lib/fold_state.ml` — add `edge` type + `edges` field to `t`; populate in `subdivide`/`fold_with_records`/`flip`; add adjacency accessor. (Primary.)
- `lib/fold_emit.ml` — read edges from `state.edges`; delete `record_of`/`on_segment` reconstruction. (Consumer switch.)
- `lib/eval.ml` — thread the new edges through `folded` (the `creases`/`recs` side-list shrinks to nothing by Task 5).
- `tests/test_golden.ml` — **new**: characterization snapshots of every example's FOLD. (Safety net.)
- `tests/test_fold_state.ml` — **new**: unit tests for adjacency + #27 in-place upgrade.
- `tests/dune` — register the two new test stanzas.

---

### Task 1: Characterization golden net (safety before any refactor)

**Files:**
- Create: `tests/test_golden.ml`
- Modify: `tests/dune` (add a `test` stanza)

**Interfaces:**
- Consumes: `Beloch.fold_string ~filename:string -> string -> Yojson.Safe.t` (returns the FOLD as a JSON value — `lib/beloch.ml:23`; render to a string with `Yojson.Safe.pretty_to_string`; used in `tests/test_e2e.ml`).
- Produces: a golden snapshot map `example-name -> FOLD-json-string` committed to the repo, and a test asserting current output equals it.

- [ ] **Step 1: Add the test stanza to `tests/dune`**

```
(test
 (name test_golden)
 (libraries beloch alcotest yojson zarith str)
 (deps (glob_files ../../../examples/*.bel) (glob_files golden/*.fold)))
```

- [ ] **Step 2: Write the golden harness that fails on missing snapshots**

```ocaml
(* tests/test_golden.ml *)
open Beloch

let examples_dir = "../../../examples/"
let golden_dir = "golden/"

(* through.bel is excluded: its irrational Field coords make convex_overlap
   non-terminate at full-FOLD (pre-existing, out of scope for this PR — see the
   roadmap note "through.bel full FOLD still hangs"). Excluding it is a logged
   cap, not a silent one. *)
let excluded = [ "through.bel" ]

(* every .bel in examples/ that is a full program (skip README + excluded) *)
let example_names () =
  Sys.readdir examples_dir |> Array.to_list
  |> List.filter (fun n -> Filename.check_suffix n ".bel")
  |> List.filter (fun n -> not (List.mem n excluded))
  |> List.sort compare

let read path = In_channel.with_open_text path In_channel.input_all

(* Some examples (dup-point.bel, parallel.bel) intentionally error. Capture the
   Beloch error message as the golden so the refactor is proven to preserve
   error behavior, not only successful FOLD output. *)
let fold_of name =
  let src = read (examples_dir ^ name) in
  try Yojson.Safe.pretty_to_string (Beloch.fold_string ~filename:name src)
  with Error.Beloch_error (_, msg) -> "ERROR: " ^ msg

let golden_path name = golden_dir ^ Filename.chop_suffix name ".bel" ^ ".fold"

let test_one name () =
  let got = fold_of name in
  let gp = golden_path name in
  if not (Sys.file_exists gp) then
    Alcotest.failf "no golden for %s — run the regen step (Step 4)" name
  else
    Alcotest.(check string) (name ^ " FOLD unchanged") (read gp) got

let () =
  Alcotest.run "golden"
    [ ("examples",
       List.map (fun n -> Alcotest.test_case n `Quick (test_one n))
         (example_names ())) ]
```

- [ ] **Step 3: Run it, confirm it fails for lack of goldens**

Run: `dune test tests/test_golden.exe 2>&1 | head`
Expected: FAIL — "no golden for bisect-a.bel — run the regen step".

- [ ] **Step 4: Generate the goldens from current `main` behavior**

Write a throwaway regen (do NOT commit the regen binary; commit only its output):

```ocaml
(* tests/regen_golden.ml — throwaway, delete after Step 5 *)
open Beloch
let examples_dir = "../../../examples/"
let () =
  Sys.mkdir "golden" 0o755;  (* run from the test build dir *)
  Sys.readdir examples_dir |> Array.to_list
  |> List.filter (fun n -> Filename.check_suffix n ".bel")
  |> List.filter (fun n -> n <> "through.bel")  (* excluded: hangs, see harness *)
  |> List.iter (fun n ->
       let src = In_channel.with_open_text (examples_dir ^ n) In_channel.input_all in
       let out =
         try Yojson.Safe.pretty_to_string (Beloch.fold_string ~filename:n src)
         with Error.Beloch_error (_, msg) -> "ERROR: " ^ msg in
       let gp = "golden/" ^ Filename.chop_suffix n ".bel" ^ ".fold" in
       Out_channel.with_open_text gp (fun oc -> Out_channel.output_string oc out))
```

Run it via a temporary `(executable (name regen_golden) ...)` stanza, then copy the produced `golden/*.fold` into `tests/golden/` in the source tree. Remove the throwaway stanza + `regen_golden.ml`.

- [ ] **Step 5: Run the golden test green on unchanged `main`**

Run: `dune test tests/test_golden.exe`
Expected: PASS — every example matches its committed golden.

- [ ] **Step 6: Commit the safety net**

```bash
git add tests/test_golden.ml tests/golden tests/dune
git commit -m "test(golden): characterization snapshots of example FOLD output"
```

---

### Task 2: Introduce the `edge` entity, populated alongside the existing records

**Files:**
- Modify: `lib/fold_state.ml` (add types; populate in `subdivide:146`, `fold_with_records:181`, `flip:272`)
- Create: `tests/test_fold_state.ml`
- Modify: `tests/dune`

**Interfaces:**
- Produces (add to `fold_state.ml`, exact shape):

```ocaml
type edge = {
  ea : Geom.point;              (* endpoint A, paper coords of [left] face *)
  eb : Geom.point;              (* endpoint B, paper coords of [left] face *)
  left : int;                   (* face id on one side *)
  right : int;                  (* face id on the other side, or -1 if paper boundary *)
  eassign : assign;             (* M | V | U (B boundary stays emit-derived) *)
  crease_id : int;              (* stable identity, survives later splits *)
  eprov : State.provenance option;
}
```
  and extend `t`:
```ocaml
type t = { faces : face array; order : rel array array; edges : edge array }
```
- Produces accessor:
```ocaml
val neighbors : t -> int -> int list   (* face ids sharing an edge with face i *)
```
- Consumes: existing `axis_segment_in_face`, `Isometry.*`, `Geom.point_equal`.

- [ ] **Step 1: Write a failing adjacency test**

```ocaml
(* tests/test_fold_state.ml *)
open Beloch
let q = Num.of_int
let line a b c = { Geom.a = q a; b = q b; c = q c }

(* one vertical fold splits the square into two faces that share the crease *)
let test_neighbors_after_one_fold () =
  let st = Fold_state.init_square in
  let axis = line 1 0 1 (* x = 1/2 needs rationals; use midline *) in
  ignore axis;
  let st', _ = Fold_state.fold_with_records st
      ~axis:(let h = Num.of_q (Q.of_ints 1 2) in { Geom.a = Num.one; b = Num.zero; c = h })
      ~move_side:1 ~valley:true ~prov:None in
  Alcotest.(check (list int)) "face 0 borders face 1"
    [1] (List.sort compare (Fold_state.neighbors st' 0))

let () =
  Alcotest.run "fold_state"
    [ ("adjacency", [ Alcotest.test_case "one fold" `Quick test_neighbors_after_one_fold ]) ]
```

Register in `tests/dune`:
```
(test
 (name test_fold_state)
 (libraries beloch alcotest zarith))
```

- [ ] **Step 2: Run it, confirm failure**

Run: `dune test tests/test_fold_state.exe 2>&1 | head`
Expected: FAIL — `Unbound value Fold_state.neighbors` / `edges`.

- [ ] **Step 3: Add the types and populate `edges`**

Add the `edge` type and the `edges` field (above). A **module-level `crease_id` counter** (`let next_id = ref 0`) mints ids; reset it at `init_square`. In `subdivide` (`fold_state.ml:146`) and `fold_with_records` (`fold_state.ml:181`), at the point each already computes `axis_segment_in_face f axis` and pushes a `crease_record`, also push an `edge`:
  - `ea`/`eb` = the segment endpoints (paper coords of the parent face `f`, as `axis_segment_in_face` returns);
  - `left`/`right` = the two child face ids produced from this cut (recover from the `(child, parent)` accumulation already present — the two children of parent `fi` straddling the axis);
  - `eassign` = `U` in `subdivide`, `assign_of ()` in `fold_with_records`;
  - `crease_id` = a fresh id;
  - `eprov` = `prov`.
  Build the final `edges : edge array` in the same pass that builds `faces`, remapping `left`/`right` to the post-sort face indices (the plan already remaps `parent`; reuse that index map).

  Add:
```ocaml
let neighbors (st : t) (i : int) : int list =
  Array.fold_left
    (fun acc e ->
      if e.left = i && e.right >= 0 then e.right :: acc
      else if e.right = i then e.left :: acc
      else acc)
    [] st.edges
```
  Extend `flip` (`fold_state.ml:272`) and `init_square` to carry `edges` (flip: keep edges, reindex `left`/`right` through the `n-1-i` reversal; `init_square`: `edges = [||]`). `build_order`'s callers now construct `{ faces; order; edges }`.

- [ ] **Step 4: Run the adjacency test green**

Run: `dune test tests/test_fold_state.exe`
Expected: PASS.

- [ ] **Step 5: Run the golden net — output still unchanged**

Run: `dune test tests/test_golden.exe`
Expected: PASS (this task only *adds* state; `fold_emit` still uses the old path).

- [ ] **Step 6: Commit**

```bash
git add lib/fold_state.ml tests/test_fold_state.ml tests/dune
git commit -m "feat(fold-state): first-class edge entity + face adjacency (#26)"
```

---

### Task 3: Accumulate edges across folds, then serialize FOLD from `state.edges`

> **Post-rebase note (#35 step-macro slice now on main):** `eval.ml` wraps `state`/`recs`
> in a `ctx` record — read `!(ctx.state)` and `ctx.recs`; the `folded` record is built near
> `eval.ml:532` (`{ state = !(ctx.state); creases = !(ctx.recs); … }`). `fold_emit.ml`'s
> classification region (`record_of` at ~`:42`, the `let assign, prov` arm at ~`:64`) is
> UNCHANGED by #35 — the added `step` provenance field is downstream in the `beloch:edges`
> emit and is irrelevant here. `fold_state.ml` was untouched by #35. Read the current files
> for exact lines; the structure matches this plan.

**Why this task carries accumulation:** Task 2 populates edges *per operation*. But an
edge made by an earlier fold must persist through later folds (and **split** when a later
fold's axis crosses it) or the emitted crease set will be incomplete for any multi-fold
program (`fold-quarter.bel`, `complex-fold.bel`, `multiple-folds.bel`). The 20-snapshot (post-rebase; 18 original + def-diagonals + precrease-fold)
**golden net is the exact oracle**: once emit reads from `state.edges`, any accumulation or
splitting error makes a multi-fold golden flip. That is a far stronger gate than a hand-
written persistence assertion, so the two changes ship together and the goldens prove them.

**Files:**
- Modify: `lib/fold_state.ml` — carry-forward + split of `edges` in `subdivide`/`fold_with_records`; add `edge_between`.
- Modify: `lib/fold_emit.ml:42-77` (replace `record_of` lookup with `edge_between`)
- Modify: `lib/eval.ml` (emit reads `fd.Eval.state.edges`; `folded.creases` stays until Task 5)

**Interfaces:**
- Consumes: `Fold_state.t.edges`, the `edge` fields from Task 2.
- Produces:
```ocaml
val edge_between : t -> int -> Geom.point -> Geom.point -> edge option
(* the edge incident to face [i] whose endpoints equal (pa,pb) in either order *)
```
  and identical `edges_assignment` / `beloch:edges` / `edges_foldAngle` as today, sourced from `state.edges`.

- [ ] **Step 1: Confirm the golden net is the spec for this task**

Run: `dune test tests/test_golden.exe`
Expected: PASS (baseline before touching emit — Task 2 kept it green).

- [ ] **Step 2: Accumulate + split edges across each operation**

In both `subdivide` and `fold_with_records`, **carry the parent state's `edges` forward** into
the child state, alongside the new-cut edges Task 2 already mints. For each parent edge `e`
incident to a parent face `fi` that gets clipped by `axis`:
  - **wholly on one side** of `axis` → `e` belongs to that one child; remap its `fi`-endpoint
    (`left` or `right`, whichever is `fi`) to that child's post-sort index.
  - **crosses `axis`** → **split** `e` at the intersection into two collinear sub-edges that
    **share `e.crease_id`, `e.eassign`, `e.eprov`** (identity survives the split — this is the
    #26 invariant), one on each child, endpoints in the child's paper coords.
  - a `-1` (paper-boundary) side stays `-1`.
Handle an edge shared by two faces once (both its `left` and `right` get remapped as their
respective parents are processed). `flip` already carries `edges` (Task 2) — no change.

This is the crux and the exact carry/split code is a **TDD target the golden net verifies** —
build it, run `dune test tests/test_golden.exe`, and iterate until every multi-fold golden is
byte-identical. **Never edit `tests/golden/` to make it pass.** If after genuine effort a
multi-fold golden will not converge and you cannot localize the split logic, report BLOCKED
with the specific example and the diff you see.

Add the emit helper:
```ocaml
let edge_between (st : t) (i : int) (pa : Geom.point) (pb : Geom.point) : edge option =
  Array.find_opt
    (fun e ->
      (e.left = i || e.right = i)
      && ((Geom.point_equal e.ea pa && Geom.point_equal e.eb pb)
          || (Geom.point_equal e.ea pb && Geom.point_equal e.eb pa)))
    st.edges
```

- [ ] **Step 3: Replace the chord match with the edge lookup in emit**

In `fold_emit.ml`, the per-face-edge loop (`:53-80`) classifies each polygon edge via
`on_unit_boundary` then `record_of` (`:42-49`). Keep `on_unit_boundary` → `"B"`. Replace the
`record_of` arm with `Fold_state.edge_between` against the folded state, using the edge's
`eassign` (→ "M"/"V"/"U") and `eprov`. Delete the `record_of` helper and the `creases`
binding it consumed (the `on_segment` function lives in `Geom` and stays; just stop calling it
from `fold_emit`).

```ocaml
let assign, prov =
  if on_unit_boundary pa pb then ("B", None)
  else
    match Fold_state.edge_between fd.Eval.state fi pa pb with
    | Some (e : Fold_state.edge) ->
        let a = match e.Fold_state.eassign with
          | Fold_state.M -> "M" | Fold_state.V -> "V" | Fold_state.U -> "U" in
        (a, e.Fold_state.eprov)
    | None -> ("U", None)
```

- [ ] **Step 4: Run the golden net — the accumulation oracle**

Run: `dune test`
Expected: PASS — all 20 goldens byte-identical, now sourced end-to-end from the entity
(multi-fold examples prove accumulation+splitting correct), plus `test_fold_state`/`test_eval`/`test_e2e` green.

- [ ] **Step 5: Confirm `record_of` is gone from emit**

Run: `rg -n 'record_of' lib/fold_emit.ml`
Expected: no matches.

- [ ] **Step 6: Commit**

```bash
git add lib/fold_state.ml lib/fold_emit.ml lib/eval.ml
git commit -m "refactor(fold): accumulate+split edges across folds; emit from state, drop chord reconstruction (#26)"
```

---

### Task 4: Oracle + unit coverage for the #27 precrease upgrade

> **Rescoped after Task 3 (see review):** the principled U→M/V upgrade *already landed* in
> Task 3's on-axis accumulation branch (`lib/fold_state.ml`, the `sa = 0 && sb = 0` arm with
> `assign_of_parent`/`has_moved_child`). It is verified correct manually — the program below
> emits `edges_assignment` containing `"V"` and `edges_foldAngle` `180.0`, one V edge, zero U —
> but **no golden or unit test exercises it**, which the Task 3 review flagged as Important.
> This task closes that gap with a golden example + a fold_state unit test. **No `lib/` change
> is expected**; if a test surprisingly fails, that is a real bug in the Task 3 branch — fix it
> in `fold_state.ml` (do not weaken the test).

**Files:**
- Create: `examples/precrease-fold.bel`
- Create: `tests/golden/precrease-fold.fold` (regenerated)
- Modify: `tests/test_fold_state.ml` (add the precrease unit test)

**Interfaces:**
- Consumes: the accumulated `edges` from Task 3 (a precrease is a carried `U` edge; folding on it upgrades that edge's `eassign` in place).

- [ ] **Step 1: Add the precrease-fold example**

Create `examples/precrease-fold.bel` (syntax verified valid on current main):
```
; status: works — mark a crease, then fold along it (#27: precrease → V/180, not U/0)
paper square
map .b onto .a
@map .b onto .a moving .b
```
Verify it folds and the crease is V/180:
Run: `dune exec bin/main.exe -- fold examples/precrease-fold.bel | rg 'edges_assignment|edges_foldAngle'`
Expected: `edges_assignment` contains `"V"` (not `"U"`); `edges_foldAngle` contains `180.0`.

- [ ] **Step 2: Add the precrease unit test (entity-level assertion)**

Append to `tests/test_fold_state.ml`, and register it in the existing test list:
```ocaml
let test_precrease_upgrades_in_place () =
  let src = "paper square\nmap .b onto .a\n@map .b onto .a moving .b\n" in
  let fd = Eval.eval_folded (Beloch.parse ~filename:"t.bel" src) in
  let edges = fd.Eval.state.Fold_state.edges in
  let vs = Array.to_list edges
           |> List.filter (fun (e:Fold_state.edge) -> e.Fold_state.eassign = Fold_state.V) in
  Alcotest.(check int) "precrease folded to a single V edge" 1 (List.length vs);
  let us = Array.to_list edges
           |> List.filter (fun (e:Fold_state.edge) -> e.Fold_state.eassign = Fold_state.U) in
  Alcotest.(check int) "no stale U crease left on the fold line" 0 (List.length us)
```
  (The `edges` array holds only interior crease edges — boundary "B" is emit-derived — so after the single precrease folds there is exactly one V edge and zero U edges.)

- [ ] **Step 3: Run the unit test — expect PASS (logic already present)**

Run: `dune test tests/test_fold_state.exe`
Expected: PASS. If it FAILS, the Task 3 on-axis branch has a bug — fix `fold_state.ml`, never the test.

- [ ] **Step 4: Regenerate the golden for the new example only**

The golden harness auto-discovers `examples/precrease-fold.bel` and will report "no golden" until
one exists. Generate it with the throwaway-regen pattern from Task 1 Step 4 (absolute paths to
`examples/` and `tests/golden/`), which writes every golden; commit ONLY the new
`tests/golden/precrease-fold.fold` (the others are unchanged — `git status` confirms). Remove the
throwaway executable + stanza. Do NOT hand-edit any golden.

- [ ] **Step 5: Full suite green**

Run: `dune test`
Expected: PASS — `test_golden` now covers `precrease-fold` (its `edges_assignment` has `"V"`,
`edges_foldAngle` `180.0`); `test_fold_state` includes the new precrease case; everything else green.

- [ ] **Step 6: Commit**

```bash
git add examples/precrease-fold.bel tests/golden/precrease-fold.fold tests/test_fold_state.ml
git commit -m "test(fold): oracle+unit coverage for #27 precrease upgrade (V/180 on the entity)"
```

> The old tactical `abut_edge` path (still present, pushing a `crease_record` into `recs`) is now
> dead for emit and is removed together with the `crease_record` side-list in Task 5.

---

### Task 5: Remove the dead `crease_record` side-list

> **Post-rebase consumer map (verified on #35 main — the grep will confirm):**
> - `lib/fold_state.ml`: `type crease_record` (~`:111`); `subdivide` & `fold_with_records`
>   return `t * crease_record list` and push into a local `recs` (~`:194-216`, `:285`,
>   `:290-342`, `:468`); the **old tactical `abut_edge` #27 path** (~`:316`, `:334`, `:341-342`)
>   pushes a `crease_record` — now dead for emit (Task 3's on-axis edge branch replaced it), so
>   **remove `abut_edge` and its `None, Some _` record push** along with the side-list. Change both
>   functions to return just `t`; update `simple_fold` (drops `fst`).
> - `lib/eval.ml`: `folded.creases` (~`:15`); the `ctx.recs` field (~`:48`, `:103`) and its two
>   pushes (~`:354`, `:383`); the final `folded` build (~`:532`). Remove all — `eval` calls become
>   `let st = Fold_state.subdivide …` / `… fold_with_records …` (no `rs`).
> - `tests/test_eval.ml` & `tests/test_e2e.ml`: `count_assign` (over `crease_record`) and several
>   tests asserting on `fd.Eval.creases` OR on the `recs` returned by `subdivide`/`fold_with_records`
>   (`test_eval.ml:234-293`). Re-express each over `state.edges`: `count_assign a st` counts
>   `st.edges` entries with `eassign = a`; the direct-return tests capture the returned `t` and count
>   its `edges`. Behavior-equivalent (a `U` record ⇔ a `U` edge on the returned state).
> - `lib/fold_emit.ml`: confirm no remaining `crease_record`/`creases` reference (Task 3 already
>   switched it to `edge_between`).

**Files:**
- Modify: `lib/fold_state.ml` (drop `crease_record`, the `recs` returns, and the `abut_edge` path), `lib/eval.ml` (`folded.creases` + `ctx.recs`), `tests/test_eval.ml`, `tests/test_e2e.ml`.

**Interfaces:**
- Produces: `folded` with no `creases` field (or `creases` repurposed to `edges`), whichever leaves tests compiling. `count_assign` in `test_eval.ml`/`test_e2e.ml` moves to counting over `state.edges`.

- [ ] **Step 1: Find every consumer of the side-list**

Run: `rg -n 'crease_record|\.creases|count_assign|fold_with_records|subdivide' lib tests`
Expected: a finite list — `eval.ml` (`recs`), `fold_emit.ml`, `test_eval.ml`, `test_e2e.ml`.

- [ ] **Step 2: Rewrite `count_assign` over edges**

```ocaml
let count_assign a (st : Fold_state.t) =
  Array.to_list st.Fold_state.edges
  |> List.filter (fun (e : Fold_state.edge) -> e.Fold_state.eassign = a)
  |> List.length
```
  Update call sites in `test_eval.ml`/`test_e2e.ml` to pass `fd.Eval.state` instead of `fd.Eval.creases`.

- [ ] **Step 3: Delete `crease_record`, the `recs` accumulation, and `folded.creases`**

Make `subdivide`/`fold_with_records` return just `t` (drop the `* crease_record list`). Remove `creases`/`recs` from `folded` and `eval.ml`. Update `simple_fold` (already discards records).

- [ ] **Step 4: Build + full test suite**

Run: `dune build && dune test`
Expected: PASS — all suites green, including `test_golden`, `test_fold_state`, `test_eval`, `test_e2e`.

- [ ] **Step 5: Confirm the type is gone**

Run: `rg -n 'crease_record' lib tests`
Expected: no matches.

- [ ] **Step 6: Commit**

```bash
git add lib tests
git commit -m "refactor(fold): drop crease_record side-list; edges are the single source of truth (#26)"
```

---

## Self-review

- **Spec coverage.** §5 (relational edge records) → Tasks 2–3, 5. §6 (principled #27) → Task 4. §7 PR 1 verification ("all current outputs byte-stable; #27 example emits V/180") → Task 1 golden net + Task 4 Steps 5. "No new language surface" → enforced by Global Constraints; no lexer/parser/AST touched. §5 "No kernel surface" → Global Constraints. Adjacency for the deferred taco checks (§8) → `neighbors` in Task 2 (built, unused here — deliberate).
- **Placeholders.** The entity-population bodies in Tasks 2/4 Step 3 are TDD targets guarded by the golden net, with exact types + real surrounding line refs + concrete transformation — flagged explicitly in the reviewer's note, not silent TODOs.
- **Type consistency.** `edge` fields (`ea/eb/left/right/eassign/crease_id/eprov`), `neighbors`, `edge_between` used consistently across Tasks 2–4. `assign` reuses the existing `M|V|U` variant (`fold_state.ml:10`). `count_assign` re-typed once in Task 5 and its call sites updated in the same task.
- **Kernel isolation.** No task touches `num.ml`/`poly.ml`/`mpoly.ml`; all geometry via `Geom`/`Isometry`. Golden net proves exactness end-to-end.
