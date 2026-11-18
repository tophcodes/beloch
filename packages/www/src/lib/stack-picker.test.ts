import { test, expect } from "bun:test";
import type { InspectSegment } from "@beloch/scene";
import { stackOrder, segMatchesLine } from "./stack-picker";

function seg(faces: [number, number]): InspectSegment {
  return { faces, paper: [[0, 0], [1, 1]], table: [[0, 0], [1, 1]], assignment: "M" };
}

const sorted = (segs: InspectSegment[], cmp: (a: InspectSegment, b: InspectSegment) => number) =>
  [...segs].sort(cmp).map((s) => s.faces);

test("stackOrder puts the segment on the upper face first when faces are up", () => {
  const cmp = stackOrder([[1, 0, 1]], [true, true]); // 1 above 0
  expect(sorted([seg([0, 0]), seg([1, 1])], cmp)).toEqual([[1, 1], [0, 0]]);
});

test("stackOrder reads the sign against the normal of the second face", () => {
  // g = 0 faces down: [1, 0, +1] puts 1 on the side 0's normal points to, i.e. below 0
  const cmp = stackOrder([[1, 0, 1]], [false, true]);
  expect(sorted([seg([1, 1]), seg([0, 0])], cmp)).toEqual([[0, 0], [1, 1]]);
});

test("stackOrder leaves segments on non-overlapping faces in their given order", () => {
  const cmp = stackOrder([[1, 0, 1]], [true, true, true, true]);
  expect(sorted([seg([2, 2]), seg([3, 3])], cmp)).toEqual([[2, 2], [3, 3]]);
  expect(cmp(seg([2, 2]), seg([3, 3]))).toBe(0);
});

test("stackOrder ignores a zero sign", () => {
  const cmp = stackOrder([[1, 0, 0]], [true, true]);
  expect(cmp(seg([0, 0]), seg([1, 1]))).toBe(0);
});

test("segMatchesLine matches identical endpoints in the same order", () => {
  expect(segMatchesLine([1, 2], [3, 4], 1, 2, 3, 4)).toBe(true);
});

test("segMatchesLine matches endpoints given in reversed order", () => {
  expect(segMatchesLine([1, 2], [3, 4], 3, 4, 1, 2)).toBe(true);
});

test("segMatchesLine matches within the epsilon tolerance", () => {
  expect(segMatchesLine([1, 2], [3, 4], 1.3, 2.3, 3.3, 3.7, 0.5)).toBe(true);
});

test("segMatchesLine rejects a line just outside the epsilon tolerance", () => {
  expect(segMatchesLine([1, 2], [3, 4], 1.6, 2, 3, 4, 0.5)).toBe(false);
});

test("segMatchesLine rejects an unrelated line", () => {
  expect(segMatchesLine([1, 2], [3, 4], 10, 10, 20, 20)).toBe(false);
});

test("segMatchesLine rejects a line matching only one endpoint", () => {
  expect(segMatchesLine([1, 2], [3, 4], 1, 2, 99, 99)).toBe(false);
});
