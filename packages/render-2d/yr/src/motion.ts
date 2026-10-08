// What a write does to the paper, read from the standard FOLD alone: the
// frames before and after it and their beloch:faces_matrix. A face of the
// state after the write moved when its isometry differs from the one of the
// face that held its paper before. The layer order of the state after tells
// a valley fold from a mountain fold and from a reverse fold.
import type { FoldScene, Frame, Isometry, Statement, Vec2 } from "@beloch/scene";
import { SceneError } from "@beloch/scene";
import { clipHalfPlane, clipSegmentToPoly, pointInPolygon, resolveIsometry, signedArea, toPaper, toTable } from "@beloch/render-svg";

// How a fold moves its paper, seen from above: onto the paper that stays,
// under it, or as a reverse fold, between its layers (inside) or around them
// (outside).
export type FoldKind = "valley" | "mountain" | "inside-reverse" | "outside-reverse";

// What a reverse fold turns, in table coordinates of the state before it.
export interface Reverse {
  near: [Vec2, Vec2][];       // the crease on the nearest layer of the tip
  far: [Vec2, Vec2][];        // the crease on the farthest layer of the tip, where no nearer layer covers it
  edge: [Vec2, Vec2];         // the folded edge the reverse turns, its end on the side of the tip second
  at: Vec2;                   // the point of that edge nearest the crease, where it meets it
  open: Vec2;                 // the end of the crease away from `at`, where the layers open
}

export interface FoldMotion {
  statement: number;          // index into scene.statements
  kind: FoldKind;
  before: number;             // index into scene.steps: the state the write reads
  after: number;              // index into scene.steps: the state it yields
  moved: Vec2[][];            // the paper that moves, one convex polygon per face, in paper coordinates
  hinge: [Vec2, Vec2][];      // the crease the write folds, in table coordinates
  hooked: boolean;            // true when some paper on the moving side of the crease stays
  tail: Vec2;                 // where the arrow starts, on the table before (see foldMotion)
  head: Vec2;                 // where that point lands
  edge: Vec2;                 // where the line from `tail` away from the hinge, square to it, leaves the moving paper
  edgeHead: Vec2;             // where that point lands
  reverse: Reverse | null;    // null on a valley or a mountain fold
}

const EPS = 1e-9;

const sameIsometry = (a: Isometry, b: Isometry) => a.every((x, i) => Math.abs(x - b[i]!) < EPS);

// A face's polygon in paper coordinates.
export function facePaper(frame: Frame, face: number): Vec2[] {
  const M = frame.facesMatrix?.[face];
  const table = frame.facesVertices[face]!.map((i) => frame.vertices[i]!);
  return M ? table.map((p) => toPaper(M, p)) : table;
}

const centroid = (poly: Vec2[]): Vec2 =>
  [poly.reduce((s, p) => s + p[0], 0) / poly.length, poly.reduce((s, p) => s + p[1], 0) / poly.length];

// The face of `frame` whose paper holds the paper point `p`.
function faceHolding(frame: Frame, p: Vec2): number {
  for (let f = 0; f < frame.facesVertices.length; f++) {
    if (pointInPolygon(p, facePaper(frame, f))) return f;
  }
  throw new SceneError(`no face of the state holds the paper point (${p[0]}, ${p[1]})`);
}

// The area two convex polygons share.
export function overlapArea(p: Vec2[], q: Vec2[]): number {
  const s = signedArea(q) < 0 ? -1 : 1;
  let clip = p;
  for (let i = 0; i < q.length && clip.length > 2; i++) {
    const [ax, ay] = q[i]!, [bx, by] = q[(i + 1) % q.length]!;
    // inward normal of the edge a→b
    const n: Vec2 = [-(by - ay) * s, (bx - ax) * s];
    clip = clipHalfPlane(clip, n, n[0] * ax + n[1] * ay);
  }
  return clip.length > 2 ? Math.abs(signedArea(clip)) : 0;
}

