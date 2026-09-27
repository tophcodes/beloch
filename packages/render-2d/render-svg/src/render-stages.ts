// Stages view: how the selection of one construction went (spec/MODEL.md,
// def-selection), drawn as spec/CLI-STAGES.md states it. One column: the
// program, one row per stage with the paper on the left and on the right the
// title, the statement with the part the stage reads underlined, and the
// text rows; then the outcome and, where several candidates or none remain,
// what to write next; then the legend of the marks the figure uses.
// Everything drawn comes from `beloch:trace` (spec/FOLD.md, "The trace"):
// the view repeats no part of the selection, and computes only where a mark
// sits on the page.
import type {
  FoldScene, LineCoeffs, Motion, Stage, TraceCandidate, TraceEntry, TraceObject, Vec2,
} from "@beloch/scene";
import { SceneError } from "@beloch/scene";
import { createDoc, el, SvgDoc } from "./svgdoc";
import type { SvgNode } from "./svgdoc";
import { DEFAULT_THEME, HIGHLIGHT_TEXT } from "./theme";
import type { Theme } from "./theme";
import { clipHalfPlane, clipLineToPoly, pointInPolygonInclusive } from "./geometry";
import type { Layout } from "./layout";
import { renderFolded } from "./render-folded";
import type { RenderOptions } from "./render-cp";
import { candidatesEntry, parabola } from "./render-candidates";

export interface StagesOptions extends RenderOptions {
  // Index into scene.statements. Undefined: as for the candidates view.
  statement?: number | undefined;
  // The program text the trace's spans point into. Without it the figure
  // leaves out the program and the statement lines.
  source?: string | undefined;
  // Draw this stage alone, 0 to 4, with the program and the legend.
  stage?: number | undefined;
  // Add the rows that say what each stage checks.
  checks?: boolean | undefined;
}

export const STAGES: Stage[] = ["paper", "heading", "side", "moved", "landing"];
const TITLES: string[] = [
  "generate candidates", "compare with the heading", "name the folding side",
  "check what the fold moves", "measure the landing",
];

// ---- page geometry, in px ----

const SQ = 220;          // the side of the paper's square
const PAD = 46;          // room around the drawing area for numbers and labels
const GUTTER = 36;       // between the drawing and the text column
const TEXT_W = 440;      // the text column
const LABEL_W = 92;      // the row labels inside it
const FONT = 13.5;
const LINE = 19;
const MONO = 12.5;
const CHAR = 6.9;
const MONO_FAMILY = "ui-monospace, 'DejaVu Sans Mono', Menlo, Consolas, monospace";        // the width of a character at FONT, for wrapping
const MONO_CHAR = 7.55;
const ROW_GAP = 26;
const GLYPH_R = 8;
const EPS = 1e-9;

// The candidates' colours, in the order they are numbered: blue, orange and
// purple of the highlight palette. Green and red read as pass and fail.
const CANDIDATE_HUES = [4, 3, 2];
const hue = (k: number) => CANDIDATE_HUES[k % CANDIDATE_HUES.length]!;
const stroke = (theme: Theme, k: number) =>
  theme.highlightPalette[hue(k) % theme.highlightPalette.length]!.stroke;
const textColour = (k: number) => HIGHLIGHT_TEXT[hue(k)] ?? "#0f172a";
// Each candidate hatches its folding side at its own angle, so the sides
// tell apart without colour.
const HATCH_ANGLES = [45, -45, 90, 0];

// What a stage reads or constructs is slate, and never a candidate's colour.
const slate = (theme: Theme) => theme.flat;

// ---- the stages the construction uses ----

const stageIndex = (s: Stage) => STAGES.indexOf(s);

// A candidate still in the selection when stage `s` starts.
function reaches(c: TraceCandidate, s: Stage): boolean {
  return c.removedAt === null || stageIndex(c.removedAt) >= stageIndex(s);
}

// Why a stage has no row of its own, or null where it has one.
export function skipReason(entry: TraceEntry, s: Stage, cs: TraceCandidate[]): string | null {
  const reached = cs.filter((c) => reaches(c, s)).length;
  const gone = "Skipped, as no candidate is left.";
  switch (s) {
    case "paper": return null;
    case "heading":
      if (cs.some((c) => c.angle !== null)) return null;
      return entry.headingLine ? (reached ? "Skipped, as only one candidate is left." : gone)
        : "Skipped, as the fold names no heading.";
    case "side":
      // without side items the side is a default of the moved-material stage
      if (!entry.towardName && !entry.movingName) return "Skipped, as the fold names neither toward nor moving.";
      return cs.some((c) => c.sideFrom !== null || c.removedAt === "side") ? null : gone;
    case "moved":
      return cs.some((c) => c.attempts.length > 0 || c.removedAt === "moved") ? null : gone;
    case "landing":
      if (cs.some((c) => c.landed !== null || c.subjectFolds !== null || c.removedAt === "landing")) return null;
      if (!entry.towardName) return "Skipped, as the fold names no toward.";
      return reached === 1 ? "Skipped, as only one candidate is left." : gone;
  }
}

// ---- small geometry on the table ----

const sub = (p: Vec2, q: Vec2): Vec2 => [p[0] - q[0], p[1] - q[1]];
const add = (p: Vec2, q: Vec2): Vec2 => [p[0] + q[0], p[1] + q[1]];
const mul = (p: Vec2, k: number): Vec2 => [p[0] * k, p[1] * k];
const dist = (p: Vec2, q: Vec2) => Math.hypot(p[0] - q[0], p[1] - q[1]);
const unit = (p: Vec2): Vec2 => { const n = Math.hypot(p[0], p[1]) || 1; return [p[0] / n, p[1] / n]; };
const mid = (p: Vec2, q: Vec2): Vec2 => [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];
const direction = ([a, b]: LineCoeffs): Vec2 => unit([-b, a]);
const sideOf = ([a, b, c]: LineCoeffs, [x, y]: Vec2) => a * x + b * y - c;

function reflect(p: Vec2, [a, b, c]: LineCoeffs): Vec2 {
  const k = (2 * (a * p[0] + b * p[1] - c)) / (a * a + b * b);
  return [p[0] - k * a, p[1] - k * b];
}

function meet([a1, b1, c1]: LineCoeffs, [a2, b2, c2]: LineCoeffs): Vec2 | null {
  const d = a1 * b2 - a2 * b1;
  if (Math.abs(d) < EPS) return null;
  return [(c1 * b2 - c2 * b1) / d, (a1 * c2 - a2 * c1) / d];
}

const lineThrough = (p: Vec2, q: Vec2): LineCoeffs => {
  const a = q[1] - p[1], b = p[0] - q[0];
  return [a, b, a * p[0] + b * p[1]];
};

// The line where it crosses the paper, one segment per face.
function onFaces(line: LineCoeffs, faces: Vec2[][]): [Vec2, Vec2][] {
  const [a, b, c] = line;
  return faces.map((f) => clipLineToPoly(a, b, c, f)).filter((s): s is [Vec2, Vec2] => s !== null);
}

// The two ends of the line's crossing with the paper, over every face.
function chord(line: LineCoeffs, faces: Vec2[][]): [Vec2, Vec2] | null {
  const pts = onFaces(line, faces).flat();
  if (pts.length === 0) return null;
  const d = direction(line);
  const t = (p: Vec2) => p[0] * d[0] + p[1] * d[1];
  const sorted = [...pts].sort((p, q) => t(p) - t(q));
  return [sorted[0]!, sorted[sorted.length - 1]!];
}

const onPaper = (p: Vec2, faces: Vec2[][]) => faces.some((f) => pointInPolygonInclusive(p, f, 1e-7));

// ---- the drawing area ----

interface Area { lay: Layout; faces: Vec2[][]; scale: number }

// The paper and what the stages draw beyond it, at a fixed scale for the
// paper: a landing past the edge widens the area, and so does a construction.
function drawingArea(faces: Vec2[][], extra: Vec2[]): Area {
  const paper = faces.flat();
  const px = paper.map((p) => p[0]), py = paper.map((p) => p[1]);
  const [x0, x1, y0, y1] = [Math.min(...px), Math.max(...px), Math.min(...py), Math.max(...py)];
  const span = Math.max(x1 - x0, y1 - y0) || 1;
  // content past the paper, up to three quarters of its size on each side
  const reach = 0.75 * span;
  const inside = extra.filter((p) => Number.isFinite(p[0]) && Number.isFinite(p[1]))
    .map(([x, y]) => [Math.min(Math.max(x, x0 - reach), x1 + reach),
      Math.min(Math.max(y, y0 - reach), y1 + reach)] as Vec2);
  const xs = [...px, ...inside.map((p) => p[0])], ys = [...py, ...inside.map((p) => p[1])];
  const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys);
  const scale = SQ / span;
  const W = (maxX - minX) * scale + 2 * PAD, H = (maxY - minY) * scale + 2 * PAD;
  return {
    faces, scale,
    lay: {
      W, H, minX, maxX, minY, maxY, span: Math.max(maxX - minX, maxY - minY),
      tx: (x: number) => PAD + (x - minX) * scale,
      ty: (y: number) => PAD + (maxY - y) * scale,
    },
  };
}

const f2 = (x: number) => Number(x.toFixed(2));
const P = (a: Area, p: Vec2): [number, number] => [f2(a.lay.tx(p[0])), f2(a.lay.ty(p[1]))];

