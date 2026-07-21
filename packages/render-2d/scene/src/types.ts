export type Vec2 = [number, number];
export type Assignment = "B" | "M" | "V" | "F" | "U";
export type LineCoeffs = [number, number, number];           // a·x + b·y = c
export type Isometry = [number, number, number, number, number, number]; // [m00,m01,m10,m11,tx,ty]
export type FaceOrder = [number, number, number];            // [f, g, s], FOLD faceOrders

export interface EdgeProvenance {                            // one beloch:edges entry
  axiom: string | null;
  sources: string[];
  span: string | null;
  name: string | null;                                       // crease name (bundle) this edge belongs to
}

export interface Frame {
  vertices: Vec2[];
  edgesVertices: [number, number][];
  edgesAssignment: Assignment[];
  edgesProvenance: (EdgeProvenance | null)[];                // same length as edgesVertices
  verticesNames: (string | null)[];                          // beloch:vertices_names, per vertex
  facesVertices: number[][];
  faceOrders: FaceOrder[];                                   // [] on the CP frame
  facesMatrix: Isometry[] | null;                            // beloch:faces_matrix; null on the CP frame
}

export interface Step {
  index: number;                                             // position in file_frames
  sourceLine: number | null;                                 // beloch:source_line
  frame: Frame;                                              // self-contained (merged over root)
}

// beloch:statements — one entry per fold- or mark-producing top-level
// statement, source order. A mark entry embeds its OWN mark geometry as
// recorded at that statement (not a beloch:marks lookup — a mark that
// later graduates into a real crease is dropped from beloch:marks, but its
// Statement.mark here is unaffected). See
// docs/superpowers/specs/2026-07-20-playground-statement-sourcemap-design.md.
export interface Statement {
  index: number;
  kind: "fold" | "mark";
  sourceLine: number;                                        // beloch:statements[i].source_line — always present (every stmt has a span)
  frameIndex: number;                                        // beloch:statements[i].frame_index — index into scene.steps
  mark: Mark | null;                                          // present only for kind: "mark"
  keptMarks: Mark[];                                          // beloch:statements[i].kept_marks — marks still dangling as of this statement (not yet graduated into a real crease)
}

export interface NamedPoint { name: string; paper: Vec2; table: Vec2; step: number; }
export interface NamedLine  { name: string; coeffs: LineCoeffs; step: number; }
export interface CreaseSegment { edgeIndex: number; a: Vec2; b: Vec2; }
export interface Crease { name: string; segments: CreaseSegment[]; }

// beloch:marks — non-subdividing record marks (dangling segments + points);
// see docs/superpowers/specs/2026-07-10-mark-fold-slice2-design.md §5.
export interface SegMark {
  kind: "seg";
  a: Vec2; b: Vec2;
  line: LineCoeffs;                                          // the mark's axis, for orientation/color context
  intent: Assignment;                                         // "M" | "V" in practice
  creaseId: number;
}
export interface PointMark {
  kind: "point";
  p: Vec2;
  line: LineCoeffs;                                          // orients the display tick: dir = (line[1], -line[0])
  intent: Assignment;
  creaseId: number;
}
export type Mark = SegMark | PointMark;

export interface FoldScene {
  cp: Frame;
  steps: Step[];                                             // one per foldedForm frame, file order
  statements: Statement[];                                   // one per fold/mark statement, source order
  namedPoints: NamedPoint[];
  namedLines: NamedLine[];
  creases: Crease[];                                         // grouped by provenance name on the CP frame
  marks: Mark[];                                              // beloch:marks, paper-space, CP frame only
}

export class SceneError extends Error {}

export class StepNotFoundError extends SceneError {
  constructor(
    readonly label: string,
    readonly available: number,
  ) {
    super(StepNotFoundError.render(label, available));
  }

  static render(label: string, available: number): string {
    return `step index '${label}' not found — ${available} frame(s) available`;
  }
}
