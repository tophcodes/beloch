// Operation view: one write drawn from its trace entry, as two panels. The
// first is the state the write read with the terms of the write's definition
// on it (spec/MODEL.md, §5): the axis, the moving set and the target of a
// fold; the axis, the tip, the spine, the halves and the bodies of a reverse
// fold; the vertex, the rays and the stayer of a flatten. The second is the
// state the write yields. Reads `beloch:trace` (spec/FOLD.md, "The trace").
import type { FoldScene, Frame, Region, Segment, Vec2, WriteCandidate, WriteEntry } from "@beloch/scene";
import { SceneError } from "@beloch/scene";
import { createDoc, el, SvgDoc } from "./svgdoc";
import type { SvgNode } from "./svgdoc";
import { DEFAULT_THEME } from "./theme";
import type { Theme } from "./theme";
import { clipHalfPlane, clipLineToPoly } from "./geometry";
import { sceneLayout } from "./layout";
import type { Layout } from "./layout";
import { renderFolded } from "./render-folded";
import type { RenderOptions } from "./render-cp";

export interface OperationOptions extends RenderOptions {
  // Index into scene.statements. Undefined: the statement a traced run failed
  // at, else the last write.
  statement?: number | undefined;
}

export function writeEntry(scene: FoldScene, statement?: number): WriteEntry {
  if (scene.writeTrace.length === 0) {
    throw new SceneError("no write in beloch:trace; write it with `beloch fold --trace`");
  }
  const target =
    statement ?? scene.error?.statement ?? scene.writeTrace[scene.writeTrace.length - 1]!.statement;
  const entry = scene.writeTrace.find((e) => e.statement === target);
  if (!entry) throw new SceneError(`statement ${target} runs no fold, reverse or flatten`);
  return entry;
}

// The scene with every candidate state of the entry appended as a step, so a
// candidate is drawn by the code that draws any folded state and the layout
// covers it. Returns the step index of each candidate, or -1 for none.
export function withCandidateSteps(scene: FoldScene, entry: WriteEntry): [FoldScene, number[]] {
  const steps = [...scene.steps];
  const index = entry.candidates.map((c) => {
    if (!c.frame) return -1;
    steps.push({ index: steps.length, sourceLine: null, frame: c.frame });
    return steps.length - 1;
  });
  return [{ ...scene, steps }, index];
}

// A folded frame read back onto the paper: each vertex through the inverse of
// the isometry of a face it bounds. What tells two candidate states apart is
// mostly their letters, which the crease pattern of this frame shows.
export function paperFrame(frame: Frame): Frame {
  const vertices = frame.vertices.map((v) => v);
  const matrices = frame.facesMatrix ?? [];
  frame.facesVertices.forEach((face, f) => {
    const m = matrices[f];
    if (!m) return;
    const [m00, m01, m10, m11, tx, ty] = m;
    for (const i of face) {
      const [x, y] = frame.vertices[i]!;
      const dx = x - tx, dy = y - ty;
      // the linear part is orthogonal, so its inverse is its transpose
      vertices[i] = [m00 * dx + m10 * dy, m01 * dx + m11 * dy];
    }
  });
  return { ...frame, vertices, faceOrders: [], facesMatrix: null };
}

export function candidateStatus(c: { selected: boolean; removedBy: string | null }): string {
  if (c.selected) return "selected";
  if (c.removedBy) return `removed: ${c.removedBy}`;
  return "open";
}

type Paint = { stroke: string; wash: string };

function paint(theme: Theme, i: number): Paint {
  return theme.highlightPalette[i % theme.highlightPalette.length]!;
}

function regionNodes(region: Region, p: Paint, lay: Layout, kind: string, dashed = false): SvgNode[] {
  const { tx, ty } = lay;
  return region.map((poly) => el("polygon", {
    "data-kind": kind,
    points: poly.map(([x, y]) => `${tx(x).toFixed(2)},${ty(y).toFixed(2)}`).join(" "),
    fill: dashed ? "none" : p.wash, "fill-opacity": dashed ? 0 : 0.6,
    stroke: p.stroke, "stroke-width": 2,
    ...(dashed ? { "stroke-dasharray": "6 4" } : {}),
  }));
}

