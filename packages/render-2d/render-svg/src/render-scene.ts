// Unified renderer. Geometry (isometry) and decorations (texture) are chosen
// independently; renderCP and renderFolded are thin presets over this. The two
// legacy draw paths are merged here verbatim under an `occlude` branch (flat CP
// sheet vs folded step), so the presets stay byte-identical — the composition
// knobs (texture.upToStep filtering, ghosted future creases) are strictly
// additive and dormant for the presets.
// Spec: docs/superpowers/specs/2026-07-14-render-scene-unified-design.md
import type { FoldScene, Mark, Vec2, Isometry as FaceMatrix } from "@beloch/scene";
import { createDoc, el, SvgDoc, SvgNode } from "./svgdoc";
import { DEFAULT_THEME, Theme, LineStyle } from "./theme";
import { makeLayout } from "./layout";
import { appendConstructions, appendLegend, appendTitle } from "./constructions";
import { coveredIntervals, faceEdgeIndex, sideUp, lineToFace, clipLineToPoly, pointCovered, pointInPolygonInclusive, segInsideIntervals, paperClippedIntervals } from "./geometry";
import { resolveIsometry, type Isometry } from "./isometry";
import { placeLabels, type LabelAnchor } from "./primitives/labels";

export interface TextureOptions {
  upToStep: number | "all"; // filter features by creation step ≤ this (flat/ghost)
  creases: boolean;
  marks: boolean; // paper-space record marks (CP frame only)
  points: boolean; // named-point construction dots (overlay, via `labels`)
  lines: boolean; // named-line construction overlay (via `labels`)
  faces: "none" | "outline" | "filled";
}

export interface MarkOverlay {
  marks: Mark[];
  newestCreaseId?: number; // Mark.creaseId of the most recently added mark — drawn with an accent style
}

export interface SceneOptions {
  isometry: Isometry;
  texture: TextureOptions;
  title?: string;
  labels?: string[]; // construction overlay selection: ["--v", ".p"]
  legend?: boolean;
  theme?: Partial<Theme>;
  view?: "top" | "bottom"; // folded only
  hidden?: "dashed" | "hide"; // folded only
  markOverlay?: MarkOverlay; // folded only — project these marks onto the step's faces
}

// fold2svg.mjs:217 — hardcoded unit-square corners, normalized paper space.
const CORNER: [number, number, string][] = [
  [0, 0, "a"], [1, 0, "b"], [1, 1, "c"], [0, 1, "d"],
];
const near = (p: Vec2, x: number, y: number) =>
  Math.abs(p[0] - x) < 1e-6 && Math.abs(p[1] - y) < 1e-6;
const cornerLabel = (p: Vec2): string | undefined =>
  CORNER.find(([x, y]) => near(p, x, y))?.[2];

