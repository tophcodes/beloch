import { test, expect } from "bun:test";
import { placeLabels, type LabelAnchor } from "../src/primitives/labels";

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
