// The default YR output: every panel of the program in one column, each the
// state it draws turned by the `@orient` in force, with the lines and arrows
// of its writes, its number above and its instruction below. Where the turn
// changes between two panels, the rotation symbol stands between them; a
// panel that turns the model over draws the turn-over arrow below or beside
// the model.
import type { Assignment, FoldScene, Statement, Vec2 } from "@beloch/scene";
import { orientationAt, SceneError } from "@beloch/scene";
import {
  clipHalfPlane, createDoc, DEFAULT_THEME, el, makeLayout, renderFolded, segInsideIntervals, segmentsInFrame, turnFrame,
} from "@beloch/render-svg";
import type { Layout, LineStyle, SvgDoc, SvgNode, Theme } from "@beloch/render-svg";
import { existingCreaseSegments } from "./creases";
import {
  existingCrease, foldAndUnfoldArrow, hookedValleyArrow, mountainArrow, mountainLine, pushArrow, turnOverArrow,
  valleyArrow, valleyLine, wrapArrows,
} from "./draw";
import type { Ink } from "./draw";
import { foldMotion, petalFold, turnOver, unionCentroid } from "./motion";
import type { FoldMotion, Petal } from "./motion";
import { panels } from "./panels";
import type { Panel } from "./panels";
import { rotationSymbol, turnFraction } from "./rotation";
import { gapFrame, openFrame } from "./open";

export interface YrOptions {
  theme?: Partial<Theme> | undefined;
  // the angle, in degrees, every fold stands open by in the drawing (see
  // openFrame); absent, OPEN; 0 draws the state flat
  open?: number | undefined;
  // whether two raw edges that meet are drawn apart (see gapFrame); absent,
  // they are
  gap?: boolean | undefined;
}

// The angle every fold stands open by unless the caller sets another, in
// degrees.
const OPEN = 2;

// The stroke width of the outline, in page units (see panelLineStyle).
const OUTLINE = 2.2;

// The width of a gap between two raw edges at its open end, and the largest
// step between two layers, in outline widths: a step narrower than a line
// would merge two edges into one.
const GAP = 3.6, STEP = 1.5;

// The state of a panel with its meeting raw edges drawn apart and drawn open
// by `angle` degrees, a unit of height moving a point straight up the page,
// and the panel's view with every point it places moved with the paper under
// it. Up the page keeps a model that is symmetric about the vertical
// symmetric in the drawing.
function openPanel(scene: FoldScene, base: number, angle: number, gap: boolean, view: PanelView) {
  const scale = view.layout.tx(1) - view.layout.tx(0);
  const flat = scene.steps[base]!.frame;
  const up: Vec2 = [Math.sin(view.turn), Math.cos(view.turn)];   // the page's up, on the table
  const apart = gap ? gapFrame(flat, (GAP * OUTLINE) / scale) : { frame: flat, move: (p: Vec2) => p };
  const opened = openFrame(apart.frame, angle, up, (STEP * OUTLINE) / scale);
  const frame = opened.frame;
  const move = (p: Vec2) => opened.move(apart.move(p));

  // the flat view is affine: its inverse from the images of three points
  const o = view.flatPx([0, 0]), ex = view.flatPx([1, 0]), ey = view.flatPx([0, 1]);
  const det = (ex[0] - o[0]) * (ey[1] - o[1]) - (ey[0] - o[0]) * (ex[1] - o[1]);
  const unpx = ([x, y]: Vec2): Vec2 => {
    const dx = x - o[0], dy = y - o[1];
    return [(dx * (ey[1] - o[1]) - dy * (ey[0] - o[0])) / det, ((ex[0] - o[0]) * dy - (ex[1] - o[1]) * dx) / det];
  };
  const movePage = (p: Vec2): Vec2 => view.flatPx(move(unpx(p)));
  // A crease is a straight line between its two ends: the ends of all its
  // pieces together move with the paper under them, and every piece lies on
  // the line between the moved ends. Creases that meet at a point meet there
  // after the move too.
  const lines = (segs: [Vec2, Vec2][]): [Vec2, Vec2][] => {
    const runs = new Map<string, { u: Vec2; ts: number[]; members: number[] }>();
    segs.forEach(([p, q], i) => {
      let a = Math.atan2(q[1] - p[1], q[0] - p[0]);
      if (a < 0) a += Math.PI;
      if (a >= Math.PI - 1e-6) a -= Math.PI;
      const u: Vec2 = [Math.cos(a), Math.sin(a)];
      const key = `${Math.round(a * 1e3)},${Math.round((-u[1] * p[0] + u[0] * p[1]) * 2)}`;
      const run = runs.get(key) ?? { u, ts: [], members: [] };
      run.ts.push(u[0] * p[0] + u[1] * p[1], u[0] * q[0] + u[1] * q[1]);
      run.members.push(i);
      runs.set(key, run);
    });
    const out = [...segs];
    for (const { u, ts, members } of runs.values()) {
      const t0 = Math.min(...ts), t1 = Math.max(...ts);
      const [p0] = segs[members[0]!]!;
      const base = u[0] * p0[0] + u[1] * p0[1];
      const at = (t: number): Vec2 => [p0[0] + u[0] * (t - base), p0[1] + u[1] * (t - base)];
      const [a, b] = [movePage(at(t0)), movePage(at(t1))];
      const along = (p: Vec2): Vec2 => {
        const s = t1 > t0 ? (u[0] * p[0] + u[1] * p[1] - t0) / (t1 - t0) : 0;
        return [a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s];
      };
      for (const i of members) out[i] = [along(segs[i]![0]), along(segs[i]![1])];
    }
    return out;
  };
  return {
    scene: { ...scene, steps: scene.steps.map((s, i) => (i === base ? { ...s, frame } : s)) },
    view: { ...view, px: (p: Vec2) => view.flatPx(move(p)), lines },
  };
}

