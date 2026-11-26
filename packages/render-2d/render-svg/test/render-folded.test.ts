import { test, expect } from "bun:test";
import { orientationAt, parseFold, SceneError, type Mark } from "@beloch/scene";
import { renderFolded, WEB_THEME, DEFAULT_THEME } from "@beloch/render-svg";
import { makeLayout, PAD, SZ } from "../src/layout";
import { pointInPolygon, sideUp } from "../src/geometry";

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

// hidden="depth" answers how deeply a segment is buried, not only that it is.
// fold-quarter stacks four layers, so its buried runs span three depths.
test("hidden=depth fades a buried segment by the layers over it", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const depth = renderFolded(scene, { hidden: "depth" }).toString();
  const dashed = renderFolded(scene, { hidden: "dashed" }).toString();
  const hide = renderFolded(scene, { hidden: "hide" }).toString();

  const occluded = (svg: string) => (svg.match(/data-occluded="true"/g) ?? []).length;
  expect(occluded(hide)).toBe(0);
  expect(occluded(dashed)).toBeGreaterThan(0);
  expect(occluded(depth)).toBeGreaterThan(0);

  const depths = [...new Set([...depth.matchAll(/data-depth="(\d+)"/g)].map((m) => Number(m[1])))];
  expect(depths.length).toBeGreaterThanOrEqual(2);
  expect(Math.min(...depths)).toBe(1);

  // The uniform mode stamps no depth at all, so the two modes stay apart.
  expect(dashed).not.toContain("data-depth");

  // Deeper is fainter, strictly, over the whole range this scene produces.
  const opacityAt = (n: number) => {
    const m = new RegExp(`data-depth="${n}" opacity="([0-9.]+)"`).exec(depth);
    return m ? Number(m[1]) : null;
  };
  const sorted = [...depths].sort((a, b) => a - b);
  const first = opacityAt(sorted[0]!);
  const last = opacityAt(sorted[sorted.length - 1]!);
  expect(first).not.toBeNull();
  expect(last).not.toBeNull();
  expect(last!).toBeLessThan(first!);
});

test("hidden=dashed draws occluded sub-segments, hide does not", async () => {
  const scene = parseFold(await occlude());
  const dashed = renderFolded(scene, { hidden: "dashed" }).toString();
  const hidden = renderFolded(scene, { hidden: "hide" }).toString();
  expect((dashed.match(/data-occluded="true"/g) ?? []).length).toBeGreaterThan(0);
  expect((hidden.match(/data-occluded="true"/g) ?? []).length).toBe(0);
});

