// Pure geometry helpers ported from tools/fold2svg.mjs — logic unchanged
// (same epsilons, same tie-breaks), typed. `foldedFrame` is deliberately not
// ported: @beloch/scene's parseFold + pickStep replace it (Task 2).
import type { FaceOrder, Isometry, LineCoeffs, Vec2 } from "@beloch/scene";

// Topologically sort faces into a bottom->top order consistent with faceOrders.
// [f,g,s]: s=+1 => f above g (edge g->f), s=-1 => f below g (edge f->g).
export function linearExtension(
  faceOrders: FaceOrder[],
  nFaces: number,
  faceUp?: boolean[],
): number[] {
  const adj: number[][] = Array.from({ length: nFaces }, () => []);
  const indeg = new Array(nFaces).fill(0);
  const addEdge = (lo: number, hi: number) => { adj[lo]!.push(hi); indeg[hi]++; }; // lo below hi
  // FOLD's faceOrders sign is relative to g's NORMAL, not global +z:
  // [f,g,+1] means f lies on the side g's normal points to. So f is globally
  // BELOW g iff (s < 0) === gUp, where gUp = g faces up (front side up, i.e.
  // det_sign > 0 ⇔ folded winding CCW). faceUp[g] carries that; when omitted
  // (all faces up) the sign reads as plain global order.
  for (const [f, g, s] of faceOrders || []) {
    if (s === 0) continue;
    const gUp = faceUp ? faceUp[g] : true;
    if ((s < 0) === gUp) addEdge(f, g); // f below g
    else addEdge(g, f);                 // g below f
  }
  const queue: number[] = [];
  for (let i = 0; i < nFaces; i++) if (indeg[i] === 0) queue.push(i);
  queue.sort((a, b) => a - b); // deterministic tie-break
  const order: number[] = [];
  while (queue.length) {
    const n = queue.shift()!;
    order.push(n);
    for (const m of adj[n]!) if (--indeg[m] === 0) {
      // insert keeping ascending index among ready nodes (stable, deterministic)
      let k = queue.length;
      while (k > 0 && queue[k - 1]! > m) k--;
      queue.splice(k, 0, m);
    }
  }
  return order;
}

// "a-b" key (sorted) -> edge index, for mapping a face outline segment to a
// FOLD edge (to recover its colour/assignment).
export function faceEdgeIndex(edgesVertices: [number, number][]): Map<string, number> {
  const m = new Map<string, number>();
  (edgesVertices || []).forEach(([a, b], i) => {
    m.set(a < b ? `${a}-${b}` : `${b}-${a}`, i);
  });
  return m;
}

// Pull a paper-frame line a·x+b·y=c back into a face's table frame, given the
// face's paper→table isometry row [m00,m01,m10,m11,tx,ty]. M is orthogonal, so
// the table-frame line is [A,B,C] with A=a·m00+b·m01, B=a·m10+b·m11,
// C=c+A·tx+B·ty. Clipping this against the face's own table polygon needs no
// per-point mapping and never touches the crease-pattern vertex indices.
export const lineToFace = (
  [m00, m01, m10, m11, tx, ty]: Isometry,
  a: number,
  b: number,
  c: number,
): LineCoeffs => {
  const A = a * m00 + b * m01;
  const B = a * m10 + b * m11;
  return [A, B, c + A * tx + B * ty];
};

// Shoelace signed area; >0 = CCW (front side up in folded coords).
export function signedArea(poly: Vec2[]): number {
  let s = 0;
  for (let i = 0; i < poly.length; i++) {
    const [x1, y1] = poly[i]!, [x2, y2] = poly[(i + 1) % poly.length]!;
    s += x1 * y2 - x2 * y1;
  }
  return s / 2;
}

export function sideUp(poly: Vec2[]): "front" | "back" {
  return signedArea(poly) >= 0 ? "front" : "back";
}

// Ray-casting point-in-polygon (boundary counts as inside is not required here).
export function pointInPolygon(pt: Vec2, poly: Vec2[]): boolean {
  const [x, y] = pt;
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i]!, [xj, yj] = poly[j]!;
    const hit = (yi > y) !== (yj > y) &&
      x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
    if (hit) inside = !inside;
  }
  return inside;
}

// Same test, but a point ON an edge (within eps) also counts as inside.
// pointInPolygon's ray-cast is undefined right on a boundary — fine for its
// existing callers, but a Beloch mark's endpoints are usually constructed to
// land exactly on a face's boundary (an existing crease or the paper edge),
// so the strict test rejects the common case. Used only by the mark-overlay
// projection (render-scene.ts) — pointInPolygon's other callers (occlusion
// checks) keep the strict behavior their design comment calls out.
export function pointInPolygonInclusive(pt: Vec2, poly: Vec2[], eps = 1e-9): boolean {
  if (pointInPolygon(pt, poly)) return true;
  const [x, y] = pt;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i]!, [xj, yj] = poly[j]!;
    const dx = xj - xi, dy = yj - yi;
    const len2 = dx * dx + dy * dy;
    if (len2 < eps) continue;
    const t = Math.max(0, Math.min(1, ((x - xi) * dx + (y - yi) * dy) / len2));
    const px = xi + t * dx, py = yi + t * dy;
    if ((px - x) * (px - x) + (py - y) * (py - y) < eps) return true;
  }
  return false;
}