// The rectangle of the drawing area in table coordinates.
function frameRect(a: Area): Vec2[] {
  const m = PAD / a.scale;
  const { minX, maxX, minY, maxY } = a.lay;
  return [[minX - m, minY - m], [maxX + m, minY - m], [maxX + m, maxY + m], [minX - m, maxY + m]];
}

// ---- marks ----

// A rim of the page colour behind a label, so a line under it does not cut
// through its letters.
const halo = (theme: Theme) => ({
  stroke: theme.background, "stroke-width": 4, "stroke-linejoin": "round", "paint-order": "stroke",
});

function text(x: number, y: number, s: string, fill: string, theme: Theme,
  attrs: Record<string, string | number> = {}): SvgNode {
  return el("text", { x: f2(x), y: f2(y), "font-size": 12.5, fill, ...halo(theme), ...attrs }, [], s);
}

function seg(a: Area, p: Vec2, q: Vec2, attrs: Record<string, string | number>): SvgNode {
  const [x1, y1] = P(a, p), [x2, y2] = P(a, q);
  return el("line", { x1, y1, x2, y2, "stroke-linecap": "round", ...attrs });
}

type GlyphState = "on" | "out" | "kept";

// A candidate's number in a circle: outlined while in the selection, crossed
// out where this stage removes it, filled where it is the line kept.
function glyph(x: number, y: number, k: number, state: GlyphState, theme: Theme, r = GLYPH_R,
  kind = "number"): SvgNode[] {
  const c = stroke(theme, k);
  const nodes: SvgNode[] = [
    el("circle", { cx: f2(x), cy: f2(y), r, fill: state === "kept" ? c : theme.background,
      stroke: c, "stroke-width": 1.6, "data-kind": kind, "data-index": k + 1, "data-status": state }),
    el("text", { x: f2(x), y: f2(y + r * 0.42), "text-anchor": "middle", "font-size": r * 1.3,
      "font-weight": 700, fill: state === "kept" ? theme.background : c }, [], String(k + 1)),
  ];
  if (state === "out") {
    const d = r * 1.25;
    nodes.push(el("path", { d: `M ${f2(x - d)} ${f2(y - d)} L ${f2(x + d)} ${f2(y + d)} M ${f2(x - d)} ${f2(y + d)} L ${f2(x + d)} ${f2(y - d)}`,
      stroke: theme.ink, "stroke-width": 1.4, fill: "none", "data-kind": "crossed" }));
  }
  return nodes;
}

// An arrow from p to q in px, bent to one side so that it reads as a motion
// and stays off a straight line under it, with its head as a triangle: a
// <marker> needs an id, and the site inlines several figures into one page.
function arrowPx(x1: number, y1: number, x2: number, y2: number, colour: string, width: number,
  bend = 1 / 5): { nodes: SvgNode[]; at: [number, number] } {
  const len = Math.hypot(x2 - x1, y2 - y1);
  if (len < 2) return { nodes: [], at: [x1, y1] };
  const cx = (x1 + x2) / 2 - ((y2 - y1) / len) * len * bend;
  const cy = (y1 + y2) / 2 + ((x2 - x1) / len) * len * bend;
  const tl = Math.hypot(x2 - cx, y2 - cy) || 1;
  const ux = (x2 - cx) / tl, uy = (y2 - cy) / tl;
  const head = 7 + width;
  const bx = x2 - head * ux, by = y2 - head * uy;
  const w = head * 0.45;
  return {
    nodes: [
      el("path", { d: `M ${f2(x1)} ${f2(y1)} Q ${f2(cx)} ${f2(cy)} ${f2(bx)} ${f2(by)}`,
        fill: "none", stroke: colour, "stroke-width": width, "data-kind": "arrow" }),
      el("polygon", { points: [[x2, y2], [bx - w * uy, by + w * ux], [bx + w * uy, by - w * ux]]
        .map(([x, y]) => `${f2(x!)},${f2(y!)}`).join(" "), fill: colour }),
    ],
    at: [0.25 * x1 + 0.5 * cx + 0.25 * bx, 0.25 * y1 + 0.5 * cy + 0.25 * by],
  };
}

// ---- the program and the statement ----

interface Program { lines: string[]; bold: number }

// The statement the view draws, after the statements that define the names
// it reads, directly or through other names, in program order.
function programOf(scene: FoldScene, statement: number, source: string): Program {
  const all = source.split("\n");
  const textOf = (i: number): string | null => {
    const sp = scene.statements[i]?.span;
    const r = sp ? spanRange(sp) : null;
    return r ? all.slice(r.l1 - 1, r.l2).join(" ").trim() : null;
  };
  const defines = (t: string): string[] => [
    ...[...t.matchAll(/\bas\s+(--[A-Za-z_][\w]*|\.[A-Za-z_][\w]*)/g)].map((m) => m[1]!),
    ...[...t.matchAll(/^\s*(--[A-Za-z_][\w]*|\.[A-Za-z_][\w]*)\s*=/g)].map((m) => m[1]!),
  ];
  const reads = (t: string) => [...t.matchAll(/(--|\.)[A-Za-z_][\w]*/g)].map((m) => m[0]);
  const texts = scene.statements.map((_, i) => textOf(i));
  const definedAt = new Map<string, number>();
  const keep = new Set<number>([statement]);
  const want = [statement];
  while (want.length) {
    const i = want.pop()!;
    const t = texts[i];
    if (!t) continue;
    for (const name of reads(t)) {
      if (defines(t).includes(name)) continue;
      let at = -1;
      for (let j = 0; j < i; j++) if (texts[j] && defines(texts[j]!).includes(name)) at = j;
      definedAt.set(name, at);
      if (at >= 0 && !keep.has(at)) { keep.add(at); want.push(at); }
    }
  }
  const paper = all.find((l) => /^\s*paper\b/.test(l))?.trim();
  const kept = [...keep].sort((a, b) => a - b).map((i) => texts[i]).filter((t): t is string => !!t);
  const lines = [...(paper ? [paper] : []), ...kept];
  return { lines, bold: lines.length - 1 };
}

interface SpanRange { l1: number; c1: number; l2: number; c2: number }

// "file:L:C1-C2", or "file:L1:C1-L2:C2" across lines, as the kernel writes a
// span; columns 1-based, the end exclusive.
function spanRange(s: string): SpanRange | null {
  const m = /:(\d+):(\d+)-(?:(\d+):)?(\d+)$/.exec(s);
  if (!m) return null;
  const l1 = Number(m[1]);
  return { l1, c1: Number(m[2]), l2: m[3] ? Number(m[3]) : l1, c2: Number(m[4]) };
}

interface StatementText { text: string; offsetOf: (span: string) => [number, number] | null }

// The statement as one line of text, and where a span of it lies in that line.
function statementText(source: string, span: string): StatementText | null {
  const r = spanRange(span);
  if (!r) return null;
  const lines = source.split("\n");
  const starts: number[] = [];
  let at = 0;
  for (const l of lines) { starts.push(at); at += l.length + 1; }
  const off = (l: number, c: number) => (starts[l - 1] ?? 0) + c - 1;
  const from = off(r.l1, r.c1), to = off(r.l2, r.c2);
  const text = source.slice(from, to).replace(/\n/g, " ");
  return {
    text,
    offsetOf: (s: string) => {
      const q = spanRange(s);
      if (!q) return null;
      // the item without the parentheses around it
      let [a, b] = [off(q.l1, q.c1), off(q.l2, q.c2)];
      if (source[a] === "(" && source[b - 1] === ")") { a++; b--; }
      return [a - from, b - from];
    },
  };
}

// The statement, wrapped between its items where it is long, with the
// ranges the stage reads underlined.
function statementNodes(st: StatementText, marks: [number, number][], x: number, y: number,
  theme: Theme): { nodes: SvgNode[]; height: number } {
  const t = st.text;
  const MAX = Math.floor(TEXT_W / MONO_CHAR);
  const breaks: number[] = [0];
  let last = 0;
  if (t.length > MAX) {
    let i = t.indexOf(") (");
    while (i >= 0) {
      const next = t.indexOf(") (", i + 1);
      if ((next < 0 ? t.length : next + 1) - last > MAX - 2) { breaks.push(i + 2); last = i + 2; }
      i = next;
    }
  }
  breaks.push(t.length);
  const nodes: SvgNode[] = [];
  for (let b = 0; b + 1 < breaks.length; b++) {
    const [s, e] = [breaks[b]!, breaks[b + 1]!];
    const parts: SvgNode[] = [];
    if (b > 0) parts.push(el("tspan", {}, [], "  "));
    let at = s;
    for (const [m0, m1] of [...marks].sort((p, q) => p[0] - q[0])) {
      const from = Math.max(m0, at), to = Math.min(m1, e);
      if (to <= from) continue;
      if (from > at) parts.push(el("tspan", {}, [], t.slice(at, from)));
      parts.push(el("tspan", { "font-weight": 700, "text-decoration": "underline", "data-kind": "reads" },
        [], t.slice(from, to)));
      at = to;
    }
    if (at < e) parts.push(el("tspan", {}, [], t.slice(at, e)));
    nodes.push(el("text", { x, y: y + b * (LINE - 2), "font-family": MONO_FAMILY,
      "font-size": MONO, fill: theme.ink, "xml:space": "preserve", "data-kind": "statement" }, parts));
  }
  return { nodes, height: (breaks.length - 1) * (LINE - 2) };
}

