// Scratch: one picture per selection rule for issue #58.
import { readFileSync, writeFileSync } from "node:fs";
import { clipHalfPlane, clipLineToPoly } from "/home/toph/code/beloch/packages/render-2d/render-svg/src/index.ts";

type V = [number, number];
type L = [number, number, number]; // a·x + b·y = c
const S = process.argv[2] ?? ".";  // a directory holding programs.json and the ax*.fold traces
const SQ: V[] = [[0, 0], [1, 0], [1, 1], [0, 1]];
const PAD = 48, SZ = 360, W = SZ + 2 * PAD;
let TOP = 0;
const tx = (x: number) => PAD + x * SZ, ty = (y: number) => TOP + PAD + (1 - y) * SZ;
// Beloch UI tokens
const CAND = ["#0D5F54", "#b05641"], TINT = ["#E2EDEA", "#F4E9E5"];
const INK = "#1A1D22", MUTED = "#5C6068", QUIET = "#E4E1DA", PAPER = "#FFFFFF";
const FONT = `font-family="Palatino, 'Palatino Linotype', Georgia, serif"`;
const MONO = `font-family="'JetBrains Mono', Menlo, monospace"`;

const norm = ([a, b, c]: L): L => { const n = Math.hypot(a, b); return [a / n, b / n, c / n]; };
const hp = (poly: V[], n: V, c: number) => clipHalfPlane(poly, n, c);
const pts = (p: V[]) => p.map(([x, y]) => `${tx(x).toFixed(1)},${ty(y).toFixed(1)}`).join(" ");
const reflect = (p: V, [a, b, c]: L): V => { const d = (a * p[0] + b * p[1] - c) / (a * a + b * b); return [p[0] - 2 * d * a, p[1] - 2 * d * b]; };

type Cells = { grey?: V[][]; hatch?: V[][]; legend?: string[]; result?: string; second?: [number, V[]][]; cells: V[][][]; bounds: L[]; none?: boolean; runs?: [number, number, number, number, number][]; curves?: V[][]; imgs?: [number, [V, V]][] };
function byLanding([p, q]: V[]): Cells {
  const n: V = [p![0] - q![0], p![1] - q![1]], c = (p![0] ** 2 + p![1] ** 2 - q![0] ** 2 - q![1] ** 2) / 2;
  return { cells: [[hp(SQ, n, c)], [hp(SQ, [-n[0], -n[1]], -c)]], bounds: [[n[0], n[1], c]] };
}
function byLine(lines: L[]): Cells {
  const [a, b] = lines.map(norm) as [L, L];
  const m: L = [a[0] - b[0], a[1] - b[1], a[2] - b[2]], p: L = [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  const piece = (s1: number, s2: number) => hp(hp(SQ, [s1 * m[0], s1 * m[1]], s1 * m[2]), [s2 * p[0], s2 * p[1]], s2 * p[2]);
  return { cells: [[piece(1, -1), piece(-1, 1)], [piece(1, 1), piece(-1, -1)]].map((c) => c.filter((q) => q.length >= 3)), bounds: [m, p] };
}
function bySide(la: L, candOnPositive: number): Cells {
  const [a, b, c] = la, cells: V[][][] = [[], []];
  cells[candOnPositive]!.push(hp(SQ, [a, b], c)); cells[1 - candOnPositive]!.push(hp(SQ, [-a, -b], -c));
  return { cells, bounds: [la] };
}

const seg = (l: L) => clipLineToPoly(l[0], l[1], l[2], SQ);
const line = (s: [V, V], stroke: string, w: number, dash = "") =>
  `<line x1="${tx(s[0][0]).toFixed(1)}" y1="${ty(s[0][1]).toFixed(1)}" x2="${tx(s[1][0]).toFixed(1)}" y2="${ty(s[1][1]).toFixed(1)}" stroke="${stroke}" stroke-width="${w}" stroke-linecap="round"${dash ? ` stroke-dasharray="${dash}"` : ""}/>`;
// an arrow drawn as a line and a filled head, shortened at both ends
function arrow(from: V, to: V, stroke: string, dashed: boolean): string {
  const x1 = tx(from[0]), y1 = ty(from[1]), x2 = tx(to[0]), y2 = ty(to[1]);
  const len = Math.hypot(x2 - x1, y2 - y1); if (len < 1) return "";
  const ux = (x2 - x1) / len, uy = (y2 - y1) / len, s = 8, e = 9;
  const ax = x1 + ux * s, ay = y1 + uy * s, bx = x2 - ux * e, by = y2 - uy * e, h = 11, w = 5;
  return `<line x1="${ax.toFixed(1)}" y1="${ay.toFixed(1)}" x2="${(bx - ux * h * 0.6).toFixed(1)}" y2="${(by - uy * h * 0.6).toFixed(1)}" stroke="${stroke}" stroke-width="2.2"${dashed ? ' stroke-dasharray="5 4"' : ""}/>` +
    `<polygon points="${bx.toFixed(1)},${by.toFixed(1)} ${(bx - ux * h - uy * w).toFixed(1)},${(by - uy * h + ux * w).toFixed(1)} ${(bx - ux * h + uy * w).toFixed(1)},${(by - uy * h - ux * w).toFixed(1)}" fill="${stroke}"/>`;
}
const label = ([x, y]: V, text: string, dx: number, dy: number, color = MUTED, anchor = "start") =>
  `<text x="${(tx(x) + dx).toFixed(1)}" y="${(ty(y) + dy).toFixed(1)}" font-size="14" fill="${color}" text-anchor="${anchor}" ${MONO}>${text}</text>`;

interface Named { lines: { l: L; name: string; at: V; dx: number; dy: number }[]; points: { p: V; name: string; dx: number; dy: number }[] }
interface Move { from: V; to: V[] } // per candidate

// The material rule: the candidate whose fold carries the moved material
// nearest the point. Material is a list of points and segments; its image
// under a candidate is each piece reflected across the candidate's line.
type Piece = V | [V, V];
const isSeg = (p: Piece): p is [V, V] => Array.isArray(p[0]);
function distPiece(x: V, p: Piece): number {
  if (!isSeg(p)) return Math.hypot(x[0] - p[0], x[1] - p[1]);
  const [a, b] = p, dx = b[0] - a[0], dy = b[1] - a[1];
  const t = Math.max(0, Math.min(1, ((x[0] - a[0]) * dx + (x[1] - a[1]) * dy) / (dx * dx + dy * dy)));
  return Math.hypot(x[0] - a[0] - t * dx, x[1] - a[1] - t * dy);
}
const imageOf = (m: Piece[], l: L): Piece[] => m.map((p) => (isSeg(p) ? [reflect(p[0], l), reflect(p[1], l)] as [V, V] : reflect(p, l)));
const distSet = (x: V, set: Piece[]) => Math.min(...set.map((p) => distPiece(x, p)));

function byMaterial(images: Piece[][]): Cells {
  const N = 240, f = (x: number, y: number) => distSet([x, y], images[0]!) - distSet([x, y], images[1]!);
  const g: number[][] = [];
  for (let j = 0; j <= N; j++) { g.push([]); for (let i = 0; i <= N; i++) g[j]!.push(f(i / N, j / N)); }
  const flat = g.every((row) => row.every((v) => Math.abs(v) < 1e-9));
  if (flat) return { cells: [[], []], bounds: [], none: true };
  // fill: runs of cells along each row, by the sign at the cell centre
  const runs: [number, number, number, number, number][] = [];
  for (let j = 0; j < N; j++) {
    let start = 0, cur = -1;
    for (let i = 0; i <= N; i++) {
      const v = i < N ? f((i + 0.5) / N, (j + 0.5) / N) : NaN;
      const k = Number.isNaN(v) ? -2 : Math.abs(v) < 1e-12 ? -1 : v < 0 ? 0 : 1;
      if (k !== cur) { if (cur >= 0) runs.push([cur, start / N, j / N, i / N, (j + 1) / N]); start = i; cur = k; }
    }
  }
  // boundary: marching squares on f = 0, chained into polylines
  const segs: [V, V][] = [];
  const at = (i: number, j: number, i2: number, j2: number): V => {
    const a = g[j]![i]!, b = g[j2]![i2]!, t = a / (a - b);
    return [(i + t * (i2 - i)) / N, (j + t * (j2 - j)) / N];
  };
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
    const c = [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]] as const;
    const ps: V[] = [];
    for (let k = 0; k < 4; k++) {
      const [i1, j1] = c[k]!, [i2, j2] = c[(k + 1) % 4]!;
      const a = g[j1]![i1]!, b = g[j2]![i2]!;
      if ((a < 0) !== (b < 0)) ps.push(at(i1, j1, i2, j2));
    }
    if (ps.length === 2) segs.push([ps[0]!, ps[1]!]);
    if (ps.length === 4) { segs.push([ps[0]!, ps[1]!]); segs.push([ps[2]!, ps[3]!]); }
  }
  const key = (p: V) => `${p[0].toFixed(6)},${p[1].toFixed(6)}`;
  const byEnd = new Map<string, number[]>();
  segs.forEach(([a, b], k) => { for (const p of [a, b]) byEnd.set(key(p), [...(byEnd.get(key(p)) ?? []), k]); });
  const used = new Set<number>(), curves: V[][] = [];
  for (let s = 0; s < segs.length; s++) {
    if (used.has(s)) continue;
    used.add(s);
    const line: V[] = [segs[s]![0], segs[s]![1]];
    for (const dir of [1, -1]) {
      for (;;) {
        const end = dir === 1 ? line[line.length - 1]! : line[0]!;
        const next = (byEnd.get(key(end)) ?? []).find((k) => !used.has(k));
        if (next === undefined) break;
        used.add(next);
        const [a, b] = segs[next]!, p = key(a) === key(end) ? b : a;
        if (dir === 1) line.push(p); else line.unshift(p);
      }
    }
    curves.push(line);
  }
  return { cells: [[], []], bounds: [], runs, curves };
}

