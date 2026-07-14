# Unified renderer (`renderScene`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse `renderCP` and `renderFolded` into one `renderScene` whose
geometry (isometry) and decorations (texture) are independently controllable,
with composable primitives (faces, lines, dots, labels, highlight) — fixing
missing folded-view labels, overlapping labels, and the 1-based stepper counter.

**Architecture:** Geometry comes from a `Frame`; decorations are paper-space
features projected through that frame's per-face isometries (`facesMatrix`).
`isometry` selects the frame (flat = synthetic single-face paper; step k =
`scene.steps[k].frame`); `texture.upToStep` filters features by step provenance,
orthogonally. `renderCP`/`renderFolded` become thin presets.

**Tech Stack:** OCaml (evaluator/emitter, dune), TypeScript + Bun (renderer/scene
in `render/`, docs site in `site/`), Yojson FOLD emission.

**Spec:** `docs/superpowers/specs/2026-07-14-render-scene-unified-design.md`

## Global Constraints

- Exact-only kernel; no floats introduced in OCaml. Emit coords via existing
  `q_to_json`.
- Determinism: no `Date.now`/`Math.random`; label declutter must be deterministic
  (byte-stable snapshots).
- OCaml builds/tests run under `direnv exec /home/toph/Projects/beloch dune …`
  (dune is not on bare PATH; `,`/comma fails headless).
- TS tests run with `bun test` inside the package dir (`render/scene`,
  `render/render-svg`, `site`); site tests that spawn `beloch` need it on PATH →
  `direnv exec /home/toph/Projects/beloch bun test`.
- FOLD emit is pretty-printed (`Yojson.Safe.pretty_to_string`); regenerate
  fixtures with the built `_build/default/bin/main.exe fold <bel>`.
- `steps` inline assertion counts `Eval.frames` (folds only, excludes the flat
  emit-frame) — do not change that.
- Conventional commits; end bodies with the repo's Co-Authored-By / Claude-Session
  trailers.

---

## Slice A — Emitter step provenance on named points/lines

Named points/lines carry no step today, so `texture.upToStep` cannot filter
freely-constructed points. Record the creation step in the evaluator and emit it.

**Creation step definition:** the number of folded frames pushed
(`List.length ctx.frames_rev`) at the moment the name is bound. Task A1's test
pins whether the record must happen before or after the binding statement's fold
push, using the reflecting example (`fold --v = map .a onto .b` → `--v` must land
on the same step as its fold).

### Task A1: record creation step at bind time

**Files:**
- Modify: `lib/eval.ml` (ctx record ~160-171; `bind_point` ~124-131;
  `bind_crease` ~133-139; result assembly ~1763-1793)
- Test: `tests/cases/construct/named-step.bel` (new inline-assertion fixture)
- Test: `tests/test_bel_assert.ml` (add a `named-step` reader if needed — see step 1)

**Interfaces:**
- Produces: `Eval.named_points : (string * Geom.point * int) list` and
  `Eval.named_lines : (string * Geom.line * int) list` (was 2-tuples; the third
  element is the 0-based creation step). All `Eval.named_points` consumers in
  `lib/fold_emit.ml` (lines 82, 163, 314-326, 391-397) must destructure the new
  arity.

- [ ] **Step 1: Write the failing test.** Add an inline-assertion case that
  fixes the step of a corner (0) and a first-fold crease. Corners are bound in
  the prelude (step 0); `--v` is created by the first `fold`.

```
; tests/cases/construct/named-step.bel
paper square
fold --v = map .a onto .b
; assert named-step .a = 0
; assert named-step --v = 1
```

  If `test_bel_assert.ml` has no `named-step` predicate, add one alongside the
  existing `steps`/`faces` readers (around line 353): look up the name in
  `fd.Eval.named_points` / `fd.Eval.named_lines` and compare the third element.

- [ ] **Step 2: Run it to verify it fails.**
  Run: `direnv exec /home/toph/Projects/beloch dune test 2>&1 | rg named-step`
  Expected: FAIL (arity error or assertion unknown).

- [ ] **Step 3: Add a creation-step side table to `ctx` and record at bind.**
  In the `ctx` record add `name_step : (string, int) Hashtbl.t` initialised
  `Hashtbl.create 16`. In `bind_point` and `bind_crease`, after the existing
  `Hashtbl.replace s.points/lines …`, record the step:

