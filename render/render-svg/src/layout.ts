// The padded-canvas transform from tools/fold2svg.mjs:192-198.
import type { Vec2 } from "@beloch/scene";

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