// A region drawn as parallel lines, so that two regions stacked on one
// another stay visible as a cross-hatch. `dir` 1 runs the lines up to the
// right, -1 down to the right. Drawn line by line, since a <pattern> needs an
// id and the site inlines several figures into one page.
function hatchNodes(region: Region, p: Paint, lay: Layout, kind: string, dir: 1 | -1,
  spacing: number, width: number): SvgNode[] {
  const gap = (spacing / 460) * lay.span * Math.SQRT2;
  const nodes: SvgNode[] = [];
  for (const poly of region) {
    // the lines x − dir·y = c across the polygon
    const cs = poly.map(([x, y]) => x - dir * y);
    const lo = Math.min(...cs), hi = Math.max(...cs);
    for (let c = Math.ceil(lo / gap) * gap; c < hi; c += gap) {
      const s = clipLineToPoly(1, -dir, c, poly);
      if (s) nodes.push(segmentNode(s, p.stroke, lay, kind, width));
    }
    nodes.push(el("polygon", {
      "data-kind": `${kind}-outline`,
      points: poly.map(([x, y]) => `${lay.tx(x).toFixed(2)},${lay.ty(y).toFixed(2)}`).join(" "),
      fill: "none", stroke: p.stroke, "stroke-width": 1.5,
    }));
  }
  return nodes;
}

function segmentNode([[x1, y1], [x2, y2]]: Segment, stroke: string, lay: Layout, kind: string,
  width = 3, dashed = false): SvgNode {
  return el("line", {
    "data-kind": kind, x1: lay.tx(x1), y1: lay.ty(y1), x2: lay.tx(x2), y2: lay.ty(y2),
    stroke, "stroke-width": width, "stroke-linecap": "round",
    ...(dashed ? { "stroke-dasharray": "6 4" } : {}),
  });
}

// The axis where it crosses the paper of the state, as one segment per face.
function axisNodes(axis: [number, number, number], faces: Vec2[][], lay: Layout, theme: Theme): SvgNode[] {
  const [a, b, c] = axis;
  return faces
    .map((poly) => clipLineToPoly(a, b, c, poly))
    .filter((s): s is [Vec2, Vec2] => s !== null)
    .map((s) => segmentNode(s, theme.construction, lay, "axis", 2.5, true));
}

export function caption(text: string, lay: Layout, theme: Theme): SvgNode {
  return el("text", {
    x: lay.W / 2, y: lay.H - 16, "text-anchor": "middle", "font-size": 15, fill: theme.ink,
  }, [], text);
}

// The part of a convex polygon on the left of the directed line from `o`
// through `p`.
function leftOf(poly: Vec2[], o: Vec2, p: Vec2): Vec2[] {
  const dx = p[0] - o[0], dy = p[1] - o[1];
  return clipHalfPlane(poly, [-dy, dx], dx * o[1] - dy * o[0]);
}

// The sector between two rays from `o`, counter-clockwise from `a` to `b`, on
// the faces of a state. A sector of a flat-foldable vertex is narrower than a
// half turn, so it is the intersection of two half-planes.
function sectorOnFaces(o: Vec2, a: Vec2, b: Vec2, faces: Vec2[][]): Region {
  return faces.map((f) => leftOf(leftOf(f, o, a), b, o)).filter((p) => p.length >= 3);
}

// The detail of one candidate on the state before it: a reverse fold's spine,
// halves and bodies, a flatten's rays and stayer. The two halves of a tip lie
// on one another, as do the two bodies, so each pair is hatched in two
// directions, a half and its body in one colour.
export function candidateNodes(entry: WriteEntry, c: WriteCandidate, faces: Vec2[][], lay: Layout,
  theme: Theme): SvgNode[] {
  const nodes: SvgNode[] = [];
  const pair = (rs: [Region, Region] | null, kind: string, spacing: number, width: number) => {
    if (!rs) return;
    nodes.push(...hatchNodes(rs[0], paint(theme, 1), lay, kind, 1, spacing, width));
    nodes.push(...hatchNodes(rs[1], paint(theme, 2), lay, kind, -1, spacing, width));
  };
  pair(c.halves, "half", 12, 2);
  pair(c.bodies, "body", 24, 1.2);
  if (c.spine) nodes.push(segmentNode(c.spine, paint(theme, 4).stroke, lay, "spine", 5));
  if (entry.terms.write === "flatten") {
    const o = entry.terms.point;
    if (c.stayer) {
      nodes.push(...regionNodes(sectorOnFaces(o, c.stayer[0], c.stayer[1], faces), paint(theme, 3), lay, "stayer"));
    }
    for (const r of c.rays) nodes.push(segmentNode(r, paint(theme, 0).stroke, lay, "ray"));
    if (c.emergent) nodes.push(segmentNode(c.emergent, paint(theme, 1).stroke, lay, "emergent", 3, true));
    nodes.push(el("circle", {
      "data-kind": "vertex", cx: lay.tx(o[0]), cy: lay.ty(o[1]), r: 6,
      fill: "none", stroke: theme.ink, "stroke-width": 2,
    }));
  }
  return nodes;
}