const nearestChoice = (lines: L[], t: V): number | null => {
  const d = lines.map((l) => { const [a, b, c] = norm(l); return Math.abs(a * t[0] + b * t[1] - c); });
  return Math.abs(d[0]! - d[1]!) < 1e-9 ? null : d[0]! < d[1]! ? 0 : 1;
};
const materialChoice = (images: Piece[][], t: V): number | null => {
  const d = distSet(t, images[0]!) - distSet(t, images[1]!);
  return Math.abs(d) < 1e-9 ? null : d < 0 ? 0 : 1;
};
const withImgs = (r: Cells, images: Piece[][]): Cells =>
  ({ ...r, imgs: images.flatMap((set, i) => set.filter(isSeg).map((s) => [i, s] as [number, [V, V]])) });

// ---- self-contained pictures: rule, program, candidates, result ----
const PROGS = JSON.parse(readFileSync(`${S}/programs.json`, "utf8"));
const CODE_LINES = 7, LH = 17, HEAD = 36 + CODE_LINES * LH + 22, H = HEAD + 24 + SZ + 112;
const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const POINTS: Record<string, V> = { ".a": [0, 0], ".b": [1, 0], ".c": [1, 1], ".d": [0, 1], ".t": [0.6, 0.4] };

function candLabel(l: L, i: number): string {
  const s = seg(l); if (!s) return "";
  const t = 0.82, p: V = [s[0][0] + t * (s[1][0] - s[0][0]), s[0][1] + t * (s[1][1] - s[0][1])];
  return `<circle cx="${tx(p[0]).toFixed(1)}" cy="${ty(p[1]).toFixed(1)}" r="10" fill="${PAPER}" stroke="${CAND[i]}" stroke-width="2"/>` +
    `<text x="${tx(p[0]).toFixed(1)}" y="${(ty(p[1]) + 4.5).toFixed(1)}" text-anchor="middle" font-size="13" font-weight="700" fill="${CAND[i]}" ${MONO}>${i + 1}</text>`;
}

