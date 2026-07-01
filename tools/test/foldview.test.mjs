import { test, expect } from "bun:test";
import { linearExtension, foldedFrame, signedArea, sideUp } from "../fold2svg.mjs";

const quarter = JSON.parse(
  await Bun.file(new URL("./fixtures/fold-quarter.fold", import.meta.url)).text()
);

test("linearExtension respects every faceOrders pair", () => {
  const ff = foldedFrame(quarter);
  const nF = (quarter.faces_vertices || []).length;
  const order = linearExtension(ff.faceOrders, nF);
  // bottom->top: every face appears exactly once
  expect([...order].sort((a, b) => a - b)).toEqual(
    Array.from({ length: nF }, (_, i) => i)
  );
  const pos = new Map(order.map((f, i) => [f, i]));
  for (const [f, g, s] of ff.faceOrders) {
    if (s === 1) expect(pos.get(f)).toBeGreaterThan(pos.get(g)); // f above g
    if (s === -1) expect(pos.get(f)).toBeLessThan(pos.get(g)); // f below g
  }
});

test("signedArea is positive for a CCW square, negative reversed", () => {
  const ccw = [[0, 0], [1, 0], [1, 1], [0, 1]];
  expect(signedArea(ccw)).toBeGreaterThan(0);
  expect(signedArea([...ccw].reverse())).toBeLessThan(0);
});

test("sideUp maps winding to front/back", () => {
  expect(sideUp([[0, 0], [1, 0], [1, 1], [0, 1]])).toBe("front");
  expect(sideUp([[0, 0], [0, 1], [1, 1], [1, 0]])).toBe("back");
});

test("fold-quarter top view has both a front and a back face", () => {
  const ff = foldedFrame(quarter);
  const V = ff.vertices_coords;
  const sides = (quarter.faces_vertices || []).map((f) =>
    sideUp(f.map((i) => V[i]))
  );
  expect(sides).toContain("front");
  expect(sides).toContain("back");
});