test("occluded named-vertex dots: dashed grays them, hide drops them", async () => {
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

// A point the reader picked is drawn whatever the hidden mode says, as a
// picked crease is: covered, grayed and flagged, with its label.
test("a picked point under a higher layer keeps its dot and its label under hide", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const svg = renderFolded(scene, { hidden: "hide", annotate: [".a"] }).toString();
  expect(svg).toMatch(/data-bel-name="a" data-kind="point"[^>]*data-occluded="true"/);
  expect(svg).toMatch(/data-bel-name="a" data-kind="point-label"[^>]*data-occluded="true"/);
  // The other covered corners stay hidden.
  expect(svg).not.toMatch(/data-bel-name="b" data-kind="point"/);
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
  const mid = renderFolded(scene, { step: "2" }).toString();
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
  // 0-based frame indices for cube-root.fold's three named foldedForm steps
  // (vertical_middle, thirds, beloch_fold), in file order.
  for (const step of ["2", "3", "4"]) {
    const found = scene.steps[Number(step)];
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

// The folded view draws no fold kinds, so it has no legend to show.
test("the folded view draws no legend, legend: true included", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  expect(renderFolded(scene).toString()).not.toContain('class="legend-panel"');
  expect(renderFolded(scene, { legend: true }).toString()).not.toContain('class="legend-panel"');
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
  expect(newestLine![0]).toContain(`stroke="${WEB_THEME.construction ?? DEFAULT_THEME.construction}"`);
  expect(olderLine![0]).not.toContain(`stroke="${WEB_THEME.construction ?? DEFAULT_THEME.construction}"`);

  const olderWidth = Number(olderLine![0].match(/stroke-width="([\d.]+)"/)![1]);
  const newestWidth = Number(newestLine![0].match(/stroke-width="([\d.]+)"/)![1]);
  expect(newestWidth).toBeGreaterThan(olderWidth);
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
  // one face" multi-face-span bug. A regression here means either bug came
  // back.
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

// A buried run is the same crease as the visible run it continues, and a host
// resolves what the reader pointed at from the line's own attributes. Without
// the id a drawn hidden line answers nothing when it is clicked.
test("a buried run carries the crease it belongs to", async () => {
  const scene = parseFold(await occlude());
  // The fixture is a bare FOLD, so every edge is given a provenance here: the
  // id is what the drawing is asked to carry through to the buried runs.
  for (const step of scene.steps) {
    step.frame.edgesProvenance = step.frame.edgesVertices.map((_, i) => ({
      axiom: null, sources: [], span: null, name: null, creaseId: i, statement: null,
    }));
  }
  const svg = renderFolded(scene, { hidden: "depth" }).toString();
  const buried = svg.match(/<line[^>]*data-occluded="true"[^>]*>/g) ?? [];
  expect(buried.length).toBeGreaterThan(0);
  expect(buried.filter((l) => /data-crease-id="\d+"/.test(l)).length).toBe(buried.length);
});

// #54. Written with `beloch fold` from
//   mark (map .a onto .b) as --ef
//   fold (map .d onto --ef through .a) (toward .c)
// The fold lays --ef on two layers, and the reader asks for it by name.
test("a requested name on two layers is written once", async () => {
  const scene = parseFold(await golden("label-twice.fold"));
  const s = renderFolded(scene, { step: "1", labels: ["--ef"] }).toString();
  expect(s.match(/>[^<]*--ef[^<]*</g)).toEqual([">--ef<"]);
  const flat = renderFolded(scene, { step: "0", labels: [".a"] }).toString();
  expect(flat.match(/>[^<]*\.a[^<]*</g)).toEqual([">.a<"]);
});

// @orient, its three forms. Each fixture folds .a onto .c, which leaves the
// triangle .b .c .d; the drawing is turned about the center of the
// triangle's bounding box, which lies halfway between .b and .d.
const dot = (svg: string, name: string): [number, number] => {
  const m = new RegExp(`<circle cx="([-0-9.]+)" cy="([-0-9.]+)"[^>]*data-bel-name="${name}"`).exec(svg);
  if (!m) throw new Error(`no dot for .${name}`);
  return [Number(m[1]), Number(m[2])];
};
const turned = async (fixture: string, orient = true) => {
  const scene = parseFold(await golden(fixture));
  const svg = renderFolded(scene, { orient, hidden: "dashed" }).toString();
  return { scene, b: dot(svg, "b"), d: dot(svg, "d") };
};

// `@orient .b down` on the flat sheet: the direction from the centroid of
// the square to .b, 45 degrees below the x axis, turns to point down.
test("@orient .a down turns the folded drawing so .a lies below the centroid", async () => {
  const { scene, b, d } = await turned("orient-point.fold");
  expect(orientationAt(scene, 1)).toBeCloseTo(-Math.PI / 4, 9);
  expect(b[0]).toBeCloseTo(d[0], 6);
  expect(b[1]).toBeGreaterThan(d[1]);           // SVG y grows downward
});

// `@orient .d .b right`: the direction from .d to .b turns to point right.
test("@orient .a .b right turns the direction from .a to .b to the right", async () => {
  const { scene, b, d } = await turned("orient-points.fold");
  expect(orientationAt(scene, 1)).toBeCloseTo(Math.PI / 4, 9);
  expect(b[1]).toBeCloseTo(d[1], 6);
  expect(b[0]).toBeGreaterThan(d[0]);
});

// `@orient .d .b up` turns by 135 degrees; `@orient --bd vertical` then has
// -45 and 135 degrees to choose from and keeps the one nearer the turn in
// force, 135. Without the earlier @orient it would choose -45.
test("@orient --l vertical takes the rotation nearer the orientation in force", async () => {
  const { scene, b, d } = await turned("orient-axis.fold");
  expect(orientationAt(scene, 0)).toBeCloseTo((3 * Math.PI) / 4, 9);
  expect(orientationAt(scene, 1)).toBeCloseTo((3 * Math.PI) / 4, 9);
  expect(b[0]).toBeCloseTo(d[0], 6);
  expect(b[1]).toBeLessThan(d[1]);
  scene.annotations.splice(scene.annotations.findIndex((a) => a.key === "orient"), 1);
  expect(orientationAt(scene, 1)).toBeCloseTo(-Math.PI / 4, 9);
});

test("without orient the folded drawing keeps the table's axes", async () => {
  const { b, d } = await turned("orient-point.fold", false);
  expect(b[0]).toBeGreaterThan(d[0]);
  expect(b[1]).toBeGreaterThan(d[1]);
});

// A turned drawing takes its frame from the turned faces: their bounds are
// centered on the canvas and the longer side spans the drawing area.
test("a turned drawing sits centered and fills the canvas", async () => {
  const scene = parseFold(await golden("orient-point.fold"));
  const svg = renderFolded(scene, { orient: true }).toString();
  const pts = [...svg.matchAll(/<polygon points="([^"]+)"/g)].flatMap((m) =>
    m[1]!.split(" ").map((p) => p.split(",").map(Number) as [number, number]));
  expect(pts.length).toBeGreaterThan(0);
  const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
  const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
  expect((x0 + x1) / 2).toBeCloseTo(PAD + SZ / 2, 6);
  expect((y0 + y1) / 2).toBeCloseTo(PAD + SZ / 2, 6);
  expect(Math.max(x1 - x0, y1 - y0)).toBeCloseTo(SZ, 6);
});

// An @orient after the last statement turns the final state, read against
// it: from the centroid (2/3, 2/3) of the triangle .b .c .d to .b points down.
test("an @orient after the last statement turns the final state", async () => {
  const scene = parseFold(await golden("orient-trailing.fold"));
  expect(scene.annotations.find((a) => a.key === "orient")!.target).toBeNull();
  expect(orientationAt(scene, 0)).toBe(0);
  expect(orientationAt(scene, 1)).toBeCloseTo(-Math.PI / 2 - Math.atan2(-2, 1), 9);
});

// The square twist of packages/core/tests/cases/collapse/flatten-square-twist.bel
// [hull2020, §6.5]: its four flaps lie in a cycle, each over the next, so no
// bottom-to-top order of whole faces exists, and a drawing that only sorts
// faces either drops some or paints one over a face that lies above it.
const twistScene = async () => parseFold(await golden("square-twist.fold"));

// over[f]: the faces that lie over face f as the reader sees the view, read
// straight from faceOrders (the sign is relative to the second face's normal).
function overSets(scene: Awaited<ReturnType<typeof twistScene>>, bottom: boolean): Set<number>[] {
  const frame = scene.steps[scene.steps.length - 1]!.frame;
  const V = frame.vertices, F = frame.facesVertices;
  const up = F.map((f) => sideUp(f.map((i) => V[i]!)) === "front");
  const over = F.map(() => new Set<number>());
  for (const [f, g, s] of frame.faceOrders) {
    if (s === 0) continue;
    const [lo, hi] = (s < 0) === up[g] ? [f, g] : [g, f];
    if (bottom) over[hi]!.add(lo);
    else over[lo]!.add(hi);
  }
  return over;
}

for (const view of ["top", "bottom"] as const) {
  test(`a layer cycle paints every face, each one hidden where a face lies over it (${view})`, async () => {
    const scene = await twistScene();
    const faces = scene.steps[scene.steps.length - 1]!.frame.facesVertices.length;
    const svg = renderFolded(scene, { view }).toString();
    const painted = [...svg.matchAll(/<polygon [^>]*data-kind="face" data-face-index="(\d+)"[^>]*>/g)]
      .map((m) => ({ face: Number(m[1]), mask: /mask="url\(#([^)]+)\)"/.exec(m[0])?.[1] }));
    expect(painted.map((p) => p.face).sort((a, b) => a - b)).toEqual([...Array(faces).keys()]);
    const cut = new Map<string, Set<number>>(
      [...svg.matchAll(/<mask id="([^"]+)"[^>]*>(.*?)<\/mask>/g)].map((m) => [
        m[1]!,
        new Set([...m[2]!.matchAll(/data-face-index="(\d+)"/g)].map((n) => Number(n[1]))),
      ]),
    );
    const over = overSets(scene, view === "bottom");
    const at = new Map(painted.map((p, i) => [p.face, i]));
    for (const p of painted) {
      for (const g of over[p.face]!) {
        // g lies over p: either g is painted later, or p leaves g's area out
        const later = at.get(g)! > at.get(p.face)!;
        const masked = p.mask !== undefined && cut.get(p.mask)!.has(g);
        expect({ face: p.face, over: g, hidden: later || masked })
          .toEqual({ face: p.face, over: g, hidden: true });
      }
    }
  });
}

// Whether p lies on an edge of poly.
const onBoundary = (p: [number, number], poly: [number, number][]): boolean =>
  poly.some((a, i) => {
    const b = poly[(i + 1) % poly.length]!;
    const dx = b[0] - a[0], dy = b[1] - a[1];
    const t = Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)));
    return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy) < 1e-9;
  });