function card(file: string, rule: string, program: string, towardName: string, cands: L[], chosen: number | null,
  r: Cells, named: Named, moves: Move[], landings: boolean,
  opts: { marker?: "toward" | "moving" | "none"; highlight?: string; prefix?: string; extra?: string[]; footerExtra?: string[] } = {}) {
  const toward = POINTS[towardName] ?? [0, 0];
  const marker = opts.marker ?? "toward";
  const n: string[] = [];
  n.push(`<rect width="${W}" height="${H}" fill="${PAPER}"/>`);
  n.push(`<text x="${PAD - 14}" y="28" font-size="17" font-weight="700" fill="${INK}" ${FONT}>${esc(rule)}</text>`);
  const lines = program.trimEnd().split("\n");
  n.push(`<rect x="${PAD - 14}" y="40" width="${W - 2 * PAD + 28}" height="${CODE_LINES * LH + 12}" rx="3" fill="#F1EFEA"/>`);
  lines.forEach((ln, k) => {
    const hl = ln.includes(opts.highlight ?? `toward ${towardName}`);
    n.push(`<text x="${PAD - 6}" y="${58 + k * LH}" font-size="11.5" fill="${hl ? INK : MUTED}"${hl ? ' font-weight="700"' : ""} ${MONO}>${esc(ln)}</text>`);
  });
  TOP = HEAD - PAD + 24;
  const body: string[] = [];
  if (r.none) body.push(`<polygon points="${pts(SQ)}" fill="${QUIET}"/>`);
  // the area of the candidate that lost is hatched in its colour, the winner filled
  body.push(`<defs>${[0, 1].map((i) => `<pattern id="hatch${i}" width="9" height="9" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="9" height="9" fill="${PAPER}"/><line x1="0" y1="0" x2="0" y2="9" stroke="${CAND[i]}" stroke-width="2.4" stroke-opacity="0.45"/></pattern>`).join("")}</defs>`);
  const fillOf = (i: number) => (chosen !== null && i !== chosen ? `url(#hatch${i})` : TINT[i]);
  for (const [i, x0, y0, x1, y1] of r.runs ?? []) body.push(`<rect x="${tx(x0).toFixed(2)}" y="${ty(y1).toFixed(2)}" width="${(tx(x1) - tx(x0) + 0.4).toFixed(2)}" height="${(ty(y0) - ty(y1) + 0.4).toFixed(2)}" fill="${fillOf(i)}"/>`);
  r.cells.forEach((cs, i) => cs.forEach((q) => body.push(`<polygon points="${pts(q)}" fill="${TINT[i]}"/>`)));
  for (const q of r.grey ?? []) body.push(`<polygon points="${pts(q)}" fill="${QUIET}"/>`);
  for (const q of r.hatch ?? []) body.push(...stripes(q));
  for (const [i, q] of r.second ?? []) { body.push(`<polygon points="${pts(q)}" fill="${TINT[i]}"/>`); body.push(...stripes(q, i)); }
  for (const nl of named.lines) { const s = seg(nl.l); if (s) body.push(line(s, MUTED, 1.2, "2 3")); }
  for (const c of r.curves ?? []) body.push(`<polyline points="${pts(c)}" fill="none" stroke="${INK}" stroke-width="1.6" stroke-dasharray="7 5"/>`);
  for (const b of r.bounds) { const s = seg(b); if (s) body.push(line(s, INK, 1.6, "7 5")); }
  cands.forEach((l, i) => { const s = seg(l); if (s) body.push(line(s, CAND[i]!, chosen === i ? 5 : 2.4, chosen === i ? "" : "9 6")); });
  for (const [i, s] of r.imgs ?? []) body.push(line(s, CAND[i]!, 9).replace("/>", ' stroke-opacity="0.35"/>'));
  body.push(`<polygon points="${pts(SQ)}" fill="none" stroke="${INK}" stroke-width="2.2"/>`);
  for (const m of moves) m.to.forEach((t, i) => body.push(arrow(m.from, t, CAND[i]!, chosen !== i)));
  if (landings) moves.forEach((m) => m.to.forEach((t, i) => body.push(`<circle cx="${tx(t[0])}" cy="${ty(t[1])}" r="5.5" fill="${CAND[i]}" stroke="${PAPER}" stroke-width="1.5"/>`)));
  for (const m of moves) body.push(`<circle cx="${tx(m.from[0])}" cy="${ty(m.from[1])}" r="4.5" fill="${MUTED}"/>`);
  for (const np of named.points) { body.push(`<circle cx="${tx(np.p[0])}" cy="${ty(np.p[1])}" r="4" fill="${MUTED}"/>`); body.push(label(np.p, np.name, np.dx, np.dy)); }
  for (const nl of named.lines) body.push(label(nl.at, nl.name, nl.dx, nl.dy));
  cands.forEach((l, i) => body.push(candLabel(l, i)));
  if (marker === "toward") body.push(`<circle cx="${tx(toward[0])}" cy="${ty(toward[1])}" r="10" fill="none" stroke="${INK}" stroke-width="2.6"/>`);
  if (marker === "moving") body.push(`<rect x="${tx(toward[0]) - 9}" y="${ty(toward[1]) - 9}" width="18" height="18" fill="none" stroke="${INK}" stroke-width="2.6"/>`);
  body.push(...(opts.extra ?? []));
  for (const [name, [x, y]] of [["a", [0, 0]], ["b", [1, 0]], ["c", [1, 1]], ["d", [0, 1]]] as [string, V][])
    body.push(label([x, y], `.${name}`, x ? 12 : -12, y ? -10 : 20, INK, x ? "start" : "end"));
  n.push(...body);
  const fy = HEAD + 24 + SZ + 44;
  const pre = opts.prefix ?? `toward ${towardName}`;
  const result = chosen !== null ? `${pre}: candidate ${chosen + 1}${r.result?.startsWith(" ") ? r.result : ""}` : `${pre}: ${r.result ?? "ambiguous"}`;
  n.push(`<text x="${PAD - 14}" y="${fy}" font-size="16" font-weight="700" fill="${chosen === null ? INK : CAND[chosen]}" ${FONT}>${esc(result)}</text>`);
  const legend = r.legend ?? ["Shaded: the candidate of that colour would be selected here.", "Dashed black: boundary, no selection there. Arrow: where the fold moves."];
  legend.forEach((t, k) => n.push(`<text x="${PAD - 14}" y="${fy + 22 + 16 * k}" font-size="12" fill="${MUTED}" ${FONT}>${esc(t)}</text>`));
  n.push(...(opts.footerExtra ?? []));
  writeFileSync(`${S}/${file}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">${n.join("")}</svg>`);
}


