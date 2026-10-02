import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { faceGraphs, layerGraph, renderFaces, spreadNodes } from "@beloch/render-svg";

// `fold-quarter-faces.fold`: the square folded in half and in half again, so
// its four faces lie in one stack. `bird-base.fold`:
// examples/bases/bird-base.bel. Both written with `beloch fold`.
// `join-edge.fold`, written by hand: an L-shaped sheet of three faces, two
// joined by a `J` edge and the third across a marked `F` crease.
// `fold-quarter.fold` was written before `edges_faces` existed.
// `crane.fold`: examples/crane.bel, written with `beloch fold` and kept to its
// last frame and the fields FOLD defines.
const fixture = async (p: string) =>
  parseFold(await Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text());

const count = (s: string, re: RegExp) => (s.match(re) ?? []).length;

test("the flat sheet is one face, with no hinge and no overlap", async () => {
  const g = faceGraphs(await fixture("fold-quarter-faces.fold"), "0");
  expect(g.nodes.length).toBe(1);
  expect(g.hinges).toEqual([]);
  expect(g.layers.above).toEqual([]);
  expect(g.layers.level).toEqual([0]);
});

test("a square folded in half twice is a stack of four, each face on the next", async () => {
  const g = faceGraphs(await fixture("fold-quarter-faces.fold"));
  expect(g.nodes.length).toBe(4);
  // every two faces overlap, and only the neighbours in the stack are drawn
  expect(g.layers.above.length).toBe(6);
  expect(g.layers.covers.length).toBe(3);
  expect([...g.layers.level].sort()).toEqual([0, 1, 2, 3]);
  const byLevel = g.nodes.map((n) => n.name).sort((a, b) => g.layers.level[a - 1]! - g.layers.level[b - 1]!);
  expect(g.layers.covers).toEqual(expect.arrayContaining(
    [[byLevel[0], byLevel[1]], [byLevel[1], byLevel[2]], [byLevel[2], byLevel[3]]],
  ));
  // the four quarters of the paper are joined by four folded hinges in a ring
  expect(g.hinges.length).toBe(4);
  expect(g.hinges.every((h) => h.assignment === "M" || h.assignment === "V")).toBe(true);
});

test("the bird base: fourteen faces, eighteen hinges, two stacks that meet at the top and the bottom", async () => {
  const scene = await fixture("bird-base.fold");
  const g = faceGraphs(scene);
  const frame = scene.steps[scene.steps.length - 1]!.frame;
  expect(g.nodes.length).toBe(14);
  // a hinge for every edge of the paper that is not the sheet's boundary
  expect(g.hinges.length).toBe(frame.edgesAssignment.filter((a) => a !== "B").length);
  // one pair per entry of faceOrders
  expect(g.layers.above.length).toBe(frame.faceOrders.length);
  // a face lies on a lower level than every face above it
  for (const [hi, lo] of g.layers.above) {
    expect(g.layers.level[hi - 1]!).toBeLessThan(g.layers.level[lo - 1]!);
  }
  // every pair follows from the covering pairs
  const below = (f: number): Set<number> => {
    const out = new Set<number>();
    const go = (h: number) => g.layers.covers.filter(([a]) => a === h).forEach(([, b]) => {
      if (!out.has(b)) { out.add(b); go(b); }
    });
    go(f);
    return out;
  };
  for (const [hi, lo] of g.layers.above) expect(below(hi).has(lo)).toBe(true);
  const top = g.nodes.filter((n) => g.layers.level[n.name - 1] === 0);
  const bottom = Math.max(...g.layers.level);
  expect(top.length).toBe(1);
  expect(g.layers.level.filter((l) => l === bottom).length).toBe(1);
});

test("the faces view draws a node per face in both graphs, a path per hinge and a line per covering pair", async () => {
  const scene = await fixture("bird-base.fold");
  const g = faceGraphs(scene);
  const s = renderFaces(scene).toString();
  expect(count(s, /data-kind="node"/g)).toBe(2 * 14);
  expect(count(s, /data-kind="face"/g)).toBe(14);
  expect(count(s, /data-kind="hinge"/g)).toBe(g.hinges.length);
  expect(count(s, /data-kind="cover"/g)).toBe(g.layers.covers.length);
  expect(s).toContain('data-graph="adjacency"');
  expect(s).toContain('data-graph="superposition"');
  expect(s).toContain("adjacency: 14 faces, 18 hinges");
  expect(s).toContain(`superposition: ${g.layers.above.length} overlapping pairs, top first`);
});

