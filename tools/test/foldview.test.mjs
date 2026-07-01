import { test, expect } from "bun:test";
import { linearExtension, foldedFrame, signedArea, sideUp, pointInPolygon, edgeCovered } from "../fold2svg.mjs";

const quarter = JSON.parse(
  await Bun.file(new URL("./fixtures/fold-quarter.fold", import.meta.url)).text()
);

test("linearExtension yields the true global bottom→top stack (honours g's normal)", () => {
  const ff = foldedFrame(quarter);
  const V = ff.vertices_coords;
  const F = quarter.faces_vertices || [];
  const faceUp = F.map((f) => sideUp(f.map((i) => V[i])) === "front");
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
    const fBelowG = (s < 0) === faceUp[g];
    if (fBelowG) expect(pos.get(f)).toBeLessThan(pos.get(g));
    else expect(pos.get(f)).toBeGreaterThan(pos.get(g));
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

test("edgeCovered below-rule: a point over a lower face is covered from beneath", () => {
  const F = [[0, 1, 2, 3], [0, 1, 2, 3]];
  const V = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const order = [0, 1]; // 0 below 1
  // from below (bottom view), the occluder is a face at a LOWER position
  expect(edgeCovered([0.5, 0.5], 1, order, F, V, true)).toBe(true);  // face 0 below pos 1
  expect(edgeCovered([0.5, 0.5], 0, order, F, V, true)).toBe(false); // nothing below pos 0
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
