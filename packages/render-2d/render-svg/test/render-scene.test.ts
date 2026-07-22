import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderScene, renderCP, renderFolded } from "@beloch/render-svg";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

const count = (s: string, re: RegExp) => (s.match(re) ?? []).length;

// The four compositions from the spec: isometry × texture.upToStep are
// independently controllable.

test("CP composition == renderCP preset (byte-identical wrapper)", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  const viaScene = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStep: "all", creases: true, marks: true, points: true, lines: true, faces: "outline" },
  }).toString();
  expect(viaScene).toBe(renderCP(scene).toString());
});

test("folded composition == renderFolded preset (byte-identical wrapper)", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const last = scene.steps.length - 1;
  const viaScene = renderScene(scene, {
    isometry: { kind: "step", index: last },
    texture: { upToStep: last, creases: true, marks: false, points: true, lines: true, faces: "filled" },
  }).toString();
  expect(viaScene).toBe(renderFolded(scene).toString());
});

test("progressive-flat shows fewer creases at an earlier step", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  const all = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStep: "all", creases: true, marks: false, points: false, lines: false, faces: "outline" },
  }).toString();
  const upTo1 = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStep: 1, creases: true, marks: false, points: false, lines: false, faces: "outline" },
  }).toString();
  // cube-root: named creases live at steps 1 (vm) and 2 (the rest); upToStep 1
  // drops the step-2 creases, so fewer crease lines are drawn.
  expect(count(upTo1, /data-kind="crease"/g)).toBeLessThan(count(all, /data-kind="crease"/g));
  expect(count(upTo1, /data-kind="crease"/g)).toBeGreaterThan(0);
});

test("ghost projects future creases onto the current folded step", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  // stand on step 1, ghost everything up to the last step
  const ghosted = renderScene(scene, {
    isometry: { kind: "step", index: 1 },
    texture: { upToStep: scene.steps.length - 1, creases: true, marks: false, points: true, lines: true, faces: "filled" },
  }).toString();
  const plain = renderScene(scene, {
    isometry: { kind: "step", index: 1 },
    texture: { upToStep: 1, creases: true, marks: false, points: true, lines: true, faces: "filled" },
  }).toString();
  expect(count(ghosted, /data-kind="ghost"/g)).toBeGreaterThan(0);
  expect(count(plain, /data-kind="ghost"/g)).toBe(0);
});

test("faces:none draws no face polygons", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStep: "all", creases: true, marks: false, points: false, lines: false, faces: "none" },
  }).toString();
  expect(count(s, /data-kind="face"/g)).toBe(0);
});

test("crease lines carry data-crease-id and data-seg; points carry data-vertex", () => {
  // None of the checked-in fixtures predate Task 3's `crease_id` emission, so
  // none carry it — build a minimal scene (square + one named diagonal) with
  // it set directly, same style as scene/test/parse.test.ts's Task 3 tests.
  const scene = parseFold({
    vertices_coords: [[0, 0], [1, 0], [1, 1], [0, 1]],
    edges_vertices: [[0, 1], [1, 2], [2, 3], [3, 0], [0, 2]],
    edges_assignment: ["B", "B", "B", "B", "V"],
    faces_vertices: [[0, 1, 2], [0, 2, 3]],
    "beloch:edges": [null, null, null, null, { name: "diag", crease_id: 7 }],
    "beloch:vertices_names": ["a", "b", "c", "d"],
  });
  const svg = renderCP(scene).toString();
  expect(svg).toContain('data-crease-id="7"');
  expect(svg).toContain('data-seg="0"');
  expect(svg).toContain("data-vertex=");
});
