import {
  Assignment, Crease, EdgeProvenance, FoldScene, Frame, LineCoeffs,
  NamedLine, NamedPoint, SceneError, Step, Vec2,
} from "./types";

function frameFrom(raw: Record<string, unknown>): Frame {
  const vertices = raw["vertices_coords"] as Vec2[] | undefined;
  if (!Array.isArray(vertices)) throw new SceneError("missing vertices_coords");
  const edgesVertices = (raw["edges_vertices"] ?? []) as [number, number][];
  const n = edgesVertices.length;
  const edgesAssignment = (raw["edges_assignment"] ??
    Array(n).fill("U")) as Assignment[];
  const prov = (raw["beloch:edges"] ?? []) as (EdgeProvenance | null)[];
  return {
    vertices,
    edgesVertices,
    edgesAssignment,
    edgesProvenance: Array.from({ length: n }, (_, i) => prov[i] ?? null),
    facesVertices: (raw["faces_vertices"] ?? []) as number[][],
    faceOrders: (raw["faceOrders"] ?? []) as Frame["faceOrders"],
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
        frame: frameFrom(merged),
      };
    });
  const namedPoints: NamedPoint[] = Object.entries(
    (fold["beloch:named_points"] ?? {}) as Record<string, { paper: Vec2; table: Vec2 }>,
  ).map(([name, v]) => ({ name, paper: v.paper, table: v.table }));
  const namedLines: NamedLine[] = Object.entries(
    (fold["beloch:named_lines"] ?? {}) as Record<string, LineCoeffs>,
  ).map(([name, coeffs]) => ({ name, coeffs }));
  return { cp, steps, namedPoints, namedLines, creases: groupCreases(cp) };
}

export function pickStep(scene: FoldScene, label?: string): Step | undefined {
  if (label !== undefined) {
    const hit = scene.steps.find((s) => s.label === label);
    if (hit) return hit;
  }
  return scene.steps[scene.steps.length - 1];
}
