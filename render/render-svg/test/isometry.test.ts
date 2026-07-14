import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { resolveIsometry } from "../src/isometry";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

test("flat isometry resolves the CP frame, no occlusion, ascending order", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const r = resolveIsometry(scene, { kind: "flat" });
  expect(r.frame).toBe(scene.cp);
  expect(r.occlude).toBe(false);
  // faceOrders is [] on CP → linear extension is the ascending index list
  expect(r.order).toEqual(scene.cp.facesVertices.map((_, i) => i));
  // every CP face is front-up in paper space
  expect(r.faceUp.every(Boolean)).toBe(true);
  expect(r.faceUp.length).toBe(scene.cp.facesVertices.length);
});

test("step isometry resolves that step's frame and occludes", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const last = scene.steps.length - 1;
  const r = resolveIsometry(scene, { kind: "step", index: last });
  expect(r.frame).toBe(scene.steps[last]!.frame);
  expect(r.occlude).toBe(true);
  // order is a permutation of all face indices
  expect([...r.order].sort((a, b) => a - b)).toEqual(
    r.frame.facesVertices.map((_, i) => i),
  );
  expect(r.faceUp.length).toBe(r.frame.facesVertices.length);
});

test("step isometry out of range throws", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  expect(() => resolveIsometry(scene, { kind: "step", index: 99 })).toThrow();
});
