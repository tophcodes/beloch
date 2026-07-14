import type { FaceOrder, Vec2 } from "./types";

// Topologically sort faces into a bottom->top order consistent with faceOrders.
// [f,g,s]: s=+1 => f above g (edge g->f), s=-1 => f below g (edge f->g).
export function linearExtension(
  faceOrders: FaceOrder[],
  nFaces: number,
  faceUp?: boolean[],
): number[] {
  const adj: number[][] = Array.from({ length: nFaces }, () => []);
  const indeg = new Array(nFaces).fill(0);
  const addEdge = (lo: number, hi: number) => { adj[lo]!.push(hi); indeg[hi]++; }; // lo below hi
  // FOLD's faceOrders sign is relative to g's NORMAL, not global +z:
  // [f,g,+1] means f lies on the side g's normal points to. So f is globally
  // BELOW g iff (s < 0) === gUp, where gUp = g faces up (front side up, i.e.
  // det_sign > 0 ⇔ folded winding CCW). faceUp[g] carries that; when omitted
  // (all faces up) the sign reads as plain global order.
  for (const [f, g, s] of faceOrders || []) {
    if (s === 0) continue;
    const gUp = faceUp ? faceUp[g] : true;
    if ((s < 0) === gUp) addEdge(f, g); // f below g
    else addEdge(g, f);                 // g below f
  }
  const queue: number[] = [];
  for (let i = 0; i < nFaces; i++) if (indeg[i] === 0) queue.push(i);
  queue.sort((a, b) => a - b); // deterministic tie-break
  const order: number[] = [];
  while (queue.length) {
    const n = queue.shift()!;
    order.push(n);
    for (const m of adj[n]!) if (--indeg[m] === 0) {
      let k = queue.length;
      while (k > 0 && queue[k - 1]! > m) k--;
      queue.splice(k, 0, m);
    }
  }
  return order;
}

// Shoelace signed area; >0 = CCW (front side up in folded coords).
export function signedArea(poly: Vec2[]): number {
  let s = 0;
  for (let i = 0; i < poly.length; i++) {
    const [x1, y1] = poly[i]!, [x2, y2] = poly[(i + 1) % poly.length]!;
    s += x1 * y2 - x2 * y1;
  }
  return s / 2;
}

export function sideUp(poly: Vec2[]): "front" | "back" {
  return signedArea(poly) >= 0 ? "front" : "back";
}

// Physical layer height per face: the longest chain of overlapping faces below
// it. faceOrders IS the overlap graph (a pair is recorded only for overlapping
// faces), so this needs no polygon geometry. Faces are oriented below->above by
// their position in linearExtension order (which already decodes faceOrders'
// normal-relative sign). Flat single-layer regions get depth 0.
export function computeFaceDepth(
  facesVertices: number[][],
  vertices: Vec2[],
  faceOrders: FaceOrder[],
): number[] {
  const n = facesVertices.length;
  if (n === 0) return [];
  const faceUp = facesVertices.map((f) => sideUp(f.map((i) => vertices[i]!)) === "front");
  const order = linearExtension(faceOrders, n, faceUp);
  const pos = new Array<number>(n);
  order.forEach((f, i) => { pos[f] = i; });
  const belowOf: number[][] = Array.from({ length: n }, () => []);
  for (const [f, g, s] of faceOrders) {
    if (s === 0) continue;
    const hi = pos[f]! < pos[g]! ? g : f;   // larger pos is above
    const lo = pos[f]! < pos[g]! ? f : g;
    belowOf[hi]!.push(lo);
  }
  const depth = new Array<number>(n).fill(0);
  for (const f of order) {                  // ascending pos => below already done
    let d = 0;
    for (const b of belowOf[f]!) d = Math.max(d, depth[b]! + 1);
    depth[f] = d;
  }
  return depth;
}
