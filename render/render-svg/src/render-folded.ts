// Folded occlusion view. Ported verbatim from tools/fold2svg.mjs:220-292
// (root defs shared with renderCP, occlusion-view branch), restructured onto
// SvgDoc layers.
import type { FoldScene, Vec2 } from "@beloch/scene";
import { pickStep, SceneError } from "@beloch/scene";
import { createDoc, el, SvgDoc, SvgNode } from "./svgdoc";
import { DEFAULT_THEME, Theme } from "./theme";
import { makeLayout } from "./layout";
import { appendConstructions, appendLegend, appendTitle } from "./constructions";
import { coveredIntervals, faceEdgeIndex } from "./geometry";
import { linearExtension, sideUp } from "@beloch/scene";
import type { RenderOptions } from "./render-cp";

export interface FoldedOptions extends RenderOptions {
  view?: "top" | "bottom";     // default "top"
  hidden?: "dashed" | "hide";  // default "hide"
  step?: string;               // beloch:step label; undefined/unmatched → final state
  thickness?: number;            // layer-edge thickness in px per stacked layer; default 1.5, 0 = flat
}

export function renderFolded(scene: FoldScene, opts: FoldedOptions = {}): SvgDoc {
  const step = pickStep(scene, opts.step);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  const frame = step.frame;

  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  // Scale every folded step to the paper (cp) footprint, not the step's own
  // bbox — otherwise a quartered sheet re-fills the canvas and reads as full
  // size. The folded silhouette shares the paper's coordinate origin and is a
  // subset of it, so a quarter fold renders at half linear scale, in place.
  const layout = makeLayout(scene.cp.vertices);
  const { tx, ty } = layout;
  const doc = createDoc(layout.W, layout.H);

  const thickness = opts.thickness ?? 1.5;

  // fold2svg.mjs:222-223 — background + shadow filter (shared with renderCP)
  doc.root.children.push(el("rect", { width: layout.W, height: layout.H, fill: "white" }));
  doc.root.children.push(el("defs", {}, [
    el("filter", { id: "layerShadow", x: "-20%", y: "-20%", width: "140%", height: "140%" }, [
      el("feDropShadow", {
        dx: 0, dy: thickness > 0 ? 0 : 1, stdDeviation: 1.1, "flood-color": "#0f172a", "flood-opacity": 0.18,
      }),
    ]),
  ]));

  const V = frame.vertices;
  const F = frame.facesVertices;
  const E = frame.edgesVertices;
  const A = frame.edgesAssignment;
  const prov = frame.edgesProvenance;

  const paper = doc.layer("paper");
  const creases = doc.layer("creases");

  // fold2svg.mjs:228-234 — bottom view: look from below => reverse the stack
  // and mirror x.
  const bottom = opts.view === "bottom";
  const mx = (x: number) => (bottom ? layout.W - tx(x) : tx(x));
  // decode the true global stack: faceOrders sign is keyed to each g's normal
  const faceUp = F.map((f) => sideUp(f.map((i) => V[i]!)) === "front");
  const order = linearExtension(frame.faceOrders, F.length, faceUp);
  const paint = bottom ? [...order].reverse() : order;
  const edgeIx = faceEdgeIndex(E);

  // Layer-thickness cue (see docs/superpowers/specs/2026-07-14-layer-epsilon-spacing-design.md,
  // grounded in [hull2020, §8.1, Fig. 8.1]): a flat-folded stack's layers stay
  // registered (coincident in the plane) — thickness only shows at the exposed
  // paper EDGES, where lower layers peek out beyond the top one. So faces are NOT
  // translated; instead each silhouette edge is offset perpendicular-OUTWARD by
  // `thickness · faceDepth`, drawing the deeper layers' edges as an outward fan (a
  // ream-of-paper edge). Interior fold spines (shared by two faces) stay flat.
  // Screen-space outward-normal offset for edge `[a0,b0]` bounding single face `fi`.
  const edgeThickness = (a0: Vec2, b0: Vec2, fi: number): [number, number] => {
    if (thickness <= 0) return [0, 0];
    const A: [number, number] = [mx(a0[0]), ty(a0[1])];
    const B: [number, number] = [mx(b0[0]), ty(b0[1])];
    let ex = B[0] - A[0], ey = B[1] - A[1];
    const L = Math.hypot(ex, ey) || 1;
    ex /= L; ey /= L;
    const face = F[fi]!;
    let cx = 0, cy = 0;
    for (const vi of face) { cx += mx(V[vi]![0]); cy += ty(V[vi]![1]); }
    cx /= face.length; cy /= face.length;
    const midx = (A[0] + B[0]) / 2, midy = (A[1] + B[1]) / 2;
    let nx = -ey, ny = ex;                       // one of the two edge normals…
    if (nx * (midx - cx) + ny * (midy - cy) < 0) { nx = -nx; ny = -ny; } // …the outward one
    const d = frame.faceDepth[fi] ?? 0;
    return [nx * thickness * d, ny * thickness * d];
  };

  // fold2svg.mjs:236-243 — opaque face painting front/back. fold2svg draws
  // each face's outline edges immediately after its polygon, so a higher
  // face's opaque fill (painted later) visually erases a lower face's crease
  // line underneath it — that incidental paint-order overlap IS its
  // occlusion mechanism for solid strokes. Our SvgDoc keeps faces and creases
  // as two persistent layers (paper always under creases, for CSS toggling),
  // which would erase that overlap and leave every crease visible regardless
  // of what covers it. So outline edges are ported below as an explicit
  // per-edge interval computation (reusing the same coveredIntervals used
  // for x-ray, fold2svg.mjs:257-292) instead of a naive per-face redraw:
  // same visual result (a covered sub-segment isn't painted solid), portable
  // to the layered structure.
  for (const fi of paint) {
    const face = F[fi]!;
    const poly = face.map((i) => V[i]!);
    // the bottom view looks at each face's underside, so its side flips
    const showFront = (sideUp(poly) === "front") !== bottom;
    const fill = showFront ? theme.front : theme.back;
    // faces stay registered — thickness is drawn at the edges, not by translating fills
    const pts = face.map((i) => `${mx(V[i]![0])},${ty(V[i]![1])}`).join(" ");
    paper.children.push(el("polygon", {
      points: pts, fill, stroke: "none", filter: "url(#layerShadow)",
      "data-kind": "face", "data-face-index": fi,
    }));
  }

  // incident faces per edge: faces whose outline contains the edge. Face
  // outline segments with no matching FOLD edge (malformed/defensive
  // fallback, believed unreachable for well-formed evaluator output) are
  // occlusion-tested below against their OWNING face's stack position, same
  // as a real edge.
  const incident: number[][] = E.map(() => []);
  const phantom: { a: number; b: number; fi: number }[] = [];
  F.forEach((face, fi) => {
    for (let k = 0; k < face.length; k++) {
      const a = face[k]!, b = face[(k + 1) % face.length]!;
      const ei = edgeIx.get(a < b ? `${a}-${b}` : `${b}-${a}`);
      if (ei !== undefined) incident[ei]!.push(fi);
      else phantom.push({ a, b, fi });
    }
  });
  const pos = new Map(order.map((f, i) => [f, i]));

  // fold2svg.mjs:236-253 (outline color/width) + :254-292 (x-ray dashed): the
  // x-ray overlay is a separate pass drawn strictly after ALL solid edges
  // (fold2svg.mjs:257, after the full bottom->top face+outline paint loop) —
  // so it stays on top regardless of which face's solid outline is painted
  // last. Collect dashed segments here and flush them after both edge passes
  // below, rather than interleaving per-edge, to preserve that draw order.
  const dashedLines: SvgNode[] = [];

  E.forEach((e, i) => {
    const faces = incident[i]!;
    if (!faces.length) return; // not on any face outline — nothing to paint
    const assignment = A[i]!;
    const style = theme.lineStyle(assignment, theme);
    const name = prov[i]?.name;
    const edgeStep = prov[i]?.step || "";
    const a0 = V[e[0]]!, b0 = V[e[1]]!;
    const refPos = bottom
      ? Math.min(...faces.map((fi) => pos.get(fi)!))
      : Math.max(...faces.map((fi) => pos.get(fi)!));
    const covered = coveredIntervals(a0, b0, order, refPos, F, V, bottom);
    const lerp = (t: number): [number, number] =>
      [a0[0] + (b0[0] - a0[0]) * t, a0[1] + (b0[1] - a0[1]) * t];
    // thickness rim only on silhouette edges (one incident face); interior spines stay flat
    const [edx, edy] = faces.length === 1 ? edgeThickness(a0, b0, faces[0]!) : [0, 0];

    const visible: [number, number][] = [];
    let cursor = 0;
    for (const [c0, c1] of covered) {
      if (c0 - cursor > 1e-9) visible.push([cursor, c0]);
      cursor = Math.max(cursor, c1);
    }
    if (1 - cursor > 1e-9) visible.push([cursor, 1]);

    for (const [t0, t1] of visible) {
      const p0 = lerp(t0), p1 = lerp(t1);
      const attrs: Record<string, string | number> = {
        class: `crease-${assignment}`,
        "data-kind": "crease",
        "data-step": edgeStep,
        x1: mx(p0[0]) + edx, y1: ty(p0[1]) + edy, x2: mx(p1[0]) + edx, y2: ty(p1[1]) + edy,
        stroke: style.stroke, "stroke-width": style.strokeWidth, "stroke-linecap": "round",
      };
      if (style.dasharray) attrs["stroke-dasharray"] = style.dasharray;
      if (name) attrs["data-name"] = name;
      if (name) attrs["data-bel-name"] = name;
      creases.children.push(el("line", attrs));
    }

    if (opts.hidden === "dashed") {
      // paper edge reads darker + thicker + longer dashes than a crease
      const isB = assignment === "B";
      const stroke = isB ? "#475569" : "#94a3b8";
      const dashWgt = isB ? 2 : 1.2;
      const dash = isB ? "6 3" : "4 3";
      for (const [t0, t1] of covered) {
        const p0 = lerp(t0), p1 = lerp(t1);
        const attrs: Record<string, string | number> = {
          class: `crease-${assignment}`,
          "data-kind": "crease",
          "data-step": edgeStep,
          "data-occluded": "true",
          x1: mx(p0[0]) + edx, y1: ty(p0[1]) + edy, x2: mx(p1[0]) + edx, y2: ty(p1[1]) + edy,
          stroke, "stroke-width": dashWgt, "stroke-dasharray": dash, "stroke-linecap": "round",
        };
        if (name) attrs["data-name"] = name;
        if (name) attrs["data-bel-name"] = name;
        dashedLines.push(el("line", attrs));
      }
    }
  });

  for (const { a, b, fi } of phantom) {
    const a0 = V[a]!, b0 = V[b]!;
    const refPos = pos.get(fi)!;
    const [pdx, pdy] = edgeThickness(a0, b0, fi);
    const covered = coveredIntervals(a0, b0, order, refPos, F, V, bottom);
    const lerp = (t: number): [number, number] =>
      [a0[0] + (b0[0] - a0[0]) * t, a0[1] + (b0[1] - a0[1]) * t];

    const visible: [number, number][] = [];
    let cursor = 0;
    for (const [c0, c1] of covered) {
      if (c0 - cursor > 1e-9) visible.push([cursor, c0]);
      cursor = Math.max(cursor, c1);
    }
    if (1 - cursor > 1e-9) visible.push([cursor, 1]);

    for (const [t0, t1] of visible) {
      const p0 = lerp(t0), p1 = lerp(t1);
      creases.children.push(el("line", {
        class: "crease-U",
        "data-kind": "crease",
        "data-step": "",
        x1: mx(p0[0]) + pdx, y1: ty(p0[1]) + pdy, x2: mx(p1[0]) + pdx, y2: ty(p1[1]) + pdy,
        stroke: theme.unassigned, "stroke-width": 2, "stroke-linecap": "round",
      }));
    }

    if (opts.hidden === "dashed") {
      for (const [t0, t1] of covered) {
        const p0 = lerp(t0), p1 = lerp(t1);
        dashedLines.push(el("line", {
          class: "crease-U",
          "data-kind": "crease",
          "data-step": "",
          "data-occluded": "true",
          x1: mx(p0[0]) + pdx, y1: ty(p0[1]) + pdy, x2: mx(p1[0]) + pdx, y2: ty(p1[1]) + pdy,
          stroke: "#94a3b8", "stroke-width": 1.2, "stroke-dasharray": "4 3", "stroke-linecap": "round",
        }));
      }
    }
  }

  creases.children.push(...dashedLines);

  // named-vertex dots + labels (hover/selection targets in the folded view)
  const annotations = doc.layer("annotations");
  const fverts = frame.vertices;
  const centreX = (layout.minX + layout.maxX) / 2;
  const centreY = (layout.minY + layout.maxY) / 2;
  frame.verticesNames.forEach((nm, i) => {
    if (!nm) return;
    const p = fverts[i]!;
    annotations.children.push(
      el("circle", {
        cx: mx(p[0]), cy: ty(p[1]), r: 3, fill: theme.ink,
        "data-bel-name": nm, "data-kind": "point",
      }),
    );
    const ox = p[0] < centreX ? -16 : 10, oy = p[1] < centreY ? 18 : -8;
    annotations.children.push(
      el("text", {
        x: mx(p[0]) + ox, y: ty(p[1]) + oy,
        "font-size": 17, "font-weight": 600, fill: theme.ink,
        "data-bel-name": nm, "data-kind": "point-label",
      }, [], `.${nm}`),
    );
  });

  appendConstructions(doc, scene, layout, theme, opts.labels, { frame });
  if (opts.title) appendTitle(doc, theme, opts.title);
  if (opts.legend) appendLegend(doc, layout, theme, frame);
  return doc;
}
