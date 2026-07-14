// Ported from tools/test/foldview.test.mjs — pure geometry helpers only.
// `foldedFrame` (fold2svg.mjs merge-over-root helper) is not ported; its job
// is done by @beloch/scene's parseFold + pickStep (Task 2). Tests that only
// used foldedFrame as setup are adapted to build a Frame that way; tests that
// exercised the full fold2svg CLI (SVG string assertions on --hidden dashed,
// data-step/data-construction hooks, crease-M/V/U classes, --step selection)
// are NOT ported here — they test CLI/SVG-generation behavior outside this
// task's scope (pure geometry helpers), not the ported functions themselves.
import { test, expect } from "bun:test";
import { parseFold, pickStep, linearExtension, signedArea, sideUp } from "@beloch/scene";
import type { Vec2 } from "@beloch/scene";
import {
  pointInPolygon,
  segInsideIntervals,
  coveredIntervals,
  lineToFace,
} from "../src/geometry";

const quarterRaw = await Bun.file(
  new URL("./fixtures/fold-quarter.fold", import.meta.url),
).text();
const quarterScene = parseFold(quarterRaw);

test("linearExtension yields the true global bottom→top stack (honours g's normal)", () => {
  const ff = pickStep(quarterScene)!.frame;
  const V = ff.vertices;
  const F = ff.facesVertices;
  const faceUp = F.map((f) => sideUp(f.map((i) => V[i]!)) === "front");
  const order = linearExtension(ff.faceOrders, F.length, faceUp);
  // bottom->top: every face appears exactly once
  expect([...order].sort((a, b) => a - b)).toEqual(F.map((_, i) => i));
  // golden: the quarter fold stacks in face-index order — root-cause regression
  // guard (a naive read of the sign scrambled this to [3,1,0,2]).
  expect(order).toEqual([0, 1, 2, 3]);
  const pos = new Map(order.map((f, i) => [f, i]));
  for (const [f, g, s] of ff.faceOrders) {
    if (s === 0) continue;
    // FOLD sign is relative to g's normal: f is globally below g iff (s<0)===gUp
    const fBelowG = (s < 0) === faceUp[g]!;
    if (fBelowG) expect(pos.get(f)).toBeLessThan(pos.get(g)!);
    else expect(pos.get(f)).toBeGreaterThan(pos.get(g)!);
  }
});

test("lineToFace pulls a paper line into a face's table frame", () => {
  expect(lineToFace([1, 0, 0, 1, 0, 0], 1, 0, 5)).toEqual([1, 0, 5]); // identity: x=5 unchanged
  expect(lineToFace([1, 0, 0, 1, 2, 3], 1, 0, 5)).toEqual([1, 0, 7]); // +2 in x: x=5 → x=7
  expect(lineToFace([0, -1, 1, 0, 0, 0], 1, 0, 5)).toEqual([0, 1, 5]); // 90° rotation: x=5 → y=5
});

test("signedArea is positive for a CCW square, negative reversed", () => {
  const ccw: Vec2[] = [[0, 0], [1, 0], [1, 1], [0, 1]];
  expect(signedArea(ccw)).toBeGreaterThan(0);
  expect(signedArea([...ccw].reverse())).toBeLessThan(0);
});

test("sideUp maps winding to front/back", () => {
  expect(sideUp([[0, 0], [1, 0], [1, 1], [0, 1]])).toBe("front");
  expect(sideUp([[0, 0], [0, 1], [1, 1], [1, 0]])).toBe("back");
});

test("fold-quarter top view has both a front and a back face", () => {
  const ff = pickStep(quarterScene)!.frame;
  const V = ff.vertices;
  const sides = ff.facesVertices.map((f) => sideUp(f.map((i) => V[i]!)));
  expect(sides).toContain("front");
  expect(sides).toContain("back");
});

test("pointInPolygon: inside vs outside a unit square", () => {
  const sq: Vec2[] = [[0, 0], [1, 0], [1, 1], [0, 1]];
  expect(pointInPolygon([0.5, 0.5], sq)).toBe(true);
  expect(pointInPolygon([1.5, 0.5], sq)).toBe(false);
});

test("segInsideIntervals: partial crossing yields the inside sub-interval", () => {
  const sq: Vec2[] = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const iv = segInsideIntervals([-1, 0.5], [2, 0.5], sq); // crosses x=0..1
  expect(iv.length).toBe(1);
  expect(iv[0]![0]).toBeCloseTo(1 / 3, 5); // enters at x=0
  expect(iv[0]![1]).toBeCloseTo(2 / 3, 5); // exits at x=1
});

test("segInsideIntervals: endpoint-inside, fully-in and fully-out cases", () => {
  const sq: Vec2[] = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const half = segInsideIntervals([0.5, 0.5], [2, 0.5], sq); // starts inside
  expect(half.length).toBe(1);
  expect(half[0]![0]).toBeCloseTo(0, 5);
  expect(half[0]![1]).toBeCloseTo(1 / 3, 5); // 0.5 + 1.5t = 1 -> t = 1/3
  expect(segInsideIntervals([0.2, 0.5], [0.8, 0.5], sq)).toEqual([[0, 1]]); // fully inside
  expect(segInsideIntervals([2, 2], [3, 3], sq)).toEqual([]); // fully outside
});

test("coveredIntervals: only the sub-segment under a higher face is covered", () => {
  // face 0 = wide lower strip; face 1 = unit square (higher) covering x∈[0,1]
  const F = [[0, 1, 2, 3], [4, 5, 6, 7]];
  const V: Vec2[] = [
    [-1, 0], [2, 0], [2, 1], [-1, 1], // face 0 (wide)
    [0, 0], [1, 0], [1, 1], [0, 1], // face 1 (unit square)
  ];
  const order = [0, 1]; // 1 above 0
  const cov = coveredIntervals([-1, 0.5], [2, 0.5], order, 0, F, V); // edge of face 0
  expect(cov.length).toBe(1);
  expect(cov[0]![0]).toBeCloseTo(1 / 3, 5); // x=0
  expect(cov[0]![1]).toBeCloseTo(2 / 3, 5); // x=1
  // below-rule: face 0 lies below pos 1 and fully spans the segment
  expect(coveredIntervals([-1, 0.5], [2, 0.5], order, 1, F, V, true)).toEqual([[0, 1]]);
});
