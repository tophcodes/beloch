import { test, expect } from "bun:test";
import { pointSegDist, segmentDrawnAt, type DrawnLine } from "./pick-visibility";

const EPS = 6;
// One horizontal segment, y = 0, x from 0 to 100, in SVG user units.
const P0: [number, number] = [0, 0];
const P1: [number, number] = [100, 0];

test("pointSegDist measures to the nearest point of the segment", () => {
  expect(pointSegDist(50, 3, 0, 0, 100, 0)).toBeCloseTo(3);
});

test("pointSegDist clamps beyond an endpoint", () => {
  expect(pointSegDist(-4, 3, 0, 0, 100, 0)).toBeCloseTo(5);
});

test("pointSegDist of a degenerate segment is the distance to its point", () => {
  expect(pointSegDist(3, 4, 0, 0, 0, 0)).toBeCloseTo(5);
});

test("a fully drawn segment is drawn anywhere along it", () => {
  const drawn: DrawnLine[] = [[0, 0, 100, 0]];
  expect(segmentDrawnAt(P0, P1, 50, 0, drawn, EPS)).toBe(true);
  expect(segmentDrawnAt(P0, P1, 2, 0, drawn, EPS)).toBe(true);
});

test("a segment with nothing drawn on it is not drawn", () => {
  expect(segmentDrawnAt(P0, P1, 50, 0, [], EPS)).toBe(false);
});

test("a partially drawn segment is drawn on its visible run only", () => {
  // The renderer clipped the buried half away: only x in [0,40] is drawn.
  const drawn: DrawnLine[] = [[0, 0, 40, 0]];
  expect(segmentDrawnAt(P0, P1, 20, 0, drawn, EPS)).toBe(true);
  expect(segmentDrawnAt(P0, P1, 80, 0, drawn, EPS)).toBe(false);
});

test("a crease crossing the segment does not make it drawn", () => {
  // Vertical line through x = 50; it passes the point but runs across the
  // segment rather than along it.
  const drawn: DrawnLine[] = [[50, -30, 50, 30]];
  expect(segmentDrawnAt(P0, P1, 50, 0, drawn, EPS)).toBe(false);
});

test("a coincident line drawn in the other endpoint order still counts", () => {
  const drawn: DrawnLine[] = [[100, 0, 0, 0]];
  expect(segmentDrawnAt(P0, P1, 50, 0, drawn, EPS)).toBe(true);
});

test("a line along the segment but away from the point does not count", () => {
  const drawn: DrawnLine[] = [[0, 0, 100, 0]];
  expect(segmentDrawnAt(P0, P1, 50, 20, drawn, EPS)).toBe(false);
});

test("a drawn line just inside the tolerance counts, just outside does not", () => {
  expect(segmentDrawnAt(P0, P1, 50, 0, [[0, 5, 100, 5]], EPS)).toBe(true);
  expect(segmentDrawnAt(P0, P1, 50, 0, [[0, 7, 100, 7]], EPS)).toBe(false);
});
