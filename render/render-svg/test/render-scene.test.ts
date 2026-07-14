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