// The area centroid of the union of convex polygons: each point of the plane
// counts once, however many polygons cover it, so a stack of layers weighs
// as much as one. Each polygon is cut along the edge lines of the polygons it
// overlaps; a piece then lies wholly inside or wholly outside each of them,
// and it counts only for the first polygon that covers it. The pieces grow
// with the product of overlapping polygons and their edges, which is small
// for the faces of one fold.
export function unionCentroid(polys: Vec2[][]): Vec2 {
  let area = 0, sx = 0, sy = 0;
  polys.forEach((poly, i) => {
    const others = polys.filter((q, j) => j !== i && overlapArea(poly, q) > EPS);
    let pieces = [poly];
    for (const q of others) {
      for (let k = 0; k < q.length; k++) {
        const [ax, ay] = q[k]!, [bx, by] = q[(k + 1) % q.length]!;
        const n: Vec2 = [-(by - ay), bx - ax], c = n[0] * ax + n[1] * ay;
        pieces = pieces.flatMap((p) => [clipHalfPlane(p, n, c), clipHalfPlane(p, [-n[0], -n[1]], -c)])
          .filter((p) => p.length > 2 && Math.abs(signedArea(p)) > EPS);
      }
    }
    for (const piece of pieces) {
      const a = signedArea(piece);
      if (polys.slice(0, i).some((q) => overlapArea(piece, q) > EPS)) continue;
      // the centroid of a polygon, from its signed area
      let px = 0, py = 0;
      piece.forEach(([x1, y1], k) => {
        const [x2, y2] = piece[(k + 1) % piece.length]!, cr = x1 * y2 - x2 * y1;
        px += (x1 + x2) * cr; py += (y1 + y2) * cr;
      });
      area += Math.abs(a); sx += (px / (6 * a)) * Math.abs(a); sy += (py / (6 * a)) * Math.abs(a);
    }
  });
  if (area <= EPS) throw new SceneError("the moving part has no area");
  return [sx / area, sy / area];
}

// The states before and after a write of kind "fold", and for each face of
// the state after, the isometry of the face that held its paper before.
function frames(scene: FoldScene, write: Statement) {
  if (write.kind !== "fold") throw new SceneError(`statement ${write.index} is no fold`);
  const after = write.frameIndex, before = after - 1;
  const A = scene.steps[after]?.frame, B = scene.steps[before]?.frame;
  if (!A?.facesMatrix || !B) throw new SceneError(`statement ${write.index} has no state before it`);
  const holder = A.facesVertices.map((_, f) => faceHolding(B, centroid(facePaper(A, f))));
  const beforeMatrix: Isometry[] = holder.map((g) => B.facesMatrix?.[g] ?? [1, 0, 0, 1, 0, 0]);
  return { A, B, after, before, holder, beforeMatrix, afterMatrix: A.facesMatrix };
}

// The creases a write folds: the mountain and valley edges of the state
// after it that the write scored.
function creasesOf(A: Frame, write: Statement): [Vec2, Vec2][] {
  const hinge: [Vec2, Vec2][] = [];
  A.edgesVertices.forEach(([u, v], e) => {
    const kind = A.edgesAssignment[e];
    if ((kind === "M" || kind === "V") && A.edgesProvenance[e]?.statement === write.index) {
      hinge.push([A.vertices[u]!, A.vertices[v]!]);
    }
  });
  return hinge;
}

export interface TurnOver {
  statement: number;          // index into scene.statements
  before: number;             // index into scene.steps: the state the write reads
  after: number;              // index into scene.steps: the state it yields
  axis: Vec2;                 // a unit vector along the line the table is mirrored in
}

// The table map from the state before a face moved to the state after it,
// as the 2×2 linear part and the translation.
function relative(Mb: Isometry, Ma: Isometry): [number, number, number, number, number, number] {
  // Ma·Mbᵀ, since Mb is orthogonal; then t = Ta − R·Tb
  const [b00, b01, b10, b11, btx, bty] = Mb, [a00, a01, a10, a11, atx, aty] = Ma;
  const r00 = a00 * b00 + a01 * b01, r01 = a00 * b10 + a01 * b11;
  const r10 = a10 * b00 + a11 * b01, r11 = a10 * b10 + a11 * b11;
  return [r00, r01, r10, r11, atx - (r00 * btx + r01 * bty), aty - (r10 * btx + r11 * bty)];
}

// The turn-over a write makes, or null when it makes none. A write turns the
// model over when it folds no crease and every face of the state after it
// differs from the face that held its paper before by one and the same
// mirroring of the table.
export function turnOver(scene: FoldScene, write: Statement): TurnOver | null {
  if (write.kind !== "fold") return null;
  const { A, after, before, beforeMatrix, afterMatrix } = frames(scene, write);
  if (creasesOf(A, write).length > 0) return null;
  const maps = afterMatrix.map((Ma, f) => relative(beforeMatrix[f]!, Ma));
  const R = maps[0];
  if (!R || maps.some((m) => !sameIsometry(m, R))) return null;
  if (R[0] * R[3] - R[1] * R[2] > 0) return null;
  // a mirroring's linear part is [[cos 2θ, sin 2θ], [sin 2θ, −cos 2θ]], with
  // its line at the angle θ
  const theta = Math.atan2(R[2], R[0]) / 2;
  return { statement: write.index, before, after, axis: [Math.cos(theta), Math.sin(theta)] };
}

