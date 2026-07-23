// Entity inspector (playground slice B): maps a pointer event's target
// element on the rendered SVG back to the `beloch:inspect` entity it
// belongs to. Pure DOM lookup, no dependency on the scene/render packages,
// so it's unit-testable in isolation (see inspect-lookup.test.ts).
//
// Keyed on the data-* attributes render-scene.ts emits (data-crease-id /
// data-face-index / data-vertex — there is NO data-seg, it was dropped).
// A named vertex also carries data-bel-name on the SAME circle element
// (render-scene.ts:320,488), so the point name is read directly here
// instead of reverse-mapping through `inspect.points` by index.
//
// The "edge" variant (task 9, paper boundary lines) is NEVER produced by
// lookupEntity itself — a boundary line carries no distinguishing attribute
// (no data-crease-id), so it can only be identified by geometry. It's
// resolved by the caller (Playground.astro) via edge-lookup.ts's
// `edgeOfLine`, after lookupEntity has already returned null. The variant
// lives here anyway so every consumer (hoverSummary, segmentRows, the
// Playground handlers) shares one EntityRef import.
export type EntityRef =
  | { kind: "crease"; creaseId: string }
  | { kind: "face"; index: string }
  | { kind: "vertex"; index: number; name: string | null }
  | { kind: "edge"; name: string };

// Pulls the (1-based) line number out of a provenance span, e.g.
// `foo.bel:12:3-8` (the `file:line:col-col` format `Error.span_to_string`
// produces) → 12. Used to drive the editor↔SVG highlight in both
// directions: click an entity → jump to its line; move the cursor → outline
// the entities whose span covers that line.
export function lineOfSpan(span: string | null): number | null {
  const m = span?.match(/:(\d+):/);
  return m ? Number(m[1]) : null;
}

export function lookupEntity(el: Element): EntityRef | null {
  const line = el.closest("[data-crease-id]");
  if (line) return { kind: "crease", creaseId: line.getAttribute("data-crease-id")! };
  const face = el.closest("[data-face-index]");
  if (face) return { kind: "face", index: face.getAttribute("data-face-index")! };
  const vert = el.closest("[data-vertex]");
  if (vert) {
    return {
      kind: "vertex",
      index: Number(vert.getAttribute("data-vertex")),
      name: vert.getAttribute("data-bel-name"),
    };
  }
  return null;
}
