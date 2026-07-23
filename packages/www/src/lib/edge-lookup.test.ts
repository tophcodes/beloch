import { test, expect } from "bun:test";
import type { Inspect } from "@beloch/scene";
import { edgeOfLine } from "./edge-lookup";

const identity = { tx: (x: number) => x, ty: (y: number) => y };

function fakeEdges(overrides: Partial<Inspect["edges"]> = {}): Inspect["edges"] {
  return {
    ab: {
      name: "ab",
      assignment: "B",
      segments: [{ faces: [0], paper: [[0, 0], [1, 0]], table: [[0, 0], [1, 0]], assignment: "B" }],
    },
    ...overrides,
  };
}

test("edgeOfLine resolves a line matching a segment's table endpoints", () => {
  expect(edgeOfLine(fakeEdges(), 0, 0, 1, 0, identity)).toBe("ab");
});

test("edgeOfLine matches endpoints given in reversed order", () => {
  expect(edgeOfLine(fakeEdges(), 1, 0, 0, 0, identity)).toBe("ab");
});

test("edgeOfLine transforms table coords through the given layout", () => {
  const layout = { tx: (x: number) => x * 10, ty: (y: number) => y * 10 };
  expect(edgeOfLine(fakeEdges(), 0, 0, 10, 0, layout)).toBe("ab");
});

test("edgeOfLine checks every segment of a multi-segment bundle (edge split by a crossing crease)", () => {
  const edges = fakeEdges({
    ab: {
      name: "ab",
      assignment: "B",
      segments: [
        { faces: [0], paper: [[0, 0], [0.5, 0]], table: [[0, 0], [0.5, 0]], assignment: "B" },
        { faces: [1], paper: [[0.5, 0], [1, 0]], table: [[0.5, 0], [1, 0]], assignment: "B" },
      ],
    },
  });
  expect(edgeOfLine(edges, 0.5, 0, 1, 0, identity)).toBe("ab");
});

test("edgeOfLine returns null when no segment matches", () => {
  expect(edgeOfLine(fakeEdges(), 5, 5, 6, 6, identity)).toBeNull();
});

test("edgeOfLine returns null given no edges", () => {
  expect(edgeOfLine({}, 0, 0, 1, 0, identity)).toBeNull();
});
