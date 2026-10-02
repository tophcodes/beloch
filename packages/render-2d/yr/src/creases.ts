// The existing creases of a panel [lang1991conventions, Part II, figure 4]:
// every crease of the state that lies flat, and every scored line that is no
// edge of it yet, where no higher layer covers it. A crease ends with a gap
// before an edge it ends on and touches an edge it runs under.
import type { FoldScene, Vec2 } from "@beloch/scene";
import {
  clipSegmentToPoly, coveredIntervals, faceEdgeIndex, pointCovered, resolveIsometry, toPaper, toTable,
} from "@beloch/render-svg";

// The gap, in page pixels, between a crease and the edge it ends on.
export const CREASE_GAP = 6;

const EPS = 1e-9;

interface Run { p: Vec2; q: Vec2; ref: number; }

const distanceToSegment = (r: Vec2, [a, b]: [Vec2, Vec2]): number => {
  const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy;
  const t = l2 ? Math.max(0, Math.min(1, ((r[0] - a[0]) * dx + (r[1] - a[1]) * dy) / l2)) : 0;
  return Math.hypot(r[0] - a[0] - t * dx, r[1] - a[1] - t * dy);
};

// The existing creases of state `base` (an index into scene.steps), with the
// scored lines `marks` given in paper coordinates, as page segments through
// `px`, each end pulled back by CREASE_GAP where it ends on an edge.
export function existingCreaseSegments(
  scene: FoldScene, base: number, marks: [Vec2, Vec2][], px: (table: Vec2) => Vec2,
): [Vec2, Vec2][] {
  const frame = scene.steps[base]!.frame;
  const { order } = resolveIsometry(scene, { kind: "step", index: base });
  const V = frame.vertices, F = frame.facesVertices, E = frame.edgesVertices, A = frame.edgesAssignment;
  const pos = new Map(order.map((f, i) => [f, i]));
  const poly = (f: number) => F[f]!.map((i) => V[i]!);

  const incident: number[][] = E.map(() => []);
  const index = faceEdgeIndex(E);
  F.forEach((face, f) => face.forEach((a, k) => {
    const b = face[(k + 1) % face.length]!;
    const e = index.get(a < b ? `${a}-${b}` : `${b}-${a}`);
    if (e !== undefined) incident[e]!.push(f);
  }));
  // An edge lies flat when paper lies on both sides of it; every other edge
  // is an edge of the model, which the panel draws in ink.
  const centroid = (f: number): Vec2 => {
    const p = poly(f);
    return [p.reduce((s, v) => s + v[0], 0) / p.length, p.reduce((s, v) => s + v[1], 0) / p.length];
  };
  const flat = (e: number): boolean => {
    const [a, b] = [V[E[e]![0]]!, V[E[e]![1]]!];
    const sides = incident[e]!.map((f) => {
      const c = centroid(f);
      return Math.sign((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]));
    });
    return sides.includes(1) && sides.includes(-1);
  };
  const inkEdges: [Vec2, Vec2][] = [];
  const pieces: Run[] = [];
  E.forEach(([u, v], e) => {
    if (incident[e]!.length === 0) return;
    const seg: [Vec2, Vec2] = [V[u]!, V[v]!];
    if (A[e] === "B" || !flat(e)) inkEdges.push(seg);
    else if (A[e] !== "J") pieces.push({ p: seg[0], q: seg[1], ref: Math.max(...incident[e]!.map((f) => pos.get(f)!)) });
  });
  F.forEach((_, f) => {
    const M = frame.facesMatrix?.[f];
    const paper = M ? poly(f).map((p) => toPaper(M, p)) : poly(f);
    for (const [a, b] of marks) {
      const cut = clipSegmentToPoly(a, b, paper);
      if (cut) pieces.push({ p: M ? toTable(M, cut[0]) : cut[0], q: M ? toTable(M, cut[1]) : cut[1], ref: pos.get(f)! });
    }
  });

  const out: [Vec2, Vec2][] = [];
  for (const { p, q, ref } of pieces) {
    const lerp = (t: number): Vec2 => [p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t];
    let cursor = 0;
    const visible: [number, number][] = [];
    for (const [c0, c1] of coveredIntervals(p, q, order, ref, F, V)) {
      if (c0 - cursor > EPS) visible.push([cursor, c0]);
      cursor = Math.max(cursor, c1);
    }
    if (1 - cursor > EPS) visible.push([cursor, 1]);
    const len = Math.hypot(q[0] - p[0], q[1] - p[1]);
    const ux = (q[0] - p[0]) / len, uy = (q[1] - p[1]) / len;
    // An end gets a gap when it lies on an edge of the model and the crease
    // does not run on under a higher layer past it.
    const endsOnEdge = (r: Vec2, outward: number): boolean => {
      const beyond: Vec2 = [r[0] + outward * ux * 1e-6, r[1] + outward * uy * 1e-6];
      if (pointCovered(beyond, order, ref, F, V)) return false;
      return inkEdges.some((s) => distanceToSegment(r, s) < 1e-7);
    };
    for (const [t0, t1] of visible) {
      const a = lerp(t0), b = lerp(t1);
      const pa = px(a), pb = px(b);
      const L = Math.hypot(pb[0] - pa[0], pb[1] - pa[1]);
      if (L < EPS) continue;
      const gap = Math.min(CREASE_GAP, L / 4);
      const vx = (pb[0] - pa[0]) / L, vy = (pb[1] - pa[1]) / L;
      const g0 = endsOnEdge(a, -1) ? gap : 0, g1 = endsOnEdge(b, 1) ? gap : 0;
      out.push([[pa[0] + vx * g0, pa[1] + vy * g0], [pb[0] - vx * g1, pb[1] - vy * g1]]);
    }
  }
  return out;
}