export interface PanelView {
  turn: number;                 // the rotation of the table onto the page, radians
  layout: Layout;
  px: (table: Vec2) => Vec2;    // a table point of the panel's state to page pixels, moved with the paper
  flatPx: (table: Vec2) => Vec2;  // the same, of the state as it lies
  // page segments of creases drawn through flatPx, moved with the paper
  lines: (segs: [Vec2, Vec2][]) => [Vec2, Vec2][];
}

// The state a panel draws, turned by the `@orient` in force, with the center
// of its outline and half the longer side of its bounding box.
function turned(scene: FoldScene, panel: Panel) {
  const frame = scene.steps[panel.base]?.frame;
  if (!frame) throw new SceneError(`panel ${panel.number} draws a state the FOLD does not hold`);
  const turn = orientationAt(scene, panel.base);
  const { frame: t, place } = turnFrame(frame, turn);
  const xs = t.vertices.map((v) => v[0]), ys = t.vertices.map((v) => v[1]);
  const cx = (Math.min(...xs) + Math.max(...xs)) / 2, cy = (Math.min(...ys) + Math.max(...ys)) / 2;
  const half = Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)) / 2;
  return { turn, place, cx, cy, half };
}

// How a panel lays its state on the page: turned by the `@orient` in force and
// centered in a square of side 2·`half` in table units, by default the square
// around the turned outline. Panels that share `half` share a scale.
export function panelView(scene: FoldScene, panel: Panel, half?: number): PanelView {
  const { turn, place, cx, cy, half: own } = turned(scene, panel);
  const h = half ?? own;
  const layout = makeLayout([[cx - h, cy - h], [cx + h, cy + h]]);
  const px = (p: Vec2): Vec2 => { const q = place(p); return [layout.tx(q[0]), layout.ty(q[1])]; };
  return { turn, layout, px, flatPx: px, lines: (segs) => segs };
}

// The paper in a panel: its outline in ink. The renderer draws the edges of
// folded layers in its own outline style and asks this style only for the
// creases that lie flat, which the panel leaves to existingCreaseSegments.
const panelLineStyle = (assignment: Assignment, theme: Theme): LineStyle =>
  assignment === "B" ? { stroke: theme.ink, strokeWidth: 2.2 } : { stroke: theme.ink, strokeWidth: 0, opacity: 0 };

