# `<Beloch>` render card — Slice 2: hydration (view toggle + stepper + code↔diagram selection)

**Date:** 2026-07-13
**Status:** design, approved for planning
**Depends on:** Slice 1 (merged, HEAD 617276e) — the SSR render card + embedded FOLD.
**Scope of THIS spec:** Slice 2 only. Slice 3 (content) is out of scope.

## Problem

Slice 1 ships a static code | CP-SVG card with the full FOLD embedded as
`<script type="application/json" class="beloch-fold">`. Slice 2 makes it
interactive: a folded-view toggle with a per-step stepper, and a bidirectional
code↔diagram link (hover to preview, click to select) so a reader can see which
diagram element a `.point`/`--line` names — and keep chosen creases visible
through the whole fold sequence.

## Architecture

A vanilla **Web Component `<beloch-figure>`** wraps the entire card (code panel +
diagram). It reads the embedded FOLD from its `<script class="beloch-fold">` child
and progressively enhances the SSR'd static SVG. No framework. The same pure-TS
`@beloch/scene` + `@beloch/render-svg` that rendered at build time run in the
browser for view/step re-renders — one pipeline, two environments.

- **Fallback:** with no JS (or before hydration), the Slice-1 static CP SVG stands.
- **Lazy:** the component defers importing `render-svg` + first hydration until an
  `IntersectionObserver` reports the card near the viewport.
- **Re-render only on view/step change.** Hover and selection are pure CSS-class
  toggles on already-stamped `data-bel-name` elements — re-applied after each
  re-render (a re-render rebuilds the SVG DOM, so selection/hover classes are
  reasserted from component state).

### The addressing attribute: `data-bel-name`

Both sides of the link key off one attribute, `data-bel-name`, whose value is the
source variable name **without sigil** (`.center` → `center`, `--d1` → `d1`).
A crease is many segments → many SVG elements share `data-bel-name="d1"`; a
selector `[data-bel-name="d1"]` inside the card hits all of them plus the matching
code token(s).

## Provenance groundwork (enables addressing)

Most provenance already exists in FOLD (`beloch:named_points`, `beloch:named_lines`,
per-edge `beloch:edges[].name`). The addressing runs entirely on **indices, never
coordinate matching** — every name→element association is decided in OCaml where
values are exact rationals, then carried by array index through scene into
render-svg, which stamps the attribute at draw time. Gaps to close:

1. **OCaml — folded-frame edge provenance (creases).** `lib/fold_emit.ml` emits
   `beloch:edges` only in the top-level creasePattern frame (~:348); the folded step
   frames (`folded_frame_of_state`, the `` `Assoc `` ~:170-183) omit it, though
   `prov` is already computed in the folded edges tuple (~:110). Serialize
   `beloch:edges` in folded frames too, so crease `data-bel-name` (which is
   index-based off `edgesProvenance[i].name`) works in folded/stepped views, not
   just CP.
2. **OCaml — per-vertex names (points).** Emit `beloch:vertices_names`: an array
   parallel to `vertices_coords`, each entry the source point name or null. Compute
   it in the emitter by **exact `Geom` equality** between each vertex and the
   `named_points` (CP frame matches paper coords, folded frames match the point's
   `table` coord) — exact rationals, no float fuzz. This replaces the fragile
   TS-side coordinate match: the name reaches render-svg as a value at a known
   index. (Emit top-level if vertex indexing is stable across CP and folded frames;
   otherwise per-frame — the plan verifies index stability.)
3. **scene — carry both.** `render/scene/src/parse.ts` `frameFrom` already maps
   `beloch:edges` → `edgesProvenance`; once (1) emits it in folded frames the step
   frames carry `EdgeProvenance.name` for free. ADD a `verticesNames:
   (string|null)[]` to `Frame` populated from `beloch:vertices_names` (2).
4. **render-svg — stamp `data-bel-name` at draw time, by index.**
   - **Creases:** `render-cp.ts` (~:76) and `render-folded.ts` (~:141) already set
     `data-name` from `prov[i].name`. ADD `data-bel-name` with the same value
     (keep `data-name`/`data-kind` for existing consumers, e.g. marks).
   - **Vertex dots:** `render-cp.ts` (~:122-123) and the folded vertex pass draw
     anonymous `<circle>`. Stamp `data-bel-name` + `data-kind="point"` from
     `frame.verticesNames[i]` when non-null. **No coordinate comparison** — the name
     is carried by the vertex's own index.
   - **Occluded geometry stays in the DOM (folded):** the component renders folded
     with `hidden: 'dashed'` so occluded crease segments are present and carry
     `data-occluded="true"` (~render-folded.ts:157), never dropped. This is what
     lets a selected line show a ghosted occluded portion (see Interaction).
5. **Highlighter — tag code tokens.** `site/src/lib/highlight-bel.ts` (~:69) wraps
   each token as `<span class="bel-${capture}">TEXT</span>`. For point/line
   captures, also emit `data-bel-name` = the token text minus its leading `.`/`--`.
   Non-variable tokens (keywords, punctuation) get no `data-bel-name`.

## View toggle + stepper

- A control row: `[ Faltbild | Gefaltet ]` (tabs/segmented buttons). **CP is the
  default view.** The "Gefaltet" tab renders only when `scene.steps.length > 0`
  (pure-CP examples show no toggle at all).
- Folded view shows a stepper `◀ Schritt n/N ▶` (N = `scene.steps.length`),
  defaulting to the **final** step. Prev/next drives `renderFolded(scene, {step: i,
  hidden: 'dashed'})`. Switching to CP calls `renderCP(scene)`.
- Re-rendering swaps the SVG inside `.beloch-diagram`; the component then reasserts
  hover (none, transient) and the selection set's classes.

## Interaction: hover + selection

Two layers, both bidirectional (code token ⇄ diagram element):

- **Hover (transient preview):** `mouseenter`/`mouseleave` on any element with a
  `data-bel-name` (code span OR svg element) toggles `.bel-hover` on **all**
  `[data-bel-name="<name>"]` within this card. Neutral highlight, disappears on
  leave. Never persists.
- **Selection (persistent, multi):** `click` on a `.point`/`.line` code token or a
  diagram element **toggles** that name in a selection set (multiple names may be
  active at once). Active names get `.bel-selected` on all their matching elements:
  - **Code token:** a persistent background chip showing it's active.
  - **Diagram:** the point dot / crease segments highlighted persistently.
  - **Through all steps:** because selection is component state re-applied after
    every step/view re-render, a selected crease stays highlighted across the whole
    fold sequence and in CP. For a selected **line** in folded view:
    - **visible segments** → solid, full-strength highlight;
    - **occluded segments** (`data-bel-name` + `data-occluded`) → still drawn, but
      dashed and at **very low opacity** (ghosted) in the highlight colour — so the
      crease reads as continuous while showing where it's hidden.
  - Clicking an active name again deselects it. (Clicking empty diagram space does
    not clear — deselection is per-name, explicit.)

### Highlight styling — per-selection colour

Because multiple names can be selected at once, a single shared highlight colour
would make "which code token = which diagram element" ambiguous. Assign each active
name a colour from a **small fixed accessible palette** (≈5–6 hues), in selection
order, reused cyclically; the code chip and the diagram elements for that name share
the colour. Hover uses one neutral colour distinct from the selection palette. Final
hues/opacities are a styling detail to tune during implementation (light + dark),
not a design blocker.

## Error handling / edge cases

- **FOLD parse or render throws in-browser:** catch, keep the SSR static SVG,
  disable the toggle/stepper, log to console. The card degrades to Slice-1 behaviour
  rather than breaking the page.
- **No named entities:** hover/selection simply have no targets; no error.
- **No folded steps:** no toggle, CP only.
- **A named point's coordinate doesn't match any vertex** (shouldn't happen for
  exact rationals): that point is silently non-addressable; don't throw.

## Testing

- **OCaml:** a golden/unit assertion that (a) a folded step frame now carries
  `beloch:edges` with `name` for a named crease, and (b) `beloch:vertices_names`
  names the right vertex for a named point (e.g. `.center` from the two-diagonals
  example). Existing goldens update where frames gain the fields.
- **render-svg (bun):** rendering a scene with a named point stamps
  `data-bel-name` on the vertex dot (CP and folded); a named crease stamps
  `data-bel-name` on its `<line>`(s) in both CP and folded; folded occluded
  segments carry `data-occluded`. Fixture FOLD generated from OCaml.
- **highlighter (bun/site):** `highlightBel` output for `.center` / `--d1` includes
  `data-bel-name="center"` / `="d1"`; keywords do not.
- **Web Component (bun + jsdom or a DOM shim, whatever the render tests use):**
  hydrating a card wires hover class toggling; clicking a token toggles
  `.bel-selected` on both sides; stepping re-renders and re-applies the selection.
  If a full component test is impractical in the harness, cover the pure logic
  (selection-set reducer, name-extraction) as unit tests and verify the wiring by a
  site build + DOM assertion.

## Out of scope

- Getting-Started content (Slice 3).
- Playground changes (last).
- Animating the fold transition between steps (steps are discrete renders).
- Extracting the component into a standalone published package (stays site-local,
  vanilla, cleanly encapsulated).

## Task decomposition (preview for the plan)

1. OCaml: emit `beloch:edges` in folded frames + `beloch:vertices_names`
   (exact-match names) in every frame (+ tests/goldens).
2. scene: carry `verticesNames` on `Frame` from `beloch:vertices_names`
   (+ folded frames carry `edgesProvenance.name`) (+ bun tests).
3. render-svg: `data-bel-name` on vertex dots (from `verticesNames[i]`) + creases
   (from `prov[i].name`), CP + folded; confirm folded occluded geometry retained
   (+ bun tests).
4. highlighter: `data-bel-name` on variable code tokens (+ test).
5. `<beloch-figure>` Web Component: lazy hydrate, read FOLD embed, view toggle +
   stepper, re-render via render-svg.
6. Interaction + styling: bidirectional hover, multi-selection set with per-name
   palette, through-step visibility with ghosted occluded segments.

(Tasks 1–4 are the provenance groundwork the component consumes; 5–6 are the
component. 1–4 land first.)

## Risks / open questions

- **Folded edge prov correctness:** the folded frame's `prov` tuple is computed but
  never serialized — confirm it maps 1:1 to the folded `edges_vertices` order when
  emitting (index alignment).
- **Vertex-index stability across frames:** `beloch:vertices_names` is index-based;
  confirm a vertex keeps its index across the CP and folded frames (so one array
  can be reused) — if Beloch reindexes vertices per frame, emit `vertices_names`
  per-frame instead. Either way there is no coordinate matching in TS.
- **Occluded-then-selected visual:** promoting a ghosted occluded segment must not
  fight the dashed occlusion styling — CSS specificity for `.bel-selected[data-occluded]`
  needs care.
- **Component testability** in the repo's bun harness (no DOM by default) — may need
  a jsdom-style shim or a build+assert approach; decide in the plan.
```
