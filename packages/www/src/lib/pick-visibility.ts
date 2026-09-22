// The view's hit test asks the `beloch:inspect` DATA which line entities lie
// under the cursor instead of the rendered SVG. Creases that fold onto each
// other (or onto a paper edge) share their table coordinates and collapse to
// a single `<line>`, and only the data still tells them apart (see
// `lineEntitiesAtPoint` in Playground.astro). That data carries no
// occlusion, so on its own it also offers segments buried under a higher
// layer, which the renderer's `hidden: "hide"` does not draw at all.
//
// Gating a candidate on a line the renderer drew along it keeps the hit test
// in step with the picture. Under `hidden: "dashed"` or `"depth"` the buried
// run is drawn, so it stays selectable without this module knowing which
// mode is on.
import type { Vec2 } from "@beloch/scene";

// A rendered line's endpoints in SVG user space: [x1, y1, x2, y2].
export type DrawnLine = readonly [number, number, number, number];

// Distance from (px,py) to the segment a->b, clamped to the segment's ends,
// so a point beyond an endpoint measures to that endpoint rather than to the
// infinite line. In SVG user units, like everything it is compared against.
export function pointSegDist(
  px: number,
  py: number,
  ax: number,
  ay: number,
  bx: number,
  by: number,
): number {
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy;
  let t = len2 ? ((px - ax) * dx + (py - ay) * dy) / len2 : 0;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

// Is the segment p0->p1 drawn at (px,py)? True when some drawn line runs
// ALONG the segment, meaning both of its endpoints sit on it within `eps`,
// and passes within `eps` of the point.
//
// Requiring both endpoints on the segment separates the two cases that meet
// at one pixel: a partially occluded segment's visible run is a sub-run of
// it and counts, while another crease crossing here has its endpoints
// elsewhere and does not. Coincident entities keep their pick, since they
// share table coordinates with the one line the renderer drew, which
// therefore runs along each of them.
export function segmentDrawnAt(
  p0: Vec2,
  p1: Vec2,
  px: number,
  py: number,
  drawn: Iterable<DrawnLine>,
  eps: number,
): boolean {
  for (const [x1, y1, x2, y2] of drawn) {
    if (pointSegDist(px, py, x1, y1, x2, y2) > eps) continue;
    if (pointSegDist(x1, y1, p0[0], p0[1], p1[0], p1[1]) > eps) continue;
    if (pointSegDist(x2, y2, p0[0], p0[1], p1[0], p1[1]) > eps) continue;
    return true;
  }
  return false;
}
