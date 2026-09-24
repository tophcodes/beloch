import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderScene, renderCP, renderFolded, PAD } from "@beloch/render-svg";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

const count = (s: string, re: RegExp) => (s.match(re) ?? []).length;

// The four compositions from the spec: isometry × texture.upToStatement are
// independently controllable.

test("CP composition == renderCP preset (byte-identical wrapper)", async () => {
  const scene = parseFold(await golden("cube-root.fold"));
  const viaScene = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStatement: "all", creases: true, marks: true, points: true, lines: true, faces: "outline" },
  }).toString();
  expect(viaScene).toBe(renderCP(scene).toString());
});

test("folded composition == renderFolded preset (byte-identical wrapper)", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const viaScene = renderScene(scene, {
    isometry: { kind: "step", index: scene.steps.length - 1 },
    texture: { upToStatement: "all", creases: true, marks: false, points: true, lines: true, faces: "filled" },
  }).toString();
  expect(viaScene).toBe(renderFolded(scene).toString());
});

// Two creases on ONE source line, scored by two different statements: the
// case a line-number join cannot tell apart, and the reason beloch:edges
// carries a statement index of its own.
const twoOnOneLine = () =>
  parseFold({
    vertices_coords: [[0, 0], [1, 0], [1, 1], [0, 1], [0.5, 0], [0.5, 1], [0, 0.5], [1, 0.5]],
    edges_vertices: [
      [4, 5], [6, 7],
      [0, 4], [4, 1], [1, 7], [7, 2], [2, 5], [5, 3], [3, 6], [6, 0],
    ],
    edges_assignment: ["V", "V", "B", "B", "B", "B", "B", "B", "B", "B"],
    faces_vertices: [[0, 4, 5, 3], [4, 1, 2, 5]],
    "beloch:edges": [
      { name: "v", span: "2:1-2:20", statement: 0 },
      { name: "h", span: "2:1-2:20", statement: 1 },
      null, null, null, null, null, null, null, null,
    ],
    "beloch:statements": [
      { kind: "mark", source_line: 2, frame_index: 0, mark: null, kept_marks: [] },
      { kind: "mark", source_line: 2, frame_index: 0, mark: null, kept_marks: [] },
    ],
  });

test("progressive-flat shows a crease from the statement that scored it", () => {
  const scene = twoOnOneLine();
  const draw = (upToStatement: number | "all") =>
    renderScene(scene, {
      isometry: { kind: "flat" },
      texture: { upToStatement, creases: true, marks: false, points: false, lines: false, faces: "outline" },
    }).toString();
  const creases = (s: string) => count(s, /data-kind="crease"/g);
  // Ten edges, eight of them the sheet's boundary: the two statements add one
  // crease each, and both report source line 2.
  expect(creases(draw(-1))).toBe(8);
  expect(creases(draw(0))).toBe(9);
  expect(creases(draw(1))).toBe(10);
  expect(creases(draw("all"))).toBe(10);
});

test("a FOLD without the statement field shows every crease at every step", () => {
  const scene = twoOnOneLine();
  for (const p of scene.cp.edgesProvenance) if (p) p.statement = null;
  const svg = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStatement: -1, creases: true, marks: false, points: false, lines: false, faces: "outline" },
  }).toString();
  expect(count(svg, /data-kind="crease"/g)).toBe(10);
});

