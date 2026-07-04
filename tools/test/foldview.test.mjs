import { test, expect } from "bun:test";
import { linearExtension, foldedFrame, signedArea, sideUp, pointInPolygon, segInsideIntervals, coveredIntervals } from "../fold2svg.mjs";

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

test("segInsideIntervals: partial crossing yields the inside sub-interval", () => {
  const sq = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const iv = segInsideIntervals([-1, 0.5], [2, 0.5], sq); // crosses x=0..1
  expect(iv.length).toBe(1);
  expect(iv[0][0]).toBeCloseTo(1 / 3, 5); // enters at x=0
  expect(iv[0][1]).toBeCloseTo(2 / 3, 5); // exits at x=1
});

test("segInsideIntervals: endpoint-inside, fully-in and fully-out cases", () => {
  const sq = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const half = segInsideIntervals([0.5, 0.5], [2, 0.5], sq); // starts inside
  expect(half.length).toBe(1);
  expect(half[0][0]).toBeCloseTo(0, 5);
  expect(half[0][1]).toBeCloseTo(1 / 3, 5); // 0.5 + 1.5t = 1 -> t = 1/3
  expect(segInsideIntervals([0.2, 0.5], [0.8, 0.5], sq)).toEqual([[0, 1]]); // fully inside
  expect(segInsideIntervals([2, 2], [3, 3], sq)).toEqual([]); // fully outside
});

test("coveredIntervals: only the sub-segment under a higher face is covered", () => {
  // face 0 = wide lower strip; face 1 = unit square (higher) covering x∈[0,1]
  const F = [[0, 1, 2, 3], [4, 5, 6, 7]];
  const V = [
    [-1, 0], [2, 0], [2, 1], [-1, 1], // face 0 (wide)
    [0, 0], [1, 0], [1, 1], [0, 1],   // face 1 (unit square)
  ];
  const order = [0, 1]; // 1 above 0
  const cov = coveredIntervals([-1, 0.5], [2, 0.5], order, 0, F, V); // edge of face 0
  expect(cov.length).toBe(1);
  expect(cov[0][0]).toBeCloseTo(1 / 3, 5); // x=0
  expect(cov[0][1]).toBeCloseTo(2 / 3, 5); // x=1
  // below-rule: face 0 lies below pos 1 and fully spans the segment
  expect(coveredIntervals([-1, 0.5], [2, 0.5], order, 1, F, V, true)).toEqual([[0, 1]]);
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

test("--hidden dashed x-rays occluded paper-edge (B) edges, not just creases", async () => {
  // fold-occlude has 3 occluded boundary edges under the top face plus 1 crease;
  // the old blanket B-skip dashed only the crease. Guard that paper edges show.
  const p = Bun.spawn(
    ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/fold-occlude.fold", "--view", "top", "--hidden", "dashed"],
    { stdout: "pipe" }
  );
  const svg = await new Response(p.stdout).text();
  const dashedCount = (svg.match(/stroke-dasharray/g) || []).length;
  expect(dashedCount).toBeGreaterThan(1); // more than the single interior crease
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

test("fold2svg tags creases with data-step and constructions with data-construction", async () => {
  // x-midpoint.fold carries beloch:edges provenance (creases d1/d2, each
  // step: null) and beloch:named_points/named_lines (a, b, c, d, center /
  // d1, d2) — enough to exercise both hook kinds without a --constructions
  // opt-in (Task 3: constructions are always emitted; a webview toggles
  // visibility via CSS, it doesn't ask the renderer to omit them).
  const p = Bun.spawn(
    ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/x-midpoint.fold"],
    { stdout: "pipe" }
  );
  const svg = await new Response(p.stdout).text();
  expect(svg).toContain("data-step=");
  expect(svg).toContain('class="construction"');
  expect(svg).toContain("data-construction=");
});

test("construction overlay renders only auxiliary constructions, not crease/corner duplicates", async () => {
  // x-midpoint.bel has both kinds: .center is a genuine auxiliary point (the
  // cross of --d1 --d2, not on the paper), while d1/d2 are named creases
  // (already drawn as solid crease lines with --d1/--d2 labels) and a/b/c/d
  // are the unit-square corners (already dotted+labelled by the CP view).
  // Overlaying the latter two would double-draw the same geometry+label.
  const p = Bun.spawn(
    ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/x-midpoint.fold"],
    { stdout: "pipe" }
  );
  const svg = await new Response(p.stdout).text();
  expect(svg).toContain('data-construction="center"'); // auxiliary point: kept
  expect(svg).not.toContain('data-construction="d1"'); // crease-duplicate: skipped
  expect(svg).not.toContain('data-construction="d2"'); // crease-duplicate: skipped
  expect(svg).not.toContain('data-construction="a"'); // corner-duplicate: skipped
  expect(svg).not.toContain('data-construction="b"'); // corner-duplicate: skipped
  expect(svg).not.toContain('data-construction="c"'); // corner-duplicate: skipped
  expect(svg).not.toContain('data-construction="d"'); // corner-duplicate: skipped
});

test("each crease element carries a crease-M/V/U class alongside data-step", async () => {
  const p = Bun.spawn(
    ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/x-midpoint.fold"],
    { stdout: "pipe" }
  );
  const svg = await new Response(p.stdout).text();
  expect(svg).toMatch(/class="crease-[MVU]"/);
});

test("--step selects the matching file_frames entry; default falls back to the last frame", async () => {
  // cube-root.fold has 3 named-step frames of strictly growing size
  // (vertical_middle < thirds < beloch_fold) — a clean signal that --step
  // actually swaps which frame gets rendered, not just re-rendering the same one.
  const run = (extra) =>
    new Promise((res) => {
      const p = Bun.spawn(
        ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/cube-root.fold", "--view", "top", ...extra],
        { stdout: "pipe" }
      );
      res(new Response(p.stdout).text());
    });
  const lineCount = (svg) => (svg.match(/<line/g) || []).length;
  const vm = await run(["--step", "vertical_middle"]);
  const thirds = await run(["--step", "thirds"]);
  const final = await run(["--step", "beloch_fold"]);
  const dflt = await run([]);
  expect(lineCount(vm)).toBeLessThan(lineCount(thirds));
  expect(lineCount(thirds)).toBeLessThan(lineCount(final));
  expect(dflt).toBe(final); // no --step -> last frame
});
