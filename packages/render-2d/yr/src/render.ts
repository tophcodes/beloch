// The default YR output: every panel of the program in one column, each the
// state it draws turned by the `@orient` in force, with the lines and arrows
// of its writes, its number above and its instruction below.
import type { Assignment, FoldScene, Statement, Vec2 } from "@beloch/scene";
import { orientationAt, SceneError } from "@beloch/scene";
import {
  createDoc, DEFAULT_THEME, el, makeLayout, renderFolded, segmentsInFrame, turnFrame,
} from "@beloch/render-svg";
import type { Layout, LineStyle, SvgDoc, SvgNode, Theme } from "@beloch/render-svg";
import { existingCrease, foldAndUnfoldArrow, valleyArrow, valleyLine } from "./draw";
import type { Ink } from "./draw";
import { foldMotion } from "./motion";
import { panels } from "./panels";
import type { Panel } from "./panels";

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

// The paper in a panel: its outline and the edges of its folded layers in
// ink, existing creases thin, join edges not at all.
const panelLineStyle = (assignment: Assignment, theme: Theme): LineStyle => {
  switch (assignment) {
    case "B": case "M": case "V": return { stroke: theme.ink, strokeWidth: 2.2 };
    case "J": return { stroke: theme.ink, strokeWidth: 0, opacity: 0 };
    default: return { stroke: theme.ink, strokeWidth: 1, opacity: 0.55 };
  }
};

const mid = (segs: [Vec2, Vec2][]): Vec2 | null => {
  if (segs.length === 0) return null;
  const pts = segs.flat();
  return [pts.reduce((s, p) => s + p[0], 0) / pts.length, pts.reduce((s, p) => s + p[1], 0) / pts.length];
};

// A mark's fold-and-unfold arrow: from the corner of the paper farthest from
// the crease on the panel's left side, to its mirror image across the crease.
function markArrow(outline: Vec2[], [a, b]: [Vec2, Vec2]): [Vec2, Vec2] {
  const dx = b[0] - a[0], dy = b[1] - a[1], L = Math.hypot(dx, dy);
  const side = (p: Vec2) => (dx * (p[1] - a[1]) - dy * (p[0] - a[0])) / L;
  const farthest = (sign: number) =>
    outline.filter((p) => sign * side(p) > 1e-6).sort((p, q) => sign * side(q) - sign * side(p))[0];
  const left = [farthest(1), farthest(-1)].filter((p): p is Vec2 => p !== undefined)
    .sort((p, q) => (Math.abs(p[0] - q[0]) > 1 ? p[0] - q[0] : p[1] - q[1]))[0];
  if (!left) throw new SceneError("a mark with no paper beside it");
  const d = side(left);
  return [left, [left[0] + (2 * d * dy) / L, left[1] - (2 * d * dx) / L]];
}

function overlays(scene: FoldScene, panel: Panel, view: PanelView, ink: Ink): SvgNode[] {
  const out: SvgNode[] = [];
  const toPx = (segs: [Vec2, Vec2][]) => segs.map(([p, q]): [Vec2, Vec2] => [view.px(p), view.px(q)]);
  const base = scene.steps[panel.base]!.frame;

  // the scored lines that stand in the panel's state and are no edge of it
  const first = panel.writes[0]?.index ?? scene.statements.length;
  const standing: Statement | undefined = scene.statements[first - 1];
  for (const m of standing?.keptMarks ?? []) {
    if (m.kind !== "seg") continue;
    for (const s of toPx(segmentsInFrame(base, [[m.a, m.b]]))) out.push(existingCrease(s, ink));
  }

  for (const w of panel.writes) {
    if (w.kind === "fold") {
      const motion = foldMotion(scene, w);
      const hinge = toPx(motion.hinge);
      for (const s of hinge) out.push(valleyLine(s, w.index, ink));
      out.push(valleyArrow(view.px(motion.tail), view.px(motion.head), mid(hinge), ink));
    } else if (w.mark?.kind === "seg") {
      const frame = scene.steps[w.frameIndex]!.frame;
      const segs = toPx(segmentsInFrame(frame, [[w.mark.a, w.mark.b]]));
      for (const s of segs) out.push(valleyLine(s, w.index, ink));
      const outline = frame.vertices.map(view.px);
      const [tail, tip] = markArrow(outline, segs[0]!);
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

const CAPTION = 22, LINE = 28, WRAP = 44;

export function renderYr(scene: FoldScene, opts: YrOptions = {}): { doc: SvgDoc; hints: string[] } {
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const ink: Ink = { ink: theme.ink, paper: theme.front };
  const { panels: list, hints } = panels(scene);

  // one scale for every panel, so that a fold shows the model getting smaller
  const half = Math.max(...list.map((p) => turned(scene, p).half));
  const drawn = list.map((panel) => {
    const view = panelView(scene, panel, half);
    const doc = renderFolded(scene, {
      step: String(panel.base), orient: true, layout: view.layout,
      annotate: [], dots: "annotated", hidden: "hide",
      theme: { ...opts.theme, lineStyle: panelLineStyle, background: "none" },
    });
    doc.layer("annotations").children.push(...overlays(scene, panel, view, ink));
    const caption = panel.text === null ? [] : wrap(panel.text, WRAP);
    return { panel, doc, caption, height: view.layout.H + caption.length * LINE + 16 };
  });

  const W = drawn[0]?.doc.width ?? 0;
  const H = drawn.reduce((s, d) => s + d.height, 0);
  const column = createDoc(W, H);
  if (theme.background !== "none") column.root.children.push(el("rect", { width: W, height: H, fill: theme.background }));
  let y = 0;
  for (const { panel, doc, caption, height } of drawn) {
    const svg = doc.node();
    const lines = caption.map((t, i) =>
      el("text", {
        x: W / 2, y: doc.height + i * LINE, "text-anchor": "middle",
        "font-size": CAPTION, fill: theme.ink,
      }, [], t));
    column.root.children.push(el("g", { "data-panel": panel.number, transform: `translate(0,${y})` }, [
      { ...svg, attrs: { ...svg.attrs, x: 0, y: 0 } },
      el("text", { x: 24, y: 48, "font-size": 36, "font-weight": 700, fill: theme.ink }, [], panel.number),
      ...lines,
    ]));
    y += height;
  }
  return { doc: column, hints };
}