// The pieces of a fold line as one line per straight run: the faces a fold
// crosses each give it a piece, and pieces that overlap would draw their dash
// patterns out of step. Each run starts at its end with the smaller parameter
// along a fixed direction, so that its dashes start at that end.
function merged(segs: [Vec2, Vec2][]): [Vec2, Vec2][] {
  const runs = new Map<string, { u: Vec2; n: Vec2; c: number; spans: [number, number][] }>();
  for (const [p, q] of segs) {
    let a = Math.atan2(q[1] - p[1], q[0] - p[0]);
    if (a < 0) a += Math.PI;
    if (a >= Math.PI - 1e-6) a -= Math.PI;
    const u: Vec2 = [Math.cos(a), Math.sin(a)], n: Vec2 = [-u[1], u[0]];
    const c = n[0] * p[0] + n[1] * p[1];
    const key = `${Math.round(a * 1e3)},${Math.round(c * 2)}`;
    const run = runs.get(key) ?? { u, n, c, spans: [] };
    const t = [u[0] * p[0] + u[1] * p[1], u[0] * q[0] + u[1] * q[1]].sort((x, y) => x - y) as [number, number];
    run.spans.push(t);
    runs.set(key, run);
  }
  const out: [Vec2, Vec2][] = [];
  for (const { u, n, c, spans } of runs.values()) {
    spans.sort((x, y) => x[0] - y[0]);
    let [t0, t1] = spans[0]!;
    const at = (t: number): Vec2 => [n[0] * c + u[0] * t, n[1] * c + u[1] * t];
    for (const [s0, s1] of spans.slice(1)) {
      if (s0 <= t1 + 0.5) t1 = Math.max(t1, s1);
      else { out.push([at(t0), at(t1)]); [t0, t1] = [s0, s1]; }
    }
    out.push([at(t0), at(t1)]);
  }
  return out;
}

const mid = (segs: [Vec2, Vec2][]): Vec2 | null => {
  if (segs.length === 0) return null;
  const pts = segs.flat();
  return [pts.reduce((s, p) => s + p[0], 0) / pts.length, pts.reduce((s, p) => s + p[1], 0) / pts.length];
};

// A mark's fold-and-unfold arrow, in page pixels: the paper on the side of
// the crease that holds the panel's leftmost corner folds over, so the arrow
// runs from the center of mass of that side [lang1991conventions, Part II]
// to its mirror image across the crease.
function markArrow(faces: Vec2[][], [a, b]: [Vec2, Vec2]): [Vec2, Vec2] {
  const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy);
  const side = (p: Vec2) => (dx * (p[1] - a[1]) - dy * (p[0] - a[0])) / L;
  const farthest = (sign: number) =>
    faces.flat().filter((p) => sign * side(p) > 1e-6).sort((p, q) => sign * side(q) - sign * side(p))[0];
  const left = [farthest(1), farthest(-1)].filter((p): p is Vec2 => p !== undefined)
    .sort((p, q) => (Math.abs(p[0] - q[0]) > 1 ? p[0] - q[0] : p[1] - q[1]))[0];
  if (!left) throw new SceneError("a mark with no paper beside it");
  // the half-plane on the side of `left`: n·p ≥ n·a
  const sign = Math.sign(side(left));
  const n: Vec2 = [-dy * sign, dx * sign];
  const moving = faces.map((f) => clipHalfPlane(f, n, n[0] * a[0] + n[1] * a[1])).filter((f) => f.length > 2);
  const tail = unionCentroid(moving);
  const d = side(tail);
  return [tail, [tail[0] + (2 * d * dy) / L, tail[1] - (2 * d * dx) / L]];
}

// The turn-over arrows of a panel, in the panel's page pixels. The line the
// table is mirrored in runs up the page for a turn from side to side. That
// arrow lies below the model; a turn from top to bottom lies right of the
// model, as close as the panel's square allows.
function turnArrows(scene: FoldScene, panel: Panel, view: PanelView, ink: Ink): SvgNode[] {
  const model = scene.steps[panel.base]!.frame.vertices.map(view.px);
  const xs = model.map((p) => p[0]), ys = model.map((p) => p[1]);
  const nodes: SvgNode[] = [];
  for (const w of panel.writes) {
    const turn = turnOver(scene, w);
    if (!turn) continue;
    const o = view.px([0, 0]), e = view.px(turn.axis);
    if (Math.abs(e[1] - o[1]) >= Math.abs(e[0] - o[0])) {
      const center: Vec2 = [(Math.min(...xs) + Math.max(...xs)) / 2, Math.max(...ys) + 44];
      nodes.push(turnOverArrow(center, "side-to-side", ink));
    } else {
      const center: Vec2 = [Math.min(Math.max(...xs) + 34, view.layout.W - 30), (Math.min(...ys) + Math.max(...ys)) / 2];
      nodes.push(turnOverArrow(center, "top-to-bottom", ink));
    }
  }
  return nodes;
}

