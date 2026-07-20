import { test, expect } from "bun:test";
import { parseFold, SceneError, type Mark } from "@beloch/scene";
import { renderFolded, WEB_THEME } from "@beloch/render-svg";
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

test("occluded named-vertex dots: dashed greys them, hide drops them", async () => {
  // fold-quarter folds paper corners a,b,c under the top flap; only d stays
  // exposed. Named-vertex dots must occlude like creases do.
  const scene = parseFold(await golden("fold-quarter.fold"));
  const dashed = renderFolded(scene, { hidden: "dashed" }).toString();
  const hidden = renderFolded(scene, { hidden: "hide" }).toString();
  const points = (s: string) => (s.match(/data-kind="point"/g) ?? []).length;
  const occludedPoints = (s: string) =>
    (s.match(/data-kind="point"[^>]*data-occluded="true"/g) ?? []).length;
  // dashed: every named dot still drawn, the covered ones flagged occluded
  expect(points(dashed)).toBe(4);
  expect(occludedPoints(dashed)).toBe(3);
  // hide: the 3 covered dots (and their labels) are gone, only `d` remains
  expect(points(hidden)).toBe(1);
  expect(occludedPoints(hidden)).toBe(0);
  expect((hidden.match(/data-kind="point-label"/g) ?? []).length).toBe(1);
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
    const layout = makeLayout(scene.cp.vertices);
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
  // In x-midpoint, corner `a` folds onto `center` (both at 0.5,0.5), so the
  // declutter primitive merges them into one label instead of stacking two on
  // the same pixel. Assert the merged label carries center's name.
  const labels = [...s.matchAll(/<text[^>]*data-kind="point-label"[^>]*>([^<]*)<\/text>/g)]
    .map((m) => m[1]!);
  expect(labels.some((t) => t.includes(".center"))).toBe(true);
  // 5 named vertices (d, center, c, b, a) but a≡center fold onto one point →
  // 4 labels, the overlap collapsed into a merged one.
  expect(labels.length).toBe(4);
});

test("renderFolded: markOverlay draws exactly the given mark, omitting it changes nothing", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));

  const withoutOverlay = renderFolded(scene, { theme: WEB_THEME }).toString();
  const withOverlayButNoMark = renderFolded(scene, { theme: WEB_THEME, markOverlay: undefined }).toString();
  expect(withOverlayButNoMark).toBe(withoutOverlay); // omitting is a true no-op

  // fold-quarter's last frame stacks all 4 faces into table-space [0,0.5]x[0,0.5];
  // face 0's facesMatrix is the identity, so this segment (inside face 0's
  // (0,0)-(0.5,0)-(0.5,0.5)-(0,0.5) polygon under that identity transform)
  // lands cleanly and the overlay actually draws.
  const seg: Mark = {
    kind: "seg", a: [0.1, 0.1], b: [0.3, 0.3], line: [1, -1, 0], intent: "V", creaseId: 999,
  };
  const withOverlay = renderFolded(scene, { theme: WEB_THEME, markOverlay: { marks: [seg] } }).toString();
  expect(withOverlay).toContain('data-crease-id="999"');
});

test("renderFolded: markOverlay draws multiple marks, highlighting the newest", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));

  const older: Mark = {
    kind: "seg", a: [0.1, 0.1], b: [0.2, 0.2], line: [1, -1, 0], intent: "V", creaseId: 111,
  };
  const newest: Mark = {
    kind: "seg", a: [0.05, 0.15], b: [0.25, 0.35], line: [1, -1, 0.1], intent: "M", creaseId: 222,
  };
  const svg = renderFolded(scene, {
    theme: WEB_THEME,
    markOverlay: { marks: [older, newest], newestCreaseId: 222 },
  }).toString();

  const olderLine = svg.match(/<line[^>]*data-crease-id="111"[^>]*\/>/);
  const newestLine = svg.match(/<line[^>]*data-crease-id="222"[^>]*\/>/);
  expect(olderLine).not.toBeNull();
  expect(newestLine).not.toBeNull();

  expect(olderLine![0]).toContain('opacity="0.7"');
  expect(newestLine![0]).toContain('opacity="1"');
  expect(newestLine![0]).toContain(`stroke="${WEB_THEME.construction ?? "#6366f1"}"`);
  expect(olderLine![0]).not.toContain(`stroke="${WEB_THEME.construction ?? "#6366f1"}"`);
});

test("renderFolded: markOverlay with an empty marks array draws nothing, same as omitting it", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const withoutOverlay = renderFolded(scene, { theme: WEB_THEME }).toString();
  const withEmptyOverlay = renderFolded(scene, { theme: WEB_THEME, markOverlay: { marks: [] } }).toString();
  expect(withEmptyOverlay).toBe(withoutOverlay);
});

test("renderFolded: markOverlay draws real marks — boundary endpoints and multi-face spans", async () => {
  // mark-overlay-regression.fold is `paper square / mark --diag = map .a
  // onto .c / step left / mark --ray = through .a .c / fold map --ab onto
  // --diag` — both marks are real Beloch marks (not hand-picked
  // safely-interior geometry): their endpoints are the paper's own
  // corners, sitting exactly ON the boundary of whatever face they land
  // in. --diag (frame 0, the synthetic flat sheet — always 1 face) exposed
  // the pointInPolygon boundary-exclusion bug on its own. --ray is
  // recorded at frame 1, captured AFTER `step left` against the live
  // state (2 faces, since --diag already subdivides the render topology by
  // then) — its segment crosses both of those still-flat, still-coplanar
  // triangles before any real fold happens, exposing the "whole segment in
  // one face" multi-face-span bug. See
  // docs/superpowers/plans/2026-07-20-playground-statement-sourcemap.md's
  // progress ledger — a regression here means either bug came back.
  const scene = parseFold(await golden("mark-overlay-regression.fold"));
  expect(scene.statements.length).toBe(3);

  for (const stmt of scene.statements) {
    if (stmt.kind !== "mark" || !stmt.mark) continue;
    const svg = renderFolded(scene, { theme: WEB_THEME, step: String(stmt.frameIndex), markOverlay: { marks: [stmt.mark] } }).toString();
    expect(svg).toContain(`data-crease-id="${stmt.mark.creaseId}"`);
  }

  // --ray (the second mark) spans both of --diag's triangles — the
  // multi-face fix must draw it as (at least) two separate pieces, not
  // silently pick one arbitrary face and drop the rest.
  const rayStmt = scene.statements[1]!;
  const raySvg = renderFolded(scene, {
    theme: WEB_THEME, step: String(rayStmt.frameIndex), markOverlay: { marks: [rayStmt.mark!] },
  }).toString();
  const pieces = raySvg.match(new RegExp(`data-crease-id="${rayStmt.mark!.creaseId}"`, "g")) ?? [];
  expect(pieces.length).toBeGreaterThan(1);
});