```ocaml
Hashtbl.replace ctx.name_step name (List.length ctx.frames_rev)
```

  If the A1 test shows `--v` recorded as 0 (bind runs before the fold push),
  move the fold statement's `push_frame` call ahead of its `bind_crease`, OR
  record in `bind_crease` as `List.length ctx.frames_rev` measured after the
  push — pick whichever the test pins and leave a comment.

- [ ] **Step 4: Thread the step into the result tuples.** At result assembly
  (1763-1788), attach the recorded step (default 0 if absent):

```ocaml
let step_of n = match Hashtbl.find_opt ctx.name_step n with Some s -> s | None -> 0 in
let named_points =
  Hashtbl.fold
    (fun k v acc -> if is_temp k then acc else (k, v, step_of k) :: acc)
    root_scope.points []
in
(* named_lines: same, appending `, step_of k` to each (k, l) tuple *)
```

  Update the `Eval.t` record fields `named_points`/`named_lines` types (lines
  15-16) to the 3-tuple arity.

- [ ] **Step 5: Fix `fold_emit.ml` destructuring.** The emitter consumes
  `fd.Eval.named_points` in several places; update each pattern to ignore or use
  the new step element. `folded_frame_of_state` and `vertices_names_json` take
  `named_points` typed `(string * Geom.point) list` (lines 7, 82) — either widen
  their signature to the 3-tuple and ignore the step, or map
  `List.map (fun (n,p,_) -> (n,p))` at the call sites (391, 314). Keep the
  helper signatures 2-tuple and strip at call sites — smaller blast radius.

- [ ] **Step 6: Run to verify pass.**
  Run: `direnv exec /home/toph/Projects/beloch dune test 2>&1 | tail -5`
  Expected: PASS, 37 tests (36 + named-step).

- [ ] **Step 7: Commit.**

```bash
git add lib/eval.ml lib/fold_emit.ml tests/cases/construct/named-step.bel tests/test_bel_assert.ml
git commit -m "feat(eval): record creation step for named points/lines"
```

### Task A2: emit `step` in `beloch:named_points`/`beloch:named_lines`

**Files:**
- Modify: `lib/fold_emit.ml:315-336`
- Test: covered by A4 (fixture regen + scene parse)

**Interfaces:**
- Produces FOLD shape:
  `beloch:named_points` = `{ name: { paper:[x,y], table:[x,y], step:int } }`
  `beloch:named_lines` = `{ name: { coeffs:[a,b,c], step:int } }`
  (named_lines becomes an object per name, no longer a bare 3-element list — this
  changes the parse in A3.)

- [ ] **Step 1: Extend `beloch_named_points`.** Add the step field:

```ocaml
let beloch_named_points =
  `Assoc
    (List.map
       (fun (name, (p : Geom.point), step) ->
         let t = Fold_state.table_position fd.Eval.state p in
         ( name,
           `Assoc
             [ ("paper", `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ]);
               ("table", `List [ q_to_json t.Geom.x; q_to_json t.Geom.y ]);
               ("step", `Int step) ] ))
       fd.Eval.named_points)
```

- [ ] **Step 2: Extend `beloch_named_lines`** to an object carrying `coeffs`+`step`:

```ocaml
let beloch_named_lines =
  `Assoc
    (List.map
       (fun (name, (l : Geom.line), step) ->
         ( name,
           `Assoc
             [ ("coeffs", `List [ q_to_json l.Geom.a; q_to_json l.Geom.b; q_to_json l.Geom.c ]);
               ("step", `Int step) ] ))
       fd.Eval.named_lines)
