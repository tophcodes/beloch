// How the model is turned on the page at a state: the `@orient` annotations
// of spec/BELOCH-ANNOTATIONS.md, read into one rotation of the table plane.
import type { Annotation, FoldScene, Frame, Vec2 } from "./types";

const DIRECTION: Record<string, number> = {
  right: 0, up: Math.PI / 2, left: Math.PI, down: -Math.PI / 2,
};
const AXIS: Record<string, number> = { horizontal: 0, vertical: Math.PI / 2 };

// An angle in (-π, π].
const wrap = (t: number): number => {
  const r = t - 2 * Math.PI * Math.floor((t + Math.PI) / (2 * Math.PI));
  return r <= -Math.PI ? r + 2 * Math.PI : r;
};

// The centroid of the region the faces of a frame cover on the table, each
// point counted once however many layers lie on it. Between two consecutive
// heights at which a vertex lies or two edges cross, the covered width along a
// horizontal line is linear in the height, so two-point Gauss-Legendre
// quadrature over each such slab integrates area and moments exactly. Known
// ceiling: the crossings are found over every pair of edges, O(E²) in the
// edge count, which a few hundred edges keep under a millisecond.
export function outlineCentroid(frame: Frame): Vec2 {
  const polys = frame.facesVertices.map((f) => f.map((i) => frame.vertices[i]!));
  const edges = polys.flatMap((p) => p.map((v, k): [Vec2, Vec2] => [v, p[(k + 1) % p.length]!]));
  const ys = polys.flat().map((v) => v[1]);
  for (let i = 0; i < edges.length; i++) {
    const [p, q] = edges[i]!;
    for (let j = i + 1; j < edges.length; j++) {
      const [r, s] = edges[j]!;
      const d = (q[0] - p[0]) * (s[1] - r[1]) - (q[1] - p[1]) * (s[0] - r[0]);
      if (Math.abs(d) < 1e-12) continue;
      const t = ((r[0] - p[0]) * (s[1] - r[1]) - (r[1] - p[1]) * (s[0] - r[0])) / d;
      const u = ((r[0] - p[0]) * (q[1] - p[1]) - (r[1] - p[1]) * (q[0] - p[0])) / d;
      if (t > 0 && t < 1 && u > 0 && u < 1) ys.push(p[1] + t * (q[1] - p[1]));
    }
  }
  ys.sort((a, b) => a - b);
  // The covered intervals along the horizontal line at height y, merged.
  const covered = (y: number): [number, number][] => {
    const spans: [number, number][] = [];
    for (const p of polys) {
      const xs: number[] = [];
      p.forEach((a, k) => {
        const b = p[(k + 1) % p.length]!;
        if ((a[1] - y) * (b[1] - y) < 0) xs.push(a[0] + ((y - a[1]) / (b[1] - a[1])) * (b[0] - a[0]));
      });
      xs.sort((a, b) => a - b);
      for (let k = 0; k + 1 < xs.length; k += 2) spans.push([xs[k]!, xs[k + 1]!]);
    }
    spans.sort((a, b) => a[0] - b[0]);
    const merged: [number, number][] = [];
    for (const s of spans) {
      const last = merged[merged.length - 1];
      if (last && s[0] <= last[1]) last[1] = Math.max(last[1], s[1]);
      else merged.push([s[0], s[1]]);
    }
    return merged;
  };
  let area = 0, mx = 0, my = 0;
  const node = 1 / Math.sqrt(3);
  for (let k = 0; k + 1 < ys.length; k++) {
    const y0 = ys[k]!, y1 = ys[k + 1]!;
    if (y1 - y0 < 1e-12) continue;
    const mid = (y0 + y1) / 2, half = (y1 - y0) / 2;
    for (const y of [mid - half * node, mid + half * node]) {
      for (const [x0, x1] of covered(y)) {
        area += half * (x1 - x0);
        mx += half * (x1 * x1 - x0 * x0) / 2;
        my += half * y * (x1 - x0);
      }
    }
  }
  return area > 0 ? [mx / area, my / area] : [0, 0];
}

// The rotation one `@orient` fixes, given the rotation in force before it.
// Null for an annotation whose arguments name no direction, which the kernel
// refuses before it writes a FOLD.
function rotationOf(scene: FoldScene, a: Annotation, current: number): number | null {
  const last = a.args[a.args.length - 1];
  if (last?.kind !== "word") return null;
  const line = a.args[0];
  if (line?.kind === "line" && AXIS[last.word] !== undefined) {
    const [la, lb] = line.coeffs;
    const turn = wrap(AXIS[last.word]! - Math.atan2(-la, lb));
    const other = wrap(turn + Math.PI);
    return Math.abs(wrap(turn - current)) <= Math.abs(wrap(other - current)) ? turn : other;
  }
  const want = DIRECTION[last.word];
  if (want === undefined) return null;
  const points = a.args.filter((x) => x.kind === "point").map((x) => x.table);
  const frame = scene.steps[a.frameIndex]?.frame;
  const from = points.length === 2 ? points[0] : frame ? outlineCentroid(frame) : undefined;
  const to = points[points.length - 1];
  if (!from || !to) return null;
  const dx = to[0] - from[0], dy = to[1] - from[1];
  if (Math.hypot(dx, dy) < 1e-12) return null;
  return wrap(want - Math.atan2(dy, dx));
}

// The counterclockwise rotation, in radians, that turns the table plane of
// state `frameIndex` (an index into scene.steps) onto the page. An `@orient`
// turns the state its statement starts from and every later one, until the
// next `@orient`; the rotation it fixes on its own state holds unchanged on
// the later ones. 0 before the first `@orient`.
export function orientationAt(scene: FoldScene, frameIndex: number): number {
  let turn = 0;
  for (const a of scene.annotations) {
    if (a.namespace !== null || a.key !== "orient" || a.frameIndex > frameIndex) continue;
    turn = rotationOf(scene, a, turn) ?? turn;
  }
  return turn;
}