// ---- text rows ----

interface Run { text: string; bold?: boolean }
interface Line { glyphs: [number, GlyphState][]; runs: Run[]; grey?: boolean }
interface Row { label: string; lines: Line[] }

const plain = (s: string): Line => ({ glyphs: [], runs: [{ text: s }] });

// One line of a row, broken to the width at spaces; a glyph stands before the
// first piece and the continuation lines up with the text after it.
function lineNodes(line: Line, x: number, y: number, width: number, theme: Theme, k0: string):
  { nodes: SvgNode[]; height: number } {
  const gw = line.glyphs.length ? line.glyphs.length * (2 * GLYPH_R + 3) + 5 : 0;
  const chars = Math.max(10, Math.floor((width - gw) / CHAR));
  // words keep their run, so a bold verdict stays bold across a break
  const words: Run[] = line.runs.flatMap((r) =>
    r.text.split(/(?<= )/).filter(Boolean).map((w) => ({ text: w, bold: r.bold ?? false })));
  const rows: Run[][] = [[]];
  let n = 0;
  for (const w of words) {
    if (n + w.text.trimEnd().length > chars && n > 0) { rows.push([]); n = 0; }
    rows[rows.length - 1]!.push(w);
    n += w.text.length;
  }
  const fill = line.grey ? theme.flat : theme.ink;
  const nodes: SvgNode[] = [];
  line.glyphs.forEach(([k, s], i) =>
    nodes.push(...glyph(x + GLYPH_R + i * (2 * GLYPH_R + 3), y - 4.5, k, s, theme, GLYPH_R, "row-number")));
  rows.forEach((ws, r) => {
    const spans: SvgNode[] = [];
    for (const w of ws) {
      const prev = spans[spans.length - 1];
      if (prev && (prev.attrs["font-weight"] === 700) === !!w.bold) prev.text = (prev.text ?? "") + w.text;
      else spans.push(el("tspan", w.bold ? { "font-weight": 700 } : {}, [], w.text));
    }
    const lastSpan = spans[spans.length - 1];
    if (lastSpan?.text) lastSpan.text = lastSpan.text.trimEnd();
    nodes.push(el("text", { x: x + gw, y: y + r * LINE, "font-size": FONT, fill, "data-row": k0,
      "xml:space": "preserve" }, spans));
  });
  return { nodes, height: rows.length * LINE };
}

function rowsNodes(rows: Row[], x: number, y: number, theme: Theme): { nodes: SvgNode[]; height: number } {
  const nodes: SvgNode[] = [];
  let h = 0;
  for (const row of rows) {
    nodes.push(el("text", { x, y: y + h, "font-size": FONT, "font-weight": 700, fill: theme.ink,
      "data-kind": "row-label" }, [], row.label));
    for (const line of row.lines) {
      const r = lineNodes(line, x + LABEL_W, y + h, TEXT_W - LABEL_W, theme, row.label.toLowerCase());
      nodes.push(...r.nodes);
      h += r.height;
    }
    h += 6;
  }
  return { nodes, height: h };
}

// ---- values ----

// Values with as many decimals as it takes to tell two different ones apart,
// at least two; values that print alike are equal in the exact comparison.
function valueFormat(values: number[]): (x: number) => string {
  let d = 2;
  const differ = (x: number, y: number) => Math.abs(x - y) > 1e-9;
  while (d < 8 && values.some((x, i) => values.some((y, j) =>
    j > i && differ(x, y) && x.toFixed(d) === y.toFixed(d)))) d++;
  return (x: number) => x.toFixed(d);
}

// Degrees without decimals where every angle is whole.
function degreeFormat(values: number[]): (x: number) => string {
  if (values.every((x) => Math.abs(x - Math.round(x)) < 1e-6)) return (x) => `${Math.round(x)}°`;
  const f = valueFormat(values);
  return (x) => `${f(x)}°`;
}

// ---- the figure ----

interface Ctx {
  scene: FoldScene; entry: TraceEntry; theme: Theme; area: Area;
  cands: TraceCandidate[];        // the candidates, numbered from 1 in this order
  numberAt: Vec2[];               // where each candidate's number stands
  corners: Set<string>;           // the paper's corners, which the paper names
  used: Set<string>;              // the legend entries the figure uses
  keptStyle: "valley" | "mountain" | "mark";
  lastStage: number;              // the last stage that has a row
  checks: boolean;
}

// A candidate's line on the paper in its state, with its number outside the
// paper at one end.
function candidateNodes(cx: Ctx, k: number, state: GlyphState): SvgNode[] {
  const { area, theme } = cx;
  const c = cx.cands[k]!;
  const colour = stroke(theme, k);
  const width = state === "out" ? 1 : 2.6;
  const dash: Record<string, string> = state !== "kept" ? {}
    : cx.keptStyle === "valley" ? { "stroke-dasharray": "7 4" }
    : cx.keptStyle === "mountain" ? { "stroke-dasharray": "9 3 2 3" }
    : { "stroke-dasharray": "1.5 3.5" };
  const nodes: SvgNode[] = onFaces(c.line, area.faces).map(([p, q]) =>
    seg(area, p, q, { stroke: colour, "stroke-width": width, ...dash, "data-kind": "candidate",
      "data-index": k + 1, "data-status": state }));
  const at = cx.numberAt[k];
  const ends = chord(c.line, area.faces);
  if (at && ends) {
    const end = dist(ends[0], at) < dist(ends[1], at) ? ends[0] : ends[1];
    const [x1, y1] = P(area, end), [x2, y2] = P(area, at);
    const l = Math.hypot(x2 - x1, y2 - y1) || 1;
    nodes.push(el("line", { x1, y1, x2: f2(x2 - ((x2 - x1) / l) * GLYPH_R * 1.2),
      y2: f2(y2 - ((y2 - y1) / l) * GLYPH_R * 1.2), stroke: colour, "stroke-width": 1 }));
    nodes.push(...glyph(x2, y2, k, state, theme, GLYPH_R * 1.2));
  }
  cx.used.add(state === "out" ? "removed" : state === "kept" ? "kept" : "candidate");
  return nodes;
}

// Where each number stands: outside the paper past one end of the line,
// each at the end farthest from the numbers already placed; the first takes
// the lower end, then the left one.
function placeNumbers(cands: TraceCandidate[], area: Area): Vec2[] {
  const out: Vec2[] = [];
  const off = 34 / area.scale;
  for (const c of cands) {
    const ends = chord(c.line, area.faces);
    if (!ends) { out.push([area.lay.minX, area.lay.minY]); continue; }
    const d = unit(sub(ends[1], ends[0]));
    const options: Vec2[] = [sub(ends[0], mul(d, off)), add(ends[1], mul(d, off))];
    const score = (p: Vec2) => out.length === 0 ? -(p[1] * 10 + p[0])
      : Math.min(...out.map((q) => dist(p, q)));
    options.sort((p, q) => score(q) - score(p));
    out.push(options[0]!);
  }
  return out;
}

// The name of an object of a stage, and the line or point it reads, drawn
// thin and solid in slate. A paper edge is drawn as a rail inside the paper.
function readNodes(cx: Ctx, o: { name: string; point: Vec2 | null; segments: [Vec2, Vec2][] },
  label = o.name): SvgNode[] {
  const { area, theme } = cx;
  const colour = slate(theme);
  const nodes: SvgNode[] = [];
  if (o.point) {
    const [x, y] = P(area, o.point);
    nodes.push(el("circle", { cx: x, cy: y, r: 3.5, fill: colour, "data-kind": "reads" }));
    // a paper corner carries its name already
    if (!cx.corners.has(label)) nodes.push(text(x + 7, y - 7, label, colour, theme, { "data-kind": "reads-label" }));
    cx.used.add("reads");
    return nodes;
  }
  const segs = o.segments.filter(([p, q]) => dist(p, q) > EPS);
  if (!segs.length) return nodes;
  const edge = segs.every((s) => isEdge(s, area.faces));
  let longest = segs[0]!;
  for (const s of segs) {
    if (dist(s[0], s[1]) > dist(longest[0], longest[1])) longest = s;
    if (edge) {
      const inward = inwardNormal(s, area.faces);
      const off = mul(inward, 5 / area.scale);
      nodes.push(seg(area, add(s[0], off), add(s[1], off), { stroke: colour, "stroke-width": 1.3,
        "data-kind": "edge-reads" }));
    } else {
      nodes.push(seg(area, s[0], s[1], { stroke: colour, "stroke-width": 1.4, "data-kind": "reads" }));
    }
  }
  cx.used.add(edge ? "edge" : "reads");
  const at = add(longest[0], mul(sub(longest[1], longest[0]), edge ? 0.5 : 0.22));
  const n = edge ? inwardNormal(longest, area.faces) : unit([-(longest[1][1] - longest[0][1]), longest[1][0] - longest[0][0]]);
  const [x, y] = P(area, add(at, mul(n, 14 / area.scale)));
  nodes.push(text(x - 8, y + 4, label, colour, theme, { "data-kind": "reads-label" }));
  return nodes;
}

function isEdge([p, q]: [Vec2, Vec2], faces: Vec2[][]): boolean {
  const m = mid(p, q);
  const n = unit([-(q[1] - p[1]), q[0] - p[0]]);
  const e = 1e-3;
  return onPaper(add(m, mul(n, e)), faces) !== onPaper(sub(m, mul(n, e)), faces);
}