// The terms of the write on the state it read.
function termNodes(entry: WriteEntry, faces: Vec2[][], lay: Layout, theme: Theme): SvgNode[] {
  const t = entry.terms;
  const shown = entry.candidates.find((c) => c.selected) ??
    entry.candidates.find((c) => c.removedBy === null);
  const nodes: SvgNode[] = [];
  if (t.write === "fold") {
    nodes.push(...regionNodes(t.moving, paint(theme, 0), lay, "moving"));
    if (t.target) nodes.push(...regionNodes(t.target, paint(theme, 1), lay, "target", true));
    nodes.push(...axisNodes(t.axis, faces, lay, theme));
  } else if (t.write === "reverse") {
    // the halves of the spine shown cover the tip
    if (!shown?.halves) nodes.push(...regionNodes(t.tip, paint(theme, 0), lay, "tip"));
    if (shown) nodes.push(...candidateNodes(entry, shown, faces, lay, theme));
    nodes.push(...axisNodes(t.axis, faces, lay, theme));
  } else if (shown) {
    nodes.push(...candidateNodes(entry, shown, faces, lay, theme));
  }
  return nodes;
}

function termCaption(entry: WriteEntry): string {
  const t = entry.terms;
  if (t.write === "fold") return `fold · ${t.placement}`;
  if (t.write === "reverse") return `reverse · ${t.kind}`;
  return "flatten";
}

export function renderOperation(scene: FoldScene, opts: OperationOptions = {}): SvgDoc {
  const entry = writeEntry(scene, opts.statement);
  const [ext, index] = withCandidateSteps(scene, entry);
  const before = ext.steps[entry.frameIndex];
  if (!before) throw new SceneError(`frame ${entry.frameIndex} is not in the file`);
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const lay = sceneLayout(ext);
  const faces = before.frame.facesVertices.map((f) => f.map((i) => before.frame.vertices[i]!));
  // a fold chooses no state: the state after it is the statement's own frame,
  // which a failed fold never reached
  const chosen = entry.candidates.findIndex((c) => c.selected);
  const failed = scene.error?.statement === entry.statement;
  const after = chosen >= 0 ? index[chosen]!
    : entry.terms.write === "fold" && !failed ? scene.statements[entry.statement]!.frameIndex
    : -1;
  const panel = (step: number, nodes: SvgNode[], i: number, title?: string) => {
    const base = renderFolded(ext, {
      step: String(step), title, labels: opts.labels, theme: opts.theme, highlight: opts.highlight,
    }).node();
    return el("svg", { ...base.attrs, x: i * lay.W, y: 0 }, [...base.children, ...nodes]);
  };
  const doc = createDoc(lay.W * 2, lay.H);
  doc.root.children.push(panel(entry.frameIndex,
    [...termNodes(entry, faces, lay, theme), caption(termCaption(entry), lay, theme)], 0, opts.title));
  if (after >= 0) {
    doc.root.children.push(panel(after, [caption("after", lay, theme)], 1));
  } else {
    const why = failed ? scene.error!.message : "no state";
    doc.root.children.push(el("svg", { x: lay.W, y: 0, width: lay.W, height: lay.H }, [
      el("text", {
        x: lay.W / 2, y: lay.H / 2, "text-anchor": "middle", "font-size": 15, fill: theme.ink,
        "data-kind": "failure",
      }, [], why),
    ]));
  }
  return doc;
}
