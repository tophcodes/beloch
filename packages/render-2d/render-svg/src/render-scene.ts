// Unified renderer. Geometry (isometry) and decorations (texture) are chosen
// independently; renderCP and renderFolded are thin presets over this. The two
// legacy draw paths are merged here verbatim under an `occlude` branch (flat CP
// sheet vs folded step), so the presets stay byte-identical — the composition
// knobs (texture.upToStatement filtering, ghosted future creases) are strictly
// additive and dormant for the presets.
import type { EdgeProvenance, FoldScene, Mark, Vec2, Isometry as FaceMatrix } from "@beloch/scene";
import { createDoc, el, SvgDoc, SvgNode } from "./svgdoc";
import { DEFAULT_THEME, Theme, LineStyle, HighlightColor } from "./theme";
import { sceneLayout } from "./layout";
import { appendConstructions, appendLegend, appendTitle } from "./constructions";
import { coverageDepth, coveredIntervals, faceEdgeIndex, sideUp, lineToFace, clipLineToPoly, paperAssignment, paperEdgeSegments, pointCovered, pointInPolygonInclusive, segInsideIntervals, paperClippedIntervals } from "./geometry";
import { resolveIsometry, type Isometry } from "./isometry";
import { besideLine, placeLabels, type LabelAnchor } from "./primitives/labels";

export interface TextureOptions {
  upToStatement: number | "all"; // filter creases by scoring statement ≤ this (flat/ghost)
  creases: boolean;
  marks: boolean; // paper-space record marks (CP frame only)
  points: boolean; // named-point construction dots (overlay, via `labels`)
  lines: boolean; // named-line construction overlay (via `labels`)
  faces: "none" | "outline" | "filled";
}

export interface MarkOverlay {
  marks: Mark[];
  newestCreaseId?: number | undefined; // Mark.creaseId of the most recently added mark — drawn with an accent style
}

export interface SceneOptions {
  isometry: Isometry;
  texture: TextureOptions;
  title?: string | undefined;
  labels?: string[] | undefined; // construction overlay selection: ["--v", ".p"]
  // Whose names the drawing writes out, spelled as the selection is (".o",
  // "--mid"). Absent labels every name the picture carries, which is what a
  // figure in the documentation wants; a list labels those names alone, and an
  // empty one leaves the drawing without a word on it. The dots and the lines
  // are drawn either way: this is about the text.
  // A crease the program never named is spelled `#<crease id>` here, and the
  // drawing writes out the line of the statement that scored it instead of a
  // name it does not have.
  annotate?: string[] | undefined;
  // Entities to emphasise: ".p" / "--l" join the construction overlay, "#[.p]"
  // fills the faces of the flap carrying every listed point.
  highlight?: string[] | undefined;
  legend?: boolean | undefined;
  theme?: Partial<Theme> | undefined;
  view?: "top" | "bottom" | undefined; // folded only
  hidden?: "dashed" | "hide" | "depth" | undefined; // folded only: drop buried segments,
  // draw them uniformly, or fade each by how many layers cover it
  markOverlay?: MarkOverlay | undefined; // draw these marks instead of the scene's final ones — projected onto the step's faces when folded, in paper space when flat
}

// fold2svg.mjs:217 — hardcoded unit-square corners, normalized paper space.
const CORNER: [number, number, string][] = [
  [0, 0, "a"], [1, 0, "b"], [1, 1, "c"], [0, 1, "d"],
];
const near = (p: Vec2, x: number, y: number) =>
  Math.abs(p[0] - x) < 1e-6 && Math.abs(p[1] - y) < 1e-6;
const cornerLabel = (p: Vec2): string | undefined =>
  CORNER.find(([x, y]) => near(p, x, y))?.[2];