function inwardNormal([p, q]: [Vec2, Vec2], faces: Vec2[][]): Vec2 {
  const n = unit([-(q[1] - p[1]), q[0] - p[0]]);
  return onPaper(add(mid(p, q), mul(n, 1e-3)), faces) ? n : mul(n, -1);
}

// The `toward` or `moving` target: a point as a filled diamond, a line as
// what the stage reads, both labelled with the item.
function targetNodes(cx: Ctx, which: "toward" | "moving"): SvgNode[] {
  const { entry, area, theme } = cx;
  const name = which === "toward" ? entry.towardName : entry.movingName;
  if (!name) return [];
  const point = which === "toward" ? entry.toward : entry.movingPoint;
  if (point) {
    const [x, y] = P(area, point);
    cx.used.add("target");
    return [
      el("path", { d: `M ${x} ${y - 7} L ${x + 7} ${y} L ${x} ${y + 7} L ${x - 7} ${y} Z`, fill: theme.ink,
        stroke: theme.background, "stroke-width": 1.5, "data-kind": "target" }),
      // left of the diamond near the right edge of the drawing
      x > area.lay.W - 90
        ? text(x - 10, y - 9, `${which} ${name}`, theme.ink, theme, { "data-kind": "target-label", "text-anchor": "end" })
        : text(x + 10, y - 9, `${which} ${name}`, theme.ink, theme, { "data-kind": "target-label" }),
    ];
  }
  const segs = which === "toward" ? entry.towardSegments
    : entry.operands.find((o) => o.name === name)?.segments ?? [];
  return readNodes(cx, { name, point: null, segments: segs }, `${which} ${name}`);
}

// The paper on the side of a line that folds over.
function foldingSide(c: TraceCandidate, faces: Vec2[][]): Vec2[][] {
  const [a, b, k] = c.line;
  const s = c.side!;
  return faces.map((f) => clipHalfPlane(f, [s * a, s * b], s * k)).filter((p) => p.length >= 3);
}

// Hatching over the side that folds over, at the candidate's own angle, with
// its number inside.
function hatchNodes(cx: Ctx, k: number, region: Vec2[][]): SvgNode[] {
  const { area, theme } = cx;
  const colour = stroke(theme, k);
  const ang = ((HATCH_ANGLES[k % HATCH_ANGLES.length]!) * Math.PI) / 180;
  const d: Vec2 = [Math.cos(ang), Math.sin(ang)];
  const n: Vec2 = [-d[1], d[0]];
  const step = 7 / area.scale;
  const nodes: SvgNode[] = [];
  for (const poly of region) {
    const proj = poly.map((p) => p[0] * n[0] + p[1] * n[1]);
    const lo = Math.min(...proj), hi = Math.max(...proj);
    for (let t = Math.ceil(lo / step) * step; t <= hi; t += step) {
      const s = clipLineToPoly(n[0], n[1], t, poly);
      if (s) nodes.push(seg(area, s[0], s[1], { stroke: colour, "stroke-width": 0.8, opacity: 0.8 }));
    }
    nodes.push(el("polygon", { points: poly.map((p) => P(area, p).join(",")).join(" "), fill: colour,
      "fill-opacity": 0.07, stroke: "none", "data-kind": "folds-over", "data-index": k + 1 }));
  }
  const largest = [...region].sort((p, q) => area2(q) - area2(p))[0];
  if (largest) {
    const c = centroid(largest);
    const [x, y] = P(area, c);
    const dy = (k - 1) * 14;
    nodes.push(el("circle", { cx: x, cy: y + dy, r: GLYPH_R + 3, fill: theme.background, stroke: "none" }));
    nodes.push(...glyph(x, y + dy, k, "on", theme, GLYPH_R, "tag"));
  }
  cx.used.add("hatch");
  return nodes;
}

const area2 = (poly: Vec2[]) => Math.abs(poly.reduce((s, p, i) => {
  const q = poly[(i + 1) % poly.length]!;
  return s + p[0] * q[1] - q[0] * p[1];
}, 0));
const centroid = (poly: Vec2[]): Vec2 => mul(poly.reduce((s, p) => add(s, p), [0, 0] as Vec2), 1 / poly.length);

// An angle between two lines at their meeting point, as an arc in the
// candidate's colour between the two directions nearest `toward`, with its
// value.
function angleArc(cx: Ctx, at: Vec2, u: Vec2, v: Vec2, r: number, k: number, label: string,
  ticks = false): SvgNode[] {
  const { area, theme } = cx;
  const colour = stroke(theme, k);
  const [x, y] = P(area, at);
  const a1 = Math.atan2(-u[1], u[0]);
  let delta = Math.atan2(-v[1], v[0]) - a1;
  while (delta > Math.PI) delta -= 2 * Math.PI;
  while (delta <= -Math.PI) delta += 2 * Math.PI;
  const pts = Array.from({ length: 25 }, (_, i) => {
    const a = a1 + (delta * i) / 24;
    return `${f2(x + r * Math.cos(a))},${f2(y + r * Math.sin(a))}`;
  });
  const nodes: SvgNode[] = [el("polyline", { points: pts.join(" "), fill: "none", stroke: colour,
    "stroke-width": 1.3, "data-kind": "angle" })];
  if (ticks) {
    for (const t of [0.25, 0.75]) {
      const a = a1 + delta * t;
      nodes.push(el("line", { x1: f2(x + (r - 4) * Math.cos(a)), y1: f2(y + (r - 4) * Math.sin(a)),
        x2: f2(x + (r + 4) * Math.cos(a)), y2: f2(y + (r + 4) * Math.sin(a)), stroke: colour, "stroke-width": 1.3 }));
    }
  }
  const am = a1 + delta / 2;
  const lx = x + (r + 12) * Math.cos(am), ly = y + (r + 12) * Math.sin(am);
  nodes.push(text(lx, ly + 4, label, textColour(k), theme,
    { "text-anchor": Math.cos(am) < -0.3 ? "end" : Math.cos(am) > 0.3 ? "start" : "middle",
      "data-kind": "angle-label" }));
  cx.used.add("construction");
  return nodes;
}

// The direction of a line pointing up, or right where it runs level.
function upward(line: LineCoeffs): Vec2 {
  const d = direction(line);
  return d[1] < -1e-9 || (Math.abs(d[1]) <= 1e-9 && d[0] < 0) ? mul(d, -1) : d;
}

// Where the angle a bisector halves lies, as a reader names it.
function whereHalves(line: LineCoeffs): string {
  const [x, y] = upward(line);
  let t = (Math.atan2(y, x) * 180) / Math.PI;
  if (t > 170) t -= 180;
  if (t <= 10) return "on the right";
  if (t >= 80 && t <= 100) return "at the top";
  return t < 80 ? "at the top right" : "at the top left";
}

const count = (n: number) => ["no", "one", "two", "three", "four"][n] ?? String(n);

// ---- stage 0 ----