const distanceToLine = (p: Vec2, [a, b]: [Vec2, Vec2]) => {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  return Math.abs(dx * (p[1] - a[1]) - dy * (p[0] - a[0])) / Math.hypot(dx, dy);
};

const det = (M: Isometry) => M[0] * M[3] - M[1] * M[2];

// The point of the segment [a, b] nearest `p`.
function nearestOn(p: Vec2, [a, b]: [Vec2, Vec2]): Vec2 {
  const dx = b[0] - a[0], dy = b[1] - a[1], L2 = dx * dx + dy * dy;
  const t = L2 === 0 ? 0 : Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2));
  return [a[0] + t * dx, a[1] + t * dy];
}

// The point of `edge` nearest the segment `axis`: where they cross, or else
// the nearest of the points that the ends of either segment give.
function nearestToSegment(edge: [Vec2, Vec2], axis: [Vec2, Vec2]): { at: Vec2; d: number } {
  const [[ax, ay], [bx, by]] = edge, [[cx, cy], [ex, ey]] = axis;
  const rx = bx - ax, ry = by - ay, sx = ex - cx, sy = ey - cy, den = rx * sy - ry * sx;
  if (Math.abs(den) > EPS) {
    const t = ((cx - ax) * sy - (cy - ay) * sx) / den, u = ((cx - ax) * ry - (cy - ay) * rx) / den;
    if (t > -1e-7 && t < 1 + 1e-7 && u > -1e-7 && u < 1 + 1e-7) return { at: [ax + t * rx, ay + t * ry], d: 0 };
  }
  const pairs: [Vec2, Vec2][] = [
    [nearestOn(axis[0], edge), axis[0]], [nearestOn(axis[1], edge), axis[1]],
    [edge[0], nearestOn(edge[0], axis)], [edge[1], nearestOn(edge[1], axis)],
  ];
  return pairs.map(([at, q]) => ({ at, d: Math.hypot(at[0] - q[0], at[1] - q[1]) }))
    .reduce((m, x) => (x.d < m.d - 1e-9 ? x : m));
}

