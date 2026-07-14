# Beloch card — point/label highlight, folded labels, per-fold step lines

**Date:** 2026-07-14
**Depends on:** the just-merged filename-as-comment + `lineNumbers` work.

Four requested changes, split into two slices by risk:

- **Slice A** (docs + `render-svg` only, no evaluator change): #1 point
  highlight, #2 labels in folded view, #3 automatic line numbers.
- **Slice B** (evaluator + scene + island): #4 per-fold folded steps with the
  active source line highlighted in the gutter.

---

## Slice A

### #1 — Point highlight shows the label and grows

Today a named vertex renders as a `<circle data-bel-name=…>` **plus** a
separate `<text>` label that is *not* stamped, so hovering/selecting the point
only lights the dot. Two fixes:

- **Stamp the label.** In `render-cp.ts`, the corner/point `<text>` label gets
  `data-bel-name = <vertex name>` (the same key the circle and the code-panel
  token already carry). Selection/hover then colours the label too.
- **Grow on highlight.** In `theme.css`:
  - `svg circle.bel-hover, svg circle.bel-selected { r: 5 }` (from base `r:3`).
  - `svg text.bel-selected { fill: var(--bel-sel) !important; }` colours the
    label to the selection colour. Hover already gets the shared
    `[data-bel-name].bel-hover` drop-shadow, which applies to `<text>` too.

### #2 — Labels in the folded view

`render-folded.ts` currently emits only the vertex dots, no text. Add name
labels mirroring the CP view: for each **named** folded vertex, emit a
`.<name>` `<text>` at the folded position, stamped `data-bel-name`, offset
outward from the layout centre (`p < centre → negative offset`, else positive)
so it clears the dot. Same font/weight as CP corner labels.

Blast radius: `render-folded` tests assert on substrings + element counts, not
whole-SVG goldens, so new `<text>` nodes don't break them. Add one assertion
that a named folded vertex now emits a stamped label.

### #3 — Automatic line numbers, addressable gutter

- **Auto, not author-set.** Drop the `lineNumbers` prop. Show the gutter iff
  the **code** (i.e. `trimmed`, excluding the injected `; filename` comment)
  has **more than 2 lines**.
- **Per-line spans.** Render the gutter as one `<span data-line="N">N</span>`
  per displayed line (not one text blob) so Slice B can highlight a single
  line. The injected filename comment is line 1; code line *k* of `trimmed`
  maps to gutter line `k + (filename ? 1 : 0)`.

---

## Slice B — #4 per-fold steps + active line

### Problem

The stepper steps through `scene.steps` = the `foldedForm` frames in
`file_frames`. The evaluator only pushes a frame at an explicit `step` marker
(`Ast.StepMark`, `eval.ml:1613`) and once at the end (`:1754`). So a
multi-`fold` example with no markers yields a **single** folded frame — nothing
to step. The user wants every `fold` to be its own step, with the gutter line
of that fold highlighted while its folded state is shown.

### Evaluator: a frame per fold

`eval.ml` pushes a frame after **each fold statement** that advances the folded
state, in addition to the existing final push. Reconciliation with the existing
`step` marker:

- A `fold` statement pushes a frame tagged with the source **span** of that
  statement.
- `StepMark` no longer self-pushes; it only sets the active label
  (`ctx.panel`), which rides along on the next pushed frame. This keeps named
  steps working (`cube-root`, `rabbit-ear`) while making every fold a frame.
- De-dupe: never emit two frames for one state (e.g. a `step` immediately
  followed by its `fold`); push on the fold, carry the pending label.

### Scene: per-frame source line

Emit the originating statement's line as a `beloch:*` extension on the folded
frame (ADR 0002 — provenance belongs in `beloch:` fields, not core FOLD).
Proposed field: `"beloch:source_line": <int>` (1-based, into the `.bel` the
evaluator saw, i.e. the `trimmed` source). `scene`'s `Step` gains
`sourceLine: number | null`; `parse.ts` reads it.

### Island: highlight the active line

`beloch-figure.ts`, when in the folded view at step *k*:

- Look up `scene.steps[k].sourceLine`; map to a gutter line via the same
  `+ (filename ? 1 : 0)` offset (the island knows whether a comment was
  injected — pass it via a `data-` attribute on the figure, or infer from the
  first gutter line's content).
- Toggle a `.bel-step-line` class on `span[data-line="<n>"]`; clear it on step
  change and when leaving the folded view.
- CSS: `.beloch-gutter span.bel-step-line { color: <accent>; font-weight: 600; }`
  (and a matching highlight on the code line itself if cheap).

### Golden churn

Frame-per-fold changes every multi-`fold` golden `.fold` (more `file_frames`).
This is mechanical: regenerate goldens, eyeball a couple (e.g. `up-to`,
`cube-root`) to confirm frame counts match fold counts and named steps keep
their labels. Accepted as the cost of the chosen approach.

## Non-goals

- No YR-style instruction-sequence format (ADR 0002's separate artifact) — we
  reuse `foldedForm` frames as steps, as the stepper already does.
- No animation/tweening between steps; discrete states only.
- No user-facing line-number toggle.

## Sequencing

Ship Slice A first (independent, low-risk, immediate value). Then Slice B:
evaluator → scene → goldens → island.