function stage0(cx: Ctx): { squares: SvgNode[][]; rows: Row[] } {
  const { entry, area, theme, cands } = cx;
  const nodes: SvgNode[] = [];
  const rows: Row[] = [];
  const named = cands.map((_, k) => k);
  const operand = (i: number) => entry.operands[i];
  const lineOf = (o: TraceObject | undefined): LineCoeffs | null => {
    const s = o?.segments.find(([p, q]) => dist(p, q) > EPS);
    return s ? lineThrough(s[0], s[1]) : null;
  };
  const yields: Line[] = [];
  let constructs = "The construction determines one line.";
  const axiom = entry.axiom;
  const labelled: [number, number][] = [];
  if (axiom === "axiom5" && cands.length === 2) {
    const [o1, o2] = [operand(0), operand(1)];
    const [l1, l2] = [lineOf(o1), lineOf(o2)];
    const x = l1 && l2 ? meet(l1, l2) : null;
    constructs = `The crease mirrors ${o1?.name} onto ${o2?.name}, so it makes the same angle with both: `
      + "it halves an angle where they cross. Two crossing lines make two angles, so there are two candidates.";
    cands.forEach((c, k) => {
      yields.push({ glyphs: [[k, "on"]], runs: [{ text: `halves the angle ${whereHalves(c.line)}` }] });
      if (!x || !l1 || !l2) return;
      const dc = upward(c.line);
      const pick = (l: LineCoeffs) => { const d = direction(l); return d[0] * dc[0] + d[1] * dc[1] >= 0 ? d : mul(d, -1); };
      const deg = (Math.acos(Math.min(1, Math.abs(direction(l1)[0] * dc[0] + direction(l1)[1] * dc[1]))) * 180) / Math.PI;
      const v = degreeFormat([deg])(deg);
      nodes.push(...angleArc(cx, x, pick(l1), pick(l2), 34 + 12 * k, k, `${v} | ${v}`, true));
    });
  } else if (axiom === "axiom6" && entry.circle) {
    const { centre, through } = entry.circle;
    const r = dist(centre, through);
    const [x, y] = P(area, centre);
    const point = entry.operands[0], target = entry.operands[1], pivot = entry.operands[2];
    constructs = `Every crease through ${pivot?.name} that folds ${point?.name} onto ${target?.name} `
      + `is the perpendicular bisector of ${point?.name} and one landing: a point of ${target?.name} `
      + `on the circle about ${pivot?.name} through ${point?.name}.`;
    nodes.push(el("circle", { cx: x, cy: y, r: f2(r * area.scale), fill: "none", stroke: slate(theme),
      "stroke-width": 1.1, "data-kind": "construction" }));
    const tl = lineOf(target);
    if (tl) {
      const s = clipLineToPoly(tl[0], tl[1], tl[2], frameRect(area));
      if (s) nodes.push(seg(area, s[0], s[1], { stroke: slate(theme), "stroke-width": 1, "data-kind": "construction" }));
    }
    const lab = add(centre, mul(unit([1, -1]), r));
    const [lx, ly] = P(area, lab);
    nodes.push(text(lx + 6, ly + 4, `circle about ${pivot?.name}`, slate(theme), theme),
      text(lx + 6, ly + 19, `through ${point?.name}`, slate(theme), theme));
    cx.used.add("construction");
    cands.forEach((c, k) => {
      if (!c.landing) return;
      const colour = stroke(theme, k);
      nodes.push(seg(area, through, c.landing, { stroke: colour, "stroke-width": 1, "data-kind": "landing-line" }));
      const m = mid(through, c.landing);
      const u = unit(sub(c.landing, through)), v = direction(c.line);
      const s = 6 / area.scale;
      const sq = [m, add(m, mul(u, s)), add(add(m, mul(u, s)), mul(v, s)), add(m, mul(v, s))];
      nodes.push(el("polyline", { points: sq.slice(1).map((p) => P(area, p).join(",")).join(" "), fill: "none",
        stroke: colour, "stroke-width": 1 }));
      const [lx2, ly2] = P(area, c.landing);
      nodes.push(el("circle", { cx: lx2, cy: ly2, r: 5, fill: theme.background, stroke: colour,
        "stroke-width": 2, "data-kind": "landing" }));
      nodes.push(...glyph(lx2 + 14, ly2 - 4, k, "on", theme, 6.5, "tag"));
    });
    cx.used.add("landing-line");
    yields.push({ glyphs: named.map((k) => [k, "on"] as [number, GlyphState]),
      runs: [{ text: `one crease for each landing of ${point?.name}` }] });
  } else if (axiom === "axiom7") {
    entry.conics.forEach((conic) => {
      parabola(conic, area.lay).forEach((run, r) => {
        nodes.push(el("polyline", { points: run.map((p) => P(area, p).join(",")).join(" "), fill: "none",
          stroke: slate(theme), "stroke-width": 1.1, "data-kind": "construction" }));
        const focus = entry.operands.find((o) => o.point && dist(o.point, conic.focus) < 1e-7);
        const dir = entry.operands.find((o) => !o.point && o.segments.some(([p, q]) =>
          Math.abs(sideOf(conic.directrix, p)) < 1e-7 && Math.abs(sideOf(conic.directrix, q)) < 1e-7));
        // named under its lowest point, clear of the label before it
        const at = [...run].sort((p, q) => p[1] - q[1])[0];
        if (r === 0 && at) {
          let [x, y] = P(area, at);
          y = Math.max(y + 16, area.lay.ty(area.lay.minY) + 16);
          while (labelled.some(([lx, ly]) => Math.abs(lx - x) < 130 && Math.abs(ly - y) < 14)) y += 15;
          labelled.push([x, y]);
          nodes.push(text(x, y, `parabola: ${focus?.name ?? "focus"}, ${dir?.name ?? "directrix"}`,
            slate(theme), theme, { "text-anchor": "middle", "data-kind": "construction-label" }));
        }
      });
    });
    cx.used.add("construction");
    const [p1, l1, p2, l2] = entry.operands.map((o) => o.name);
    constructs = `Every crease that folds ${p1} onto ${l1} touches the parabola with focus ${p1} and `
      + `directrix ${l1}; the same holds for ${p2} and ${l2}. A crease that does both touches both `
      + "parabolas: their common tangents, the roots of a cubic, up to three.";
    yields.push({ glyphs: named.map((k) => [k, "on"] as [number, GlyphState]),
      runs: [{ text: cands.length === 1 ? "the one common tangent" : `the ${count(cands.length)} common tangents` }] });
  }
  if (!yields.length) {
    yields.push({ glyphs: named.map((k) => [k, "on"] as [number, GlyphState]),
      runs: [{ text: cands.length === 1 ? "the one line of the construction" : `${count(cands.length)} lines` }] });
  }
  for (const o of entry.operands) nodes.push(...readNodes(cx, o));
  const last = cx.lastStage === 0;
  cands.forEach((c, k) => nodes.push(...candidateNodes(cx, k, last && c.selected ? "kept" : "on")));
  if (cx.checks) rows.push({ label: "Constructs", lines: [plain(constructs)] });
  rows.push({ label: "Yields", lines: yields });
  return { squares: [nodes], rows };
}

// ---- stage 1 ----

function stage1(cx: Ctx): { squares: SvgNode[][]; rows: Row[] } {
  const { entry, area, cands } = cx;
  const nodes: SvgNode[] = [];
  const h = entry.headingLine!, name = entry.headingName ?? "";
  nodes.push(...readNodes(cx, { name, point: null, segments: onFaces(h, area.faces) }, `heading ${name}`));
  const here = cands.map((c, k) => [c, k] as const).filter(([c]) => reaches(c, "heading"));
  const fmt = degreeFormat(here.map(([c]) => c.angle ?? 0));
  const passing = here.filter(([c]) => c.removedAt !== "heading");
  const lines: Line[] = [];
  for (const [c, k] of here) {
    const out = c.removedAt === "heading";
    const kept = cx.lastStage === 1 && c.selected;
    nodes.push(...candidateNodes(cx, k, out ? "out" : kept ? "kept" : "on"));
    const x = meet(c.line, h);
    if (x && c.angle && c.angle > 1e-6) {
      const dc = direction(c.line), dh = direction(h);
      const toward = (d: Vec2) => onPaper(add(x, mul(d, 0.05)), area.faces) ? d : mul(d, -1);
      nodes.push(...angleArc(cx, x, toward(dh), toward(dc), 24 + 12 * k, k, fmt(c.angle)));
    }
    const tie = !out && passing.length > 1 && passing[passing.length - 1]![1] === k ? ", a tie passes on" : "";
    lines.push({ glyphs: [[k, out ? "out" : "on"]], grey: out,
      runs: [{ text: out ? "eliminated" : "passes", bold: true },
        { text: `: ${fmt(c.angle ?? 0)} to ${name}${tie}` }] });
  }
  const rows: Row[] = [];
  if (cx.checks) {
    rows.push({ label: "Checks", lines: [plain(`Which candidate makes the smallest angle with ${name}? Its position plays no part.`)] });
  }
  rows.push({ label: "Result", lines });
  return { squares: [nodes], rows };
}

// ---- stage 2 ----

function stage2(cx: Ctx): { squares: SvgNode[][]; rows: Row[] } {
  const { entry, area, cands } = cx;
  const nodes: SvgNode[] = [];
  const t = entry.towardName, m = entry.movingName;
  const here = cands.map((c, k) => [c, k] as const).filter(([c]) => reaches(c, "side"));
  for (const [c, k] of here) {
    if (c.removedAt !== "side" && c.side !== null) nodes.push(...hatchNodes(cx, k, foldingSide(c, area.faces)));
  }
  const lines: Line[] = [];
  for (const [c, k] of here) {
    const out = c.removedAt === "side";
    const kept = cx.lastStage === 2 && c.selected;
    nodes.push(...candidateNodes(cx, k, out ? "out" : kept ? "kept" : "on"));
    let why: string;
    if (!out) why = `${c.sideFrom === "moving" ? m : t} lies on one side`;
    else if (c.removedBy === "toward") {
      why = entry.toward ? `${t} lies on it, so it names no side` : `${t} crosses it, so it names no side`;
    } else {
      const p = entry.movingPoint;
      const conflict = t && (p ? Math.abs(sideOf(c.line, p)) > 1e-9 : false);
      why = conflict ? `toward ${t} and moving ${m} name the same side`
        : p ? `${m} lies on it, so it names no side` : `${m} crosses it, so it names no side`;
    }
    lines.push({ glyphs: [[k, out ? "out" : "on"]], grey: out,
      runs: [{ text: out ? "eliminated" : "passes", bold: true }, { text: `: ${why}` }] });
  }
  if (t) nodes.push(...targetNodes(cx, "toward"));
  if (m) nodes.push(...targetNodes(cx, "moving"));
  const rows: Row[] = [];
  if (cx.checks) {
    rows.push({ label: "Checks", lines: [plain(
      t && m ? `Which side of each line holds ${t}? It stays, and ${m} has to lie on the other side, which folds over.`
      : t ? `Which side of each line holds ${t}? It stays; the other side folds over.`
      : `Which side of each line holds ${m}? It folds over.`)] });
  }
  rows.push({ label: "Result", lines });
  return { squares: [nodes], rows };
}

// ---- stage 3 ----

// The attempt a figure draws for a candidate: the side it folds with, else
// the first side tried.
function attemptOf(c: TraceCandidate) {
  return c.attempts.find((a) => a.side === c.side) ?? c.attempts[0] ?? null;
}

const zeroLength = (s: [Vec2, Vec2][]) => s.every(([p, q]) => dist(p, q) < 1e-9);
const prime = (name: string) => `${name}′`;