// two-coloured stripes across a convex polygon: both candidates possible
function stripes(poly: V[], only?: number): string[] {
  const out: string[] = [], gap = only === undefined ? 0.028 : 0.045;
  const cs = poly.map(([x, y]) => x - y), lo = Math.min(...cs), hi = Math.max(...cs);
  let k = 0;
  for (let c = Math.ceil(lo / gap) * gap; c < hi; c += gap, k++) {
    const s = clipLineToPoly(1, -1, c, poly);
    if (s) out.push(only === undefined
      ? line(s, CAND[k % 2]!, 3.2).replace("/>", ' stroke-opacity="0.55"/>')
      : line(s, CAND[only]!, 1.3).replace("/>", ' stroke-opacity="0.45"/>'));
  }
  return out;
}

const traceOf = (f: string) => JSON.parse(readFileSync(`${S}/${f}.fold`, "utf8"))["beloch:trace"].find((e: any) => e.axiom && e.candidates.length > 1);

// Arrival rule: the side of a candidate that holds `toward` stays, the other
// side folds over. A candidate qualifies when that fold carries all of the
// moved material, that is when the material lies wholly on the side away
// from `toward`. Arrival side of a candidate: the half-plane opposite its
// material, or none when material lies on both sides.
const sideOf = (l: L, p: V) => { const v = l[0] * p[0] + l[1] * p[1] - l[2]; return Math.abs(v) < 1e-9 ? 0 : Math.sign(v); };
function materialSide(l: L, m: Piece[]): number {
  const signs = m.flatMap((p) => (isSeg(p) ? [sideOf(l, p[0]), sideOf(l, p[1])] : [sideOf(l, p)])).filter((s) => s !== 0);
  if (signs.every((s) => s > 0)) return 1;
  if (signs.every((s) => s < 0)) return -1;
  return 0;
}
// the half-plane where n·x ≥ c as an arrival side: the side opposite material
function arrival(l: L, m: Piece[]): [V, number] | null {
  const s = materialSide(l, m);
  if (s === 0) return null;
  return [[-s * l[0], -s * l[1]], -s * l[2]];
}
function byArrival(cands: L[], m: Piece[]): Cells {
  const A = cands.map((l) => arrival(l, m));
  const inside = (poly: V[], h: [V, number] | null, keep: boolean): V[] => {
    if (!h) return keep ? [] : poly;
    return keep ? hp(poly, h[0], h[1]) : hp(poly, [-h[0][0], -h[0][1]], -h[1]);
  };
  const only = (i: number) => { const p = inside(inside(SQ, A[i]!, true), A[1 - i]!, false); return p.length >= 3 ? [p] : []; };
  const both = inside(inside(SQ, A[0]!, true), A[1]!, true);
  const none = inside(inside(SQ, A[0]!, false), A[1]!, false);
  const bounds = cands.filter((_, i) => A[i]);
  return {
    cells: [only(0), only(1)], bounds, grey: none.length >= 3 ? [none] : [], hatch: both.length >= 3 ? [both] : [],
    legend: ["Shaded: only the candidate of that colour remains.", "Striped: both remain, ambiguous.",
      "Grey: no candidate remains."],
  };
}
function arrivalChoice(cands: L[], m: Piece[], t: V): number | null {
  const ok = cands.map((l) => { const s = materialSide(l, m); return s !== 0 && sideOf(l, t) === -s; });
  return ok[0] && !ok[1] ? 0 : ok[1] && !ok[0] ? 1 : null;
}

