// The face graph of a frame, read from `edges_faces` (docs/reference/FOLD.md, "Standard
// fields"). A node is a set of faces joined across `J` edges: a join edge only
// divides a non-convex sheet into convex faces, and FOLD counts the faces on
// its two sides as one. Every other edge with two faces, `M`, `V` or `F`,
// separates two nodes, or runs inside one when a chain of join edges already
// joins its faces.
import type { Frame } from "./types";
import { SceneError } from "./types";

export interface FaceGraph {
  // the faces of each node, ascending; nodes ordered by their first face
  nodes: number[][];
  // the node of each face
  nodeOf: number[];
  // the nodes that share an edge with `node`, ascending
  neighbors(node: number): number[];
  // the indices of the edges between nodes `a` and `b`, ascending; [] when
  // they share none, and when `a` is `b`
  edgesBetween(a: number, b: number): number[];
}

export function faceGraph(frame: Frame): FaceGraph {
  const edgesFaces = frame.edgesFaces;
  if (edgesFaces === null) {
    throw new SceneError("this FOLD file has no edges_faces; write it again with `beloch fold`");
  }
  const n = frame.facesVertices.length;
  const parent = Array.from({ length: n }, (_, f) => f);
  const find = (f: number): number => (parent[f] === f ? f : (parent[f] = find(parent[f]!)));
  edgesFaces.forEach((fs, e) => {
    if (frame.edgesAssignment[e] !== "J" || fs.length !== 2) return;
    const [a, b] = [find(fs[0]!), find(fs[1]!)];
    if (a !== b) parent[Math.max(a, b)] = Math.min(a, b);
  });
  const nodes: number[][] = [];
  const nodeOf = new Array<number>(n);
  const index = new Map<number, number>();
  for (let f = 0; f < n; f++) {
    const root = find(f);
    let k = index.get(root);
    if (k === undefined) { k = nodes.length; index.set(root, k); nodes.push([]); }
    nodes[k]!.push(f);
    nodeOf[f] = k;
  }
  // the edges between each pair of nodes, keyed "a,b" with a < b
  const between = new Map<string, number[]>();
  const adjacent: Set<number>[] = nodes.map(() => new Set());
  edgesFaces.forEach((fs, e) => {
    if (fs.length !== 2) return;
    const [a, b] = [nodeOf[fs[0]!]!, nodeOf[fs[1]!]!];
    if (a === b) return;
    const key = a < b ? `${a},${b}` : `${b},${a}`;
    between.set(key, [...(between.get(key) ?? []), e]);
    adjacent[a]!.add(b);
    adjacent[b]!.add(a);
  });
  return {
    nodes,
    nodeOf,
    neighbors: (node) => [...(adjacent[node] ?? [])].sort((x, y) => x - y),
    edgesBetween: (a, b) => between.get(a < b ? `${a},${b}` : `${b},${a}`) ?? [],
  };
}
