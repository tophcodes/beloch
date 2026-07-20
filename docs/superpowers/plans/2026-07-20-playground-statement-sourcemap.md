# Playground Statement Sourcemap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Playground step player so `mark` statements are
navigable alongside `fold`/`flatten` statements, with the mark's own
geometry (as it existed at that point in the program, before any later
graduation into a real crease) overlaid on the folded picture.

**Architecture:** A new OCaml-emitted `beloch:statements` JSON channel
enumerates every fold- or mark-producing top-level statement in source
order, each entry carrying its own source line, which `file_frames` index
its geometry backdrop reads against, and — for marks — the mark's own
geometry embedded directly (not a lookup into the separately-filtered
`beloch:marks` array, which only reflects the *final* program state and
would be empty or wrong for a mark that later gets folded along). `@beloch/scene`
parses this into `FoldScene.statements: Statement[]`. `@beloch/render-svg`
gets a new `markOverlay` option on `renderFolded` that projects one mark's
paper-space geometry onto a folded step's faces (reusing the existing
ghost-overlay face-projection technique). The Playground's scrubber switches
from iterating `scene.steps` to `scene.statements`.

**Tech Stack:** OCaml (`packages/core/lib`), Alcotest (`packages/core/tests`),
TypeScript (`@beloch/scene`, `@beloch/render-svg`), `bun:test`, Astro
component script (`packages/www`).

## Global Constraints

- `beloch:statements` is additive — `file_frames` and `beloch:marks` are
  unchanged in shape and content. Every existing consumer (`<Beloch>`,
  `<beloch-figure>`, `scene.steps`) keeps working exactly as before.
- A mark statement's embedded geometry reflects **the mark as recorded at
  that statement** — independent of whether it later graduates into a real
  crease. This was verified empirically during design: a two-mark,
  one-fold source produces an *empty* `beloch:marks` (both marks graduate
  trivially — their endpoints are paper corners) while
  `beloch:statements` still carries both marks' full geometry. Do not
  "fix" this by looking marks up in `beloch:marks` instead — that was the
  bug this design specifically avoids.
