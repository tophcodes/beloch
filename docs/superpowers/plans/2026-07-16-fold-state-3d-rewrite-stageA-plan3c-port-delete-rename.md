# Fold-state 3D rewrite — Stage A / Plan 3c: port consumers, delete old, rename

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every consumer (`eval.ml`, `fold_emit.ml`, tests) onto `Fold_graph`, update the goldens for the adjudicated collapse-letter fix, correct spec §4.6's collapse application + stale example comments, delete the old `Fold_state`/`Layer_order`/collapse kernel, and rename `Fold_graph` → `Fold_state`. End state: ADR-0015's 3D-native core is THE fold state; illegal states unrepresentable end to end.

**Architecture:** This is a PORT plan, not a design plan: the source files themselves are the complete specification, and the normative substitution dictionary below (identical to Plan 3b's, plus consumer-specific rows) defines every rewrite. Tasks are bounded by build/test gates, not by code listings. The build is RED during Tasks 2–4 (accepted in the design spec); the new suites (72 fold_graph + 4 collapse_graph tests) are the confidence anchor.

**Tech Stack:** OCaml, dune, alcotest; `lib/eval.ml`, `lib/fold_emit.ml`, `lib/beloch.ml`, `tests/*`, `spec/SPECIFICATION.md`, `tests/golden/`.

## Global Constraints

- Worktree `/home/toph/Projects/beloch-rewrite`, branch `feat/fold-state-invariants` (based on current origin/main e28aaaa — verified, no rebase needed). `git branch --show-current` before every commit.
- Build/test: `direnv exec /home/toph/Projects/beloch-rewrite dune build` / `… dune test`; suites: `tests/test_fold_graph.exe` (72), `tests/test_collapse_graph.exe` (4) must stay green THROUGH every task (they define the core's behaviour).
- **Adjudicated (Toph, 2026-07-16): derived `mv` is authoritative for folded-frame `edges_assignment`; collapse-crease golden letters CHANGE; spec §4.6 is corrected, not emulated.** CP-frame letters (`intent`/old `eintent`) are unchanged everywhere.
- The two "pre-existing" golden failures (rabbit-ear/swivel-rabbit "syntax error") must be EXPLAINED in Task 5 before any golden is regenerated — never regenerate a golden you cannot explain.
- No behaviour changes beyond the two sanctioned divergences (collapse letters; D8 both-sides/unfold semantics) — if a ported consumer produces any OTHER output diff, STOP and report.
- No floats. Old modules stay compilable until their deletion task. Conventional commits.

## Substitution dictionary (normative; supersets Plan 3b's)

| Old | New |
|---|---|
| `Fold_state.t` (consumer state type) | `Fold_graph.t` |
| `st.Fold_state.faces.(i).Fold_state.paper` | `(Fold_graph.faces st).(i)` (bind the copy once per scope) |
| `st.Fold_state.faces.(i).Fold_state.iso` | `Fold_graph.face_iso2 st i` |
| `st.Fold_state.edges` iteration | `Fold_graph.hinges st` (+ `hinge_segment`/`hinge_table_segment` by index) |
| `e.Fold_state.ea/.eb` | `Fold_graph.hinge_segment st i` |
| `e.Fold_state.left/.right` | `h.Fold_graph.fa/.fb` |
| `e.Fold_state.eassign` (letter read) | `Fold_graph.mv st i` |
| `e.Fold_state.eassign = F` (flatness test) | `Num.sign h.Fold_graph.angle = 0` |
| `e.Fold_state.eintent` | `h.Fold_graph.intent` |
| `e.Fold_state.crease_id` / `.eprov` | `h.Fold_graph.crease_id` / `.prov` |
| `Fold_state.edge_between st i pa pb` (record) | `Fold_graph.hinge_between st i pa pb` (index; metadata via the index) |
| `Fold_state.axis_segment_in_face st.faces.(i) axis` | `Fold_graph.axis_chord_in_face st i axis` |
| `Layer_order.get st.Fold_state.order i j` | `Fold_graph.rel st i j` (constructors `Above/Below/Apart` from `Fold_graph.rel` type) |
| `Layer_order.negate` | pattern-match locally (only if still needed; check each site) |
| `Isometry.det_sign f.iso < 0` (parity read) | `not (Fold_graph.face_up st i)` |
| `f.iso` matrix fields (`m00…ty`) | `Fold_graph.face_iso2 st i` fields (same names) |
| `Fold_state.fold_with_records` | `Fold_graph.fold` (same labels; `?moving_parents` kept) |
| `Fold_state.subdivide/subdivide_paper/flip/add_mark/init_square/table_position/table_polygon(_ccw)/on_paper/paper_preimages/fresh_crease_id/reset_ids/simple_fold` | same names on `Fold_graph` |
| `Fold_state.crease_segments/all_crease_ids/crease_axis/crease_paper_axis/edge_boundary_segments/neighbors/coplanar_clusters/flap_of_points/cluster_of_points/line_material_segments/line_cuts_paper/select_scope/scope_target/TargetFace/TargetHinged/scoped_fold_hinge_closed/mark_*/classify_mark_extent/mark_class/CSubdivide/CRecord/CCrossesFold/point_on_polygon_boundary/mark type/mark_geom/MSeg/MPoint/assign/M/V/F` | same names on `Fold_graph` |
| `Fold_state.crease_segment` record + fields | `Fold_graph.crease_segment` (identical fields) |
| `Collapse.collapse` | `Collapse.collapse_graph` |
| `Fold_state.validity_error` (tests) | delete the assertion or replace with `Fold_graph.make`-mediated construction (case by case; the constructor IS the validity check now) |
| `Fold_state.build_order` (tests) | construct via `Fold_graph.make … ()` |
| `Fold_state.next_id` (test_e2e direct ref) | `Fold_graph.fresh_crease_id`/`reset_ids` (no raw counter access — rewrite the site) |

Signature reshapes to expect (only two): `axis_chord_in_face` takes a face INDEX; `hinge_between` returns an INDEX option.

---

### Task 1: TargetHinged parity test (final-review mandate — BEFORE the eval port)

**Files:** `tests/test_fold_graph.ml`

- [ ] **Step 1:** Add `test_select_scope_target_hinged_parity`: build the 3-layer pleat state from `test_select_scope_parity` in BOTH models (same op sequence, both id counters reset). Determine the book-fold crease's cid (it is the first fold's cid — 0 after reset in both models). Call both models' `select_scope` with `target:(TargetHinged pred)` where each model's `pred` uses its OWN state: old `pred g = Fold_state.crease_segments st cid |> List.exists (fun s -> fst s.Fold_state.faces = g || snd s.Fold_state.faces = g)`; new likewise via `Fold_graph.crease_segments`. Anchor = each model's own top face (reuse the existing per-model top-finding from `test_select_scope_parity`). Assert both return `Ok` with EQUAL bool arrays (or equal error strings). Choose axis/move_side so the hinged target is genuinely reachable (axis x=3/8, move_side −1, valley true — same as the TargetFace test; if select returns an error in BOTH models with the same string, that is also a valid parity outcome but then adjust the axis until you get an `Ok` case — the point is to exercise the frontier BFS, so an `Ok` case is REQUIRED; report what you chose).
- [ ] **Step 2:** Suite green (73). Commit: `test(foldgraph): TargetHinged select_scope parity`.

### Task 2: port eval.ml

**Files:** `lib/eval.ml`, `lib/beloch.ml` (re-export sanity only if needed)

- [ ] **Step 1:** Apply the dictionary to every `Fold_state.`/`Layer_order.`/`Collapse.collapse` site in `lib/eval.ml` (~140 sites; the state lives in the eval context record — change its type to `Fold_graph.t`). `Collapse.elem` construction stays (shared type). Keep all error messages byte-identical. The two reshapes: `axis_segment_in_face` sites (eval.ml ~1294/1370/1383) take the face index they already have; `edge_between` read-sites (~735) use the returned index for metadata.
- [ ] **Step 2:** Gate: `direnv exec … dune build` compiles `lib/` cleanly (tests may be red). `test_fold_graph` + `test_collapse_graph` still green.
- [ ] **Step 3:** Commit: `refactor(eval): port evaluator onto Fold_graph`.

### Task 3: port fold_emit.ml

**Files:** `lib/fold_emit.ml`

- [ ] **Step 1:** Apply the dictionary. Specifics: `cp_display` → `Fold_graph.marks`/`subdivide_paper`/`point_on_polygon_boundary` over bare polygons; folded-frame letter = `Fold_graph.mv` (string via existing match, F→"F"); CP-frame letter = `h.intent`; provenance = `h.prov`; vertex table-keying via `face_iso2`-applied points; `faceOrders` from `Fold_graph.rel` with sign from `Fold_graph.face_up st gi` (old: `det_sign iso > 0` ⟺ `face_up`); `beloch:faces_matrix` from `face_iso2` fields; `init_square`/`table_position` from `Fold_graph`. `edge_between`→`hinge_between` index lookups.
- [ ] **Step 2:** Gate: full `dune build` clean (lib + bin). Core suites green.
- [ ] **Step 3:** Commit: `refactor(emit): serialize FOLD from Fold_graph — derived letters in folded frames`.

### Task 4: port the test suite

**Files:** `tests/test_eval.ml`, `tests/test_collapse.ml`, `tests/test_e2e.ml`, `tests/test_bel_assert.ml`, `tests/test_flatten.ml`; DELETE `tests/test_fold_state.ml` (+ its dune stanza)

- [ ] **Step 1:** `test_fold_state.ml` is superseded by the `test_fold_graph` suite — delete it and its stanza. For the rest: apply the dictionary. Sites that constructed old records directly (`test_eval` field pokes, `test_collapse` fixtures, `test_e2e` `next_id`) are rewritten against the new API (constructor-only; `make`-built fixtures where a raw state was assembled). `test_collapse.ml` drives `Collapse.collapse_graph`; its per-test EXPECTED letters on collapse results change per the adjudication — expected `eassign` letters become the DERIVED letters (= raw declared letters on those fixtures; the old parity-adjusted expectations are exactly the bug). Every other expectation stays byte-identical; any other diff → STOP.
- [ ] **Step 2:** Gate: `dune test` green EXCEPT `test_golden` (Task 5's business) — including test_eval's error-string assertions (they must pass unmodified; they pin the ported error paths).
- [ ] **Step 3:** Commit: `test: port suites onto Fold_graph; collapse letter expectations follow derived mv`.

### Task 5: goldens + spec §4.6 + example comments

**Files:** `tests/golden/**`, `spec/SPECIFICATION.md`, `examples/bases/rabbit-ear.bel`, `examples/bases/waterbomb.bel` (comment blocks only)

- [ ] **Step 1 (explain first):** Diagnose the two pre-existing golden failures (rabbit-ear/swivel-rabbit "syntax error") — they predate this branch's work (stash-verified in Plan 2b) and are NOT ours; identify the actual cause (likely the checked-in goldens/examples expect syntax from a branch newer than the base, or a test-runner path issue). Write the finding into the ledger. If they are trivially fixable in-branch, fix; if they belong to main, document and leave.
- [ ] **Step 2:** Regenerate goldens; diff EVERY changed file. The ONLY acceptable diffs: folded-frame `edges_assignment`/`edges_foldAngle` letters (and any letter-derived field) on collapse-produced creases. Sweep for the D8 both-sides shape (scoped fold with a both-sides-moving on-axis crease) in all goldens/examples — expected: none exist; if one does, STOP and report. Commit goldens separately with a before/after letter table per file in the body, referencing the Task-3b-5 adjudication: `test(golden): collapse folded-frame letters follow derived mv`.
- [ ] **Step 3:** Spec §4.6 (`spec/SPECIFICATION.md:647` area): the rule "valley XOR (the cutting face is back-up), fixed when the fold runs" is CORRECT for simple folds (pre-fold parity — proven equivalent to derived mv by the 3a parity suite). Add the collapse clarification: for multi-crease moves the folded-form letter is the derived global-frame M/V of the folded state [hullzakharevich2023 §2.1]; the old implementation's per-ray parity adjustment (fan-index term) was a bug, fixed in this rewrite. Correct the stale rationalizing comment blocks in `rabbit-ear.bel`/`waterbomb.bel` (they explain the OLD wrong letters as spec behaviour). Commit: `docs(spec): §4.6 — collapse letters are the derived folded-state M/V`.

### Task 6: delete old, guard, rename

**Files:** DELETE `lib/fold_state.ml`, `lib/layer_order.ml`; `lib/collapse.ml` (old kernel out), `lib/beloch.ml`, `tests/test_fold_graph.ml`, `tests/test_collapse_graph.ml`; RENAME `lib/fold_graph.ml(i)` → `lib/fold_state.ml(i)`

- [ ] **Step 1 (delete):** Remove `fold_state.ml`, `layer_order.ml`, their `beloch.ml` re-exports; in `collapse.ml` remove the old `collapse` kernel + `sector_of` + anything only it used (shared helpers stay); rename `collapse_graph` → `collapse`. In the two core test files, remove the old-model halves: parity harnesses become direct assertions against the CURRENT values they were proven equal to (mechanical: inline the old model's outputs as literals where a test still needs an expectation, or drop the comparison where the new-side assertion already exists — the divergence-pin test `test_old_eassign_divergence` loses its old-side half; keep the new-side assertions (mv == raw declared) and rewrite its comment to cite the ledger/commit instead of live old code). Battery `replay` drops the old-model track. Add the one-line `invalid_arg` guard for `rep`/`first_face_in_sector` in collapse (carried minor). Gate: full `dune test` green (including goldens as left by Task 5). Commit: `refactor!: delete legacy Fold_state/Layer_order — hinge graph is the fold state`.
- [ ] **Step 2 (rename, PURE):** `git mv lib/fold_graph.ml lib/fold_state.ml` (+ .mli), global identifier rename `Fold_graph` → `Fold_state` (sed over lib/ bin/ tests/; beloch.ml re-export becomes `module Fold_state = Fold_state`), rename `tests/test_fold_graph.ml` → `tests/test_fold_state.ml` and `test_collapse_graph.ml` → `test_collapse.ml`?? NO — `tests/test_collapse.ml` already exists (ported, Task 4); merge instead: fold `test_collapse_graph.ml`'s cases into `tests/test_collapse.ml` and delete the extra file + stanza (do this in Step 1 where the old halves are removed, so Step 2 stays a pure rename). No logic changes in Step 2 — the diff must be mv + mechanical identifier substitution only. Gate: full `dune test` green. Commit: `refactor: rename Fold_graph → Fold_state — the rewrite is the fold state`.
- [ ] **Step 3:** One prov-carrying spot check (final-review rec): a `.bel` evaluation whose FOLD output contains a `beloch:edges` provenance entry — assert axiom/sources/span fields non-null for a folded crease (add to test_e2e if not already covered by an existing assertion; if covered, point at it in the ledger instead of adding). Ledger: `Plan 3c: COMPLETE — Stage A delivered; illegal folded states unrepresentable end to end.`

### Task 7: final whole-plan review

- [ ] Dispatch the final code reviewer (most capable model) over the whole 3c range; fix Criticals/Importants; ledger the outcome.
