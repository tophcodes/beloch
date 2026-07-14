import {
  Assignment, Crease, EdgeProvenance, FoldScene, Frame, LineCoeffs,
  Mark, NamedLine, NamedPoint, SceneError, Step, StepNotFoundError, Vec2,
} from "./types";
import { computeFaceDepth } from "./topology";

function frameFrom(raw: Record<string, unknown>): Frame {
  const vertices = raw["vertices_coords"] as Vec2[] | undefined;
  if (!Array.isArray(vertices)) throw new SceneError("missing vertices_coords");
  const edgesVertices = (raw["edges_vertices"] ?? []) as [number, number][];
  const n = edgesVertices.length;
  const edgesAssignment = (raw["edges_assignment"] ??
    Array(n).fill("U")) as Assignment[];
  const prov = (raw["beloch:edges"] ?? []) as (EdgeProvenance | null)[];
  const vnames = (raw["beloch:vertices_names"] ?? []) as (string | null)[];
  const facesVertices = (raw["faces_vertices"] ?? []) as number[][];
  const faceOrders = (raw["faceOrders"] ?? []) as Frame["faceOrders"];
  return {
    vertices,
    edgesVertices,
    edgesAssignment,
    edgesProvenance: Array.from({ length: n }, (_, i) => prov[i] ?? null),
    verticesNames: Array.from(
      { length: vertices.length },
      (_, i) => vnames[i] ?? null,
    ),
    facesVertices,
    faceOrders,
    faceDepth: computeFaceDepth(facesVertices, vertices, faceOrders),
    facesMatrix: (raw["beloch:faces_matrix"] ?? null) as Frame["facesMatrix"],
  };
}

function groupCreases(cp: Frame): Crease[] {
  const byName = new Map<string, Crease>();
  cp.edgesVertices.forEach(([a, b], edgeIndex) => {
    const name = cp.edgesProvenance[edgeIndex]?.name;
    if (!name) return;
    const crease = byName.get(name) ?? { name, segments: [] };
    crease.segments.push({ edgeIndex, a: cp.vertices[a]!, b: cp.vertices[b]! });
    byName.set(name, crease);
  });
  return [...byName.values()];
}

function marksFrom(fold: Record<string, unknown>): Mark[] {
  const raw = (fold["beloch:marks"] ?? []) as Record<string, unknown>[];
  return raw.map((m): Mark => {
    const line = m["line"] as LineCoeffs;
    const intent = m["intent"] as Assignment;
    const creaseId = m["crease_id"] as number;
    return m["kind"] === "seg"
      ? { kind: "seg", a: m["a"] as Vec2, b: m["b"] as Vec2, line, intent, creaseId }
      : { kind: "point", p: m["p"] as Vec2, line, intent, creaseId };
  });
}

export function parseFold(input: string | object): FoldScene {
  const fold = (typeof input === "string" ? JSON.parse(input) : input) as
    Record<string, unknown>;
  const cp = frameFrom(fold);
  const frames = (fold["file_frames"] ?? []) as Record<string, unknown>[];
  const steps: Step[] = frames
    .map((f, index) => ({ f, index }))
    .filter(({ f }) => ((f["frame_classes"] ?? []) as string[]).includes("foldedForm"))
    .map(({ f, index }) => {
      const merged = { ...fold, ...f }; // foldedForm overrides root (fold2svg semantics)
      return {
        index,
        label: (f["beloch:step"] ?? null) as string | null,
        sourceLine: (f["beloch:source_line"] ?? null) as number | null,
        frame: frameFrom(merged),
      };
    });
  const namedPoints: NamedPoint[] = Object.entries(
    (fold["beloch:named_points"] ?? {}) as
      Record<string, { paper: Vec2; table: Vec2; step?: number }>,
  ).map(([name, v]) => ({ name, paper: v.paper, table: v.table, step: v.step ?? 0 }));
  const namedLines: NamedLine[] = Object.entries(
    (fold["beloch:named_lines"] ?? {}) as
      Record<string, { coeffs: LineCoeffs; step?: number }>,
  ).map(([name, v]) => ({ name, coeffs: v.coeffs, step: v.step ?? 0 }));
  return { cp, steps, namedPoints, namedLines, creases: groupCreases(cp), marks: marksFrom(fold) };
}

export function pickStep(scene: FoldScene, label?: string): Step | undefined {
  if (label === undefined) return scene.steps[scene.steps.length - 1];
  const byName = scene.steps.find((s) => s.label === label);
  if (byName) return byName;
  if (/^\d+$/.test(label)) {
    // 0-based: step 0 is the flat starting sheet, step k the k-th fold.
    const idx = Number(label);
    if (idx >= 0 && idx < scene.steps.length) return scene.steps[idx];
  }
  throw new StepNotFoundError(
    label,
    scene.steps.map((s, i) => ({ index: i, label: s.label })),
  );
}