- `renderFolded`'s `markOverlay` option is additive — omitting it must be a
  100% no-op for every existing caller (`<Beloch>`, `<beloch-figure>`, the
  Playground's own fold-statement clicks).
- The CM6 gutter marker module (`packages/www/src/lib/cm-step-marker.ts`,
  shipped 2026-07-19) needs **zero changes** — it only consumes a
  `sourceLine: number | null`, which `Statement` already provides
  uniformly for both kinds.
- Scrubber dots stay visually uniform between mark-steps and fold-steps —
  no distinct styling (explicit prior decision, unchanged).

---

### Task 1: OCaml — `beloch:statements` emission

**Files:**
- Modify: `packages/core/lib/eval.ml`
- Modify: `packages/core/lib/fold_emit.ml`
- Modify: `packages/core/tests/test_e2e.ml`

**Interfaces:**
- Produces: `Eval.stmt_kind = SFold | SMark`,
  `Eval.stmt_log_entry = { sl_kind; sl_span : Error.span; sl_frame_index : int;
  sl_mark : Fold_state.mark option }`, and `Eval.folded.statements : stmt_log_entry list`
  (new field on the existing `folded` record). `Fold_emit.mark_json : Fold_state.mark -> Yojson.Safe.t`
  (extracted, reused by both `beloch:marks` and `beloch:statements`).
  JSON shape: `"beloch:statements": [{ "kind": "fold"|"mark", "source_line": int,
  "frame_index": int, "mark": null | {kind, a/b|p, line, intent, crease_id} }]`.

This task's code was prototyped and empirically verified against the real
evaluator during design (compiled clean, tested against multi-mark/fold
sources, frame indices cross-checked against `file_frames` byte-for-byte).
Transcribe it exactly.

- [ ] **Step 1: Add the statement-log types and thread them through `ctx`/`snapshot`**

In `packages/core/lib/eval.ml`, find:

```ocaml
type folded = {
  state : Fold_state.t;
  named_points : (string * Geom.point * int) list;
      (* [int] is the 0-based creation step (index into [frames] at bind
         time); see [scope.point_steps]/[scope.line_steps] *)
  named_lines : (string * Geom.line * int) list;
  named_line_cids : (string * int) list;
      (* crease id per name for [Material]/[Mark] creases — the identity the
         line coefficients in [named_lines] lose (a folded crease's current
         line can coincide with another crease's line) *)
  frames : (string option * Fold_state.t * Error.span option) list;
}
```

Replace with:

```ocaml
type stmt_kind = SFold | SMark

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

type folded = {
  state : Fold_state.t;
  named_points : (string * Geom.point * int) list;
      (* [int] is the 0-based creation step (index into [frames] at bind
         time); see [scope.point_steps]/[scope.line_steps] *)
  named_lines : (string * Geom.line * int) list;
  named_line_cids : (string * int) list;
      (* crease id per name for [Material]/[Mark] creases — the identity the
         line coefficients in [named_lines] lose (a folded crease's current
         line can coincide with another crease's line) *)
  frames : (string option * Fold_state.t * Error.span option) list;
  statements : stmt_log_entry list;
}
```

Find (the `ctx` record):

```ocaml
  mutable frames_rev : (string option * Fold_state.t * Error.span option) list;
```

Replace with:

```ocaml
  mutable frames_rev : (string option * Fold_state.t * Error.span option) list;
  mutable statements_rev : stmt_log_entry list;
```

Find (the `snapshot` record — the incremental-eval-cache's per-statement
snapshot, must carry the new field or a `resume` silently drops/duplicates
statement-log entries):

```ocaml
  s_frames_rev : (string option * Fold_state.t * Error.span option) list;
```

Replace with:

```ocaml
  s_frames_rev : (string option * Fold_state.t * Error.span option) list;
  s_statements_rev : stmt_log_entry list;
```

Find (inside `snapshot ctx`):

```ocaml
        s_frames_rev = ctx.frames_rev;
```

Replace with:

```ocaml
        s_frames_rev = ctx.frames_rev;
        s_statements_rev = ctx.statements_rev;
```

Find (inside `restore ctx s`):

```ocaml
      ctx.frames_rev <- s.s_frames_rev;
```

Replace with:

```ocaml
      ctx.frames_rev <- s.s_frames_rev;
      ctx.statements_rev <- s.s_statements_rev;
```

- [ ] **Step 2: Initialize the accumulator and log fold-producing statements in `push_frame`**

Find (inside `eval_program`, the `ctx` construction and `push_frame`):

```ocaml
    frames_rev = [];
    pending = true;
  } in
  let push_frame (span : Error.span option) =
    ctx.frames_rev <- (ctx.panel, !(ctx.state), span) :: ctx.frames_rev;
    ctx.pending <- false
```

Replace with:

```ocaml
    frames_rev = [];
    statements_rev = [];
    pending = true;
  } in
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
```

(`push_frame None` is the plain `step left`/`step right` marker — no span,
not logged as a statement. Every `push_frame (Some span)` call site — three
for `Ast.Fold`, one for `Ast.Flatten` — is covered by this one change,
since they all funnel through `push_frame`.)

- [ ] **Step 3: Log mark-producing statements in the `record` helper**

Find (inside `eval_stmt`'s `Ast.Mark` case):

```ocaml
        let record ~prov cid mgeom paper_axis =
          ctx.state :=
            Fold_state.add_mark !(ctx.state)
              { Fold_state.mgeom; mline = paper_axis; mintent = intent;
                mcrease_id = cid; mprov = prov };
          bind_mark cid paper_axis
        in
```

Replace with:

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

(`span` is the `Ast.Mark (name_opt, m, ext, dir, layer_opt, span)` match
arm's own span, in scope here regardless of which operand kind —
`` `Fresh `` or `` `Existing `` — the statement resolves to; this `record`
helper is the single funnel every mark-creation path goes through, so one
edit covers all of them.)

- [ ] **Step 4: Return the accumulated statement log from `eval_program`**

Find:

```ocaml
  let frames = List.rev ctx.frames_rev in
  { state = !(ctx.state); named_points; named_lines; named_line_cids; frames }
```

Replace with:

```ocaml
  let frames = List.rev ctx.frames_rev in
  let statements = List.rev ctx.statements_rev in
  { state = !(ctx.state); named_points; named_lines; named_line_cids; frames; statements }
```

- [ ] **Step 5: Build and confirm no compile errors**

Run: `dune build`
Expected: no output, exit 0.

- [ ] **Step 6: Extract a shared `mark_json` serializer in `fold_emit.ml`**

In `packages/core/lib/fold_emit.ml`, find:

```ocaml
let q_to_json (x : Num.t) : Yojson.Safe.t = `Float (Num.to_float x)
```

Replace with:

```ocaml
let q_to_json (x : Num.t) : Yojson.Safe.t = `Float (Num.to_float x)

let mark_assign_str = function
  | Fold_state.M -> "M"
  | Fold_state.V -> "V"
  | Fold_state.F -> "F"

(* One `beloch:marks`-shaped entry — shared by the global (final-state) list
   and each statement-log entry's embedded as-recorded mark. *)
let mark_json (m : Fold_state.mark) : Yojson.Safe.t =
  let line =
    let l = m.Fold_state.mline in
    `List [ q_to_json l.Geom.a; q_to_json l.Geom.b; q_to_json l.Geom.c ]
  in
  let common =
    [
      ("line", line);
      ("intent", `String (mark_assign_str m.Fold_state.mintent));
      ("crease_id", `Int m.Fold_state.mcrease_id);
    ]
  in
  match m.Fold_state.mgeom with
  | Fold_state.MSeg (a, b) ->
      `Assoc
        (("kind", `String "seg")
        :: ("a", `List [ q_to_json a.Geom.x; q_to_json a.Geom.y ])
        :: ("b", `List [ q_to_json b.Geom.x; q_to_json b.Geom.y ])
        :: common)
  | Fold_state.MPoint p ->
      `Assoc
        (("kind", `String "point")
        :: ("p", `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
        :: common)
```

- [ ] **Step 7: Simplify the existing `beloch_marks` builder to use it**

Find (inside `to_json_folded`):

```ocaml
  (* record marks (non-subdividing; see Fold_state.mark) — a mark's intent is
     only ever M or V (never F: F is a folded-form dihedral, not a
     crease-pattern colour), but match totally rather than special-casing. *)
  let mark_assign_str = function
    | Fold_state.M -> "M"
    | Fold_state.V -> "V"
    | Fold_state.F -> "F"
  in
  let beloch_marks =
    kept_marks
    |> List.map (fun (m : Fold_state.mark) ->
        let line =
          let l = m.Fold_state.mline in
          `List [ q_to_json l.Geom.a; q_to_json l.Geom.b; q_to_json l.Geom.c ]
        in
        let common =
          [
            ("line", line);
            ("intent", `String (mark_assign_str m.Fold_state.mintent));
            ("crease_id", `Int m.Fold_state.mcrease_id);
          ]
        in
        match m.Fold_state.mgeom with
        | Fold_state.MSeg (a, b) ->
            `Assoc
              (("kind", `String "seg")
              :: ("a", `List [ q_to_json a.Geom.x; q_to_json a.Geom.y ])
              :: ("b", `List [ q_to_json b.Geom.x; q_to_json b.Geom.y ])
              :: common)
        | Fold_state.MPoint p ->
            `Assoc
              (("kind", `String "point")
              :: ("p", `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
              :: common))
  in
```

Replace with:

```ocaml
  (* record marks (non-subdividing; see Fold_state.mark) *)
  let beloch_marks = kept_marks |> List.map mark_json in
```

- [ ] **Step 8: Add the `beloch:statements` builder and wire it in**

Find (right before `let to_json_folded (fd : Eval.folded) : Yojson.Safe.t =`):

```ocaml
let to_json_folded (fd : Eval.folded) : Yojson.Safe.t =
  let disp, kept_marks = cp_display fd.Eval.state in
```

Replace with:

```ocaml
(* One entry per fold- or mark-producing top-level statement, in source
   order — a statement-level sourcemap for the Playground step player. A
   mark statement embeds its OWN mark geometry as recorded at that point,
   independent of whether it later graduates into a real crease (which only
   ever happens at some LATER fold statement) — see
   docs/superpowers/specs/2026-07-20-playground-statement-sourcemap-design.md. *)
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

let to_json_folded (fd : Eval.folded) : Yojson.Safe.t =
  let disp, kept_marks = cp_display fd.Eval.state in
```

Find:

```ocaml
      ("beloch:marks", `List beloch_marks);
