import { test, expect } from "bun:test";
import { outlineCentroid, type Frame } from "../src";

const frame = (faces: [number, number][][]): Frame => {
  const vertices = faces.flat();
  let k = 0;
  return {
    vertices, edgesVertices: [], edgesAssignment: [], edgesProvenance: [], edgesFaces: null,
    verticesNames: vertices.map(() => null),
    facesVertices: faces.map((f) => f.map(() => k++)),
    faceOrders: [], facesMatrix: null,
  };
};

// Two layers of [0,2]×[0,1] and one of [1,3]×[0,1] cover [0,3]×[0,1], whose
// centroid is (1.5, 0.5). Weighting each face by its area would give x = 4/3.
test("outlineCentroid counts a point under several layers once", () => {
  const left: [number, number][] = [[0, 0], [2, 0], [2, 1], [0, 1]];
  const right: [number, number][] = [[1, 0], [3, 0], [3, 1], [1, 1]];
  const [x, y] = outlineCentroid(frame([left, right, left]));
  expect(x).toBeCloseTo(1.5, 9);
  expect(y).toBeCloseTo(0.5, 9);
});

test("outlineCentroid of a triangle is the mean of its corners", () => {
  const [x, y] = outlineCentroid(frame([[[1, 0], [1, 1], [0, 1]]]));
  expect(x).toBeCloseTo(2 / 3, 9);
  expect(y).toBeCloseTo(2 / 3, 9);
});
