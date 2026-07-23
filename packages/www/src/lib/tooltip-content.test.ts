import { test, expect } from "bun:test";
import type { Inspect, InspectSegment } from "@beloch/scene";
import { hoverSummary, segmentRows } from "./tooltip-content";

function seg(faces: [number, number], assignment = "M"): InspectSegment {
  return { faces, paper: [[0, 0], [1, 1]], table: [[0, 0], [1, 1]], assignment };
}

function fakeInsp(overrides: Partial<Inspect> = {}): Inspect {
  return { creases: {}, faces: {}, points: {}, ...overrides };
}

test("hoverSummary for a named crease shows --name and the true segment count", () => {
  const insp = fakeInsp({
    creases: { "3": { name: "a", axiom: "O1", sources: [], span: null, segments: [seg([0, 1]), seg([1, 2])] } },
  });
  expect(hoverSummary({ kind: "crease", creaseId: "3" }, insp)).toEqual({
    title: "--a",
    detail: "2 segments",
  });
});

test("hoverSummary for an unnamed crease falls back to crease #id", () => {
  const insp = fakeInsp({
    creases: { "3": { name: null, axiom: null, sources: [], span: null, segments: [seg([0, 1])] } },
  });
  expect(hoverSummary({ kind: "crease", creaseId: "3" }, insp)).toEqual({
    title: "crease #3",
    detail: "1 segment",
  });
});

test("hoverSummary returns null for a crease id absent from insp.creases", () => {
  const insp = fakeInsp();
  expect(hoverSummary({ kind: "crease", creaseId: "9" }, insp)).toBeNull();
});

test("hoverSummary for a face shows flap and rank", () => {
  const insp = fakeInsp({ faces: { "2": { vertices: [], flap: 1, rank: 3 } } });
  expect(hoverSummary({ kind: "face", index: "2" }, insp)).toEqual({
    title: "face 2",
    detail: "flap 1 · rank 3",
  });
});

test("hoverSummary returns null for a face index absent from insp.faces", () => {
  expect(hoverSummary({ kind: "face", index: "9" }, fakeInsp())).toBeNull();
});

test("hoverSummary for a named vertex shows the point name and face/flap", () => {
  const insp = fakeInsp({ points: { r: { face: 1, flap: 0 } } });
  expect(hoverSummary({ kind: "vertex", index: 4, name: "r" }, insp)).toEqual({
    title: ".r",
    detail: "face 1 · flap 0",
  });
});

test("hoverSummary for an unnamed vertex shows a bare index and no detail", () => {
  expect(hoverSummary({ kind: "vertex", index: 4, name: null }, fakeInsp())).toEqual({
    title: "vertex 4",
    detail: "",
  });
});

test("segmentRows lists every segment of the bundle in array order when sortByRank is false", () => {
  const insp = fakeInsp({
    faces: { "0": { vertices: [], flap: 0, rank: 1 }, "1": { vertices: [], flap: 0, rank: 5 } },
    creases: {
      "3": { name: "a", axiom: null, sources: [], span: null, segments: [seg([0, 1], "M"), seg([0, 0], "V")] },
    },
  });
  const rows = segmentRows(insp, "3", false);
  expect(rows.map((r) => r.index)).toEqual([0, 1]);
  expect(rows[0]).toEqual({ index: 0, faceL: 0, faceR: 1, assignment: "M", rank: 5 });
});

test("segmentRows sorts by segRank descending when sortByRank is true", () => {
  const insp = fakeInsp({
    faces: { "0": { vertices: [], flap: 0, rank: 1 }, "1": { vertices: [], flap: 0, rank: 5 } },
    creases: {
      "3": {
        name: "a",
        axiom: null,
        sources: [],
        span: null,
        segments: [seg([0, 0], "V"), seg([0, 1], "M")], // rank 1 then rank 5
      },
    },
  });
  const rows = segmentRows(insp, "3", true);
  expect(rows.map((r) => r.index)).toEqual([1, 0]); // rank 5 first
  expect(rows.map((r) => r.rank)).toEqual([5, 1]);
});

test("segmentRows returns an empty array for a crease id absent from insp.creases", () => {
  expect(segmentRows(fakeInsp(), "9", true)).toEqual([]);
});
