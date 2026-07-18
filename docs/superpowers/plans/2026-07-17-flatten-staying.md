# flatten stayer anchoring — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `flatten` states which material stays (leading-element convention +
`(staying <flap>)`); the solver anchors sector parity there, killing the
mirror-world bug (#52) and the improper-anchor fallback.

**Architecture:** Three layers touched in order: grammar (`staying` replaces
`standing`), collapse kernel (stayer-anchored fan labeling, one pipeline run
per admissible stayer sector), eval (leading-element arc, per-element segment
candidates, staying wiring). Then cases/spec migration.

**Tech Stack:** OCaml (dune), menhir parser, Alcotest unit tests, `.bel`
inline-assertion cases via `test_bel_assert`.

**Spec:** `docs/superpowers/specs/2026-07-17-flatten-staying-design.md` — read
it first; it is the contract. Empirics: `notes/2026-07-17-flatten-parity-origin.md`.

## Global Constraints

- Branch: work on `fix/flatten-anchor-parity` (continues the parity work; the
  taco checks `ab8aa12`/`f3361d7` are prerequisites, the fallback `1a4f6d9`
  gets deleted here).
- Breaking existing tests/goldens is EXPECTED and fine (standing directive
  2026-07-17); never keep a wrong behavior for compatibility.
- Error strings are contracts: new texts exactly as written in the spec's
  Errors table; `standing folds are not yet supported` must disappear.
- Build/test: `dune build 2>&1 | head -50`, `dune test 2>&1 | tail -30`.
- `Collapse.collapse` keeps its single-or-`e_ambig` contract (tests use it);
  only its anchoring/stayer plumbing changes.
- The #51 trio (`flatten-fish-pinned-unique.bel`,
  `flatten-opposite-ray-toward-{b,d}.bel`, opposite-ray test in
  `test_flatten.ml`) stays red — do NOT chase those failures here.

---

### Task 1: Grammar — `staying` replaces `standing`

