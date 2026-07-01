import { test, expect } from "bun:test";
import { linearExtension, foldedFrame } from "../fold2svg.mjs";

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