```

- [ ] **Step 3: Build + emit reflecting example, verify shape.**
  Run: `direnv exec /home/toph/Projects/beloch dune build bin/main.exe && _build/default/bin/main.exe fold tests/cases/fold/cube-root.bel | jq '.["beloch:named_lines"] | to_entries[0]'`
  Expected: value is `{coeffs:[…], step:N}`.

- [ ] **Step 4: Commit.**

```bash
git add lib/fold_emit.ml
git commit -m "feat(emit): step provenance in beloch:named_points/named_lines"
```

### Task A3: parse `step` in the scene layer

**Files:**
- Modify: `render/scene/src/types.ts` (`NamedPoint`, `NamedLine`)
- Modify: `render/scene/src/parse.ts` (named points/lines parsing)
- Test: `render/scene/test/parse.test.ts`

**Interfaces:**
- Produces: `NamedPoint { name, paper, table, step: number }`,
  `NamedLine { name, coeffs, step: number }`. Downstream (Slice B `texture.ts`)
  filters on `step`.

- [ ] **Step 1: Write the failing test.** In `parse.test.ts`, extend the
  bisect-a named-lines assertion (currently line 23) to include `step`:

```ts
expect(scene.namedLines).toEqual([{ name: "v", coeffs: [-1, 0, -0.5], step: 1 }]);
```

  (Adjust the expected step to whatever A1's semantics produce for `--v`; read it
  once via a scratch parse if unsure.)

- [ ] **Step 2: Run to verify it fails.**
  Run: `cd render/scene && bun test 2>&1 | rg -A2 namedLines`
  Expected: FAIL (missing `step`).

- [ ] **Step 3: Add `step` to the types.**

```ts
export interface NamedPoint { name: string; paper: Vec2; table: Vec2; step: number; }
export interface NamedLine  { name: string; coeffs: LineCoeffs; step: number; }
```

- [ ] **Step 4: Parse the new shape.** In `parse.ts`, where named points/lines
  are read from `beloch:named_points`/`beloch:named_lines`, read `paper`/`table`/
  `coeffs` and the new `step` (default 0 if absent for older fixtures). named_lines
  changed from a bare list to `{coeffs, step}` — update the reader accordingly.

- [ ] **Step 5: Run to verify pass.**
  Run: `cd render/scene && bun test 2>&1 | tail -3`
  Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add render/scene/src/types.ts render/scene/src/parse.ts render/scene/test/parse.test.ts
git commit -m "feat(scene): parse step provenance on named points/lines"
```

### Task A4: regenerate fixtures + goldens; fix affected assertions

**Files:**
- Modify (regen): all `.fold` under `render/render-svg/test/fixtures`,
  `render/scene/test/fixtures`, `site/src/lib/fixtures`, `tests/golden/bases`
  (except bespoke `fold-occlude.fold`, `marks-demo.fold`)
- Test: run every suite

- [ ] **Step 1: Regenerate `.bel`-sourced fixtures** with the built exe (mapping
  as in the prior slice: bisect-a, cube-root, fold-quarter, square, x-midpoint,
  def-diagonals). Golden bases via `direnv exec … dune exec tools/regen.exe`.

- [ ] **Step 2: Run OCaml + all TS suites; fix any assertion that enumerates
  named points/lines** (only shape changes are the added `step`).
  Run: `direnv exec /home/toph/Projects/beloch dune test` then
  `cd render/scene && bun test`, `cd render/render-svg && bun test`,
  `direnv exec /home/toph/Projects/beloch bun test` in `site`.
  Expected: all green.

- [ ] **Step 3: Commit.**

```bash
git add -A ':*.fold' render/scene/test/parse.test.ts
git commit -m "test(fixtures): regenerate with named-construction step provenance"
```

**Slice A deliverable:** every FOLD carries step provenance on all feature types;
all suites green. Independently mergeable.

---

## Slice B — `renderScene` core + presets

Detailed plan authored after Slice A merges (its steps reference A's concrete
emitted shape and move large existing blocks). Task shape and interfaces below
are fixed by the spec; the per-step code is filled in at that point.

- **B1 — flat frame + isometry resolver** (`render/render-svg/src/isometry.ts`):
  `resolveIsometry(scene, { kind:"flat" } | { kind:"step", index }) → { frame: Frame, order: number[], faceUp: boolean[] }`.
  Flat builds a synthetic single-face `Frame` over `scene.cp.vertices` bbox with
  identity `facesMatrix` and empty `faceOrders`; step returns `scene.steps[k].frame`
  with occlusion via existing `linearExtension`/`sideUp`.
- **B2 — texture collect+project** (`render/render-svg/src/texture.ts`):
  `collectTexture(scene, { upToStep, creases, marks, points, lines }) → { lines: ProjLine[], dots: ProjDot[] }`
  filtering every feature by `step ≤ upToStep`, projecting paper→face via the
  isometry frame's `facesMatrix` + `clipLineToPoly`/`lineToFace` (moved from
  `constructions.ts`).
- **B3 — faces primitive** (`primitives/faces.ts`): draw `"filled"`(+occlusion) |
  `"outline"` | `"none"` from the resolver output (moves the face-painting loop
  out of `render-folded.ts`).