interface Ex2 { key: string; named: Named; material: Piece[]; moves: (cands: L[]) => Move[]; landings: boolean }
const EX2: Ex2[] = [
  { key: "ax6", landings: true, material: [[0, 1]],
    named: { lines: [{ l: [1, 0, 0.5], name: "--ef", at: [0.5, 0], dx: 6, dy: -8 }, { l: [1, 1, 1], name: "--bd", at: [0.82, 0.18], dx: 8, dy: 4 }], points: [{ p: [0.25, 0.75], name: ".p", dx: -30, dy: 5 }] },
    moves: (c) => [{ from: [0, 1], to: c.map((l) => reflect([0, 1], l)) }] },
  { key: "ax7", landings: true, material: [[0, 0], [0, 1]],
    named: { lines: [{ l: [1, -1, 0], name: "--diag", at: [0.7, 0.7], dx: 8, dy: 12 }, { l: [1, 1, 1], name: "--anti", at: [0.3, 0.7], dx: -60, dy: 12 }], points: [] },
    moves: (c) => [[0, 0] as V, [0, 1] as V].map((p) => ({ from: p, to: c.map((l) => reflect(p, l)) })) },
  { key: "ax5e", landings: false, material: [[[0.5, 0], [0.5, 1]]],
    named: { lines: [{ l: [1, 0, 0.5], name: "--v", at: [0.5, 0.92], dx: 8, dy: 0 }, { l: [0, 1, 0], name: "--ab", at: [0.62, 0], dx: 0, dy: 18 }], points: [] },
    moves: (c) => [{ from: [0.5, 0.5], to: c.map((l) => reflect([0.5, 0.5], l)) }] },
  { key: "ax5c", landings: false, material: [[[0.5, 0], [0.5, 1]]],
    named: { lines: [{ l: [1, 0, 0.5], name: "--v", at: [0.5, 0.95], dx: 8, dy: 4 }, { l: [0, 1, 0.5], name: "--h", at: [0.03, 0.5], dx: 0, dy: -8 }], points: [] },
    moves: (c) => [[0.5, 0.8] as V, [0.5, 0.2] as V].map((p) => ({ from: p, to: c.map((l) => reflect(p, l)) })) },
  { key: "ax5o", landings: false, material: [[[0.5, 0], [1, 1]]],
    named: { lines: [{ l: [2, -1, 1], name: "--mc", at: [0.9, 0.8], dx: 8, dy: 4 }, { l: [0, 1, 0], name: "--ab", at: [0.25, 0], dx: 0, dy: 18 },
      { l: [1, 1, 1], name: "--bd", at: [0.15, 0.85], dx: 8, dy: 4 }], points: [{ p: [0.5, 0], name: ".m", dx: -8, dy: 20 }, { p: [0.6, 0.4], name: ".t", dx: 14, dy: 5 }] },
    moves: (c) => [{ from: [0.75, 0.5], to: c.map((l) => reflect([0.75, 0.5], l)) }] },
];
// Second stage: where both candidates qualify, the one whose landing of the
// moved material lies nearest decides. Exact for a single moved point: the
// perpendicular bisector of the two landings.
function byArrivalLanding(cands: L[], m: Piece[]): Cells {
  const base = byArrival(cands, m);
  const images = cands.map((c) => imageOf(m, c));
  const second: [number, V[]][] = [];
  const bounds: L[] = [...base.bounds];
  for (const both of base.hatch ?? []) {
    if (m.length !== 1 || isSeg(m[0]!)) throw new Error("second stage drawn only for one moved point");
    const [p, q] = images.map((s) => s[0] as V) as [V, V];
    const n: V = [p[0] - q[0], p[1] - q[1]], c = (p[0] ** 2 + p[1] ** 2 - q[0] ** 2 - q[1] ** 2) / 2;
    const near0 = hp(both, n, c), near1 = hp(both, [-n[0], -n[1]], -c);
    if (near0.length >= 3) second.push([0, near0]);
    if (near1.length >= 3) second.push([1, near1]);
    // the bisector inside the overlap only
    const s = clipLineToPoly(n[0], n[1], c, both);
    if (s) base.curves = [...(base.curves ?? []), [s[0], s[1]]];
  }
  return {
    ...base, hatch: [], second, bounds,
    legend: ["Shaded: only the candidate of that colour remains.", "Hatched: both remain; the nearer landing decides.",
      "Grey: no candidate remains."],
  };
}
function arrivalLandingChoice(cands: L[], m: Piece[], t: V): { ch: number | null; why: string } {
  const ok = cands.map((l) => { const s = materialSide(l, m); return s !== 0 && sideOf(l, t) === -s; });
  const n = ok.filter(Boolean).length;
  if (n === 1) return { ch: ok[0] ? 0 : 1, why: "" };
  if (n === 0) return { ch: null, why: "no candidate remains" };
  const images = cands.map((c) => imageOf(m, c));
  const d = distSet(t, images[0]!) - distSet(t, images[1]!);
  return Math.abs(d) < 1e-9 ? { ch: null, why: "equally near, ambiguous" } : { ch: d < 0 ? 0 : 1, why: " (second stage: landing)" };
}

