# Design: Playground statement-level sourcemap (marks as steps)

**Date:** 2026-07-20
**Status:** approved (brainstorming) — pending implementation plan
**Topic:** extend the Playground's step player (shipped 2026-07-19, see
`2026-07-19-playground-step-navigation-design.md`) so `mark` statements are
navigable alongside `fold`/`flatten` statements, with the mark itself
overlaid on the folded picture — not just source-line highlighting.

## Problem

The shipped step player only lets you step through `scene.steps` — one entry
per fold-producing frame (`file_frames` with `frame_classes: ["foldedForm"]`).
`mark` statements never produce a frame (marks don't change the paper's
geometry, they just record a crease line/point on it), so they're invisible
to the player: you can watch the folds happen but not see *how each crease
line was constructed* step by step.

## Existing data (confirmed by investigation, no assumptions)

- `mark` statements never call `push_frame` (`packages/core/lib/eval.ml`) —
  confirmed at the `Ast.Fold`/`Ast.Flatten`/`StepMark` call sites vs. the
  `Ast.Mark` handler (`eval.ml:1436`), which never does.
- Every `Ast.Mark` AST node unconditionally carries its own `Error.span`
  (`packages/core/lib/ast.ml:108`: `Mark of ... * Error.span`), available at
  the top of `eval.ml`'s match arm (`eval.ml:1436`) regardless of which
  operand kind is used (`` `Fresh `` — a freshly constructed line/point, or
  `` `Existing `` — a reference to an already-bound line, `eval.ml:1500-1527`).
  **So every mark statement can get a source line, no exceptions** — the
  `~prov:None` passed for the `` `Existing `` case (`eval.ml:1523,1526`) is a
  separate, narrower concept (crease-attribution provenance for when a mark
  later graduates into a real crease edge), not the statement's own span.
- `beloch:marks` (`packages/core/lib/fold_emit.ml:352-377`,
  `@beloch/scene`'s `parse.ts:42-52`/`types.ts`'s `SegMark`/`PointMark`)
  carries geometry + intent + `creaseId`, but no span/step/source-line today.
  The array itself is the natural id space — a mark's 0-based position in
  `beloch:marks` — as long as insertion order is stable between when the
  evaluator creates the mark and when `fold_emit.ml` later serializes it
  (append-only list; verify this holds during implementation).
- Mark geometry is **paper-space** (flat, unfolded coordinates) — confirmed
  in `packages/render-2d/render-svg/src/render-scene.ts:20`
  (`marks: boolean; // paper-space record marks (CP frame only)`) and its
  only draw path (`render-scene.ts:376-406`), which lives entirely in the
  flat/CP branch (`occlude === false`). **There is no existing code path
  that draws a mark in the folded/occluded branch** — this needs new
  rendering logic, not a flag flip.
- A working precedent for paper-space-to-folded-face projection already
  exists: the "ghost overlay" for future creases (`render-scene.ts:266-289`)
  projects a named line through each face's `facesMatrix` via `lineToFace`
  and clips it to the face polygon via `clipLineToPoly`
  (`packages/render-2d/render-svg/src/geometry.ts`). The mark overlay reuses
  this exact technique.

## Design

### 1. OCaml evaluator — `beloch:statements` (new JSON channel)

While the evaluator processes the top-level statement list, it already
tracks (implicitly, via `push_frame`) which frame index is "current." Extend
this to emit one entry per statement that is either fold-producing or
mark-producing:

```json
"beloch:statements": [
  { "index": 0, "kind": "mark", "source_line": 3, "frame_index": 0, "mark_ids": [0] },
  { "index": 1, "kind": "mark", "source_line": 4, "frame_index": 0, "mark_ids": [1] },
  { "index": 2, "kind": "fold", "source_line": 5, "frame_index": 1, "mark_ids": [] }
]
```

- **`fold`** entries: `frame_index` is the newly-pushed frame (same as
  today's `beloch:step`/`beloch:source_line` per-frame data — this is not a
  new concept, just re-exposed as a statement-indexed list instead of only a
  frame-indexed one).
- **`mark`** entries: `frame_index` is the *current* (most recent) frame —
  unchanged, since marks don't fold anything. `mark_ids` is the 0-based
  index/indices this statement contributes to `beloch:marks`.
