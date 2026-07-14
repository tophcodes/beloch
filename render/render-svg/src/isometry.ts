// Geometry axis of renderScene: pick which Frame supplies the folded (or flat)
// face polygons, and compute the stack order + per-face orientation used for
// occlusion. Orthogonal to `texture` (which decorations get drawn) — see
// docs/superpowers/specs/2026-07-14-render-scene-unified-design.md.
import type { FoldScene, Frame } from "@beloch/scene";
import { SceneError } from "@beloch/scene";
import { linearExtension, sideUp } from "./geometry";

// Which geometry to render: the flat crease-pattern sheet, or a folded step.
export type Isometry =
  | { kind: "flat" }
  | { kind: "step"; index: number };

export interface ResolvedFrame {
  frame: Frame;
  order: number[]; // face indices, bottom → top paint order
  faceUp: boolean[]; // per face: front side up? (front fill vs back fill)
  occlude: boolean; // folded frames occlude; the flat sheet does not
}

// Resolve an isometry to the concrete frame + stack it draws from. The flat
// sheet is the CP frame (identity paper→table, no layer occlusion); a step is
// scene.steps[k].frame with its layer ordering decoded exactly as the ported
// fold2svg occlusion pass did (faceOrders sign is keyed to each face normal, so
// faceUp must be threaded through linearExtension).
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
    };
  }
  const step = scene.steps[iso.index];
  if (!step) {
    throw new SceneError(
      `isometry step ${iso.index} out of range — ${scene.steps.length} step(s)`,
    );
  }
  const frame = step.frame;
  const V = frame.vertices;
  const faceUp = frame.facesVertices.map(
    (f) => sideUp(f.map((i) => V[i]!)) === "front",
  );
  const order = linearExtension(frame.faceOrders, frame.facesVertices.length, faceUp);
  return { frame, order, faceUp, occlude: true };
}