// Parameter sub-intervals [t0,t1] of segment a→b that lie inside `poly`.
// Breakpoints are the segment's crossings of the polygon's edges; each gap is
// classified inside/outside by its midpoint. Works for convex or non-convex,
// CW or CCW polygons. Returns merged intervals in [0,1].
export function segInsideIntervals(a: Vec2, b: Vec2, poly: Vec2[]): [number, number][] {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const ts = [0, 1];
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const c = poly[j]!, d = poly[i]!;
    const ex = d[0] - c[0], ey = d[1] - c[1];
    const denom = dx * ey - dy * ex;
    if (Math.abs(denom) < 1e-12) continue; // parallel/collinear
    const wx = c[0] - a[0], wy = c[1] - a[1];
    const t = (wx * ey - wy * ex) / denom; // along a→b
    const u = (wx * dy - wy * dx) / denom; // along the polygon edge
    if (t > 1e-9 && t < 1 - 1e-9 && u >= -1e-9 && u <= 1 + 1e-9) ts.push(t);
  }
  ts.sort((p, q) => p - q);
  const out: [number, number][] = [];
  for (let k = 0; k < ts.length - 1; k++) {
    const t0 = ts[k]!, t1 = ts[k + 1]!;
    if (t1 - t0 < 1e-9) continue;
    const tm = (t0 + t1) / 2;
    if (pointInPolygon([a[0] + dx * tm, a[1] + dy * tm], poly)) {
      const last = out[out.length - 1];
      if (last && t0 - last[1] < 1e-9) last[1] = t1; // merge adjacent
      else out.push([t0, t1]);
    }
  }
  return out;
}

// Sub-intervals of segment a→b hidden by a face strictly above (or, for the
// bottom view, below) `refPos` in the stack order — the union over all such
// covering faces.
export function coveredIntervals(
  a: Vec2,
  b: Vec2,
  order: number[],
  refPos: number,
  F: number[][],
  V: Vec2[],
  below = false,
): [number, number][] {
  const spans: [number, number][] = [];
  const from = below ? refPos - 1 : refPos + 1;
  const step = below ? -1 : 1;
  for (let pos = from; pos >= 0 && pos < order.length; pos += step) {
    for (const iv of segInsideIntervals(a, b, F[order[pos]!]!.map((i) => V[i]!))) spans.push(iv);
  }
  if (!spans.length) return spans;
  spans.sort((p, q) => p[0] - q[0]);
  const merged: [number, number][] = [spans[0]!.slice() as [number, number]];
  for (let k = 1; k < spans.length; k++) {
    const last = merged[merged.length - 1]!;
    if (spans[k]![0] <= last[1] + 1e-9) last[1] = Math.max(last[1], spans[k]![1]);
    else merged.push(spans[k]!.slice() as [number, number]);
  }
  return merged;
}

// True if point `p` is hidden by a face strictly above (or, for the bottom
// view, below) `refPos` in the stack order — the point analogue of
// coveredIntervals, used to occlude named-vertex dots and labels.
export function pointCovered(
  p: Vec2,
  order: number[],
  refPos: number,
  F: number[][],
  V: Vec2[],
  below = false,
): boolean {
  const from = below ? refPos - 1 : refPos + 1;
  const step = below ? -1 : 1;
  for (let pos = from; pos >= 0 && pos < order.length; pos += step) {
    if (pointInPolygon(p, F[order[pos]!]!.map((i) => V[i]!))) return true;
  }
  return false;
}

// clip line ax+by=c to bounding box
export function clipLineBox(
  a: number,
  b: number,
  c: number,
  x0: number,
  x1: number,
  y0: number,
  y1: number,
): [Vec2, Vec2] | null {
  const eps = 1e-9, pts: Vec2[] = [];
  const tryX = (x: number) => { if (Math.abs(b) > eps) { const y = (c - a * x) / b; if (y >= y0 - eps && y <= y1 + eps) pts.push([x, y]); } };
  const tryY = (y: number) => { if (Math.abs(a) > eps) { const x = (c - b * y) / a; if (x >= x0 - eps && x <= x1 + eps) pts.push([x, y]); } };
  tryX(x0); tryX(x1); tryY(y0); tryY(y1);
  const uniq = pts.filter((p, i) => !pts.slice(0, i).some((q) => Math.abs(p[0] - q[0]) < eps && Math.abs(p[1] - q[1]) < eps));
  return uniq.length >= 2 ? [uniq[0]!, uniq[uniq.length - 1]!] : null;
}

// clip line ax+by=c to a convex polygon [[x,y],...]; returns [p1,p2] in paper space or null
export function clipLineToPoly(
  a: number,
  b: number,
  c: number,
  poly: Vec2[],
): [Vec2, Vec2] | null {
  const eps = 1e-9, n = poly.length, pts: Vec2[] = [];
  for (let i = 0; i < n; i++) {
    const [x1, y1] = poly[i]!, [x2, y2] = poly[(i + 1) % n]!;
    const d = a * (x2 - x1) + b * (y2 - y1);
    if (Math.abs(d) < eps) continue;
    const t = (c - a * x1 - b * y1) / d;
    if (t >= -eps && t <= 1 + eps) pts.push([x1 + t * (x2 - x1), y1 + t * (y2 - y1)]);
  }
  const uniq = pts.filter((p, i) => !pts.slice(0, i).some((q) => Math.hypot(p[0] - q[0], p[1] - q[1]) < 1e-8));
  return uniq.length >= 2 ? [uniq[0]!, uniq[uniq.length - 1]!] : null;
}
