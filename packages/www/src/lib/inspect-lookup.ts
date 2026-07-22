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
export type EntityRef =
  | { kind: "crease"; creaseId: string }
  | { kind: "face"; index: string }
  | { kind: "vertex"; index: number; name: string | null };

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
