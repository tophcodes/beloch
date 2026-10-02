// The default YR output: every panel of the program in one column, each the
// state it draws turned by the `@orient` in force, with the lines and arrows
// of its writes, its number above and its instruction below. Where the turn
// changes between two panels, the rotation symbol stands between them; a
// panel that turns the model over draws the turn-over arrow below or beside
// the model.
import type { Assignment, FoldScene, Statement, Vec2 } from "@beloch/scene";
import { orientationAt, SceneError } from "@beloch/scene";
import {
  clipHalfPlane, createDoc, DEFAULT_THEME, el, makeLayout, renderFolded, segmentsInFrame, turnFrame,
} from "@beloch/render-svg";
import type { Layout, LineStyle, SvgDoc, SvgNode, Theme } from "@beloch/render-svg";
import { existingCreaseSegments } from "./creases";
import {
  existingCrease, foldAndUnfoldArrow, hookedValleyArrow, mountainArrow, mountainLine, pushArrow, turnOverArrow,
  valleyArrow, valleyLine, wrapArrows,
} from "./draw";
import type { Ink } from "./draw";
import { foldMotion, turnOver, unionCentroid } from "./motion";
import type { FoldMotion } from "./motion";
import { panels } from "./panels";
import type { Panel } from "./panels";
import { rotationSymbol, turnFraction } from "./rotation";

export interface YrOptions {
  theme?: Partial<Theme> | undefined;
}

export interface PanelView {
  turn: number;                 // the rotation of the table onto the page, radians
  layout: Layout;
  px: (table: Vec2) => Vec2;    // a table point of the panel's state to page pixels
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
  return {
    turn, layout,
    px: (p) => { const q = place(p); return [layout.tx(q[0]), layout.ty(q[1])]; },
  };
}

// The paper in a panel: its outline in ink. The renderer draws the edges of
// folded layers in its own outline style and asks this style only for the
// creases that lie flat, which the panel leaves to existingCreaseSegments.
const panelLineStyle = (assignment: Assignment, theme: Theme): LineStyle =>
  assignment === "B" ? { stroke: theme.ink, strokeWidth: 2.2 } : { stroke: theme.ink, strokeWidth: 0, opacity: 0 };

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

// The turn-over arrows of a panel, in the panel's page pixels, and the
// lowest point they reach. The line the table is mirrored in runs up the page
// for a turn from side to side. That arrow lies below the model, where it may
// reach past the panel's square; a turn from top to bottom lies right of the
// model, as close as the panel's edge allows.
function turnArrows(scene: FoldScene, panel: Panel, view: PanelView, ink: Ink): { nodes: SvgNode[]; bottom: number } {
  const model = scene.steps[panel.base]!.frame.vertices.map(view.px);
  const xs = model.map((p) => p[0]), ys = model.map((p) => p[1]);
  const nodes: SvgNode[] = [];
  let bottom = 0;
  for (const w of panel.writes) {
    const turn = turnOver(scene, w);
    if (!turn) continue;
    const o = view.px([0, 0]), e = view.px(turn.axis);
    if (Math.abs(e[1] - o[1]) >= Math.abs(e[0] - o[0])) {
      const center: Vec2 = [(Math.min(...xs) + Math.max(...xs)) / 2, Math.max(...ys) + 44];
      nodes.push(turnOverArrow(center, "side-to-side", ink));
      bottom = Math.max(bottom, center[1] + 30);
    } else {
      const center: Vec2 = [Math.min(Math.max(...xs) + 34, view.layout.W - 30), (Math.min(...ys) + Math.max(...ys)) / 2];
      nodes.push(turnOverArrow(center, "top-to-bottom", ink));
    }
  }
  return { nodes, bottom };
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
  const px = (segs: [Vec2, Vec2][]) => segs.map(([p, q]): [Vec2, Vec2] => [view.px(p), view.px(q)]);
  const near = px(r.near), far = px(r.far);
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
  const out = unit(at, open);
  const beyond: [Vec2, Vec2] = [open, [open[0] + out[0] * BEYOND, open[1] + out[1] * BEYOND]];
  const pushAt: Vec2 = [at[0] + (tipEnd[0] - at[0]) * PUSH_ALONG, at[1] + (tipEnd[1] - at[1]) * PUSH_ALONG];
  const tail = view.px(motion.tail), head = view.px(motion.head);
  const crease = mid(near) ?? at;
  const away: Vec2 = [tail[0] + head[0] - crease[0], tail[1] + head[1] - crease[1]];
  return [
    ...near.map((s) => mountainLine(s, statement, ink)),
    ...[...far, beyond].map((s) => valleyLine(s, statement, ink)),
    push(pushAt),
    valleyArrow(tail, head, away, ink),
  ];
}

