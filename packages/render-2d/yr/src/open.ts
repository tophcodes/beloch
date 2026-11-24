// A flat state drawn as if it had been let go: its folds stand open by a
// small angle and the layers lift apart, seen from slightly above
// [lang1991conventions, Part I, "Show multiple layers whenever possible"].
//
// Every vertex gets a height. Wherever two faces overlap, the upper one in the
// layer order lies higher than the lower one at each corner of their overlap,
// by tan(angle) times that corner's distance from the nearest hinge
// that wraps around one of the two, and by no more than `step`: no gap opens
// at a hinge, nor between the layers inside it, and far from a hinge a layer
// keeps its shape and moves by `step`. A vertex is one point of the paper, so a hinge keeps one
// height and stays in place. The heights
// are relaxed toward zero under these conditions: each round pushes the
// vertices of every violated pair apart, and a share of every height decays,
// until no condition is violated. The faces bend slightly where rigid paper
// could not open, and no layer passes through another. The drawing moves
// every vertex by its height along a direction the caller gives, and every
// other point, such as a crease or an arrow, with the topmost face under it.
//
// Known limitation: the relaxation runs a fixed number of rounds, and a crease
// or an arrow moves by its two ends, so one that crosses faces of different
// heights runs straight where the paper under it bends.
import type { Frame, Vec2 } from "@beloch/scene";
import { linearExtension, pointInPolygonInclusive, sideUp } from "@beloch/render-svg";

const ROUNDS = 400, DECAY = 0.02, EPS = 1e-9;

// A point of a face as weights over the face's vertices.
type Weights = [number, number][];

// The weights of `p` in the convex face `face`, by a fan of triangles from its
// first corner; null when `p` is outside it.
function weights(face: number[], V: Vec2[], p: Vec2): Weights | null {
  const a = V[face[0]!]!;
  for (let k = 1; k + 1 < face.length; k++) {
    const b = V[face[k]!]!, c = V[face[k + 1]!]!;
    const d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1]);
    if (Math.abs(d) < EPS) continue;
    const l1 = ((b[1] - c[1]) * (p[0] - c[0]) + (c[0] - b[0]) * (p[1] - c[1])) / d;
    const l2 = ((c[1] - a[1]) * (p[0] - c[0]) + (a[0] - c[0]) * (p[1] - c[1])) / d;
    const l3 = 1 - l1 - l2;
    if (l1 > -1e-7 && l2 > -1e-7 && l3 > -1e-7) return [[face[0]!, l1], [face[k]!, l2], [face[k + 1]!, l3]];
  }
  return null;
}

const segmentDistance = (p: Vec2, a: Vec2, b: Vec2): number => {
  const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy;
  const t = l2 ? Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)) : 0;
  return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy);
};

// Where the segment from a to b crosses the segment from c to d, if it does.
function crossing(a: Vec2, b: Vec2, c: Vec2, d: Vec2): Vec2 | null {
  const r: Vec2 = [b[0] - a[0], b[1] - a[1]], s: Vec2 = [d[0] - c[0], d[1] - c[1]];
  const den = r[0] * s[1] - r[1] * s[0];
  if (Math.abs(den) < EPS) return null;
  const t = ((c[0] - a[0]) * s[1] - (c[1] - a[1]) * s[0]) / den;
  const u = ((c[0] - a[0]) * r[1] - (c[1] - a[1]) * r[0]) / den;
  return t > EPS && t < 1 - EPS && u > EPS && u < 1 - EPS ? [a[0] + t * r[0], a[1] + t * r[1]] : null;
}

interface Contact { upper: Weights; lower: Weights; gap: number; }

