// Folded-view stack picker (playground slice B, task 7): when several
// `beloch:inspect` crease segments coincide in the folded projection (the
// same bundle stacked across layers), order them by layer rank so the panel
// lists top-of-stack first, and let a picked row's SVG line(s) be found by
// geometry — there is NO `data-seg` attribute (dropped in Task 4), so a
// segment can only be re-identified by matching its `table` endpoints
// against the rendered `<line>`'s x1/y1/x2/y2, in the SAME (rendered SVG
// pixel) coordinate space. Pure, DOM-free functions so both are unit
// testable (see stack-picker.test.ts); the caller (Playground.astro) does
// the coordinate transform via `@beloch/render-svg`'s `makeLayout` and the
// actual DOM query/class toggling.
import type { Inspect, InspectSegment, Vec2 } from "@beloch/scene";

// A segment's layer identity = the higher of its two bounding faces' rank
// (Fold_state.rank — stacking order, higher = closer to viewer). `insp.faces`
// is keyed by string index; a face absent from it (shouldn't happen for a
// valid scene) falls back to 0 rather than throwing.
export function segRank(insp: Inspect, s: InspectSegment): number {
  return Math.max(
    insp.faces[String(s.faces[0])]?.rank ?? 0,
    insp.faces[String(s.faces[1])]?.rank ?? 0,
  );
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
