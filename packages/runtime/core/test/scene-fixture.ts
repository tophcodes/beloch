// A FoldScene carrying only what the core reads: the statement list. The core
// never looks inside a frame, so the frames stay empty and a test that starts
// caring about geometry is a test that belongs to the renderer.
import type { FoldScene, Frame, Mark, NamedLine, Statement } from "@beloch/scene";

const emptyFrame = (): Frame => ({
  vertices: [],
  edgesVertices: [],
  edgesAssignment: [],
  edgesProvenance: [],
  verticesNames: [],
  facesVertices: [],
  faceOrders: [],
  facesMatrix: null,
});

export interface StatementSpec {
  kind?: Statement["kind"];
  sourceLine?: number;
  frameIndex?: number;
  keptMarks?: Mark[];
}

export function statement(index: number, spec: StatementSpec = {}): Statement {
  return {
    index,
    kind: spec.kind ?? "fold",
    sourceLine: spec.sourceLine ?? index + 1,
    span: null,
    frameIndex: spec.frameIndex ?? index + 1,
    mark: null,
    keptMarks: spec.keptMarks ?? [],
    parent: null,
    def: null,
  };
}

// A named line bound against `step`, which counts frames rather than
// statements.
export const namedLine = (name: string, step: number): NamedLine => ({
  name,
  coeffs: [1, 0, 0],
  step,
  statement: null,
});

export function sceneOf(statements: Statement[], namedLines: NamedLine[] = []): FoldScene {
  return {
    cp: emptyFrame(),
    steps: statements.map((s) => ({ index: s.frameIndex, sourceLine: s.sourceLine, frame: emptyFrame() })),
    statements,
    writes: statements.filter((s) => s.kind !== "bind"),
    references: [],
    namedPoints: [],
    namedLines,
    creases: [],
    marks: [],
    inspect: null,
    trace: [],
    error: null,
  };
}