export function renderScene(scene: FoldScene, opts: SceneOptions): SvgDoc {
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  // Always scale to the paper (cp) footprint so folded subsets render in place
  // at true relative size, sharing the flat sheet's coordinate origin.
  const layout = makeLayout(scene.cp.vertices);
  const { tx, ty, minX, maxX, minY, maxY } = layout;
  const doc = createDoc(layout.W, layout.H);

  // fold2svg.mjs:222-223 — background + shadow filter (shared by both views)
  doc.root.children.push(el("rect", { width: layout.W, height: layout.H, fill: theme.background }));
  doc.root.children.push(el("defs", {}, [
    el("filter", { id: "layerShadow", x: "-20%", y: "-20%", width: "140%", height: "140%" }, [
      el("feDropShadow", {
        dx: 0, dy: 1, stdDeviation: 1.1, "flood-color": "#0f172a", "flood-opacity": 0.18,
      }),
    ]),
  ]));

  const { frame, order, occlude } = resolveIsometry(scene, opts.isometry);
  const upTo = opts.texture.upToStep;

  const V = frame.vertices;
  const F = frame.facesVertices;
  const E = frame.edgesVertices;
  const A = frame.edgesAssignment;
  const prov = frame.edgesProvenance;

  // Numeric creation step of a crease edge, for texture.upToStep filtering on
  // the flat sheet (progressive CP). Boundary edges are the sheet itself → step
  // 0 (always shown). A named crease inherits its named-line's numeric step
  // (Slice A); anything unnamed defaults to 0 (present from the start).
  const creaseStepOf = (i: number): number => {
    if (A[i] === "B") return 0;
    const nm = prov[i]?.name;
    if (nm) {
      const nl = scene.namedLines.find((l) => l.name === nm);
      if (nl) return nl.step;
    }
    return 0;
  };
  const showCrease = (i: number): boolean =>
    typeof upTo !== "number" || creaseStepOf(i) <= upTo;

  const paper = doc.layer("paper");
  const creases = doc.layer("creases");
  const annotations = doc.layer("annotations");

  if (occlude) {
    // ===== folded step geometry (ported from renderFolded) =====
    const bottom = opts.view === "bottom";
    const mx = (x: number) => (bottom ? layout.W - tx(x) : tx(x));
    const paint = bottom ? [...order].reverse() : order;
    const edgeIx = faceEdgeIndex(E);

    if (opts.texture.faces === "filled") {
      for (const fi of paint) {
        const face = F[fi]!;
        const poly = face.map((idx) => V[idx]!);
        const showFront = (sideUp(poly) === "front") !== bottom;
        const fill = showFront ? theme.front : theme.back;
        const pts = face.map((idx) => `${mx(V[idx]![0])},${ty(V[idx]![1])}`).join(" ");
        paper.children.push(el("polygon", {
          points: pts, fill, stroke: "none", filter: "url(#layerShadow)",
          "data-kind": "face", "data-face-index": fi,
        }));
      }
    }

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
    const dashedLines: SvgNode[] = [];

    // A crease that has been folded stacks its two faces onto the SAME side of
    // the crease line, so in projection the crease sits on the silhouette of the
    // folded figure — physically a paper edge, and drawn solid black like one. A
    // crease still lying flat keeps its faces on OPPOSITE sides (paper continues
    // past it) and stays an on-paper crease, drawn dashed. Naked edges (<2 faces)
    // are boundaries by definition.
    const centroid = (fi: number): [number, number] => {
      const vs = F[fi]!;
      let sx = 0, sy = 0;
      for (const vi of vs) { sx += V[vi]![0]; sy += V[vi]![1]; }
      return [sx / vs.length, sy / vs.length];
    };
    const sideOf = (a0: number[], b0: number[], p: number[]): number =>
      (b0[0] - a0[0]) * (p[1] - a0[1]) - (b0[1] - a0[1]) * (p[0] - a0[0]);
    const onSilhouette = (a0: number[], b0: number[], faces: number[]): boolean => {
      if (faces.length < 2) return true;
      let pos = false, neg = false;
      for (const fi of faces) {
        const s = sideOf(a0, b0, centroid(fi));
        if (s > 1e-9) pos = true;
        else if (s < -1e-9) neg = true;
      }
      return !(pos && neg); // faces all on one side → boundary of the silhouette
    };

    const segCounter = new Map<number, number>();
    if (opts.texture.creases) {
      E.forEach((e, i) => {
        const faces = incident[i]!;
        if (!faces.length) return;
        const assignment = A[i]!;
        const name = prov[i]?.name;
        const cid = prov[i]?.creaseId ?? null;
        const a0 = V[e[0]]!, b0 = V[e[1]]!;
        // Paper edges keep their bold solid style; other silhouette edges (folded
        // creases now on the outline) also go solid black, just a touch lighter;
        // only genuine on-paper creases keep the dashed assignment style.
        const style: LineStyle =
          assignment === "B"
            ? theme.lineStyle("B", theme)
            : onSilhouette(a0, b0, faces)
              ? { stroke: theme.boundary, strokeWidth: 2 }
              : theme.lineStyle(assignment, theme);
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
            x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
            stroke: style.stroke, "stroke-width": style.strokeWidth, "stroke-linecap": "round",
          };
          if (style.dasharray) attrs["stroke-dasharray"] = style.dasharray;
          if (style.opacity !== undefined) attrs["opacity"] = style.opacity;
          if (name) attrs["data-name"] = name;
          if (name) attrs["data-bel-name"] = name;
          if (cid !== null) {
            const seg = segCounter.get(cid) ?? 0;
            segCounter.set(cid, seg + 1);
            attrs["data-crease-id"] = cid;
            attrs["data-seg"] = seg;
          }
          creases.children.push(el("line", attrs));
        }

        if (opts.hidden === "dashed") {
          const isB = assignment === "B";
          const stroke = isB ? "#475569" : "#94a3b8";
          const dashWgt = isB ? 2 : 1.2;
          const dash = isB ? "6 3" : "4 3";
          for (const [t0, t1] of covered) {
            const p0 = lerp(t0), p1 = lerp(t1);
            const attrs: Record<string, string | number> = {
              class: `crease-${assignment}`,
              "data-kind": "crease",
              "data-occluded": "true",
              x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
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
            x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
            stroke: theme.unassigned, "stroke-width": 2, "stroke-linecap": "round",
          }));
        }

        if (opts.hidden === "dashed") {
          for (const [t0, t1] of covered) {
            const p0 = lerp(t0), p1 = lerp(t1);
            dashedLines.push(el("line", {
              class: "crease-U",
              "data-kind": "crease",
              "data-occluded": "true",
              x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
              stroke: "#94a3b8", "stroke-width": 1.2, "stroke-dasharray": "4 3", "stroke-linecap": "round",
            }));
          }
        }
      }

      creases.children.push(...dashedLines);
    }

    // Ghost overlay: future creases (named lines with step in (isometry, upTo])
    // projected onto the current folded faces as translucent dashed hints.
    if (opts.isometry.kind === "step" && typeof upTo === "number" && upTo > opts.isometry.index) {
      const FM = frame.facesMatrix ?? [];
      for (const nl of scene.namedLines) {
        if (nl.step <= opts.isometry.index || nl.step > upTo) continue;
        const [la, lb, lc] = nl.coeffs;
        for (let fi = 0; fi < F.length; fi++) {
          const M = FM[fi];
          if (!M) continue;
          const tabPoly = F[fi]!.map((idx) => V[idx]!);
          const [ta, tb, tc] = lineToFace(M, la, lb, lc);
          const seg = clipLineToPoly(ta, tb, tc, tabPoly);
          if (!seg) continue;
          const [t1, t2] = seg;
          creases.children.push(el("line", {
            class: "ghost", "data-kind": "ghost", "data-name": nl.name,
            x1: mx(t1[0]), y1: ty(t1[1]), x2: mx(t2[0]), y2: ty(t2[1]),
            stroke: theme.construction, "stroke-width": 1.5,
            "stroke-dasharray": "3 4", opacity: 0.55,
          }));
        }
      }
    }

    // named-vertex dots + decluttered labels. Occluded like creases: a dot
    // sitting under a higher face is greyed + flagged under hidden="dashed",
    // and dropped entirely (dot + label) under "hide".
    const fverts = frame.vertices;
    const centreX = (minX + maxX) / 2;
    const centreY = (minY + maxY) / 2;
    const vertexFaces: number[][] = fverts.map(() => []);
    F.forEach((face, fi) => face.forEach((vi) => vertexFaces[vi]!.push(fi)));
    const occludedPt = (i: number): boolean => {
      const faces = vertexFaces[i]!;
      if (!faces.length) return false;
      const ps = faces.map((fi) => pos.get(fi)!);
      const refPos = bottom ? Math.min(...ps) : Math.max(...ps);
      return pointCovered(fverts[i]!, order, refPos, F, V, bottom);
    };
    const MUTED = "#94a3b8"; // matches occluded (non-boundary) crease grey
    const occludedNames = new Set<string>();
    const labelAnchors: LabelAnchor[] = [];
    frame.verticesNames.forEach((nm, i) => {
      if (!nm) return;
      const p = fverts[i]!;
      const buried = occludedPt(i);
      if (buried && opts.hidden !== "dashed") return; // "hide": drop dot + label
      if (buried) occludedNames.add(nm);
      const circle: Record<string, string | number> = {
        cx: mx(p[0]), cy: ty(p[1]), r: 3, fill: buried ? MUTED : theme.ink,
        "data-bel-name": nm, "data-kind": "point", "data-vertex": i,
      };
      if (buried) circle["data-occluded"] = "true";
      annotations.children.push(el("circle", circle));
      const ox = p[0] < centreX ? -16 : 10, oy = p[1] < centreY ? 18 : -8;
      labelAnchors.push({
        x: mx(p[0]), y: ty(p[1]), text: `.${nm}`, key: nm, preferOffset: [ox, oy],
      });
    });
    for (const lab of placeLabels(labelAnchors, { fontSize: 17 })) {
      const buried = occludedNames.has(lab.keys[0]!);
      const attrs: Record<string, string | number> = {
        x: lab.x, y: lab.y, "font-size": 17, "font-weight": 600,
        fill: buried ? MUTED : theme.ink,
        "data-bel-name": lab.keys[0]!, "data-kind": "point-label",
      };
      if (buried) attrs["data-occluded"] = "true";
      if (lab.anchor !== "start") attrs["text-anchor"] = lab.anchor;
      annotations.children.push(el("text", attrs, [], lab.text));
    }

    // Mark overlay: project one mark's paper-space geometry onto the folded
    // faces via each face's own isometry — same paper->table technique as
    // the ghost-overlay above. A `seg` mark is clipped per face (like the
    // ghost overlay clips a named line) rather than required to fit
    // entirely inside one face: a mark created before any actual fold
    // routinely spans several still-flat, still-coplanar sub-faces (creases
    // already subdivide the topology for rendering before anything has
    // folded in 3D), so "whole segment in exactly one face" rejects the
    // common case. A `point` mark has no span to clip, so it still just
    // picks the one face it lands in.
    if (opts.markOverlay) {
      const FM = frame.facesMatrix ?? [];
      const applyIso = ([m00, m01, m10, m11, ox, oy]: FaceMatrix, p: Vec2): Vec2 =>
        [m00 * p[0] + m01 * p[1] + ox, m10 * p[0] + m11 * p[1] + oy];
      for (const m of opts.markOverlay.marks) {
        const isNewest = m.creaseId === opts.markOverlay.newestCreaseId;
        const style = theme.lineStyle(m.intent, theme);
        const markAttrs = {
          stroke: isNewest ? theme.construction : style.stroke,
          "stroke-width": isNewest ? style.strokeWidth + 1 : Math.max(1, style.strokeWidth - 1),
          "stroke-dasharray": "2 2",
          "stroke-linecap": "round" as const,
          opacity: isNewest ? 1 : 0.7,
          "data-crease-id": m.creaseId,
        };
        if (m.kind === "seg") {
          for (let fi = 0; fi < F.length; fi++) {
            const M = FM[fi];
            if (!M) continue;
            const tabPoly = F[fi]!.map((idx) => V[idx]!);
            const pa = applyIso(M, m.a), pb = applyIso(M, m.b);
            for (const [t0, t1] of segInsideIntervals(pa, pb, tabPoly)) {
              const p0: Vec2 = [pa[0] + (pb[0] - pa[0]) * t0, pa[1] + (pb[1] - pa[1]) * t0];
              const p1: Vec2 = [pa[0] + (pb[0] - pa[0]) * t1, pa[1] + (pb[1] - pa[1]) * t1];
              creases.children.push(el("line", {
                ...markAttrs, class: "mark", "data-kind": "mark",
                x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
              }));
            }
          }
        } else {
          for (let fi = 0; fi < F.length; fi++) {
            const M = FM[fi];
            if (!M) continue;
            const tabPoly = F[fi]!.map((idx) => V[idx]!);
            const pp = applyIso(M, m.p);
            if (!pointInPolygonInclusive(pp, tabPoly)) continue;
            const TICK = 0.06;
            const [la, lb] = m.line;
            const norm = Math.hypot(lb, -la) || 1;
            const dx = lb / norm, dy = -la / norm;
            const p0 = applyIso(M, [m.p[0] - dx * TICK, m.p[1] - dy * TICK]);
            const p1 = applyIso(M, [m.p[0] + dx * TICK, m.p[1] + dy * TICK]);
            for (const [t0, t1] of segInsideIntervals(p0, p1, tabPoly)) {
              const c0: Vec2 = [p0[0] + (p1[0] - p0[0]) * t0, p0[1] + (p1[1] - p0[1]) * t0];
              const c1: Vec2 = [p0[0] + (p1[0] - p0[0]) * t1, p0[1] + (p1[1] - p0[1]) * t1];
              creases.children.push(el("line", {
                ...markAttrs, class: "mark", "data-kind": "mark-tick",
                x1: mx(c0[0]), y1: ty(c0[1]), x2: mx(c1[0]), y2: ty(c1[1]),
              }));
            }
            break; // a point belongs to exactly one face
          }
        }
      }
    }

    appendConstructions(doc, scene, layout, theme, opts.labels, { frame });
  } else {
    // ===== flat crease-pattern geometry (ported from renderCP) =====
    if (opts.texture.faces !== "none") {
      F.forEach((f, i) => {
        const pts = f.map((vi) => `${tx(V[vi]![0])},${ty(V[vi]![1])}`).join(" ");
        paper.children.push(el("polygon", {
          points: pts, fill: theme.paperFill, stroke: "none",
          "data-kind": "face", "data-face-index": i,
        }));
      });
    }

    if (opts.texture.creases) {
      const segCounter = new Map<number, number>();
      E.forEach(([a, b], i) => {
        if (!showCrease(i)) return;
        const assignment = A[i]!;
        const name = prov[i]?.name;
        const cid = prov[i]?.creaseId ?? null;
        const style = theme.lineStyle(assignment, theme);
        const attrs: Record<string, string | number> = {
          class: `crease-${assignment}`,
          "data-kind": "crease",
          x1: tx(V[a]![0]), y1: ty(V[a]![1]),
          x2: tx(V[b]![0]), y2: ty(V[b]![1]),
          stroke: style.stroke,
          "stroke-width": style.strokeWidth,
          "stroke-linecap": "round",
        };
        if (style.dasharray) attrs["stroke-dasharray"] = style.dasharray;
        if (style.opacity !== undefined) attrs["opacity"] = style.opacity;
        if (name) attrs["data-name"] = name;
        if (name) attrs["data-bel-name"] = name;
        if (cid !== null) {
          const seg = segCounter.get(cid) ?? 0;
          segCounter.set(cid, seg + 1);
          attrs["data-crease-id"] = cid;
          attrs["data-seg"] = seg;
        }
        creases.children.push(el("line", attrs));
      });
    }

    if (opts.texture.marks) {
      const MARK_TICK_LEN = 0.06;
      scene.marks.forEach((m) => {
        const lineStyle = theme.lineStyle(m.intent, theme);
        const attrs: Record<string, string | number> = {
          class: "mark",
          "data-crease-id": m.creaseId,
          stroke: lineStyle.stroke,
          "stroke-width": Math.max(1, lineStyle.strokeWidth - 1),
          "stroke-dasharray": "2 2",
          "stroke-linecap": "round",
          opacity: 0.7,
        };
        if (m.kind === "seg") {
          creases.children.push(el("line", {
            ...attrs, "data-kind": "mark",
            x1: tx(m.a[0]), y1: ty(m.a[1]), x2: tx(m.b[0]), y2: ty(m.b[1]),
          }));
        } else {
          const [la, lb] = m.line;
          const norm = Math.hypot(lb, -la) || 1;
          const dx = lb / norm, dy = -la / norm;
          const p0: Vec2 = [m.p[0] - dx * MARK_TICK_LEN, m.p[1] - dy * MARK_TICK_LEN];
          const p1: Vec2 = [m.p[0] + dx * MARK_TICK_LEN, m.p[1] + dy * MARK_TICK_LEN];
          for (const [t0, t1] of paperClippedIntervals(p0, p1, F, V)) {
            const c0: Vec2 = [p0[0] + (p1[0] - p0[0]) * t0, p0[1] + (p1[1] - p0[1]) * t0];
            const c1: Vec2 = [p0[0] + (p1[0] - p0[0]) * t1, p0[1] + (p1[1] - p0[1]) * t1];
            creases.children.push(el("line", {
              ...attrs, "data-kind": "mark-tick",
              x1: tx(c0[0]), y1: ty(c0[1]), x2: tx(c1[0]), y2: ty(c1[1]),
            }));
          }
        }
      });
    }

    // vertex dots + corner labels
    V.forEach((p, i) => {
      const nm = scene.cp.verticesNames[i];
      const circleAttrs: Record<string, string | number> = {
        cx: tx(p[0]), cy: ty(p[1]), r: 3, fill: theme.ink, "data-vertex": i,
      };
      if (nm) { circleAttrs["data-bel-name"] = nm; circleAttrs["data-kind"] = "point"; }
      annotations.children.push(el("circle", circleAttrs));
      const lab = cornerLabel(p);
      if (lab) {
        const ox = p[0] < 0.5 ? -16 : 10, oy = p[1] < 0.5 ? 18 : -8;
        const labelAttrs: Record<string, string | number> = {
          x: tx(p[0]) + ox, y: ty(p[1]) + oy,
          "font-size": 17, "font-weight": 600, fill: theme.ink,
        };
        if (nm) labelAttrs["data-bel-name"] = nm;
        annotations.children.push(el("text", labelAttrs, [], `.${lab}`));
      }
    });

    // crease-name labels, placed near a boundary end of the named bundle
    const B_EPS = 1e-6;
    const onB = (p: Vec2) =>
      Math.abs(p[0] - minX) < B_EPS || Math.abs(p[0] - maxX) < B_EPS ||
      Math.abs(p[1] - minY) < B_EPS || Math.abs(p[1] - maxY) < B_EPS;
    const creaseGroups = new Map<string, { vs: Set<number>; col: string }>();
    E.forEach(([a, b], i) => {
      const nm = prov[i]?.name;
      if (!nm || !showCrease(i)) return;
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

    appendConstructions(doc, scene, layout, theme, opts.labels, null);
  }

  if (opts.title) appendTitle(doc, theme, opts.title);
  if (opts.legend) appendLegend(doc, layout, theme, frame);
  return doc;
}
