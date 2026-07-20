# Design: Playground folded-step view shows cumulative marks

**Date:** 2026-07-20
**Status:** approved (brainstorming) — pending implementation plan
**Topic:** extend the Playground's folded-step overlay (shipped
`2026-07-20-playground-statement-sourcemap-design.md`) so scrubbing to step
`i` shows **every** still-active mark from statements `0..i`, not just step
`i`'s own mark, with the most recent one visually distinguished.

## Problem

The statement-sourcemap feature explicitly chose non-cumulative mark display:
clicking a `mark` statement shows only that statement's own mark, and
clicking a later mark does not keep earlier marks visible (see "Not
cumulative" in the prior design doc). In practice this makes it hard to see
how a crease pattern builds up while narrating a multi-mark construction —
each click replaces the previous mark instead of accumulating it. This
design reverses that one choice: marks accumulate across `0..i`; the
statement-sourcemap design's other decisions (scrubber dots, gutter sync,
fold-kind step rendering) are unchanged.

## Existing data (confirmed by investigation)

- `SceneOptions.markOverlay?: Mark` (`packages/render-2d/render-svg/src/render-scene.ts:35`)
  is a single mark today, drawn in the occluded/folded branch
  (`render-scene.ts:339-398`) — dashed line/tick, `theme.lineStyle(intent)`
  color, `stroke-width: max(1, style.strokeWidth - 1)`, `opacity: 0.7`.
- `Statement.mark: Mark | null` (`packages/render-2d/scene/src/types.ts:44`)
  is the mark **as recorded at that statement** — it stays populated even
  after the mark later graduates into a real crease (comment at
  `types.ts:33-38` confirms this explicitly).
- `FoldScene.marks: Mark[]` (`types.ts:77`) is the final, file-wide list of
  **still-active** (non-graduated) marks — a mark that graduated is absent
  here. Graduation is one-directional (a graduated mark does not
  un-graduate), so "is this statement's mark still active as of the final
  scene" is a valid proxy for "was it still active at step `i`" for any
  `i` ≤ the statement's own index.
- `Playground.astro`'s `renderStep(i)` (line 494-512) currently passes
  `markOverlay: stmt.mark ?? undefined` — exactly one statement's mark.
- Theme has no dedicated "highlight" token; `theme.construction` (`#6366f1`,
  indigo) is the existing accent color already used for named-point/line
  construction overlays (`render-scene.ts` construction-overlay path,
  `theme.ts:27`) and is otherwise idle in the folded-step branch (marks are
  not styled with it today).

## Design

### 1. `SceneOptions.markOverlay` — single `Mark` → mark list + newest marker

```ts
export interface MarkOverlay {
  marks: Mark[];
  newestCreaseId?: number; // Mark.creaseId of the most recently added mark
}
export interface SceneOptions {
  // ...
  markOverlay?: MarkOverlay; // folded only — project these marks onto the step's faces
}
```

Renamed field stays `markOverlay` (call sites already scoped to this repo).
`marks: []` is a legal, cheap no-op (nothing drawn) — used implicitly by any
step at or before the first mark statement.

### 2. `render-scene.ts` mark-drawing block (339-398) — loop, not single draw

- Wrap the existing per-mark drawing logic (both `seg` and `point` branches)
  in `for (const m of opts.markOverlay.marks)`.
- Draw order: array order (oldest → newest) — later marks paint over earlier
  ones at shared geometry, which is the desired "newest on top" effect for
  free.
- Style branch: if `m.creaseId === opts.markOverlay.newestCreaseId`, override
  `markAttrs` with `stroke: theme.construction`, `opacity: 1`, keep
  `stroke-dasharray`/width as-is (only color + opacity change — the design
  question "how to highlight" was answered as "color + full opacity", not a
  dash/width change). Otherwise keep today's `theme.lineStyle(intent)` +
  `opacity: 0.7` styling, unchanged.
- No new theme field — reuses `theme.construction`. Risk: if a caller also
  renders the named-line/point construction overlay (`opts.labels`) in the
  same folded step, both use indigo. Accepted — the two overlays are drawn
  in different regions (construction overlay is points/named lines, not
  marks) and this is Playground-only where construction labels aren't
  currently toggled on by the scrubber.

### 3. `Playground.astro` `renderStep(i)` — build the cumulative list

```ts
function renderStep(i: number) {
  // ...unchanged clamping...
  const stmt = currentStatements[clamped]!;
  const activeMarks = currentStatements
    .slice(0, clamped + 1)
    .filter((s) => s.kind === "mark" && s.mark !== null)
    .map((s) => s.mark!)
    .filter((m) => currentScene!.marks.some((sm) => sm.creaseId === m.creaseId));
  const newestCreaseId = activeMarks.at(-1)?.creaseId;
  const svg = renderFolded(currentScene, {
    theme: WEB_THEME,
    step: String(stmt.frameIndex),
    markOverlay: activeMarks.length > 0 ? { marks: activeMarks, newestCreaseId } : undefined,
  }).toString();
  // ...unchanged...
}
```

- `activeMarks` is recomputed per click — statement counts in this feature
  (Playground demo sources) are small (single digits to low tens), so no
  memoization needed.
- Filter order matters: build from `Statement.mark` (survives graduation),
  then drop graduated ones via the `scene.marks` membership check — matches
  the "hide once graduated" decision.
- `newestCreaseId` is the creaseId of the **last surviving entry** in
  `activeMarks` (not necessarily `stmt`'s own mark — if `stmt` itself is a
  `fold` statement, or its mark already graduated by step `i`, the newest
  active mark is the last mark statement ≤ `i` that hasn't graduated).

## Edge cases

- **Step `i` is a fold statement, no marks yet**: `activeMarks` is `[]`,
  `markOverlay` is `undefined` — identical to today's no-mark rendering.
- **All marks so far have graduated**: `activeMarks` is `[]` even though
  mark statements exist in `0..i` — no overlay drawn, consistent with "hide
  once graduated."
- **Same `creaseId` reused** (shouldn't happen — creaseId is assigned once
  per mark by the evaluator) — not defended against; would only affect which
  duplicate is treated as "newest," a non-issue in practice.
- **Scrubbing backward**: recompute is stateless (always derived from
  `currentStatements.slice(0, i+1)`), so backward navigation is naturally
  correct — no stale accumulation to clear.

## Out of scope

- Flat CP view (`renderCP`, `opts.texture.marks` path, `render-scene.ts:438-468`)
  is unchanged — it already shows all active marks unconditionally,
  independent of step.
- No new Playground prop — this changes `renderStep`'s internal behavior
  only, the single homepage embed (`packages/www/src/pages/index.astro:116`)
  gets it automatically.

## Testing

- `packages/render-2d/render-svg/test/marks.test.ts`: extend with — multiple
  marks in one `markOverlay.marks` array all render; the mark matching
  `newestCreaseId` gets `theme.construction` stroke + `opacity: 1`; others
  keep the existing dashed/0.7-opacity style; empty `marks: []` renders
  nothing (regression guard, mirrors the existing empty-marks case).
- Playground: manual browser verification — source with 3+ marks before a
  fold, scrub forward and confirm marks accumulate with the latest
  highlighted, scrub backward and confirm no stale marks linger, confirm a
  mark disappears from the overlay once its statement's fold makes it
  graduate.
