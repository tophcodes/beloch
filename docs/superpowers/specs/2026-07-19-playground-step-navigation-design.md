# Design: Playground step navigation

**Date:** 2026-07-19
**Status:** approved (brainstorming) — pending implementation plan
**Topic:** let the live Playground (`packages/www/src/components/Playground.astro`)
step back and forth through a fold's intermediate steps, highlighting the
source line that produced the currently-shown step — a live-editor analogue
of the existing build-time `<beloch-figure>` stepper.

## Problem

Today the Playground always renders the *final* folded state (or the crease
pattern, if the scene has no steps) in one shot — `renderResult()` in
`Playground.astro` does `scene.steps.length > 0 ? renderFolded(scene, {theme})
: renderCP(scene, {theme})`, with no way to see any intermediate state. For
multi-step folds (`step left` / `step right` blocks, or just several
sequential fold statements) there is no way to inspect how the paper got to
its final state, or which source line produced which fold.

The docs site already has exactly this for **static, build-time-rendered**
figures — `packages/www/src/lib/beloch-figure.ts`'s stepper toggles through
`scene.steps`, highlighting the corresponding source line in a
build-time-rendered `<span data-line="N">` gutter (`Beloch.astro`). The
Playground's editor is a live CodeMirror 6 instance instead, so that
mechanism doesn't transfer directly — but the underlying data it relies on
already exists end-to-end and needs no changes.

## Existing data (confirmed, no evaluator changes needed)

- The OCaml evaluator already threads a source span per fold-producing
  statement through `Eval.frames` and emits it in the FOLD JSON:
  `packages/core/lib/fold_emit.ml:227-231` writes `"beloch:step"` (step-block
  label, if any) and `"beloch:source_line"` (1-based line number, or `null`)
  per frame.
- `@beloch/scene`'s `Step` type already surfaces this:
  `packages/render-2d/scene/src/types.ts:26-31` —
  `{ index: number; label: string | null; sourceLine: number | null; frame: Frame }`,
  parsed in `packages/render-2d/scene/src/parse.ts:59-70`.
- `renderFolded(scene, { step })` (`packages/render-2d/render-svg/src/render-folded.ts:15-35`)
  already renders one specific step, addressed by label or by stringified
  index (`pickStep`, `parse.ts:82-95`) — it is not "final scene only".
- `scene.steps[0]` is the flat, unfolded starting sheet and deliberately has
  `label: null, sourceLine: null` (nothing in the source produced it).

So this is purely a front-end feature: new player UI in the Playground, plus
a CM6-native way to show "this is the current step" in the gutter (the
existing `<beloch-figure>` approach is static-HTML-only and does not apply to
a live `EditorView`).

## Rejected alternative

Reusing `beloch-figure.ts`'s stepper wholesale was considered and rejected:
it operates on a static `<span data-line="N">` per line, rendered once at
build time (`Beloch.astro`). The Playground's source is live and editable —
there is no such gutter markup to toggle a class on. CM6 needs its own
gutter/decoration extension operating on the live `EditorView`.

## Design

### 1. State & rendering (`Playground.astro`)

`renderResult()` currently parses the fold and discards the `Scene` object
after one render. It will instead:

- Store the parsed `Scene` in a per-instance variable (`currentScene`).
- Compute the initial step index as the **last** one (`scene.steps.length - 1`) —
  preserves today's behavior of landing on the final folded state.
- Extract a `renderStep(i: number)` function: calls
  `renderFolded(currentScene, { theme: WEB_THEME, step: String(i) })`, injects
  the resulting SVG, updates the step gutter marker (see below), and updates
  the scrubber's active dot. This is pure client-side re-render — **no worker
  round-trip** per step change, since one eval already returns every frame.
- The crease-pattern path (`scene.steps.length === 0`) is unaffected — no
  scrubber, no gutter marker.
- The scrubber is only shown when `scene.steps.length > 1` (nothing to
  navigate for 0 or 1 steps).

### 2. Scrubber UI

A new bar at the bottom of `.pg-output`, under `.pg-result`, shown only when
applicable:

- One small dot per step, visually consistent with the existing paper-scheme
  swatches (`.pg-swatch`) already in this component — same circular-button
  idiom, so it reads as "this playground's established control style," not a
  new one.
- The active dot is filled with `var(--beloch-valley)` (same accent already
  used for the active swatch outline and the Run button); inactive dots use
  `var(--beloch-border)`.
- Clicking a dot calls `renderStep(i)` directly — no separate prev/next
  buttons needed, since clicking the adjacent dot already serves that role.
- A small muted-text label next to the dots reads `Step {i+1}/{n}`, plus
  ` · {label}` when `scene.steps[i].label` is set (e.g. `Step 3/7 · right`).

### 3. CM6 step-line gutter marker

New small module, `packages/www/src/lib/cm-step-marker.ts`, kept separate
from `Playground.astro` so the CM6-specific logic is isolated and testable:

- A `StateField<number | null>` holding the current 1-based source line (or
  `null` when there's nothing to show — step 0, or the doc has gone dirty).
- A dedicated CM6 gutter rendering a small dot (same `--beloch-valley` accent
  as the scrubber) next to the line held in that field — the "breakpoint"
  look the source data already supports natively via `gutter()` /
  `GutterMarker`.
- A line decoration giving that line a subtle background highlight, for
  visibility beyond just the gutter dot.
- An exported `setStepLine(view, line: number | null)` helper that dispatches
  a `StateEffect` to update the field and, when `line` is non-null, calls
  `view.dispatch({ effects: EditorView.scrollIntoView(pos, { y: "center" }) })`
  so the line is scrolled into view. **Does not** move the text
  cursor/selection — this is a read-only visual indicator, not a jump that
  should interfere with editing.

`Playground.astro`'s `renderStep(i)` calls `setStepLine(editor,
scene.steps[i].sourceLine)` after rendering.

### 4. Edge cases

- **Step 0** (flat, unfolded sheet): `sourceLine` is `null` — the SVG shows
  the flat square, and the gutter marker is simply absent for that step (no
  special-casing needed beyond "null means don't show a marker").
- **Doc goes dirty** (user edits after a run, per the existing
  `updateRunButtonState` dirty-tracking): the line numbers from the last eval
  no longer necessarily match the edited text, so the gutter marker is
  cleared (`setStepLine(editor, null)`) as soon as the doc is flagged dirty.
  The scrubber and the currently-shown SVG are **not** cleared — same
  philosophy as the existing "don't wipe the result on Run" behavior: a
  stale-but-still-useful result stays visible until the next successful run
  replaces it.
- **Bidirectional navigation** (clicking a line to jump the player) is
  explicitly out of scope for this iteration, per user's choice — the
  gutter marker is purely a read-only indicator.
- **Re-running**: a fresh `run()` replaces `currentScene` entirely and resets
  to the new final step, same as today's single-shot render.

## Testing

- Existing `beloch-figure.test.ts` patterns (step→line highlighting
  assertions) are a template for equivalent CM6-side tests of
  `cm-step-marker.ts` (e.g. dispatch `setStepLine`, assert gutter/decoration
  state) using `@codemirror/state`'s headless `EditorState`/`EditorView`
  testing utilities already available in this toolchain.
- Manual verification: load the Playground with a multi-step example (e.g.
  `FISH_BASE_SRC` from `packages/www/src/pages/index.astro`, which has two
  `step` blocks), click through the scrubber, confirm the gutter marker and
  SVG update together and that editing the code clears the marker but keeps
  the last rendered SVG and scrubber usable.
