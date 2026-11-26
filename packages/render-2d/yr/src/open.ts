// A flat state drawn as if it had been let go, so that stacked layers show
// [lang1991conventions, Part I, "Show multiple layers whenever possible";
// lang2011secrets, Fig. 2.31]: a covered layer shifts down the page beside
// the raw edge of the layer above it (bandFrame), and two raw edges that meet
// part (gapFrame).
import type { Frame, Vec2 } from "@beloch/scene";
import { linearExtension, sideUp } from "@beloch/render-svg";

const EPS = 1e-9;

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

// `frame` with the raw edges of every layer that another layer covers shifted
// by `shift`, so that the next layer down shows as one band beside the top
// layer's raw edge, its corners straight below the top layer's corners when
// `shift` points down the page [lang2011secrets, Fig. 2.31]. A layer no other
// layer covers stays where it is. A covered layer's corner moves by `shift`
// where one of its raw edges lies under a raw edge of the highest layer above
// that stretch; any other corner stays, so a layer tucked under a fold does
// not show. All covered layers shift alike, so their edges fall on one line
// and no more than one band shows; an edge that faces against `shift` moves
// under the layer above it and hides. A vertex that layers share moves with
// each of them: where they move by different amounts it becomes one vertex
// per amount. Returns `move`, which carries a point of the flat state with
// the topmost face under it.
export function bandFrame(frame: Frame, shift: Vec2): { frame: Frame; move: (p: Vec2) => Vec2 } {
  const V = frame.vertices, F = frame.facesVertices;
  const faceUp = F.map((f) => sideUp(f.map((i) => V[i]!)) === "front");
  const order = linearExtension(frame.faceOrders, F.length, faceUp);
  const height = new Map(order.map((f, i) => [f, i]));
  const h = (f: number) => height.get(f) ?? 0;
  const covered = F.map(() => false);
  for (const [f, g] of frame.faceOrders) covered[h(f) < h(g) ? f : g] = true;

  const key = (a: number, b: number) => `${Math.min(a, b)}-${Math.max(a, b)}`;
  const edgeIx = new Map(frame.edgesVertices.map(([a, b], e) => [key(a, b), e]));
  // the boundary edges of every face, with their assignment
  const sides = F.map((face) => face.map((v, k) => {
    const w = face[(k + 1) % face.length]!;
    return { v, w, raw: frame.edgesAssignment[edgeIx.get(key(v, w)) ?? -1] === "B" };
  }));
  const along = (a: Vec2, b: Vec2, c: Vec2, d: Vec2) => {
    const l = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (l < EPS) return false;
    const u: Vec2 = [(b[0] - a[0]) / l, (b[1] - a[1]) / l];
    const off = (p: Vec2) => Math.abs((p[0] - a[0]) * u[1] - (p[1] - a[1]) * u[0]);
    if (off(c) > 1e-7 || off(d) > 1e-7) return false;
    const t = (p: Vec2) => (p[0] - a[0]) * u[0] + (p[1] - a[1]) * u[1];
    return Math.min(l, Math.max(t(c), t(d))) - Math.max(0, Math.min(t(c), t(d))) > 1e-7;
  };
  // A covered layer's raw edge steps out where the highest layer above it
  // that has an edge on the same stretch has a raw edge there, so the edge
  // shows beside that layer's raw edge; under a fold it stays tucked in.
  const stepsOut = (f: number, v: number, w: number) => {
    let best = -1, raw = false;
    sides.forEach((ss, g) => {
      if (h(g) <= h(f) || h(g) <= best) return;
      const s = ss.find((x) => along(V[v]!, V[w]!, V[x.v]!, V[x.w]!));
      if (s) { best = h(g); raw = s.raw; }
    });
    return raw;
  };
  // each face's step at each of its corners
  const steps = F.map((face, f): Vec2[] => face.map((v, k) => {
    if (!covered[f]) return [0, 0];
    const shows = [face[(k + 1) % face.length]!, face[(k + face.length - 1) % face.length]!].some((w) => {
      const e = edgeIx.get(key(v, w));
      return e !== undefined && frame.edgesAssignment[e] === "B" && stepsOut(f, v, w);
    });
    return shows ? shift : [0, 0];
  }));

  // one vertex per point of the paper and step: the first step at a vertex
  // keeps its index, every other step gets a new one at the same flat point
  const flat: Vec2[] = [...V];
  const moved: Vec2[] = [...V];
  const names = [...frame.verticesNames];
  const copies = V.map(() => new Map<string, number>());
  const faces = F.map((face, f) => face.map((v, k) => {
    const d = steps[f]![k]!, id = `${d[0].toFixed(9)},${d[1].toFixed(9)}`;
    const seen = copies[v]!;
    if (seen.has(id)) return seen.get(id)!;
    const ix = seen.size === 0 ? v : flat.length;
    if (ix !== v) { flat.push(V[v]!); moved.push(V[v]!); names.push(null); }
    moved[ix] = [V[v]![0] + d[0], V[v]![1] + d[1]];
    seen.set(id, ix);
    return ix;
  }));
  // an edge whose ends a face holds as other vertices gets a copy for that face
  const edgesVertices = [...frame.edgesVertices], edgesAssignment = [...frame.edgesAssignment];
  const edgesProvenance = [...frame.edgesProvenance];
  const edgesFaces = frame.edgesFaces ? frame.edgesFaces.map((fs) => [...fs]) : null;
  const have = new Set(edgesVertices.map(([a, b]) => key(a, b)));
  faces.forEach((face, f) => face.forEach((v, k) => {
    const w = face[(k + 1) % face.length]!;
    if (have.has(key(v, w))) return;
    const e = edgeIx.get(key(F[f]![k]!, F[f]![(k + 1) % face.length]!));
    if (e === undefined) return;
    have.add(key(v, w));
    edgesVertices.push([v, w]);
    edgesAssignment.push(frame.edgesAssignment[e]!);
    edgesProvenance.push(frame.edgesProvenance[e] ?? null);
    edgesFaces?.push([f]);
  }));
  // The center of the bounding box stays where it was, so that a turn about
  // that center places the moved state where it places the flat one.
  const center = (P: Vec2[]): Vec2 => {
    const xs = P.map((p) => p[0]), ys = P.map((p) => p[1]);
    return [(Math.min(...xs) + Math.max(...xs)) / 2, (Math.min(...ys) + Math.max(...ys)) / 2];
  };
  const [c0, c1] = [center(V), center(moved)];
  const back = (p: Vec2): Vec2 => [p[0] + c0[0] - c1[0], p[1] + c0[1] - c1[1]];
  const out: Frame = {
    ...frame, vertices: moved.map(back), verticesNames: names, facesVertices: faces,
    edgesVertices, edgesAssignment, edgesProvenance, edgesFaces,
  };
  const top = [...order].reverse();
  const move = (p: Vec2): Vec2 => {
    for (const f of top) {
      const w = weights(faces[f]!, flat, p);
      if (w) return back(w.reduce((s, [v, t]): Vec2 => [s[0] + t * moved[v]![0], s[1] + t * moved[v]![1]], [0, 0]));
    }
    return back(p);
  };
  return { frame: out, move };
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
