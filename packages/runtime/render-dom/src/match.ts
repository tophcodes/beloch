// Matching drawn lines against the geometry in `beloch:inspect`, in the SVG's
// own user space. Both directions are needed because a drawn line carries only
// part of its identity: a crease line names its bundle in `data-crease-id`, a
// paper boundary names nothing, and no line says which segment of its bundle
// it is. What closes the gap is the coordinates, run through the same layout
// the renderer used.
import type { Inspect, Vec2 } from "@beloch/scene";

// A drawn line's endpoints in SVG user space: [x1, y1, x2, y2].
export type DrawnLine = readonly [number, number, number, number];

// The part of the renderer's layout this needs: world to pixel, both axes.
export interface PixelTransform {
  tx: (x: number) => number;
  ty: (y: number) => number;
}

// Distance from (px,py) to the segment a->b, clamped to the segment's ends, so
// a point beyond an endpoint measures to that endpoint rather than to the
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

const near = (a: Vec2, b: Vec2, eps: number): boolean =>
  Math.abs(a[0] - b[0]) <= eps && Math.abs(a[1] - b[1]) <= eps;

// Does the drawn line [x1,y1]-[x2,y2] have the endpoints p0/p1, in either
// order? Both orders have to be checked: occlusion clipping walks an edge from
// whichever vertex the frame lists first, so the drawn order is unrelated to
// the order a segment records its ends in.
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

// Which paper-edge bundle (by name, "ab") the drawn line belongs to, or null
// for none. Every segment of every edge is checked, since a crossing crease
// splits an edge into several.
export function edgeOfLine(
  edges: Inspect["edges"],
  line: DrawnLine,
  layout: PixelTransform,
): string | null {
  const [x1, y1, x2, y2] = line;
  for (const [name, edge] of Object.entries(edges)) {
    for (const seg of edge.segments) {
      const p0: Vec2 = [layout.tx(seg.table[0][0]), layout.ty(seg.table[0][1])];
      const p1: Vec2 = [layout.tx(seg.table[1][0]), layout.ty(seg.table[1][1])];
      if (segMatchesLine(p0, p1, x1, y1, x2, y2)) return name;
    }
  }
  return null;
}
