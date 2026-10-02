import { test, expect } from "bun:test";
import { faceGraph, parseFold } from "@beloch/scene";

// `fold-quarter-faces.fold`: packages/core/tests/cases/fold/fold-quarter.bel,
// written with `beloch fold`. `join-edge.fold`, written by hand: an L-shaped
// sheet of three faces, the bar and the cell above its left end joined by a
// `J` edge, and a third cell above that one across a marked `F` crease.
// `fold-quarter.fold` was written before `edges_faces` existed.
const fixture = async (p: string) =>
  parseFold(await Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text());

test("every frame reads edges_faces, one face on a boundary edge and two on a crease", async () => {
  const scene = await fixture("fold-quarter-faces.fold");
  for (const frame of [scene.cp, ...scene.steps.map((s) => s.frame)]) {
    expect(frame.edgesFaces).not.toBeNull();
    frame.edgesFaces!.forEach((fs, e) => {
      expect(fs.length).toBe(frame.edgesAssignment[e] === "B" ? 1 : 2);
      const [u, v] = frame.edgesVertices[e]!;
      for (const f of fs) expect(frame.facesVertices[f]).toEqual(expect.arrayContaining([u, v]));
    });
  }
});

test("a sheet folded in quarters: four nodes in a ring, one edge between neighbors", async () => {
  const scene = await fixture("fold-quarter-faces.fold");
  const g = faceGraph(scene.steps[scene.steps.length - 1]!.frame);
  expect(g.nodes).toEqual([[0], [1], [2], [3]]);
  expect(g.nodeOf).toEqual([0, 1, 2, 3]);
  expect(g.nodes.map((_, k) => g.neighbors(k).length)).toEqual([2, 2, 2, 2]);
  for (let a = 0; a < 4; a++) {
    for (const b of g.neighbors(a)) expect(g.edgesBetween(a, b).length).toBe(1);
    expect(g.edgesBetween(a, a)).toEqual([]);
  }
  // nodes across the ring share no edge
  const far = [0, 1, 2, 3].find((b) => b !== 0 && !g.neighbors(0).includes(b))!;
  expect(g.edgesBetween(0, far)).toEqual([]);
});

test("faces joined across a J edge are one node; an F edge separates nodes", async () => {
  const scene = await fixture("join-edge.fold");
  for (const frame of [scene.cp, scene.steps[0]!.frame]) {
    const g = faceGraph(frame);
    expect(g.nodes).toEqual([[0, 1], [2]]);
    expect(g.nodeOf).toEqual([0, 0, 1]);
    expect(g.neighbors(0)).toEqual([1]);
    expect(g.neighbors(1)).toEqual([0]);
    // the F edge, and not the J edge inside the first node
    expect(g.edgesBetween(0, 1)).toEqual([6]);
    expect(g.edgesBetween(1, 0)).toEqual([6]);
    expect(g.edgesBetween(0, 0)).toEqual([]);
  }
});

test("a file written before edges_faces has no face graph, and says how to get one", async () => {
  const scene = await fixture("fold-quarter.fold");
  expect(scene.cp.edgesFaces).toBeNull();
  expect(scene.steps.every((s) => s.frame.edgesFaces === null)).toBe(true);
  expect(() => faceGraph(scene.cp)).toThrow("no edges_faces");
});
