import { test, expect } from "bun:test";
import { parseFold, pickStep, SceneError, StepNotFoundError } from "@beloch/scene";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

test("parses bisect-a: CP frame, provenance, named points/lines, creases", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  expect(scene.cp.vertices.length).toBe(7);
  expect(scene.cp.edgesVertices.length).toBe(9);
  expect(scene.cp.edgesAssignment[0]).toBe("B");
  // beloch:edges nulls become null entries, same length as edges
  expect(scene.cp.edgesProvenance.length).toBe(9);
  expect(scene.cp.edgesProvenance[0]).toBeNull();
  expect(scene.cp.edgesProvenance[3]?.axiom).toBe("axiom2");
  expect(scene.cp.edgesProvenance[3]?.name).toBe("v");
  // named constructions
  // Beloch has no line sign convention (see lib/geom.ml): coeffs are whatever
  // construction order produces. This "v" line comes from record_full's
  // extreme_pair(a,b) over the face clip endpoints, which orders b=(0.5,1)
  // before a=(0.5,0) here, giving [-1,0,-0.5] (same line as [1,0,0.5], sign
  // flipped) — deterministic, matches the golden.
  expect(scene.namedLines).toEqual([{ name: "v", coeffs: [-1, 0, -0.5], step: 0 }]);
  expect(scene.namedPoints.map((p) => p.name).sort()).toEqual(["a", "b", "c", "d"]);
  expect(scene.namedPoints.find((p) => p.name === "a")).toEqual({
    name: "a", paper: [0, 0], table: [0, 0], step: 0,
  });
  // crease bundle: edge 3 = [1,3] = (0.5,0)→(0.5,1), named "v"
  expect(scene.creases).toEqual([
    { name: "v", segments: [{ edgeIndex: 3, a: [0.5, 0], b: [0.5, 1] }] },
  ]);
});

test("parses fold-quarter: foldedForm step inherits root fields", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  // fold-quarter.bel has two `fold` statements and no step markers: one
  // frame per fold, each carrying its statement's source line, preceded by
  // the synthetic flat step 0 (the unfolded sheet, no source span).
  expect(scene.steps.length).toBe(3);
  expect(scene.steps.map((s) => s.sourceLine)).toEqual([null, 3, 4]);
  // the fully-folded state (both folds applied) is the LAST frame; its edge
  // list matches the root creasePattern
  const step = scene.steps[scene.steps.length - 1]!;
  // frame has own vertices + faceOrders; edges_assignment merged from root
  expect(step.frame.faceOrders.length).toBeGreaterThan(0);
  expect(step.frame.edgesAssignment).toEqual(scene.cp.edgesAssignment);
  expect(step.frame.facesMatrix).not.toBeNull();
  expect(step.frame.facesMatrix!.length).toBe(step.frame.facesVertices.length);
});

test("parseFold: statements carries one entry per fold statement, source order", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  expect(scene.statements.length).toBe(2);
  expect(scene.statements.map((s) => s.kind)).toEqual(["fold", "fold"]);
  expect(scene.statements.map((s) => s.sourceLine)).toEqual([3, 4]);
  expect(scene.statements.every((s) => s.mark === null)).toBe(true);
});

test("parseFold: statements carries kept_marks per statement", async () => {
  const seg = (creaseId: number) => ({
    kind: "seg", a: [0, 0], b: [1, 1], line: [1, -1, 0], intent: "V", crease_id: creaseId,
  });
  const fold = {
    vertices_coords: [[0, 0], [1, 0], [1, 1], [0, 1]],
    "beloch:statements": [
      { kind: "mark", source_line: 2, frame_index: 0, mark: seg(0), kept_marks: [seg(0)] },
      { kind: "mark", source_line: 3, frame_index: 0, mark: seg(1), kept_marks: [seg(0), seg(1)] },
      { kind: "fold", source_line: 4, frame_index: 1, mark: null, kept_marks: [] },
    ],
  };
  const scene = parseFold(fold);
  expect(scene.statements.map((s) => s.keptMarks.length)).toEqual([1, 2, 0]);
  expect(scene.statements[1]!.keptMarks.map((m) => m.creaseId)).toEqual([0, 1]);
});

test("pickStep: no label falls back to last step", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  expect(pickStep(scene)).toBe(scene.steps[scene.steps.length - 1]);
});

test("pickStep: unmatched (non-numeric) label throws StepNotFoundError", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  expect(() => pickStep(scene, "no-such-step")).toThrow(StepNotFoundError);
  try {
    pickStep(scene, "no-such-step");
    throw new Error("expected pickStep to throw");
  } catch (err) {
    expect(err).toBeInstanceOf(StepNotFoundError);
    expect((err as Error).message).toBe(
      "step index 'no-such-step' not found — 5 frame(s) available",
    );
  }
});

test("pickStep: numeric label selects by 0-based ordinal", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  // step 0 is the flat sheet, step k the k-th fold
  expect(pickStep(scene, "0")!.index).toBe(0);
  expect(pickStep(scene, "1")!.index).toBe(1);
  expect(pickStep(scene, "2")!.index).toBe(2);
});

test("pickStep: out-of-range ordinal throws StepNotFoundError", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  expect(() => pickStep(scene, "10")).toThrow(StepNotFoundError);
});

