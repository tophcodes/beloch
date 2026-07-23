import { test, expect } from "bun:test";
import type { Inspect, InspectSegment } from "@beloch/scene";
import { segRank, segMatchesLine } from "./stack-picker";

function fakeInsp(ranks: Record<number, number>): Inspect {
  const faces: Inspect["faces"] = {};
  for (const [i, rank] of Object.entries(ranks)) {
    faces[i] = { vertices: [], flap: 0, rank };
  }
  return { creases: {}, faces, points: {}, edges: {} };
}

function seg(faces: [number, number]): InspectSegment {
  return { faces, paper: [[0, 0], [1, 1]], table: [[0, 0], [1, 1]], assignment: "M" };
}

test("segRank is the max rank of a segment's two faces", () => {
  const insp = fakeInsp({ 0: 2, 1: 5 });
  expect(segRank(insp, seg([0, 1]))).toBe(5);
});

test("segRank picks the higher face regardless of argument order", () => {
  const insp = fakeInsp({ 0: 5, 1: 2 });
  expect(segRank(insp, seg([0, 1]))).toBe(5);
});

test("segRank falls back to 0 for a face missing from insp.faces", () => {
  const insp = fakeInsp({ 0: 3 });
  expect(segRank(insp, seg([0, 99]))).toBe(3);
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
