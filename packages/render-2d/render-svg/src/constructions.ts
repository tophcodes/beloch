// Labels overlay (named points/lines), title and legend — shared by renderCP
// and renderFolded. Originally ported verbatim from tools/fold2svg.mjs:342-463;
// the auto-all/dedup behavior from that port has since been replaced by an
// explicit opt-in list (see appendConstructions below).
import type { Assignment, FoldScene, Frame, Vec2 } from "@beloch/scene";
import { el, SvgDoc, SvgNode } from "./svgdoc";
import { namedSegments, segmentsInFrame } from "./geometry";
import { PAD } from "./layout";
import type { Layout } from "./layout";
import type { HighlightColor, Theme } from "./theme";
import { besideLine, type LabelAnchor } from "./primitives/labels";

// A named line that's also a real crease highlights in that crease's own
// assignment color (bolder, dashed on top) rather than a separate hue — the
// overlay marks WHICH line, it doesn't invent a new line-type color. Pure
// constructions (never folded, no assignment) fall back to theme.construction.
function creaseColor(frame: Frame, name: string, theme: Theme): string | undefined {
  const i = frame.edgesProvenance.findIndex((p) => p?.name === name);
  return i === -1 ? undefined : theme.lineStyle(frame.edgesAssignment[i]!, theme).stroke;
}

export function appendConstructions(
  doc: SvgDoc,
  scene: FoldScene,
  layout: Layout,
  theme: Theme,
  selection: string[] | undefined,
  folded: null | { frame: Frame },
  // The palette color of each entity the caller highlights, keyed by the
  // selection entry (".p", "--l"). An entry outside it keeps the crease or
  // construction color it had.
  highlightOf: Map<string, HighlightColor> = new Map(),
  // The names the drawing writes out; absent writes them all. See
  // `SceneOptions.annotate`.
  annotate?: string[] | undefined,
): LabelAnchor[] {
  // The overlay draws the shapes and hands the names back: every label in a
  // drawing goes through one placement pass, so two of them cannot land on
  // each other (see `placeLabels`).
  const anchors: LabelAnchor[] = [];
  const labeled = (name: string): boolean =>
    annotate === undefined || annotate.includes(name);
  const annotations = doc.layer("annotations");
  const { tx, ty, minX, maxX, minY, maxY } = layout;

  // No `--labels` flag => no overlay at all. An explicit list always draws
  // exactly what's named, even a line/point also drawn elsewhere (a named
  // crease, a paper corner) — the caller asked for it, so show it.
  const sel = selection ?? [];

  for (const s of sel) {
    // A highlighted entity is drawn in its own palette color, in this view and
    // in the other view of the same scene, matching the caption's inline code.
    const hl = highlightOf.get(s);
    if (s.startsWith("--")) {
      const name = s.slice(2);
      // Where the line lies on the paper: a crease's own scars, or the paper
      // under a line bound with `=`. The folded view takes the same pieces to
      // the table face by face, so both views draw one set of paper points.
      const paper = namedSegments(scene, name);
      const drawn = folded ? segmentsInFrame(folded.frame, paper) : paper;
      if (drawn.length === 0) continue;
      const color = hl?.stroke ?? creaseColor(folded?.frame ?? scene.cp, name, theme) ?? theme.construction;
      const g: SvgNode[] = drawn.map(([[x1, y1], [x2, y2]]) => el("line", {
        x1: tx(x1), y1: ty(y1), x2: tx(x2), y2: ty(y2),
        stroke: color, "stroke-width": 3,
        "stroke-dasharray": "6 3", opacity: 0.8,
      }));
      if (labeled(`--${name}`)) {
        const [[x1, y1], [x2, y2]] = drawn[0]!;
        const a: Vec2 = [tx(x1), ty(y1)], b: Vec2 = [tx(x2), ty(y2)];
        anchors.push({
          x: (a[0] + b[0]) / 2, y: (a[1] + b[1]) / 2,
          text: `--${name}`, key: `--${name}`,
          preferOffset: besideLine(a, b, 12),
          group: `line:${name}`,
          attrs: { fill: color, "data-bel-name": name, "data-construction": name,
                   "data-kind": "line-label" },
        });
      }
      annotations.children.push(el("g", {
        class: "construction", "data-construction": name,
        "data-kind": "line", "data-name": name,
      }, g));
    } else if (s.startsWith(".")) {
      const name = s.slice(1);
      const pt = scene.namedPoints.find((p) => p.name === name);
      if (!pt) continue;
      const [px, py] = folded ? pt.table : pt.paper;
      const color = hl?.stroke ?? theme.ink;
      const ox = px < (minX + maxX) / 2 ? -14 : 10;
      const oy = py < (minY + maxY) / 2 ? 16 : -7;
      annotations.children.push(el("g", {
        class: "construction", "data-construction": name,
        "data-kind": "point", "data-name": name,
      }, [el("circle", { cx: tx(px), cy: ty(py), r: 4.5, fill: color, opacity: 0.85 })]));
      if (labeled(`.${name}`)) {
        anchors.push({
          x: tx(px), y: ty(py), text: `.${name}`, key: `.${name}`,
          preferOffset: [ox, oy],
          group: "point",
          attrs: { fill: color, "data-bel-name": name, "data-construction": name,
                   "data-kind": "point-label" },
        });
      }
    }
  }
  return anchors;
}

// fold2svg.mjs:450-453
export function appendTitle(doc: SvgDoc, theme: Theme, title: string): void {
  const hud = doc.layer("hud");
  hud.children.push(el("rect", {
    x: PAD - 10, y: 10, width: title.length * 9 + 20, height: 26, rx: 6, fill: "#f1f5f9",
  }));
  hud.children.push(el("text", {
    x: PAD, y: 28, "font-size": 16, "font-weight": 700, fill: theme.ink,
  }, [], title));
}

// fold2svg.mjs:455-463 — assignments (M/V/B/U/F) present in this diagram,
// styled the same as the creases themselves via theme.lineStyle.
const ASSIGNMENT_LABEL: Record<Assignment, string> = {
  B: "boundary", M: "mountain", V: "valley", F: "flat", J: "join", U: "unassigned",
};
const ASSIGNMENT_ORDER: Assignment[] = ["B", "M", "V", "F", "J", "U"];

export function appendLegend(doc: SvgDoc, layout: Layout, theme: Theme, frame: Frame): void {
  const seen = new Set(frame.edgesAssignment);
  const present = ASSIGNMENT_ORDER.filter((a) => seen.has(a));
  if (!present.length) return;
  const hud = doc.layer("hud");
  const { H } = layout;
  hud.children.push(el("rect", {
    class: "legend-panel", x: PAD - 12, y: H - 38, width: present.length * 110 + 4,
    height: 26, rx: 6, fill: "#f8fafc", stroke: "#e2e8f0",
  }));
  present.forEach((a, k) => {
    const lx = PAD + k * 110;
    const style = theme.lineStyle(a, theme);
    const attrs: Record<string, string | number> = {
      x1: lx, y1: H - 25, x2: lx + 22, y2: H - 25, stroke: style.stroke,
      "stroke-width": style.strokeWidth, "stroke-linecap": "round",
    };
    if (style.dasharray) attrs["stroke-dasharray"] = style.dasharray;
    hud.children.push(el("line", attrs));
    hud.children.push(el("text", {
      x: lx + 28, y: H - 20, "font-size": 13, fill: "#334155",
    }, [], ASSIGNMENT_LABEL[a]));
  });
}
