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
  creaseId: number | null;                                   // beloch:edges[i].crease_id
  statement: number | null;                                  // beloch:edges[i].statement — index into scene.statements; null on a FOLD written before the field existed
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

// Which axis a statement moves (ADR 0030). "fold" and "mark" are the writes:
// the paper moved, or it was scored and stands where it was. "bind" moves the
// program alone — a point, a construction line, a bundle, a definition, an
// export. "apply" runs a def; its body's entries follow it.
export type StatementKind = "fold" | "mark" | "bind" | "apply";

// beloch:statements — one entry per executed statement, execution order,
// the statements of an apply's body flat after the apply (ADR 0030). A mark
// entry embeds its OWN mark geometry as recorded at that statement (not a
// beloch:marks lookup — a mark that later graduates into a real crease is
// dropped from beloch:marks, but its Statement.mark here is unaffected).
// Contract: spec/FOLD.md.
export interface Statement {
  index: number;
  kind: StatementKind;
  sourceLine: number;                                        // beloch:statements[i].source_line — always present (every stmt has a span)
  span: string | null;                                       // beloch:statements[i].span; null on a FOLD written before the field existed
  frameIndex: number;                                        // beloch:statements[i].frame_index — index into scene.steps
  mark: Mark | null;                                          // present only for kind: "mark"
  keptMarks: Mark[];                                          // beloch:statements[i].kept_marks — marks still dangling as of this statement (not yet graduated into a real crease)
  parent: number | null;                                     // index of the apply entry this statement runs under; null at the top level
  def: string | null;                                        // the def an apply entry runs; null for every other kind
}

// beloch:references — where the program names a crease. `span` is the
// emitter's "file:line:startCol-endCol" (1-based columns, end exclusive);
// a span crossing lines reads "file:line:col-line:col".
export interface SourceRef {
  span: string;
  creaseId: number | null;
  edge: string | null;                                       // paper boundary edge ("ab"), when it is one
}

export interface NamedPoint {
  name: string; paper: Vec2; table: Vec2;
  step: number;                                              // frame counter
  statement: number | null;                                  // index into scene.statements; null on a FOLD written before the field existed
}
export interface NamedLine {
  name: string; coeffs: LineCoeffs;
  step: number;                                              // frame counter
  statement: number | null;                                  // index into scene.statements; null on a FOLD written before the field existed
}
export interface CreaseSegment { edgeIndex: number; a: Vec2; b: Vec2; }
export interface Crease { name: string; segments: CreaseSegment[]; }

// beloch:marks — non-subdividing record marks (dangling segments + points);
// see spec/FOLD.md.
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

// beloch:inspect — entity inspector data (playground slice B); keyed by
// crease_id / face index / point name as emitted by the core.
//
// `faces` is `number[]` rather than a strict 2-tuple: a crease segment
// borders two faces, but a paper-boundary edge segment (see InspectEdge
// below) borders only one (fold_emit.ml emits `"faces": [fi]` for those —
// there's no far side, it's the sheet's edge).
export interface InspectSegment {
  faces: number[];
  paper: [Vec2, Vec2];
  table: [Vec2, Vec2];
  assignment: string;
}
export interface InspectCrease {
  name: string | null;
  axiom: string | null;
  sources: string[];
  span: string | null;
  segments: InspectSegment[];
}
export interface InspectFace {
  vertices: Vec2[];
  flap: number;
  rank: number;
}
// beloch:inspect.edges — the four paper-boundary bundles (--ab/--bc/--cd/
// --da), one entry per edge that exists; a crossing crease splits an edge
// into several segments (task 9, playground slice B).
export interface InspectEdge {
  name: string;
  assignment: string;
  segments: InspectSegment[];
}
export interface Inspect {
  creases: Record<string, InspectCrease>;
  faces: Record<string, InspectFace>;
  points: Record<string, { face: number | null; flap: number | null }>;
  edges: Record<string, InspectEdge>;
}

// beloch:trace, written by `beloch fold --trace` (spec/FOLD.md, "The trace"):
// every candidate line of a construction, in the table coordinates of the
// frame the construction read (`frameIndex`; for a fold the state before it),
// with the rule that removed it.
export type Removal = "paper" | "toward" | "moving";
export interface TraceCandidate {
  line: LineCoeffs;
  removedBy: Removal | null;
  selected: boolean;
}
export interface Conic { focus: Vec2; directrix: LineCoeffs; }            // a parabola
export interface TraceEntry {
  statement: number;                                         // index into scene.statements
  frameIndex: number;                                        // index into scene.steps: the state the construction read
  axiom: string;
  toward: Vec2 | null;
  candidates: TraceCandidate[];
  conics: Conic[];
}
// beloch:error: why a traced program stopped.
export interface TraceError {
  message: string;
  hint: string | null;
  span: string;
  statement: number;
}

export interface FoldScene {
  cp: Frame;
  steps: Step[];                                             // one per foldedForm frame, file order
  statements: Statement[];                                   // every statement, source order — the axis a reader of the program walks
  writes: Statement[];                                       // the statements that changed the paper, source order — the axis the stepper walks
  references: SourceRef[];                                   // every mention of a crease name in the source
  namedPoints: NamedPoint[];
  namedLines: NamedLine[];
  creases: Crease[];                                         // grouped by provenance name on the CP frame
  marks: Mark[];                                              // beloch:marks, paper-space, CP frame only
  inspect: Inspect | null;                                   // beloch:inspect, entity inspector data
  trace: TraceEntry[];                                       // beloch:trace; [] when the file was written without --trace
  error: TraceError | null;                                  // beloch:error; null unless a traced program failed
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