// The flat sheet draws a dot per vertex of the FINAL topology, so without a
// filter every state shows every point that will ever exist. A drawing of an
// earlier statement marks the corners and the points named by then.
test("progressive-flat marks the corners and the points named so far", () => {
  const scene = parseFold({
    // unit square, split by a vertical crease (statement 0) and a horizontal
    // one (statement 1). Vertex 8 is their crossing; 4..7 are the four points
    // where a crease meets the paper edge; 9 is a named point on the top edge
    // bound by a construction that lands on statement 1.
    vertices_coords: [
      [0, 0], [1, 0], [1, 1], [0, 1],
      [0.5, 0], [0.5, 1], [0, 0.5], [1, 0.5],
      [0.5, 0.5], [0.75, 1],
    ],
    edges_vertices: [
      [4, 8], [8, 5], [6, 8], [8, 7],
      [0, 4], [4, 1], [1, 7], [7, 2], [2, 9], [9, 5], [5, 3], [3, 6], [6, 0],
    ],
    edges_assignment: ["V", "V", "V", "V", "B", "B", "B", "B", "B", "B", "B", "B", "B"],
    faces_vertices: [[0, 4, 8, 6], [4, 1, 7, 8], [8, 7, 2, 9], [6, 8, 9, 3]],
    "beloch:edges": [
      { name: "v", statement: 0 }, { name: "v", statement: 0 },
      { name: "h", statement: 1 }, { name: "h", statement: 1 },
      null, null, null, null, null, null, null, null, null,
    ],
    "beloch:vertices_names": ["a", "b", "c", "d", null, null, null, null, null, "s"],
    "beloch:named_points": {
      a: { paper: [0, 0], table: [0, 0], step: 0, statement: 0 },
      b: { paper: [1, 0], table: [1, 0], step: 0, statement: 0 },
      c: { paper: [1, 1], table: [1, 1], step: 0, statement: 0 },
      d: { paper: [0, 1], table: [0, 1], step: 0, statement: 0 },
      s: { paper: [0.75, 1], table: [0.75, 1], step: 0, statement: 1 },
    },
    "beloch:statements": [
      { kind: "mark", source_line: 2, frame_index: 0, mark: null, kept_marks: [] },
      { kind: "mark", source_line: 3, frame_index: 0, mark: null, kept_marks: [] },
    ],
  });
  const dots = (upToStatement: number | "all") =>
    (renderScene(scene, {
      isometry: { kind: "flat" },
      texture: { upToStatement, creases: true, marks: false, points: false, lines: false, faces: "outline" },
    }).toString().match(/data-vertex=/g) ?? []).length;

  expect(dots(-1)).toBe(4); // empty paper: its four corners and nothing else
  expect(dots(0)).toBe(4); // the vertical crease names no point
  expect(dots(1)).toBe(5); // the named point .s arrives with its statement
  expect(dots("all")).toBe(10);
});

test("ghost projects future creases onto the current folded step", async () => {
  // mark-overlay-regression binds --diag at frame 0 and --ray at frame 1, so a
  // reader standing on frame 0 has exactly one line still ahead of them.
  const scene = parseFold(await golden("mark-overlay-regression.fold"));
  const draw = (upToStatement: number) =>
    renderScene(scene, {
      isometry: { kind: "step", index: 0 },
      texture: { upToStatement, creases: true, marks: false, points: true, lines: true, faces: "filled" },
    }).toString();
  // Statement 1 reads against frame 1, which is where --ray arrives.
  expect(count(draw(1), /data-kind="ghost"/g)).toBeGreaterThan(0);
  // Statement 0 reads against frame 0: nothing is ahead yet.
  expect(count(draw(0), /data-kind="ghost"/g)).toBe(0);
});

test("faces:none draws no face polygons", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStatement: "all", creases: true, marks: false, points: false, lines: false, faces: "none" },
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

// A crease is drawn with the assignment it has at the step shown. In the bird
// base with its petals lifted, the preliminary base's reverse fold scores --h
// as a valley right to the paper's edge, and lifting the petals lays its outer
// pieces flat again: at the step that scores it, every crease drawn is folded.
test("progressive-flat draws a crease with its assignment at that step", async () => {
  const scene = parseFold(await golden("bird-base-petal.fold"));
  const draw = (upToStatement: number | "all") =>
    renderScene(scene, {
      isometry: { kind: "flat" },
      texture: { upToStatement, creases: true, marks: false, points: false, lines: false, faces: "outline" },
    }).toString();
  const flat = (s: string) => count(s, /class="crease-F"/g);
  const scoring = scene.statements.findIndex((s) => s.sourceLine === 12);
  expect(scoring).toBeGreaterThanOrEqual(0);
  expect(flat(draw(scoring))).toBe(0);
  expect(flat(draw("all"))).toBeGreaterThan(0);
});
