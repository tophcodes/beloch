// Candidates view: one panel per candidate of a statement. For a construction
// the candidates are lines, each drawn on its own copy of the state the
// construction read, as Ida draws the choices of a fold [ida2020, Fig. 2.17];
// for a write they are states, drawn by what tells them apart. Reads
// `beloch:trace` (spec/FOLD.md, "The trace"), so the file has to be written by
// `beloch fold --trace`.
import type { Conic, FoldScene, LineCoeffs, TraceCandidate, TraceEntry, Vec2, WriteEntry } from "@beloch/scene";
import { SceneError } from "@beloch/scene";
import { createDoc, el, SvgDoc } from "./svgdoc";
import type { SvgNode } from "./svgdoc";
import { colorLineStyle, DEFAULT_THEME } from "./theme";
import type { Theme } from "./theme";
import { clipLineToPoly } from "./geometry";
import { sceneLayout } from "./layout";
import type { Layout } from "./layout";
import { renderFolded } from "./render-folded";
import type { RenderOptions } from "./render-cp";
import { candidateNodes, candidateStatus, caption, paperFrame, withCandidateSteps } from "./render-operation";
import { renderCP } from "./render-cp";

export interface CandidatesOptions extends RenderOptions {
  // Index into scene.statements. Undefined: the statement a traced run failed
  // at, else the last statement that chose from candidates.
  statement?: number | undefined;
}

function defaultStatement(scene: FoldScene): number | undefined {
  const last = (es: { statement: number }[]) => es[es.length - 1]?.statement ?? -1;
  const s = Math.max(last(scene.trace), last(scene.writeTrace.filter((e) => e.candidates.length > 0)));
  return scene.error?.statement ?? (s >= 0 ? s : undefined);
}

// The write entry of a statement when the write chose from candidates. A fold
// chooses none, so the candidates of a fold's statement are its construction's.
export function writeCandidatesEntry(scene: FoldScene, statement?: number): WriteEntry | undefined {
  const target = statement ?? defaultStatement(scene);
  return scene.writeTrace.find((e) => e.statement === target && e.candidates.length > 0);
}

export function candidatesEntry(scene: FoldScene, statement?: number): TraceEntry {
  if (scene.trace.length === 0) {
    throw new SceneError("no beloch:trace in this file; write it with `beloch fold --trace`");
  }
  const target = statement ?? defaultStatement(scene);
  const entries = scene.trace.filter((e) => e.statement === target);
  const entry = entries[entries.length - 1];
  if (!entry) throw new SceneError(`statement ${target} evaluates no construction`);
  return entry;
}

const STATUS: Record<string, string> = {
  paper: "removed: creases no face",
  toward: "removed by toward",
  moving: "removed by moving",
};

function status(c: TraceCandidate): string {
  if (c.selected) return "selected";
  if (c.removedBy) return STATUS[c.removedBy]!;
  return "open";
}

// The parabola with this focus and directrix as polylines inside the frame,
// sampled along the directrix: the point above the foot q lies at distance
// |q − f|² / 2d from it, with d the focus's distance from the directrix.
function parabola(conic: Conic, lay: Layout): Vec2[][] {
  const [a, b, c] = conic.directrix;
  const len = Math.hypot(a, b);
  const [fx, fy] = conic.focus;
  const d = (a * fx + b * fy - c) / len;
  if (Math.abs(d) < 1e-12) return [];
  const n: Vec2 = [(a / len) * Math.sign(d), (b / len) * Math.sign(d)];
  const u: Vec2 = [-b / len, a / len];
  const q0: Vec2 = [fx - n[0] * Math.abs(d), fy - n[1] * Math.abs(d)];
  const margin = 0.02 * lay.span;
  const inside = ([x, y]: Vec2) =>
    x >= lay.minX - margin && x <= lay.maxX + margin && y >= lay.minY - margin && y <= lay.maxY + margin;
  const runs: Vec2[][] = [];
  let run: Vec2[] = [];
  const reach = 4 * lay.span;
  for (let i = 0; i <= 400; i++) {
    const t = -reach + (2 * reach * i) / 400;
    const q: Vec2 = [q0[0] + t * u[0], q0[1] + t * u[1]];
    const s = ((q[0] - fx) ** 2 + (q[1] - fy) ** 2) / (2 * Math.abs(d));
    const p: Vec2 = [q[0] + s * n[0], q[1] + s * n[1]];
    if (inside(p)) run.push(p);
    else if (run.length) { runs.push(run); run = []; }
  }
  if (run.length) runs.push(run);
  return runs.filter((r) => r.length > 1);
}

function lineOnFaces(line: LineCoeffs, faces: Vec2[][]): [Vec2, Vec2][] {
  const [a, b, c] = line;
  return faces
    .map((poly) => clipLineToPoly(a, b, c, poly))
    .filter((s): s is [Vec2, Vec2] => s !== null);
}

