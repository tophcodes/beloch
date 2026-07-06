import { test, expect } from "bun:test";
import { parseFold, SceneError } from "@beloch/scene";
import { renderFolded } from "@beloch/render-svg";

const golden = (p: string) =>
  Bun.file(new URL(`../../../tests/golden/${p}`, import.meta.url)).text();
const occlude = () =>
  Bun.file(new URL("../../../tools/test/fixtures/fold-occlude.fold", import.meta.url)).text();

test("fold-quarter top view paints all faces bottom→top", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  const s = renderFolded(scene).toString();
  const faces = scene.steps[0]!.frame.facesVertices.length;
  expect((s.match(/data-kind="face"/g) ?? []).length).toBe(faces);
  // both paper sides appear in a quarter fold
  expect(s).toContain("#fafaf7");
  expect(s).toContain("#dbe4ee");
});

test("hidden=dashed draws occluded sub-segments, hide does not", async () => {
  const scene = parseFold(await occlude());
  const dashed = renderFolded(scene, { hidden: "dashed" }).toString();
  const hidden = renderFolded(scene, { hidden: "hide" }).toString();
  expect((dashed.match(/data-occluded="true"/g) ?? []).length).toBeGreaterThan(0);
  expect((hidden.match(/data-occluded="true"/g) ?? []).length).toBe(0);
});

test("bottom view mirrors x", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  const top = renderFolded(scene, { view: "top" }).toString();
  const bottom = renderFolded(scene, { view: "bottom" }).toString();
  expect(bottom).not.toBe(top);
});

test("fold-quarter folded golden snapshot", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  expect(renderFolded(scene, { hidden: "dashed" }).toString()).toMatchSnapshot();
});

test("fold-occlude dashed golden snapshot", async () => {
  const scene = parseFold(await occlude());
  expect(renderFolded(scene, { hidden: "dashed" }).toString()).toMatchSnapshot();
});

test("step option selects an intermediate folded state", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  const mid = renderFolded(scene, { step: "vertical_middle" }).toString();
  const fin = renderFolded(scene).toString();
  expect(mid).not.toBe(fin);
});

test("folded view renders named-point constructions", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  expect(renderFolded(scene).toString()).toContain('data-construction="s"');
});

test("scene without folded steps throws SceneError", async () => {
  const scene = parseFold(await golden("syntax/square.fold"));
  if (scene.steps.length === 0) {
    expect(() => renderFolded(scene)).toThrow(SceneError);
  } else {
    const empty = parseFold(JSON.stringify({ vertices_coords: [[0, 0]] }));
    expect(() => renderFolded(empty)).toThrow(SceneError);
  }
});