// ---- the rules of ADR 0031, drawn for every example ----
const NEW: Record<string, { toward: string; along: string; moving?: string }> = {
  ax6: {
    toward: "paper square\nmark (map .a onto .b) as --ef\nmark (through .b .d) as --bd\n.p = free on --bd from .d at 1/4\nfold (map .d onto --ef through .p) (toward X) as --s\n",
    along: "paper square\nmark (map .a onto .b) as --ef\nmark (through .b .d) as --bd\n.p = free on --bd from .d at 1/4\nfold (map .d onto --ef through .p along --ef) as --s\n",
    moving: "paper square\nmark (map .a onto .b) as --ef\nmark (through .b .d) as --bd\n.p = free on --bd from .d at 1/4\nfold (map .d onto --ef through .p) (moving X) as --s\n",
  },
  ax7: {
    toward: "paper square\nmark (through .a .c) as --diag\nmark (through .b .d) as --anti\nmark (map .a onto --anti and .d onto --diag) (toward X)\n",
    along: "paper square\nmark (through .a .c) as --diag\nmark (through .b .d) as --anti\nmark (map .a onto --anti and .d onto --diag along --ab)\n",
  },
  ax5e: {
    toward: "paper square\nmark (map .a onto .b) as --v\nmark (map --v onto --ab) (toward X) as --k\n",
    along: "paper square\nmark (map .a onto .b) as --v\nmark (through .b .d) as --bd\nmark (map --v onto --ab along --bd) as --k\n",
  },
  ax5c: {
    toward: "paper square\nmark (map .a onto .b) as --v\nmark (map .a onto .d) as --h\nmark (map --v onto --h) (toward X) as --k\n",
    along: "paper square\nmark (map .a onto .b) as --v\nmark (map .a onto .d) as --h\nmark (through .b .d) as --bd\nmark (map --v onto --h along --bd) as --k\n",
  },
  ax5o: {
    toward: "paper square\nmark (map .a onto .b) as --v\n.m = --v * --ab\nmark (through .m .c) as --mc\nmark (through .b .d) as --bd\n.t = free on --bd from .b at 2/5\nmark (map --mc onto --ab) (toward X) as --k\n",
    along: "paper square\nmark (map .a onto .b) as --v\n.m = --v * --ab\nmark (through .m .c) as --mc\nmark (through .b .d) as --bd\nmark (map --mc onto --ab along --bd) as --k\n",
  },
};
const ALONG: Record<string, { l: L; name: string }> = {
  ax6: { l: [1, 0, 0.5], name: "--ef" }, ax7: { l: [0, 1, 0], name: "--ab" },
  ax5e: { l: [1, 1, 1], name: "--bd" }, ax5c: { l: [1, 1, 1], name: "--bd" }, ax5o: { l: [1, 1, 1], name: "--bd" },
};
const dirAngle = ([a, b]: L) => Math.atan2(-a, b) * 180 / Math.PI; // direction (b, −a)
const angDiff = (p: number, q: number) => Math.abs((((p - q) % 180) + 270) % 180 - 90);
function alongChoice(cands: L[], ref: L): number | null {
  const d = cands.map((c) => angDiff(dirAngle(c), dirAngle(ref)));
  return Math.abs(d[0]! - d[1]!) < 1e-9 ? null : d[0]! < d[1]! ? 0 : 1;
}
// a dial of directions: each direction coloured by the candidate nearer it
// in angle, the candidates and the reference line drawn through the centre
function dial(cx: number, cy: number, r: number, cands: L[], ref: L): string[] {
  const out: string[] = [];
  const pt = (deg: number, rr: number) => [cx + rr * Math.cos(deg * Math.PI / 180), cy - rr * Math.sin(deg * Math.PI / 180)];
  for (let deg = 0; deg < 360; deg += 2) {
    const d = cands.map((c) => angDiff(dirAngle(c), deg + 1));
    const i = Math.abs(d[0]! - d[1]!) < 1e-9 ? -1 : d[0]! < d[1]! ? 0 : 1;
    const [x1, y1] = pt(deg, r), [x2, y2] = pt(deg + 2.2, r);
    out.push(`<path d="M${cx},${cy} L${x1!.toFixed(1)},${y1!.toFixed(1)} A${r},${r} 0 0 0 ${x2!.toFixed(1)},${y2!.toFixed(1)} Z" fill="${i < 0 ? QUIET : CAND[i]}" fill-opacity="${i < 0 ? 1 : 0.28}"/>`);
  }
  out.push(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${MUTED}" stroke-width="1"/>`);
  cands.forEach((c, i) => { const a = dirAngle(c); const [x1, y1] = pt(a, r), [x2, y2] = pt(a + 180, r);
    out.push(`<line x1="${x1!.toFixed(1)}" y1="${y1!.toFixed(1)}" x2="${x2!.toFixed(1)}" y2="${y2!.toFixed(1)}" stroke="${CAND[i]}" stroke-width="2.4"/>`); });
  const a = dirAngle(ref); const [x1, y1] = pt(a, r + 6), [x2, y2] = pt(a + 180, r + 6);
  out.push(`<line x1="${x1!.toFixed(1)}" y1="${y1!.toFixed(1)}" x2="${x2!.toFixed(1)}" y2="${y2!.toFixed(1)}" stroke="${INK}" stroke-width="2" stroke-dasharray="4 3"/>`);
  return out;
}
// moving: the side of the moving point folds over, so a candidate remains
// when its material lies on that side
function byMoving(cands: L[], m: Piece[]): Cells {
  const M = cands.map((l) => { const s = materialSide(l, m); return s === 0 ? null : [[s * l[0], s * l[1]], s * l[2]] as [V, number]; });
  const cut = (poly: V[], h: [V, number] | null, keep: boolean): V[] => (!h ? (keep ? [] : poly) : keep ? hp(poly, h[0], h[1]) : hp(poly, [-h[0][0], -h[0][1]], -h[1]));
  const only = (i: number) => { const p = cut(cut(SQ, M[i]!, true), M[1 - i]!, false); return p.length >= 3 ? [p] : []; };
  const both = cut(cut(SQ, M[0]!, true), M[1]!, true), none = cut(cut(SQ, M[0]!, false), M[1]!, false);
  return {
    cells: [only(0), only(1)], bounds: cands.filter((_, i) => M[i]), grey: none.length >= 3 ? [none] : [], hatch: both.length >= 3 ? [both] : [],
    legend: ["Shaded: a moving point here leaves only this candidate.", "Striped: both remain, ambiguous (moving has no second stage).", "Grey: no candidate remains."],
  };
}
function movingChoice(cands: L[], m: Piece[], p: V): { ch: number | null; why: string } {
  const ok = cands.map((l) => { const s = materialSide(l, m); return s !== 0 && sideOf(l, p) === s; });
  const n = ok.filter(Boolean).length;
  return n === 1 ? { ch: ok[0] ? 0 : 1, why: "" } : { ch: null, why: n === 0 ? "no candidate remains" : "both remain, ambiguous" };
}

// ---- ADR 0031 as implemented: alignments are incidences ----

// an object of an `onto` alignment: a point, or a line with its material
type Obj = { p: V; name: string } | { l: L; s: [V, V]; name: string };
const isPt = (o: Obj): o is { p: V; name: string } => "p" in o;
const P = (p: V, name: string): Obj => ({ p, name });
const Ln = (l: L, s: [V, V], name: string): Obj => ({ l, s, name });
const onSeg = ([a, b]: [V, V], r: V) => distPiece(r, [a, b]) < 1e-9;
const ALIGNS: Record<string, [Obj, Obj][]> = {
  ax6: [[P([0, 1], ".d"), Ln([1, 0, 0.5], [[0.5, 0], [0.5, 1]], "--ef")]],
  ax7: [[P([0, 0], ".a"), Ln([1, 1, 1], [[1, 0], [0, 1]], "--anti")], [P([0, 1], ".d"), Ln([1, -1, 0], [[0, 0], [1, 1]], "--diag")]],
  ax5e: [[Ln([1, 0, 0.5], [[0.5, 0], [0.5, 1]], "--v"), Ln([0, 1, 0], [[0, 0], [1, 0]], "--ab")]],
  ax5c: [[Ln([1, 0, 0.5], [[0.5, 0], [0.5, 1]], "--v"), Ln([0, 1, 0.5], [[0, 0.5], [1, 0.5]], "--h")]],
  ax5o: [[Ln([2, -1, 1], [[0.5, 0], [1, 1]], "--mc"), Ln([0, 1, 0], [[0, 0], [1, 0]], "--ab")]],
};
// the part of an object on side s of c, as pieces; empty when none
function partOn(c: L, s: number, o: Obj): Piece[] {
  if (isPt(o)) return sideOf(c, o.p) === s ? [o.p] : [];
  const part = movedPart(c, [o.s], s);
  return part ?? [];
}
function movedPart(l: L, m: Piece[], foldSide: number): Piece[] | null {
  const out: Piece[] = [];
  for (const p of m) {
    if (!isSeg(p)) { if (sideOf(l, p) !== foldSide) return null; out.push(p); continue; }
    const [a, b] = p, va = l[0] * a[0] + l[1] * a[1] - l[2], vb = l[0] * b[0] + l[1] * b[1] - l[2];
    const sa = foldSide * va, sb = foldSide * vb;
    if (sa <= 1e-12 && sb <= 1e-12) return null;
    if (sa >= -1e-12 && sb >= -1e-12) { out.push(p); continue; }
    const t = va / (va - vb), q: V = [a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])];
    out.push(sa > 0 ? [a, q] : [q, b]);
  }
  return out;
}
// x on side s lands on y
function carries(c: L, s: number, x: Obj, y: Obj): boolean {
  if (isPt(x)) return sideOf(c, x.p) === s;
  if (isPt(y)) { const r = reflect(y.p, c); return sideOf(c, r) === s && onSeg(x.s, r); }
  return partOn(c, s, x).length > 0;
}
const already = (c: L, x: Obj, y: Obj) =>
  isPt(x) && !isPt(y) ? sideOf(c, x.p) === 0 && sideOf(y.l, x.p) === 0
  : isPt(y) && !isPt(x) ? sideOf(c, y.p) === 0 && sideOf(x.l, y.p) === 0 : false;
