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
// One model for what a reader can point at, held by @beloch/runtime: the
// playground, the drawing and the editor all name the same things.
export type { EntityRef } from "@beloch/runtime";
import type { EntityRef } from "@beloch/runtime";

// Spans are the editor module's: it reads them in both directions, and one
// parser is what keeps a mark and a lookup saying the same thing about a
// piece of text.
export { lineOfSpan } from "@beloch/runtime-editor";

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
