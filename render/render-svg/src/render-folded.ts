// Folded occlusion view. Ported verbatim from tools/fold2svg.mjs:220-292
// (root defs shared with renderCP, occlusion-view branch), restructured onto
// SvgDoc layers.
import type { FoldScene } from "@beloch/scene";
import { pickStep, SceneError } from "@beloch/scene";
import { createDoc, el, SvgDoc, SvgNode } from "./svgdoc";
import { DEFAULT_THEME, edgeColor, Theme } from "./theme";
import { makeLayout } from "./layout";
import { appendConstructions, appendLegend, appendTitle } from "./constructions";
import { coveredIntervals, faceEdgeIndex, linearExtension, sideUp } from "./geometry";
import type { RenderOptions } from "./render-cp";

export interface FoldedOptions extends RenderOptions {
  view?: "top" | "bottom";     // default "top"
  hidden?: "dashed" | "hide";  // default "hide"
  step?: string;               // beloch:step label; undefined/unmatched → final state
}

export function renderFolded(scene: FoldScene, opts: FoldedOptions = {}): SvgDoc {
  const step = pickStep(scene, opts.step);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  const frame = step.frame;

  const theme: Theme = {
    ...DEFAULT_THEME, ...opts.theme,
    axioms: { ...DEFAULT_THEME.axioms, ...(opts.theme?.axioms ?? {}) },
  };
  const layout = makeLayout(frame.vertices);
  const { tx, ty } = layout;
  const doc = createDoc(layout.W, layout.H);

  // fold2svg.mjs:222-223 — background + shadow filter (shared with renderCP)
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
    const col = edgeColor(theme, assignment, prov[i]?.axiom ?? null);
    const name = prov[i]?.name;
    const edgeStep = prov[i]?.step || "";
    const wgt = assignment === "B" ? 2.5 : 2;
    const a0 = V[e[0]]!, b0 = V[e[1]]!;
    const refPos = bottom
      ? Math.min(...faces.map((fi) => pos.get(fi)!))
      : Math.max(...faces.map((fi) => pos.get(fi)!));
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
      const attrs: Record<string, string | number> = {
        class: `crease-${assignment}`,
        "data-kind": "crease",
        "data-step": edgeStep,
        x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
        stroke: col, "stroke-width": wgt, "stroke-linecap": "round",
      };
      if (name) attrs["data-name"] = name;
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
          x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
          stroke, "stroke-width": dashWgt, "stroke-dasharray": dash, "stroke-linecap": "round",
        };
        if (name) attrs["data-name"] = name;
        dashedLines.push(el("line", attrs));
      }
    }
  });

  for (const { a, b, fi } of phantom) {
    const a0 = V[a]!, b0 = V[b]!;
    const refPos = pos.get(fi)!;
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
        x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
        stroke: theme.crease, "stroke-width": 2, "stroke-linecap": "round",
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
          x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
          stroke: "#94a3b8", "stroke-width": 1.2, "stroke-dasharray": "4 3", "stroke-linecap": "round",
        }));
      }
    }
  }

  creases.children.push(...dashedLines);

  appendConstructions(doc, scene, layout, theme, opts.constructions, { frame });
  if (opts.title) appendTitle(doc, layout, theme, opts.title);
  appendLegend(doc, layout, theme, frame);
  return doc;
}
