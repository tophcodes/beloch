# Entity Inspector (Playground slice B) — Design

**Date:** 2026-07-22
**Status:** Design (approved, pre-plan)
**Slice:** B of the "Origami IDE" vision (A = native `beloch playground` server;
B = read-only inspector; C = selector authoring; D = action palette). This spec
covers **B only**. A/C/D are separate spec→plan cycles.

## Motivation

A live debugging session on `playground/peacock.bel` showed the gap concretely.
The line

```
.lb = --r & #[.a] * --ab
```

failed with `no segment of --r & #[.a] matches`. Answering *why* required
dropping into the OCaml evaluator: enumerating `--r`'s segments, checking which
face each borders, and finding that the face currently holding `.a` borders none
of them (while `#[.c]` does). None of that is visible from the rendered diagram.

ADR-0014 already names this as a tooling gap, not a language feature:

> ">1 ambiguous" becomes a routine outcome, so bundle **inspection** (enumerate a
> crease's segments, in folded and CP coordinates) becomes a needed
> evaluator/tooling affordance — not a language construct.

Slice B builds that affordance: hover/click any entity in the playground and see
its real structure — a crease as its segment bundle, a point with its face and
flap, an edge with its provenance — cross-linked to the source line that built
it.

## Goals

- Make every rendered entity (point, edge/segment, face, crease bundle)
  inspectable by hover and click.
- Reveal the structure that is currently evaluator-internal: a crease's segment
  list with per-segment face pair + paper/table coordinates + assignment; a
  point's owning face and flap (coplanar cluster).
- Bidirectional, **read-only** code↔diagram linking: clicking an entity
  highlights the source statement that produced it; placing the editor cursor on
  a line highlights the entities that line defines.

## Non-goals (explicit)

- **No writing to source.** Generating selectors from clicks is slice C.
- **No partial evaluation.** B operates on the last *successful* FOLD. Rendering
  the partial state up to an error is a separate slice.
- **No new views.** Works within the existing CP / folded views + stepper.
- **No native server.** Runs on the existing js_of_ocaml worker bundle
  (slice A swaps the transport underneath later, without touching B).

## Architecture

Three isolated layers, each independently testable.

### 1. Core export: `beloch:inspect`

A new top-level key in the emitted FOLD document, built in
`packages/core/lib/fold_emit.ml` from existing `fold_state` queries. No new
geometry — pure serialization of data the evaluator already computes.

```jsonc
"beloch:inspect": {
  "creases": {
    "<crease_id>": {
      "name": "r",                 // or null for an anonymous fold crease
      "axiom": "axiom5",
      "sources": ["--h", "--l"],
      "span": "peacock.bel:13:1-40",
      "segments": [
        {
          "faces":      [7, 9],            // (l, r) from crease_segment.faces
          "paper":      [[x, y], [x, y]],  // pa, pb
          "table":      [[x, y], [x, y]],  // ta, tb
          "assignment": "V"               // looked up from the edge
        }
      ]
    }
  },
  "faces":  { "<i>": { "vertices": [...], "flap": <cluster_id>, "rank": <int> } },
  "points": { "<name>": { "face": <i-or-null>, "flap": <cluster_id-or-null> } }
}
```

Sources:
- `Fold_state.crease_segments cid` → `faces`, `pa`/`pb`, `ta`/`tb` per segment.
- `Fold_state.coplanar_clusters` → the `flap` (cluster) id for each face; a
  point's flap is the cluster of its owning face.
- The fold-state `rank` array (stacking height per face, higher = above) → the
  per-face `rank`. A segment's **layer identity** is the ranks of its two
  bordering faces; the folded-view stack picker (§3) orders coincident segments
  by it. Already computed by the layer-ordering solver — pure serialization.
- `face_of_points [p]` → a point's owning face (may be `null` on a shared
  boundary → `Ambiguous`/`Zero`, surfaced honestly as null rather than a guess).
- Per-segment `assignment`: matched from `edges_assignment` via the segment's
  edge.

