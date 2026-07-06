// Labels overlay (named points/lines), title and legend — shared by renderCP
// and renderFolded. Originally ported verbatim from tools/fold2svg.mjs:342-463;
// the auto-all/dedup behavior from that port has since been replaced by an
// explicit opt-in list (see appendConstructions below).
import type { Assignment, FoldScene, Frame, Vec2 } from "@beloch/scene";
import { el, SvgDoc, SvgNode } from "./svgdoc";
import { clipLineBox, clipLineToPoly, lineToFace } from "./geometry";
import { PAD } from "./layout";
import type { Layout } from "./layout";
import type { Theme } from "./theme";

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
): void {
  const annotations = doc.layer("annotations");
  const { tx, ty, minX, maxX, minY, maxY } = layout;

  // No `--labels` flag => no overlay at all. An explicit list always draws
  // exactly what's named, even a line/point also drawn elsewhere (a named
  // crease, a paper corner) — the caller asked for it, so show it.
  const sel = selection ?? [];

  // fold2svg.mjs:366-370 — the box-clip for the CP-mode line construction
  // always uses the root/CP vertex bbox, regardless of view.
  const rootV = scene.cp.vertices;
  const pxs = rootV.map((p) => p[0]), pys = rootV.map((p) => p[1]);
  const pMinX = Math.min(...pxs), pMaxX = Math.max(...pxs);
  const pMinY = Math.min(...pys), pMaxY = Math.max(...pys);

  for (const s of sel) {
    if (s.startsWith("--")) {
      const name = s.slice(2);
      const line = scene.namedLines.find((l) => l.name === name);
      if (!line) continue;
      const [la, lb, lc] = line.coeffs;
      const g: SvgNode[] = [];
      if (folded) {
        const color = creaseColor(folded.frame, name, theme) ?? theme.construction;
        const F = folded.frame.facesVertices;
        const V = folded.frame.vertices;
        const FM = folded.frame.facesMatrix ?? [];
        const drawn: [Vec2, Vec2][] = [];
        for (let fi = 0; fi < F.length; fi++) {
          const M = FM[fi];
          if (!M) continue;
          const tabPoly = F[fi]!.map((vi) => V[vi]!);
          const [ta, tb, tc] = lineToFace(M, la, lb, lc);
          const seg = clipLineToPoly(ta, tb, tc, tabPoly);
          if (!seg) continue;
          const [t1, t2] = seg;
          g.push(el("line", {
            x1: tx(t1[0]), y1: ty(t1[1]), x2: tx(t2[0]), y2: ty(t2[1]),
            stroke: color, "stroke-width": 3,
            "stroke-dasharray": "6 3", opacity: 0.8,
          }));
          drawn.push([t1, t2]);
        }
        if (drawn.length > 0) {
          const [[x1, y1], [x2, y2]] = drawn[0]!;
          g.push(el("text", {
            x: tx((x1 + x2) / 2), y: ty((y1 + y2) / 2) - 6,
            "font-size": 12, "font-weight": 600, fill: color,
            stroke: "white", "stroke-width": 2.5, "paint-order": "stroke",
            "text-anchor": "middle",
          }, [], `--${name}`));
        }
      } else {
        const color = creaseColor(scene.cp, name, theme) ?? theme.construction;
        const seg = clipLineBox(la, lb, lc, pMinX, pMaxX, pMinY, pMaxY);
        if (!seg) continue;
        const [[x1, y1], [x2, y2]] = seg;
        g.push(el("line", {
          x1: tx(x1), y1: ty(y1), x2: tx(x2), y2: ty(y2),
          stroke: color, "stroke-width": 3,
          "stroke-dasharray": "6 3", opacity: 0.8,
        }));
        g.push(el("text", {
          x: tx((x1 + x2) / 2), y: ty((y1 + y2) / 2) - 6,
          "font-size": 12, "font-weight": 600, fill: color,
          stroke: "white", "stroke-width": 2.5, "paint-order": "stroke",
          "text-anchor": "middle",
        }, [], `--${name}`));
      }
      if (g.length) {
        annotations.children.push(el("g", {
          class: "construction", "data-construction": name,
          "data-kind": "line", "data-name": name,
        }, g));
      }
    } else if (s.startsWith(".")) {
      const name = s.slice(1);
      const pt = scene.namedPoints.find((p) => p.name === name);
      if (!pt) continue;
      const [px, py] = folded ? pt.table : pt.paper;
      const ox = px < (minX + maxX) / 2 ? -14 : 10;
      const oy = py < (minY + maxY) / 2 ? 16 : -7;
      annotations.children.push(el("g", {
        class: "construction", "data-construction": name,
        "data-kind": "point", "data-name": name,
      }, [
        el("circle", { cx: tx(px), cy: ty(py), r: 4.5, fill: theme.ink, opacity: 0.85 }),
        el("text", {
          x: tx(px) + ox, y: ty(py) + oy,
          "font-size": 13, "font-weight": 600, fill: theme.ink,
          stroke: "white", "stroke-width": 2.5, "paint-order": "stroke",
        }, [], `.${name}`),
      ]));
    }
  }
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
  B: "boundary", M: "mountain", V: "valley", F: "flat", U: "unassigned",
};
const ASSIGNMENT_ORDER: Assignment[] = ["B", "M", "V", "F", "U"];

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