// A motion drawn: a point as a filled dot, an arrow and a ring where it
// lands; a piece of line as a filled bar, an arrow and an outlined bar.
function motionNodes(cx: Ctx, k: number, m: Motion, name: string, line: LineCoeffs,
  labelled = true): SvgNode[] {
  const { area, theme } = cx;
  const colour = stroke(theme, k);
  const nodes: SvgNode[] = [];
  const src = m.source.filter(([p, q]) => dist(p, q) >= 0 && Number.isFinite(p[0]));
  const img = m.image;
  const barHalf = 11 / area.scale;
  const bar = (p: Vec2, d: Vec2): [Vec2, Vec2] => [sub(p, mul(d, barHalf)), add(p, mul(d, barHalf))];
  const filledBar = ([p, q]: [Vec2, Vec2]) =>
    seg(area, p, q, { stroke: colour, "stroke-width": 4.5, "data-kind": "moves" });
  const hollowBar = ([p, q]: [Vec2, Vec2]) => [
    seg(area, p, q, { stroke: colour, "stroke-width": 6, "data-kind": "lands" }),
    seg(area, p, q, { stroke: theme.background, "stroke-width": 3 }),
  ];
  let from: Vec2, to: Vec2;
  if (zeroLength(src) && name.startsWith(".")) {
    // a point
    from = src[0]![0]; to = img[0]![0];
    const [x, y] = P(area, from);
    nodes.push(el("circle", { cx: x, cy: y, r: 4.5, fill: colour, "data-kind": "moves" }));
    cx.used.add("moves-point");
  } else if (zeroLength(src)) {
    // the place of a line that lands on a point
    from = src[0]![0]; to = img[0]![0];
    const d = direction(line);
    nodes.push(filledBar(bar(from, d)));
    const [x, y] = P(area, from);
    nodes.push(el("circle", { cx: x, cy: y, r: 3.5, fill: colour }));
    const dImg = direction(lineThrough(reflectAcross(cx, k, add(from, d)), reflectAcross(cx, k, from)));
    nodes.push(...hollowBar(bar(to, dImg)));
    cx.used.add("moves-line");
  } else {
    // the part of a line that folds over, and its image
    for (const s of src) nodes.push(filledBar(s));
    for (const s of img) nodes.push(...hollowBar(s));
    const far = (ss: [Vec2, Vec2][]) => {
      const c = cx.cands[k]!.line;
      return ss.flat().sort((p, q) => Math.abs(sideOf(c, q)) - Math.abs(sideOf(c, p)))[0]!;
    };
    from = far(src); to = far(img);
    cx.used.add("moves-line");
  }
  const [x1, y1] = P(area, from), [x2, y2] = P(area, to);
  const a = arrowPx(x1, y1, x2, y2, colour, 1.5);
  nodes.push(...a.nodes);
  if (zeroLength(src) && name.startsWith(".")) {
    nodes.push(el("circle", { cx: x2, cy: y2, r: 5, fill: theme.background, stroke: colour,
      "stroke-width": 2.2, "data-kind": "lands" }));
  }
  nodes.push(...glyph(a.at[0], a.at[1], k, "on", theme, 6.5, "tag"));
  if (labelled) {
    // a point's image is named beside its ring, a line's at the middle of
    // its image, off the line
    const at = zeroLength(src) && name.startsWith(".") ? [x2 + 9, y2 + 16]
      : (() => {
        const [p, q] = img.length ? img[0]! : [to, to];
        const [mx, my] = P(area, mid(p, q));
        const [ux, uy] = [q[0] - p[0], -(q[1] - p[1])];
        const l = Math.hypot(ux, uy) || 1;
        return [mx - (uy / l) * 16 - 8, my + (ux / l) * 16 + 4];
      })();
    nodes.push(text(at[0]!, at[1]!, prime(name), textColour(k), theme, { "data-kind": "image-label" }));
  }
  return nodes;
}

function reflectAcross(cx: Ctx, k: number, p: Vec2): Vec2 {
  return reflect(p, cx.cands[k]!.line);
}

// A motion the paper cannot make: a cross where the missing paper would be,
// a thin arrow, and a label naming what is missing.
function missingNodes(cx: Ctx, k: number, from: Vec2, to: Vec2, cross: Vec2, label: string): SvgNode[] {
  const { area, theme } = cx;
  const colour = stroke(theme, k);
  const [x1, y1] = P(area, from), [x2, y2] = P(area, to), [cxp, cyp] = P(area, cross);
  cx.used.add("missing");
  return [
    ...arrowPx(x1, y1, x2, y2, colour, 1).nodes,
    el("path", { d: `M ${cxp - 6} ${cyp - 6} L ${cxp + 6} ${cyp + 6} M ${cxp - 6} ${cyp + 6} L ${cxp + 6} ${cyp - 6}`,
      stroke: colour, "stroke-width": 1.8, "data-kind": "missing" }),
    text(cxp + 10, cyp - 8, label, textColour(k), theme, { "data-kind": "missing-label" }),
  ];
}

interface Said { nodes: SvgNode[]; text: string }

// What one candidate's fold does with each alignment, drawn and said.
function movedOf(cx: Ctx, k: number, stage: "moved" | "landing"): Said {
  const { entry, area } = cx;
  const c = cx.cands[k]!;
  const a = attemptOf(c);
  const nodes: SvgNode[] = [];
  const said: string[] = [];
  entry.alignments.forEach((al, i) => {
    const meets = a?.alignments[i] ?? null;
    const [x, y] = al.objects;
    const m = a?.motions[i] ?? null;
    if ((meets === 0 || meets === 1) && m) {
      const mover = meets === 0 ? x : y, target = meets === 0 ? y : x;
      const ml = moverLine(mover);
      nodes.push(...motionNodes(cx, k, m, mover.name, ml ?? c.line, stage === "moved"));
      if (stage === "moved") {
        if (!mover.point && target.point) {
          nodes.push(...readNodes(cx, target));
          said.push(entry.alignments.length > 1 ? `${mover.name} lands on ${target.name}`
            : `${mover.name} folds over, and its paper at the dot lands on ${target.name}`);
        } else said.push(mover.point ? `${mover.name} lands on ${target.name}`
          : `${mover.name} folds over onto ${target.name}`);
      }
    } else if (meets === "already") {
      said.push(`${(x.point ? x : y).name} lies on the crease and on ${(x.point ? y : x).name} already`);
    } else if (stage === "moved" && c.side !== null) {
      // neither object reaches the other: name the paper that is missing
      const pt = x.point ? x : y.point ? y : null, ln = pt === x ? y : x;
      if (pt?.point && !ln.point) {
        const r = reflect(pt.point, c.line);
        const moves = sideOf(c.line, pt.point) * c.side > 0;
        nodes.push(...missingNodes(cx, k, moves ? pt.point : r, moves ? r : pt.point, r,
          `${ln.name} has no paper here`));
        said.push(moves ? `${pt.name} would land where ${ln.name} has no paper`
          : `${pt.name} stays, and the paper of ${ln.name} that would land on it lies beyond the edge`);
      } else said.push(`neither ${x.name} nor ${y.name} folds over onto the other`);
    } else if (stage === "moved") said.push(`neither side carries out ${x.name} onto ${y.name}`);
  });
  void area;
  return { nodes, text: said.join(", ") };
}

function moverLine(o: TraceObject): LineCoeffs | null {
  const s = o.segments.find(([p, q]) => dist(p, q) > EPS);
  return s ? lineThrough(s[0], s[1]) : null;
}

// Marks of several candidates cover each other where their boxes meet.
function overlap(boxes: [number, number, number, number][]): boolean {
  return boxes.some((b, i) => boxes.some((d, j) => j > i
    && b[0] < d[2] && d[0] < b[2] && b[1] < d[3] && d[1] < b[3]));
}

function boxOf(nodes: SvgNode[]): [number, number, number, number] {
  const xs: number[] = [], ys: number[] = [];
  const walk = (n: SvgNode) => {
    if (n.attrs["data-kind"] === "moves" || n.attrs["data-kind"] === "lands" || n.attrs["data-kind"] === "missing") {
      for (const [kx, ky] of [["x1", "y1"], ["x2", "y2"], ["cx", "cy"]] as const) {
        const x = Number(n.attrs[kx]), y = Number(n.attrs[ky]);
        if (Number.isFinite(x) && Number.isFinite(y)) { xs.push(x); ys.push(y); }
      }
    }
    n.children.forEach(walk);
  };
  nodes.forEach(walk);
  if (!xs.length) return [0, 0, 0, 0];
  return [Math.min(...xs) - 8, Math.min(...ys) - 8, Math.max(...xs) + 8, Math.max(...ys) + 8];
}