// `#[.p .q]` names the flap carrying every listed point, the same incidence
// rule the language's flap selector uses. The flap numbering comes from
// `beloch:inspect`, which describes the final state, so it addresses the faces
// of the crease pattern and of the last folded step; an earlier step has its
// own face decomposition and is left unhighlighted. Each face is mapped to the
// colour of the selector that claimed it, so two highlighted flaps stay apart.
function flapFaces(
  scene: FoldScene,
  colorOf: Map<string, HighlightColor>,
): Map<number, HighlightColor> {
  const faces = new Map<number, HighlightColor>();
  const inspect = scene.inspect;
  if (!inspect) return faces;
  for (const [selector, color] of colorOf) {
    if (!selector.startsWith("#[")) continue;
    const names = selector.slice(2, -1).trim().split(/\s+/).filter(Boolean);
    const flaps = names.map((n) => inspect.points[n.replace(/^\./, "")]?.flap ?? null);
    const flap = flaps[0];
    if (flap === null || flap === undefined) continue;
    if (!flaps.every((f) => f === flap)) continue;
    for (const [index, face] of Object.entries(inspect.faces)) {
      if (face.flap === flap) faces.set(Number(index), color);
    }
  }
  return faces;
}

// The names a drawing carries, placed so that two of them cannot land on each
// other and written in the colour of the thing each one names. Every branch
// collects its anchors and ends here, which is what keeps a crease's name and
// a construction's name looking alike.
function emitLabels(
  annotations: { children: SvgNode[] },
  anchors: LabelAnchor[],
  fontSize: number,
  cluster: boolean,
): void {
  for (const lab of placeLabels(anchors, { fontSize, cluster })) {
    const attrs: Record<string, string | number> = {
      x: lab.x, y: lab.y,
      "font-size": fontSize, "font-weight": 600,
      // The halo is what keeps a name legible where it crosses a line.
      stroke: "white", "stroke-width": 2.5, "paint-order": "stroke",
      ...lab.attrs,
    };
    if (lab.anchor !== "start") attrs["text-anchor"] = lab.anchor;
    annotations.children.push(el("text", attrs, [], lab.text));
  }
}

// What a crease the program never named is written as: the line of the
// statement that scored it. The reader can act on that — it is where the
// crease was made and where a name would go — and it invents no binding the
// program does not have.
function sourceMark(scene: FoldScene, prov: EdgeProvenance | null): string {
  const stmt = prov?.statement ?? null;
  const line = stmt === null ? null : scene.statements[stmt]?.sourceLine ?? null;
  return line === null ? "@?" : `@${line}`;
}