Additional change: **add `crease_id` to each `beloch:edges` entry.** Today an
edge carries `{axiom, sources, span, name}` but no crease id, so the frontend
cannot group a bundle's segments (and anonymous creases have no name to group
by). The id makes SVG edges addressable back to `beloch:inspect.creases`.

### 2. Render stamping (`packages/render-2d/render-svg`)

Every inspectable SVG element gets a stable data attribute, in **both**
`renderCP` and `renderFolded`:

- crease `<line>` → `data-crease-id`, `data-seg` (segment index within the bundle)
- face `<polygon>` → `data-face-index` (already emitted)
- point `<circle>` → `data-vertex` / `data-bel-name`

Anonymous creases carry a `crease_id` but no name and stay inspectable. Where a
crease id is not directly threaded to an edge at render time, the segment's
paper endpoints (`beloch:inspect`) match the edge by coordinate as a fallback.

### 3. Playground UI (`packages/www/src/components/Playground.astro`)

- **Hover** → outline the element under the cursor + a one-line tooltip
  (`--r · seg 1/2 · face 7|9 · V`).
- **Click** → pin the entity's full detail into a **side panel**: segment list,
  paper + table coordinates, provenance, face/flap. The panel persists while the
  user reads or edits code (a segment list is too large for a tooltip).
- **Stacked-group picker (folded view only).** When a click lands where multiple
  drawn elements coincide on the table, the panel shows them as a stack ordered
  top→bottom by face `rank`; the user picks which layer to focus. In the CP view
  no picker is needed: a bundle's segments scatter to distinct paper preimages on
  unfold (ADR-0014), so each is already individually clickable. This is the UI's
  answer to ADR-0014's "a purely table-space selector cannot disambiguate stacked
  copies" — an explicit layer chooser rather than reliance on click position.
- **Code link (read-only, bidirectional):**
  - Clicking an entity scrolls/highlights its provenance span in the CodeMirror
    editor.
  - Placing the editor cursor on line N outlines the entities whose provenance
    span covers line N in the SVG.
- Works in whichever view is currently shown; the panel always lists both
  paper and table coordinates.

## Data flow

```
FOLD (+ beloch:inspect)
  → @beloch/scene parse (retains the inspect map)
  → render-svg stamps data-crease-id / data-seg / data-face-index / data-vertex
  → UI pointer/selection event reads the data attribute
  → lookup in the inspect map
  → render side panel + editor decoration
```

## Error handling & edge cases

- **Eval error:** B shows data for the last successful FOLD; the current error
  notice is unchanged. Partial-render-to-error is out of scope (separate slice).
- **Stacked/occluded segments** (folded view): hover resolves to the topmost
  drawn element; clicking opens the stack picker (§3), which lists every
  coincident segment ordered by `rank`. The CP view separates them spatially.
- **Anonymous crease:** panel titled `crease #<id> · axiom5 · from --h --l`.
- **Point on a shared boundary** (`face`/`flap` = null): shown as
  "on a face boundary (ambiguous)" rather than an arbitrary pick.

## Testing

- **Core** (assertion test, `tests/cases/`): for a model with a folded,
  multi-segment crease (the peacock `--r`), assert `beloch:inspect.creases`
  enumerates the expected segments with correct `faces` pairs, `flap` ids, and
  per-face `rank` — the exact facts that were invisible during the live session.
- **Render** (snapshot): assert `data-crease-id` / `data-seg` appear on crease
  lines in both CP and folded output.
- **UI** (light DOM smoke): hovering a stamped element populates the panel.
  Playground test infrastructure is thin; this stays deliberately minimal.

## Scope summary

| In | Out |
|----|-----|
| `beloch:inspect` export (creases/faces/points) | Writing selectors to source (slice C) |
| per-face `rank` → segment layer identity | Partial-eval to error |
| `crease_id` on `beloch:edges` | Native `beloch playground` server (slice A) |
| render-svg data-attr stamping | New views / action palette (slice D) |
| hover + click-pin side panel + folded stack picker | |
| read-only bidirectional code↔SVG highlight | |
