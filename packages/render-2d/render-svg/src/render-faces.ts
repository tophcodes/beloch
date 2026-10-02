// Face graphs: the two relations between the faces of a flat folded state
// (spec/MODEL.md, def-flat-state), each drawn as a graph. Adjacency joins two
// faces that share a hinge, an edge of the paper they both bound;
// superposition joins two faces that overlap on the table, the pairs
// `faceOrders` lists, the upper one above the lower. Ida draws graphs of these
// relations for the crane folded by Eos [ida2020, Fig. 7.23, 7.24]. After
// Ida's step 15 the superposition graph here is the graph of Fig. 7.24, 44
// nodes and 52 edges. The adjacency graph keeps Ida's relation (Def. 7.4) and
// stands its nodes on the paper, where Fig. 7.23 lays them out free of it.
//
// A node is a node of the scene's face graph (`faceGraph`, read from
// `edges_faces`): one face, or the faces a `J` edge joins, which FOLD counts as
// one. A node is named by the smallest number among its faces, each face
// numbered by its place in `faces_vertices` from 1, and it stands at the
// centre of its largest face, which lies inside the node however its faces
// are shaped.
//
// The adjacency graph stands on the paper: each node inside its faces, and
// each hinge between two nodes a path from one through the middle of the
// hinge into the other, drawn in the hinge's letter, dashed when it is flat.
// The superposition graph stands in levels, the top layer first, and only the
// pairs no third node lies between are drawn, since the rest follow from
// them. A node first lies one level below the lowest node above it. Then each
// node moves, within the levels its pairs allow, to the end where more of
// its drawn lines go, and down at a tie, which keeps the lines short in total
// and ends a short column beside a long one where the long one ends. A line
// across several levels bends at each level between, at a point that takes
// a place in that level as a node does, so it passes no node.
// `beloch:faces_matrix` brings a folded face back onto the paper.
import type { Assignment, FoldScene, Vec2 } from "@beloch/scene";
import { faceGraph, pickStep, SceneError } from "@beloch/scene";
import { createDoc, el, SvgDoc } from "./svgdoc";
import type { SvgNode } from "./svgdoc";
import { colorLineStyle, DEFAULT_THEME } from "./theme";
import type { Theme } from "./theme";
import { signedArea } from "./geometry";
import { resolveIsometry } from "./isometry";
import { makeLayout } from "./layout";
import { paperFrame } from "./render-operation";
import type { RenderOptions } from "./render-cp";

export interface FacesOptions extends RenderOptions {
  step?: string | undefined; // frame index; undefined → final state
}

// A node of the face graph: its name, the numbers of its faces, their
// polygons on the paper, the point it stands at, and whether its front lies
// up on the table.
export interface GraphNode { name: number; faces: number[]; paper: Vec2[][]; at: Vec2; up: boolean }
// One edge of the paper between two nodes, named the smaller first. A folded
// hinge carries `M` or `V`, a flat one `F`.
export interface Hinge { nodes: [number, number]; edge: number; assignment: Assignment; paper: [Vec2, Vec2] }
// The superposition relation by node names: `above` holds every overlapping
// pair once, the upper node first; `covers` the pairs with no third node
// between them; `level` the row of each node, in the order of `nodes`, 0 for
// the top row.
export interface Layers { above: [number, number][]; covers: [number, number][]; level: number[] }
export interface FaceGraphs { nodes: GraphNode[]; hinges: Hinge[]; layers: Layers }