test("StepNotFoundError.render: reports the requested label and available frame count", () => {
  expect(StepNotFoundError.render("x", 1)).toBe(
    "step index 'x' not found — 1 frame(s) available",
  );
  expect(StepNotFoundError.render("x", 5)).toBe(
    "step index 'x' not found — 5 frame(s) available",
  );
});

test("multi-step file keeps file order", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  expect(scene.steps.length).toBe(5);
  expect(pickStep(scene, "3")!.index).toBe(3);
  // indices strictly increasing (file order preserved)
  const idx = scene.steps.map((s) => s.index);
  expect([...idx].sort((a, b) => a - b)).toEqual(idx);
});

test("malformed input throws SceneError naming the field", () => {
  expect(() => parseFold("{}")).toThrow(SceneError);
  expect(() => parseFold("{}")).toThrow(/vertices_coords/);
});

// Task 8 (mark/fold slice 2): beloch:marks — non-subdividing record marks.
// Fixture generated via `dune exec bin/main.exe -- fold` on a program that
// records exactly one seg mark (a between-clip stub dangling mid-face) and
// one point mark (an `at .p` reference on --vm); see
// render-svg/test/marks.test.ts for the full .bel source.
const fixture = (p: string) =>
  Bun.file(new URL(`../../render-svg/test/fixtures/${p}`, import.meta.url)).text();

test("parses beloch:marks: seg + point records", async () => {
  const scene = parseFold(await fixture("marks-demo.fold"));
  expect(scene.marks.length).toBe(2);
  const seg = scene.marks.find((m) => m.kind === "seg");
  const point = scene.marks.find((m) => m.kind === "point");
  expect(seg).toEqual({
    kind: "seg", a: [0.5, 0.5], b: [0.75, 0.75],
    line: [0.75, -0.75, 0.0], intent: "V", creaseId: 4,
  });
  expect(point).toEqual({
    kind: "point", p: [0.5, 0.5],
    line: [0.25, 0.0, 0.125], intent: "V", creaseId: 5,
  });
});

test("no beloch:marks field parses to an empty marks array", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  expect(scene.marks).toEqual([]);
});

test("frame carries verticesNames from beloch:vertices_names", async () => {
  const scene = parseFold(await golden("x-midpoint.fold"));
  expect(scene.cp.verticesNames).toContain("center");
  expect(scene.cp.verticesNames.length).toBe(scene.cp.vertices.length);
});

test("folded step frames carry crease provenance names", async () => {
  const scene = parseFold(await golden("x-midpoint.fold"));
  const step = scene.steps[scene.steps.length - 1]!;
  const hasNamedCrease = step.frame.edgesProvenance.some((p) => p?.name);
  expect(hasNamedCrease).toBe(true);
});

// Task 3 (entity inspector, playground slice B): beloch:inspect + per-edge
// crease_id.
test("parse surfaces inspect and edge crease id", () => {
  const fold = {
    vertices_coords: [[0, 0], [1, 0]], edges_vertices: [[0, 1]],
    edges_assignment: ["V"], faces_vertices: [],
    "beloch:edges": [{ axiom: "axiom2", sources: [".a", ".d"], span: "x:2:1", name: "h", crease_id: 4 }],
    "beloch:inspect": {
      creases: { "4": { name: "h", axiom: "axiom2", sources: ["--h"], span: "x:2:1",
        segments: [{ faces: [0, 1], paper: [[0, 0.5], [1, 0.5]], table: [[0, 0.5], [1, 0.5]], assignment: "V" }] } },
      faces: { "0": { vertices: [[0, 0], [1, 0], [1, 1], [0, 1]], flap: 0, rank: 1 } },
      points: { a: { face: 0, flap: 0 } },
    },
  };

  const scene = parseFold(fold as any);
  expect(scene.inspect?.creases["4"]!.segments[0]!.assignment).toBe("V");
  expect(scene.inspect?.faces["0"]!.rank).toBe(1);
  expect(scene.cp.edgesProvenance[0]?.creaseId).toBe(4);
});

test("no beloch:inspect field parses to a null inspect", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  expect(scene.inspect).toBeNull();
});

// Task 9 (entity inspector, playground slice B): beloch:inspect.edges — the
// paper-boundary bundles (--ab/--bc/--cd/--da).
test("parse surfaces inspect.edges", () => {
  const fold = {
    vertices_coords: [[0, 0], [1, 0]], edges_vertices: [[0, 1]],
    edges_assignment: ["B"], faces_vertices: [],
    "beloch:inspect": {
      creases: {}, faces: { "0": { vertices: [[0, 0], [1, 0], [1, 1], [0, 1]], flap: 0, rank: 0 } },
      points: {},
      edges: {
        ab: { name: "ab", assignment: "B",
          segments: [{ faces: [0], paper: [[0, 0], [1, 0]], table: [[0, 0], [1, 0]], assignment: "B" }] },
      },
    },
  };

  const scene = parseFold(fold as any);
  expect(scene.inspect?.edges["ab"]!.name).toBe("ab");
  expect(scene.inspect?.edges["ab"]!.segments[0]!.faces).toEqual([0]);
});

test("inspect.edges defaults to {} when the core build predates it", () => {
  const fold = {
    vertices_coords: [[0, 0], [1, 0]], edges_vertices: [[0, 1]],
    edges_assignment: ["B"], faces_vertices: [],
    "beloch:inspect": { creases: {}, faces: {}, points: {} },
  };

  const scene = parseFold(fold as any);
  expect(scene.inspect?.edges).toEqual({});
});
