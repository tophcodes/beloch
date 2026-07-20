# Per-statement `kept_marks` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each `beloch:statements` entry carries `kept_marks` — the marks still dangling (not yet graduated into a real crease) as of that statement — so the Playground's mark overlay stops highlighting a mark that's already become part of the real folded geometry.

**Architecture:** Extract the existing graduation predicate (`fold_emit.ml`'s `cp_display`) into `Fold_state.mark_graduates`, shared by both the existing emit-time call site and a new one in `eval.ml`. `stmt_log_entry` gains `sl_kept : Fold_state.mark list`, computed differently per statement kind: `SMark` inherits the previous statement's kept list and appends its own new mark (no re-check — the backdrop frame is fixed and strictly predates the mark, so graduation can't apply yet); `SFold` recomputes fresh via `mark_graduates` against the just-folded state. `@beloch/scene` parses the new `kept_marks` field onto `Statement.keptMarks`; `Playground.astro` uses it directly, deleting its own (buggy) client-side accumulation.

**Tech Stack:** OCaml (dune, Alcotest), TypeScript (Bun test runner), Astro client script (manual verification only, no automated harness for `.astro` — established precedent).

## Global Constraints

- Field name: `kept_marks` in JSON, `keptMarks` in TS — distinct from the existing singular `mark` field on the same statement entry (avoid ambiguity).
- `Fold_state.mark_graduates` is the single source of truth for the boundary-material check — `cp_display` must be refactored to call it, not keep its own duplicate closure.
- No changes to `folded_frame_of_state`, `file_frames`, or the top-level `beloch:marks` field — out of scope, per spec's "Out of scope" section.
- `render-2d/render-svg`'s `MarkOverlay` type is unchanged — it already accepts an arbitrary `Mark[]` + `newestCreaseId`.
- Spec: `docs/superpowers/specs/2026-07-20-per-statement-mark-graduation-design.md`.
- OCaml test baseline (confirmed before starting): `dune exec packages/core/tests/test_e2e.exe -- test` → 37/37 pass. `dune exec packages/core/tests/test_fold_state.exe -- test` → 73/73 pass. (Unrelated pre-existing failures exist elsewhere in the repo — `golden`, `bel_assert`, `flatten bind` test suites — do not chase those; they're not touched by this plan and were already red before it started.)

---

### Task 1: `Fold_state.mark_graduates` — extract the shared predicate

**Files:**
- Modify: `packages/core/lib/fold_state.ml` (add function after `point_on_polygon_boundary`, ~line 1306)
- Modify: `packages/core/lib/fold_state.mli` (add `val`, after `point_on_polygon_boundary`, ~line 396)
- Modify: `packages/core/lib/fold_emit.ml:83-97` (`cp_display`'s `graduates` closure → call the shared function)
- Test: `packages/core/tests/test_fold_state.ml`

**Interfaces:**
- Produces: `Fold_state.mark_graduates : Fold_state.t -> Fold_state.mark -> bool` — true iff a `MSeg` mark's both endpoints lie on some face's boundary in this state's current topology; always `false` for `MPoint`.
- Consumes: existing `Fold_state.faces`, `Fold_state.point_on_polygon_boundary`, `Fold_state.mark`/`mark_geom` types (unchanged).

- [ ] **Step 1: Write the failing test**

Add to `packages/core/tests/test_fold_state.ml`, right after `test_add_mark` (~line 998):

```ocaml
(* mark_graduates: a corner-to-corner seg mark graduates immediately (both
   endpoints are already face-boundary vertices on the flat single-face
   sheet); an interior point mark never graduates. *)
let test_mark_graduates () =
  let corner_seg =
    { Fold_state.mgeom = Fold_state.MSeg (gp 0 0, gp 1 1);
      mline = { Geom.a = q 1; b = q (-1); c = q 0 };
      mintent = Fold_state.V; mcrease_id = 0; mprov = None }
  in
  Alcotest.(check bool) "corner-to-corner seg graduates immediately" true
    (Fold_state.mark_graduates Fold_state.init_square corner_seg);
  let half = Num.div (q 1) (q 2) in
  let interior_seg =
    { Fold_state.mgeom = Fold_state.MSeg (gp 0 0, gph half half);
      mline = { Geom.a = q 1; b = q (-1); c = q 0 };
      mintent = Fold_state.V; mcrease_id = 1; mprov = None }
  in
  Alcotest.(check bool) "seg ending mid-face does not graduate" false
    (Fold_state.mark_graduates Fold_state.init_square interior_seg);
  let point =
    { Fold_state.mgeom = Fold_state.MPoint (gp 0 0);
      mline = { Geom.a = q 1; b = q (-1); c = q 0 };
      mintent = Fold_state.V; mcrease_id = 2; mprov = None }
  in
  Alcotest.(check bool) "point marks never graduate" false
    (Fold_state.mark_graduates Fold_state.init_square point)
```

Register it in the `"task5-flip"` group (~line 1450-1456), which is where
`test_add_mark` itself is registered. Replace line 1456:

```ocaml
          Alcotest.test_case "add_mark" `Quick test_add_mark ] );
```

with:

```ocaml
          Alcotest.test_case "add_mark" `Quick test_add_mark;
          Alcotest.test_case "mark_graduates" `Quick test_mark_graduates ] );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/core && dune build 2>&1`
Expected: FAIL with `Unbound value Fold_state.mark_graduates` (compile error — the function doesn't exist yet).

- [ ] **Step 3: Add `mark_graduates` to `fold_state.ml`**

In `packages/core/lib/fold_state.ml`, immediately after the `point_on_polygon_boundary` function (ends ~line 1305, right before the `polygon_edge_at` comment at ~1307):

```ocaml
(* Emit-time graduation test (design §3.6, packages/core/lib/fold_emit.ml's
   cp_display): true when a seg mark's endpoints already sit on a face
   boundary in this state's current topology — i.e. it's indistinguishable
   from a real crease and should stop being drawn as a dangling record.
   Point marks never graduate. *)
