# Design: fold2svg — occlusion-correct folded view + aesthetic pass

**Date:** 2026-07-01
**Status:** approved (brainstorming) — pending implementation plan

## Problem

The folded-state render (`tools/fold2svg.mjs --folded`) draws *every* face and
crease of *every* layer superimposed in the folded footprint. Because a flat
fold stacks many faces into the same 2D region, the result is a mush of
overlapping fold lines: you cannot tell which layer is on top, which side of the
paper shows, or which creases would actually be visible on a real model.

This blocks the upcoming pocket-tuck slice, whose entire behaviour is a change in
*layer ordering* — invisible in a silhouette that collapses all layers. More
immediately, it makes for weak PR screenshots.

Rendering should eventually become a full engine with complete control. That is a
separate, future slice. **This slice** improves the *existing* tool so the folded
view is occlusion-correct and PR images get better right away.

## Decisions made during brainstorming

| Question | Decision |
|---|---|
| Core job | Static **layer viewer** — make the folded state's layers legible in a still image. |
| Output form | **Static image** (SVG/PNG), like today. No browser/interactivity this slice. |
| Representation | **Occlusion-correct**: only the topmost layer is drawn at each point; lower creases are hidden behind opaque paper (what the real model looks like). NOT explode/cross-section/small-multiples. |
| Views | **Top + bottom** (front and flipped). Together they show which creases are visible on which side. |
| Side annotation | Front vs back of the paper is colour-distinguished (classic coloured-paper convention). |
| Hidden creases | Toggle `--hidden dashed\|hide`: occluded creases either drawn dashed (origami x-ray convention) or culled. Default `hide`. |
| Organisation | **Extend the existing `fold2svg.mjs`** (Approach A), not a new tool. The future full engine supersedes this anyway. |
| Extra polish | Occlusion view **plus** a bounded aesthetic pass; exact pixels tuned against real renders in the PR. |
| No OCaml change | Everything needed is already in the emitted foldedForm frame. |

## Data available (verified)

`beloch fold examples/fold-quarter.bel` → the top-level frame is the crease
pattern; `file_frames[0]` is the foldedForm, carrying:

- `faceOrders` — array of `[f, g, s]` (the per-face partial order from PR #21;
  6 entries for the quarter fold).
- `vertices_coords` — folded 2D coordinates.
- `frame_inherit: true` / `frame_parent: 0` — inherits `faces_vertices`,
  `edges_vertices`, `edges_assignment`, and `beloch:edges` (provenance) from the
  parent frame.

Front vs back is derivable from the *winding* (signed area) of each face polygon
in folded coordinates — no extra export needed.

## Architecture

Single TypeScript-edge tool, per [ADR 0001](../../../decisions/0001-ocaml-core-typescript-edge.md).
`tools/fold2svg.mjs` gains an occlusion renderer alongside its existing
crease-pattern and (replaced) folded modes. Rabbit Ear stays only as the
FOLD-load sanity check (ADR 0009 consumer); drawing remains hand-rolled SVG for
full control.

### Occlusion algorithm

1. **Linear extension.** Topologically sort the faces by `faceOrders`
   (`[f,g,s]`, `s=+1` ⇔ f above g toward g's normal) into a bottom→top order.
   For a flat fold, any set of mutually-overlapping faces is *totally* ordered
   (guaranteed by the tortilla-tortilla acyclicity guard shipped in #21), so a
   linear extension consistent with all overlaps exists.

2. **Painter's algorithm.** Draw faces bottom→top with **opaque** fill. Higher
   faces overwrite lower ones, so occluded regions and their creases disappear
   for free. Each face draws only its own edges, on top of its own fill.

3. **Top vs bottom.**
   - **Top view:** paint in the linear-extension order (bottom→top), forward
     coordinates.
   - **Bottom view:** reverse the paint order (view from below) **and** mirror
     horizontally (turning the sheet over flips left↔right).

### Side tinting

The signed area of a face's folded polygon gives its orientation: CCW = front
side up, CW = back side up (calibrated against a known example in a test).
Front → warm off-white; back → a subtle tint. Standard coloured-paper reading.

### Hidden-crease mode (`--hidden dashed|hide`)

For each crease edge, test whether a *higher* face (later in the linear
extension) covers it — edge-midpoint-in-polygon against each higher face's
folded polygon. If covered:

- `hide` (default): the opaque painter's pass already removed it — nothing extra.
- `dashed`: redraw the covered crease as a light dashed line (x-ray) over the
  paper, so hidden structure reads without breaking the occlusion.

### Aesthetic pass (bounded)

Exact colours/weights tuned against real PNGs in the PR; the list is fixed:

- Paper look: front off-white, back a subtle tint.
- Layer depth: hairline drop-shadow at layer boundaries to sell stacking.
- Folded creases: visible = solid dark, hidden = light dashed (per above).
- Typography/legend: consistent sizes, a cleaner legend box, title treatment.
- Strokes: refined weights, round caps (already present); white background
  (PR light background).
- The crease-pattern render (frame 0) gets only the typography/legend polish —
  otherwise untouched.

### CLI surface

- New: `--view top|bottom` — the occlusion view.
- **`--folded` becomes `--view top`** in effect: the old mushy silhouette had no
  real value, so replacing it in place makes the existing PR folded shots better
  immediately. `--view bottom` is the flip.
- `--hidden dashed|hide` applies to the views (default `hide`).
- Existing `--title`, output-path, and `.png` handling are unchanged, so the
  curl-assets PR-screenshot pipeline keeps working.

## Testing

No JS test setup exists yet. Add a minimal node harness with a few assertions
over `fold-quarter` / `fold-half` fixtures:

1. Faces are painted in a `faceOrders`-consistent (linear-extension) order.
2. Back-facing faces receive the back-side class/tint.
3. A known-occluded crease is dashed in `--hidden dashed` mode.
4. The bottom view is horizontally mirrored relative to the top view.

Lightweight — this is dev tooling, not the evaluator core.

## Out of scope

- The full future rendering engine (complete control, own draw stack).
- Animation of the fold sequence; interactivity.
- Exact insertion-*depth* readout (top+bottom shows *which side* a flap is on and
  whether it is occluded, but not "tucked between layer 3 and 4"). A later
  cross-section annotation could add this.
- **Bottom-view x-ray.** `--hidden dashed` computes occlusion for the top view (a
  crease is hidden if a face strictly *above* it covers it). The fills and edges
  of `--view bottom` are correct, but the dashed overlay still uses the top-view
  rule, so `--view bottom --hidden dashed` dashes the wrong creases. The default
  `--hidden hide` is correct in both views. Fix only if the pocket-tuck slice
  needs bottom x-ray (occlusion test would flip to faces *below* from the back).