const performs = (c: L, s: number, al: [Obj, Obj][]) =>
  al.every(([x, y]) => carries(c, s, x, y) || carries(c, s, y, x) || already(c, x, y));
const objectsOf = (al: [Obj, Obj][]) => [...new Set(al.flat())];
// score of a candidate for a toward point: the distance of what lands, or
// Infinity when the candidate does not remain
function towardScore(c: L, al: [Obj, Obj][], subject: Obj | null, t: V): number {
  const st = sideOf(c, t); if (st === 0) return Infinity;
  const s = -st;
  if (!performs(c, s, al)) return Infinity;
  const objs = subject ? [subject] : objectsOf(al);
  const landed = objs.flatMap((o) => imageOf(partOn(c, s, o), c));
  if (subject && landed.length === 0) return Infinity;
  return landed.length ? distSet(t, landed) : Infinity;
}
function towardChoice(cands: L[], al: [Obj, Obj][], subject: Obj | null, t: V): { ch: number | null; why: string } {
  const d = cands.map((c) => towardScore(c, al, subject, t)), ok = d.filter((v) => v < Infinity).length;
  if (ok === 0) return { ch: null, why: "no candidate remains" };
  if (ok === 1) return { ch: d[0]! < Infinity ? 0 : 1, why: "" };
  return Math.abs(d[0]! - d[1]!) < 1e-9 ? { ch: null, why: "equally near, ambiguous" } : { ch: d[0]! < d[1]! ? 0 : 1, why: " (by the landing)" };
}
// moving: the side of the point folds over
const movingOk = (c: L, al: [Obj, Obj][], p: V) => { const s = sideOf(c, p); return s !== 0 && performs(c, s, al); };
function movingChoice2(cands: L[], al: [Obj, Obj][], p: V): { ch: number | null; why: string } {
  const ok = cands.map((c) => movingOk(c, al, p)), n = ok.filter(Boolean).length;
  return n === 1 ? { ch: ok[0] ? 0 : 1, why: "" } : { ch: null, why: n === 0 ? "no candidate remains" : "both remain, ambiguous" };
}
// cells by a per-point classifier: 0 or 1 a candidate, 2 a tie, -1 none
function byClass(f: (x: V) => number, legend: string[]): Cells {
  const N = 240, runs: [number, number, number, number, number][] = [], ties: V[][] = [];
  for (let j = 0; j < N; j++) { let start = 0, cur = -9;
    for (let i = 0; i <= N; i++) {
      const k = i < N ? f([(i + 0.5) / N, (j + 0.5) / N]) : -9;
      if (k !== cur) {
        if (cur === 0 || cur === 1) runs.push([cur, start / N, j / N, i / N, (j + 1) / N]);
        if (cur === 2) ties.push([[start / N, j / N], [i / N, j / N], [i / N, (j + 1) / N], [start / N, (j + 1) / N]]);
        start = i; cur = k;
      } } }
  return { cells: [[], []], bounds: [], runs, grey: ties, legend };
}
const cls = (r: { ch: number | null; why: string }) => r.ch !== null ? r.ch : r.why.startsWith("no") ? -1 : 2;

const FIRST: Record<string, string> = { ax6: ".d", ax7: ".a", ax5e: "--v", ax5c: "--v", ax5o: "--mc" };
const OUT: string[] = [];
const PROG_TOWARD: Record<string, string> = {
  ax6: "paper square\nmark (map .a onto .b) as --ef\nmark (through .b .d) as --bd\n.p = free on --bd from .d at 1/4\nfold (map .d onto --ef through .p) (TW) as --s\n",
  ax7: "paper square\nmark (through .a .c) as --diag\nmark (through .b .d) as --anti\nmark (map .a onto --anti and .d onto --diag) (TW)\n",
  ax5e: "paper square\nmark (map .a onto .b) as --v\nmark (map --v onto --ab) (TW) as --k\n",
  ax5c: "paper square\nmark (map .a onto .b) as --v\nmark (map .a onto .d) as --h\n.u = free on --ab from .b at 1/5\nmark (map --v onto --h) (TW) as --k\n",
  ax5o: "paper square\nmark (map .a onto .b) as --v\n.m = --v * --ab\nmark (through .m .c) as --mc\nmark (through .b .d) as --bd\n.t = free on --bd from .b at 2/5\nmark (map --mc onto --ab) (TW) as --k\n",
};
const PROG_ALONG: Record<string, string> = {
  ax6: "paper square\nmark (map .a onto .b) as --ef\nmark (through .b .d) as --bd\n.p = free on --bd from .d at 1/4\nfold (align (.d onto --ef) (through .p) (heading --ef)) as --s\n",
  ax7: "paper square\nmark (through .a .c) as --diag\nmark (through .b .d) as --anti\nmark (align (.a onto --anti) (.d onto --diag) (heading --ab))\n",
  ax5e: "paper square\nmark (map .a onto .b) as --v\nmark (through .b .d) as --bd\nmark (align (--v onto --ab) (heading --bd)) as --k\n",
  ax5c: "paper square\nmark (map .a onto .b) as --v\nmark (map .a onto .d) as --h\nmark (through .b .d) as --bd\nmark (align (--v onto --h) (heading --bd)) as --k\n",
  ax5o: "paper square\nmark (map .a onto .b) as --v\n.m = --v * --ab\nmark (through .m .c) as --mc\nmark (through .b .d) as --bd\nmark (align (--mc onto --ab) (heading --bd)) as --k\n",
};
POINTS[".u"] = [0.8, 0];

