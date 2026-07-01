import { test, expect } from "bun:test";
import { linearExtension, foldedFrame, signedArea, sideUp, pointInPolygon, edgeCovered } from "../fold2svg.mjs";

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

test("pointInPolygon: inside vs outside a unit square", () => {
  const sq = [[0, 0], [1, 0], [1, 1], [0, 1]];
  expect(pointInPolygon([0.5, 0.5], sq)).toBe(true);
  expect(pointInPolygon([1.5, 0.5], sq)).toBe(false);
});

test("edgeCovered: a point under a higher face is covered", () => {
  // faces: 0 = lower square, 1 = higher square overlapping it
  const F = [[0, 1, 2, 3], [0, 1, 2, 3]];
  const V = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const order = [0, 1]; // 1 is above 0
  expect(edgeCovered([0.5, 0.5], 0, order, F, V)).toBe(true);  // face 1 above pos 0
  expect(edgeCovered([0.5, 0.5], 1, order, F, V)).toBe(false); // nothing above pos 1
});

test("--hidden dashed emits a dashed stroke; hide does not", async () => {
  const run = (extra) =>
    new Promise((res) => {
      const p = Bun.spawn(
        ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/fold-occlude.fold", "--view", "top", ...extra],
        { stdout: "pipe" }
      );
      res(new Response(p.stdout).text());
    });
  const dashed = await run(["--hidden", "dashed"]);
  const hide = await run(["--hidden", "hide"]);
  expect((await dashed).includes("stroke-dasharray")).toBe(true);
  expect((await hide).includes("stroke-dasharray")).toBe(false);
});

test("occlusion view defines a soft layer shadow and a legend panel", async () => {
  const p = Bun.spawn(
    ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/fold-quarter.fold", "--view", "top", "--title", "q"],
    { stdout: "pipe" }
  );
  const svg = await new Response(p.stdout).text();
  expect(svg.includes('id="layerShadow"')).toBe(true); // drop-shadow filter defined
  expect(svg.includes('class="legend-panel"')).toBe(true); // legend backing panel
});