function overlays(scene: FoldScene, panel: Panel, view: PanelView, ink: Ink): SvgNode[] {
  const out: SvgNode[] = [];
  const toPx = (segs: [Vec2, Vec2][]) => segs.map(([p, q]): [Vec2, Vec2] => [view.px(p), view.px(q)]);

  // the creases of the panel's state, and the scored lines that stand in it
  // and are no edge of it
  const first = panel.writes[0]?.index ?? scene.statements.length;
  const standing: Statement | undefined = scene.statements[first - 1];
  const marks = (standing?.keptMarks ?? []).flatMap((m): [Vec2, Vec2][] => (m.kind === "seg" ? [[m.a, m.b]] : []));
  for (const s of existingCreaseSegments(scene, panel.base, marks, view.px)) out.push(existingCrease(s, ink));

  for (const w of panel.writes) {
    if (turnOver(scene, w)) continue;
    if (w.kind === "fold") {
      const motion = foldMotion(scene, w);
      if (motion.reverse) {
        out.push(...reverseOverlays(motion, w.index, view, ink));
        continue;
      }
      const hinge = toPx(motion.hinge);
      const tail = view.px(motion.tail);
      if (motion.kind === "mountain") {
        for (const s of hinge) out.push(mountainLine(s, w.index, ink));
        const base = scene.steps[panel.base]!.frame;
        const paper = base.facesVertices.map((f) => f.map((i) => view.px(base.vertices[i]!)));
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
      const segs = toPx(segmentsInFrame(frame, [[w.mark.a, w.mark.b]]));
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
    const view = panelView(scene, panel, halves[i]);
    const doc = renderFolded(scene, {
      step: String(panel.base), orient: true, layout: view.layout,
      annotate: [], dots: "annotated", hidden: "hide",
      theme: { ...opts.theme, lineStyle: panelLineStyle, background: "none" },
    });
    doc.layer("annotations").children.push(...overlays(scene, panel, view, ink));
    const flips = turnArrows(scene, panel, view, ink);
    const caption = panel.text === null ? [] : wrap(panel.text, WRAP);
    // the first line of the caption stands below the turn-over arrows
    const top = Math.max(view.layout.H, flips.bottom + LINE);
    return {
      panel, doc, flips: flips.nodes, caption, top, turn: view.turn, height: top + caption.length * LINE + 16,
    };
  });
  // the turn from the previous panel to each panel, where there is one
  const turns = drawn.map((d, i) => {
    const delta = i === 0 ? 0 : d.turn - drawn[i - 1]!.turn;
    return Math.abs(Math.atan2(Math.sin(delta), Math.cos(delta))) > 1e-9 ? turnFraction(delta) : null;
  });

  const W = drawn[0]?.doc.width ?? 0;
  const H = drawn.reduce((s, d, i) => s + d.height + (turns[i] ? ROTATION : 0), 0);
  const column = createDoc(W, H);
  if (theme.background !== "none") column.root.children.push(el("rect", { width: W, height: H, fill: theme.background }));
  let y = 0;
  drawn.forEach(({ panel, doc, flips, caption, top, height }, i) => {
    const turn = turns[i];
    if (turn) {
      column.root.children.push(rotationSymbol([W / 2, y + ROTATION / 2], turn, ink));
      y += ROTATION;
    }
    const svg = doc.node();
    const lines = caption.map((t, i) =>
      el("text", {
        x: W / 2, y: top + i * LINE, "text-anchor": "middle",
        "font-size": CAPTION, fill: theme.ink,
      }, [], t));
    column.root.children.push(el("g", { "data-panel": panel.number, transform: `translate(0,${y})` }, [
      { ...svg, attrs: { ...svg.attrs, x: 0, y: 0 } },
      ...flips,
      el("text", { x: 24, y: 48, "font-size": 36, "font-weight": 700, fill: theme.ink }, [], panel.number),
      ...lines,
    ]));
    y += height;
  });
  return { doc: column, hints };
}
