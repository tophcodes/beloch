// Geometry axis of renderScene: pick which Frame supplies the folded (or flat)
// face polygons, and compute the stack order + per-face orientation used for
// occlusion. Orthogonal to `texture` (which decorations get drawn).
import type { FoldScene, Frame, Vec2 } from "@beloch/scene";
import { SceneError } from "@beloch/scene";
import { linearExtension, sideUp } from "./geometry";

// Which geometry to render: the flat crease-pattern sheet, or a folded step.
// `turn` rotates the step's drawing counterclockwise by that many radians
// about the center of its bounding box (see turnFrame); absent, 0.
export type Isometry =
  | { kind: "flat" }
  | { kind: "step"; index: number; turn?: number | undefined };

export interface ResolvedFrame {
  frame: Frame;
  order: number[]; // face indices, bottom → top paint order
  faceUp: boolean[]; // per face: front side up? (front fill vs back fill)
  occlude: boolean; // folded frames occlude; the flat sheet does not
  place: (p: Vec2) => Vec2; // a table point of the step to where `frame` draws it
}

// The frame turned counterclockwise by `turn` radians about the center of its
// bounding box, faces' matrices included, so that every point a renderer maps
// through the frame lands where the turned faces are. A rotation keeps each
// face's side up, so stack order and fills are unchanged.
export function turnFrame(frame: Frame, turn: number): { frame: Frame; place: (p: Vec2) => Vec2 } {
  if (turn === 0) return { frame, place: (p) => p };
  const xs = frame.vertices.map((v) => v[0]), ys = frame.vertices.map((v) => v[1]);
  const cx = (Math.min(...xs) + Math.max(...xs)) / 2, cy = (Math.min(...ys) + Math.max(...ys)) / 2;
  const c = Math.cos(turn), s = Math.sin(turn);
  const place = ([x, y]: Vec2): Vec2 =>
    [cx + c * (x - cx) - s * (y - cy), cy + s * (x - cx) + c * (y - cy)];
  return {
    place,
    frame: {
      ...frame,
      vertices: frame.vertices.map(place),
      facesMatrix: frame.facesMatrix?.map(([m00, m01, m10, m11, tx, ty]) => {
        const [ox, oy] = place([tx, ty]);
        return [c * m00 - s * m10, c * m01 - s * m11, s * m00 + c * m10, s * m01 + c * m11, ox, oy];
      }) ?? null,
    },
  };
}

// Resolve an isometry to the concrete frame + stack it draws from. The flat
// sheet is the CP frame (identity paper→table, no layer occlusion); a step is
// scene.steps[k].frame with its layer ordering decoded by linearExtension
// (faceOrders sign is keyed to each face normal, so faceUp must be threaded
// through it).
export function resolveIsometry(scene: FoldScene, iso: Isometry): ResolvedFrame {
  if (iso.kind === "flat") {
    const frame = scene.cp;
    const n = frame.facesVertices.length;
    // faceOrders is [] on the CP frame → linearExtension yields ascending
    // indices; every CP face is front-up in paper space.
    return {
      frame,
      order: linearExtension(frame.faceOrders, n),
      faceUp: frame.facesVertices.map(() => true),
      occlude: false,
      place: (p) => p,
    };
  }
  const step = scene.steps[iso.index];
  if (!step) {
    throw new SceneError(
      `isometry step ${iso.index} out of range — ${scene.steps.length} step(s)`,
    );
  }
  const { frame, place } = turnFrame(step.frame, iso.turn ?? 0);
  const V = frame.vertices;
  const faceUp = frame.facesVertices.map(
    (f) => sideUp(f.map((i) => V[i]!)) === "front",
  );
  const order = linearExtension(frame.faceOrders, frame.facesVertices.length, faceUp);
  return { frame, order, faceUp, occlude: true, place };
}
