# VSCode live preview — per-step diagrams synced to the cursor

**Status:** approved
**Date:** 2026-07-03
**Subsystem of:** [VSCode extension foundation](2026-07-03-vscode-extension-foundation-design.md)

## Goal

A live preview webview that shows the folded state / crease pattern of a Beloch
program at the `step` the editor cursor is in, with toggles for crease-pattern vs
folded, cursor-sync on/off (manual stepping), which named constructions to
overlay, and highlighting of the current step's crease/construction. No
animation in this slice — interpolation between folded states is deferred to a
future 3D-viewer slice.

## Scope

Two phases in one vertical:

- **Phase 1 — evaluator (OCaml), closes [#42](https://git.toph.so/toph/beloch/issues/42):**
  emit a multi-frame FOLD — one flat `foldedForm` frame per `step` panel,
  step-tagged. This is the minimal #42: static per-step frames only.
- **Phase 2 — renderer + webview (TS):** a `fold2svg` enhancement that tags SVG
  elements with stable classes (per crease with its provenance step, per named
  construction), and a webview that displays the host-rendered SVG and drives
  toggles/highlighting purely by CSS/DOM over that SVG.

**Explicitly out (deferred to the 3D-viewer slice):** all animation and
interpolation between folded states, rigid dihedral rotation, per-face
isometries ([#31](https://git.toph.so/toph/beloch/issues/31)), per-vertex
paper-coordinate correspondence for tweening, mid-fold layer occlusion, arbitrary
/ non-flat fold angles, 3D orbit of the model, and the force-graph /
relaxable-crease simulation (see `notes/2026-07-03-fold-sim-dof.md`, itself
far-future and citation-blocked).

## Why no animation now

The force-graph relaxation model is only needed for complex maneuvers (pocket /
sink / squash) the language cannot yet evaluate, and is citation-blocked. Rigid
dihedral rotation would need the per-face isometry / paper-coord correspondence
that only pays off once a real 3D view exists (`fold2svg` is 2D-only and
temporary). Deferring animation entirely to the 3D-viewer slice removes the
hardest mechanics (vertex correspondence across face-splitting frames, mid-fold
occlusion) from this MVP and keeps the webview a dumb display.

## Phase 1 — multi-frame FOLD (#42)

`lib/fold_emit.ml` currently emits one `foldedForm` frame (the final state). It
gains one `foldedForm` frame per `step` panel:

- One `foldedForm` frame per `step`, each = the exact flat folded state as of the
  end of that step, tagged with the step id (the same identifier carried in
  `beloch:edges[].step`). The pre-first-`step` state (flat paper / ungrouped
  actions) is the frame-0 baseline.
- Frames are exact (`Num`), serialized to float only at the FOLD boundary as
  today — floats never enter the exact artifact (the action-model principle:
  "animation is never baked as float keyframes into the exact artifact").
- No per-vertex paper-coordinate pairing, no active-crease / moving-face
  emission, no isometries in this slice — those land with animation in the
  3D-viewer slice.
- The crease-pattern frame and `beloch:named_points` / `beloch:named_lines` /
  `beloch:edges` (with `step`, `name`, `span`) are unchanged; the webview keys
  cursor→step off `beloch:edges[].step` + `.span`.

The spec's §7 FOLD mapping is updated to document the multi-frame layout.

## Phase 2 — renderer + webview

### fold2svg enhancement (`tools/fold2svg.mjs`)

`fold2svg` already overlays named constructions and draws creases; it gains
**stable, semantic hooks** so the webview can style without re-rendering:

- Each crease `<path>`/`<line>` carries `data-step="<id>"` (from its provenance)
  and a class for its assignment (`crease-M` / `crease-V` / `crease-U`).
- Each named construction (point/line) carries `class="construction"` and
  `data-construction="<name>"`.
- A `data-frame` / per-step selector so a single rendered SVG (or a small set)
  exposes all steps; the concrete mechanism (one SVG per step vs. one SVG with
  per-step groups) is a plan-level decision, but the webview MUST be able to
  switch the displayed step by DOM/CSS, not by asking the host to re-render.

`fold2svg` is a temporary tool; these additions are low-risk and confined to it.

### Webview (`editors/vscode/src/preview.ts` + modules)

The webview is a display surface with UI controls; it holds **no fold geometry**.
The host (Node extension) runs `beloch fold` (via `resolveBeloch()`) and
`fold2svg` and posts the rendered SVG(s) to the webview. All controls then act by
CSS/DOM over that SVG:

- **CP ↔ folded toggle** — switch between the crease-pattern and folded views.
- **Sync toggle** — on: the editor cursor drives the current step (cursor line →
  the `step` whose `beloch:edges` spans contain it). Off: the cursor is ignored
  and the user steps manually (prev/next step, or a step scrubber) — so the view
  does not jump while editing.
- **Construction selector** — a checklist of the program's named constructions;
  toggling one shows/hides its overlay (`data-construction`) via CSS.
- **Current-step highlight** — the crease line(s) / construction of the current
  step (`data-step` = current) are visually emphasized via a CSS rule keyed to
  the step id.
- **Pre-first-step state** — cursor before the first `step` shows the flat
  paper / frame-0 baseline.

Re-render (host round-trip) happens only when the document changes (re-evaluate)
— not on toggles, step changes, or cursor moves within an already-rendered
program.

### Error handling

If `beloch fold` fails (program has an error), the webview shows the diagnostic
(span + message) rather than a stale or blank render. Emitting-until-first-error
is a possible later refinement; the MVP shows the error.

## Files

- `lib/fold_emit.ml` — multi-frame emission (Phase 1).
- `tests/` — OCaml test(s) asserting one `foldedForm` frame per `step`, correct
  step tags, exact coords.
- `spec/SPECIFICATION.md` §7 — document the multi-frame FOLD layout.
- `tools/fold2svg.mjs` — semantic class/id/`data-*` emission.
- `tools/test/` — assert the SVG carries the crease `data-step` and
  `data-construction` hooks.
- `editors/vscode/src/preview.ts` — replace the stub: host render pipeline +
  webview host.
- `editors/vscode/src/preview-webview.ts` (or an inline script asset) — the
  webview-side controls (toggles, stepper, selector, highlight) over the SVG.
- `editors/vscode/package.json` — additive only (any preview dep + test script);
  `contributes` blocks frozen (the `beloch.showPreview` command already exists).
- `editors/vscode/test/` — tests for cursor-line→step mapping and the message
  protocol (pure functions, bun-testable without the extension host).

## Testing

- **Phase 1:** OCaml golden/unit test — a program with N `step` panels emits N
  `foldedForm` frames, each step-tagged, coords exact; frame-0 baseline present.
- **fold2svg:** a rendered example asserts the `data-step` and
  `data-construction` hooks exist on the right elements (extend the existing
  `tools/test` harness).
- **Webview logic:** unit-test the pure pieces in bun — cursor-line→step mapping
  (from `beloch:edges` spans), and the host↔webview message protocol
  (toggle/step/selection state → what the webview should show). The extension
  host / real webview interaction is a manual smoke test (documented steps).

## Related

- [#42](https://git.toph.so/toph/beloch/issues/42) — per-step folded frames; this
  slice closes its first two stages (per-step frame emission), leaving the
  exact-isometry stage for the animation/3D work.
- [#31](https://git.toph.so/toph/beloch/issues/31) — exact per-face isometries;
  needed for animation, deferred here.
- `notes/2026-07-03-fold-sim-dof.md` — the force-graph / relaxable-crease
  simulation for realistic collapse; far-future, citation-blocked, out of scope.
- The foundation's `beloch.showPreview` command + preview webview stub is the
  seam this fills.