// The levels and the covering pairs of an "above" relation on faces 0..n-1.
// A flat-foldable state can have faces that lie over one another in a cycle
// (spec/MODEL.md, rem-linear-extension); the faces of one cycle share a level.
export function layerGraph(n: number, above: [number, number][]): { covers: [number, number][]; level: number[] } {
  const out: number[][] = Array.from({ length: n }, () => []);
  for (const [f, g] of above) if (!out[f]!.includes(g)) out[f]!.push(g);
  // every face below f, through any chain
  const below = out.map((_, f) => {
    const seen = new Set<number>();
    const stack = [...out[f]!];
    while (stack.length) {
      const g = stack.pop()!;
      if (seen.has(g)) continue;
      seen.add(g);
      stack.push(...out[g]!);
    }
    return seen;
  });
  // the cycles, as classes of faces each below the other
  const cls = Array.from({ length: n }, (_, f) => f);
  for (let f = 0; f < n; f++) {
    for (let g = 0; g < f; g++) {
      if (below[f]!.has(g) && below[g]!.has(f)) { cls[f] = cls[g]!; break; }
    }
  }
  // a face lies one level below the lowest face of another class above it
  const level = new Array<number>(n).fill(-1);
  const levelOf = (f: number): number => {
    if (level[f]! >= 0) return level[f]!;
    const members = cls.flatMap((c, g) => (c === cls[f] ? [g] : []));
    let l = 0;
    for (let g = 0; g < n; g++) {
      if (cls[g] !== cls[f] && members.some((m) => below[g]!.has(m))) l = Math.max(l, levelOf(g) + 1);
    }
    for (const m of members) level[m] = l;
    return l;
  };
  for (let f = 0; f < n; f++) levelOf(f);
  // f covers g when no other face h lies below f and above g
  const covers: [number, number][] = [];
  out.forEach((gs, f) => {
    for (const g of gs) {
      const between = gs.some((h) => h !== g && h !== f && below[h]!.has(g) && !(cls[h] === cls[f] && cls[h] === cls[g]));
      if (!between) covers.push([f, g]);
    }
  });
  // Then each class moves, between the lowest level of the faces above it
  // and the highest of the faces below it, to the end where more of its
  // covering lines go, and down when as many go up as down. Each move
  // shortens the lines in total or, at a tie, goes down, so the moves stop.
  let moved = true;
  while (moved) {
    moved = false;
    for (let f = 0; f < n; f++) {
      if (cls[f] !== f) continue;
      let hi = -1, lo = Infinity, ups = 0, downs = 0;
      for (const [a, b] of out.flatMap((gs, a) => gs.map((b) => [a, b] as const))) {
        if (cls[a] === f && cls[b] !== f) lo = Math.min(lo, level[b]! - 1);
        if (cls[b] === f && cls[a] !== f) hi = Math.max(hi, level[a]! + 1);
      }
      for (const [a, b] of covers) {
        if (cls[a] === f && cls[b] !== f) downs++;
        if (cls[b] === f && cls[a] !== f) ups++;
      }
      const to = ups > downs ? hi : downs > 0 ? lo : level[f]!;
      if (to !== level[f]) {
        cls.forEach((c, g) => { if (c === f) level[g] = to; });
        moved = true;
      }
    }
  }
  return { covers, level };
}

export function faceGraphs(scene: FoldScene, stepLabel?: string): FaceGraphs {
  const step = pickStep(scene, stepLabel);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  const { frame, faceUp } = resolveIsometry(scene, { kind: "step", index: step.index });
  const graph = faceGraph(frame);
  const paper = paperFrame(frame);
  const polygon = (f: number) => paper.facesVertices[f]!.map((v) => paper.vertices[v]!);
  const nodes: GraphNode[] = graph.nodes.map((fs) => {
    const largest = fs.reduce((a, b) => (Math.abs(signedArea(polygon(b))) > Math.abs(signedArea(polygon(a))) ? b : a));
    return {
      name: fs[0]! + 1, faces: fs.map((f) => f + 1), paper: fs.map(polygon),
      at: centre(polygon(largest)), up: faceUp[fs[0]!]!,
    };
  });
  const hinges: Hinge[] = [];
  graph.nodes.forEach((_, a) => {
    for (const b of graph.neighbours(a)) {
      if (b < a) continue;
      for (const e of graph.edgesBetween(a, b)) {
        const [u, v] = frame.edgesVertices[e]!;
        hinges.push({
          nodes: [nodes[a]!.name, nodes[b]!.name], edge: e,
          assignment: frame.edgesAssignment[e]!,
          paper: [paper.vertices[u]!, paper.vertices[v]!],
        });
      }
    }
  });
  // FOLD's sign is keyed to the second face's normal: [f, g, +1] puts f on
  // the side g's normal points to, which is up when g lies face up. Faces of
  // one node lie side by side and never overlap each other.
  const pairs = new Map<string, [number, number]>();
  for (const [f, g, s] of frame.faceOrders) {
    if (s === 0) continue;
    const [hi, lo] = (s > 0) === faceUp[g] ? [f, g] : [g, f];
    const [a, b] = [graph.nodeOf[hi]!, graph.nodeOf[lo]!];
    if (a !== b) pairs.set(`${a},${b}`, [a, b]);
  }
  const above = [...pairs.values()];
  const { covers, level } = layerGraph(nodes.length, above);
  const named = (ps: [number, number][]) => ps.map(([a, b]) => [nodes[a]!.name, nodes[b]!.name] as [number, number]);
  return { nodes, hinges, layers: { above: named(above), covers: named(covers), level } };
}

