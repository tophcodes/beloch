import {
  Assignment, Crease, EdgeProvenance, FoldScene, Frame, Inspect, LineCoeffs,
  Mark, NamedLine, NamedPoint, SceneError, SourceRef, Statement, StatementKind, Step,
  StepNotFoundError, TraceEntry, TraceError, Vec2, WriteCandidate, WriteEntry, WriteTerms,
} from "./types";

function frameFrom(raw: Record<string, unknown>): Frame {
  const vertices = raw["vertices_coords"] as Vec2[] | undefined;
  if (!Array.isArray(vertices)) throw new SceneError("missing vertices_coords");
  const edgesVertices = (raw["edges_vertices"] ?? []) as [number, number][];
  const n = edgesVertices.length;
  const edgesAssignment = (raw["edges_assignment"] ??
    Array(n).fill("U")) as Assignment[];
  const prov = (raw["beloch:edges"] ?? []) as (Record<string, unknown> | null)[];
  const vnames = (raw["beloch:vertices_names"] ?? []) as (string | null)[];
  return {
    vertices,
    edgesVertices,
    edgesAssignment,
    edgesProvenance: Array.from({ length: n }, (_, i) => {
      const p = prov[i];
      return p
        ? ({
            ...p,
            creaseId: (p["crease_id"] ?? null) as number | null,
            statement: (p["statement"] ?? null) as number | null,
          } as EdgeProvenance)
        : null;
    }),
    verticesNames: Array.from(
      { length: vertices.length },
      (_, i) => vnames[i] ?? null,
    ),
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

function markFrom(m: Record<string, unknown>): Mark {
  const line = m["line"] as LineCoeffs;
  const intent = m["intent"] as Assignment;
  const creaseId = m["crease_id"] as number;
  return m["kind"] === "seg"
    ? { kind: "seg", a: m["a"] as Vec2, b: m["b"] as Vec2, line, intent, creaseId }
    : { kind: "point", p: m["p"] as Vec2, line, intent, creaseId };
}

function marksFrom(fold: Record<string, unknown>): Mark[] {
  const raw = (fold["beloch:marks"] ?? []) as Record<string, unknown>[];
  return raw.map(markFrom);
}

function statementsFrom(fold: Record<string, unknown>): Statement[] {
  const raw = (fold["beloch:statements"] ?? []) as Record<string, unknown>[];
  return raw.map((s, index) => ({
    index,
    // A FOLD written before the second axis existed logged writes alone, so an
    // entry without a kind is a write.
    kind: (s["kind"] ?? "fold") as StatementKind,
    sourceLine: s["source_line"] as number,
    span: (s["span"] ?? null) as string | null,
    frameIndex: s["frame_index"] as number,
    mark: s["mark"] ? markFrom(s["mark"] as Record<string, unknown>) : null,
    keptMarks: ((s["kept_marks"] ?? []) as Record<string, unknown>[]).map(markFrom),
    parent: (s["parent"] ?? null) as number | null,
    def: (s["def"] ?? null) as string | null,
  }));
}

function traceFrom(fold: Record<string, unknown>): TraceEntry[] {
  const raw = (fold["beloch:trace"] ?? []) as Record<string, unknown>[];
  return raw.filter((e) => e["write"] === undefined).map((e) => ({
    statement: e["statement"] as number,
    frameIndex: e["frame_index"] as number,
    axiom: e["axiom"] as string,
    toward: (e["toward"] ?? null) as Vec2 | null,
    candidates: ((e["candidates"] ?? []) as Record<string, unknown>[]).map((c) => ({
      line: c["line"] as LineCoeffs,
      removedBy: (c["removed_by"] ?? null) as TraceEntry["candidates"][number]["removedBy"],
      selected: c["selected"] === true,
      landing: (c["landing"] ?? null) as Vec2 | null,
    })),
    conics: ((e["conics"] ?? []) as { focus: Vec2; directrix: LineCoeffs }[]).map((c) => ({
      focus: c.focus, directrix: c.directrix,
    })),
  }));
}

function writeTraceFrom(fold: Record<string, unknown>): WriteEntry[] {
  const raw = (fold["beloch:trace"] ?? []) as Record<string, unknown>[];
  return raw.filter((e) => e["write"] !== undefined).map((e) => {
    const t = (e["terms"] ?? {}) as Record<string, unknown>;
    const terms = { ...t, write: e["write"], target: t["target"] ?? null } as WriteTerms;
    return {
      statement: e["statement"] as number,
      frameIndex: e["frame_index"] as number,
      terms,
      candidates: ((e["candidates"] ?? []) as Record<string, unknown>[]).map((c): WriteCandidate => ({
        // a candidate frame is a foldedForm frame like those in file_frames
        frame: c["frame"] ? frameFrom({ ...fold, ...(c["frame"] as Record<string, unknown>) }) : null,
        removedBy: (c["removed_by"] ?? null) as WriteCandidate["removedBy"],
        selected: c["selected"] === true,
        spine: (c["spine"] ?? null) as WriteCandidate["spine"],
        halves: (c["halves"] ?? null) as WriteCandidate["halves"],
        bodies: (c["bodies"] ?? null) as WriteCandidate["bodies"],
        rays: (c["rays"] ?? []) as WriteCandidate["rays"],
        emergent: (c["emergent"] ?? null) as WriteCandidate["emergent"],
        stayer: (c["stayer"] ?? null) as WriteCandidate["stayer"],
      })),
    };
  });
}

function errorFrom(fold: Record<string, unknown>): TraceError | null {
  const e = fold["beloch:error"] as Record<string, unknown> | undefined;
  if (!e) return null;
  return {
    message: String(e["message"] ?? ""),
    hint: (e["hint"] ?? null) as string | null,
    span: String(e["span"] ?? ""),
    statement: e["statement"] as number,
  };
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
        sourceLine: (f["beloch:source_line"] ?? null) as number | null,
        frame: frameFrom(merged),
      };
    });
  const namedPoints: NamedPoint[] = Object.entries(
    (fold["beloch:named_points"] ?? {}) as
      Record<string, { paper: Vec2; table: Vec2; step?: number; statement?: number }>,
  ).map(([name, v]) => ({
    name, paper: v.paper, table: v.table,
    step: v.step ?? 0,
    statement: v.statement ?? null,
  }));
  const references: SourceRef[] = (
    (fold["beloch:references"] ?? []) as Record<string, unknown>[]
  ).map((r) => ({
    span: String(r["span"] ?? ""),
    creaseId: (r["crease_id"] ?? null) as number | null,
    edge: (r["edge"] ?? null) as string | null,
  }));
  const namedLines: NamedLine[] = Object.entries(
    (fold["beloch:named_lines"] ?? {}) as
      Record<string, { coeffs: LineCoeffs; step?: number; statement?: number }>,
  ).map(([name, v]) => ({
    name, coeffs: v.coeffs,
    step: v.step ?? 0,
    statement: v.statement ?? null,
  }));
  // `edges` is a task-9 addition to beloch:inspect; default it to {} for a
  // fold produced by a core build predating it, same treatment the rest of
  // this parse gives every other optional beloch: field.
  const rawInspect = (fold["beloch:inspect"] ?? null) as
    (Omit<Inspect, "edges"> & { edges?: Inspect["edges"] }) | null;
  const inspect: Inspect | null = rawInspect
    ? { ...rawInspect, edges: rawInspect.edges ?? {} }
    : null;
  const statements = statementsFrom(fold);
  return {
    cp, steps, statements,
    // The stepper stops where the paper changed. The entries keep their index
    // in `statements`, so a join on a statement index reads either list.
    writes: statements.filter((s) => s.kind === "fold" || s.kind === "mark"),
    references, namedPoints, namedLines,
    creases: groupCreases(cp), marks: marksFrom(fold), inspect,
    trace: traceFrom(fold), writeTrace: writeTraceFrom(fold), error: errorFrom(fold),
  };
}

export function pickStep(scene: FoldScene, label?: string): Step | undefined {
  if (label === undefined) return scene.steps[scene.steps.length - 1];
  if (/^\d+$/.test(label)) {
    // 0-based: step 0 is the flat starting sheet, step k the k-th fold.
    const idx = Number(label);
    if (idx >= 0 && idx < scene.steps.length) return scene.steps[idx];
  }
  throw new StepNotFoundError(label, scene.steps.length);
}
