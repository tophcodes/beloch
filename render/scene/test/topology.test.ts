import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";

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