- **B4 — lines+dots primitives** (`primitives/lines.ts`, `primitives/dots.ts`):
  render projected texture with `data-bel-name`/`data-step`/highlight hooks
  (consolidates the crease/edge drawing from both current renderers).
- **B5 — labels primitive** (`primitives/labels.ts`): `placeLabels(anchors) →`
  positioned `<text>`; deterministic candidate-offset ring + ε-coincidence
  clustering (`.a,.b,.c,.d`). New unit test with coincident + dense anchors.
- **B6 — orchestrator** (`render/render-svg/src/render-scene.ts`): `renderScene`
  wiring isometry → faces → texture → lines/dots → labels → highlight → HUD.
- **B7 — presets**: rewrite `render-cp.ts`/`render-folded.ts` as thin wrappers
  over `renderScene`; target byte-compatible snapshots for CP and re-baseline the
  folded snapshots (labels now present). Keep exported signatures
  (`renderCP(scene, opts)`, `renderFolded(scene, FoldedOptions)`).
- **B8 — labels in folded**: the folded preset sets `primitives.labels`; the docs
  figure passes it. Verify reflecting page shows `.a/.b/--v` labels folded.

**Slice B deliverable:** one renderer path; CP byte-compatible, folded gains
decluttered labels; the four compositions callable.

---

## Slice C — compositions & 0-based stepper

Detailed plan authored after Slice B merges.

- **C1 — stepper numbering**: `site/src/lib/beloch-figure.ts` label reads
  `Step ${this.step} / ${N-1}` (0-based; flat = Step 0). Update
  `beloch-figure.test.ts` expectations.
- **C2 — composition opt-in**: `site/src/components/Beloch.astro` accepts optional
  attributes (e.g. `texture-up-to`, `isometry`) that map to `renderScene` params
  for ghost / progressive-flat; default stays CP/folded.
- **C3 — wire tutorials**: use a ghost or progressive figure where a tutorial page
  benefits (reflecting first); confirm renders.

**Slice C deliverable:** ghost/progressive compositions available in docs; stepper
reads step 0…N−1.

---

## Shipped (2026-07-14) — deviations from the sketch above

Slices B and C landed on `feat/render-scene-b-core`. Two deliberate deviations
from the interface sketch, both to cut churn under structural-only test coverage:

- **No `texture.ts` / `primitives/faces|lines|dots.ts` split.** The two legacy
  draw paths were merged into a single `render-scene.ts` orchestrator under one
  `occlude` branch instead of four primitive files. Same single-path goal; the
  presets (`renderCP`/`renderFolded`) are byte-identical thin wrappers, proven
  by the unchanged CP structural assertions + folded snapshots. `labels.ts`
  (declutter) and `isometry.ts` (resolver) *did* land as their own modules.
- **Crease step provenance for `texture.upToStep` is derived, not intrinsic.**
  Edge `beloch:step` is a string macro-label, so numeric filtering maps a crease
  to its named-line's numeric step (Slice A); boundary/unnamed creases default to
  step 0 (always shown). Good enough for progressive-flat + ghost; a first-class
  numeric edge step is a possible follow-up.
- **Ghost projects only *named* future lines** (`--second`), reused via the
  existing per-face `lineToFace`+`clipLineToPoly` pullback. Anonymous future
  creases are not ghosted.
- **C3 landed on `layers.mdx`, not `reflecting.mdx`.** Reflecting is now entirely
  `mark`-based (no folded steps), so a composition figure there would not be
  load-bearing. The two-fold section on the Layers page ghosts the second crease
  onto the one-fold stack — a view the CP/folded stepper cannot produce.

## Self-review notes

- Spec coverage: isometry×texture axes (B1/B2), 4 compositions (B6/C2), faces
  styles (B3), labels+declutter (B5/B8), stepper (C1), named-step provenance
  (A1–A4), presets/byte-compat (B7). All mapped.
- The only cross-task type change is `Eval.named_points/named_lines` arity (A1) →
  consumed in A1/A2 fold_emit and A3 parse; signatures stated in A1 Interfaces.
- Slices B/C are intentionally interface-level: their code moves large existing
  blocks whose exact diffs depend on A's merged output. Each gets a full
  code-complete plan at execution time, per the per-sub-project cycle.