```

Replace with:

```ocaml
      ("beloch:marks", `List beloch_marks);
      ("beloch:statements", beloch_statements_json fd.Eval.statements);
```

- [ ] **Step 9: Build again**

Run: `dune build`
Expected: no output, exit 0.

- [ ] **Step 10: Write the test**

Scope note: this test exercises the `` `Fresh `` mark-operand path (a mark
built from a fresh axiom construction, e.g. `map .a onto .c`). The design
investigation also confirmed — by reading `eval.ml`'s `Ast.Mark` handler
directly, not by running it — that `span` is bound unconditionally at the
top of that match arm regardless of operand kind, so the `` `Existing ``
path (marking a reference to an already-bound line) needs no special-casing
and is covered by the same code change. Finding valid `.bel` syntax that
reaches the `` `Existing `` branch (attempts during design hit unrelated
syntax errors) is a nice-to-have follow-up test, not a blocker for this task.

In `packages/core/tests/test_e2e.ml`, add this test function near
`test_multiframe` (same file, same style — uses `Beloch.fold_string` +
`Yojson.Safe.Util`):

```ocaml
(* Statement-level sourcemap for the Playground step player: one
   beloch:statements entry per mark/fold statement, each mark embedding its
   OWN geometry — even when both marks in this source graduate into real
   creases by the end (their endpoints are paper corners), so beloch:marks
   is empty while beloch:statements still carries their geometry. *)
let test_beloch_statements () =
  let src =
    "paper square\n\
     mark --diag = map .a onto .c\n\
     mark --ray = through .a .c\n\
     fold map .b onto .d\n"
  in
  let json = Beloch.fold_string ~filename:"t" src in
  let open Yojson.Safe.Util in
  let stmts = json |> member "beloch:statements" |> to_list in
  Alcotest.(check int) "one entry per mark/fold statement" 3 (List.length stmts);
  let kind_of j = j |> member "kind" |> to_string in
  Alcotest.(check (list string)) "kinds in source order"
    [ "mark"; "mark"; "fold" ] (List.map kind_of stmts);
  let line_of j = j |> member "source_line" |> to_int in
  Alcotest.(check (list int)) "source lines"
    [ 2; 3; 4 ] (List.map line_of stmts);
  let frame_of j = j |> member "frame_index" |> to_int in
  Alcotest.(check (list int))
    "marks before any fold read frame 0 (the flat sheet); the fold itself \
     reads frame 1 (its own just-pushed frame)"
    [ 0; 0; 1 ] (List.map frame_of stmts);
  let mark_present j = j |> member "mark" <> `Null in
  Alcotest.(check (list bool)) "both marks carry embedded geometry, the fold does not"
    [ true; true; false ] (List.map mark_present stmts);
  (* the bug this design avoids: both marks graduate (their endpoints are
     corners), so the global list is empty — but the statement log is
     unaffected, since it embeds geometry at record time, not by lookup. *)
  let global_marks = json |> member "beloch:marks" |> to_list in
  Alcotest.(check int) "both marks graduate — beloch:marks is empty" 0
    (List.length global_marks)
```

- [ ] **Step 11: Register the test**

Find (inside the `Alcotest.run "beloch-e2e"` call's `"e2e"` group list, near
the `test_multiframe` registration):

```ocaml
          Alcotest.test_case "one folded frame per step" `Quick
            test_multiframe;
```

Replace with:

```ocaml
          Alcotest.test_case "one folded frame per step" `Quick
            test_multiframe;
          Alcotest.test_case "beloch:statements sourcemap" `Quick
            test_beloch_statements;
```

- [ ] **Step 12: Run the test to verify it passes**

Run: `dune exec packages/core/tests/test_e2e.exe -- test e2e`
Expected: all cases pass, including `beloch:statements sourcemap`, no
failures (baseline is 30/30 passing before this change; expect 31/31 after).

- [ ] **Step 13: Commit**

```bash
git add packages/core/lib/eval.ml packages/core/lib/fold_emit.ml packages/core/tests/test_e2e.ml
git commit -m "feat(core): emit beloch:statements — per-statement sourcemap for marks+folds"
```

---

### Task 2: `@beloch/scene` — `Statement` type + parser

**Files:**
- Modify: `packages/render-2d/scene/src/types.ts`
- Modify: `packages/render-2d/scene/src/parse.ts`
- Test: `packages/render-2d/scene/test/parse.test.ts` (existing file —
  check its exact name via `ls packages/render-2d/scene/test/` if this
  doesn't match; add to whichever file already tests `parseFold`)

**Interfaces:**
- Consumes: `beloch:statements` JSON (Task 1) — `{ kind: "fold"|"mark",
  source_line: number, frame_index: number, mark: null | {kind, a/b|p, line,
  intent, crease_id} }[]`.
- Produces: `Statement` type and `FoldScene.statements: Statement[]`.

- [ ] **Step 1: Add the `Statement` type**

In `packages/render-2d/scene/src/types.ts`, find:

```ts
export interface Step {
  index: number;                                             // position in file_frames
  label: string | null;                                      // beloch:step
  sourceLine: number | null;                                 // beloch:source_line
  frame: Frame;                                              // self-contained (merged over root)
}
```

Add right after it:

```ts
// beloch:statements — one entry per fold- or mark-producing top-level
// statement, source order. A mark entry embeds its OWN mark geometry as
// recorded at that statement (not a beloch:marks lookup — a mark that
// later graduates into a real crease is dropped from beloch:marks, but its
// Statement.mark here is unaffected). See
// docs/superpowers/specs/2026-07-20-playground-statement-sourcemap-design.md.
export interface Statement {
  index: number;
  kind: "fold" | "mark";
  sourceLine: number;                                        // beloch:statements[i].source_line — always present (every stmt has a span)
  frameIndex: number;                                        // beloch:statements[i].frame_index — index into scene.steps
  mark: Mark | null;                                          // present only for kind: "mark"
}
```

Find:

```ts
export interface FoldScene {
  cp: Frame;
  steps: Step[];                                             // one per foldedForm frame, file order
  namedPoints: NamedPoint[];
  namedLines: NamedLine[];
  creases: Crease[];                                         // grouped by provenance name on the CP frame
  marks: Mark[];                                              // beloch:marks, paper-space, CP frame only
}
```

Replace with:

```ts
export interface FoldScene {
  cp: Frame;
  steps: Step[];                                             // one per foldedForm frame, file order
  statements: Statement[];                                   // one per fold/mark statement, source order
  namedPoints: NamedPoint[];
  namedLines: NamedLine[];
  creases: Crease[];                                         // grouped by provenance name on the CP frame
  marks: Mark[];                                              // beloch:marks, paper-space, CP frame only
}
```

- [ ] **Step 2: Parse `beloch:statements`, reusing a shared mark parser**

In `packages/render-2d/scene/src/parse.ts`, find:

```ts
import {
  Assignment, Crease, EdgeProvenance, FoldScene, Frame, LineCoeffs,
  Mark, NamedLine, NamedPoint, SceneError, Step, StepNotFoundError, Vec2,
} from "./types";
```

Replace with:

```ts
import {
  Assignment, Crease, EdgeProvenance, FoldScene, Frame, LineCoeffs,
  Mark, NamedLine, NamedPoint, SceneError, Statement, Step, StepNotFoundError, Vec2,
} from "./types";
```

Find:

```ts
function marksFrom(fold: Record<string, unknown>): Mark[] {
  const raw = (fold["beloch:marks"] ?? []) as Record<string, unknown>[];
  return raw.map((m): Mark => {
    const line = m["line"] as LineCoeffs;
    const intent = m["intent"] as Assignment;
    const creaseId = m["crease_id"] as number;
    return m["kind"] === "seg"
      ? { kind: "seg", a: m["a"] as Vec2, b: m["b"] as Vec2, line, intent, creaseId }
      : { kind: "point", p: m["p"] as Vec2, line, intent, creaseId };
  });
}
```

Replace with:

```ts
function markFrom(m: Record<string, unknown>): Mark {
  const line = m["line"] as LineCoeffs;
  const intent = m["intent"] as Assignment;
  const creaseId = m["crease_id"] as number;
  return m["kind"] === "seg"
    ? { kind: "seg", a: m["a"] as Vec2, b: m["b"] as Vec2, line, intent, creaseId }
    : { kind: "point", p: m["p"] as Vec2, line, intent, creaseId };
}

function marksFrom(fold: Record<string, unknown>): Mark[] {
  const raw = (fold["beloch:marks"] ?? []) as Record<string, unknown>[];
  return raw.map(markFrom);
}

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

Find:

```ts
  return { cp, steps, namedPoints, namedLines, creases: groupCreases(cp), marks: marksFrom(fold) };
```

Replace with:

```ts
  return {
    cp, steps, statements: statementsFrom(fold), namedPoints, namedLines,
    creases: groupCreases(cp), marks: marksFrom(fold),
  };
```

- [ ] **Step 3: Find the existing parser test file**

Run: `ls packages/render-2d/scene/test/`
Note the file that tests `parseFold` (likely `parse.test.ts`) and the
fixture-loading convention it uses (likely `Bun.file(new URL("./fixtures/...",
import.meta.url)).text()`, matching `packages/www/src/lib/beloch-figure.test.ts`'s
convention).

- [ ] **Step 4: Write the test**

Add to that test file (adjust the import path / fixture-loading style to
match what Step 3 found — this fixture, `fold-quarter.fold`, already exists
per `packages/www/src/lib/beloch-figure.test.ts`'s comment: "fold-quarter.bel
is `; status …\npaper square\nfold …\nfold …\n` (4 lines) — its two folded
steps carry beloch:source_line 3 and 4"):

```ts
test("parseFold: statements carries one entry per fold statement, source order", async () => {
  const raw = await Bun.file(
    new URL("../../../www/src/lib/fixtures/fold-quarter.fold", import.meta.url),
  ).text();
  const scene = parseFold(raw);
  expect(scene.statements.length).toBe(2);
  expect(scene.statements.map((s) => s.kind)).toEqual(["fold", "fold"]);
  expect(scene.statements.map((s) => s.sourceLine)).toEqual([3, 4]);
  expect(scene.statements.every((s) => s.mark === null)).toBe(true);
});
```

If Step 3 shows a different fixture-path convention for this package
(e.g. its own local `fixtures/` directory rather than reaching into
`packages/www`), use that instead — adjust the relative path, keep the
assertions.

- [ ] **Step 5: Run the tests**

Run: `cd packages/render-2d && bun test`
Expected: all tests pass (baseline 83/83 before this change; expect 84/84
after), no failures.

- [ ] **Step 6: Commit**

```bash
git add packages/render-2d/scene/src/types.ts packages/render-2d/scene/src/parse.ts packages/render-2d/scene/test/
git commit -m "feat(scene): parse beloch:statements into FoldScene.statements"
```

---

### Task 3: `@beloch/render-svg` — `markOverlay` on `renderFolded`

**Files:**
- Modify: `packages/render-2d/render-svg/src/render-scene.ts`
- Modify: `packages/render-2d/render-svg/src/render-folded.ts`
- Test: `packages/render-2d/render-svg/test/` (find the existing
  `renderFolded` test file the same way as Task 2 Step 3 — `ls
  packages/render-2d/render-svg/test/`)

**Interfaces:**
- Consumes: `Statement.mark: Mark | null` (Task 2).
- Produces: `renderFolded(scene, { ..., markOverlay?: Mark })` — draws
  exactly that one mark, projected onto the rendered step's faces. Omitting
  it is a no-op (existing behavior unchanged).

- [ ] **Step 1: Add `markOverlay` to `SceneOptions` and draw it in the occluded branch**

In `packages/render-2d/render-svg/src/render-scene.ts`, find:

```ts
import type { FoldScene, Vec2 } from "@beloch/scene";
import { createDoc, el, SvgDoc, SvgNode } from "./svgdoc";
import { DEFAULT_THEME, Theme, LineStyle } from "./theme";
import { makeLayout } from "./layout";
import { appendConstructions, appendLegend, appendTitle } from "./constructions";
import { coveredIntervals, faceEdgeIndex, sideUp, lineToFace, clipLineToPoly, pointCovered } from "./geometry";
import { resolveIsometry, type Isometry } from "./isometry";
import { placeLabels, type LabelAnchor } from "./primitives/labels";
```

Replace with:

```ts
import type { FoldScene, Mark, Vec2 } from "@beloch/scene";
import { createDoc, el, SvgDoc, SvgNode } from "./svgdoc";
import { DEFAULT_THEME, Theme, LineStyle } from "./theme";
import { makeLayout } from "./layout";
import { appendConstructions, appendLegend, appendTitle } from "./constructions";
import { coveredIntervals, faceEdgeIndex, sideUp, lineToFace, clipLineToPoly, pointCovered, pointInPolygon } from "./geometry";
import { resolveIsometry, type Isometry } from "./isometry";
import { placeLabels, type LabelAnchor } from "./primitives/labels";
```

Find:

```ts
export interface SceneOptions {
  isometry: Isometry;
  texture: TextureOptions;
  title?: string;
  labels?: string[]; // construction overlay selection: ["--v", ".p"]
  legend?: boolean;
  theme?: Partial<Theme>;
  view?: "top" | "bottom"; // folded only
  hidden?: "dashed" | "hide"; // folded only
}
```

Replace with:

```ts
export interface SceneOptions {
  isometry: Isometry;
  texture: TextureOptions;
  title?: string;
  labels?: string[]; // construction overlay selection: ["--v", ".p"]
  legend?: boolean;
  theme?: Partial<Theme>;
  view?: "top" | "bottom"; // folded only
  hidden?: "dashed" | "hide"; // folded only
  markOverlay?: Mark; // folded only — project this one mark onto the step's faces
}
```

Find (the end of the occluded branch — right before `appendConstructions`
closes it out):

```ts
    for (const lab of placeLabels(labelAnchors, { fontSize: 17 })) {
      const buried = occludedNames.has(lab.keys[0]!);
      const attrs: Record<string, string | number> = {
        x: lab.x, y: lab.y, "font-size": 17, "font-weight": 600,
        fill: buried ? MUTED : theme.ink,
        "data-bel-name": lab.keys[0]!, "data-kind": "point-label",
      };
      if (buried) attrs["data-occluded"] = "true";
      if (lab.anchor !== "start") attrs["text-anchor"] = lab.anchor;
      annotations.children.push(el("text", attrs, [], lab.text));
    }

    appendConstructions(doc, scene, layout, theme, opts.labels, { frame });
  } else {
```

Replace with:

```ts
    for (const lab of placeLabels(labelAnchors, { fontSize: 17 })) {
      const buried = occludedNames.has(lab.keys[0]!);
      const attrs: Record<string, string | number> = {
        x: lab.x, y: lab.y, "font-size": 17, "font-weight": 600,
        fill: buried ? MUTED : theme.ink,
        "data-bel-name": lab.keys[0]!, "data-kind": "point-label",
      };
      if (buried) attrs["data-occluded"] = "true";
      if (lab.anchor !== "start") attrs["text-anchor"] = lab.anchor;
      annotations.children.push(el("text", attrs, [], lab.text));
    }

    // Mark overlay: project one mark's paper-space geometry onto whichever
    // face it lands on, via that face's own isometry — same paper->table
    // technique as the ghost-overlay above, but for a bounded mark segment
    // (known endpoints) rather than an infinite named line, so this tests
    // point-in-polygon membership directly instead of clipping.
    if (opts.markOverlay) {
      const m = opts.markOverlay;
      const FM = frame.facesMatrix ?? [];
      const applyIso = ([m00, m01, m10, m11, ox, oy]: Isometry, p: Vec2): Vec2 =>
        [m00 * p[0] + m01 * p[1] + ox, m10 * p[0] + m11 * p[1] + oy];
      const style = theme.lineStyle(m.intent, theme);
      const markAttrs = {
        stroke: style.stroke,
        "stroke-width": Math.max(1, style.strokeWidth - 1),
        "stroke-dasharray": "2 2",
        "stroke-linecap": "round" as const,
        opacity: 0.7,
        "data-crease-id": m.creaseId,
      };
      for (let fi = 0; fi < F.length; fi++) {
        const M = FM[fi];
        if (!M) continue;
        const tabPoly = F[fi]!.map((idx) => V[idx]!);
        if (m.kind === "seg") {
          const pa = applyIso(M, m.a), pb = applyIso(M, m.b);
          if (!pointInPolygon(pa, tabPoly) || !pointInPolygon(pb, tabPoly)) continue;
          creases.children.push(el("line", {
            ...markAttrs, class: "mark", "data-kind": "mark",
            x1: mx(pa[0]), y1: ty(pa[1]), x2: mx(pb[0]), y2: ty(pb[1]),
          }));
        } else {
          const pp = applyIso(M, m.p);
          if (!pointInPolygon(pp, tabPoly)) continue;
          const TICK = 0.03;
          const [la, lb] = m.line;
          const norm = Math.hypot(lb, -la) || 1;
          const dx = lb / norm, dy = -la / norm;
          const p0 = applyIso(M, [m.p[0] - dx * TICK, m.p[1] - dy * TICK]);
          const p1 = applyIso(M, [m.p[0] + dx * TICK, m.p[1] + dy * TICK]);
          creases.children.push(el("line", {
            ...markAttrs, class: "mark", "data-kind": "mark-tick",
            x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
          }));
        }
        break; // a mark belongs to exactly one face
      }
    }

    appendConstructions(doc, scene, layout, theme, opts.labels, { frame });
  } else {
```

- [ ] **Step 2: Thread the option through `renderFolded`**

In `packages/render-2d/render-svg/src/render-folded.ts`, find:

```ts
import type { FoldScene } from "@beloch/scene";
import { pickStep, SceneError } from "@beloch/scene";
import { SvgDoc } from "./svgdoc";
import { renderScene } from "./render-scene";
import type { RenderOptions } from "./render-cp";

export interface FoldedOptions extends RenderOptions {
  view?: "top" | "bottom";     // default "top"
  hidden?: "dashed" | "hide";  // default "hide"
  step?: string;               // beloch:step label; undefined/unmatched → final state
}

export function renderFolded(scene: FoldScene, opts: FoldedOptions = {}): SvgDoc {
  const step = pickStep(scene, opts.step);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  return renderScene(scene, {
    isometry: { kind: "step", index: step.index },
    texture: {
      upToStep: step.index,
      creases: true,
      marks: false,
      points: true,
      lines: true,
      faces: "filled",
    },
    view: opts.view,
    hidden: opts.hidden,
    title: opts.title,
    labels: opts.labels,
    legend: opts.legend,
    theme: opts.theme,
  });
}
```

Replace with:

```ts
import type { FoldScene, Mark } from "@beloch/scene";
import { pickStep, SceneError } from "@beloch/scene";
import { SvgDoc } from "./svgdoc";
import { renderScene } from "./render-scene";
import type { RenderOptions } from "./render-cp";

export interface FoldedOptions extends RenderOptions {
  view?: "top" | "bottom";     // default "top"
  hidden?: "dashed" | "hide";  // default "hide"
  step?: string;               // beloch:step label; undefined/unmatched → final state
  markOverlay?: Mark;          // project this one mark onto the step's faces
}

export function renderFolded(scene: FoldScene, opts: FoldedOptions = {}): SvgDoc {
  const step = pickStep(scene, opts.step);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  return renderScene(scene, {
    isometry: { kind: "step", index: step.index },
    texture: {
      upToStep: step.index,
      creases: true,
      marks: false,
      points: true,
      lines: true,
      faces: "filled",
    },
    view: opts.view,
    hidden: opts.hidden,
    title: opts.title,
    labels: opts.labels,
    legend: opts.legend,
    theme: opts.theme,
    markOverlay: opts.markOverlay,
  });
}
```

- [ ] **Step 3: Find the existing `renderFolded` test file**

Run: `ls packages/render-2d/render-svg/test/`

- [ ] **Step 4: Write the test**

Add to that file (match its existing fixture-loading convention — likely
loading one of `packages/www/src/lib/fixtures/*.fold` the same way Task 2's
test does, or a local fixture if this package has its own):

```ts
test("renderFolded: markOverlay draws exactly the given mark, omitting it changes nothing", async () => {
  const raw = await Bun.file(
    new URL("../../../www/src/lib/fixtures/fold-quarter.fold", import.meta.url),
  ).text();
  const scene = parseFold(raw);

  const withoutOverlay = renderFolded(scene, { theme: WEB_THEME }).toString();
  const withOverlayButNoMark = renderFolded(scene, { theme: WEB_THEME, markOverlay: undefined }).toString();
  expect(withOverlayButNoMark).toBe(withoutOverlay); // omitting is a true no-op

  const seg: Mark = {
    kind: "seg", a: [0, 0], b: [1, 1], line: [1, -1, 0], intent: "V", creaseId: 999,
  };
  const withOverlay = renderFolded(scene, { theme: WEB_THEME, markOverlay: seg }).toString();
  expect(withOverlay).toContain('data-crease-id="999"');
});
```

Adjust the fixture path and the exact `Mark` fixture values if
`fold-quarter.fold`'s geometry doesn't place `[0,0]`-`[1,1]` inside any face
of its final step (check by reading the fixture's `vertices_coords` — the
mark must land inside the actual folded polygon for the overlay to draw
anything at all, so the test's `expect(withOverlay).toContain(...)` needs a
segment that's genuinely inside a face; if the diagonal isn't, pick two
points that are, e.g. reading two of the fixture's own `vertices_coords`
entries and averaging them toward the centroid slightly inward).

- [ ] **Step 5: Run the tests**

Run: `cd packages/render-2d && bun test`
Expected: all tests pass, no failures.

- [ ] **Step 6: Commit**

```bash
git add packages/render-2d/render-svg/src/render-scene.ts packages/render-2d/render-svg/src/render-folded.ts packages/render-2d/render-svg/test/
git commit -m "feat(render-svg): markOverlay option on renderFolded"
```

---

### Task 4: Playground — statement-driven scrubber + mark overlay

**Files:**
- Modify: `packages/www/src/components/Playground.astro`

**Interfaces:**
- Consumes: `scene.statements: Statement[]` (Task 2), `renderFolded(scene,
  { step, markOverlay })` (Task 3).
- Produces: nothing new for later tasks — this is the last task.

This task generalizes the existing `renderStep`/`buildStepsUI`/`updateStepsUI`
(shipped 2026-07-19) from iterating `scene.steps` to iterating
`scene.statements`. The CM6 gutter marker wiring (`setStepLineOn`) is
unchanged — only what feeds it changes.

- [ ] **Step 1: Switch the `@beloch/scene` import to bring in `Statement`**

Find:

```ts
  import { parseFold, type FoldScene } from "@beloch/scene";
```

Replace with:

```ts
  import { parseFold, type FoldScene, type Statement } from "@beloch/scene";
```

- [ ] **Step 2: Rewrite the scrubber functions to work over statements**

Find (the three functions added 2026-07-19, plus the `let currentScene`
declaration just above them):

```ts
    let currentScene: FoldScene | null = null;
```

Replace with:

```ts
    let currentScene: FoldScene | null = null;
    let currentStatements: Statement[] = [];
```

Find:

```ts
    // Rebuilds the scrubber's dots for a freshly-parsed scene (called once
    // per successful run, not per step-click). Hides the bar entirely when
    // there's nothing to navigate (0 or 1 steps).
    function buildStepsUI(scene: FoldScene) {
      const n = scene.steps.length;
      stepDots!.innerHTML = "";
      if (n <= 1) {
        stepsBar!.hidden = true;
        return;
      }
      stepsBar!.hidden = false;
      for (let i = 0; i < n; i++) {
        const dot = document.createElement("button");
        dot.type = "button";
        dot.className = "pg-step-dot";
        dot.setAttribute("aria-label", `Step ${i + 1} von ${n}`);
        dot.setAttribute("aria-current", "false");
        dot.addEventListener("click", () => renderStep(i));
        stepDots!.appendChild(dot);
      }
    }

    // Cheap per-step-change update: toggles the active dot + label text,
    // without touching event listeners (buildStepsUI owns those).
    function updateStepsUI(i: number, scene: FoldScene) {
      stepDots!.querySelectorAll<HTMLButtonElement>(".pg-step-dot").forEach((dot, idx) => {
        dot.classList.toggle("is-active", idx === i);
        dot.setAttribute("aria-current", idx === i ? "true" : "false");
      });
      const step = scene.steps[i];
      stepLabel!.textContent = step?.label
        ? `Step ${i + 1}/${scene.steps.length} · ${step.label}`
        : `Step ${i + 1}/${scene.steps.length}`;
    }

    // Client-side-only re-render of one step of the already-parsed scene —
    // no worker round-trip, since one eval already returned every frame.
    function renderStep(i: number) {
      if (!currentScene) return;
      const n = currentScene.steps.length;
      const clamped = Math.max(0, Math.min(i, n - 1));
      const step = currentScene.steps[clamped]!;
      try {
        showSvg(renderFolded(currentScene, { theme: WEB_THEME, step: String(clamped) }).toString());
      } catch (err) {
        showError(`Render-Fehler: ${err instanceof Error ? err.message : String(err)}`);
        return;
      }
      setStepLineOn(editor, step.sourceLine);
      updateStepsUI(clamped, currentScene);
    }
```

Replace with:

```ts
    // Rebuilds the scrubber's dots for a freshly-parsed set of statements
    // (called once per successful run, not per statement-click). Hides the
    // bar entirely when there's nothing to navigate (0 or 1 statements).
    function buildStepsUI(statements: Statement[]) {
      const n = statements.length;
      stepDots!.innerHTML = "";
      if (n <= 1) {
        stepsBar!.hidden = true;
        return;
      }
      stepsBar!.hidden = false;
      for (let i = 0; i < n; i++) {
        const dot = document.createElement("button");
        dot.type = "button";
        dot.className = "pg-step-dot";
        dot.setAttribute("aria-label", `Step ${i + 1} von ${n}`);
        dot.setAttribute("aria-current", "false");
        dot.addEventListener("click", () => renderStep(i));
        stepDots!.appendChild(dot);
      }
    }

    // Cheap per-step-change update: toggles the active dot + label text,
    // without touching event listeners (buildStepsUI owns those).
    function updateStepsUI(i: number, statements: Statement[]) {
      stepDots!.querySelectorAll<HTMLButtonElement>(".pg-step-dot").forEach((dot, idx) => {
        dot.classList.toggle("is-active", idx === i);
        dot.setAttribute("aria-current", idx === i ? "true" : "false");
      });
      stepLabel!.textContent = `Step ${i + 1}/${statements.length}`;
    }

    // Client-side-only re-render of one statement of the already-parsed
    // scene — no worker round-trip, since one eval already returned every
    // frame and every statement's own mark geometry. A fold-kind statement
    // just re-renders its backdrop frame; a mark-kind statement re-renders
    // the SAME backdrop (marks don't fold anything) with its own mark
    // overlaid.
    function renderStep(i: number) {
      if (!currentScene || currentStatements.length === 0) return;
      const n = currentStatements.length;
      const clamped = Math.max(0, Math.min(i, n - 1));
      const stmt = currentStatements[clamped]!;
      try {
        const svg = renderFolded(currentScene, {
          theme: WEB_THEME,
          step: String(stmt.frameIndex),
          markOverlay: stmt.mark ?? undefined,
        }).toString();
        showSvg(svg);
      } catch (err) {
        showError(`Render-Fehler: ${err instanceof Error ? err.message : String(err)}`);
        return;
      }
      setStepLineOn(editor, stmt.sourceLine);
      updateStepsUI(clamped, currentStatements);
    }
```

- [ ] **Step 3: Rewire `renderResult` and `clearStepsUI`**

Find:

```ts
    function clearStepsUI() {
      currentScene = null;
      stepsBar!.hidden = true;
      setStepLineOn(editor, null);
    }
```

Replace with:

```ts
    function clearStepsUI() {
      currentScene = null;
      currentStatements = [];
      stepsBar!.hidden = true;
      setStepLineOn(editor, null);
    }
```

Find (inside `renderResult`'s success branch):

```ts
          const scene = parseFold(parsed.fold as object);
          if (scene.steps.length > 0) {
            currentScene = scene;
            buildStepsUI(scene);
            renderStep(scene.steps.length - 1);
          } else {
            showSvg(renderCP(scene, { theme: WEB_THEME }).toString());
          }
```

Replace with:

```ts
          const scene = parseFold(parsed.fold as object);
          if (scene.statements.length > 0) {
            currentScene = scene;
            currentStatements = scene.statements;
            buildStepsUI(scene.statements);
            renderStep(scene.statements.length - 1);
          } else {
            showSvg(renderCP(scene, { theme: WEB_THEME }).toString());
          }
```

(`clearStepsUI()` already ran unconditionally at the top of `renderResult`,
per the 2026-07-19 fix round — that's unchanged and still correct here: it
resets `currentStatements` too now, so the `else` branch doesn't need to
repeat the reset.)

- [ ] **Step 4: Build**

Run: `cd packages/www && bun run build`
Expected: succeeds with no new errors.

- [ ] **Step 5: Verify manually**

Run: `cd packages/www && bun run dev` (or use the `run` skill). Load the
landing page, click the "Fish base" example chip (two `step` blocks, four
`mark` statements, two `flatten` statements — exactly the source verified
during design). Confirm:
- The scrubber shows one dot per statement (marks AND folds — more dots
  than the 2026-07-19 version showed for this same example, which only
  counted the two folds).
- Clicking a mark-statement dot shows the SAME folded picture as the
  previous dot (marks don't fold anything) but with a dashed mark line/tick
  drawn on top of it, styled like the existing crease-pattern mark ticks.
- The gutter marker still tracks correctly for both mark and fold dots (no
  regression — `cm-step-marker.ts` is unchanged).
- Clicking a fold-statement dot shows no mark overlay (the fold's own
  `stmt.mark` is `null`).
- No new network requests fire on any dot click (still purely client-side,
  same as 2026-07-19).
- Editing the code after a run still clears the gutter marker but leaves
  the scrubber and image alone (Task 4 from the 2026-07-19 plan, unaffected
  by this change).

- [ ] **Step 6: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "feat(playground): statement-driven scrubber with mark overlay"
```