// `frame` drawn let go, with every fold open by `angle` degrees, no step
// between two layers larger than `step`, and a unit of height moving a point
// by `lift` on the table, with `move`, which carries a point of the flat state
// to where the drawing puts it.
export function openFrame(
  frame: Frame, angle: number, lift: Vec2, step = Infinity,
): { frame: Frame; move: (p: Vec2) => Vec2 } {
  const V = frame.vertices, F = frame.facesVertices;
  const faceUp = F.map((f) => sideUp(f.map((i) => V[i]!)) === "front");
  const order = linearExtension(frame.faceOrders, F.length, faceUp);
  const height = new Map(order.map((f, i) => [f, i]));   // 0 is the bottom layer
  const slope = Math.tan((angle * Math.PI) / 180);
  // the folded hinges on each face's boundary, with the face across each
  const key = (a: number, b: number) => `${Math.min(a, b)}-${Math.max(a, b)}`;
  const across = new Map<string, number[]>();
  F.forEach((face, f) => face.forEach((v, k) => {
    const e = key(v, face[(k + 1) % face.length]!);
    across.set(e, [...(across.get(e) ?? []), f]);
  }));
  const folded = new Set(frame.edgesVertices.flatMap(([a, b], e) => {
    const k = frame.edgesAssignment[e];
    return k === "M" || k === "V" ? [key(a, b)] : [];
  }));
  interface Hinge { seg: [Vec2, Vec2]; other: number; }
  const hinges: Hinge[][] = F.map((face, f) => face.flatMap((v, k): Hinge[] => {
    const w = face[(k + 1) % face.length]!;
    const other = (across.get(key(v, w)) ?? []).find((g) => g !== f);
    return folded.has(key(v, w)) && other !== undefined ? [{ seg: [V[v]!, V[w]!], other }] : [];
  }));
  const h = (f: number) => height.get(f) ?? 0;

  // A height is linear on each triangle of a face's fan, so the difference of
  // two faces is linear on each overlap of two of their triangles, and holds
  // everywhere once it holds at the corners of those overlaps.
  const fan = (f: number): Vec2[][] =>
    F[f]!.slice(1, -1).map((_, k) => [V[F[f]![0]!]!, V[F[f]![k + 1]!]!, V[F[f]![k + 2]!]!]);
  const overlapCorners = (P: Vec2[], Q: Vec2[]): Vec2[] => {
    const corners: Vec2[] = [
      ...P.filter((p) => pointInPolygonInclusive(p, Q)),
      ...Q.filter((q) => pointInPolygonInclusive(q, P)),
    ];
    P.forEach((a, i) => Q.forEach((c, j) => {
      const x = crossing(a, P[(i + 1) % P.length]!, c, Q[(j + 1) % Q.length]!);
      if (x) corners.push(x);
    }));
    return corners;
  };

  // the corners of every overlap, with the gap the upper face keeps there
  const contacts: Contact[] = [];
  for (const [f0, g0] of frame.faceOrders) {
    const [hi, lo] = (height.get(f0) ?? 0) > (height.get(g0) ?? 0) ? [f0, g0] : [g0, f0];
    const corners = fan(hi).flatMap((P) => fan(lo).flatMap((Q) => overlapCorners(P, Q)));
    // A hinge closes the gap between the two faces where it wraps around one
    // of them: a hinge of the upper face to a face at or below the lower one,
    // or of the lower face to a face at or above the upper one. Two faces no
    // hinge wraps close toward any hinge of theirs.
    const wraps = [
      ...hinges[hi]!.filter(({ other }) => h(other) <= h(lo)),
      ...hinges[lo]!.filter(({ other }) => h(other) >= h(hi)),
    ];
    const pins = (wraps.length ? wraps : [...hinges[hi]!, ...hinges[lo]!]).map(({ seg }) => seg);
    for (const p of corners) {
      const upper = weights(F[hi]!, V, p), lower = weights(F[lo]!, V, p);
      if (!upper || !lower) continue;
      const d = Math.min(...pins.map(([a, b]) => segmentDistance(p, a, b)));
      contacts.push({ upper, lower, gap: Math.min(step, slope * (Number.isFinite(d) ? d : 0)) });
    }
  }

  // relax: decay every height, then push apart each contact that is violated
  const z = V.map(() => 0);
  const at = (w: Weights) => w.reduce((s, [v, t]) => s + t * z[v]!, 0);
  for (let round = 0; round < ROUNDS; round++) {
    if (round < ROUNDS / 2) for (let v = 0; v < z.length; v++) z[v]! *= 1 - DECAY;
    for (const { upper, lower, gap } of contacts) {
      const c = at(upper) - at(lower) - gap;
      if (c >= 0) continue;
      // the step that closes c, spread over the vertices by their weights
      const norm = upper.reduce((s, [, t]) => s + t * t, 0) + lower.reduce((s, [, t]) => s + t * t, 0);
      if (norm < EPS) continue;
      const push = -c / norm;
      for (const [v, t] of upper) z[v]! += push * t;
      for (const [v, t] of lower) z[v]! -= push * t;
    }
  }
  // A deep stack would add a step per layer and tilt its top layer out of
  // shape. Heights above the lowest point are pressed into two steps by a
  // function that only rises, so a higher point stays higher and no layer
  // passes through another.
  const floor = Math.min(0, ...z), ceiling = 2 * step;
  const press = (h: number) => (Number.isFinite(ceiling) ? ceiling * Math.tanh((h - floor) / ceiling) : h - floor);
  const shift = (p: Vec2, h: number): Vec2 => [p[0] + press(h) * lift[0], p[1] + press(h) * lift[1]];
  const moved = V.map((p, v) => shift(p, z[v]!));

  // The center of the bounding box stays where it was, so that a turn about
  // that center places the moved state where it places the flat one.
  const center = (P: Vec2[]): Vec2 => {
    const xs = P.map((p) => p[0]), ys = P.map((p) => p[1]);
    return [(Math.min(...xs) + Math.max(...xs)) / 2, (Math.min(...ys) + Math.max(...ys)) / 2];
  };
  const [c0, c1] = [center(V), center(moved)];
  const back = (p: Vec2): Vec2 => [p[0] + c0[0] - c1[0], p[1] + c0[1] - c1[1]];

  // A point of the table moves with the topmost face that holds it; a point
  // off the paper moves with the vertex nearest to it.
  const top = [...order].reverse();
  const move = (p: Vec2): Vec2 => {
    for (const f of top) {
      const w = weights(F[f]!, V, p);
      if (w) return back(shift(p, w.reduce((s, [v, t]) => s + t * z[v]!, 0)));
    }
    let near = 0;
    V.forEach((q, v) => {
      if (Math.hypot(q[0] - p[0], q[1] - p[1]) < Math.hypot(V[near]![0] - p[0], V[near]![1] - p[1])) near = v;
    });
    return back(shift(p, z[near] ?? 0));
  };
  return { frame: { ...frame, vertices: moved.map(back) }, move };
}

