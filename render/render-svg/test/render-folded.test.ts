import { test, expect } from "bun:test";
import { parseFold, SceneError } from "@beloch/scene";
import { renderFolded } from "@beloch/render-svg";
import { makeLayout, PAD, SZ } from "../src/layout";
import { pointInPolygon } from "../src/geometry";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();
const occlude = () =>
  Bun.file(new URL("./fixtures/fold-occlude.fold", import.meta.url)).text();

test("fold-quarter top view paints all faces bottom→top", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const s = renderFolded(scene).toString();
  // renderFolded with no --step defaults to the LAST frame (fully folded,
  // both `fold` statements applied); fold-quarter.bel now has one frame per
  // fold (Slice B, per-fold frames)
  const faces = scene.steps[scene.steps.length - 1]!.frame.facesVertices.length;
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
  const scene = parseFold(await golden("fold-quarter.fold"));
  const top = renderFolded(scene, { view: "top" }).toString();
  const bottom = renderFolded(scene, { view: "bottom" }).toString();
  expect(bottom).not.toBe(top);
});

test("fold-quarter folded golden snapshot", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  expect(renderFolded(scene, { hidden: "dashed" }).toString()).toMatchSnapshot();
});

test("fold-occlude dashed golden snapshot", async () => {
  const scene = parseFold(await occlude());
  expect(renderFolded(scene, { hidden: "dashed" }).toString()).toMatchSnapshot();
});

test("step option selects an intermediate folded state", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  const mid = renderFolded(scene, { step: "vertical_middle" }).toString();
  const fin = renderFolded(scene).toString();
  expect(mid).not.toBe(fin);
});

test("no --labels: folded view renders no overlay", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  expect(renderFolded(scene).toString()).not.toContain('class="construction"');
});

test("explicit --labels renders the named point in folded view", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  const s = renderFolded(scene, { labels: [".s"] }).toString();
  expect(s).toContain('data-construction="s"');
});

// #9 — integration fixture for the folded auxiliary named-line overlay.
// cube-root.fold's `--pq` (examples/syntax/cube-root.bel:42, `--pq = through
// ._pq1 ._pq2`) is a pure VALUE binding, not `mark`-ed: it never subdivides
// the mesh, so it names no edge in any frame — a genuine auxiliary line, not
// a crease-duplicate (contrast the `.s` point test above, and every `mark`ed
// name in this same file, which ARE creases). This exercises `lineToFace` +
// `clipLineToPoly` end to end across three distinct --step frames, not just
// the `lineToFace` unit.
test("--pq (pure-value, non-crease named line) clips into folded faces across --step frames", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  for (const step of ["vertical_middle", "thirds", "beloch_fold"]) {
    const found = scene.steps.find((s) => s.label === step);
    expect(found).toBeDefined();
    const { frame } = found!;

    const s = renderFolded(scene, { step, labels: ["--pq"] }).toString();
    const group = s.match(
      /<g class="construction" data-construction="pq" data-kind="line" data-name="pq">[\s\S]*?<\/g>/,
    );
    expect(group).not.toBeNull();

    const lines = [
      ...group![0].matchAll(
        /<line x1="([-\d.]+)" y1="([-\d.]+)" x2="([-\d.]+)" y2="([-\d.]+)"/g,
      ),
    ];
    expect(lines.length).toBeGreaterThan(0); // at least one face was clipped against

    // Invert the same screen transform renderFolded used (layout.ts) to get
    // back to table coordinates, then confirm each drawn segment's midpoint
    // actually landed inside one of this frame's face polygons — proving the
    // clip ran geometrically, not just that a <line> tag was emitted.
    const layout = makeLayout(frame.vertices);
    const faces = frame.facesVertices.map((idxs) => idxs.map((i) => frame.vertices[i]!));
    for (const [, x1, y1, x2, y2] of lines) {
      const sx = (Number(x1) + Number(x2)) / 2;
      const sy = (Number(y1) + Number(y2)) / 2;
      const px = layout.minX + ((sx - PAD) / SZ) * layout.span;
      const py = layout.minY + (1 - (sy - PAD) / SZ) * layout.span;
      expect(faces.some((poly) => pointInPolygon([px, py], poly))).toBe(true);
    }
  }
});

test("scene without folded steps throws SceneError", async () => {
  const scene = parseFold(await golden("square.fold"));
  if (scene.steps.length === 0) {
    expect(() => renderFolded(scene)).toThrow(SceneError);
  } else {
    const empty = parseFold(JSON.stringify({ vertices_coords: [[0, 0]] }));
    expect(() => renderFolded(empty)).toThrow(SceneError);
  }
});

test("legend hidden by default", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const s = renderFolded(scene).toString();
  expect(s).not.toContain('class="legend-panel"');
});

test("legend: true shows the legend panel", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const s = renderFolded(scene, { legend: true }).toString();
  expect(s).toContain('class="legend-panel"');
});

test("folded stamps data-bel-name on named vertex dots and keeps occluded creases", async () => {
  const scene = parseFold(await golden("x-midpoint.fold"));
  const s = renderFolded(scene, { hidden: "dashed" }).toString();
  expect(s).toContain('data-bel-name="center"');
  expect(s).toContain('data-occluded="true"');               // occluded geometry retained
});

test("folded view stamps a text label (not just the dot) for a named vertex", async () => {
  const scene = parseFold(await golden("x-midpoint.fold"));
  const s = renderFolded(scene).toString();
  const label = s.match(/<text[^>]*data-bel-name="center"[^>]*>\.center<\/text>/);
  expect(label).not.toBeNull();
});
