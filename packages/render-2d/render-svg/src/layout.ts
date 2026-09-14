// The padded-canvas transform from tools/fold2svg.mjs:192-198.
import type { FoldScene, Vec2 } from "@beloch/scene";

export const PAD = 56;
export const SZ = 460;

export interface Layout {
  W: number; H: number;                 // canvas size (PAD=56, SZ=460 → 572×572)
  tx(x: number): number;                // world → px
  ty(y: number): number;                // world → px, y flipped
  minX: number; maxX: number; minY: number; maxY: number; span: number;
}

export function makeLayout(vertices: Vec2[]): Layout {
  const W = SZ + 2 * PAD, H = SZ + 2 * PAD;
  const xs = vertices.map((p) => p[0]), ys = vertices.map((p) => p[1]);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  const span = Math.max(maxX - minX, maxY - minY) || 1;
  return {
    W, H, minX, maxX, minY, maxY, span,
    tx: (x: number) => PAD + ((x - minX) / span) * SZ,
    ty: (y: number) => PAD + (1 - (y - minY) / span) * SZ,
  };
}

// The one frame every view of a scene draws in: the union of the paper's bounds
// and the bounds of each folded frame. Sharing it is what lets the crease
// pattern and the folded form stand side by side at one scale on one baseline,
// with a point the same size in both. A folded form can reach outside the
// paper, since a fold whose moving side is the larger one reflects it past the
// sheet, so the paper alone would leave that part in the padding or off the
// canvas.
// Every caller that maps between world and pixel coordinates uses this, the
// renderers and the Playground's hit testing alike, or the two drift apart.
export function sceneLayout(scene: FoldScene): Layout {
  const vertices = [scene.cp.vertices, ...scene.steps.map((s) => s.frame.vertices)].flat();
  return makeLayout(vertices);
}