function stage3(cx: Ctx): { squares: SvgNode[][]; rows: Row[] } {
  const { entry, cands } = cx;
  const here = cands.map((c, k) => [c, k] as const).filter(([c]) => reaches(c, "moved"));
  const per = here.map(([c, k]) => {
    const out = c.removedAt === "moved";
    const kept = cx.lastStage === 3 && c.selected;
    const said = movedOf(cx, k, "moved");
    const objs = new Map<string, TraceObject>();
    for (const al of entry.alignments) for (const o of al.objects) if (!o.point) objs.set(o.name, o);
    const reads = [...objs.values()].flatMap((o) => readNodes(cx, o));
    return { c, k, out, said, reads, line: candidateNodes(cx, k, out ? "out" : kept ? "kept" : "on") };
  });
  const apart = per.length > 1 && overlap(per.map((p) => boxOf(p.said.nodes)));
  const squares = apart ? per.map((p) => [...p.reads, ...p.line, ...p.said.nodes])
    : [[...(per[0]?.reads ?? []), ...per.flatMap((p) => [...p.line, ...p.said.nodes])]];
  const lines: Line[] = per.map(({ c, k, out, said }) => {
    let tail = "";
    if (!out && c.sideFrom === "first") {
      const first = entry.alignments[0]?.objects[0]?.name ?? "the first object";
      tail = ` (either side carries it out; the side of ${first} folds over, as the statement reads)`;
    } else if (!out && c.sideFrom === "alone") tail = " (only this side carries it out)";
    return { glyphs: [[k, out ? "out" : "on"]], grey: out,
      runs: [{ text: out ? "eliminated" : "passes", bold: true }, { text: `: ${said.text}${tail}` }] };
  });
  const rows: Row[] = [];
  if (cx.checks) {
    rows.push({ label: "Checks", lines: [plain(
      "Does the fold carry out every alignment: an object on the folding side lands on the other's paper?"
      + (apart ? " One square per candidate, as their marks would cover each other." : ""))] });
  }
  rows.push({ label: "Result", lines });
  return { squares, rows };
}

// ---- stage 4 ----

function stage4(cx: Ctx): { squares: SvgNode[][]; rows: Row[] } {
  const { entry, area, theme, cands } = cx;
  const here = cands.map((c, k) => [c, k] as const).filter(([c]) => reaches(c, "landing"));
  const t = entry.towardName ?? "";
  const fmt = valueFormat(here.flatMap(([c]) => (c.distance === null ? [] : [c.distance])));
  const passing = here.filter(([c]) => c.removedAt !== "landing");
  const squares: SvgNode[][] = [];
  const lines: Line[] = [];
  for (const [c, k] of here) {
    const out = c.removedAt === "landing";
    const nodes: SvgNode[] = [];
    nodes.push(...movedOf(cx, k, "landing").nodes);
    nodes.push(...candidateNodes(cx, k, out ? "out" : c.selected ? "kept" : "on"));
    if (c.nearest && c.distance !== null) {
      const [p, q] = c.nearest;
      const colour = stroke(theme, k);
      const [x1, y1] = P(area, p), [x2, y2] = P(area, q);
      nodes.push(el("line", { x1, y1, x2, y2, stroke: colour, "stroke-width": 1.2, "data-kind": "distance" }),
        el("circle", { cx: x1, cy: y1, r: 3, fill: colour }));
      const label = fmt(c.distance);
      const w = label.length * 7 + 26;
      // the tag beside the middle of the distance, kept inside the drawing
      const mx = Math.min((x1 + x2) / 2, area.lay.W - w - 10), my = (y1 + y2) / 2 + 14;
      nodes.push(el("rect", { x: f2(mx + 6), y: f2(my - 10), width: w, height: 20, rx: 3,
        fill: theme.background, stroke: colour, "stroke-width": 1 }),
        ...glyph(mx + 16, my, k, "on", theme, 6.5, "tag"),
        text(mx + 26, my + 4.5, label, textColour(k), theme, { "font-weight": 700, "data-kind": "distance-label" }));
      cx.used.add("distance");
    }
    nodes.push(...targetNodes(cx, "toward"));
    squares.push(nodes);
    let say: string;
    if (c.subjectFolds === false) say = `does not fold ${entry.subject} over`;
    else if (c.landed && c.landed.length === 0) say = "lands nothing";
    else {
      const tie = !out && passing.length > 1 && passing[passing.length - 1]![1] === k ? ", a tie" : "";
      say = `${entry.subject ? `${entry.subject} ` : ""}lands ${fmt(c.distance ?? 0)} from ${t}${tie}`;
    }
    lines.push({ glyphs: [[k, out ? "out" : "on"]], grey: out,
      runs: [{ text: out ? "eliminated" : "passes", bold: true }, { text: `: ${say}` }] });
  }
  const rows: Row[] = [];
  if (cx.checks) {
    const s = entry.subject;
    rows.push({ label: "Checks", lines: [plain(s
      ? `(${s} toward ${t}) measures only ${s}: where does it land, and how far is that from ${t}? The nearest wins.`
      : `How far from ${t} do the objects of the alignments land? The nearest wins.`)] });
  }
  rows.push({ label: "Result", lines });
  return { squares: squares.length > 1 ? squares : [squares.flat()], rows };
}

const STAGE_FNS = [stage0, stage1, stage2, stage3, stage4];

// The part of the statement each stage reads.
function readSpans(entry: TraceEntry, s: number): string[] {
  const sp = entry.spans;
  const some = (x: string | null) => (x ? [x] : []);
  switch (s) {
    case 0: return sp.alignments;
    case 1: return some(sp.heading);
    case 2: return [...some(sp.toward), ...some(sp.moving)];
    case 3: return entry.alignments.flatMap((a) => some(a.span));
    default: return some(sp.toward);
  }
}

// ---- the closing block ----

function closing(cx: Ctx): Row[] {
  const { cands, scene, entry } = cx;
  const kept = cands.findIndex((c) => c.selected);
  if (kept >= 0) return [{ label: "Outcome", lines: [{ glyphs: [[kept, "kept"]], runs: [{ text: "holds", bold: true }] }] }];
  const open = cands.map((c, k) => [c, k] as const).filter(([c]) => c.removedAt === null);
  const rows: Row[] = [];
  if (open.length > 1) {
    const all = open.length === 2 ? "both hold" : `all ${count(open.length)} hold`;
    rows.push({ label: "Outcome", lines: [{ glyphs: open.map(([, k]) => [k, "on"] as [number, GlyphState]),
      runs: [{ text: all, bold: true }, { text: ": ambiguous" }] }] });
    rows.push({ label: "Next", lines: open.map(([c, k]) => ({ glyphs: [[k, "on"]] as [number, GlyphState][],
      runs: [{ text: c.suggestion ? `to keep it, add ${c.suggestion}` : "no single item keeps it alone" }] })) });
  } else {
    rows.push({ label: "Outcome", lines: [{ glyphs: [], runs: [{ text: "none holds", bold: true }] }] });
    const hint = scene.error?.statement === entry.statement ? scene.error.hint : null;
    if (hint) rows.push({ label: "Next", lines: [plain(hint)] });
  }
  return rows;
}

// ---- the legend ----

// The legend's entries in three groups: the states of a candidate, the paper
// and what the stages read, and the marks of the stages.
const LEGEND: [string, string][][] = [
  [["candidate", "a candidate, by its number"], ["removed", "removed by this stage"],
    ["kept", "the line kept, as the fold it makes"]],
  [["mark", "a mark (drawn, not folded)"], ["reads", "what this stage reads"],
    ["edge", "an edge this stage reads"], ["construction", "how the stage finds its candidates"],
    ["landing-line", "where a point can land, mirrored in the candidate"]],
  [["hatch", "the side that folds over"], ["target", "the toward or moving point"],
    ["moves-point", "a point that moves, and where it lands"],
    ["moves-line", "a piece of line that moves, and where it lands"],
    ["missing", "a motion the paper cannot make"], ["distance", "distance to the toward point"]],
];

function legendSample(kind: string, x: number, y: number, cx: Ctx): SvgNode[] {
  const { theme } = cx;
  const c0 = stroke(theme, 0), c1 = stroke(theme, 1);
  const s = slate(theme);
  const line = (attrs: Record<string, string | number>, x2 = x + 30) =>
    el("line", { x1: x, y1: y, x2, y2: y, ...attrs });
  switch (kind) {
    case "candidate": return [line({ stroke: c0, "stroke-width": 2.6 }, x + 18), ...glyph(x + 27, y, 0, "on", theme)];
    case "removed": return [line({ stroke: c0, "stroke-width": 1 }, x + 18), ...glyph(x + 27, y, 0, "out", theme)];
    case "kept": return [line({ stroke: c1, "stroke-width": 2.6, "stroke-dasharray": "7 4" }, x + 18),
      ...glyph(x + 27, y, 1, "kept", theme)];
    case "mark": return [line({ stroke: theme.flat, "stroke-width": 1.2, "stroke-dasharray": "2 2" })];
    case "reads": return [line({ stroke: s, "stroke-width": 1.4 }), el("circle", { cx: x + 15, cy: y, r: 3.5, fill: s })];
    case "edge": return [line({ stroke: theme.boundary, "stroke-width": 2.5 }),
      el("line", { x1: x, y1: y + 5, x2: x + 30, y2: y + 5, stroke: s, "stroke-width": 1.3 })];
    case "construction": return [el("path", { d: `M ${x} ${y + 5} Q ${x + 15} ${y - 9} ${x + 30} ${y + 5}`,
      fill: "none", stroke: s, "stroke-width": 1.1 })];
    case "landing-line": return [line({ stroke: c0, "stroke-width": 1 }),
      el("polyline", { points: `${x + 15},${y} ${x + 15},${y - 6} ${x + 21},${y - 6}`, fill: "none", stroke: c0, "stroke-width": 1 })];
    case "hatch": return [el("rect", { x, y: y - 7, width: 30, height: 14, fill: c0, "fill-opacity": 0.07,
      stroke: "none" }), ...[0, 7, 14, 21, 28].map((d) => el("line", { x1: x + d, y1: y + 7, x2: Math.min(x + d + 14, x + 30),
      y2: y + 7 - (Math.min(x + d + 14, x + 30) - (x + d)), stroke: c0, "stroke-width": 0.8 }))];
    case "target": return [el("path", { d: `M ${x + 15} ${y - 7} L ${x + 22} ${y} L ${x + 15} ${y + 7} L ${x + 8} ${y} Z`,
      fill: theme.ink })];
    case "moves-point": {
      const a = arrowPx(x + 5, y, x + 27, y, c0, 1.5, 0);
      return [el("circle", { cx: x + 3, cy: y, r: 4.5, fill: c0 }), ...a.nodes,
        el("circle", { cx: x + 34, cy: y, r: 5, fill: theme.background, stroke: c0, "stroke-width": 2.2 })];
    }
    case "moves-line": {
      const a = arrowPx(x + 16, y, x + 28, y, c0, 1.5, 0);
      return [line({ stroke: c0, "stroke-width": 4.5 }, x + 14), ...a.nodes,
        el("line", { x1: x + 32, y1: y, x2: x + 48, y2: y, stroke: c0, "stroke-width": 6, "stroke-linecap": "round" }),
        el("line", { x1: x + 32, y1: y, x2: x + 48, y2: y, stroke: theme.background, "stroke-width": 3, "stroke-linecap": "round" })];
    }
    case "missing": return [...arrowPx(x, y, x + 24, y, c0, 1, 0).nodes,
      el("path", { d: `M ${x + 26} ${y - 5} L ${x + 36} ${y + 5} M ${x + 26} ${y + 5} L ${x + 36} ${y - 5}`, stroke: c0, "stroke-width": 1.8 })];
    case "distance": return [line({ stroke: c0, "stroke-width": 1.2 }), el("circle", { cx: x, cy: y, r: 3, fill: c0 })];
    default: return [];
  }
}