let mark_graduates (st : t) (m : mark) : bool =
  let material (p : Geom.point) =
    Array.exists (fun f -> point_on_polygon_boundary f p) (faces st)
  in
  match m.mgeom with
  | MSeg (a, b) -> material a && material b
  | MPoint _ -> false
```

- [ ] **Step 4: Export it from `fold_state.mli`**

In `packages/core/lib/fold_state.mli`, immediately after the `point_on_polygon_boundary` val (~line 396, before the `type mark_class` block):

```ocaml
val mark_graduates : t -> mark -> bool
(** Emit-time graduation test: true when a seg mark's endpoints already sit
    on a face boundary in this state's current topology. Point marks never
    graduate. *)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/core && dune exec tests/test_fold_state.exe -- test 2>&1 | grep -i "mark_graduates\|Test Successful\|failure"`
Expected: `[OK] ... mark_graduates.` and `Test Successful in ...s. 74 tests run.` (73 existing + 1 new).

- [ ] **Step 6: Refactor `cp_display` to use the shared predicate**

In `packages/core/lib/fold_emit.ml`, replace lines 83-94 (the `cp_display` function's `material`/`graduates` closures):

```ocaml
let cp_display (st : Fold_state.t) : Fold_state.t * Fold_state.mark list =
  let faces = Fold_state.faces st in
  let material (p : Geom.point) =
    Array.exists
      (fun (f : Fold_state.face) -> Fold_state.point_on_polygon_boundary f p)
      faces
  in
  let graduates (m : Fold_state.mark) =
    match m.Fold_state.mgeom with
    | Fold_state.MSeg (a, b) -> material a && material b
    | Fold_state.MPoint _ -> false
  in
  let grad, kept =
    List.partition graduates (Array.to_list (Fold_state.marks st))
  in
```

with:

```ocaml
let cp_display (st : Fold_state.t) : Fold_state.t * Fold_state.mark list =
  let grad, kept =
    List.partition (Fold_state.mark_graduates st)
      (Array.to_list (Fold_state.marks st))
  in