// How far the valley line of an inside reverse fold runs beyond the edge and
// the gap between the push arrow and the edge it points at, in page pixels;
// and where the push arrow of an inside reverse fold points, as a fraction of
// the folded edge from the crease to the tip.
const BEYOND = 36, PUSH_GAP = 6, PUSH_ALONG = 0.4;

const unit = (from: Vec2, to: Vec2): Vec2 => {
  const dx = to[0] - from[0], dy = to[1] - from[1], l = Math.hypot(dx, dy);
  return [dx / l, dy / l];
};

// The lines and arrows of a reverse fold [lang1991conventions, Parts IV and
// V; lang2011secrets, Figs. 2.21 and 2.22]. Both draw a push arrow that
// crosses the folded edge square, from outside the paper. Inside: the
// mountain line on the near layer, the valley line on the far layer where it
// shows and beyond the edge where the layers open, the push arrow on the
// folded edge between the crease and the tip, and a valley arrow from the tip
// to where it lands, bent away from the crease so that its stem stays off the
// paper. Outside: the valley line on the near layer, the mountain line on the
// far layer where it shows, the push arrow where the crease meets the folded
// edge, and the two loops of `wrapArrows` around the flap.
function reverseOverlays(motion: FoldMotion, statement: number, view: PanelView, ink: Ink): SvgNode[] {
  const r = motion.reverse!;
  const flat = (segs: [Vec2, Vec2][]) => segs.map(([p, q]): [Vec2, Vec2] => [view.flatPx(p), view.flatPx(q)]);
  const near = merged(view.lines(flat(r.near))), far = merged(view.lines(flat(r.far)));
  const at = view.px(r.at), open = view.px(r.open), tipEnd = view.px(r.edge[1]);
  const along = unit(view.px(r.edge[0]), tipEnd);
  // the normal of the folded edge, toward the open edges
  let n: Vec2 = [-along[1], along[0]];
  if (n[0] * (open[0] - at[0]) + n[1] * (open[1] - at[1]) < 0) n = [-n[0], -n[1]];
  const push = (p: Vec2) => pushArrow([p[0] - n[0] * PUSH_GAP, p[1] - n[1] * PUSH_GAP], n, ink);

  if (motion.kind === "outside-reverse") {
    const width = (open[0] - at[0]) * n[0] + (open[1] - at[1]) * n[1];
    return [
      ...near.map((s) => valleyLine(s, statement, ink)),
      ...far.map((s) => mountainLine(s, statement, ink)),
      push(at),
      ...wrapArrows([at[0] + n[0] * width, at[1] + n[1] * width], at, unit(at, tipEnd), ink),
    ];
  }
  // the valley line beyond the edge continues the one on the far layer
  const flatAt = view.flatPx(r.at), flatOpen = view.flatPx(r.open), out = unit(flatAt, flatOpen);
  const valley = merged(view.lines([...flat(r.far), [flatOpen, [flatOpen[0] + out[0] * BEYOND, flatOpen[1] + out[1] * BEYOND]]]));
  const pushAt: Vec2 = [at[0] + (tipEnd[0] - at[0]) * PUSH_ALONG, at[1] + (tipEnd[1] - at[1]) * PUSH_ALONG];
  const tail = view.px(motion.tail), head = view.px(motion.head);
  const crease = mid(near) ?? at;
  const away: Vec2 = [tail[0] + head[0] - crease[0], tail[1] + head[1] - crease[1]];
  return [
    ...near.map((s) => mountainLine(s, statement, ink)),
    ...valley.map((s) => valleyLine(s, statement, ink)),
    push(pushAt),
    valleyArrow(tail, head, away, ink),
  ];
}

// How far past the paper's outline the lift arrow of a petal fold ends, in
// page pixels, as in [lang2011secrets, Fig. 2.31].
const LIFT_PAST = 90;

// Where the lift arrow from `tail` toward `landing` ends, in page pixels: on
// the line between them, LIFT_PAST past the last point where that line leaves
// the paper `paper` (polygons in page pixels), and never past `landing`.
export function liftHead(tail: Vec2, landing: Vec2, paper: Vec2[][]): Vec2 {
  const L = Math.hypot(landing[0] - tail[0], landing[1] - tail[1]);
  const exit = Math.max(0, ...paper.flatMap((poly) => segInsideIntervals(tail, landing, poly).map(([, t1]) => t1)));
  const t = Math.min(1, exit + LIFT_PAST / L);
  return [tail[0] + (landing[0] - tail[0]) * t, tail[1] + (landing[1] - tail[1]) * t];
}