// The motion of one write of kind "fold" that folds a crease. Seen from
// above, a valley fold lays the moving paper on top of the paper it lands on
// and a mountain fold lays it underneath. An inside reverse fold puts a moving
// layer between two that stay; an outside reverse fold puts a layer that stays
// between two that move. A fold that lays paper between layers that stay and
// turns no folded edge is no reverse fold, and is refused. A fold is hooked
// when paper on the moving side of the crease stays where it was: the fold
// takes some of the layers there.
//
// The arrow of a valley or a mountain fold has no reference point, so it runs
// from the center of mass of the moving paper to where that point lands
// [lang1991conventions, Part II]. A reverse fold's arrow runs from the tip:
// the moving paper farthest from the hinge, a corner or the middle of an edge
// that lies parallel to it.
export function foldMotion(scene: FoldScene, write: Statement): FoldMotion {
  const { A, B, after, before, holder, beforeMatrix, afterMatrix } = frames(scene, write);

  const movedFaces: number[] = [], stayingFaces: number[] = [];
  const tip = new Set<number>();          // the faces of B whose paper moves
  afterMatrix.forEach((Ma, f) => {
    if (sameIsometry(beforeMatrix[f]!, Ma)) stayingFaces.push(f);
    else { movedFaces.push(f); tip.add(holder[f]!); }
  });
  if (movedFaces.length === 0) throw new SceneError(`statement ${write.index} moves no paper`);

  const hinge = creasesOf(A, write);
  if (hinge.length === 0) throw new SceneError(`statement ${write.index} folds no crease`);

  const { order } = resolveIsometry(scene, { kind: "step", index: after });
  const rank = new Map(order.map((f, i) => [f, i]));
  const table = (f: number) => A.facesVertices[f]!.map((i) => A.vertices[i]!);
  const sides = new Map<number, { above: boolean; below: boolean }>();
  const side = (f: number) => sides.get(f) ?? sides.set(f, { above: false, below: false }).get(f)!;
  let over = false, under = false;
  for (const m of movedFaces) {
    for (const s of stayingFaces) {
      if (overlapArea(table(m), table(s)) <= EPS) continue;
      if (rank.get(m)! > rank.get(s)!) { over = true; side(m).below = true; side(s).above = true; }
      else { under = true; side(m).above = true; side(s).below = true; }
    }
  }
  const between = (fs: number[]) => fs.some((f) => sides.get(f)?.above && sides.get(f)?.below);
  const kind: FoldKind | null = !under ? "valley"
    : !over ? "mountain"
    : between(movedFaces) ? "inside-reverse"
    : between(stayingFaces) ? "outside-reverse"
    : null;

  const tableBefore = (f: number) => facePaper(A, f).map((p) => toTable(beforeMatrix[f]!, p));
  const hooked = movedFaces.some((m) => stayingFaces.some((s) => overlapArea(tableBefore(m), table(s)) > EPS));
  // every moved face turns by the same motion of the table, so the first one
  // carries a point
  const f0 = movedFaces[0]!;
  const carry = (p: Vec2) => toTable(afterMatrix[f0]!, toPaper(beforeMatrix[f0]!, p));

  // the tip of a reverse fold
  const axis = hinge[0]!;
  const corners = movedFaces.flatMap((f) => tableBefore(f).map((from) => ({ from, d: distanceToLine(from, axis) })));
  const far = Math.max(...corners.map((c) => c.d));
  const mean = (pts: Vec2[]): Vec2 => {
    const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
    return [(Math.min(...xs) + Math.max(...xs)) / 2, (Math.min(...ys) + Math.max(...ys)) / 2];
  };
  const corner = mean(corners.filter((c) => c.d > far - 1e-7).map((c) => c.from));

  const reverse = kind === "inside-reverse" || kind === "outside-reverse"
    ? reverseOf(write, A, B, movedFaces, tip, order, corner) : null;
  if (kind === null || (kind !== "valley" && kind !== "mountain" && reverse === null)) {
    throw new SceneError(
      `statement ${write.index} folds paper between layers that stay and turns no folded edge; the diagram cannot draw it`,
    );
  }

  const moving = movedFaces.map(tableBefore);
  const tail = reverse ? corner : unionCentroid(moving);
  // The outer edge of the moving paper, where a hooked tail and a mountain
  // arrow turn around it: the farthest point of the moving paper on the ray
  // from `tail` away from the hinge, square to it.
  const [a, b] = axis;
  let u: Vec2 = [-(b[1] - a[1]), b[0] - a[0]];
  const l = Math.hypot(u[0], u[1]);
  u = [u[0] / l, u[1] / l];
  if (u[0] * (tail[0] - a[0]) + u[1] * (tail[1] - a[1]) < 0) u = [-u[0], -u[1]];
  const span = Math.max(...moving.flat().map((p) => Math.hypot(p[0] - tail[0], p[1] - tail[1])));
  const ray: Vec2 = [tail[0] + 2 * span * u[0], tail[1] + 2 * span * u[1]];
  let edge = tail, reach = 0;
  for (const poly of moving) {
    const cut = clipSegmentToPoly(tail, ray, poly);
    if (!cut) continue;
    for (const p of cut) {
      const r = (p[0] - tail[0]) * u[0] + (p[1] - tail[1]) * u[1];
      if (r > reach) { reach = r; edge = p; }
    }
  }
  return {
    statement: write.index, kind, before, after, hooked,
    moved: movedFaces.map((f) => facePaper(A, f)),
    hinge,
    tail, head: carry(tail),
    edge, edgeHead: carry(edge),
    reverse,
  };
}

