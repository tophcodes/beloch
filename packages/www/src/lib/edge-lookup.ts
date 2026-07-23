// Boundary-edge geometry lookup (playground slice B, task 9): paper
// boundary lines (assignment "B") carry no data-crease-id — render-scene.ts
// only tags real creases (M/V/F) with one, since there's no per-edge id for
// a boundary. So a boundary line's rendered `<line>` is otherwise
// indistinguishable from any other crease-layer line via attributes alone;
// it must be re-identified by GEOMETRY instead, the same way Task 7's stack
// picker re-identifies a crease segment without a data-seg attribute: match
// its rendered endpoints (SVG pixel space) against an `InspectEdge`'s
// `table` coordinates, run through the SAME layout the renderer used
// (`makeLayout(scene.cp.vertices)` from @beloch/render-svg).
import type { Inspect } from "@beloch/scene";
import { segMatchesLine } from "./stack-picker";

// The subset of makeLayout's return value this needs — kept minimal so unit
// tests can pass a fake transform instead of pulling in @beloch/render-svg.
export interface EdgeLayout {
  tx: (x: number) => number;
  ty: (y: number) => number;
}

// Which paper-edge bundle (keyed by name, e.g. "ab") the rendered line
// [x1,y1]-[x2,y2] belongs to — checked against every segment of every edge
// (a crossing crease splits an edge into several segments) — or null if it
// matches none.
export function edgeOfLine(
  edges: Inspect["edges"],
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  layout: EdgeLayout,
): string | null {
  for (const [name, edge] of Object.entries(edges)) {
    for (const seg of edge.segments) {
      const p0: [number, number] = [layout.tx(seg.table[0][0]), layout.ty(seg.table[0][1])];
      const p1: [number, number] = [layout.tx(seg.table[1][0]), layout.ty(seg.table[1][1])];
      if (segMatchesLine(p0, p1, x1, y1, x2, y2)) return name;
    }
  }
  return null;
}