// A drawn crease line shows where no face lies over the faces it borders.
test("a layer cycle hides the creases under each flap", async () => {
  const scene = await twistScene();
  const frame = scene.steps[scene.steps.length - 1]!.frame;
  const V = frame.vertices, F = frame.facesVertices;
  const polys = F.map((f) => f.map((i) => V[i]!));
  const over = overSets(scene, false);
  const layout = makeLayout([scene.cp.vertices, ...scene.steps.map((s) => s.frame.vertices)].flat());
  const world = (px: number, py: number): [number, number] => [
    layout.minX + ((px - PAD) / SZ) * layout.span,
    layout.minY + (1 - (py - PAD) / SZ) * layout.span,
  ];
  const svg = renderFolded(scene, { hidden: "hide" }).toString();
  const lines = [...svg.matchAll(/<line [^>]*data-kind="crease"[^>]*x1="([^"]+)" y1="([^"]+)" x2="([^"]+)" y2="([^"]+)"/g)];
  expect(lines.length).toBeGreaterThan(0);
  for (const m of lines) {
    const [x1, y1, x2, y2] = [1, 2, 3, 4].map((k) => Number(m[k]));
    const mid = world((x1! + x2!) / 2, (y1! + y2!) / 2);
    const own = polys.flatMap((p, f) => (onBoundary(mid, p) ? [f] : []));
    const inside = polys.flatMap((p, f) => (pointInPolygon(mid, p) && !own.includes(f) ? [f] : []));
    const buried = inside.filter((c) => own.every((b) => over[b]!.has(c)));
    expect({ line: m[0].slice(0, 60), buried }).toEqual({ line: m[0].slice(0, 60), buried: [] });
  }
});

// A crease that lies flat in the state drawn, such as a construction line the
// program marked to place a point, is drawn unless hideFlat leaves it out.
test("hideFlat leaves out the creases that lie flat", async () => {
  const scene = parseFold(await golden("square-twist.fold"));
  const flat = (svg: string) => (svg.match(/class="crease-F"/g) ?? []).length;
  expect(flat(renderFolded(scene).toString())).toBeGreaterThan(0);
  expect(flat(renderFolded(scene, { hideFlat: true }).toString())).toBe(0);
  expect(flat(renderFolded(scene, { view: "bottom", hideFlat: true }).toString())).toBe(0);
});