test("faces joined by a J edge are one node, named by its first face and standing in its largest face", async () => {
  const scene = await fixture("join-edge.fold");
  const g = faceGraphs(scene);
  expect(g.nodes.map((n) => [n.name, n.faces])).toEqual([[1, [1, 2]], [3, [3]]]);
  // the bar, face 1, is the larger of the two; its centre lies inside the L
  expect(g.nodes[0]!.at).toEqual([1, 0.6]);
  expect(g.hinges).toEqual([{ nodes: [1, 3], edge: 6, assignment: "F", paper: [[1, 2], [0, 2]] }]);
  const s = renderFaces(scene).toString();
  expect(count(s, /data-kind="node"/g)).toBe(2 * 2);
  expect(count(s, /data-kind="face"/g)).toBe(3);
  expect(count(s, /data-kind="hinge"/g)).toBe(1);
  expect(s).toContain('data-name="1" data-faces="1 2"');
  expect(s).toContain("adjacency: 2 faces, 1 hinge<");
});

test("a file written before edges_faces says how to get the face graphs", async () => {
  const scene = await fixture("fold-quarter.fold");
  expect(() => renderFaces(scene)).toThrow("write it again with `beloch fold`");
});

test("faces that lie over one another in a cycle share a level, and each line of the cycle is drawn", () => {
  // 0 over 1 over 2 over 0, and all three over 3
  const { covers, level } = layerGraph(4, [[0, 1], [1, 2], [2, 0], [0, 3], [1, 3], [2, 3]]);
  expect(level).toEqual([0, 0, 0, 1]);
  expect(covers).toEqual(expect.arrayContaining([[0, 1], [1, 2], [2, 0]]));
});

test("nodes that would overlap are pushed apart, and the others stay where their faces are", () => {
  const spots = spreadNodes([[100, 100], [101, 100], [300, 300]]);
  const [a, b, c] = spots as [[number, number], [number, number], [number, number]];
  expect(Math.hypot(a[0] - b[0], a[1] - b[1])).toBeGreaterThanOrEqual(24);
  expect(c).toEqual([300, 300]);
});

test("a chain beside a longer one ends where the longer one ends", () => {
  // 0 over 1 over 2 over 3 over 4, and 0 over 5 over 4
  const { level } = layerGraph(6, [[0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [5, 4], [0, 2], [0, 3], [0, 4], [1, 3], [1, 4], [2, 4]]);
  expect(level).toEqual([0, 1, 2, 3, 4, 3]);
});

test("the crane: the tail's column ends beside the neck's, and no line runs through a node", async () => {
  const scene = await fixture("crane.fold");
  const g = faceGraphs(scene);
  const levelOf = (name: number) => g.layers.level[g.nodes.findIndex((n) => n.name === name)]!;
  expect(levelOf(18)).toBe(levelOf(16));
  expect(levelOf(18)).toBe(levelOf(14) - 1);
  const s = renderFaces(scene).toString().split('data-graph="superposition"')[1]!;
  const nodes = [...s.matchAll(/data-kind="node" data-name="(\d+)"[^>]*><circle cx="([-\d.]+)" cy="([-\d.]+)" r="([\d.]+)"/g)]
    .map((m) => ({ name: m[1]!, x: +m[2]!, y: +m[3]!, r: +m[4]! }));
  expect(nodes.length).toBe(g.nodes.length);
  // the distance from (x, y) to the segment from a to b
  const dist = (x: number, y: number, [ax, ay]: number[], [bx, by]: number[]) => {
    const [dx, dy] = [bx! - ax!, by! - ay!];
    const t = Math.max(0, Math.min(1, ((x - ax!) * dx + (y - ay!) * dy) / (dx * dx + dy * dy)));
    return Math.hypot(x - ax! - t * dx, y - ay! - t * dy);
  };
  const lines = [...s.matchAll(/data-kind="cover" data-nodes="(\d+) (\d+)" points="([^"]+)"/g)];
  expect(lines.length).toBe(g.layers.covers.length);
  const through: string[] = [];
  for (const [, hi, lo, points] of lines) {
    const ps = points!.split(" ").map((p) => p.split(",").map(Number));
    for (let k = 1; k < ps.length; k++) {
      for (const n of nodes) {
        if (n.name !== hi && n.name !== lo && dist(n.x, n.y, ps[k - 1]!, ps[k]!) < n.r) through.push(`${hi} ${lo} through ${n.name}`);
      }
    }
  }
  expect(through).toEqual([]);
});