// The layers a reverse fold creases and the folded edge it turns, or null when
// the fold turns no folded edge and so is no reverse fold. `tip` holds
// the faces of `B` whose paper moves; `order` is the stack of `A`, bottom to
// top, in which the faces that stay keep the order they have in `B`.
function reverseOf(
  write: Statement, A: Frame, B: Frame, moved: number[], tip: Set<number>, order: number[], tail: Vec2,
): Reverse | null {
  if (!A.edgesFaces || !B.edgesFaces) throw new SceneError(`statement ${write.index}: the FOLD has no edges_faces`);
  const rank = new Map(order.map((f, i) => [f, i]));
  // every new crease, with the rank of the layer that stays on its far side
  const creases = A.edgesVertices.flatMap(([u, v], e) => {
    const kindOf = A.edgesAssignment[e];
    if ((kindOf !== "M" && kindOf !== "V") || A.edgesProvenance[e]?.statement !== write.index) return [];
    const staying = A.edgesFaces![e]!.find((f) => !moved.includes(f));
    return staying === undefined ? [] : [{ seg: [A.vertices[u]!, A.vertices[v]!] as [Vec2, Vec2], r: rank.get(staying)! }];
  });
  // positions along the line of the crease
  const [o, p1] = creases[0]!.seg;
  const L = Math.hypot(p1[0] - o[0], p1[1] - o[1]);
  const dir: Vec2 = [(p1[0] - o[0]) / L, (p1[1] - o[1]) / L];
  const tOf = (p: Vec2) => (p[0] - o[0]) * dir[0] + (p[1] - o[1]) * dir[1];
  const point = (t: number): Vec2 => [o[0] + t * dir[0], o[1] + t * dir[1]];
  const spans = creases.map((c) => {
    const a = tOf(c.seg[0]), b = tOf(c.seg[1]);
    return { ...c, t0: Math.min(a, b), t1: Math.max(a, b) };
  });
  type Span = (typeof spans)[number];
  const covers = (s: Span, t: number) => s.t0 - 1e-7 <= t && t <= s.t1 + 1e-7;
  const mid = (s: Span) => (s.t0 + s.t1) / 2;
  const near = spans.filter((s) => !spans.some((x) => x.r > s.r && covers(x, mid(s))));
  const far = spans.filter((s) => !near.includes(s) && !spans.some((x) => x.r < s.r && covers(x, mid(s))));
  // the parts of the far layer's crease that no near one covers
  const shows: [Vec2, Vec2][] = [];
  for (const f of far) {
    let open: [number, number][] = [[f.t0, f.t1]];
    for (const n of near) {
      open = open.flatMap(([a, b]): [number, number][] =>
        [[a, Math.min(b, n.t0)], [Math.max(a, n.t1), b]].filter(([x, y]) => y - x > 1e-7) as [number, number][]);
    }
    for (const [a, b] of open) shows.push([point(a), point(b)]);
  }

  // The folded edge the reverse turns is the hinge between the two blocks of
  // the tip (decisions/a-reverse-fold-turns-the-hinges-across-its-opening): an edge of `B` between two faces of the tip whose
  // paper carries a crease of the other letter in `A`. Of those, the one
  // nearest the crease.
  const t0 = Math.min(...spans.map((s) => s.t0)), t1 = Math.max(...spans.map((s) => s.t1));
  const axis: [Vec2, Vec2] = [point(t0), point(t1)];
  const MB = (g: number): Isometry => B.facesMatrix?.[g] ?? [1, 0, 0, 1, 0, 0];
  const paperOf = (M: Isometry, [p, q]: [Vec2, Vec2]): [Vec2, Vec2] => [toPaper(M, p), toPaper(M, q)];
  const turnedInA = A.edgesVertices.flatMap(([u, v], e) => {
    const fs = A.edgesFaces![e]!, letter = A.edgesAssignment[e];
    if (fs.length !== 2 || !fs.every((f) => moved.includes(f)) || (letter !== "M" && letter !== "V")) return [];
    return [{ letter, paper: paperOf(A.facesMatrix![fs[0]!]!, [A.vertices[u]!, A.vertices[v]!]) }];
  });
  const turns = (paper: [Vec2, Vec2], letter: string) => turnedInA.some((x) => {
    if (x.letter === letter || x.paper.some((p) => distanceToLine(p, paper) > 1e-7)) return false;
    const [a, b] = paper, dx = b[0] - a[0], dy = b[1] - a[1], L2 = dx * dx + dy * dy;
    const ts = x.paper.map((p) => ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2);
    return Math.min(1, Math.max(...ts)) - Math.max(0, Math.min(...ts)) > 1e-7;
  });
  let best = null as { edge: [Vec2, Vec2]; at: Vec2; d: number } | null;
  B.edgesVertices.forEach(([u, v], e) => {
    const fs = B.edgesFaces![e]!;
    if (fs.length !== 2 || !fs.every((g) => tip.has(g)) || det(MB(fs[0]!)) * det(MB(fs[1]!)) > 0) return;
    const edge: [Vec2, Vec2] = [B.vertices[u]!, B.vertices[v]!];
    if (!turns(paperOf(MB(fs[0]!), edge), B.edgesAssignment[e]!)) return;
    const n = nearestToSegment(edge, axis);
    if (!best || n.d < best.d - 1e-9) best = { edge, ...n };
  });
  if (!best) return null;
  const { edge: [e0, e1], at } = best;
  // the end of the folded edge on the side of the tip comes second
  const side = (p: Vec2) => (p1[0] - o[0]) * (p[1] - o[1]) - (p1[1] - o[1]) * (p[0] - o[0]);
  const edge: [Vec2, Vec2] = side(e1) * side(tail) >= side(e0) * side(tail) ? [e0, e1] : [e1, e0];
  const dist = (p: Vec2) => Math.hypot(p[0] - at[0], p[1] - at[1]);
  return {
    near: near.map((s) => s.seg), far: shows, edge, at,
    open: dist(axis[0]) > dist(axis[1]) ? axis[0] : axis[1],
  };
}