const centre = (poly: Vec2[]): Vec2 =>
  [poly.reduce((s, p) => s + p[0], 0) / poly.length, poly.reduce((s, p) => s + p[1], 0) / poly.length];

const many = (n: number, word: string) => `${n} ${word}${n === 1 ? "" : "s"}`;

const PAD = 56, DX = 30, DY = 36, R = 11, MIN_W = 380;

// Where the nodes of the adjacency graph stand: each at the point it stands
// at, unless that puts it on another node, as the slivers of a crane's
// points do. Nodes that overlap are pushed apart until none does, each pulled
// back a little towards that point every round, so a node stands as near it
// as the others allow.
export function spreadNodes(anchors: Vec2[], gap = 2 * R + 2): Vec2[] {
  const p = anchors.map(([x, y]) => [x, y] as Vec2);
  for (let round = 0; round < 400; round++) {
    if (round > 0) {
      p.forEach((q, i) => { q[0] += (anchors[i]![0] - q[0]) * 0.02; q[1] += (anchors[i]![1] - q[1]) * 0.02; });
    }
    let moved = false;
    for (let i = 0; i < p.length; i++) {
      for (let j = i + 1; j < p.length; j++) {
        let dx = p[j]![0] - p[i]![0], dy = p[j]![1] - p[i]![1];
        let d = Math.hypot(dx, dy);
        if (d >= gap) continue;
        // two nodes on one spot part along a direction fixed by their order
        if (d < 1e-9) { dx = Math.cos(i + j); dy = Math.sin(i + j); d = 1; }
        const push = (gap - d) / 2 + 0.01;
        p[i]![0] -= (dx / d) * push; p[i]![1] -= (dy / d) * push;
        p[j]![0] += (dx / d) * push; p[j]![1] += (dy / d) * push;
        moved = true;
      }
    }
    if (!moved) break;
  }
  return p;
}

// The colour and dash of a hinge: its letter, dashed when it is flat.
function hingeStyle(h: Hinge, theme: Theme): Record<string, string | number> {
  if (h.assignment === "M" || h.assignment === "V") {
    return { stroke: colorLineStyle(h.assignment, theme).stroke, "stroke-width": 2 };
  }
  return { stroke: theme.flat, "stroke-width": 1.5, "stroke-dasharray": "4 3" };
}

function node(n: GraphNode, x: number, y: number, theme: Theme, extra: Record<string, string | number> = {}): SvgNode {
  return el("g", {
    "data-kind": "node", "data-name": n.name, "data-faces": n.faces.join(" "), "data-up": String(n.up), ...extra,
  }, [
    el("circle", { cx: x, cy: y, r: R, fill: n.up ? theme.front : theme.back, stroke: theme.ink, "stroke-width": 1.2 }),
    el("text", {
      x, y: y + 4, "text-anchor": "middle", "font-size": 11, fill: theme.ink,
    }, [], String(n.name)),
  ]);
}

function captionAt(text: string, x: number, y: number, theme: Theme): SvgNode {
  return el("text", { x, y, "text-anchor": "middle", "font-size": 15, fill: theme.ink }, [], text);
}

