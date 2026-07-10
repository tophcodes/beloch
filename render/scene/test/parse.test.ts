import { test, expect } from "bun:test";
import { parseFold, pickStep, SceneError, StepNotFoundError } from "@beloch/scene";

const golden = (p: string) =>
  Bun.file(new URL(`../../../tests/golden/${p}`, import.meta.url)).text();

test("parses bisect-a: CP frame, provenance, named points/lines, creases", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  expect(scene.cp.vertices.length).toBe(7);
  expect(scene.cp.edgesVertices.length).toBe(9);
  expect(scene.cp.edgesAssignment[0]).toBe("B");
  // beloch:edges nulls become null entries, same length as edges
  expect(scene.cp.edgesProvenance.length).toBe(9);
  expect(scene.cp.edgesProvenance[0]).toBeNull();
  expect(scene.cp.edgesProvenance[3]?.axiom).toBe("axiom2");
  expect(scene.cp.edgesProvenance[3]?.name).toBe("v");
  // named constructions
  expect(scene.namedLines).toEqual([{ name: "v", coeffs: [1, 0, 0.5] }]);
  expect(scene.namedPoints.map((p) => p.name).sort()).toEqual(["a", "b", "c", "d"]);
  expect(scene.namedPoints.find((p) => p.name === "a")).toEqual({
    name: "a", paper: [0, 0], table: [0, 0],
  });
  // crease bundle: edge 3 = [v3,v0] = (0.5,1)→(0.5,0), named "v"
  expect(scene.creases).toEqual([
    { name: "v", segments: [{ edgeIndex: 3, a: [0.5, 1], b: [0.5, 0] }] },
  ]);
});

test("parses fold-quarter: foldedForm step inherits root fields", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  expect(scene.steps.length).toBe(1);
  const step = scene.steps[0]!;
  expect(step.label).toBeNull();
  // frame has own vertices + faceOrders; edges_assignment merged from root
  expect(step.frame.faceOrders.length).toBeGreaterThan(0);
  expect(step.frame.edgesAssignment).toEqual(scene.cp.edgesAssignment);
  expect(step.frame.facesMatrix).not.toBeNull();
  expect(step.frame.facesMatrix!.length).toBe(step.frame.facesVertices.length);
});

test("pickStep: no label falls back to last step", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  expect(pickStep(scene)).toBe(scene.steps[scene.steps.length - 1]);
});

test("pickStep: unmatched label throws StepNotFoundError listing named steps", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  expect(() => pickStep(scene, "no-such-step")).toThrow(StepNotFoundError);
  try {
    pickStep(scene, "no-such-step");
    throw new Error("expected pickStep to throw");
  } catch (err) {
    expect(err).toBeInstanceOf(StepNotFoundError);
    expect((err as Error).message).toBe(
      "step 'no-such-step' not found — 4 step(s) available. " +
        "named steps are vertical_middle (2), thirds (3), beloch_fold (4)",
    );
  }
});

test("pickStep: numeric label selects by 1-based ordinal", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  expect(pickStep(scene, "2")!.label).toBe("vertical_middle");
  expect(pickStep(scene, "1")!.label).toBeNull();
});

test("pickStep: out-of-range ordinal throws StepNotFoundError", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  expect(() => pickStep(scene, "10")).toThrow(StepNotFoundError);
});

test("StepNotFoundError.render: no named steps omits the list", () => {
  expect(StepNotFoundError.render("x", [{ index: 0, label: null }], (s) => s)).toBe(
    "step 'x' not found — 1 step(s) available",
  );
});

test("StepNotFoundError.render: applies the given style to names only", () => {
  const available = [{ index: 0, label: null }, { index: 1, label: "a" }];
  const styled = StepNotFoundError.render("x", available, (s) => `[${s}]`);
  expect(styled).toBe("step 'x' not found — 2 step(s) available. named steps are [a] (2)");
});

test("multi-step file keeps file order and labels", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  expect(scene.steps.length).toBe(4);
  expect(scene.steps.map((s) => s.label)).toEqual([
    null, "vertical_middle", "thirds", "beloch_fold",
  ]);
  // "thirds" is the 3rd foldedForm frame => file_frames position 2
  expect(pickStep(scene, "thirds")!.index).toBe(2);
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
// render/render-svg/test/marks.test.ts for the full .bel source.
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
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  expect(scene.marks).toEqual([]);
});