function legendNodes(cx: Ctx, y0: number, width: number): { nodes: SvgNode[]; height: number } {
  const nodes: SvgNode[] = [];
  let y = y0;
  for (const group of LEGEND) {
    const items = group.filter(([k]) => cx.used.has(k));
    if (!items.length) continue;
    let x = 16;
    for (const [kind, label] of items) {
      const w = 60 + label.length * 6.6 + 24;
      if (x + w > width && x > 16) { x = 16; y += 24; }
      nodes.push(el("g", { "data-legend": kind }, [
        ...legendSample(kind, x, y - 4, cx),
        el("text", { x: x + 58, y, "font-size": 12.5, fill: cx.theme.ink }, [], label),
      ]));
      x += w;
    }
    y += 28;
  }
  return { nodes, height: y - y0 };
}

// ---- assembling ----

export function renderStages(scene: FoldScene, opts: StagesOptions = {}): SvgDoc {
  const entry = candidatesEntry(scene, opts.statement);
  const step = scene.steps[entry.frameIndex];
  if (!step) throw new SceneError(`frame ${entry.frameIndex} is not in the file`);
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const faces = step.frame.facesVertices.map((f) => f.map((i) => step.frame.vertices[i]!));
  // A line that creases no face is no candidate: it is neither drawn nor numbered.
  const cands = entry.candidates.filter((c) => c.removedAt !== "paper");
  const skip = STAGES.map((s) => skipReason(entry, s, cands));
  const only = opts.stage;
  if (only !== undefined && !(only >= 0 && only <= 4)) throw new SceneError(`there is no stage ${only}`);
  const shown = [0, 1, 2, 3, 4].filter((s) => only === undefined || s === only);
  const lastStage = Math.max(...[0, 1, 2, 3, 4].filter((s) => skip[s] === null));

  // everything the rows draw past the paper widens the drawing area
  const extra: Vec2[] = [];
  for (const c of cands) {
    if (c.landing) extra.push(c.landing);
    if (c.nearest) extra.push(...c.nearest);
    for (const a of c.attempts) for (const m of a.motions) if (m) extra.push(...m.source.flat(), ...m.image.flat());
    for (const al of entry.alignments) {
      const pt = al.objects.find((o) => o.point)?.point;
      if (pt && c.removedAt === "moved") extra.push(reflect(pt, c.line));
    }
  }
  if (entry.circle) {
    const r = dist(entry.circle.centre, entry.circle.through);
    extra.push(add(entry.circle.centre, [r, r]), sub(entry.circle.centre, [r, r]));
  }
  if (entry.toward) extra.push(entry.toward);
  const area = drawingArea(faces, extra);
  const write = scene.writeTrace.find((w) => w.statement === entry.statement);
  const kind = scene.statements[entry.statement]?.kind;
  const cx: Ctx = {
    scene, entry, theme, area, cands, numberAt: [], used: new Set(),
    corners: new Set(scene.namedPoints.filter((p) => p.statement === null).map((p) => `.${p.name}`)),
    keptStyle: kind !== "fold" ? "mark"
      : write?.terms.write === "fold" && write.terms.placement === "bottom" ? "mountain" : "valley",
    lastStage, checks: opts.checks === true,
  };
  cx.numberAt = placeNumbers(cands, area);
  const marks = scene.statements[entry.statement - 1]?.keptMarks ?? [];
  if (marks.length) cx.used.add("mark");
  const corners = scene.namedPoints.filter((p) => p.statement === null).map((p) => `.${p.name}`);
  const base = () => renderFolded(scene, {
    step: String(entry.frameIndex), labels: opts.labels, theme: opts.theme, highlight: opts.highlight,
    markOverlay: { marks }, annotate: corners, dots: "annotated", layout: area.lay,
  }).node();

  const left = area.lay.W;
  const TX = left + GUTTER;
  const width = TX + TEXT_W + 20;
  const body: SvgNode[] = [];
  let y = 18;
  if (opts.title) {
    body.push(el("text", { x: 16, y: y + 6, "font-size": 16, "font-weight": 700, fill: theme.ink }, [], opts.title));
    y += 30;
  }
  const source = opts.source;
  const stmtSpan = scene.statements[entry.statement]?.span ?? null;
  const st = source && stmtSpan ? statementText(source, stmtSpan) : null;
  if (source) {
    const prog = programOf(scene, entry.statement, source);
    body.push(el("text", { x: 16, y: y + 12, "font-size": FONT, "font-weight": 700, fill: theme.ink }, [], "Program"));
    prog.lines.forEach((l, i) => body.push(el("text", {
      x: 16 + LABEL_W, y: y + 12 + i * (LINE - 3), "font-family": MONO_FAMILY, "font-size": MONO,
      fill: i === prog.bold ? theme.ink : theme.flat, "xml:space": "preserve", "data-kind": "program",
      ...(i === prog.bold ? { "font-weight": 700 } : {}),
    }, [], l)));
    y += 12 + prog.lines.length * (LINE - 3) + 20;
  }

  const rule = (yy: number, heavy: boolean) => el("line", { x1: 16, y1: yy, x2: width - 16, y2: yy,
    stroke: heavy ? theme.ink : theme.flat, "stroke-width": heavy ? 2.5 : 1.4 });
  shown.forEach((s, i) => {
    if (i > 0) { body.push(rule(y, false)); y += ROW_GAP; }
    const title = `Stage ${s} · ${TITLES[s]}`;
    const why = skip[s];
    if (why !== null) {
      body.push(el("g", { "data-stage": STAGES[s]!, "data-status": "skipped" }, [
        el("text", { x: TX, y: y + 14, "font-size": 15, "font-weight": 700, fill: theme.flat }, [], title),
        el("text", { x: TX, y: y + 34, "font-size": FONT, fill: theme.flat }, [], why),
      ]));
      y += 48;
      return;
    }
    const drawn = STAGE_FNS[s]!(cx);
    const children: SvgNode[] = [];
    let sy = y;
    for (const nodes of drawn.squares) {
      const b = base();
      children.push(el("svg", { ...b.attrs, x: 0, y: f2(sy) }, [...b.children, ...nodes]));
      sy += area.lay.H + 8;
    }
    let ty = y + PAD + 4;
    children.push(el("text", { x: TX, y: ty, "font-size": 15, "font-weight": 700, fill: theme.ink,
      "data-kind": "stage-title" }, [], title));
    ty += 26;
    if (st) {
      const marks2 = readSpans(entry, s).map((sp) => st.offsetOf(sp)).filter((r): r is [number, number] => r !== null);
      const sn = statementNodes(st, marks2, TX, ty, theme);
      children.push(...sn.nodes);
      ty += sn.height + 16;
    }
    const rn = rowsNodes(drawn.rows, TX, ty, theme);
    children.push(...rn.nodes);
    ty += rn.height;
    body.push(el("g", { "data-stage": STAGES[s]!, "data-status": "drawn" }, children));
    y = Math.max(sy - 8, ty) + 16;
  });

  if (only === undefined) {
    body.push(rule(y, true));
    y += 30;
    const rn = rowsNodes(closing(cx), TX, y, theme);
    body.push(el("g", { "data-kind": "closing" }, rn.nodes));
    y += rn.height + 24;
  }
  y += 16;
  const lg = legendNodes(cx, y, width);
  body.push(el("g", { "data-kind": "legend" }, lg.nodes));
  y += lg.height + 8;

  const doc = createDoc(Math.ceil(width), Math.ceil(y));
  doc.root.children.push(el("rect", { width: Math.ceil(width), height: Math.ceil(y), fill: theme.background }), ...body);
  return doc;
}
