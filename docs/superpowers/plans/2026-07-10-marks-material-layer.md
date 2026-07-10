# Marks as a Material Non-Subdividing Layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mark`ed lines material (`*`-meetable) and locatable-interior-point sources, without ever subdividing the working fold arrangement; graduate full mark chords to `F` creases at emit only.

**Architecture:** Marks stay in `Fold_state.marks` and never enter `st.edges`, so every fold-time algorithm is untouched (Approach B). A new `crease_val` constructor `Mark(cid, line)` lets `*` read chords from the mark layer. Fold-time dispatch stops subdividing for full marks — everything records. FOLD emit gains one isolated step: a planar overlay of `real_edges ∪ mark_segments` in global paper space that splits at crossings and classifies each mark sub-segment (both endpoints material → standard `F`; any dangling endpoint → `beloch:marks`).

**Tech Stack:** OCaml (dune), Menhir parser, exact rational/real-algebraic kernel (`Num`), `Geom` primitives, FOLD JSON emit, `tools/fold2svg.mjs` renderer.

Design spec: `docs/superpowers/specs/2026-07-10-marks-material-layer-design.md`.

## Global Constraints

- **Exact arithmetic only.** All incidence/coincidence tests use `Num`/`Geom` exact predicates (`Geom.point_equal`, `Geom.side_of_line = 0`, `Geom.on_segment`). No floats, no tolerance. (`decisions/0008`, `decisions/0010`.)
- **Paper space is global.** `face.paper` polygons and mark `mgeom` share one global paper coordinate frame; the table position is `Isometry.apply_point face.iso`. All overlay geometry is done in paper space.
- **Never conflate language vs evaluator.** This changes the reference evaluator only. (`[[beloch-language-vs-implementation]]`.)
- **Branch:** `slice/marks-material-layer` off `main`. `git branch --show-current` before every commit (shared checkout, `[[beloch-shared-checkout-branch-check]]`).
- **Build/test:** `dune build 2>&1` and `dune test 2>&1` (or `dune exec test/…`); goldens live under `tests/`.

---

## Phase 1 — Fold-time: marks material & non-subdividing

At the end of Phase 1: `mark` never subdivides `st.edges`; `--ac * --bd` locates `.ctr` with the sheet still 1 face; `fold` on a mark makes a real crease. Emit is temporarily unchanged (all marks, including full chords, still serialize into `beloch:marks`; full chords do NOT yet appear as `F` — that is Phase 2). This is a coherent, testable intermediate.

### Task 1: `Mark` crease_val constructor + resolution wiring

**Files:**
- Modify: `lib/eval.ml` — `crease_val` type (~line 22-30), `materialize_crease` (~line 199), `paper_line_of_crease` (~line 217-250).
- Test: `tests/test_eval.ml`.