// The lines and arrows of a petal fold [lang2011secrets, Figs. 2.31 and 2.32,
// step 5]: its creases on the top layer, the valley arrow that lifts the
// flap from its tip toward where the tip lands, ending a short way past the
// paper `paper` (see liftHead), and a push arrow at the middle of each fan ray
// on the outline that swings in, square to that ray and into the paper.
function petalOverlays(petal: Petal, statement: number, view: PanelView, paper: Vec2[][], ink: Ink): SvgNode[] {
  const flat = (seg: [Vec2, Vec2]): [Vec2, Vec2] => [view.flatPx(seg[0]), view.flatPx(seg[1])];
  const lines = (letter: "M" | "V") => merged(view.lines(petal.lines.filter((l) => l.letter === letter).map((l) => flat(l.seg))));
  const pushes = petal.pushes.map(({ at, normal }) => {
    const p = view.px(at), n = unit(p, view.px([at[0] + normal[0] * 1e-3, at[1] + normal[1] * 1e-3]));
    return pushArrow([p[0] - n[0] * PUSH_GAP, p[1] - n[1] * PUSH_GAP], n, ink);
  });
  const tail = view.px(petal.tail);
  return [
    ...lines("V").map((s) => valleyLine(s, statement, ink)),
    ...lines("M").map((s) => mountainLine(s, statement, ink)),
    ...pushes,
    valleyArrow(tail, liftHead(tail, view.px(petal.head), paper), null, ink),
  ];
}

function overlays(scene: FoldScene, panel: Panel, view: PanelView, ink: Ink): SvgNode[] {
  const out: SvgNode[] = [];
  // a crease is drawn as it lies and moves with the paper as one line
  const toPx = (segs: [Vec2, Vec2][]) =>
    view.lines(segs.map(([p, q]): [Vec2, Vec2] => [view.flatPx(p), view.flatPx(q)]));

  // the creases of the panel's state, and the scored lines that stand in it
  // and are no edge of it
  const first = panel.writes[0]?.index ?? scene.statements.length;
  const standing: Statement | undefined = scene.statements[first - 1];
  const marks = (standing?.keptMarks ?? []).flatMap((m): [Vec2, Vec2][] => (m.kind === "seg" ? [[m.a, m.b]] : []));
  for (const s of view.lines(existingCreaseSegments(scene, panel.base, marks, view.flatPx))) {
    out.push(existingCrease(s, ink));
  }

  const base = scene.steps[panel.base]!.frame;
  const paper = base.facesVertices.map((f) => f.map((i) => view.px(base.vertices[i]!)));
  for (const w of panel.writes) {
    if (turnOver(scene, w)) continue;
    if (w.kind === "fold") {
      const petal = petalFold(scene, w);
      if (petal) {
        out.push(...petalOverlays(petal, w.index, view, paper, ink));
        continue;
      }
      const motion = foldMotion(scene, w);
      if (motion.reverse) {
        out.push(...reverseOverlays(motion, w.index, view, ink));
        continue;
      }
      const hinge = merged(toPx(motion.hinge));
      const tail = view.px(motion.tail);
      if (motion.kind === "mountain") {
        for (const s of hinge) out.push(mountainLine(s, w.index, ink));
        out.push(mountainArrow(tail, view.px(motion.edge), motion.hooked, paper, `yr-behind-${w.index}`, ink));
      } else if (motion.hooked) {
        // the hook wraps the outer edge of the layers that move, and the arrow
        // carries that point of the edge to where it lands
        for (const s of hinge) out.push(valleyLine(s, w.index, ink));
        out.push(hookedValleyArrow(view.px(motion.edge), view.px(motion.edgeHead), mid(hinge), ink));
      } else {
        for (const s of hinge) out.push(valleyLine(s, w.index, ink));
        out.push(valleyArrow(tail, view.px(motion.head), mid(hinge), ink));
      }
    } else if (w.mark?.kind === "seg") {
      const frame = scene.steps[w.frameIndex]!.frame;
      const segs = merged(toPx(segmentsInFrame(frame, [[w.mark.a, w.mark.b]])));
      for (const s of segs) out.push(valleyLine(s, w.index, ink));
      const faces = frame.facesVertices.map((f) => f.map((i) => view.px(frame.vertices[i]!)));
      const [tail, tip] = markArrow(faces, segs[0]!);
      out.push(foldAndUnfoldArrow(tail, tip, mid(segs), ink));
    }
  }
  return out;
}