```

(The rest of `cp_display` — the `disp` fold_left that subdivides `grad` marks — is unchanged; `faces`/`material`/`graduates` are no longer referenced elsewhere in this function.)

- [ ] **Step 7: Run the full core test suite to confirm no regressions**

Run: `cd packages/core && dune exec tests/test_fold_state.exe -- test 2>&1 | tail -3 && dune exec tests/test_e2e.exe -- test 2>&1 | tail -3`
Expected: both report `Test Successful` — 74/74 and 37/37 respectively (baseline counts from Global Constraints, +1 for the new `test_mark_graduates`).

- [ ] **Step 8: Commit**

```bash
git add packages/core/lib/fold_state.ml packages/core/lib/fold_state.mli packages/core/lib/fold_emit.ml packages/core/tests/test_fold_state.ml
git commit -m "refactor(core): extract Fold_state.mark_graduates from cp_display"
```

---

### Task 2: `stmt_log_entry.sl_kept` — populate per statement kind

**Files:**
- Modify: `packages/core/lib/eval.ml:15-27` (`stmt_log_entry` type)
- Modify: `packages/core/lib/eval.ml:313-322` (`push_frame`, `SFold` case)
- Modify: `packages/core/lib/eval.ml:1472-1483` (`record` closure inside the `Ast.Mark` handler, `SMark` case)
- Test: `packages/core/tests/test_e2e.ml`

**Interfaces:**
- Consumes: `Fold_state.mark_graduates` (Task 1), `Fold_state.marks`, `ctx.statements_rev : stmt_log_entry list`, `ctx.state : Fold_state.t ref` (all pre-existing).
- Produces: `stmt_log_entry.sl_kept : Fold_state.mark list` — read by Task 3's JSON serializer.

- [ ] **Step 1: Write the failing test**

Extend `test_beloch_statements` in `packages/core/tests/test_e2e.ml`. Its last
two lines currently (~676-677) are:

```ocaml
  Alcotest.(check int) "both marks graduate — beloch:marks is empty" 0
    (List.length global_marks)