function overlay(
  entry: TraceEntry, cand: TraceCandidate, index: number, faces: Vec2[][],
  lay: Layout, theme: Theme,
): SvgNode[] {
  const { tx, ty } = lay;
  const pts = (ps: Vec2[]) => ps.map(([x, y]) => `${tx(x).toFixed(2)},${ty(y).toFixed(2)}`).join(" ");
  const nodes: SvgNode[] = [];
  for (const conic of entry.conics) {
    for (const run of parabola(conic, lay)) {
      nodes.push(el("polyline", {
        "data-kind": "conic", points: pts(run), fill: "none",
        stroke: theme.construction, "stroke-width": 1.2, opacity: 0.7,
      }));
    }
  }
  const live = cand.removedBy === null;
  const accent = theme.highlightPalette[1 % theme.highlightPalette.length]!.stroke;
  for (const [p, q] of lineOnFaces(cand.line, faces)) {
    nodes.push(el("line", {
      "data-kind": "candidate", "data-status": status(cand),
      x1: tx(p[0]), y1: ty(p[1]), x2: tx(q[0]), y2: ty(q[1]),
      stroke: live ? accent : theme.flat,
      "stroke-width": live ? 4 : 2,
      ...(live ? {} : { "stroke-dasharray": "6 4", opacity: 0.7 }),
      "stroke-linecap": "round",
    }));
  }
  if (entry.toward) {
    const [x, y] = entry.toward;
    nodes.push(el("circle", {
      "data-kind": "toward", cx: tx(x), cy: ty(y), r: 6,
      fill: "none", stroke: theme.ink, "stroke-width": 2,
    }));
  }
  nodes.push(el("text", {
    x: lay.W / 2, y: lay.H - 16, "text-anchor": "middle",
    "font-size": 15, fill: theme.ink,
  }, [], `${index + 1} · ${status(cand)}`));
  return nodes;
}

// Panels in rows of at most four.
const COLS = 4;

function grid(n: number, lay: Layout): { doc: SvgDoc; at: (i: number) => { x: number; y: number } } {
  const cols = Math.min(Math.max(n, 1), COLS);
  const rows = Math.ceil(Math.max(n, 1) / cols);
  return {
    doc: createDoc(lay.W * cols, lay.H * rows),
    at: (i) => ({ x: (i % cols) * lay.W, y: Math.floor(i / cols) * lay.H }),
  };
}

function renderWriteCandidates(scene: FoldScene, entry: WriteEntry, opts: CandidatesOptions): SvgDoc {
  const [ext] = withCandidateSteps(scene, entry);
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const lay = sceneLayout(ext);
  const { doc, at } = grid(entry.candidates.length, lay);
  const before = ext.steps[entry.frameIndex];
  if (!before) throw new SceneError(`frame ${entry.frameIndex} is not in the file`);
  const faces = before.frame.facesVertices.map((f) => f.map((v) => before.frame.vertices[v]!));
  entry.candidates.forEach((c, i) => {
    // each panel draws what tells the candidates apart: the states of a
    // flatten differ in their letters, which their crease patterns show; the
    // spines of a reverse fold differ in where they cut the tip, which the
    // state before the fold shows
    const panelOpts = {
      title: i === 0 ? opts.title : undefined, labels: opts.labels, theme: opts.theme,
      highlight: opts.highlight,
    };
    const asPattern = entry.terms.write === "flatten" && c.frame !== null;
    const base = (asPattern
      ? renderCP({ ...ext, cp: paperFrame(c.frame!) }, {
        ...panelOpts,
        // in colour: a dash-dot mountain reads as a solid line at this size
        theme: { lineStyle: colorLineStyle, ...opts.theme },
      })
      : renderFolded(ext, { ...panelOpts, step: String(entry.frameIndex) })).node();
    const nodes = asPattern ? [] : candidateNodes(entry, c, faces, lay, theme);
    doc.root.children.push(el("svg", { ...base.attrs, ...at(i), "data-status": candidateStatus(c) }, [
      ...base.children, ...nodes, caption(`${i + 1} · ${candidateStatus(c)}`, lay, theme),
    ]));
  });
  return doc;
}

export function renderCandidates(scene: FoldScene, opts: CandidatesOptions = {}): SvgDoc {
  const write = writeCandidatesEntry(scene, opts.statement);
  if (write) return renderWriteCandidates(scene, write, opts);
  const entry = candidatesEntry(scene, opts.statement);
  const step = scene.steps[entry.frameIndex];
  if (!step) throw new SceneError(`frame ${entry.frameIndex} is not in the file`);
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const lay = sceneLayout(scene);
  const faces = step.frame.facesVertices.map((f) => f.map((i) => step.frame.vertices[i]!));
  // the marks scored and not yet folded when the construction ran, which a
  // folded frame does not draw by itself
  const marks = scene.statements[entry.statement - 1]?.keptMarks ?? [];
  const panel = (nodes: SvgNode[], i: number, title?: string) => {
    const base = renderFolded(scene, {
      step: String(entry.frameIndex), title, labels: opts.labels, theme: opts.theme,
      highlight: opts.highlight,
      markOverlay: { marks },
    }).node();
    return el("svg", { ...base.attrs, ...at(i) }, [...base.children, ...nodes]);
  };
  const cands = entry.candidates;
  const { doc, at } = grid(cands.length, lay);
  if (cands.length === 0) {
    doc.root.children.push(panel([el("text", {
      x: lay.W / 2, y: lay.H - 16, "text-anchor": "middle", "font-size": 15, fill: theme.ink,
    }, [], "no candidate")], 0, opts.title));
  }
  cands.forEach((c, i) => {
    doc.root.children.push(panel(overlay(entry, c, i, faces, lay, theme), i, i === 0 ? opts.title : undefined));
  });
  return doc;
}