- Statement kinds this repo doesn't need for the player (comments, `paper`,
  bare `step` labels that don't themselves carry a span) are simply not
  added as entries — this channel is additive, `file_frames` and
  `beloch:marks` are unchanged.

### 2. `@beloch/scene` — `Statement` type

```ts
export interface Statement {
  index: number;
  kind: "fold" | "mark";
  sourceLine: number | null;
  frameIndex: number;
  markIds: number[];
}
```

Parsed from `beloch:statements` into `FoldScene.statements: Statement[]`
(`packages/render-2d/scene/src/parse.ts`, `types.ts`). `FoldScene.steps` is
**unchanged** — `<beloch-figure>` and any other existing consumer keep
today's fold-only behavior; `statements` is additive.

### 3. `@beloch/render-svg` — mark overlay on a folded step

New, additive option on `renderFolded`:

```ts
export interface FoldedOptions extends RenderOptions {
  // ...existing fields unchanged...
  markOverlay?: number[]; // beloch:marks indices to project onto this step
}
```

When present, `render-scene.ts`'s occluded (folded) branch draws exactly
those marks (not the whole `scene.marks` array — filtered to
`markOverlay`), each projected through its containing face's
`facesMatrix` using the same `lineToFace`/`clipLineToPoly` path the ghost
overlay already uses, then clipped/styled the same way marks are drawn in
the CP view (dashed tick/line, `theme.lineStyle(intent)`). Omitting the
option is a no-op — zero behavior change for `<Beloch>`, `<beloch-figure>`,
or any other existing `renderFolded` caller.

### 4. Playground — statement-driven scrubber

- The scrubber iterates `scene.statements` instead of `scene.steps` — one
  dot per statement, **all styled identically** (marks and folds are not
  visually distinguished in the scrubber — explicit choice, keeps the
  control simple).
- Clicking a statement:
  - `kind: "fold"` → `renderFolded(scene, { step: String(frameIndex) })` —
    unchanged from today.
  - `kind: "mark"` → `renderFolded(scene, { step: String(frameIndex),
    markOverlay: markIds })` — same fold backdrop, with just that
    statement's mark(s) drawn on top. **Not cumulative** — clicking a later
    mark does not keep earlier marks visible; each click shows only its own
    statement's mark(s), explicit choice for a simpler mental model
    ("this dot = this line got drawn here").
- The gutter marker (`cm-step-marker.ts`) is **unchanged** — it only needs
  `sourceLine`, which `Statement` already carries uniformly for both kinds.
- The label reads `Step N/M` the same way as today (statement index, not
  frame index) — no mark-specific copy needed since dots aren't visually
  distinguished.

## Edge cases

- **First statement is a mark** (before any fold): `frame_index: 0`, the
  flat sheet — its (trivial, identity-ish) `facesMatrix` still projects the
  mark correctly, no special-casing needed.
- **A mark whose flap later folds away**: the backdrop shown is the frame
  *as of that statement*, i.e. before that fold happened — the mark's face
  is guaranteed present in that specific frame's geometry, since the mark
  was recorded against exactly that paper state.
- **Mark ordering stability**: the plan must verify (with a golden-file or
  targeted test) that a mark's position in the evaluator's internal list at
  record-time matches its final index in the serialized `beloch:marks`
  array — implementation risk to close during the plan, not assumed here.
- **0 or 1 statements**: same rule as today's step scrubber — hidden when
  `scene.statements.length <= 1`.

## Testing

- OCaml: extend existing golden-fold tests (or add new ones) asserting
  `beloch:statements` entries for a source mixing marks and folds, covering
  both `` `Fresh `` and `` `Existing `` mark operand kinds (the case that
  turned out *not* to need special-casing — a regression test here is cheap
  insurance).
- `@beloch/scene`: parser test for `Statement[]` shape, mirroring the
  existing `Step[]` parser tests.
- `@beloch/render-svg`: a `markOverlay` render test asserting the projected
  mark appears in the folded SVG output at the expected face, and that
  omitting the option changes nothing (regression guard for the "additive,
  no behavior change" claim).
- Playground: manual browser verification (same approach as the original
  step-navigation feature — no automated test convention exists for
  `Playground.astro`), stepping through a source with interleaved marks and
  folds, confirming each mark shows only its own line/point and the gutter
  marker tracks correctly for both kinds.
