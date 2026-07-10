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
  step: string | null;                                       // step-macro label
}

export interface Frame {
  vertices: Vec2[];
  edgesVertices: [number, number][];
  edgesAssignment: Assignment[];
  edgesProvenance: (EdgeProvenance | null)[];                // same length as edgesVertices
  facesVertices: number[][];
  faceOrders: FaceOrder[];                                   // [] on the CP frame
  facesMatrix: Isometry[] | null;                            // beloch:faces_matrix; null on the CP frame
}

export interface Step {
  index: number;                                             // position in file_frames
  label: string | null;                                      // beloch:step
  frame: Frame;                                              // self-contained (merged over root)
}

export interface NamedPoint { name: string; paper: Vec2; table: Vec2; }
export interface NamedLine  { name: string; coeffs: LineCoeffs; }
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
  namedPoints: NamedPoint[];
  namedLines: NamedLine[];
  creases: Crease[];                                         // grouped by provenance name on the CP frame
  marks: Mark[];                                              // beloch:marks, paper-space, CP frame only
}

export class SceneError extends Error {}

export class StepNotFoundError extends SceneError {
  constructor(
    readonly label: string,
    readonly available: { index: number; label: string | null }[],
  ) {
    super(StepNotFoundError.render(label, available, (s) => s));
  }

  static render(
    label: string,
    available: { index: number; label: string | null }[],
    style: (s: string) => string,
  ): string {
    const named = available
      .filter((s) => s.label !== null)
      .map((s) => `${style(s.label!)} (${s.index + 1})`)
      .join(", ");
    return (
      `step '${label}' not found — ${available.length} step(s) available` +
      (named ? `. named steps are ${named}` : "")
    );
  }
}