**Files:**
- Modify: `lib/lexer.ml:34` (keyword table)
- Modify: `lib/parser.mly` (token, `collapse_item_inner`, `mk_flatten`)
- Modify: `lib/ast.ml:127-140` (comment only — the `flap_arg option` slot stays)
- Modify: `lib/eval.ml:1719-1722` (accept, don't reject)
- Delete: `tests/cases/collapse/collapse-standing.bel`

**Interfaces:**
- Produces: `Ast.Flatten (name, elems, overs, staying_opt, toward_opt, span)`
  where `staying_opt : Ast.flap_arg option` now means the staying flap.
  Task 3 consumes `staying_opt`; until then eval ignores it (`ignore staying_opt`).

- [ ] **Step 1: Delete the standing case file**

```bash
git rm tests/cases/collapse/collapse-standing.bel
```

- [ ] **Step 2: Rename the keyword and token**

`lib/lexer.ml:34`: `| "standing" -> STANDING` → `| "staying" -> STAYING`.
`lib/parser.mly`: token declaration `STANDING` → `STAYING`; rule
`| STANDING flap_arg { CStanding ($2, $loc) }` → `| STAYING flap_arg
{ CStaying ($2, $loc) }`; rename the `CStanding` constructor to `CStaying`
where `collapse_item` is defined; in `mk_flatten` rename the fold-left case
and the duplicate error to:

```ocaml
| CStaying (f, sp) -> (
    match st with
    | Some _ -> Error.fail sp "only one staying clause per flatten"
    | None -> (es, os, Some f, tw))
```

- [ ] **Step 3: eval accepts staying (inert for now)**

`lib/eval.ml:1719-1722`: rename the binding `standing_opt` → `staying_opt` and
replace the rejection with a no-op:

```ocaml
| Ast.Flatten (name_opt, elems, overs, staying_opt, toward_opt, span) ->
    ignore staying_opt;  (* wired in Task 3 *)
```

Update the `ast.ml` comment on the `Flatten` constructor: the slot is the
staying flap (spec 2026-07-17), no longer "reserved standing".

- [ ] **Step 4: Build and test**

Run: `dune build 2>&1 | head -30` — expect clean.
Run: `dune test 2>&1 | tail -20` — expect the same failures as before this
task minus the standing case (two-ears + derive-13 + #51 trio red; nothing NEW).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(flatten): staying clause replaces reserved standing"
```

---

### Task 2: Collapse kernel — stayer-anchored pipeline

**Files:**
- Modify: `lib/collapse.ml` (the bulk: stayer type, rotation, fallback deletion)
- Modify: `tests/test_collapse.ml` (all callers gain `~stayer`; waterbomb unit
  tests pass an explicit sector)

**Interfaces:**
- Produces:
  ```ocaml
  type stayer =
    | Arc of Geom.point * Geom.point  (* far tips of the two leading rays;
                                         stayer region = the <π CCW arc *)
    | Faces of int list               (* pre-collapse face indices that stay *)
  val collapse     : Fold_state.t -> elem list -> over:(int*int) list
                     -> stayer:stayer -> (Fold_state.t, string) result
  val collapse_all : Fold_state.t -> elem list -> over:(int*int) list
                     -> stayer:stayer -> (Fold_state.t list, string) result
  val e_stayer_collinear : string   (* "collinear leading creases don't pick a stayer; add (staying <flap>)" *)
  val e_stayer_dead      : string   (* "no realization keeps the staying flap still" *)
  ```
- Consumes: nothing new. Task 3 calls `collapse_all ~stayer`.

- [ ] **Step 1: Write the failing unit test — stayer picks the world**

In `tests/test_collapse.ml`, add a test on the existing rabbit-ear fixture
geometry (reuse the helpers the `normalization` tests use): same elems, two
opposite `Arc` stayers must both solve, and their realizations must be
mirror stacks of each other (compare `Fold_state.rank` of a shared face pair
flipping). Sketch:

```ocaml
let test_stayer_picks_world () =
  let g, elems = rabbit_ear_fixture () in
  let arc_a = Collapse.Arc (far1, far2)      (* strip side *)
  and arc_b = Collapse.Arc (far2, far1) in   (* complement — expect reject or mirror *)
  match Collapse.collapse_all g elems ~over:[] ~stayer:arc_a,
        Collapse.collapse_all g elems ~over:[] ~stayer:arc_b with
  | Ok sts_a, _ -> Alcotest.(check bool) "arc_a solves" true (sts_a <> [])
  | Error e, _ -> Alcotest.fail e
```

(Exact fixture names from the file; `arc_b`'s expectation: the >π arc is a
caller error — see Step 3 — so pass the two rays that bound the complement
instead. The load-bearing assertion: both worlds are reachable and differ.)

- [ ] **Step 2: Run it to confirm it fails to compile**

Run: `dune build @all 2>&1 | head` — expect: `Unbound constructor
Collapse.Arc` / label errors. That's the red.

- [ ] **Step 3: Implement the stayer plumbing in `collapse.ml`**

1. Add the `stayer` type and the two error strings (top of file, with the
   other `e_*`).
2. After `rays` is built and validated (post-`closure_ok`/Maekawa, where
   `tsec`/`sec` are computed today), compute admissible stayer sectors:

```ocaml
(* q strictly inside the CCW arc from a to b around o; the caller guarantees
   the a→b CCW arc is the <π one (cross(a,b) > 0). *)
let in_ccw_arc o a b q =
  let oc = (o.Geom.x, o.Geom.y) in
  Num.sign (cross oc (a.Geom.x, a.Geom.y) (q.Geom.x, q.Geom.y)) > 0
  && Num.sign (cross oc (q.Geom.x, q.Geom.y) (b.Geom.x, b.Geom.y)) > 0
```

```ocaml
let admissible_sectors ~stayer o rays sec nf =
  match stayer with
  | Faces fs -> List.sort_uniq compare (List.map (fun i -> sec.(i)) fs)
  | Arc (pa, pb) ->
      let oc = (o.Geom.x, o.Geom.y) in
      let c = cross oc (pa.Geom.x, pa.Geom.y) (pb.Geom.x, pb.Geom.y) in
      if Num.sign c = 0 then raise (Stayer_collinear)   (* → Error e_stayer_collinear *)
      else
        let a, b = if Num.sign c > 0 then (pa, pb) else (pb, pa) in
        (* sector k admissible iff an interior direction of it is in the arc;
           k's interior representative: any face's rep in that sector — reuse
           sector_of_poly's rep machinery, or test both bounding rays with
           closed-arc membership (endpoints a,b are themselves fan rays). *)
        List.filter
          (fun k ->
            let rk, _ = rays.(k) and rk1, _ = rays.((k + 1) mod n) in
            let inc p = Geom.point_equal p a || Geom.point_equal p b
                        || in_ccw_arc o a b p in
            inc rk && inc rk1
            && not (Geom.point_equal rk b) && not (Geom.point_equal rk1 a))
          (List.init n Fun.id)
```

   (The last two conjuncts stop the degenerate zero-width “sector” readings at
   the arc's endpoints; adjust against the fixture until the rabbit-ear arc
   yields exactly the strip sector(s) — 1 without an emergent inside, 2 with.)
3. Extract the pipeline body (from `let tsec = sector_isometries o rays` down
   to the `distinct` construction) into `pipeline_at ~(rays : _ array)` so it
   can run on a rotated ray array:

```ocaml
let rotate_rays rays s0 =
  let n = Array.length rays in
  Array.init n (fun k -> rays.((k + s0) mod n))
```

   For each admissible sector `s0`: run the existing body verbatim on
   `rotate_rays rays s0`. In the rotated frame the stayer is sector 0, so
   `tsec.(0) = identity` sits on the stayer by construction and
   `effective_valley`/`intra`/`ray_assign`/`over` are consistent
   automatically. The `rep` for `valid_srank` is any face with rotated
   `sec.(i) = 0`.
4. **Anchoring**: replace `anchor_realization`'s proper/improper walk with:
   root = first face in rotated sector 0, base = `Fold_state.face_iso g root`,
   one `candidate_at`, `in_bounds` check; on failure that realization is
   dropped with `e_out_of_paper` recorded. Delete: the `improper` list, the
   `fr_rev` reversal, the descending-srank sort, and the whole fallback
   comment block from `1a4f6d9`.
5. `collapse_all ~stayer`: pool realizations over all admissible `s0` (no
   cross-run dedup — different stayers are different folds; keep the
   per-run signature dedup). Empty admissible list (Faces off-fan) or all
   runs dead → `Error e_stayer_dead` unless a run recorded
   `e_out_of_paper`/`e_contra` (keep today's error-priority behavior).
6. `collapse ~stayer`: unchanged contract on top of the pooled list
   (1 → fold, ≥2 → `e_ambig k`, 0 → as `collapse_all`).

- [ ] **Step 4: Update `tests/test_collapse.ml` callers**

Every `Collapse.collapse`/`collapse_all` call gains `~stayer`. Waterbomb-
geometry unit tests (`test_waterbomb_assignment`, `test_over_resolves_ambiguity`,
`test_collapse_all_*`, …) pass an explicit `Faces [f]` for the sector the old
sort-ccw labeling anchored (pick the face index that keeps the existing
expected stack; adjust expectations where the old arbitrary anchor differed
from a stated one — expectation changes here are findings, note them in the
commit message). The waterbomb *language* cases are already gone (Task 4
deletes the rest).

- [ ] **Step 5: Run tests**

Run: `dune test 2>&1 | tail -30`
Expected: test_collapse green (incl. the new stayer test); `.bel` cases still
red where they were (eval not wired yet).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(collapse): stayer-anchored pipeline, drop improper-anchor fallback"
```

---

### Task 3: eval — leading-element convention, segment candidates, staying

**Files:**
- Modify: `lib/eval.ml:1719-1938` (resolution + `try_patterns` call sites)

**Interfaces:**
- Consumes: `Collapse.collapse_all ~stayer`, `Collapse.Arc/Faces`,
  `resolve_flap_cluster` (eval.ml:598) for the staying flap.
- Produces: the language behavior the spec defines. New error texts:
  - `` collinear leading creases don't pick a stayer; add (staying <flap>) ``
    (map `e_stayer_collinear` through)
  - `` no realization keeps the staying flap still `` (`e_stayer_dead`)
  - `` the staying flap does not touch the vertex ``
  - `` --<name> is ambiguous at the vertex; select a segment with `&` ``

- [ ] **Step 1: Write failing case files**

`tests/cases/collapse/flatten-staying-override.bel` — the single rabbit ear
from `flatten-rabbit-ear-toward-*.bel` geometry, leading elements ordered so
the convention picks the strip, then the same fold with `(staying <point in
the strip>)` and the leading elements SWAPPED — assert both produce the same
`faces =` count and identical assertions (staying overrides order).

`tests/cases/collapse/flatten-order-load-bearing.bel` — same geometry, leading
pair chosen so the conventional arc holds another element's ray on every
resolution → expect error (use the error the solver actually reports; the
point is that reordering the same items changes the outcome).

`tests/cases/collapse/flatten-staying-collinear.bel` — two collinear leading
creases (waterbomb diagonals reduced to a legal 4-ray vertex), no staying:
`; expect error "collinear leading creases"`.

Also in `flatten-two-ears-sequential.bel`: rewrite both statements to the
bare convention form (this is the acceptance case):

```
flatten (--l1) (--l2) (--ray) {toward .d}
...
flatten (--l3) (--l4) (--ray) {toward .d}
```

- [ ] **Step 2: Run to confirm red**

Run: `dune test 2>&1 | tail -30` — the new cases fail (multi-segment `&`
errors / wrong results), two-ears fails. Red confirmed.

- [ ] **Step 3: Segment candidates instead of hard `&` errors**

Replace `resolve_elem`'s multi-segment failures with candidate lists:

```ocaml
(* each element resolves to 1..k material segments; the stayer filter and
   the vertex check prune combinations. resolve_elem_candidates NEVER errors
   on multiplicity — only on "not material at all". *)
let resolve_elem_candidates (el : Ast.collapse_elem) :
    (int * Geom.point * Geom.point * Ast.mv_constraint) list = ...
```

(keep the existing zero-segment errors verbatim). Then:

1. Vertex: O = the point shared by ≥1 candidate segment of EVERY element
   (generalize the current `common_vertex` use; if none → `e_no_vertex`).
2. Per element, keep candidates ending at O.
3. Enumerate combinations (product; in practice ≤2 per element). Per
   combination: leading pair arc via `cross` sign; drop the combination if
   any OTHER element's ray falls strictly inside the arc (`in_ccw_arc`),
   or if Kawasaki-level checks reject it downstream anyway (let the kernel
   do that — don't duplicate).
4. If >1 combination survives resolution AND their realization pools are
   both non-empty after the solver runs, fail with the `&`-suggestion error
   naming the multi-segment element. Tag realizations with a combination id
   to detect this after pooling, before the three-stage selection.

- [ ] **Step 4: Build the stayer and wire `try_patterns`**

```ocaml
let stayer : Collapse.stayer =
  match staying_opt with
  | Some fa ->
      let faces = resolve_flap_cluster fa span in
      if faces = [] then Error.fail span "the staying flap does not touch the vertex"
      else Collapse.Faces faces
  | None ->
      let (_, a1, b1, _), (_, a2, b2, _) = leading_pair combo in
      Collapse.Arc (far_of_seg_at o (a1, b1), far_of_seg_at o (a2, b2))
```

- `Faces` validity (off-fan flap) surfaces from the kernel as
  `e_stayer_dead`; map the collinear exception to its error text at this
  call site with the statement span.
- Thread `~stayer` into both `Collapse.collapse_all` call sites inside
  `try_patterns` (line 1875) — the stayer is per-combination, so
  `try_patterns` takes it as an argument.
- The all-layers guard (1792) and everything after pooling (tiers, selection,
  binding) stay untouched.
- A `staying` that names exactly the conventional arc's material: no check,
  no error (lint is out of scope — #64 territory).

- [ ] **Step 5: Run the full suite**

Run: `dune test 2>&1 | tail -40`
Expected green: two-ears (the true chain enumerates and survives the taco
checks), derive-13, the three new cases, all `flatten-rabbit-ear-*` /
`collapse-*` survivors. Expected red: exactly the #51 trio. Anything else
red: investigate before proceeding — likely a case whose leading order now
picks a different stayer than the old arbitrary anchor did; fix the CASE
(order/`&`/staying), not the solver, unless the solver contradicts the spec.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(flatten): leading-element stayer convention + (staying) wiring"
```

---

### Task 4: Case sweep and fish base

**Files:**
- Delete: `tests/cases/collapse/collapse-all-valley.bel`,
  `collapse-ambiguous.bel`, `collapse-ambiguous-over.bel`
- Modify: every remaining `tests/cases/collapse/flatten-*.bel`,
  `examples/bases/fish-base.bel`, `examples/bases/swivel-rabbit.bel`

**Interfaces:** none — pure case migration on the Task-3 behavior.

- [ ] **Step 1: Delete the waterbomb-geometry cases**

```bash
git rm tests/cases/collapse/collapse-all-valley.bel \
       tests/cases/collapse/collapse-ambiguous.bel \
       tests/cases/collapse/collapse-ambiguous-over.bel
```

(Wrong per Toph, 2026-07-17; unit-level Maekawa/over coverage lives in
`test_collapse.ml` since Task 2.)

- [ ] **Step 2: Migrate the survivors to convention order**

For each `flatten-*.bel` and both examples: leading elements = the two
creases bounding the physical stayer, redundant `&` dropped (Example
Discipline — implied clauses go). The rabbit-ear family follows the fish
pattern (bisectors first). Verify each by running the suite, not by eye.

`examples/bases/fish-base.bel`: uncomment the second flatten, both statements
in bare convention form; final `; assert steps = 4` / `; assert faces = 12`
as in `flatten-two-ears-sequential.bel`.

- [ ] **Step 3: Run and commit**

Run: `dune test 2>&1 | tail -30` — green except #51 trio.

```bash
git add -A && git commit -m "test(flatten): migrate cases to stayer convention, complete fish base"
```

---

### Task 5: Spec §4.9 rewrite

**Files:**
- Modify: `spec/SPECIFICATION.md` §4.9 (lines ~800-1010) + version banner

**Interfaces:** none — prose contract.

- [ ] **Step 1: Rewrite §4.9 per the design doc**

- Grammar block: `staying` item, element order semantic, "items in any order"
  scoped to non-element items only.
- Replace the "State construction" stayer paragraph: stayer = does-not-move
  (identity, face-up), stated by convention (leading-element <180° arc) or
  `(staying <flap>)`; stack position is a consequence, not the definition.
  Delete "lowest face-up of the solved stack" and the `standing` clause
  paragraph + its check row; add the new error rows (spec Errors table).
- Pipeline section: admissible stayer sectors anchor the enumeration; the
  emergent may split the conventional arc → ≤2 realizisation worlds,
  `{toward}` selects. Bracket ontology sentence: `()` filters (incl.
  staying), `{}` selects.
- Bump `v0.23-dev` banner line to mention the stayer model.

- [ ] **Step 2: Consistency pass and commit**

`rg -n "standing" spec/ lib/ tests/` → only historical mentions in
ADRs/notes/design docs remain. Run `dune test` once more (unchanged).

```bash
git add -A && git commit -m "docs(spec): §4.9 stayer convention + staying clause"
```

---

### Task 6: Wrap-up

- [ ] **Step 1: Full verification**

`dune build && dune test 2>&1 | tail -40` — red = #51 trio only. Render the
fish base (`tools/fold2svg.mjs`) and eyeball the second ear: wings above the
stationary strip, ear on top (the ghost had them under).

- [ ] **Step 2: Update the parity note + issue**

Append a short "resolved by" section to
`notes/2026-07-17-flatten-parity-origin.md` pointing at the spec/plan and the
commits. Comment on #52: implemented, what changed, session link per repo
convention.

- [ ] **Step 3: Final commit / hand back for PR decision**

Commit remaining bits; report status (branch commits, test summary, fish
render) back to Toph — PR vs. more slices is his call (#51 next).
