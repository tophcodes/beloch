# Design: per-statement `kept_marks` (correct mark-graduation for the Playground overlay)

**Date:** 2026-07-20
**Status:** approved (brainstorming) — pending implementation plan
**Topic:** fixes a real bug in `2026-07-20-playground-cumulative-marks-design.md`'s
shipped implementation — the newest-mark highlight sticks to an already-folded
crease line forever once its statement graduates, because that design
deliberately dropped graduation filtering as "harmless redundancy." It isn't:
confirmed via a user-reported repro where `flatten` consumes 4 marks into
real creases, and the last one (`--ec`) stays rendered in the accent color
on top of the flatten's own crease line for every subsequent step.

## Problem

The shipped Playground overlay shows `currentStatements.slice(0, i+1)` — every
`mark`-kind statement's own `Mark`, unconditionally, regardless of whether a
later fold has since consumed (graduated) it into a real crease. For a
program where marks get consumed by a `flatten`/`fold`, the highlighted
"newest" mark never moves past whatever the last `mark` statement was, and
keeps drawing on top of already-real geometry for every step after.

The obvious fix — filter against `FoldScene.marks` (the final, file-wide
snapshot of still-active marks) — was tried and rejected in the prior spec,
correctly: graduation is a **per-frame, geometric** check (`fold_emit.ml`'s
`cp_display`/`graduates`: a mark graduates once both endpoints of its segment
sit on some face's boundary in the state being displayed). For the user's
repro, **all four marks eventually graduate** — filtering by the final
snapshot would hide them from step 0 onward, breaking the entire "watch
marks accumulate" use case, not just the tail end.

## Existing data (confirmed by investigation)

- `Statement.mark`'s `frame_index` has **different meaning per statement
  kind** (`eval.ml`'s `push_frame` / `Ast.Mark` handler, `stmt_log_entry`
  comment at `eval.ml:15-27`): for `SFold`, it's the frame *this fold just
  produced*. For `SMark`, it's the *most-recently-pushed* frame — i.e. the
  backdrop from **before** this mark existed (marks don't push frames).
  Consequence: you cannot check "is this mark still kept" against
  `scene.steps[stmt.frameIndex]` — for a mark statement, that frame
  structurally predates the mark and can never reflect it either way.
- `file_frames[0]` (`scene.steps[0]`) is a **synthetic** frame
  (`fold_emit.ml:420-427`, built from `Fold_state.init_square` directly, not
  from any real evaluator state reached during evaluation) — any mark
  statement before the first fold has `frame_index: 0`, pointing at this
  synthetic frame, which by construction has zero marks in its own state.
  Reinforces the previous point: per-frame lookups don't work for marks.
- `Fold_state.mark`'s identity (`mcrease_id`) is stable and monotonically
  assigned (`Fold_state.fresh_crease_id`, confirmed deterministic by
  `test_beloch_marks_crease_id_deterministic` in `test_e2e.ml`). The **same**
  `marks` array is threaded through every state transformation unchanged
  (`fold_state.ml`'s `make ~marks:g.marks ...` call sites) — `cp_display`
  never mutates the real state, only derives a display-time `kept` list from
  it. This means `Fold_state.marks !(ctx.state)` grows monotonically for the
  whole file; graduation is computed **fresh, per call**, from current face
  topology — never cached or subtracted from the real array.
- `cp_display` (`fold_emit.ml:83-109`) already computes exactly what's
  needed — `graduates`/`kept` — but only for two existing call sites: the
  final whole-file `beloch:marks` (`to_json_folded`) and, per-frame but
  discarded, inside `folded_frame_of_state` (comment: "graduate marks into
  flat (F) creases for the folded diagram too... emit-only", `fold_emit.ml`
  ~117-119 — the `kept` half of that call's result is thrown away today).
- `beloch:statements` (`stmt_log_entry` in `eval.ml`, serialized by
  `beloch_statements_json` in `fold_emit.ml:274-292`) already carries
  `sl_kind`/`sl_span`/`sl_frame_index`/`sl_mark` per statement, built up via
  `ctx.statements_rev` at `push_frame` (`SFold`, `eval.ml:313-322`) and at
  mark-recording (`SMark`, `eval.ml:1477-1481`, inside the `record` closure).
  This is the natural place to add graduation-aware data, since it's already
  statement-scoped and already the sole data source the Playground's
  scrubber reads.

## Design

### 1. `Fold_state.mark_graduates` — extract the shared predicate

`cp_display`'s `graduates` closure (material-boundary check) is duplicated
verbatim into `eval.ml` by this design. Extract it once into `Fold_state` (a
module both `Eval` and `Fold_emit` already depend on — `Eval` cannot depend
on `Fold_emit`, which is what currently prevents reuse):

```ocaml
(* fold_state.ml — emit-time graduation test (design §3.6): true when a seg
   mark's endpoints already sit on a face boundary in this state's current
   topology, i.e. it's indistinguishable from a real crease. Point marks
   never graduate. *)
let mark_graduates (st : t) (m : mark) : bool =
  let material (p : Geom.point) =
    Array.exists (fun f -> point_on_polygon_boundary f p) (faces st)
  in
  match m.mgeom with
  | MSeg (a, b) -> material a && material b
  | MPoint _ -> false
```

`fold_emit.ml`'s `cp_display` is updated to call `Fold_state.mark_graduates
st` instead of its own inline closure — behavior-preserving, existing tests
must still pass unchanged.

### 2. `stmt_log_entry` — add `sl_kept : Fold_state.mark list`

```ocaml
type stmt_log_entry = {
  sl_kind : stmt_kind;
  sl_span : Error.span;
  sl_frame_index : int;
  sl_mark : Fold_state.mark option;
  sl_kept : Fold_state.mark list;
      (* marks still dangling (not yet graduated into a real crease) as of
         immediately after this statement — see design doc for the
         accumulate-vs-recompute rule per statement kind. *)
}
```

Populated with **different logic per kind** — this is the crux of the fix:

- **`SMark`** (inside `record`, `eval.ml` ~1470-1481): the backdrop frame for
  a mark statement is fixed, from a strictly earlier fold (or the synthetic
  frame 0) — it cannot possibly already contain a mark that didn't exist
  when it was captured. So graduation is **not re-checked** mid-window;
  `sl_kept` simply **inherits the previous statement's `sl_kept` and appends
  the new mark**:

  ```ocaml
  let prior_kept =
    match ctx.statements_rev with
    | prev :: _ -> prev.sl_kept
    | [] -> []
  in
  ...
  ctx.statements_rev <-
    { sl_kind = SMark; sl_span = span; sl_frame_index = List.length ctx.frames_rev;
      sl_mark = Some m; sl_kept = prior_kept @ [ m ] }
    :: ctx.statements_rev;
  ```

- **`SFold`** (inside `push_frame`, `eval.ml` ~313-322): the just-pushed
  frame **is** a real, freshly-derived state — graduation is recomputed
  fresh against it, filtering the **whole** `Fold_state.marks` array (not
  just the open window), matching exactly what the existing final
  `beloch:marks` computation already does — just now done at every fold, not
  only once at the end:

  ```ocaml
  let st = !(ctx.state) in
  let kept =
    Array.to_list (Fold_state.marks st)
    |> List.filter (fun m -> not (Fold_state.mark_graduates st m))
  in
  ctx.statements_rev <-
    { sl_kind = SFold; sl_span = sp; sl_frame_index = List.length ctx.frames_rev;
      sl_mark = None; sl_kept = kept }
    :: ctx.statements_rev;
  ```

Order is preserved end-to-end: `Fold_state.marks` is append-only
(`Fold_state.add_mark`, `Array.append g.marks [|m|]`), `List.filter`
preserves relative order, and mark-statement accumulation appends — so
`sl_kept`'s **last element**, whenever non-empty, is always the
most-recently-created still-dangling mark, for both statement kinds
uniformly. This matters for step 4 below.

### 3. `beloch_statements_json` — serialize `kept_marks`

```ocaml
let common =
  [ (* ...existing kind/source_line/frame_index... *) ]
in
let kept_json = ("kept_marks", `List (List.map mark_json s.Eval.sl_kept)) in
match s.Eval.sl_mark with
| None -> `Assoc (("mark", `Null) :: kept_json :: common)
| Some m -> `Assoc (("mark", mark_json m) :: kept_json :: common)
```

Reuses `mark_json` verbatim (already shared between the final `beloch:marks`
and each statement's own `mark` field).

### 4. `@beloch/scene` — `Statement.keptMarks`

```ts
export interface Statement {
  index: number;
  kind: "fold" | "mark";
  sourceLine: number;
  frameIndex: number;
  mark: Mark | null;
  keptMarks: Mark[];   // NEW — still-dangling marks as of this statement, see design doc
}
```

`parse.ts` parses `kept_marks` the same way `beloch:marks`/`mark` are
already parsed (reuse the existing mark-parsing helper for the array).

### 5. `Playground.astro` `renderStep` — simplifies

The client no longer accumulates or filters anything — the evaluator has
already done it, correctly, per statement:

```ts
const activeMarks = stmt.keptMarks;
const newestCreaseId = activeMarks.at(-1)?.creaseId;
const svg = renderFolded(currentScene, {
  theme: WEB_THEME,
  step: String(stmt.frameIndex),
  markOverlay: activeMarks.length > 0 ? { marks: activeMarks, newestCreaseId } : undefined,
}).toString();
```

This **replaces** the `currentStatements.slice(0, clamped + 1).filter(...).map(...)`
logic shipped in the prior design — smaller than what it replaces.

## Edge cases

- **Point marks never graduate** (`mark_graduates`'s `MPoint _ -> false`) —
  they stay in `kept_marks` for the rest of the file once added, matching
  their role as permanent reference annotations (e.g. `mark --vm at .ctr` in
  the existing `marks.test.ts` fixture).
- **First statement is a fold, no marks yet**: `Fold_state.marks st` is `[]`
  trivially (nothing added yet) — `sl_kept = []`, no special-casing needed.
- **First statement is a mark**: `ctx.statements_rev` is empty, `prior_kept`
  defaults to `[]` — `sl_kept = [mark]`.
- **A mark that graduates instantly** (e.g. a corner-to-corner `through .a
  .c` on the still-flat single-face sheet — both endpoints are already face
  vertices): per the design, mid-window marks are **never** graduation-
  checked, so this does **not** vanish from the overlay the moment it's
  created — it only drops out once an actual fold's fresh `cp_display` finds
  it graduated. This was a real alternative considered (checking graduation
  live at `SMark` time) and rejected — it would make visually-common
  patterns like the docs' own HERO fold (`mark --diag = through .a .c`)
  disappear from the overlay from step 0, which is worse than the bug being
  fixed.
- **A fold that graduates nothing**: `sl_kept` for that `SFold` equals
  whatever marks survive `Fold_state.mark_graduates` — could be the same set
  as before, a subset, or (as in the bug repro) empty.

## Out of scope

- `folded_frame_of_state`'s own discarded per-frame `kept` (used only to
  bake graduated marks into that frame's F-creases) is untouched — this
  design doesn't add a `beloch:marks` field to `file_frames` entries; it was
  considered and rejected (see "Existing data") because per-frame lookups
  don't correctly attribute mark-statement graduation regardless.
- Flat CP view (`renderCP`) — unchanged, still shows all currently-active
  (file-wide-final) marks unconditionally, independent of any step.

## Testing

- OCaml (`packages/core/tests/test_e2e.ml`): extend `test_beloch_statements`
  (or add a sibling test) with a source mixing marks that survive and marks
  that get consumed by a fold — assert `kept_marks` per statement: growing
  through the mark run, then correctly emptied/reduced at the fold that
  consumes them. Reuse the user's repro shape (4 marks + `flatten`) as the
  concrete case.
- `packages/core/tests/test_fold_state.ml`: a small unit test for
  `Fold_state.mark_graduates` directly (extracted predicate), mirroring
  `test_add_mark`'s existing "marks ride through a fold" style.
- `@beloch/scene` parser test: `Statement.keptMarks` shape, mirroring
  existing `Statement`/`Mark` parser tests.
- `packages/render-2d/render-svg`: no change needed — `MarkOverlay` already
  accepts an arbitrary `Mark[]` + `newestCreaseId`, this design only changes
  what the Playground passes in.
- Playground: manual verification with the exact bug repro from this
  session (4 marks + `flatten` + trailing `fold`) — confirm the highlighted
  mark disappears once scrubbed past the `flatten` step, instead of sticking
  to the accent color forever.
