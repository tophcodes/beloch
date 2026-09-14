import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderScene, renderCP, renderFolded, PAD } from "@beloch/render-svg";

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

test("crease lines carry data-crease-id (bundle-grouped); boundary edges don't; points carry data-vertex", () => {
  // None of the checked-in fixtures predate Task 3's `crease_id` emission, so
  // none carry it — build a minimal scene directly, same style as
  // scene/test/parse.test.ts's Task 3 tests. A single crease bundle (id 4) is
  // split across TWO collinear edges (0-4 and 4-2, the diagonal through the
  // midpoint 4); the fourth edge is a null-provenance boundary.
  const scene = parseFold({
    vertices_coords: [[0, 0], [1, 0], [1, 1], [0, 1], [0.5, 0.5]],
    edges_vertices: [[0, 4], [4, 2], [0, 1], [1, 2], [2, 3], [3, 0]],
    edges_assignment: ["V", "V", "B", "B", "B", "B"],
    faces_vertices: [[0, 1, 2], [0, 2, 3]],
    "beloch:edges": [
      { name: "diag", crease_id: 4 },
      { name: "diag", crease_id: 4 },
      null, null, null, null,
    ],
    "beloch:vertices_names": ["a", "b", "c", "d"],
  });
  const svg = renderCP(scene).toString();
  // Both edges of the bundle carry the same crease id (grouping).
  expect(count(svg, /data-crease-id="4"/g)).toBe(2);
  // The boundary edge (assignment B, on the outer square) carries no crease id;
  // exactly the two bundle edges are stamped, no boundary line is.
  expect(count(svg, /data-crease-id=/g)).toBe(2);
  expect(svg).toContain("data-vertex=");
});

// One frame for both views of one program: the union of the paper's bounds and
// every folded frame's bounds, so the crease pattern and the folded form sit at
// one scale on one baseline. cube-root's last step reaches to x = -0.115, past
// the sheet, which is what makes the union differ from the paper alone.
test("cp and folded share one frame: one viewBox, one scale, one baseline", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  const cp = renderCP(scene, { labels: [".a", ".b"] }).toString();
  const folded = renderFolded(scene, { labels: [".a", ".b"] }).toString();

  const attr = (s: string, name: string) =>
    new RegExp(`\\b${name}="([^"]*)"`).exec(s)?.[1];
  expect(attr(folded, "viewBox")).toBe(attr(cp, "viewBox") as string);
  expect(attr(folded, "height")).toBe(attr(cp, "height") as string);

  // `.a` and `.b` do not move in cube-root: paper and table coordinates agree.
  // Same pixels in both drawings means one scale and one baseline.
  const dot = (s: string, name: string) => {
    const g = s.slice(s.indexOf(`data-construction="${name}"`));
    const m = /<circle cx="([^"]*)" cy="([^"]*)"/.exec(g);
    return `${m?.[1]},${m?.[2]}`;
  };
  expect(dot(folded, "a")).toBe(dot(cp, "a"));
  expect(dot(folded, "b")).toBe(dot(cp, "b"));
  // The folded form reaching past the sheet is inside the frame, not in the
  // padding: every drawn x is at least the left pad.
  const xs = [...folded.matchAll(/points="([^"]*)"/g)].flatMap((m) =>
    m[1]!.split(" ").map((p) => Number(p.split(",")[0])),
  );
  expect(Math.min(...xs)).toBeGreaterThanOrEqual(PAD - 1e-6);
});