```

Replace those two lines with (note the added `;` — this is no longer the
function's tail expression):

```ocaml
  Alcotest.(check int) "both marks graduate — beloch:marks is empty" 0
    (List.length global_marks);
  let kept_count_of j = j |> member "kept_marks" |> to_list |> List.length in
  Alcotest.(check (list int))
    "kept_marks grows through the mark run, then both graduate at the fold"
    [ 1; 2; 0 ] (List.map kept_count_of stmts)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/core && dune build 2>&1`
Expected: FAIL — either a compile error (if `kept_marks` doesn't parse as valid — it won't, `member` on a missing key returns `` `Null ``, and `to_list` on `` `Null `` raises `Yojson.Safe.Util.Type_error`) or a runtime `Type_error: Expected list, got null` when the test runs. Confirm via: `dune exec tests/test_e2e.exe -- test 2>&1 | grep -i "beloch_statements\|kept_marks\|error"`

- [ ] **Step 3: Add `sl_kept` to `stmt_log_entry`**

In `packages/core/lib/eval.ml`, replace lines 15-27:

```ocaml
type stmt_log_entry = {
  sl_kind : stmt_kind;
  sl_span : Error.span;
  sl_frame_index : int;
      (* file_frames index of the frame this statement's geometry reads
         against — the just-pushed frame for [SFold], the most-recently
         pushed frame for [SMark] (marks don't fold anything) *)
  sl_mark : Fold_state.mark option;
      (* the mark AS RECORDED by this statement, captured at record-time —
         independent of whether it later graduates into a real crease (which
         only happens at some LATER fold statement, or never). None for
         [SFold]. *)
}
```

with:

```ocaml
type stmt_log_entry = {
  sl_kind : stmt_kind;
  sl_span : Error.span;
  sl_frame_index : int;
      (* file_frames index of the frame this statement's geometry reads
         against — the just-pushed frame for [SFold], the most-recently
         pushed frame for [SMark] (marks don't fold anything) *)
  sl_mark : Fold_state.mark option;
      (* the mark AS RECORDED by this statement, captured at record-time —
         independent of whether it later graduates into a real crease (which
         only happens at some LATER fold statement, or never). None for
         [SFold]. *)
  sl_kept : Fold_state.mark list;
      (* marks still dangling (not yet graduated into a real crease) as of
         immediately after this statement. [SMark] inherits the previous
         statement's [sl_kept] and appends its own new mark, unchecked — the
         backdrop frame is fixed and strictly predates this mark, so
         graduation cannot apply yet. [SFold] recomputes fresh via
         [Fold_state.mark_graduates] against the just-folded state. See
         docs/superpowers/specs/2026-07-20-per-statement-mark-graduation-design.md. *)
}
```

- [ ] **Step 4: Populate `sl_kept` for `SFold` in `push_frame`**

In `packages/core/lib/eval.ml`, replace lines 313-322:

```ocaml
  let push_frame (span : Error.span option) =
    ctx.frames_rev <- (ctx.panel, !(ctx.state), span) :: ctx.frames_rev;
    ctx.pending <- false;
    (match span with
    | Some sp ->
        ctx.statements_rev <-
          { sl_kind = SFold; sl_span = sp;
            sl_frame_index = List.length ctx.frames_rev; sl_mark = None }
          :: ctx.statements_rev
    | None -> ())
  in
```

with:

```ocaml
  let push_frame (span : Error.span option) =
    ctx.frames_rev <- (ctx.panel, !(ctx.state), span) :: ctx.frames_rev;
    ctx.pending <- false;
    (match span with
    | Some sp ->
        let st = !(ctx.state) in
        let kept =
          Array.to_list (Fold_state.marks st)
          |> List.filter (fun m -> not (Fold_state.mark_graduates st m))
        in
        ctx.statements_rev <-
          { sl_kind = SFold; sl_span = sp;
            sl_frame_index = List.length ctx.frames_rev; sl_mark = None;
            sl_kept = kept }
          :: ctx.statements_rev
    | None -> ())
  in
```

- [ ] **Step 5: Populate `sl_kept` for `SMark` in the `record` closure**

In `packages/core/lib/eval.ml`, replace lines 1472-1483:

```ocaml
        let record ~prov cid mgeom paper_axis =
          let m : Fold_state.mark =
            { Fold_state.mgeom; mline = paper_axis; mintent = intent;
              mcrease_id = cid; mprov = prov }
          in
          ctx.state := Fold_state.add_mark !(ctx.state) m;
          ctx.statements_rev <-
            { sl_kind = SMark; sl_span = span;
              sl_frame_index = List.length ctx.frames_rev; sl_mark = Some m }
            :: ctx.statements_rev;
          bind_mark cid paper_axis
        in
```

with:

```ocaml
        let record ~prov cid mgeom paper_axis =
          let m : Fold_state.mark =
            { Fold_state.mgeom; mline = paper_axis; mintent = intent;
              mcrease_id = cid; mprov = prov }
          in
          ctx.state := Fold_state.add_mark !(ctx.state) m;
          let prior_kept =
            match ctx.statements_rev with
            | prev :: _ -> prev.sl_kept
            | [] -> []
          in
          ctx.statements_rev <-
            { sl_kind = SMark; sl_span = span;
              sl_frame_index = List.length ctx.frames_rev; sl_mark = Some m;
              sl_kept = prior_kept @ [ m ] }
            :: ctx.statements_rev;
          bind_mark cid paper_axis
        in
```

- [ ] **Step 6: Add `kept_marks` to the JSON serializer**

In `packages/core/lib/fold_emit.ml`, replace `beloch_statements_json` (lines 274-292):

```ocaml
let beloch_statements_json (statements : Eval.stmt_log_entry list) : Yojson.Safe.t =
  `List
    (List.map
       (fun (s : Eval.stmt_log_entry) ->
         let common =
           [
             ( "kind",
               `String
                 (match s.Eval.sl_kind with
                 | Eval.SFold -> "fold"
                 | Eval.SMark -> "mark") );
             ("source_line", `Int (fst s.Eval.sl_span).Lexing.pos_lnum);
             ("frame_index", `Int s.Eval.sl_frame_index);
           ]
         in
         match s.Eval.sl_mark with
         | None -> `Assoc (("mark", `Null) :: common)
         | Some m -> `Assoc (("mark", mark_json m) :: common))
       statements)
```

with:

```ocaml
let beloch_statements_json (statements : Eval.stmt_log_entry list) : Yojson.Safe.t =
  `List
    (List.map
       (fun (s : Eval.stmt_log_entry) ->
         let common =
           [
             ( "kind",
               `String
                 (match s.Eval.sl_kind with
                 | Eval.SFold -> "fold"
                 | Eval.SMark -> "mark") );
             ("source_line", `Int (fst s.Eval.sl_span).Lexing.pos_lnum);
             ("frame_index", `Int s.Eval.sl_frame_index);
             ("kept_marks", `List (List.map mark_json s.Eval.sl_kept));
           ]
         in
         match s.Eval.sl_mark with
         | None -> `Assoc (("mark", `Null) :: common)
         | Some m -> `Assoc (("mark", mark_json m) :: common))
       statements)
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd packages/core && dune exec tests/test_e2e.exe -- test 2>&1 | grep -i "beloch:statements\|Test Successful\|FAIL"`
Expected: `[OK] ... beloch:statements.` and `Test Successful in ...s. 37 tests run.` (same count as baseline — this extends an existing test, doesn't add a new one).

- [ ] **Step 8: Run the full core test suite to confirm no regressions**

Run: `cd packages/core && dune exec tests/test_fold_state.exe -- test 2>&1 | tail -3 && dune exec tests/test_e2e.exe -- test 2>&1 | tail -3`
Expected: 74/74 and 37/37, both `Test Successful`.

- [ ] **Step 9: Commit**

```bash
git add packages/core/lib/eval.ml packages/core/lib/fold_emit.ml packages/core/tests/test_e2e.ml
git commit -m "feat(core): compute kept_marks per statement, fixes graduation tracking"
```

---

### Task 3: `@beloch/scene` — parse `keptMarks`

**Files:**
- Modify: `packages/render-2d/scene/src/types.ts` (`Statement` interface, ~line 39-45)
- Modify: `packages/render-2d/scene/src/parse.ts` (`statementsFrom`, ~line 56-65)
- Test: `packages/render-2d/scene/test/parse.test.ts` (the sole test file for
  `parseFold` — has one existing `statements`-focused test,
  `"parseFold: statements carries one entry per fold statement, source
  order"`, ~line 50-56, using the golden fixture `fold-quarter.fold`, which
  has no marks at all. None of `scene/test/fixtures/*.fold`'s existing
  fixtures carry populated `kept_marks` data (all pre-date this field), so
  this task adds a small **inline** FOLD object literal instead of a golden
  fixture — `parseFold` accepts a plain object directly, and only
  `vertices_coords` is required for the CP frame to parse without error;
  everything else defaults safely (confirmed via `parse.ts`'s `frameFrom`).

**Interfaces:**
- Consumes: `Mark`, `markFrom` (existing, `parse.ts:42-49`), the new `kept_marks` JSON field from Task 2.
- Produces: `Statement.keptMarks : Mark[]` — read by Task 4.

- [ ] **Step 1: Write the failing test**

Add to `packages/render-2d/scene/test/parse.test.ts`, right after the
existing `"parseFold: statements carries one entry per fold statement,
source order"` test (~line 56):

```ts
test("parseFold: statements carries kept_marks per statement", async () => {
  const seg = (creaseId: number) => ({
    kind: "seg", a: [0, 0], b: [1, 1], line: [1, -1, 0], intent: "V", crease_id: creaseId,
  });
  const fold = {
    vertices_coords: [[0, 0], [1, 0], [1, 1], [0, 1]],
    "beloch:statements": [
      { kind: "mark", source_line: 2, frame_index: 0, mark: seg(0), kept_marks: [seg(0)] },
      { kind: "mark", source_line: 3, frame_index: 0, mark: seg(1), kept_marks: [seg(0), seg(1)] },
      { kind: "fold", source_line: 4, frame_index: 1, mark: null, kept_marks: [] },
    ],
  };
  const scene = parseFold(fold);
  expect(scene.statements.map((s) => s.keptMarks.length)).toEqual([1, 2, 0]);
  expect(scene.statements[1]!.keptMarks.map((m) => m.creaseId)).toEqual([0, 1]);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/render-2d/scene && bun test test/parse.test.ts -t "kept_marks per statement"`
Expected: FAIL — `s.keptMarks` is `undefined`, `.length` throws
`TypeError: undefined is not an object`.

- [ ] **Step 3: Add `keptMarks` to the `Statement` interface**

In `packages/render-2d/scene/src/types.ts`, replace lines 39-45:

```ts
export interface Statement {
  index: number;
  kind: "fold" | "mark";
  sourceLine: number;                                        // beloch:statements[i].source_line — always present (every stmt has a span)
  frameIndex: number;                                        // beloch:statements[i].frame_index — index into scene.steps
  mark: Mark | null;                                          // present only for kind: "mark"
}
```

with:

```ts
export interface Statement {
  index: number;
  kind: "fold" | "mark";
  sourceLine: number;                                        // beloch:statements[i].source_line — always present (every stmt has a span)
  frameIndex: number;                                        // beloch:statements[i].frame_index — index into scene.steps
  mark: Mark | null;                                          // present only for kind: "mark"
  keptMarks: Mark[];                                          // beloch:statements[i].kept_marks — marks still dangling as of this statement (not yet graduated into a real crease)
}
```

- [ ] **Step 4: Parse `kept_marks` in `statementsFrom`**

In `packages/render-2d/scene/src/parse.ts`, replace lines 56-65:

```ts
function statementsFrom(fold: Record<string, unknown>): Statement[] {
  const raw = (fold["beloch:statements"] ?? []) as Record<string, unknown>[];
  return raw.map((s, index) => ({
    index,
    kind: s["kind"] as "fold" | "mark",
    sourceLine: s["source_line"] as number,
    frameIndex: s["frame_index"] as number,
    mark: s["mark"] ? markFrom(s["mark"] as Record<string, unknown>) : null,
  }));
}
```

with:

```ts
function statementsFrom(fold: Record<string, unknown>): Statement[] {
  const raw = (fold["beloch:statements"] ?? []) as Record<string, unknown>[];
  return raw.map((s, index) => ({
    index,
    kind: s["kind"] as "fold" | "mark",
    sourceLine: s["source_line"] as number,
    frameIndex: s["frame_index"] as number,
    mark: s["mark"] ? markFrom(s["mark"] as Record<string, unknown>) : null,
    keptMarks: ((s["kept_marks"] ?? []) as Record<string, unknown>[]).map(markFrom),
  }));
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/render-2d/scene && bun test test/parse.test.ts -t "kept_marks per statement"`
Expected: PASS.

- [ ] **Step 6: Run the full scene package test suite**

Run: `cd packages/render-2d/scene && bun test`
Expected: all pass, no regressions. The existing `"parseFold: statements
carries one entry per fold statement, source order"` test (`fold-quarter.fold`,
no `kept_marks` in its fixture) now gets `keptMarks: []` per statement via
the `?? []` default — it doesn't assert on `keptMarks` at all today, so no
update needed there.

- [ ] **Step 7: Typecheck**

Run: `cd packages/render-2d && bunx tsc -p tsconfig.json --noEmit`
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add packages/render-2d/scene/src/types.ts packages/render-2d/scene/src/parse.ts packages/render-2d/scene/test/parse.test.ts
git commit -m "feat(scene): parse kept_marks onto Statement.keptMarks"
```

---

### Task 4: `Playground.astro` — use `keptMarks` directly

**Files:**
- Modify: `packages/www/src/components/Playground.astro:505-516` (`renderStep`)

**Interfaces:**
- Consumes: `Statement.keptMarks : Mark[]` (Task 3), `MarkOverlay` (unchanged, from the prior `2026-07-20-playground-cumulative-marks-design.md`).
- Produces: nothing consumed by later tasks (last task in this plan).

- [ ] **Step 1: Replace the client-side accumulation with `stmt.keptMarks`**

In `packages/www/src/components/Playground.astro`, replace lines 505-516:

```ts
      try {
        const activeMarks = currentStatements
          .slice(0, clamped + 1)
          .filter((s) => s.kind === "mark" && s.mark !== null)
          .map((s) => s.mark!);
        const newestCreaseId = activeMarks.at(-1)?.creaseId;
        const svg = renderFolded(currentScene, {
          theme: WEB_THEME,
          step: String(stmt.frameIndex),
          markOverlay: activeMarks.length > 0 ? { marks: activeMarks, newestCreaseId } : undefined,
        }).toString();
        showSvg(svg);
      } catch (err) {
        showError(`Render-Fehler: ${err instanceof Error ? err.message : String(err)}`);
        return;
      }
```

with:

```ts
      try {
        const activeMarks = stmt.keptMarks;
        const newestCreaseId = activeMarks.at(-1)?.creaseId;
        const svg = renderFolded(currentScene, {
          theme: WEB_THEME,
          step: String(stmt.frameIndex),
          markOverlay: activeMarks.length > 0 ? { marks: activeMarks, newestCreaseId } : undefined,
        }).toString();
        showSvg(svg);
      } catch (err) {
        showError(`Render-Fehler: ${err instanceof Error ? err.message : String(err)}`);
        return;
      }
```

- [ ] **Step 2: Typecheck**

Run: `cd packages/www && bunx astro check`
Expected: same 5 pre-existing errors as baseline (`runBtn` possibly-null ×2 in this same file, `beloch-figure.ts` HTMLElement conflict ×3 — unrelated, do not fix as part of this task) — no *new* errors introduced by this change.

- [ ] **Step 3: Rebuild the core evaluator's wasm/JS bundle the Playground actually runs**

`packages/www/public/beloch/beloch-eval.js` is a **committed, pre-built**
js_of_ocaml bundle — it does not pick up the `eval.ml`/`fold_emit.ml`
changes from Tasks 1-2 automatically (confirmed by the exact same gotcha
hitting the prior statement-sourcemap work, commit `a96af6e`). Run:

```bash
packages/www/scripts/build-eval.sh
```

Expected: `Wrote packages/www/public/beloch/beloch-eval.js (...)`. Without
this, the browser runs the OLD evaluator (no `kept_marks` in its output)
against the NEW client code in Step 4 below.

Commit the rebuilt artifact on its own, matching the established precedent
(`a96af6e build(www): rebuild eval-worker bundle for beloch:statements`):

```bash
git add packages/www/public/beloch/beloch-eval.js
git commit -m "build(www): rebuild eval-worker bundle for kept_marks"
```

- [ ] **Step 4: Manual browser verification with the exact bug repro**

Run: `cd packages/www && bun run dev` (reuses the already-running dev server if one is up on port 4321 — check with `curl -s localhost:4321/ -o /dev/null -w "%{http_code}"` first)

Paste this exact program (the session's original bug report) into the Playground:

```
paper square

mark --diag = through .a .c
mark --ea = map --ab onto --diag
mark --eb = map --ab onto --bc
mark --ec = map --bc onto --diag

flatten (--ea & .a) (--ec & .c) (--eb & .b) {toward .a}
fold map .d onto .b
```

Run it, then:
1. Scrub through steps 0-3 (the four `mark` statements) — confirm marks accumulate and the newest is highlighted (indigo, thicker), same as before.
2. Scrub to step 4 (`flatten`) — confirm **no** mark overlay is drawn (all four graduated) — this is the bug fix; previously `--ec` stayed highlighted here.
3. Scrub to step 5 (final `fold`) — confirm still no mark overlay.
4. Scrub back to step 3 — confirm the marks reappear (stateless recompute, no stale leftover from having visited step 4/5).

- [ ] **Step 5: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "fix(playground): use evaluator-computed keptMarks, fixes stuck mark highlight"
```

---

## Self-Review Notes

- **Spec coverage:** `Fold_state.mark_graduates` extraction (Task 1), `sl_kept` population for both statement kinds (Task 2, Steps 4-5), `kept_marks` JSON field (Task 2, Step 6), `Statement.keptMarks` parsing (Task 3), Playground simplification (Task 4) — every design section has a task. The spec's "Out of scope" section (no `file_frames`/`beloch:marks`-per-frame changes) is respected — no task touches `folded_frame_of_state`.
- **Type consistency:** `Fold_state.mark_graduates : t -> mark -> bool` (Task 1) is the exact signature used in Task 2's `push_frame` and `cp_display` refactor. `sl_kept : Fold_state.mark list` (Task 2) → `kept_marks` JSON array of `mark_json`-shaped objects → `Statement.keptMarks : Mark[]` (Task 3) → consumed as `stmt.keptMarks` (Task 4) — one field, one shape, traced end to end.
- **No placeholders:** every step has literal OCaml/TS diffs; Task 3 Step 1 asks the implementer to locate the existing test file rather than guess its name/path — this is a discovery step, not a placeholder, since the exact file wasn't confirmed during planning (avoids hardcoding a wrong path).
- **Bundle-rebuild gotcha called out explicitly** (Task 4, Step 3) — the prior session's git history shows this exact class of mistake already happened once (`a96af6e build(www): rebuild eval-worker bundle for beloch:statements`), so it's flagged as its own step rather than assumed.
