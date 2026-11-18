// Folded-view stack picker: when several
// `beloch:inspect` crease segments coincide in the folded projection (the
// same bundle stacked across layers), order them by the frame's `faceOrders`
// so the panel lists top-of-stack first, and let a picked row's SVG line(s) be found by
// geometry. There is NO `data-seg` attribute, so a
// segment can only be re-identified by matching its `table` endpoints
// against the rendered `<line>`'s x1/y1/x2/y2, in the SAME (rendered SVG
// pixel) coordinate space. Pure, DOM-free functions so both are unit
// testable (see stack-picker.test.ts); the caller (Playground.astro) does
// the coordinate transform via `@beloch/render-svg`'s `makeLayout` and the
// actual DOM query/class toggling.
import type { FaceOrder, InspectSegment, Vec2 } from "@beloch/scene";

// Orders two segments, top of stack first (negative: `a` comes first). Each
// segment lies on two faces. `a` is above `b` when a face of `a` is above a
// face of `b` in `faceOrders`, which relates only faces that overlap; it is
// below when the reverse holds. Segments with no such pair, or with both
// directions, compare equal, so a stable sort keeps their existing order.
// The sign of a `[f, g, s]` triple is keyed to g's normal (as in
// `linearExtension` and the renderers): f is above g iff `(s > 0) === faceUp[g]`.
export function stackOrder(
  faceOrders: FaceOrder[],
  faceUp: boolean[],
): (a: InspectSegment, b: InspectSegment) => number {
  const above = new Set<string>();
  for (const [f, g, s] of faceOrders) {
    if (s === 0) continue;
    above.add((s > 0) === faceUp[g] ? `${f},${g}` : `${g},${f}`);
  }
  const over = (a: InspectSegment, b: InspectSegment): boolean =>
    a.faces.some((f) => b.faces.some((g) => above.has(`${f},${g}`)));
  return (a, b) => Number(over(b, a)) - Number(over(a, b));
}

const near = (a: Vec2, b: Vec2, eps: number): boolean =>
  Math.abs(a[0] - b[0]) <= eps && Math.abs(a[1] - b[1]) <= eps;

// Does the rendered line [x1,y1]-[x2,y2] (already in the same pixel space as
// p0/p1 — the caller transforms the segment's `table` endpoints through the
// renderer's own layout first) represent the same endpoints as p0/p1, in
// either order? A drawn crease line's endpoint order isn't guaranteed to
// match the InspectSegment's `table[0]/table[1]` order (occlusion clipping
// walks the edge parametrically from whichever vertex the frame edge lists
// first), so both orders must be checked.
export function segMatchesLine(
  p0: Vec2,
  p1: Vec2,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  eps = 0.5,
): boolean {
  return (
    (near(p0, [x1, y1], eps) && near(p1, [x2, y2], eps)) ||
    (near(p0, [x2, y2], eps) && near(p1, [x1, y1], eps))
  );
}