// `frame` with every two visible raw edges that meet on one line of the
// table, from faces on its two sides, drawn apart by a wedge-shaped gap
// [lang1991conventions, Part I, figure 3]: closed at
// the end more faces meet at, `width` wide at the other, so that the layer
// below shows through it. Edges a higher layer covers stay where they are. A
// vertex both edges end at is one point of the paper and stays too. Returns
// `move`, which carries a point of `frame` along with the face under it.
//
// Known limitation: an edge whose two ends have as many faces closes at
// neither and steps back by half the width along its length; an end of an
// edge is a vertex other edges share, so those edges bend with it.
export function gapFrame(frame: Frame, width: number): { frame: Frame; move: (p: Vec2) => Vec2 } {
  const V = frame.vertices, F = frame.facesVertices, E = frame.edgesVertices;
  const faceUp = F.map((f) => sideUp(f.map((i) => V[i]!)) === "front");
  const order = linearExtension(frame.faceOrders, F.length, faceUp);
  const faceOf = E.map(() => -1);
  const facesAt = V.map(() => 0);
  const key = (a: number, b: number) => `${Math.min(a, b)}-${Math.max(a, b)}`;
  const edgeIx = new Map(E.map(([a, b], e) => [key(a, b), e]));
  F.forEach((face, f) => face.forEach((v, k) => {
    facesAt[v]! += 1;
    const e = edgeIx.get(key(v, face[(k + 1) % face.length]!));
    if (e !== undefined) faceOf[e] = f;
  }));
  const centroid = (f: number): Vec2 => {
    const ps = F[f]!.map((i) => V[i]!);
    return [ps.reduce((s, p) => s + p[0], 0) / ps.length, ps.reduce((s, p) => s + p[1], 0) / ps.length];
  };

  const top = [...order].reverse();
  const topmost = (p: Vec2) => top.find((f) => weights(F[f]!, V, p) !== null);

  // each visible raw edge with its line and the unit normal into its face; an
  // edge is visible when its own face is the topmost one just inside its middle
  const raw = E.flatMap(([a, b], e) => {
    if (frame.edgesAssignment[e] !== "B" || faceOf[e]! < 0) return [];
    const p = V[a]!, q = V[b]!, l = Math.hypot(q[0] - p[0], q[1] - p[1]);
    const u: Vec2 = [(q[0] - p[0]) / l, (q[1] - p[1]) / l];
    let n: Vec2 = [-u[1], u[0]];
    const c = centroid(faceOf[e]!);
    if ((c[0] - p[0]) * n[0] + (c[1] - p[1]) * n[1] < 0) n = [-n[0], -n[1]];
    const inside: Vec2 = [(p[0] + q[0]) / 2 + n[0] * l * 1e-4, (p[1] + q[1]) / 2 + n[1] * l * 1e-4];
    return topmost(inside) === faceOf[e] ? [{ a, b, p, u, n }] : [];
  });

  const shifts: Vec2[][] = V.map(() => []);
  for (const x of raw) {
    // a raw edge meets another when that one lies on its line, overlaps it,
    // and has its paper on the other side
    const meets = raw.some((y) => y !== x
      && Math.abs((y.p[0] - x.p[0]) * x.n[0] + (y.p[1] - x.p[1]) * x.n[1]) < 1e-7
      && x.n[0] * y.n[0] + x.n[1] * y.n[1] < -1 + 1e-7
      && (() => {
        const t = (v: number) => (V[v]![0] - x.p[0]) * x.u[0] + (V[v]![1] - x.p[1]) * x.u[1];
        const [s0, s1] = [t(x.a), t(x.b)].sort((i, j) => i - j), [r0, r1] = [t(y.a), t(y.b)].sort((i, j) => i - j);
        return Math.min(s1!, r1!) - Math.max(s0!, r0!) > 1e-7;
      })());
    if (!meets) continue;
    // each edge steps back by half the gap
    let [da, db] = [width / 4, width / 4];
    if (facesAt[x.a] !== facesAt[x.b]) [da, db] = facesAt[x.a]! > facesAt[x.b]! ? [0, width / 2] : [width / 2, 0];
    shifts[x.a]!.push([x.n[0] * da, x.n[1] * da]);
    shifts[x.b]!.push([x.n[0] * db, x.n[1] * db]);
  }
  // a vertex edges move apart stays; otherwise it takes the largest step
  const shift = shifts.map((ss): Vec2 => {
    const opposed = ss.some((s) => ss.some((t) => s[0] * t[0] + s[1] * t[1] < -EPS));
    if (opposed || ss.length === 0) return [0, 0];
    return ss.reduce((m, s) => (Math.hypot(...s) > Math.hypot(...m) ? s : m));
  });
  const moved = V.map((p, v): Vec2 => [p[0] + shift[v]![0], p[1] + shift[v]![1]]);
  const move = (p: Vec2): Vec2 => {
    for (const f of top) {
      const w = weights(F[f]!, V, p);
      if (w) return w.reduce((s, [v, t]): Vec2 => [s[0] + t * moved[v]![0], s[1] + t * moved[v]![1]], [0, 0]);
    }
    return p;
  };
  return { frame: { ...frame, vertices: moved }, move };
}