// The points of each level, by index into `level` and `x`, ordered to keep
// the `lines` between levels short: each point moves towards the mean place
// of the points it touches in the level above, then in the level below, a
// few times over. The order starts from `x`, left to right.
function orderLevels(level: number[], x: number[], lines: [number, number][]): number[][] {
  const rows: number[][] = [];
  level.forEach((l, i) => { (rows[l] ??= []).push(i); });
  for (let l = 0; l < rows.length; l++) rows[l] ??= [];
  for (const row of rows) row.sort((a, b) => x[a]! - x[b]! || a - b);
  const pos = new Map<number, number>();
  const place = () => rows.forEach((row) => row.forEach((f, k) => pos.set(f, k / Math.max(row.length - 1, 1))));
  const ups = new Map<number, number[]>(), downs = new Map<number, number[]>();
  for (const [hi, lo] of lines) {
    ups.set(lo!, [...(ups.get(lo!) ?? []), hi!]);
    downs.set(hi!, [...(downs.get(hi!) ?? []), lo!]);
  }
  const mean = (fs: number[] | undefined, own: number) =>
    fs && fs.length ? fs.reduce((s, f) => s + pos.get(f)!, 0) / fs.length : pos.get(own)!;
  place();
  for (let sweep = 0; sweep < 6; sweep++) {
    const along = sweep % 2 === 0 ? ups : downs;
    const seq = sweep % 2 === 0 ? rows : [...rows].reverse();
    for (const row of seq) {
      const key = new Map(row.map((f) => [f, mean(along.get(f), f)]));
      row.sort((a, b) => key.get(a)! - key.get(b)! || pos.get(a)! - pos.get(b)!);
      row.forEach((f, k) => pos.set(f, k / Math.max(row.length - 1, 1)));
    }
  }
  return rows;
}

