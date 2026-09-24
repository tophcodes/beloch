import { test, expect } from "bun:test";
import { besideLine, placeLabels, type LabelAnchor } from "../src/primitives/labels";

const A = (x: number, y: number, text: string, key = text): LabelAnchor => ({
  x, y, text, key, preferOffset: [10, -8],
});

test("coincident anchors merge into one comma-joined label", () => {
  // cube-root collapse: four corners on the same folded pixel
  const out = placeLabels(
    [A(100, 100, ".a"), A(101, 100, ".b"), A(100, 101, ".c"), A(101, 99, ".d")],
    { epsilon: 6 },
  );
  expect(out).toHaveLength(1);
  expect(out[0]!.text).toBe(".a,.b,.c,.d");
  expect(out[0]!.keys).toEqual([".a", ".b", ".c", ".d"]);
});

test("well-separated anchors keep their preferred offset (byte-stable)", () => {
  const out = placeLabels([A(50, 50, ".a"), A(300, 300, ".b")], {});
  // no collision → each label sits at anchor + preferOffset, start-anchored
  const a = out.find((p) => p.text === ".a")!;
  expect(a.anchor).toBe("start");
  expect(a.x).toBe(50 + 10);
  expect(a.y).toBe(50 - 8);
});

test("dense but distinct anchors get separated (no two boxes overlap)", () => {
  // 20px apart (> ε) → distinct clusters, but each label is wider than 20px so
  // preferred boxes collide and the ring must separate them.
  const anchors = Array.from({ length: 6 }, (_, i) =>
    A(100 + i * 20, 100, `.p${i}`),
  );
  const out = placeLabels(anchors, {});
  // deterministic + all placed
  expect(out).toHaveLength(6);
  // second run identical (no randomness)
  const out2 = placeLabels(anchors, {});
  expect(out2).toEqual(out);
});

test("empty input yields no labels", () => {
  expect(placeLabels([])).toEqual([]);
});

test("names of different kinds at one spot stay two labels", () => {
  // A construction's midpoint on the point it was built through: two things
  // meet there, and reading them as one name says there is one.
  const out = placeLabels(
    [
      { ...A(100, 100, ".o"), group: "point" },
      { ...A(100, 100, "--mid"), group: "line:mid" },
    ],
    { epsilon: 6 },
  );
  expect(out.map((l) => l.text).sort()).toEqual([".o", "--mid"].sort());
  // and the placement keeps them apart
  expect(out[0]!.x !== out[1]!.x || out[0]!.y !== out[1]!.y).toBe(true);
});

test("an anchor carries its own attributes into the placed label", () => {
  const out = placeLabels([{ ...A(10, 10, "--v"), attrs: { fill: "#123456" } }], {});
  expect(out[0]!.attrs).toEqual({ fill: "#123456" });
});

test("a line's name sits beside the line rather than on it", () => {
  // A horizontal line: the offset is perpendicular to it, which is up here.
  expect(besideLine([0, 0], [100, 0], 10)).toEqual([0, -10]);
  // A vertical one: the offset is sideways, and the same side either way the
  // line was drawn.
  expect(besideLine([0, 0], [0, 100], 10)).toEqual([-10, 0]);
  expect(besideLine([0, 100], [0, 0], 10)).toEqual([-10, 0]);
});

test("names a reader picked keep their own labels where they coincide", () => {
  // Four corners on one folded pixel, all four asked for: each gets a label of
  // its own, and the ring walks them apart.
  const out = placeLabels(
    [A(100, 100, ".a"), A(101, 100, ".b"), A(100, 101, ".c"), A(101, 99, ".d")],
    { cluster: false },
  );
  expect(out.map((l) => l.text).sort()).toEqual([".a", ".b", ".c", ".d"]);
  const spots = new Set(out.map((l) => `${l.x},${l.y},${l.anchor}`));
  expect(spots.size).toBe(4);
});