**Interfaces:**
- Produces: `crease_val` gains `Mark of int * Geom.line` (mark_id = the mark's `mcrease_id`; line = its paper-space motion line). `materialize_crease` on a `Mark` returns the line. `paper_line_of_crease` on a `Mark` returns `(line, Some chords)` where `chords` are the paper endpoints of every `MSeg` in `Fold_state.marks` whose `mcrease_id` equals the mark id.
- Consumes: `Fold_state.marks : mark array`, `mark.mcrease_id`, `mark.mgeom`.

- [ ] **Step 1: Add a helper on Fold_state to fetch a mark's chords by id.**

In `lib/fold_state.ml`, after `add_mark` (~line 592):

```ocaml
(* Paper-space chords (segment endpoints) of every MSeg mark carrying
   [cid]. Point marks (MPoint) contribute no chord. Used by the meet
   operator to test that a marked line physically reaches a crossing. *)
let mark_chords (st : t) (cid : int) : (Geom.point * Geom.point) list =
  Array.to_list st.marks
  |> List.filter_map (fun m ->
         if m.mcrease_id = cid then
           match m.mgeom with MSeg (a, b) -> Some (a, b) | MPoint _ -> None
         else None)
```

- [ ] **Step 2: Add the `Mark` constructor to `crease_val`.**

In `lib/eval.ml`, the `crease_val` variant (~line 22):

```ocaml
  | Material of int * Geom.line
  | Mark of int * Geom.line
  | Frozen of Geom.line
```

- [ ] **Step 3: Run the build to see the non-exhaustive-match errors.**

Run: `dune build 2>&1 | head -40`
Expected: FAIL — several `match cv with` and `match lookup_crease …` sites now warn/err non-exhaustive (`materialize_crease`, `paper_line_of_crease`, `promote`, any `Material _ | Bundle _ …` arms). This lists exactly the sites to update.

- [ ] **Step 4: Handle `Mark` in `materialize_crease`.**

Find the `materialize_crease` match on `cv` (~line 199, the `Frozen l -> l` arm). Add:

```ocaml
    | Mark (_cid, line) -> line
```

- [ ] **Step 5: Handle `Mark` in `paper_line_of_crease`.**

In `paper_line_of_crease` (~line 217), add an arm mirroring the `Material` branch but sourcing chords from the mark layer:

```ocaml
    | Mark (cid, line) -> (line, Some (Fold_state.mark_chords !(ctx.state) cid))
```

- [ ] **Step 6: Handle `Mark` in every remaining non-exhaustive site.**

For each site the build flagged (e.g. the `promote` guard's `Material _ | Bundle _ | Edge _ -> ()` at ~line 1313, and any bundle/coerce match), add `Mark _` to whichever arm matches its `Material` sibling's behaviour. A `Mark` is a materialized construction line, so wherever `Material _` is a no-op or "already material", `Mark _` joins it.

- [ ] **Step 7: Build clean.**

Run: `dune build 2>&1`
Expected: no errors, no non-exhaustive warnings.

- [ ] **Step 8: Commit.**

```bash
git branch --show-current   # must print slice/marks-material-layer
git add lib/eval.ml lib/fold_state.ml
git commit -m "feat(eval): Mark crease_val backed by the mark layer"
```

### Task 2: Marks stop subdividing — dispatch always records

**Files:**
- Modify: `lib/eval.ml` — the `Ast.Mark` handler `dispatch_partial` + the `` `Full `` / `` `Existing `` branches (~line 1240-1325).
- Modify: `lib/eval.ml` — `resolve_mark_extent` `` `Full `` case (~line 1166) to yield the full chord geometry.
- Test: `tests/test_eval.ml`.

**Interfaces:**
- Consumes: `Fold_state.add_mark`, `Fold_state.MSeg`, the `Mark` constructor from Task 1.
- Produces: after any `mark` statement the sheet's `st.edges`/`st.faces` are unchanged (no subdivision); the name binds to `Mark(cid, line)`; a full mark records an `MSeg` chord spanning the flap.

- [ ] **Step 1: Write the failing test — a full mark does not subdivide.**

In `tests/test_eval.ml`, add:

```ocaml
let () =
  let st = eval_source {|
paper square
mark --ac = through .a .c
|} in
  (* one flat face, four boundary edges — the diagonal must NOT split it *)
  Alcotest.(check int) "faces after full mark" 1 (Array.length st.Fold_state.faces);
  Alcotest.(check int) "marks after full mark" 1 (Array.length st.Fold_state.marks)
```

(Use whatever the file's existing `eval_source`/state-access helper is; match the surrounding test style. If the file exposes the final `Fold_state.t` differently, adapt the accessor.)

- [ ] **Step 2: Run it — expect failure (currently 4 faces).**

Run: `dune test 2>&1 | grep -A3 "full mark"`
Expected: FAIL — `faces after full mark` gets 4 (current subdivide behaviour), not 1.

- [ ] **Step 3: Make `resolve_mark_extent`'s `Full` yield the chord.**

The `Full` case (~line 1166) currently returns the bare `` `Full ``. Change it to compute the paper-space chord by clipping `table_axis` to the paper and return it like a segment. Replace:

```ocaml
    | Ast.Full -> `Full
```

with:

```ocaml
    | Ast.Full ->
        (* the full chord: the mark's line clipped to the flat sheet. Reuse the
           per-face axis clip and take the extreme endpoints across the carrying
           faces (unfolded sheet = one face → corner-to-corner). *)
        let st = !(ctx.state) in
        let pts =
          Array.to_list st.Fold_state.faces
          |> List.filter_map (fun (f : Fold_state.face) ->
                 Fold_state.axis_segment_in_face f table_axis)
          |> List.concat_map (fun (p, q) -> [ p; q ])
        in
        (match Geom.extreme_pair pts with
        | Some (a, b) ->
            `Partial (Fold_state.MSeg (a, b), a, Geom.line_through a b)
        | None -> Error.fail span "the mark's line does not cross the paper")
```

- [ ] **Step 4: Add `Geom.extreme_pair` (the two farthest-apart collinear points).**

In `lib/geom.ml`, add:

```ocaml
(* From a list of collinear points, the two that are farthest apart (the
   segment's extreme endpoints). None if fewer than two distinct points. *)
let extreme_pair (pts : point list) : (point * point) option =
  match pts with
  | [] | [ _ ] -> None
  | p0 :: _ ->
      let d2 a b =
        let dx = Num.sub a.x b.x and dy = Num.sub a.y b.y in
        Num.add (Num.mul dx dx) (Num.mul dy dy)
      in
      let best = ref None in
      List.iter
        (fun a ->
          List.iter
            (fun b ->
              let d = d2 a b in
              match !best with
              | Some (_, _, bd) when Num.compare d bd <= 0 -> ()
              | _ -> best := Some (a, b, d))
            pts)
        pts;
      (match !best with Some (a, b, _) -> Some (a, b) | None -> None)
      |> fun r -> ignore p0; r
```

(If a farthest-pair or collinear-extent helper already exists in `Geom`, use it instead and skip this step.)

- [ ] **Step 5: Route `` `Full `` through the record path + `Mark` binding.**

`resolve_mark_extent` no longer returns `` `Full `` (it returns `` `Partial `` now), so in the `Ast.Mark` handler delete the `` `Full -> subdivide … `` arm in BOTH the `` `Fresh `` (~line 1286) and `` `Existing `` (~line 1317) matches, leaving only the `` `Partial `` arm. Then in `dispatch_partial`, replace the `CSubdivide` arm so it records instead of subdividing, and change `bind_material` to bind a `Mark`:

```ocaml
        let bind_mark cid line =
          match name_opt with
          | Some n -> bind_crease ctx n span (Mark (cid, line))
          | None -> ()
        in
        let dispatch_partial ~cid ~table_axis:_ ~prov:_ ~flap ~extent_geom
            ~paper_axis =
          match
            Fold_state.classify_mark_extent !(ctx.state) ~flap ~axis:paper_axis
              ~extent_geom
          with
          | Fold_state.CSubdivide (a, b) | Fold_state.CRecord (Fold_state.MSeg (a, b)) ->
              ctx.state :=
                Fold_state.add_mark !(ctx.state)
                  { Fold_state.mgeom = MSeg (a, b); mline = paper_axis;
                    mintent = intent; mcrease_id = cid };
              bind_mark cid paper_axis
          | Fold_state.CRecord (Fold_state.MPoint p) ->
              ctx.state :=
                Fold_state.add_mark !(ctx.state)
                  { Fold_state.mgeom = MPoint p; mline = paper_axis;
                    mintent = intent; mcrease_id = cid };
              bind_mark cid paper_axis
          | Fold_state.CCrossesFold _ ->
              let a, b =
                match ext with Ast.Between (a, b) -> (a, b) | _ -> assert false
              in
              Error.fail span
                (Printf.sprintf
                   "the mark's extent from %s to %s crosses a folded crease \
                    (it leaves its flap)"
                   (pstr a) (pstr b))
        in
```

Note: `CSubdivide` now records rather than subdivides — full chords become `MSeg` marks. The `table_axis`/`prov` params are unused by the record path; keep the signature for the caller but underscore them.

- [ ] **Step 6: Update the `` `Existing `` branch's `promote` to bind `Mark`.**

In the `` `Existing `` branch (~line 1295), the `promote` closure promotes a `Frozen` to `Material`. Change it to promote to `Mark` (a marked value line is now a material construction, not a subdividing crease):

```ocaml
                  | Frozen _ ->
                      promote_crease ctx cr.Ast.cname (Mark (cid, table_axis))
```

- [ ] **Step 7: Build + run the Task-1/2 tests.**

Run: `dune build 2>&1 && dune test 2>&1 | grep -A3 "full mark"`
Expected: PASS — 1 face, 1 mark.

- [ ] **Step 8: Commit.**

```bash
git branch --show-current
git add lib/eval.ml lib/geom.ml
git commit -m "feat(eval): marks record instead of subdividing (full chords too)"
```

### Task 3: Meet locates an interior point with the sheet still 1 face

**Files:**
- Test: `tests/test_eval.ml` (behaviour already wired by Tasks 1-2; this task proves it and locks it with a golden).

**Interfaces:**
- Consumes: `Mark` binding + `paper_line_of_crease` + `select_point` (~line 411, unchanged).

- [ ] **Step 1: Write the failing test — centre of a square, still 1 face.**

```ocaml
let () =
  let st = eval_source {|
paper square
mark --ac = through .a .c
mark --bd = through .b .d
.ctr = --ac * --bd
|} in
  Alcotest.(check int) "faces after centre" 1 (Array.length st.Fold_state.faces);
  let ctr = named_point st "ctr" in   (* use the file's point accessor *)
  Alcotest.(check bool) "centre at (1/2,1/2)" true
    (Geom.point_equal ctr { Geom.x = Num.of_string "1/2"; y = Num.of_string "1/2" })
```

- [ ] **Step 2: Run it.**

Run: `dune test 2>&1 | grep -A3 "centre"`
Expected: PASS (Tasks 1-2 already deliver this). If `named_point`/`Num.of_string` differ, match the file's helpers. If it FAILS on "no material mark to cross", re-check Task 1 Step 5 wiring.

- [ ] **Step 3: Add the `.bel` example + golden.**

Create `examples/square-centre.bel`:

```
paper square
mark --ac = through .a .c
mark --bd = through .b .d
.ctr = --ac * --bd
```

Regenerate its golden the way the repo does (find how existing `examples/*.bel` goldens are produced — e.g. a `dune test` promote or a `tools/` script — and follow it). Verify the FOLD output has the expected face count for this Phase (Phase 1: marks in `beloch:marks`, sheet 1 face).

- [ ] **Step 4: Commit.**

```bash
git branch --show-current
git add tests/test_eval.ml examples/square-centre.bel tests/  # + the generated golden path
git commit -m "test(eval): centre-of-square locates a point with sheet still 1 face"
```

### Task 4: `fold` on a mark materializes a real crease

**Files:**
- Modify: `lib/eval.ml` — verify the `Ast.Fold` handler + `resolve_markable` resolve a `Mark` binding to its line (~line 1098-1140, 1326).
- Test: `tests/test_eval.ml`.

**Interfaces:**
- Consumes: `Mark(cid, line)` binding; `resolve_markable` / `run_fold`.
- Produces: `fold --ac` where `--ac` is a `Mark` produces a real subdividing crease (faces increase), leaving the mark intact.

- [ ] **Step 1: Write the failing test — fold along a marked diagonal really subdivides.**

```ocaml
let () =
  let st = eval_source {|
paper square
mark --ac = through .a .c
fold --ac valley moving .a
|} in
  Alcotest.(check bool) "fold on mark subdivides" true
    (Array.length st.Fold_state.faces >= 2)
```

- [ ] **Step 2: Run it.**

Run: `dune test 2>&1 | grep -A3 "fold on mark"`
Expected: it may already PASS if `resolve_markable` resolves a `Mark` to its line. If it FAILS (e.g. "not a physical crease" / cannot find the line), proceed to Step 3; else skip to Step 4.

- [ ] **Step 3: Teach `resolve_markable` to accept a `Mark` binding.**

In `resolve_markable` (~line 1098), wherever it inspects the bound `crease_val` to recover an axis, add a `Mark (_, line) -> …` arm that yields `line` as the fold axis (mirroring the `Material` case's line recovery). A `fold` then runs the normal `run_fold`, which subdivides — the mark is untouched.

- [ ] **Step 4: Build + test.**

Run: `dune build 2>&1 && dune test 2>&1 | grep -A3 "fold on mark"`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git branch --show-current
git add lib/eval.ml tests/test_eval.ml
git commit -m "feat(eval): fold on a mark materializes a real crease"
```

### Task 5: Full regression sweep for Phase 1

**Files:**
- Modify: existing goldens under `tests/`/`examples/` that used full `mark` chords and previously showed subdivided faces.

- [ ] **Step 1: Run the whole suite.**

Run: `dune test 2>&1 | tail -40`
Expected: failures ONLY in goldens where a full `mark` previously subdivided (now records). Inspect each: the face/edge counts drop; the mark moves from `edges_*` into `beloch:marks`. No fold-time behaviour (collapse/layer-order) should change.

- [ ] **Step 2: For each legitimately-changed golden, confirm the diff is only mark-subdivision removal, then promote.**

Review the diff per file. It must be: fewer faces/edges, the mark now under `beloch:marks`. If any collapse/layer-order golden changed, STOP — that means a mark leaked into fold-time (regression); re-check Task 2. Otherwise promote goldens the repo's way (`dune promote` or the project script).

- [ ] **Step 3: Commit.**

```bash
git branch --show-current
git add tests/ examples/
git commit -m "test: promote goldens for non-subdividing full marks (Phase 1)"
```

---

## Phase 2 — Emit: planar overlay + boundary-incidence classifier

At the end of Phase 2: at FOLD emit, mark segments are overlaid on the real crease pattern in paper space, split at crossings; a mark sub-segment with both endpoints material graduates to a standard `F` crease (so full diagonals are visible `F` creases meeting at `.ctr`); dangling sub-segments stay in `beloch:marks`; a mark coincident with a real crease is dropped.

### Task 6: The overlay data structure + classifier (pure, unit-tested)

**Files:**
- Create: `lib/mark_overlay.ml` (+ `lib/mark_overlay.mli`).
- Modify: `lib/dune` if modules are listed explicitly (check first).
- Test: `tests/test_mark_overlay.ml` (+ wire into `tests/dune`).

**Interfaces:**
- Consumes: `Fold_state.t` (its `faces`, `edges`, `marks`), `Geom` primitives.
- Produces:

```ocaml
(* mark_overlay.mli *)
type mark_edge = {
  a : Geom.point;              (* paper space *)
  b : Geom.point;
  intent : Fold_state.assign;  (* CP colour, from the source mark's mintent *)
  graduated : bool;            (* true → emit as standard F; false → beloch:marks *)
  crease_id : int;             (* source mark's mcrease_id *)
}

(* Overlay all MSeg marks against the real crease pattern of [st], in global
   paper space: split every mark segment at its intersections with real edges
   and with other mark segments, drop sub-segments coincident with a real
   crease, and classify each surviving sub-segment. A sub-segment is
   [graduated] iff BOTH endpoints are "material" — coincident with a paper
   corner, on the paper boundary, or on a real crease/vertex. MPoint marks are
   not overlaid (they carry through untouched). *)
val compute : Fold_state.t -> mark_edge list
```

- [ ] **Step 1: Write failing unit tests with exact geometry.**

`tests/test_mark_overlay.ml` — build a `Fold_state.t` for an unfolded unit square (corners (0,0),(1,0),(1,1),(0,1)) with two full-diagonal marks and assert:

```ocaml
(* two diagonals, no real creases: each diagonal splits at the centre into
   two sub-segments, all four endpoints material (corners + the centre, which
   is a mark×mark crossing) → all graduated. 4 mark_edges, all graduated. *)
let () =
  let st = square_with_diagonal_marks () in   (* test helper, built by hand *)
  let es = Mark_overlay.compute st in
  Alcotest.(check int) "4 sub-edges" 4 (List.length es);
  Alcotest.(check bool) "all graduated" true
    (List.for_all (fun e -> e.Mark_overlay.graduated) es)

(* a dangling reference mark from corner .a to the centre (mid-face endpoint,
   with NO second diagonal present so the centre is NOT a crossing) → its
   centre endpoint is dangling → not graduated. *)
let () =
  let st = square_with_dangling_mark () in
  let es = Mark_overlay.compute st in
  Alcotest.(check int) "1 sub-edge" 1 (List.length es);
  Alcotest.(check bool) "not graduated" false
    (List.hd es).Mark_overlay.graduated
```

Write the two `square_with_*` helpers by hand constructing `Fold_state.t` (one face, four boundary edges, the mark(s)); mirror how `tests/test_eval.ml` builds states, or eval a tiny `.bel` and read `!ctx.state`.

- [ ] **Step 2: Run — expect module-not-found / test fail.**

Run: `dune test 2>&1 | grep -iA3 overlay`
Expected: FAIL (module `Mark_overlay` undefined).

- [ ] **Step 3: Implement `Mark_overlay.compute`.**

Algorithm (all in global paper space, exact `Num`):

1. `real_segs` = for each `e` in `st.edges`, the paper segment `(e.ea, e.eb)`.
2. `mark_segs` = for each `MSeg (a,b)` mark, record `(a, b, mintent, mcrease_id)`; skip `MPoint`.
3. For each mark seg, collect **split points**: its own endpoints, plus every `Geom.intersection` with a real seg or another mark seg that lies on the mark seg (`Geom.on_segment`). Dedup with `Geom.point_equal`, sort along the segment by `Geom.seg_param`.
4. Emit consecutive pairs as sub-segments.
5. **Coincidence drop:** skip a sub-segment whose midpoint lies on some real seg (collinear + `on_segment`) — it is a real crease already.
6. **Classify `graduated`:** endpoint `p` is material iff — it is a paper corner OR on the paper boundary (`Fold_state.point_on_polygon_boundary` against the sheet outline / any face boundary) OR it lies on a real seg (`on_segment`) OR it is an intersection with another mark seg that is itself graduated. A conservative, correct first cut: material iff `p` is on the paper boundary OR on some real edge OR is a mark×mark crossing. `graduated` = both endpoints material.

Implement with `Geom` primitives already used elsewhere (`intersection`, `on_segment`, `seg_param`, `point_equal`, `side_of_line`). Keep it a pure function of `st`.

- [ ] **Step 4: Run unit tests to green.**

Run: `dune test 2>&1 | grep -iA3 overlay`
Expected: PASS both cases.

- [ ] **Step 5: Commit.**

```bash
git branch --show-current
git add lib/mark_overlay.ml lib/mark_overlay.mli lib/dune tests/test_mark_overlay.ml tests/dune
git commit -m "feat(emit): mark overlay + boundary-incidence classifier"
```

### Task 7: Wire the overlay into FOLD emit

**Files:**
- Modify: `lib/fold_emit.ml` — the CP-frame builder (`to_json_folded`, edges ~line 176-219) and `beloch_marks` (~line 271-297).
- Test: golden update via `examples/square-centre.bel`.

**Interfaces:**
- Consumes: `Mark_overlay.compute`.
- Produces: emitted CP where graduated mark edges appear in `edges_vertices`/`edges_assignment` as `F` (colour from `intent`), and only non-graduated marks + all `MPoint` marks remain in `beloch:marks`.

- [ ] **Step 1: Write/adjust the golden expectation for `square-centre`.**

The centre example must now emit: a vertex at (1/2,1/2), four `F` edges (the diagonal halves) meeting there, and an EMPTY (or `MPoint`-only) `beloch:marks`. Encode this as the promoted golden (Step 4 regenerates it); first assert in `tests/test_e2e.ml` the CP has the centre vertex + 4 `F` edges.

- [ ] **Step 2: In `fold_emit`, fold graduated overlay edges into the CP edge arrays.**

In `to_json_folded`, after the existing real-edge loop, append the `Mark_overlay.compute fd.Eval.state` edges with `graduated = true` into `vertices_coords`/`edges_vertices`/`edges_assignment` (assignment string from `intent` via the existing `mark_assign_str`, or `"F"` per the design's folded-form rule — use CP-frame `intent` colour here since this is the crease-pattern frame). Reuse the `vindex` vertex-dedup helper so the centre coincides with any existing vertex.

- [ ] **Step 3: Restrict `beloch_marks` to non-graduated + points.**

Change `beloch_marks` (~line 271) to emit: every `MPoint` mark, plus the overlay edges with `graduated = false` (as `kind:"seg"`). Do NOT emit graduated segments here (they are now `F` edges in Step 2). Drop coincident segments (already dropped by `compute`).

- [ ] **Step 4: Build, run, promote goldens.**

Run: `dune build 2>&1 && dune test 2>&1 | tail -40`
Expected: `square-centre` shows 4 `F` diagonal halves + centre vertex, empty `beloch:marks`. Promote changed goldens; verify no fold-time (collapse/layer) golden moved.

- [ ] **Step 5: Commit.**

```bash
git branch --show-current
git add lib/fold_emit.ml tests/ examples/
git commit -m "feat(emit): graduate full mark chords to F creases at emit"
```

### Task 8: Renderer parity + dangling-mark example

**Files:**
- Verify: `tools/fold2svg.mjs` still renders `beloch:marks` (dangling segs + point ticks) and now also draws graduated marks as ordinary `F` creases.
- Create: `examples/reference-then-fold.bel` — a dangling reference mark that a later fold splits, proving one piece graduates and one stays a mark.

- [ ] **Step 1: Render `square-centre` and a dangling example.**

Follow `[[beloch-fold-rendering-and-pr-screenshots]]`: `node tools/fold2svg.mjs` (CP view) on `square-centre` (expect an X of `F` creases) and on a dangling example (expect a short reference tick/seg).

- [ ] **Step 2: Add the split-mark example + golden.**

`examples/reference-then-fold.bel`: a `mark … between .a <mid>` dangling reference, then a `fold` whose crease crosses it. After Phase 2 emit, the bounded piece graduates to `F`, the dangling piece stays in `beloch:marks`. Assert this in `tests/test_e2e.ml` and promote the golden.

- [ ] **Step 3: Commit.**

```bash
git branch --show-current
git add examples/reference-then-fold.bel tools/fold2svg.mjs tests/
git commit -m "test: split-mark graduation + renderer parity"
```

### Task 9: Update the spec/docs to record shipped behaviour

**Files:**
- Modify: `docs/superpowers/specs/2026-07-10-marks-material-layer-design.md` (status → shipped), the mark/fold notation spec if it states full marks subdivide, `CLAUDE.md`/notes only if a documented invariant changed.

- [ ] **Step 1: Flip the design status + note any deltas discovered during impl.**

- [ ] **Step 2: Grep the spec tree for "full marks subdivide" and correct stale claims.**

Run: `rg -n "full.*subdivid|subdivid.*full" docs/`
Expected: fix the Slice 2 line that says full marks subdivide (now: full marks record; graduate to F at emit).

- [ ] **Step 3: Commit.**

```bash
git branch --show-current
git add docs/
git commit -m "docs: record marks-material-layer as shipped"
```

---

## Self-Review

**Spec coverage:** §3.1 data model → Task 2 (record path) + Task 1 (`mark_chords`). §3.2 binding → Task 1. §3.3 meet → Task 3. §3.4 fold-on-mark → Task 4. §3.5 zero fold-time filters → verified negatively in Tasks 5/7 (no collapse/layer golden may move). §3.6 emit overlay + classifier + coincidence → Tasks 6-7. §3.7 MPoint untouched → Task 6 (skips MPoint) + Task 8. Worked example §4 → Tasks 3/7. Scope §5 deferrals (fuzzy snapping, inference, set-valued layers, clean-CP toggle) → not tasked, correct.

**Placeholder scan:** All code steps carry real code except Task 6 Step 3 (algorithm as a numbered spec with named `Geom` primitives) and golden-regeneration steps ("the repo's way") — both are honest: the arrangement is test-driven against the exact cases in Step 1, and the golden mechanism is discovered from the existing suite rather than guessed.

**Type consistency:** `Mark of int * Geom.line` used identically in Tasks 1-4. `mark_chords : t -> int -> (point*point) list` defined Task 1, consumed Task 1 Step 5. `Mark_overlay.mark_edge`/`compute` defined Task 6 `.mli`, consumed Task 7. `graduated` bool consistent across Tasks 6-8.

**Known soft spots to watch during execution:**
- Task 2 Step 3/4: the full-chord clip across a *multi-face* flap is approximated by farthest-pair of per-face clip endpoints — correct for convex single-flap sheets (all current examples); a non-convex flap could need per-face marks. Flag if an example breaks it.
- Task 6 Step 3: "material endpoint" via mark×mark crossing has a mutual-recursion smell (a crossing is material iff the crossing edges graduate). The conservative cut (crossing counts as material) is sound for the centre case; revisit only if a chained-scaffold example misclassifies.