export function renderFaces(scene: FoldScene, opts: FacesOptions = {}): SvgDoc {
  const g = faceGraphs(scene, opts.step);
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const index = new Map(g.nodes.map((n, i) => [n.name, i]));
  const byName = (name: number) => g.nodes[index.get(name)!]!;

  // adjacency, on the paper
  const lay = makeLayout(g.nodes.flatMap((n) => n.paper.flat()));
  const at = (p: Vec2): Vec2 => [lay.tx(p[0]), lay.ty(p[1])];
  const pts = (ps: Vec2[]) => ps.map((p) => at(p).map((c) => c.toFixed(2)).join(",")).join(" ");
  const adjacency: SvgNode[] = [
    el("rect", { x: 0, y: 0, width: lay.W, height: lay.H, fill: theme.background }),
  ];
  for (const n of g.nodes) {
    n.paper.forEach((poly, k) => adjacency.push(el("polygon", {
      "data-kind": "face", "data-name": n.faces[k]!, "data-node": n.name, points: pts(poly),
      fill: theme.fill, stroke: theme.boundary, "stroke-width": 0.8, "stroke-opacity": 0.35,
    })));
  }
  for (const h of g.hinges) {
    const [a, b] = h.nodes.map((n) => at(byName(n).at)) as [Vec2, Vec2];
    const m = at([(h.paper[0][0] + h.paper[1][0]) / 2, (h.paper[0][1] + h.paper[1][1]) / 2]);
    adjacency.push(el("polyline", {
      "data-kind": "hinge", "data-nodes": h.nodes.join(" "), "data-assignment": h.assignment,
      points: [a, m, b].map((p) => p.map((c) => c.toFixed(2)).join(",")).join(" "),
      fill: "none", "stroke-linejoin": "round", ...hingeStyle(h, theme),
    }));
  }
  // a node pushed off the point it stands at keeps a thin line back to it
  const anchors = g.nodes.map((n) => at(n.at));
  const spots = spreadNodes(anchors);
  g.nodes.forEach((_, i) => {
    const [[ax, ay], [x, y]] = [anchors[i]!, spots[i]!];
    if (Math.hypot(x - ax, y - ay) < R) return;
    adjacency.push(
      el("line", { "data-kind": "leader", x1: ax, y1: ay, x2: x, y2: y, stroke: theme.ink, "stroke-width": 0.8 }),
      el("circle", { cx: ax, cy: ay, r: 1.8, fill: theme.ink }),
    );
  });
  g.nodes.forEach((n, i) => adjacency.push(node(n, ...spots[i]!, theme)));
  adjacency.push(captionAt(`adjacency: ${many(g.nodes.length, "face")}, ${many(g.hinges.length, "hinge")}`, lay.W / 2, lay.H - 16, theme));
  if (opts.title) {
    adjacency.push(el("text", { x: 16, y: 28, "font-size": 16, "font-weight": 600, fill: theme.ink }, [], opts.title));
  }

  // superposition, in levels, the top layer first; a line that spans several
  // levels bends at each level between, at a point that takes its place in
  // that level beside the nodes, so no line runs through a node
  const level = [...g.layers.level];
  const x = g.nodes.map((n) => n.at[0]);
  const lines = g.layers.covers.map(([hi, lo]) => {
    const [a, b] = [index.get(hi)!, index.get(lo)!];
    const path = [a];
    for (let l = level[a]! + 1; l < level[b]!; l++) {
      const t = (l - level[a]!) / (level[b]! - level[a]!);
      path.push(level.length);
      level.push(l);
      x.push(x[a]! + t * (x[b]! - x[a]!));
    }
    return { hi, lo, path: [...path, b] };
  });
  const rows = orderLevels(level, x, lines.flatMap(({ path }) => path.slice(1).map((b, k) => [path[k]!, b] as [number, number])));
  const widest = Math.max(1, ...rows.map((r) => r.length));
  const SW = Math.max(MIN_W, (widest - 1) * DX + 2 * PAD);
  const SH = Math.max(lay.H, (rows.length - 1) * DY + 2 * PAD);
  const top = (SH - (rows.length - 1) * DY) / 2;
  const place = new Map<number, Vec2>();
  rows.forEach((row, l) => row.forEach((f, k) => {
    place.set(f, [SW / 2 + (k - (row.length - 1) / 2) * DX, top + l * DY]);
  }));
  const superposition: SvgNode[] = [
    el("rect", { x: 0, y: 0, width: SW, height: SH, fill: theme.background }),
  ];
  for (const { hi, lo, path } of lines) {
    const ps = path.map((f) => place.get(f)!);
    // faces of one cycle share a level, and the line between them says
    // which lies above with an arrow
    const flat = Math.abs(ps[0]![1] - ps[ps.length - 1]![1]) < 1e-9;
    superposition.push(el("polyline", {
      "data-kind": "cover", "data-nodes": `${hi} ${lo}`, points: ps.map((p) => p.join(",")).join(" "),
      fill: "none", stroke: theme.ink, "stroke-width": 1.2, "stroke-opacity": 0.55,
      ...(flat ? { "marker-end": "url(#face-graphs-arrow)" } : {}),
    }));
  }
  g.nodes.forEach((n, i) => {
    const [x, y] = place.get(i)!;
    superposition.push(node(n, x, y, theme, { "data-level": g.layers.level[i]! }));
  });
  superposition.push(captionAt(
    `superposition: ${many(g.layers.above.length, "overlapping pair")}, top first`, SW / 2, SH - 16, theme,
  ));

  const H = Math.max(lay.H, SH);
  const doc = createDoc(lay.W + SW, H);
  doc.root.children.push(
    el("defs", {}, [el("marker", {
      // 8 px wide, its tip on the rim of the node it points to
      id: "face-graphs-arrow", viewBox: "0 0 10 10", refX: 10 + R / 0.8, refY: 5,
      markerUnits: "userSpaceOnUse", markerWidth: 8, markerHeight: 8, orient: "auto",
    }, [el("path", { d: "M 0 0 L 10 5 L 0 10 z", fill: theme.ink })])]),
    el("svg", { x: 0, y: 0, width: lay.W, height: H, "data-graph": "adjacency" }, adjacency),
    el("svg", { x: lay.W, y: 0, width: SW, height: H, "data-graph": "superposition" }, superposition),
  );
  return doc;
}