// Breaks a sentence into lines of at most `width` characters.
function wrap(text: string, width: number): string[] {
  const lines: string[] = [];
  for (const word of text.split(/\s+/)) {
    const last = lines[lines.length - 1];
    if (last !== undefined && last.length + 1 + word.length <= width) lines[lines.length - 1] = `${last} ${word}`;
    else lines.push(word);
  }
  return lines;
}

const CAPTION = 22, LINE = 28, WRAP = 44, ROTATION = 88;

// The room a panel keeps between what it draws and its edge, in page pixels.
const MARGIN = 16;

type Box = [number, number, number, number];  // min x, min y, max x, max y

// The points the curve of an svg path passes through: the ends of its
// commands, with each segment of an M, L, Q or C command in absolute
// coordinates sampled at 16 points along it, so that a curve counts where it
// runs and its control points do not.
function pathInk(d: string): Vec2[] {
  const pairs = (s: string) => [...s.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)].map((m): Vec2 => [Number(m[1]), Number(m[2])]);
  const out: Vec2[] = [];
  let at: Vec2 = [0, 0];
  for (const [, cmd, args] of d.matchAll(/([MLQC])([^MLQC]*)/g)) {
    const ps = pairs(args!);
    if (cmd === "M") {
      out.push(...ps);
      at = ps.at(-1) ?? at;
      continue;
    }
    const per = cmd === "Q" ? 2 : cmd === "C" ? 3 : 1;
    for (let i = 0; i + per <= ps.length; i += per) {
      const seg = [at, ...ps.slice(i, i + per)];
      for (let k = 1; k <= 16; k++) {
        // the point at k/16 along the curve, by repeated interpolation between its control points
        let q = seg;
        while (q.length > 1) q = q.slice(1).map((p, j): Vec2 => [q[j]![0] + ((p[0] - q[j]![0]) * k) / 16, q[j]![1] + ((p[1] - q[j]![1]) * k) / 16]);
        out.push(q[0]!);
      }
      at = ps[i + per - 1]!;
    }
  }
  return out;
}

