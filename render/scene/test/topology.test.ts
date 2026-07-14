import { test, expect } from "bun:test";
import { parseFold, computeFaceDepth } from "@beloch/scene";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

test("faceDepth: quartered sheet is a full 4-layer stack", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const frame = scene.steps[scene.steps.length - 1]!.frame; // fully folded, 4 faces
  expect(frame.faceDepth.length).toBe(frame.facesVertices.length);
  // a quartered sheet stacks all four faces: depths are a permutation of 0..3
  expect([...frame.faceDepth].sort((a, b) => a - b)).toEqual([0, 1, 2, 3]);
});

test("faceDepth: CP frame (no faceOrders) is all zeros", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  expect(scene.cp.faceDepth.every((d) => d === 0)).toBe(true);
  expect(scene.cp.faceDepth.length).toBe(scene.cp.facesVertices.length);
});

test("faceDepth: two disjoint 2-face stacks stay LOCAL depth, not global paint index", () => {
  // faceOrders links 0-1 and 2-3 as independent overlap pairs (no edge between
  // the two pairs), so each pair is only 2 layers deep. A correct longest-chain
  // depth gives {0,1} within each pair (max depth 1 overall); an implementation
  // that mistakenly returns the global linearExtension index instead would give
  // a permutation of 0..3 (max depth 3) — this test fails against that bug.
  const vertices: [number, number][] = [
    [0, 0], [1, 0], [1, 1], [0, 1], // square A (verts 0-3)
    [2, 0], [3, 0], [3, 1], [2, 1], // square B (verts 4-7)
  ];
  const facesVertices = [
    [0, 1, 2, 3],
    [0, 1, 2, 3],
    [4, 5, 6, 7],
    [4, 5, 6, 7],
  ];
  const faceOrders: [number, number, number][] = [
    [0, 1, -1],
    [2, 3, -1],
  ];
  const depth = computeFaceDepth(facesVertices, vertices, faceOrders);
  expect(Math.max(...depth)).toBe(1);
  expect([...depth].sort((a, b) => a - b)).toEqual([0, 0, 1, 1]);
});