export function renderScene(scene: FoldScene, opts: SceneOptions): SvgDoc {
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  // A `.p` / `--l` highlight is the construction overlay the `labels` option
  // already draws: a dot with its name, or the line bolder and dashed on top,
  // clipped per face in a folded frame so what shows is the line's material.
  const highlight = opts.highlight ?? [];
  const selection = [...(opts.labels ?? []), ...highlight.filter((h) => !h.startsWith("#["))];
  // One palette colour per highlighted entity, by its position in the list, in
  // this view and in the other view of the same scene.
  const palette = theme.highlightPalette;
  const colorOf = new Map<string, HighlightColor>(
    highlight.map((h, i) => [h, palette[i % palette.length]!]),
  );
  const highlightFaces = flapFaces(scene, colorOf);
  // Whether the drawing writes this name out.
  const labelled = (name: string): boolean =>
    opts.annotate === undefined || opts.annotate.includes(name);
  // Whether the reader settled on this one. A caller that names nothing has
  // named no selection either, so nothing counts as picked.
  const selected = (name: string): boolean =>
    opts.annotate !== undefined && opts.annotate.includes(name);
  // The sheet's own edges, by name. A crease name spelled with two letters
  // would otherwise be read as a pair of corners and drawn as an edge that
  // does not exist.
  const paperEdges = scene.inspect?.edges ?? {};
  const pickedPaperEdges = (opts.annotate ?? [])
    .filter((n) => n.startsWith("--") && paperEdges[n.slice(2)] !== undefined)
    .map((n) => n.slice(2));
  // The frame both views of this scene share: the paper's footprint together
  // with every folded frame's, so a folded subset renders in place at true
  // relative size on the flat sheet's baseline.
  const layout = sceneLayout(scene);
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
  const upTo = opts.texture.upToStatement;

  const V = frame.vertices;
  const F = frame.facesVertices;
  const E = frame.edgesVertices;
  const A = frame.edgesAssignment;
  const prov = frame.edgesProvenance;

  // Progressive CP: an edge shows once the statement that scored it has run.
  // The scoring statement is named by the edge itself (beloch:edges[i].
  // statement); a FOLD written before that field existed reports null, and
  // such a scene shows every crease at every step rather than guessing.
  const showCrease = (i: number): boolean => {
    if (typeof upTo !== "number") return true;
    const stmt = prov[i]?.statement;
    return stmt == null || stmt <= upTo;
  };

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
        const lit = highlightFaces.get(fi);
        const fill = lit ? lit.wash : showFront ? theme.front : theme.back;
        const pts = face.map((idx) => `${mx(V[idx]![0])},${ty(V[idx]![1])}`).join(" ");
        paper.children.push(el("polygon", {
          points: pts, fill, stroke: "none", filter: "url(#layerShadow)",
          "data-kind": "face", "data-face-index": fi,
          ...(lit ? { "data-highlight": "true" } : {}),
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
    const showHidden = opts.hidden === "dashed" || opts.hidden === "depth";

    // hidden="depth": how faint a buried segment is, by how many layers lie
    // over it. Known ceiling: the floor is reached at four layers, so a
    // deeper stack reads as "deep" without separating further. Finer steps
    // are not distinguishable at the sizes these diagrams are drawn at; if
    // that changes, raise the floor's reach rather than the base opacity,
    // which one layer already spends.
    const HIDDEN_BASE = 0.55, HIDDEN_FALLOFF = 0.6, HIDDEN_FLOOR = 0.12;
    const depthOpacity = (n: number) =>
      Number(Math.max(HIDDEN_FLOOR, HIDDEN_BASE * HIDDEN_FALLOFF ** (n - 1)).toFixed(3));
    // The buried runs of one edge, as {t0,t1,depth}. depth is 0 for the
    // uniform mode, which is the signal not to stamp a fade at all.
    const buriedRuns = (a0: Vec2, b0: Vec2, refPos: number, cov: [number, number][]) =>
      opts.hidden === "depth"
        ? coverageDepth(a0, b0, order, refPos, F, V, bottom)
        : cov.map(([t0, t1]) => ({ t0, t1, depth: 0 }));

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
    const sideOf = (a0: Vec2, b0: Vec2, p: Vec2): number =>
      (b0[0] - a0[0]) * (p[1] - a0[1]) - (b0[1] - a0[1]) * (p[0] - a0[0]);
    const onSilhouette = (a0: Vec2, b0: Vec2, faces: number[]): boolean => {
      if (faces.length < 2) return true;
      let pos = false, neg = false;
      for (const fi of faces) {
        const s = sideOf(a0, b0, centroid(fi));
        if (s > 1e-9) pos = true;
        else if (s < -1e-9) neg = true;
      }
      return !(pos && neg); // faces all on one side → boundary of the silhouette
    };

    // Every name this drawing writes out, placed in one pass at the end of the
    // branch so that two of them cannot land on each other, whatever drew
    // them: a crease, a construction the paper does not carry, a named point.
    const labelAnchors: LabelAnchor[] = [];
    // The longest drawn run of each named crease, which is where its name
    // goes: a bundle is drawn in pieces, and the widest piece is the one with
    // room for a word beside it.
    const creaseRuns = new Map<
      string,
      { a: Vec2; b: Vec2; len: number; stroke: string; text: string; name: string | null }
    >();
    // Where a picked paper edge runs in this frame, in the frame's own
    // coordinates. The sheet's edges carry no name in the graph, so a run is
    // recognised as one of them by lying along it.
    const pickedEdgeRuns = new Map<string, [Vec2, Vec2][]>();
    for (const name of pickedPaperEdges) {
      const runs = paperEdgeSegments(scene, frame, name);
      if (runs.length > 0) pickedEdgeRuns.set(name, runs);
    }
    const pickedEdges: [Vec2, Vec2][] = [...pickedEdgeRuns.values()].flat();
    const EDGE_EPS = 1e-6;
    const onPickedEdge = (p: Vec2, q: Vec2): boolean =>
      pickedEdges.some(([a, b]) => {
        const along = (r: Vec2) => {
          const dx = b[0] - a[0], dy = b[1] - a[1];
          const len2 = dx * dx + dy * dy;
          const t = len2 ? Math.max(0, Math.min(1, ((r[0] - a[0]) * dx + (r[1] - a[1]) * dy) / len2)) : 0;
          return Math.hypot(r[0] - (a[0] + t * dx), r[1] - (a[1] + t * dy));
        };
        return along(p) <= EDGE_EPS && along(q) <= EDGE_EPS;
      });

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
          if (cid !== null) attrs["data-crease-id"] = cid;
          creases.children.push(el("line", attrs));
          const writes = name
            ? labelled(`--${name}`)
            : cid !== null && labelled(`#${cid}`);
          if (writes) {
            const key = name ?? `#${cid}`;
            const pa: Vec2 = [mx(p0[0]), ty(p0[1])], pb: Vec2 = [mx(p1[0]), ty(p1[1])];
            const len = Math.hypot(pb[0] - pa[0], pb[1] - pa[1]);
            const best = creaseRuns.get(key);
            if (!best || len > best.len) {
              creaseRuns.set(key, {
                a: pa, b: pb, len, stroke: style.stroke,
                text: name ? `--${name}` : sourceMark(scene, prov[i] ?? null),
                name: name ?? null,
              });
            }
          }
        }

        // What the reader picked is never hidden: where it runs under a
        // higher layer it is drawn dashed, so the line they asked about keeps
        // its whole length whatever the hidden mode says.
        const picked = name
          ? selected(`--${name}`)
          : cid !== null
            ? selected(`#${cid}`)
            : assignment === "B" && onPickedEdge(a0, b0);
        if (showHidden || picked) {
          const isB = assignment === "B";
          const stroke = isB ? "#475569" : "#94a3b8";
          const dashWgt = isB ? 2 : 1.2;
          const dash = isB ? "6 3" : "4 3";
          for (const { t0, t1, depth } of buriedRuns(a0, b0, refPos, covered)) {
            const p0 = lerp(t0), p1 = lerp(t1);
            const attrs: Record<string, string | number> = {
              class: `crease-${assignment}`,
              "data-kind": "crease",
              "data-occluded": "true",
              x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
              stroke, "stroke-width": dashWgt, "stroke-dasharray": dash, "stroke-linecap": "round",
            };
            if (depth && showHidden) {
              attrs["data-depth"] = depth;
              attrs["opacity"] = depthOpacity(depth);
            }
            if (name) attrs["data-name"] = name;
            if (name) attrs["data-bel-name"] = name;
            // The same crease as the visible run it continues. A host resolves
            // what the reader pointed at from the line's own attributes, and a
            // drawn segment that answers nothing is a target that lies.
            if (cid !== null) attrs["data-crease-id"] = cid;
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

        if (showHidden) {
          for (const { t0, t1, depth } of buriedRuns(a0, b0, refPos, covered)) {
            const p0 = lerp(t0), p1 = lerp(t1);
            dashedLines.push(el("line", {
              class: "crease-U",
              "data-kind": "crease",
              "data-occluded": "true",
              x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
              stroke: "#94a3b8", "stroke-width": 1.2, "stroke-dasharray": "4 3", "stroke-linecap": "round",
              ...(depth ? { "data-depth": depth, opacity: depthOpacity(depth) } : {}),
            }));
          }
        }
      }

      creases.children.push(...dashedLines);
    }

    // Ghost overlay: future creases projected onto the current folded faces as
    // translucent dashed hints. Named lines are dated by FRAME (their binding
    // step), so the statement bound is read as the frame that statement folds
    // against. "all", or a statement index the scene has no entry for, ghosts
    // nothing, as before.
    const ghostTo =
      typeof upTo === "number" ? scene.statements[upTo]?.frameIndex ?? -1 : -1;
    if (opts.isometry.kind === "step" && ghostTo > opts.isometry.index) {
      const FM = frame.facesMatrix ?? [];
      for (const nl of scene.namedLines) {
        if (nl.step <= opts.isometry.index || nl.step > ghostTo) continue;
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
    frame.verticesNames.forEach((nm, i) => {
      if (!nm) return;
      const p = fverts[i]!;
      const buried = occludedPt(i);
      if (buried && !showHidden) return; // "hide": drop dot + label
      const circle: Record<string, string | number> = {
        cx: mx(p[0]), cy: ty(p[1]), r: 3, fill: buried ? MUTED : theme.ink,
        "data-bel-name": nm, "data-kind": "point", "data-vertex": i,
      };
      if (buried) circle["data-occluded"] = "true";
      annotations.children.push(el("circle", circle));
      if (!labelled(`.${nm}`)) return;
      const ox = p[0] < centreX ? -16 : 10, oy = p[1] < centreY ? 18 : -8;
      const attrs: Record<string, string | number> = {
        fill: buried ? MUTED : theme.ink,
        "data-bel-name": nm, "data-kind": "point-label",
      };
      if (buried) attrs["data-occluded"] = "true";
      labelAnchors.push({
        x: mx(p[0]), y: ty(p[1]), text: `.${nm}`, key: `.${nm}`,
        preferOffset: [ox, oy], group: "point", attrs,
      });
    });

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

    labelAnchors.push(
      ...appendConstructions(doc, scene, layout, theme, selection, { frame }, colorOf, opts.annotate),
    );
    // A picked paper edge writes its name out too. It carries no name in the
    // graph, so it is not among the creases above; where it runs in this frame
    // is what the anchor is taken from.
    for (const [name, runs] of pickedEdgeRuns) {
      const longest = runs.reduce((best, r) =>
        Math.hypot(r[1][0] - r[0][0], r[1][1] - r[0][1]) >
        Math.hypot(best[1][0] - best[0][0], best[1][1] - best[0][1]) ? r : best);
      const a: Vec2 = [mx(longest[0][0]), ty(longest[0][1])];
      const b: Vec2 = [mx(longest[1][0]), ty(longest[1][1])];
      labelAnchors.push({
        x: (a[0] + b[0]) / 2, y: (a[1] + b[1]) / 2,
        text: `--${name}`, key: `--${name}`,
        preferOffset: besideLine(a, b, 14),
        group: `line:${name}`,
        attrs: { fill: theme.boundary, "data-bel-name": name, "data-kind": "line-label" },
      });
    }
    for (const [key, run] of creaseRuns) {
      const attrs: Record<string, string | number> = {
        fill: run.stroke, "data-kind": "line-label",
      };
      if (run.name !== null) attrs["data-bel-name"] = run.name;
      labelAnchors.push({
        x: (run.a[0] + run.b[0]) / 2, y: (run.a[1] + run.b[1]) / 2,
        text: run.text, key,
        preferOffset: besideLine(run.a, run.b, 14),
        group: `line:${key}`,
        attrs,
      });
    }
    emitLabels(annotations, labelAnchors, 17, opts.annotate === undefined);
  } else {
    // ===== flat crease-pattern geometry (ported from renderCP) =====
    if (opts.texture.faces !== "none") {
      F.forEach((f, i) => {
        const lit = highlightFaces.get(i);
        const pts = f.map((vi) => `${tx(V[vi]![0])},${ty(V[vi]![1])}`).join(" ");
        paper.children.push(el("polygon", {
          points: pts, fill: lit ? lit.wash : theme.fill, stroke: "none",
          "data-kind": "face", "data-face-index": i,
          ...(lit ? { "data-highlight": "true" } : {}),
        }));
      });
    }

    if (opts.texture.creases) {
      // The sheet as it stands after statement `upTo`: a crease a later fold
      // lays flat again, or turns over, still carries the assignment it has
      // at that step. The crease pattern's own assignments are the final ones.
      const stepFrame =
        typeof upTo === "number" ? scene.steps[scene.statements[upTo]?.frameIndex ?? -1]?.frame : undefined;
      const assignmentAtStep = stepFrame ? paperAssignment(stepFrame) : null;
      E.forEach(([a, b], i) => {
        if (!showCrease(i)) return;
        const assignment = assignmentAtStep?.(V[a]!, V[b]!) ?? A[i]!;
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
        if (cid !== null) attrs["data-crease-id"] = cid;
        creases.children.push(el("line", attrs));
      });
    }

    if (opts.texture.marks) {
      const MARK_TICK_LEN = 0.06;
      // The flat sheet draws marks in paper space, so it needs no face
      // matrices and takes the overlay list directly. Without an overlay it
      // falls back to the scene's own marks, i.e. the final state's.
      const flatMarks = opts.markOverlay?.marks ?? scene.marks;
      flatMarks.forEach((m) => {
        const lineStyle = theme.lineStyle(m.intent, theme);
        const isNewest = m.creaseId === opts.markOverlay?.newestCreaseId;
        const attrs: Record<string, string | number> = {
          class: "mark",
          "data-crease-id": m.creaseId,
          stroke: isNewest ? theme.construction : lineStyle.stroke,
          "stroke-width": isNewest
            ? lineStyle.strokeWidth + 1
            : Math.max(1, lineStyle.strokeWidth - 1),
          "stroke-dasharray": "2 2",
          "stroke-linecap": "round",
          opacity: isNewest ? 1 : 0.7,
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

    // Which points a drawing of the sheet at this statement marks: the paper's
    // corners, and the points the program has named by then. The vertices are
    // the final crease pattern's, carved by every crease the program will ever
    // score, so a crossing cannot be dated by the creases drawn so far; a
    // point the program has not named yet is left unmarked.
    const showVertex = (i: number, nm: string | null): boolean => {
      if (typeof upTo !== "number") return true;
      if (cornerLabel(V[i]!)) return true;
      if (!nm) return false;
      const np = scene.namedPoints.find((q) => q.name === nm);
      // No point statement to read (a FOLD from before the field): show it,
      // the same promise the crease filter makes.
      return np ? np.statement == null || np.statement <= upTo : false;
    };

    // Every name this drawing writes out, placed in one pass at the end of the
    // branch, as in the folded one above.
    const labelAnchors: LabelAnchor[] = [];

    // vertex dots + corner labels
    V.forEach((p, i) => {
      const nm = scene.cp.verticesNames[i] ?? null;
      if (!showVertex(i, nm)) return;
      const circleAttrs: Record<string, string | number> = {
        cx: tx(p[0]), cy: ty(p[1]), r: 3, fill: theme.ink, "data-vertex": i,
      };
      if (nm) { circleAttrs["data-bel-name"] = nm; circleAttrs["data-kind"] = "point"; }
      annotations.children.push(el("circle", circleAttrs));
      // Which name this vertex is written out under. A caller that named the
      // ones it wants gets any named point; without such a list the drawing
      // labels the paper's corners, as it always has, and leaves the points a
      // program bound to the construction overlay.
      const lab = opts.annotate === undefined ? cornerLabel(p) : nm ?? cornerLabel(p);
      // A highlighted corner is already labelled by the construction overlay,
      // in its palette colour and at nearly this offset; drawing the plain
      // label too would set one name on top of the other.
      if (lab && !colorOf.has(`.${lab}`) && labelled(`.${lab}`)) {
        const ox = p[0] < 0.5 ? -16 : 10, oy = p[1] < 0.5 ? 18 : -8;
        const labelAttrs: Record<string, string | number> = { fill: theme.ink };
        if (nm) labelAttrs["data-bel-name"] = nm;
        labelAttrs["data-kind"] = "point-label";
        labelAnchors.push({
          x: tx(p[0]), y: ty(p[1]), text: `.${lab}`, key: `.${lab}`,
          preferOffset: [ox, oy], group: "point", attrs: labelAttrs,
        });
      }
    });

    // crease-name labels, placed near a boundary end of the named bundle
    const B_EPS = 1e-6;
    const onB = (p: Vec2) =>
      Math.abs(p[0] - minX) < B_EPS || Math.abs(p[0] - maxX) < B_EPS ||
      Math.abs(p[1] - minY) < B_EPS || Math.abs(p[1] - maxY) < B_EPS;
    const creaseGroups = new Map<
      string,
      { vs: Set<number>; col: string; text: string; name: string | null }
    >();
    E.forEach(([a, b], i) => {
      if (!showCrease(i)) return;
      const nm = prov[i]?.name ?? null;
      const cid = prov[i]?.creaseId ?? null;
      // A crease the program never named is grouped by its id and written out
      // as the line that scored it.
      const key = nm ?? (cid === null ? null : `#${cid}`);
      if (key === null) return;
      if (!creaseGroups.has(key)) {
        creaseGroups.set(key, {
          vs: new Set(),
          col: theme.lineStyle(A[i]!, theme).stroke,
          text: nm ? `--${nm}` : sourceMark(scene, prov[i] ?? null),
          name: nm,
        });
      }
      const grp = creaseGroups.get(key)!;
      grp.vs.add(a);
      grp.vs.add(b);
    });
    for (const [key, { vs, col, text, name: nm }] of creaseGroups) {
      if (!labelled(key.startsWith("#") ? key : `--${key}`)) continue;
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
      const a: Vec2 = [tx(P[0]), ty(P[1])], b: Vec2 = [tx(C[0]), ty(C[1])];
      const attrs: Record<string, string | number> = {
        fill: col, "data-kind": "line-label",
      };
      if (nm !== null) { attrs["data-bel-name"] = nm; attrs["data-name"] = nm; }
      labelAnchors.push({
        x: tx(P[0] + (C[0] - P[0]) * t), y: ty(P[1] + (C[1] - P[1]) * t),
        text, key,
        preferOffset: besideLine(a, b, 14),
        group: `line:${key}`,
        attrs,
      });
    }

    // A picked paper edge writes its name out, at the side it runs along.
    for (const name of pickedPaperEdges) {
      const longest = paperEdgeSegments(scene, scene.cp, name)[0];
      if (!longest) continue;
      const a: Vec2 = [tx(longest[0][0]), ty(longest[0][1])];
      const b: Vec2 = [tx(longest[1][0]), ty(longest[1][1])];
      labelAnchors.push({
        x: (a[0] + b[0]) / 2, y: (a[1] + b[1]) / 2,
        text: `--${name}`, key: `--${name}`,
        preferOffset: besideLine(a, b, 14),
        group: `line:${name}`,
        attrs: { fill: theme.boundary, "data-bel-name": name, "data-kind": "line-label" },
      });
    }
    labelAnchors.push(
      ...appendConstructions(doc, scene, layout, theme, selection, null, colorOf, opts.annotate),
    );
    emitLabels(annotations, labelAnchors, 17, opts.annotate === undefined);
  }

  if (opts.title) appendTitle(doc, theme, opts.title);
  if (opts.legend) appendLegend(doc, layout, theme, frame);
  return doc;
}
