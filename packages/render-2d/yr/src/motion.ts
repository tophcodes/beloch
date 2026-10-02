// What a write does to the paper, read from the standard FOLD alone: the
// frames before and after it and their beloch:faces_matrix. A face of the
// state after the write moved when its isometry differs from the one of the
// face that held its paper before.
import type { FoldScene, Frame, Isometry, Statement, Vec2 } from "@beloch/scene";
import { SceneError } from "@beloch/scene";
import { clipHalfPlane, pointInPolygon, resolveIsometry, signedArea, toPaper, toTable } from "@beloch/render-svg";

export interface FoldMotion {
  statement: number;          // index into scene.statements
  before: number;             // index into scene.steps: the state the write reads
  after: number;              // index into scene.steps: the state it yields
  moved: Vec2[][];            // the paper that moves, one convex polygon per face, in paper coordinates
  hinge: [Vec2, Vec2][];      // the crease the write folds, in table coordinates
  tail: Vec2;                 // the moving corner farthest from the hinge, on the table before
  head: Vec2;                 // where that corner lands
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

const distanceToLine = (p: Vec2, [a, b]: [Vec2, Vec2]) => {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  return Math.abs(dx * (p[1] - a[1]) - dy * (p[0] - a[0])) / Math.hypot(dx, dy);
};

// The motion of one write of kind "fold". A write that folds paper behind
// the layers that stay, or folds between them, is refused: the first slice of
// the diagram draws valley folds alone.
export function foldMotion(scene: FoldScene, write: Statement): FoldMotion {
  if (write.kind !== "fold") throw new SceneError(`statement ${write.index} is no fold`);
  const after = write.frameIndex, before = after - 1;
  const A = scene.steps[after]?.frame, B = scene.steps[before]?.frame;
  if (!A?.facesMatrix || !B) throw new SceneError(`statement ${write.index} has no state before it`);

  const movedFaces: number[] = [], stayingFaces: number[] = [];
  const beforeMatrix: Isometry[] = [];
  A.facesVertices.forEach((_, f) => {
    const g = faceHolding(B, centroid(facePaper(A, f)));
    const Mb = B.facesMatrix?.[g] ?? [1, 0, 0, 1, 0, 0];
    beforeMatrix[f] = Mb;
    (sameIsometry(Mb, A.facesMatrix![f]!) ? stayingFaces : movedFaces).push(f);
  });
  if (movedFaces.length === 0) throw new SceneError(`statement ${write.index} moves no paper`);

  const hinge: [Vec2, Vec2][] = [];
  A.edgesVertices.forEach(([u, v], e) => {
    const kind = A.edgesAssignment[e];
    if ((kind === "M" || kind === "V") && A.edgesProvenance[e]?.statement === write.index) {
      hinge.push([A.vertices[u]!, A.vertices[v]!]);
    }
  });
  if (hinge.length === 0) throw new SceneError(`statement ${write.index} folds no crease`);

  // Seen from above, a valley fold lays the moving paper on top of the paper
  // it lands on.
  const { order } = resolveIsometry(scene, { kind: "step", index: after });
  const rank = new Map(order.map((f, i) => [f, i]));
  const table = (f: number) => A.facesVertices[f]!.map((i) => A.vertices[i]!);
  for (const m of movedFaces) {
    for (const s of stayingFaces) {
      if (overlapArea(table(m), table(s)) > EPS && rank.get(m)! < rank.get(s)!) {
        throw new SceneError(
          `statement ${write.index} folds paper behind or between layers; the diagram draws valley folds only`,
        );
      }
    }
  }

  // The arrow starts at the moving paper farthest from the hinge: a corner, or
  // the middle of an edge that lies parallel to it.
  const axis = hinge[0]!;
  const corners = movedFaces.flatMap((f) => facePaper(A, f).map((p) => {
    const from = toTable(beforeMatrix[f]!, p);
    return { from, to: toTable(A.facesMatrix![f]!, p), d: distanceToLine(from, axis) };
  }));
  const far = Math.max(...corners.map((c) => c.d));
  const farthest = corners.filter((c) => c.d > far - 1e-7);
  const mean = (pts: Vec2[]): Vec2 => {
    const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
    return [(Math.min(...xs) + Math.max(...xs)) / 2, (Math.min(...ys) + Math.max(...ys)) / 2];
  };
  return {
    statement: write.index, before, after,
    moved: movedFaces.map((f) => facePaper(A, f)),
    hinge,
    tail: mean(farthest.map((c) => c.from)),
    head: mean(farthest.map((c) => c.to)),
  };
}