// The box the lines, polygons and paths of `nodes` and their children reach,
// or null when they draw none. A mask draws nothing of its own.
function inkBox(nodes: SvgNode[]): Box | null {
  const pts: Vec2[] = [];
  const visit = (n: SvgNode) => {
    if (n.tag === "mask") return;
    const a = n.attrs;
    if (n.tag === "line") pts.push([Number(a["x1"]), Number(a["y1"])], [Number(a["x2"]), Number(a["y2"])]);
    if (n.tag === "polygon") pts.push(...pathInk(`M${String(a["points"])}`));
    if (n.tag === "path") pts.push(...pathInk(String(a["d"])));
    n.children.forEach(visit);
  };
  nodes.forEach(visit);
  if (pts.length === 0) return null;
  const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
  return [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
}

// The size of a state: the greatest distance between two of its vertices,
// which a rotation on the page leaves unchanged. Known ceiling: every pair of
// vertices is measured, O(V²), which a few thousand vertices keep fast.
function size(scene: FoldScene, panel: Panel): number {
  const V = scene.steps[panel.base]!.frame.vertices;
  let d = 0;
  for (let i = 0; i < V.length; i++) {
    for (let j = i + 1; j < V.length; j++) d = Math.max(d, Math.hypot(V[i]![0] - V[j]![0], V[i]![1] - V[j]![1]));
  }
  return d;
}

// The half side, in table units, of the square each panel is drawn in (see
// panelView). Panels share a scale until the model is less than half the size
// it had on the first panel of that scale; that panel starts a new one, and a
// scale fits the largest of its panels [lang1991conventions, Part III].
export function panelHalves(scene: FoldScene, list: Panel[]): number[] {
  const runs: Panel[][] = [];
  let reference = 0;
  for (const p of list) {
    const d = size(scene, p);
    if (runs.length === 0 || d < reference / 2 - 1e-9) {
      runs.push([]);
      reference = d;
    }
    runs[runs.length - 1]!.push(p);
  }
  return runs.flatMap((run) => {
    const half = Math.max(...run.map((p) => turned(scene, p).half));
    return run.map(() => half);
  });
}

export function renderYr(scene: FoldScene, opts: YrOptions = {}): { doc: SvgDoc; hints: string[] } {
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const ink: Ink = { ink: theme.ink, paper: theme.front };
  const { panels: list, hints } = panels(scene);

  const halves = panelHalves(scene, list);
  const drawn = list.map((panel, i) => {
    const flat = panelView(scene, panel, halves[i]);
    const [angle, gap] = [opts.open ?? OPEN, opts.gap ?? true];
    const opened = angle || gap ? openPanel(scene, panel.base, angle, gap, flat) : { scene, view: flat };
    const view = opened.view;
    const doc = renderFolded(opened.scene, {
      step: String(panel.base), orient: true, layout: view.layout,
      annotate: [], dots: "annotated", hidden: "hide",
      theme: { ...opts.theme, lineStyle: panelLineStyle, background: "none" },
    });
    const marks = overlays(scene, panel, view, ink);
    doc.layer("annotations").children.push(...marks);
    const flips = turnArrows(scene, panel, view, ink);
    const caption = panel.text === null ? [] : wrap(panel.text, WRAP);
    // the panel's square, grown until everything it draws lies MARGIN inside
    // it; the first line of the caption stands below that
    const { W: S } = view.layout;
    const reach = inkBox([...marks, ...flips]);
    const box: Box = reach ? [
      Math.min(0, reach[0] - MARGIN), Math.min(0, reach[1] - MARGIN),
      Math.max(S, reach[2] + MARGIN), Math.max(S, reach[3] + MARGIN),
    ] : [0, 0, S, S];
    const top = Math.max(box[3], reach ? reach[3] + MARGIN + CAPTION : 0);
    return {
      panel, doc, flips, caption, box, top, turn: view.turn,
      height: top - box[1] + caption.length * LINE + 16,
    };
  });
  // the turn from the previous panel to each panel, where there is one
  const turns = drawn.map((d, i) => {
    const delta = i === 0 ? 0 : d.turn - drawn[i - 1]!.turn;
    return Math.abs(Math.atan2(Math.sin(delta), Math.cos(delta))) > 1e-9 ? turnFraction(delta) : null;
  });

  // The column is as wide as the widest reach of any panel to either side of
  // its square, the same on both sides, so that every model stands in the
  // middle of the column.
  const S = drawn[0]?.doc.width ?? 0;
  const side = Math.ceil(Math.max(0, ...drawn.map(({ box }) => Math.max(-box[0], box[2] - S))));
  const W = S + 2 * side;
  const H = drawn.reduce((s, d, i) => s + d.height + (turns[i] ? ROTATION : 0), 0);
  const column = createDoc(W, H);
  if (theme.background !== "none") column.root.children.push(el("rect", { width: W, height: H, fill: theme.background }));
  let y = 0;
  drawn.forEach(({ panel, doc, flips, caption, box, top, height }, i) => {
    const turn = turns[i];
    if (turn) {
      column.root.children.push(rotationSymbol([W / 2, y + ROTATION / 2], turn, ink));
      y += ROTATION;
    }
    // the drawing keeps the coordinates of the panel's square, its viewport
    // grown to the panel's box so that nothing it draws is cut off
    const svg = doc.node();
    const [x0, y0] = [-side, box[1]], [w, h] = [W, top - box[1]];
    const drawing = { ...svg, attrs: { ...svg.attrs, x: x0, y: y0, width: w, height: h, viewBox: `${x0} ${y0} ${w} ${h}` } };
    const lines = caption.map((t, i) =>
      el("text", {
        x: W / 2, y: top - box[1] + i * LINE, "text-anchor": "middle",
        "font-size": CAPTION, fill: theme.ink,
      }, [], t));
    column.root.children.push(el("g", { "data-panel": panel.number, transform: `translate(0,${y})` }, [
      el("g", { transform: `translate(${side},${-box[1]})` }, [drawing, ...flips]),
      el("text", { x: 24, y: 48, "font-size": 36, "font-weight": 700, fill: theme.ink }, [], panel.number),
      ...lines,
    ]));
    y += height;
  });
  return { doc: column, hints };
}
