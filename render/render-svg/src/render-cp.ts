// Crease-pattern view. Ported verbatim from tools/fold2svg.mjs:220-340
// (root defs) and :293-339 (CP branch), restructured onto SvgDoc layers.
import type { FoldScene, Vec2 } from "@beloch/scene";
import { createDoc, el, SvgDoc } from "./svgdoc";
import { DEFAULT_THEME, Theme } from "./theme";
import { makeLayout } from "./layout";
import { appendConstructions, appendLegend, appendTitle } from "./constructions";

export interface RenderOptions {
  title?: string;
  constructions?: string[];             // ["--v", ".e"]; undefined = all auxiliary
  theme?: Partial<Theme>;
}

// fold2svg.mjs:217 — hardcoded unit-square corners, normalized paper space.
const CORNER: [number, number, string][] = [
  [0, 0, "a"], [1, 0, "b"], [1, 1, "c"], [0, 1, "d"],
];
const near = (p: Vec2, x: number, y: number) =>
  Math.abs(p[0] - x) < 1e-6 && Math.abs(p[1] - y) < 1e-6;
const cornerLabel = (p: Vec2): string | undefined =>
  CORNER.find(([x, y]) => near(p, x, y))?.[2];

export function renderCP(scene: FoldScene, opts: RenderOptions = {}): SvgDoc {
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const frame = scene.cp;
  const layout = makeLayout(frame.vertices);
  const { tx, ty, minX, maxX, minY, maxY } = layout;
  const doc = createDoc(layout.W, layout.H);

  // fold2svg.mjs:222-223 — background + shadow filter (shared with renderFolded)
  doc.root.children.push(el("rect", { width: layout.W, height: layout.H, fill: "white" }));
  doc.root.children.push(el("defs", {}, [
    el("filter", { id: "layerShadow", x: "-20%", y: "-20%", width: "140%", height: "140%" }, [
      el("feDropShadow", {
        dx: 0, dy: 1, stdDeviation: 1.1, "flood-color": "#0f172a", "flood-opacity": 0.18,
      }),
    ]),
  ]));

  const V = frame.vertices;
  const F = frame.facesVertices;
  const E = frame.edgesVertices;
  const A = frame.edgesAssignment;
  const prov = frame.edgesProvenance;

  // fold2svg.mjs:295-298
  const paper = doc.layer("paper");
  F.forEach((f, i) => {
    const pts = f.map((vi) => `${tx(V[vi]![0])},${ty(V[vi]![1])}`).join(" ");
    paper.children.push(el("polygon", {
      points: pts, fill: theme.paperFill, stroke: "none",
      "data-kind": "face", "data-face-index": i,
    }));
  });

  // fold2svg.mjs:299-304
  const creases = doc.layer("creases");
  E.forEach(([a, b], i) => {
    const assignment = A[i]!;
    const step = prov[i]?.step ?? "";
    const name = prov[i]?.name;
    const style = theme.lineStyle(assignment, theme);
    const attrs: Record<string, string | number> = {
      class: `crease-${assignment}`,
      "data-kind": "crease",
      "data-step": step,
      x1: tx(V[a]![0]), y1: ty(V[a]![1]),
      x2: tx(V[b]![0]), y2: ty(V[b]![1]),
      stroke: style.stroke,
      "stroke-width": style.strokeWidth,
      "stroke-linecap": "round",
    };
    if (style.dasharray) attrs["stroke-dasharray"] = style.dasharray;
    if (name) attrs["data-name"] = name;
    creases.children.push(el("line", attrs));
  });

  // fold2svg.mjs:305-312 — vertex dots + corner labels
  const annotations = doc.layer("annotations");
  V.forEach((p) => {
    annotations.children.push(el("circle", { cx: tx(p[0]), cy: ty(p[1]), r: 3, fill: theme.ink }));
    const lab = cornerLabel(p);
    if (lab) {
      const ox = p[0] < 0.5 ? -16 : 10, oy = p[1] < 0.5 ? 18 : -8;
      annotations.children.push(el("text", {
        x: tx(p[0]) + ox, y: ty(p[1]) + oy,
        "font-size": 17, "font-weight": 600, fill: theme.ink,
      }, [], `.${lab}`));
    }
  });

  // fold2svg.mjs:313-339 — crease-name labels, placed near a boundary end of
  // the named bundle (or the two farthest-apart vertices as a fallback).
  const B_EPS = 1e-6;
  const onB = (p: Vec2) =>
    Math.abs(p[0] - minX) < B_EPS || Math.abs(p[0] - maxX) < B_EPS ||
    Math.abs(p[1] - minY) < B_EPS || Math.abs(p[1] - maxY) < B_EPS;
  const creaseGroups = new Map<string, { vs: Set<number>; col: string }>();
  E.forEach(([a, b], i) => {
    const nm = prov[i]?.name;
    if (!nm) return;
    if (!creaseGroups.has(nm)) {
      creaseGroups.set(nm, { vs: new Set(), col: theme.lineStyle(A[i]!, theme).stroke });
    }
    const grp = creaseGroups.get(nm)!;
    grp.vs.add(a);
    grp.vs.add(b);
  });
  for (const [nm, { vs, col }] of creaseGroups) {
    const list = [...vs];
    let ends = list.filter((j) => onB(V[j]!));
    if (ends.length < 2) {
      let best = [list[0]!, list[0]!], bd = -1;
      for (const a of list) for (const b of list) {
        const d = (V[a]![0] - V[b]![0]) ** 2 + (V[a]![1] - V[b]![1]) ** 2;
        if (d > bd) { bd = d; best = [a, b]; }
      }
      ends = best;
    }
    const P = V[ends[0]!]!, C = V[ends[1]!]!, t = 0.18;
    const px = tx(P[0] + (C[0] - P[0]) * t), py = ty(P[1] + (C[1] - P[1]) * t);
    annotations.children.push(el("text", {
      x: px, y: py, "font-size": 13, "font-weight": 600, fill: col,
      stroke: "white", "stroke-width": 3, "paint-order": "stroke",
      "text-anchor": "middle", "dominant-baseline": "middle",
      "data-kind": "crease-label", "data-name": nm,
    }, [], `--${nm}`));
  }

  appendConstructions(doc, scene, layout, theme, opts.constructions, null);
  if (opts.title) appendTitle(doc, theme, opts.title);
  appendLegend(doc, layout, theme, frame);
  return doc;
}
