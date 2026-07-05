import { test, expect } from "bun:test";
import { parseFold, pickStep, SceneError } from "@beloch/scene";

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

test("pickStep: undefined or unmatched label falls back to last step", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  expect(pickStep(scene)).toBe(scene.steps[scene.steps.length - 1]);
  expect(pickStep(scene, "no-such-step")).toBe(scene.steps[scene.steps.length - 1]);
});

test("multi-step file keeps file order and labels", async () => {
  const scene = parseFold(await golden("syntax/precrease-fold.fold"));
  expect(scene.steps.length).toBeGreaterThanOrEqual(1);
  // labels are string|null, indices strictly increasing
  const idx = scene.steps.map((s) => s.index);
  expect([...idx].sort((a, b) => a - b)).toEqual(idx);
});

test("malformed input throws SceneError naming the field", () => {
  expect(() => parseFold("{}")).toThrow(SceneError);
  expect(() => parseFold("{}")).toThrow(/vertices_coords/);
});
