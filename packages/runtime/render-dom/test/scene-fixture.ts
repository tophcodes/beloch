// A scene whose paper is the unit square, carrying the inspect data the
// highlight reads: a crease bundle of two segments and one paper edge. The
// frames are the flat sheet in both cases, so the pixel coordinates a test
// asserts against come out of the renderer's own layout rather than a table of
// numbers.
import type { FoldScene, Frame, InspectSegment, Statement, Vec2 } from "@beloch/scene";

const UNIT: Vec2[] = [
  [0, 0],
  [1, 0],
  [1, 1],
  [0, 1],
];

const frame = (): Frame => ({
  vertices: UNIT,
  edgesVertices: [],
  edgesAssignment: [],
  edgesProvenance: [],
  verticesNames: [],
  facesVertices: [],
  faceOrders: [],
  facesMatrix: null,
});

export const segment = (a: Vec2, b: Vec2): InspectSegment => ({
  faces: [0, 1],
  paper: [a, b],
  table: [a, b],
  assignment: "M",
});

// The bundle's two segments: one the drawing shows, one buried under a flap.
export const DRAWN = segment([0, 0], [1, 0]);
export const BURIED = segment([0, 1], [1, 1]);
export const EDGE_AB = segment([0, 0], [0, 1]);

const statement = (index: number): Statement => ({
  index,
  kind: "fold",
  sourceLine: index + 1,
  span: null,
  frameIndex: index + 1,
  mark: null,
  keptMarks: [],
});

// One statement, so frame 1 is the final fold and frame 0 the sheet before it.
export function inspectScene(): FoldScene {
  return {
    cp: frame(),
    steps: [
      { index: 0, sourceLine: null, frame: frame() },
      { index: 1, sourceLine: 1, frame: frame() },
    ],
    statements: [statement(0)],
    writes: [statement(0)],
    references: [],
    namedPoints: [],
    namedLines: [],
    creases: [],
    marks: [],
    inspect: {
      creases: {
        "3": { name: "v", axiom: null, sources: [], span: null, segments: [DRAWN, BURIED] },
      },
      faces: {},
      points: {},
      edges: { ab: { name: "ab", assignment: "B", segments: [EDGE_AB] } },
    },
  };
}