// arrows for what lands: a point subject to its landing under each
// candidate, a line subject from the middle of its part on the side away
// from toward
function subjectMoves(cands: L[], subject: Obj, t: V | null): Move[] {
  if (isPt(subject)) return [{ from: subject.p, to: cands.map((c) => reflect(subject.p, c)) }];
  const out: Move[] = [];
  cands.forEach((c, i) => {
    // the part the fold with toward would carry, else, for a candidate that
    // lost, the part on the other side, so every candidate shows an arrow
    const st = t ? sideOf(c, t) : 0;
    const away = st !== 0 ? partOn(c, -st, subject) : [];
    const parts = away.length ? away : partOn(c, st !== 0 ? st : 1, subject).length ? partOn(c, st !== 0 ? st : 1, subject) : partOn(c, -1, subject);
    for (const p of parts) if (isSeg(p)) {
      const mid: V = [(p[0][0] + p[1][0]) / 2, (p[0][1] + p[1][1]) / 2];
      out.push({ from: mid, to: i === 0 ? [reflect(mid, c), mid] : [mid, reflect(mid, c)] });
    }
  });
  return out;
}
function landedImgs(cands: L[], objs: Obj[], t: V): [number, [V, V]][] {
  const out: [number, [V, V]][] = [];
  cands.forEach((c, i) => { const st = sideOf(c, t); if (st === 0) return;
    for (const o of objs) for (const p of imageOf(partOn(c, -st, o), c)) if (isSeg(p)) out.push([i, p]); });
  return out;
}

for (const ex of EX2) {
  const al = ALIGNS[ex.key]!, cands = traceOf(`${ex.key}${PROGS[ex.key].towards[0]}`).candidates.map((c: any) => c.line) as L[];
  const subject = objectsOf(al).find((o) => o.name === FIRST[ex.key])!;
  const pointsFor = ex.key === "ax5c" ? [".b", ".u"] : (PROGS[ex.key].towards as string[]);
  const named: Named = ex.key === "ax5c" ? { ...ex.named, points: [{ p: [0.8, 0], name: ".u", dx: -6, dy: 20 }] } : ex.named;
  for (const tw of pointsFor) {
    const t = POINTS[tw]!, item = `${subject.name} toward ${tw}`;
    const r = towardChoice(cands, al, subject, t);
    card(`new-${ex.key}-toward-${tw.slice(1)}`, `(x toward …): the side that stays, then where x lands`,
      PROG_TOWARD[ex.key]!.replace("TW", item), tw, cands, r.ch,
      { ...byClass((x) => cls(towardChoice(cands, al, subject, x)),
          ["The side of toward stays, the other folds over. A toward point here", `selects the candidate of that colour, by where ${subject.name} lands; filled:`, "the one selected above, hatched: the other. Grey: equally near."]),
        imgs: isPt(subject) ? [] : landedImgs(cands, [subject], t), result: r.why || undefined },
      named, subjectMoves(cands, subject, t), ex.landings,
      { highlight: item, prefix: `(${item})` });
    OUT.push(`${ex.key} (${item}): ${r.ch === null ? r.why : `candidate ${r.ch + 1}${r.why}`}`);
  }
  if (ex.key === "ax5c") for (const tw of [".b", ".u"]) {
    const t = POINTS[tw]!, r = towardChoice(cands, al, null, t);
    card(`new-ax5c-bare-${tw.slice(1)}`, "bare toward: everything that folds over counts", PROG_TOWARD.ax5c!.replace("TW", `toward ${tw}`), tw, cands, r.ch,
      { ...byClass((x) => cls(towardChoice(cands, al, null, x)),
          ["Both lines fold over in part, and both parts count. A toward point", "here selects the candidate of that colour; filled: the one selected", "above, hatched: the other. Grey: equally near, ambiguous."]),
        imgs: landedImgs(cands, objectsOf(al), t), result: r.why || undefined },
      named, [], false);
    OUT.push(`ax5c (toward ${tw}): ${r.ch === null ? r.why : `candidate ${r.ch + 1}${r.why}`}`);
  }
  const ref = ALONG[ex.key]!, ach = alongChoice(cands, ref.l);
  const namedA = ex.named.lines.some((l) => l.name === ref.name) ? ex.named
    : { ...ex.named, lines: [...ex.named.lines, { l: ref.l, name: ref.name, at: [0.15, 0.85] as V, dx: 8, dy: 4 }] };
  const sref = seg(ref.l);
  card(`new-${ex.key}-heading`, "heading: the direction of the crease", PROG_ALONG[ex.key]!, "", cands, ach,
    { cells: [[], []], bounds: [], result: "equal angles, passed on to toward",
      legend: ["Only the direction of the heading line counts.", "Dial: each direction in the colour of the", "candidate it selects; dashed: the heading line."] },
    namedA, [], false,
    { marker: "none", highlight: `(heading ${ref.name})`, prefix: `heading ${ref.name}`,
      extra: sref ? [line(sref, INK, 3, "10 6").replace("/>", ' stroke-opacity="0.55"/>')] : [],
      footerExtra: dial(W - 58, HEAD + 24 + SZ + 58, 38, cands, ref.l) });
  OUT.push(`${ex.key} heading ${ref.name}: ${ach === null ? "tie" : `candidate ${ach + 1}`}`);
  if (ex.key === "ax6") for (const mv of [".a", ".d"]) {
    const r = movingChoice2(cands, al, POINTS[mv]!);
    card(`new-ax6-moving-${mv.slice(1)}`, "moving: the point's side folds over",
      PROG_TOWARD.ax6!.replace("TW", `moving ${mv}`), mv, cands, r.ch,
      { ...byClass((x) => cls(movingChoice2(cands, al, x)),
          ["A moving point here leaves only the candidate of that colour;", "filled: the one selected above, hatched: the other.", "Grey: both remain, ambiguous (moving has no second stage)."]),
        result: r.why || undefined },
      ex.named, ex.moves(cands), ex.landings, { marker: "moving", highlight: `moving ${mv}`, prefix: `moving ${mv}` });
    OUT.push(`ax6 moving ${mv}: ${r.ch === null ? r.why : `candidate ${r.ch + 1}`}`);
  }
}
console.log(OUT.join("\n"));
