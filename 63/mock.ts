// Hand-placed mockups of the stages-view rules. No selection logic: every
// coordinate and every sentence is written in by hand.
import { writeFileSync, readFileSync } from "node:fs";

type P = [number, number];
const C1 = process.env.MONO === "1" ? "#0f172a" : "#0880d4", C2 = process.env.MONO === "1" ? "#0f172a" : "#ce6400";           // highlight 4 and 3
const T1 = process.env.MONO === "1" ? "#0f172a" : "#0b6fb0", T2 = process.env.MONO === "1" ? "#0f172a" : "#b25600";           // their text variants
const INK = "#0f172a", BND = "#1f2937", CON = "#334155", FLAT = "#64748b", PAPER = "#fafaf7", MUTED = "#64748b";
const MONOPRINT = process.env.MONO === "1";
const C3 = MONOPRINT ? "#0f172a" : "#a945ff", T3 = MONOPRINT ? "#0f172a" : "#8a2fd6";
const col = (k: number) => (k === 1 ? C1 : k === 2 ? C2 : C3);
const tcol = (k: number) => (k === 1 ? T1 : k === 2 ? T2 : T3);

const PW = 820, S = 220, SX = 80, SY = 50, PH = 330, TX = 380;   // panel width, square, square origin, panel height
const FONT = `font-family="IBM Plex Sans, Inter, DejaVu Sans, sans-serif"`;
const MONO = `font-family="IBM Plex Mono, DejaVu Sans Mono, monospace"`;

const LAND = process.env.LAND ?? "outline";
function landMark(x: number, y: number, c: string) {
  if (LAND === "double") return `<circle cx="${x}" cy="${y}" r="7" fill="${PAPER}" stroke="${c}" stroke-width="1.6"/><circle cx="${x}" cy="${y}" r="3" fill="none" stroke="${c}" stroke-width="1.6"/>`;
  if (LAND === "cross") return `<circle cx="${x}" cy="${y}" r="5" fill="${PAPER}" stroke="${c}" stroke-width="1.6"/><path d="M${x - 9} ${y} h18 M${x} ${y - 9} v18" stroke="${c}" stroke-width="1.3"/>`;
  return `<circle cx="${x}" cy="${y}" r="5" fill="${PAPER}" stroke="${c}" stroke-width="2.2"/>`;
}
function refl(n: P, c: number, p: P): P { const d = (n[0] * p[0] + n[1] * p[1] - c) / (n[0] ** 2 + n[1] ** 2); return [p[0] - 2 * d * n[0], p[1] - 2 * d * n[1]]; }
const diamond = (x: number, y: number) => `<path d="M${x} ${y - 8} L${x + 8} ${y} L${x} ${y + 8} L${x - 8} ${y} Z" fill="${INK}" stroke="${PAPER}" stroke-width="1.5"/>`;
function esc(s: string) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;"); }

class Panel {
  out: string[] = [];
  constructor(public ox: number, public oy: number, public s = S, public sx = SX, public sy = SY) {}
  X(p: P) { return this.ox + this.sx + p[0] * this.s; }
  Y(p: P) { return this.oy + this.sy + (1 - p[1]) * this.s; }
  xy(p: P) { return `${this.X(p).toFixed(1)},${this.Y(p).toFixed(1)}`; }
  add(s: string) { this.out.push(s); }
  title(t: string) { this.add(`<text x="${this.ox + TX}" y="${this.oy + 60}" ${FONT} font-size="15" font-weight="600" fill="${INK}">${esc(t)}</text>`); }
  // program lines; hl = [line index, [before, span, after]]
  program(lines: string[], hl: [number, string, string, string]) {
    lines.forEach((l, i) => {
      const y = this.oy + 88 + i * 16;
      if (i === hl[0]) {
        this.add(`<text x="${this.ox + TX}" y="${y}" ${MONO} font-size="11.5" fill="${INK}">${esc(hl[1])}<tspan fill="${CON}" font-weight="700" text-decoration="underline">${esc(hl[2])}</tspan>${esc(hl[3])}</text>`);
      } else this.add(`<text x="${this.ox + TX}" y="${y}" ${MONO} font-size="11.5" fill="${MUTED}">${esc(l)}</text>`);
    });
  }
  paper() {
    this.add(`<rect x="${this.X([0, 1])}" y="${this.Y([0, 1])}" width="${this.s}" height="${this.s}" fill="${PAPER}" stroke="${BND}" stroke-width="2.5"/>`);
  }
  corners(names: Record<string, P>) {
    for (const [n, p] of Object.entries(names)) {
      const dx = p[0] === 0 ? -16 : 6, dy = p[1] === 0 ? 16 : -6;
      this.add(`<text x="${this.X(p) + dx}" y="${this.Y(p) + dy}" ${FONT} font-size="12" fill="${MUTED}">${n}</text>`);
    }
  }
  mark(a: P, b: P) { // an existing mark: F in yrLineStyle
    this.add(`<line x1="${this.X(a)}" y1="${this.Y(a)}" x2="${this.X(b)}" y2="${this.Y(b)}" stroke="${INK}" stroke-width="1.5" stroke-dasharray="1 3" opacity="0.45"/>`);
  }
  read(a: P, b: P, label: string, at: P, anchor = "start") { // what this stage reads
    this.add(`<line x1="${this.X(a)}" y1="${this.Y(a)}" x2="${this.X(b)}" y2="${this.Y(b)}" stroke="${CON}" stroke-width="1.2"/>`);
    this.label(label, at, CON, anchor);
  }
  readPoint(p: P, label: string, at: P) {
    this.add(`<circle cx="${this.X(p)}" cy="${this.Y(p)}" r="3" fill="${CON}"/>`);
    this.label(label, at, CON);
  }
  label(t: string, at: P, fill = INK, anchor = "start", size = 12) {
    this.add(`<text x="${this.X(at)}" y="${this.Y(at)}" ${FONT} font-size="${size}" fill="${fill}" text-anchor="${anchor}" paint-order="stroke" stroke="${PAPER}" stroke-width="3">${esc(t)}</text>`);
  }
  curve(pts: P[], stroke: string) {
    this.add(`<polyline points="${pts.map((p) => this.xy(p)).join(" ")}" fill="none" stroke="${stroke}" stroke-width="1"/>`);
  }
  // a candidate: clipped segment a-b on the paper, extended past `end` to a numeral outside the square
  cand(k: number, a: P, b: P, state: "in" | "removed" | "winner") {
    const c = col(k);
    const style = state === "in" ? `stroke-width="2.5"` : state === "removed" ? `stroke-width="0.8"` : `stroke-width="2.5" stroke-dasharray="7 4"`;
    this.add(`<line x1="${this.X(a)}" y1="${this.Y(a)}" x2="${this.X(b)}" y2="${this.Y(b)}" stroke="${c}" ${style}/>`);
    // extension to the numeral beyond b
    const dx = this.X(b) - this.X(a), dy = this.Y(b) - this.Y(a), L = Math.hypot(dx, dy);
    const ex = this.X(b) + (dx / L) * 22, ey = this.Y(b) + (dy / L) * 22;
    this.add(`<line x1="${this.X(b)}" y1="${this.Y(b)}" x2="${ex}" y2="${ey}" stroke="${c}" stroke-width="0.8"/>`);
    this.numeral(k, ex + (dx / L) * 11, ey + (dy / L) * 11, state);
  }
  numeral(k: number, x: number, y: number, state0: "in" | "removed" | "winner" | "small" | "smallx" | "smallwin") {
    const small = state0.startsWith("small"), state = state0 === "smallx" ? "removed" : state0 === "smallwin" ? "winner" : state0;
    const c = col(k), r = small ? 8 : 11, e = small ? 10 : 13;
    const fill = state === "winner" ? c : PAPER, tf = state === "winner" ? "white" : c;
    this.add(`<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${c}" stroke-width="1.8"/>`);
    this.add(`<text x="${x}" y="${y + 4.5}" ${FONT} font-size="${r + 2}" font-weight="700" fill="${tf}" text-anchor="middle">${k}</text>`);
    if (state === "removed") {
      this.add(`<path d="M${x - e} ${y - e} L${x + e} ${y + e} M${x + e} ${y - e} L${x - e} ${y + e}" stroke="${INK}" stroke-width="1.6"/>`);
    }
  }
  numeralAt(k: number, p: P, state: "in" | "removed" | "winner" | "small" = "small") { this.numeral(k, this.X(p), this.Y(p), state); }
  hatch(k: number, poly: P[]) {
    this.add(`<polygon points="${poly.map((p) => this.xy(p)).join(" ")}" fill="url(#hatch${k})" stroke="none"/>`);
  }
  target(p: P, label: string, at: P, anchor = "end") {
    this.add(diamond(this.X(p), this.Y(p)));
    this.label(label, at, INK, anchor, 12.5);
  }
  arrow(k: number, from: P, to: P, bend: number, thin = false) {
    const x1 = this.X(from), y1 = this.Y(from), x2 = this.X(to), y2 = this.Y(to);
    const mx = (x1 + x2) / 2 - (y2 - y1) * bend, my = (y1 + y2) / 2 + (x2 - x1) * bend;
    this.add(`<path d="M${x1} ${y1} Q${mx} ${my} ${x2} ${y2}" fill="none" stroke="${col(k)}" stroke-width="${thin ? 0.8 : 1.3}" marker-end="url(#arrow${k})"/>`);
    this.numeral(k, 0.25 * x1 + 0.5 * mx + 0.25 * x2, 0.25 * y1 + 0.5 * my + 0.25 * y2, "small");
  }
  circle(c: P, r: number, label: string, at: P) {
    this.add(`<circle cx="${this.X(c)}" cy="${this.Y(c)}" r="${r * this.s}" fill="none" stroke="${CON}" stroke-width="1"/>`);
    this.label(label, at, CON, "start", 11.5);
  }
  hair(k: number, a: P, b: P) {
    this.add(`<line x1="${this.X(a)}" y1="${this.Y(a)}" x2="${this.X(b)}" y2="${this.Y(b)}" stroke="${col(k)}" stroke-width="0.8"/>`);
  }
  mirror(k: number, a: P, b: P) {
    this.hair(k, a, b);
    const ax = this.X(a), ay = this.Y(a), bx = this.X(b), by = this.Y(b), L = Math.hypot(bx - ax, by - ay);
    const ux = (bx - ax) / L * 7, uy = (by - ay) / L * 7, vx = -uy, vy = ux, mx = (ax + bx) / 2, my = (ay + by) / 2;
    this.add(`<path d="M${mx + ux} ${my + uy} l${vx} ${vy} l${-ux} ${-uy}" fill="none" stroke="${col(k)}" stroke-width="0.9"/>`);
  }
  image(k: number, p: P) { this.add(landMark(this.X(p), this.Y(p), col(k))); }
  rail(a: P, b: P, inward: P, label: string, at: P, anchor = "start") {
    const ox = inward[0] * 6, oy = -inward[1] * 6;
    this.add(`<line x1="${this.X(a) + ox}" y1="${this.Y(a) + oy}" x2="${this.X(b) + ox}" y2="${this.Y(b) + oy}" stroke="${CON}" stroke-width="1.4"/>`);
    this.label(label, at, CON, anchor);
  }
  src(k: number | null, p: P) { this.add(`<circle cx="${this.X(p)}" cy="${this.Y(p)}" r="5" fill="${k ? col(k) : INK}"/>`); }
  srcBand(k: number, a: P, b: P, off = 0) {
    const BAND = process.env.BAND ?? "pill";
    const seg = (w: number, c: string, cap = "butt", extra = "") => `<line x1="${this.X(a)}" y1="${this.Y(a)}" x2="${this.X(b)}" y2="${this.Y(b)}" stroke="${c}" stroke-width="${w}" stroke-linecap="${cap}" ${extra}/>`;
    if (BAND === "pill") { this.add(seg(7, PAPER, "round") + seg(4, col(k), "round")); return; }
    if (BAND === "ticks") { this.add(seg(3.2, col(k)) + this.ticks(k, a, b, 1.8)); return; }
    const L = Math.hypot(this.X(b) - this.X(a), this.Y(b) - this.Y(a)), ox = -(this.Y(b) - this.Y(a)) / L * off, oy = (this.X(b) - this.X(a)) / L * off;
    this.add(`<line x1="${this.X(a) + ox}" y1="${this.Y(a) + oy}" x2="${this.X(b) + ox}" y2="${this.Y(b) + oy}" stroke="${col(k)}" stroke-width="${off ? 5 : 6}" opacity="0.35"/>`);
  }
  ticks(k: number, a: P, b: P, w: number) {
    const ax = this.X(a), ay = this.Y(a), bx = this.X(b), by = this.Y(b), L = Math.hypot(bx - ax, by - ay), nx = -(by - ay) / L * 6, ny = (bx - ax) / L * 6;
    return [[ax, ay], [bx, by]].map(([x, y]) => `<line x1="${x - nx}" y1="${y - ny}" x2="${x + nx}" y2="${y + ny}" stroke="${col(k)}" stroke-width="${w}"/>`).join("");
  }
  imgBand(k: number, a: P, b: P) {
    const BAND = process.env.BAND ?? "pill";
    const seg = (w: number, c: string, cap = "butt") => `<line x1="${this.X(a)}" y1="${this.Y(a)}" x2="${this.X(b)}" y2="${this.Y(b)}" stroke="${c}" stroke-width="${w}" stroke-linecap="${cap}"/>`;
    if (BAND === "pill") {
      this.add(seg(7, PAPER, "round") + seg(5, col(k), "round") + seg(2.2, PAPER, "round"));
      const ax = this.X(a), ay = this.Y(a), bx = this.X(b), by = this.Y(b), L = Math.hypot(bx - ax, by - ay);
      this.numeral(k, (ax + bx) / 2 - (by - ay) / L * 13, (ay + by) / 2 + (bx - ax) / L * 13, "small");
      return;
    }
    if (BAND === "ticks") { this.add(seg(1.2, col(k)) + this.ticks(k, a, b, 1.2)); return; }
    const l = (w: number, c: string) => `<line x1="${this.X(a)}" y1="${this.Y(a)}" x2="${this.X(b)}" y2="${this.Y(b)}" stroke="${c}" stroke-width="${w}"/>`;
    this.add(l(6, col(k)) + l(3.4, PAPER));
  }
  imageSeg(k: number, a: P, b: P, off: number) {
    const ay = this.Y(a) + off, by = this.Y(b) + off, ax = this.X(a), bx = this.X(b);
    this.add(`<line x1="${ax}" y1="${ay}" x2="${bx}" y2="${by}" stroke="${col(k)}" stroke-width="1.3"/>`);
    for (const x of [ax, bx]) this.add(`<line x1="${x}" y1="${ay - 5}" x2="${x}" y2="${ay + 5}" stroke="${col(k)}" stroke-width="1.3"/>`);
  }
  // a distance: from the nearest landed point (dot) to the target, its value in a tag beside the middle
  dim(k: number, a: P, b: P, value: string, lab: P) {
    const x1 = this.X(a), y1 = this.Y(a), x2 = this.X(b), y2 = this.Y(b);
    const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy);
    let nx = -dy / L, ny = dx / L;
    const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
    if ((this.X(lab) - mx) * nx + (this.Y(lab) - my) * ny < 0) { nx = -nx; ny = -ny; }
    this.add(`<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${col(k)}" stroke-width="1.4"/>`);
    this.add(`<circle cx="${x1}" cy="${y1}" r="3.5" fill="${col(k)}"/>`);
    const w = 22 + value.length * 7.2, tx = mx + nx * 20 - w / 2, ty = my + ny * 20 - 10;
    this.add(`<rect x="${tx}" y="${ty}" width="${w}" height="20" rx="4" fill="${PAPER}" stroke="${col(k)}" stroke-width="1"/>`);
    this.numeral(k, tx + 10, ty + 10, "small");
    this.add(`<text x="${tx + 21}" y="${ty + 14.5}" ${FONT} font-size="12.5" font-weight="600" fill="${tcol(k)}">${esc(value)}</text>`);
  }
  rows(rows0: [string, string[]][]) {
    const rows = rows0.filter(([h]) => { if (h === "Outcome" || h === "Next") { END.push([h, rows0.find(r => r[0] === h)![1]]); return false; } return true; });
    let y = this.oy + 124 + (((this as any).codeLines ?? 1) - 1) * 16;
    for (const [head, lines] of rows) {
      this.add(`<text x="${this.ox + TX}" y="${y}" ${FONT} font-size="12.5" font-weight="600" fill="${INK}">${esc(head)}</text>`);
      let lastX = false;
      for (const l0 of lines) {
        let l = l0, x = this.ox + TX + 96;
        const cont = !/^\{/.test(l0);
        for (let m; (m = /^\{(\d)([x*]?)\}\s*/.exec(l)); l = l.slice(m[0].length)) { this.numeral(+m[1], x + 8, y - 4.5, m[2] === "x" ? "smallx" : m[2] === "*" ? "smallwin" : "small"); x += 20; }
        if (x > this.ox + TX + 96) x += 3;
        else if (/^\s{2}/.test(l)) { x += 23; l = l.trimStart(); }
        const v = /^(passes|eliminated|holds|both hold)(.*)$/.exec(l);
        const muted = /\{\dx\}/.test(l0) || (cont && lastX);
        if (/^\{\dx\}/.test(l0)) lastX = true; else if (/^\{/.test(l0)) lastX = false;
        this.add(`<text x="${x}" y="${y}" ${FONT} font-size="12.5" fill="${muted ? MUTED : INK}">${v ? `<tspan font-weight="700">${esc(v[1])}</tspan>${esc(v[2])}` : esc(l)}</text>`);
        y += 17;
      }
      y += 3;
    }
    (this as any).rowsEnd = y;
  }
}

function defs() {
  const h = (k: number, angle: number) =>
    `<pattern id="hatch${k}" patternUnits="userSpaceOnUse" width="7" height="7" patternTransform="rotate(${angle})"><rect width="7" height="7" fill="${MONOPRINT ? "none" : k === 1 ? "#c1dff4" : k === 2 ? "#f3d8bf" : "#e9d0ff"}" opacity="0.35"/><line x1="0" y1="0" x2="0" y2="7" stroke="${col(k)}" stroke-width="1.1"/></pattern>`;
  const a = (k: number) =>
    `<marker id="arrow${k}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="${col(k)}"/></marker>`;
  return `<defs>${h(1, 45)}${h(2, -45)}${h(3, 0)}${a(1)}${a(2)}${a(3)}</defs>`;
}

// the legend, drawn with the exact marks; `which` picks the entries that occur
function legend(which: string[], y0: number) {
  const out: string[] = [];
  let x = 20, y = y0;
  const entry = (w: number, mark: string, text: string) => {
    if (x + w + text.length * 6.6 > 830) { x = 20; y += 30; }
    out.push(`<g transform="translate(${x},${y})">${mark}</g>`);
    out.push(`<text x="${x + w + 8}" y="${y + 4}" ${FONT} font-size="12.5" fill="${INK}">${esc(text)}</text>`);
    x += w + 8 + text.length * 6.6 + 26;
  };
  const num = (k: number, st: string) => {
    const c = col(k), fill = st === "winner" ? c : PAPER, tf = st === "winner" ? "white" : c;
    let s = `<circle cx="0" cy="0" r="11" fill="${fill}" stroke="${c}" stroke-width="1.8"/><text x="0" y="4.5" ${FONT} font-size="13" font-weight="700" fill="${tf}" text-anchor="middle">${k}</text>`;
    if (st === "removed") s += `<path d="M-13 -13 L13 13 M13 -13 L-13 13" stroke="${INK}" stroke-width="1.4"/>`;
    return s;
  };
  const E: Record<string, () => void> = {
    cand: () => entry(40, `<line x1="0" y1="0" x2="24" y2="0" stroke="${C1}" stroke-width="2.5"/><g transform="translate(34,0)">${num(1, "in")}</g>`, "a candidate, by its number"),
    removed: () => entry(40, `<line x1="0" y1="0" x2="24" y2="0" stroke="${C1}" stroke-width="0.8"/><g transform="translate(34,0)">${num(1, "removed")}</g>`, "removed by this stage"),
    winner: () => entry(40, `<line x1="0" y1="0" x2="24" y2="0" stroke="${C2}" stroke-width="2.5" stroke-dasharray="7 4"/><g transform="translate(34,0)">${num(2, "winner")}</g>`, "the line kept, as the fold it makes"),
    mark: () => entry(28, `<line x1="0" y1="0" x2="28" y2="0" stroke="${INK}" stroke-width="1.5" stroke-dasharray="1 3" opacity="0.45"/>`, "a mark (drawn, not folded)"),
    read: () => entry(28, `<line x1="0" y1="0" x2="28" y2="0" stroke="${CON}" stroke-width="1.2"/><circle cx="14" cy="0" r="3" fill="${CON}"/>`, "what this stage reads"),
    hatch: () => entry(28, `<rect x="0" y="-8" width="28" height="16" fill="url(#hatch1)" stroke="${C1}" stroke-width="0.5"/>`, "the side that folds over"),
    target: () => entry(16, diamond(8, 0), "the toward or moving point"),
    arrow: () => entry(34, `<circle cx="0" cy="4" r="3.5" fill="${C1}"/><path d="M0 4 Q16 -10 32 2" fill="none" stroke="${C1}" stroke-width="1.6" marker-end="url(#arrow1)"/>`, "what the fold moves"),
    image: () => entry(40, `<circle cx="4" cy="0" r="5" fill="${C1}"/><path d="M11 0 H27" stroke="${C1}" stroke-width="1.4" marker-end="url(#arrow1)"/><g>${landMark(36, 0, C1)}</g>`, "a point that moves, and where it lands (.d′)"),
    band: () => entry(64, `<line x1="3" y1="0" x2="20" y2="0" stroke="${C1}" stroke-width="4" stroke-linecap="round"/><path d="M25 0 H36" stroke="${C1}" stroke-width="1.3" marker-end="url(#arrow1)"/><line x1="45" y1="0" x2="62" y2="0" stroke="${C1}" stroke-width="5" stroke-linecap="round"/><line x1="45" y1="0" x2="62" y2="0" stroke="${PAPER}" stroke-width="2.2" stroke-linecap="round"/>`, "a piece of line that moves, and where it lands (--ac′)"),
    imageSeg: () => entry(28, `<line x1="0" y1="0" x2="28" y2="0" stroke="${C1}" stroke-width="1.3"/><line x1="0" y1="-5" x2="0" y2="5" stroke="${C1}" stroke-width="1.3"/><line x1="28" y1="-5" x2="28" y2="5" stroke="${C1}" stroke-width="1.3"/>`, "where a piece of line lands"),
    construct: () => entry(28, `<path d="M0 6 Q14 -10 28 6" fill="none" stroke="${CON}" stroke-width="1"/>`, "how the stage finds its candidates"),
    rail: () => entry(28, `<line x1="0" y1="-5" x2="28" y2="-5" stroke="${BND}" stroke-width="2.5"/><line x1="0" y1="1" x2="28" y2="1" stroke="${CON}" stroke-width="1.4"/>`, "an edge this stage reads"),
    mirror: () => entry(34, `<line x1="0" y1="0" x2="34" y2="0" stroke="${C1}" stroke-width="0.8"/><path d="M24 0 v-7 h-7" fill="none" stroke="${C1}" stroke-width="0.9"/>`, "where a point can land, mirrored in the candidate"),
    dim: () => entry(28, `<line x1="0" y1="0" x2="28" y2="0" stroke="${C1}" stroke-width="0.9"/><line x1="0" y1="-5" x2="0" y2="5" stroke="${C1}" stroke-width="0.9"/><line x1="28" y1="-5" x2="28" y2="5" stroke="${C1}" stroke-width="0.9"/><text x="14" y="-5" ${FONT} font-size="10" fill="${T1}" text-anchor="middle">0.5</text>`, "distance to the toward point"),
  };
  const groups = [["cand", "removed", "winner"], ["mark", "read", "construct", "mirror"], ["hatch", "target", "rail", "image", "band", "dim"]];
  const all = [...which, ...(which.includes("construct") ? ["mirror"] : [])];
  groups.forEach((g, gi) => { if (gi > 0) { x = 20; y += 30; } for (const w of g) if (all.includes(w)) E[w](); });
  return { svg: out.join("\n"), bottom: y + 20 };
}

let END: [string, string[]][] = [];
const CUTS: Record<string, number[]> = {};
const PARTS: Record<string, { body: string; legend: string; legendTop: number; legendH: number; W: number }> = {};
const TITLES = ["Stage 0 · generate candidates", "Stage 1 · compare with the heading", "Stage 2 · name the folding side", "Stage 3 · check what the fold moves", "Stage 4 · measure the landing"];
const WHY: Record<string, string> = {
  "no heading item": "the fold names no heading",
  "no toward item": "the fold names no toward",
  "no toward or moving item": "the fold names neither toward nor moving",
  "one candidate left": "only one candidate is left",
};
function stagesLine(y: number, parts: [string, boolean][]) {
  const off = parts.filter(([, on]) => !on).map(([t]) => { const [n, r] = t.split(": "); return `stage ${n}, as ${WHY[r]}`; });
  const lines = off.length ? ["Not drawn: " + off.join("; ") + "."] : [];
  const wrapped: string[] = [];
  for (const l of lines) { let cur = ""; for (const w of l.split(" ")) { if ((cur + " " + w).length > 118) { wrapped.push(cur); cur = w; } else cur = cur ? cur + " " + w : w; } wrapped.push(cur); }
  return wrapped.map((l, i) => `<text x="20" y="${y + i * 18}" ${FONT} font-size="13" fill="${MUTED}">${esc(l)}</text>`).join("");
}

const SQ = { ".d": [0, 1] as P, ".c": [1, 1] as P, ".a": [0, 0] as P, ".b": [1, 0] as P };
let PROG = ["paper square", "mark (map .a onto .b) as --ef", "mark (through .b .d) as --bd", ".p = free on --bd from .d at 1/4"];
const parabola: P[] = Array.from({ length: 21 }, (_, i) => { const y = 1 - i * 0.025; return [0.25 - (y - 1) ** 2, y] as P; });
const C1a: P = [0, 0.5], C1b: P = [0.5, 1];    // candidate 1: y = x + 1/2
const C2a: P = [0.25, 1], C2b: P = [0.25, 0];  // candidate 2: x = 1/4
const P_: P = [0.25, 0.75];

// clip the line n·x = c to the unit square
function clip(n: P, c: number): [P, P] {
  const pts: P[] = [];
  for (const x of [0, 1]) { const y = (c - n[0] * x) / n[1]; if (Math.abs(n[1]) > 1e-9 && y >= -1e-9 && y <= 1 + 1e-9) pts.push([x, y]); }
  for (const y of [0, 1]) { const x = (c - n[1] * y) / n[0]; if (Math.abs(n[0]) > 1e-9 && x > 1e-9 && x < 1 - 1e-9) pts.push([x, y]); }
  return [pts[0], pts[1]];
}
// axiom 6 by hand: landings of .d on x = 1/2 around .p, and the crease for each
function ax6(pp: P) {
  const d: P = [0, 1], r = Math.hypot(pp[0] - d[0], pp[1] - d[1]), h = Math.sqrt(r * r - (0.5 - pp[0]) ** 2);
  const qs: P[] = [[0.5, pp[1] - h], [0.5, pp[1] + h]];
  const lines = qs.map((q) => { const n: P = [q[0] - d[0], q[1] - d[1]]; const m: P = [(q[0] + d[0]) / 2, (q[1] + d[1]) / 2]; return clip(n, n[0] * m[0] + n[1] * m[1]); });
  return { r, qs, lines };
}
function stage0(p: Panel, pp: P, lab: P, numEnds: [boolean, boolean]) {
  const g = ax6(pp);
  p.read([0.5, -0.12], [0.5, 1.2], "--ef", [0.53, 0.18]);
  p.circle(pp, g.r, "circle about .p", [0.62, 0.3]); p.label("through .d", [0.62, 0.23], CON, "start", 11.5);
  g.qs.forEach((q, i) => { const k = i + 1; p.mirror(k, [0, 1], q); });
  g.lines.forEach((l, i) => { const k = i + 1; p.cand(k, numEnds[i] ? l[1] : l[0], numEnds[i] ? l[0] : l[1], "in"); });
  g.qs.forEach((q, i) => { const k = i + 1; p.image(k, q); p.numeralAt(k, [q[0] + 0.07, q[1] + 0.02]); });
  p.readPoint(pp, ".p", lab);
  p.src(null, [0, 1]);
}
function base(p: Panel, readEf: boolean) {
  p.paper();
  p.corners(SQ);
  p.mark([1, 0], [0, 1]);
  if (!readEf) p.mark([0.5, 0], [0.5, 1]);
}

function figure(file: string, mode: "spec" | "author", foldLine: string, hl: Record<string, [string, string, string]>,
  header: [string, boolean][], legendKeys: string[], panels: ((p: Panel) => void)[]) {
  // the context: the statements before the traced one, once, above the panels
  const ctxY = 30;
  const ctx = [`<text x="20" y="${ctxY}" ${FONT} font-size="12.5" font-weight="600" fill="${INK}">Program</text>`,
    ...PROG.map((l, i) => `<text x="92" y="${ctxY + i * 16}" ${MONO} font-size="11.5" fill="${MUTED}">${esc(l)}</text>`),
    `<text x="92" y="${ctxY + PROG.length * 16}" ${MONO} font-size="11.5" font-weight="700" fill="${INK}">${esc(foldLine)}</text>`];
  const top = ctxY + PROG.length * 16 + 24;
  const perRow = 1;
  const L = legend(legendKeys, 0);
  const W = 20 + perRow * (PW + 20);
  const body: string[] = [];
  END = [];
  const cuts: number[] = [0, top - 20];
  let y = top, next = 0;
  header.forEach(([t, on], si) => {
    if (si > 0) cuts.push(y - 8);
    if (si > 0) body.push(`<line x1="20" y1="${y - 6}" x2="${20 + PW}" y2="${y - 6}" stroke="#64748b" stroke-width="2"/>`);
    if (!on) {
      const r = t.split(": ")[1];
      body.push(`<text x="${20 + TX}" y="${y + 26}" ${FONT} font-size="15" font-weight="600" fill="${MUTED}">${esc(TITLES[si])}</text>`);
      body.push(`<text x="${20 + TX}" y="${y + 48}" ${FONT} font-size="12.5" fill="${MUTED}">${esc("Skipped, as " + WHY[r] + ".")}</text>`);
      y += 70; return;
    }
    const p = new Panel(20, y);
    (p as any).hl = hl; (p as any).fold = foldLine; (p as any).mode = mode;
    panels[next++](p);
    body.push(...p.out);
    y += (p as any).h ?? PH;
  });
  cuts.push(y - 10);
  if (END.length) {
    body.push(`<line x1="20" y1="${y - 6}" x2="${20 + PW}" y2="${y - 6}" stroke="${INK}" stroke-width="3"/>`);
    const e = new Panel(20, y - 124 + 30);
    e.rows(END.splice(0).map(([h, l]) => [h + " ", l]));
    body.push(...e.out);
    y += 30 + 24 * 3;
  }
  cuts.push(y + 20);
  const Lb = legend(legendKeys, y + 40), H = Lb.bottom + 10;
  CUTS[file] = cuts;
  PARTS[file] = { body: `${defs()}\n${ctx.join("\n")}\n${body.join("\n")}`, legend: Lb.svg, legendTop: y + 20, legendH: Lb.bottom + 10 - (y + 20), W };
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><rect width="100%" height="100%" fill="white"/>${defs()}\n${Lb.svg}\n${ctx.join("\n")}\n${body.join("\n")}</svg>`;
  writeFileSync(file, svg);
}

function prog(p: Panel, key: string) {
  const [a, b, c] = (p as any).hl[key], full = a + b + c, h0 = a.length, h1 = a.length + b.length;
  const breaks: number[] = [0];
  let last = 0;
  for (let i = 1; i < full.length; i++) if (full.slice(i - 2, i + 1) === ") (" && i - last > 20 && full.length - last > 52) {
    const nextBreak = full.indexOf(") (", i + 1);
    if (i - last > 44 || (nextBreak > 0 && nextBreak - last > 54)) { breaks.push(i); last = i; }
  }
  breaks.push(full.length);
  for (let li = 0; li < breaks.length - 1; li++) {
    const s0 = breaks[li], s1 = breaks[li + 1], y = p.oy + 88 + li * 16, x = p.ox + TX + (li ? 16 : 0);
    const part = (from: number, to: number, hl: boolean) => from < to ? (hl ? `<tspan fill="${CON}" font-weight="700" text-decoration="underline">${esc(full.slice(from, to))}</tspan>` : esc(full.slice(from, to))) : "";
    const A = Math.max(s0, Math.min(h0, s1)), B = Math.max(s0, Math.min(h1, s1));
    p.add(`<text x="${x}" y="${y}" ${MONO} font-size="11.5" fill="${INK}">${part(s0, A, false)}${part(A, B, true)}${part(B, s1, false)}</text>`);
  }
  (p as any).codeLines = breaks.length - 1;
}
const spec = (p: Panel) => (p as any).mode === "spec";

// ---------- Figure A: (toward .c), spec reader: a point moves onto a line ----------
const foldA = "fold (map .d onto --ef through .p) (toward .c) as --s";
figure("A-toward-c.svg", "spec", foldA, {
  align: ["fold (map ", ".d onto --ef through .p", ") (toward .c) as --s"],
  toward: ["fold (map .d onto --ef through .p) (", "toward .c", ") as --s"],
}, [["0 candidates", true], ["1 heading: no heading item", false], ["2 side", true], ["3 moved material", true], ["4 landing", true]],
["cand", "removed", "winner", "mark", "read", "construct", "hatch", "target", "image", "dim"], [
  (p) => {
    p.title("Stage 0 · generate candidates"); prog(p, "align"); base(p, true);
    stage0(p, P_, [0.18, 0.66], [true, true]);
    p.rows([
      ...(spec(p) ? [["Constructs", [".p lies on the crease, so .d lands as far from .p", "as it is now: on the circle. Where the circle", "meets --ef, .d can land; each landing gives", "one crease. Does the crease cross the paper?"]] as [string, string[]]] : []),
      ["Yields", ["{1}{2} one crease for each landing of .d"]],
    ]);
  },
  (p) => {
    p.title("Stage 2 · name the folding side"); prog(p, "toward"); base(p, false);
    p.hatch(2, [[0, 0], [0.25, 0], [0.25, 1], [0, 1]]);
    p.hatch(1, [[0, 0.5], [0.5, 1], [0, 1]]);
    p.cand(2, C2a, C2b, "in"); p.cand(1, C1b, C1a, "in");
    p.numeralAt(1, [0.33, 0.93]); p.numeralAt(2, [0.12, 0.2]);
    p.target([1, 1], "toward .c", [0.94, 1.05]);
    p.rows([
      ...(spec(p) ? [["Checks", ["Which side of each line holds .c?", "It stays; the other side folds over."]] as [string, string[]]] : []),
      ["Result", ["{1} passes: .c lies on one side", "{2} passes: .c lies on one side"]],
    ]);
  },
  (p) => {
    p.title("Stage 3 · check what the fold moves"); prog(p, "align"); base(p, true);
    p.read([0.5, 0], [0.5, 1], "--ef", [0.53, 0.2]);
    p.cand(2, C2a, C2b, "in"); p.cand(1, C1b, C1a, "in");
    p.arrow(1, [0, 1], [0.5, 0.5], 0.35); p.arrow(2, [0, 1], [0.5, 1], -0.35);
    p.src(null, [0, 1]); p.image(1, [0.5, 0.5]); p.image(2, [0.5, 1]);
    p.label(".d′", [0.54, 0.46], T1); p.label(".d′", [0.54, 1.04], T2);
    p.rows([
      ...(spec(p) ? [["Checks", ["Does the fold carry out every alignment: an", "object on the folding side lands on the other's paper?"]] as [string, string[]]] : []),
      ["Result", ["{1} passes: .d lands on --ef", "{2} passes: .d lands on --ef"]],
    ]);
  },
  (p) => {
    p.title("Stage 4 · measure the landing"); prog(p, "toward"); base(p, false);
    p.cand(1, C1b, C1a, "removed"); p.cand(2, C2a, C2b, "winner");
    p.image(1, [0.5, 0.5]); p.image(2, [0.5, 1]);
    p.label(".d′", [0.43, 0.46], T1);
    p.dim(1, [0.5, 0.5], [1, 1], "1: 0.71", [0.78, 0.55]);
    p.dim(2, [0.5, 0.955], [1, 0.955], "2: 0.50", [0.6, 0.83]);
    p.target([1, 1], "toward .c", [0.94, 1.05]);
    p.rows([
      ...(spec(p) ? [["Checks", ["How far from .c do the objects of the", "alignments land? The nearest wins."]] as [string, string[]]] : []),
      ["Result", ["{1x} eliminated: lands 0.71 from .c", "{2} passes: lands 0.50 from .c"]],
      ["Outcome", ["{2*} holds"]],
    ]);
  },
]);

// ---------- Figure B: (moving .a), author, ambiguous: a point moves, and a line moves onto a point ----------
const foldB = "fold (map .d onto --ef through .p) (moving .a) as --s";
figure("B-moving-a.svg", "author", foldB, {
  align: ["fold (map ", ".d onto --ef through .p", ") (moving .a) as --s"],
  moving: ["fold (map .d onto --ef through .p) (", "moving .a", ") as --s"],
}, [["0 candidates", true], ["1 heading: no heading item", false], ["2 side", true], ["3 moved material", true], ["4 landing: no toward item", false]],
["cand", "mark", "read", "construct", "hatch", "target", "image", "band"], [
  (p) => {
    p.title("Stage 0 · generate candidates"); prog(p, "align"); base(p, true);
    stage0(p, P_, [0.18, 0.66], [true, true]);
    p.rows([["Yields", ["{1}{2} one crease for each landing of .d"]]]);
  },
  (p) => {
    p.title("Stage 2 · name the folding side"); prog(p, "moving"); base(p, false);
    p.hatch(1, [[0, 0], [1, 0], [1, 1], [0.5, 1], [0, 0.5]]);
    p.hatch(2, [[0, 0], [0.25, 0], [0.25, 1], [0, 1]]);
    p.cand(2, C2a, C2b, "in"); p.cand(1, C1b, C1a, "in");
    p.numeralAt(1, [0.75, 0.3]); p.numeralAt(2, [0.12, 0.85]);
    p.target([0, 0], "moving .a", [0.29, 0.04], "start");
    p.rows([["Result", ["{1} passes: .a lies on one side", "{2} passes: .a lies on one side"]]]);
  },
  (p) => {
    p.title("Stage 3 · check what the fold moves"); prog(p, "align"); base(p, true);
    p.read([0.5, 0], [0.5, 1], "--ef", [0.53, 0.2]);
    p.cand(2, C2a, C2b, "in"); p.cand(1, C1b, C1a, "in");
    // 1: --ef folds over; its image --ef′ runs along the top edge, through .d
    p.srcBand(1, [0.5, 0.38], [0.5, 0.62]); p.imgBand(1, [-0.12, 1], [0.12, 1]);
    p.arrow(1, [0.5, 0.5], [0, 1], 0.3); p.src(1, [0.5, 0.5]); p.image(1, [0, 1]);
    p.label("--ef′", [-0.3, 1.07], T1);
    // 2: .d lands on --ef
    p.arrow(2, [0, 1], [0.5, 1], -0.35); p.src(2, [0, 1]); p.image(2, [0.5, 1]); p.label(".d′", [0.55, 1.06], T2);
    p.rows([
      ["Result", ["{1} passes: --ef folds over, and its paper", "  at the dot lands on .d", "{2} passes: .d lands on --ef"]],
      ["Outcome", ["{1}{2} both hold: ambiguous"]],
      ["Next", ["{1} to keep it, add (toward .d)", "{2} to keep it, add (toward .c)"]],
    ]);
  },
]);

// ---------- Figure C: (toward .d) keeps .d still; --ef has to bring paper ----------
PROG = ["paper square", "mark (map .a onto .b) as --ef", "mark (through .b .d) as --bd", ".p = free on --bd from .d at 3/10"];
const PC: P = [0.3, 0.7];
const gC = ax6(PC);
const nC: P = [gC.qs[0][0], gC.qs[0][1] - 1], cC = nC[0] * gC.qs[0][0] / 2 + nC[1] * (gC.qs[0][1] + 1) / 2;
const efTop: P = [0.5, (cC - nC[0] * 0.5) / nC[1]];     // where --ef crosses candidate 1
const foldC = "fold (map .d onto --ef through .p) (toward .d) as --s";
figure("C-off-paper.svg", "author", foldC, {
  align: ["fold (map ", ".d onto --ef through .p", ") (toward .d) as --s"],
  toward: ["fold (map .d onto --ef through .p) (", "toward .d", ") as --s"],
}, [["0 candidates", true], ["1 heading: no heading item", false], ["2 side", true], ["3 moved material", true], ["4 landing: one candidate left", false]],
["cand", "removed", "winner", "mark", "read", "construct", "hatch", "target", "image", "band"], [
  (p) => {
    p.title("Stage 0 · generate candidates"); prog(p, "align"); base(p, true);
    stage0(p, PC, [0.34, 0.66], [true, true]);
    p.rows([["Yields", ["{1}{2} one crease for each landing of .d"]]]);
  },
  (p) => {
    p.title("Stage 2 · name the folding side"); prog(p, "toward"); base(p, false);
    const [a1, b1] = gC.lines[0], [a2, b2] = gC.lines[1];
    p.hatch(1, [[0, 0], [1, 0], [1, 1], b1, a1]);
    p.hatch(2, [b2, [1, 1], [1, 0], a2]);
    p.cand(2, b2, a2, "in"); p.cand(1, b1, a1, "in");
    p.numeralAt(1, [0.22, 0.2]); p.numeralAt(2, [0.8, 0.8]);
    p.target([0, 1], "toward .d", [0.05, 1.05], "start");
    p.rows([["Result", ["{1} passes: .d lies on one side", "{2} passes: .d lies on one side"]]]);
  },
  (p) => {
    p.title("Stage 3 · check what the fold moves"); prog(p, "align"); base(p, true);
    p.read([0.5, -0.12], [0.5, 1.2], "--ef", [0.53, 0.18]);
    const [a1, b1] = gC.lines[0], [a2, b2] = gC.lines[1];
    p.cand(2, b2, a2, "removed"); p.cand(1, b1, a1, "winner");
    const lo: P = [0.5, gC.qs[0][1] - 0.12], hi: P = [0.5, gC.qs[0][1] + 0.12];
    p.srcBand(1, lo, hi); p.imgBand(1, refl(nC, cC, lo), refl(nC, cC, hi));
    p.label("--ef′", [-0.3, 0.9], T1);
    p.arrow(1, gC.qs[0], [0, 1], -0.3); p.src(1, gC.qs[0]); p.image(1, [0, 1]);
    p.arrow(2, gC.qs[1], [0, 1], 0.25, true);
    p.add(`<path d="M${p.X(gC.qs[1]) - 6} ${p.Y(gC.qs[1]) - 6} l12 12 m0 -12 l-12 12" stroke="${C2}" stroke-width="2"/>`);
    p.label("--ef has no paper here", [0.56, 1.1], T2, "start", 11.5);
    p.rows([
      ["Result", ["{1} passes: --ef folds over, and its paper", "  at the dot lands on .d", "{2x} eliminated: .d stays, and the paper", "  of --ef that would land on it lies", "  beyond the edge"]],
      ["Outcome", ["{1*} holds"]],
    ]);
  },
]);

// ---------- Figures D and E: a line onto a line (axiom 5), verified against the kernel ----------
PROG = ["paper square", "mark (through .a .c) as --ac", "mark (through .b .d) as --bd"];
const H1a: P = [1, 0.5], H1b: P = [0, 0.5];     // candidate 1: y = 1/2, numeral left
const V2a: P = [0.5, 1], V2b: P = [0.5, 0];     // candidate 2: x = 1/2, numeral below
function stage0ax5(p: Panel) {
  p.read([0, 0], [1, 1], "--ac", [0.8, 0.9], "end"); p.read([1, 0], [0, 1], "--bd", [0.2, 0.9]);
  const o = [p.X([0.5, 0.5]), p.Y([0.5, 0.5])], r = 0.13 * S;
  const pt = (deg: number) => [o[0] + r * Math.cos(deg * Math.PI / 180), o[1] - r * Math.sin(deg * Math.PI / 180)];
  const arc = (a: number, b: number) => { const [x1, y1] = pt(a), [x2, y2] = pt(b); return `<path d="M${x1} ${y1} A${r} ${r} 0 0 0 ${x2} ${y2}" fill="none" stroke="${CON}" stroke-width="1"/>`; };
  p.add(arc(-45, 45) + arc(45, 135));
  for (const [deg, n] of [[-22.5, 1], [22.5, 1], [67.5, 2], [112.5, 2]] as [number, number][]) {
    for (let i = 0; i < n; i++) { const [x, y] = pt(deg + (i - (n - 1) / 2) * 5); const ux = Math.cos(deg * Math.PI / 180), uy = -Math.sin(deg * Math.PI / 180); p.add(`<line x1="${x - ux * 4}" y1="${y - uy * 4}" x2="${x + ux * 4}" y2="${y + uy * 4}" stroke="${CON}" stroke-width="1"/>`); }
  }
  p.label("equal angles", [0.66, 0.42], CON, "start", 11.5);
  p.cand(2, V2a, V2b, "in"); p.cand(1, H1a, H1b, "in");
}
const foldD = "fold (map --ac onto --bd) (toward .b) (moving .c) as --s";
figure("D-line-onto-line.svg", "author", foldD, {
  align: ["fold (map ", "--ac onto --bd", ") (toward .b) (moving .c) as --s"],
  side: ["fold (map --ac onto --bd) (", "toward .b) (moving .c", ") as --s"],
}, [["0 candidates", true], ["1 heading: no heading item", false], ["2 side", true], ["3 moved material", true], ["4 landing: one candidate left", false]],
["cand", "removed", "winner", "mark", "read", "construct", "hatch", "target", "band"], [
  (p) => {
    p.title("Stage 0 · generate candidates"); prog(p, "align"); p.paper(); p.corners(SQ);
    stage0ax5(p);
    p.rows([["Yields", ["{1}{2} one crease for each landing of .d"]]]);
  },
  (p) => {
    p.title("Stage 2 · name the folding side"); prog(p, "side"); p.paper(); p.corners(SQ); p.mark([0, 0], [1, 1]); p.mark([1, 0], [0, 1]);
    p.hatch(1, [[0, 0.5], [1, 0.5], [1, 1], [0, 1]]);
    p.cand(2, V2a, V2b, "removed"); p.cand(1, H1a, H1b, "in");
    p.numeralAt(1, [0.25, 0.8]);
    p.target([1, 0], "toward .b", [0.95, 0.05]); p.target([1, 1], "moving .c", [0.95, 0.9]);
    p.rows([["Result", ["{1} passes: .b stays, .c folds over", "{2x} eliminated: .b and .c lie on the same", "  side, so toward and moving contradict"]]]);
  },
  (p) => {
    p.title("Stage 3 · check what the fold moves"); prog(p, "align"); p.paper(); p.corners(SQ);
    p.read([0, 0], [1, 1], "--ac", [0.3, 0.2]); p.read([1, 0], [0, 1], "--bd", [0.12, 0.72]);
    p.cand(1, H1a, H1b, "winner");
    p.srcBand(1, [0.5, 0.5], [1, 1]); p.imgBand(1, [0.5, 0.5], [1, 0]);
    p.arrow(1, [0.8, 0.8], [0.8, 0.2], -0.35);
    p.label("--ac′", [0.66, 0.1], T1);
    p.rows([["Result", ["{1} passes: the half of --ac above the line", "  folds over and lands on --bd"]], ["Outcome", ["{1*} holds"]]]);
  },
]);

const foldE = "fold (map --ac onto --bd) as --s";
function halves(p: Panel, k: number, mid: number, r: number, lab: P) {
  const o = [p.X([0.5, 0.5]), p.Y([0.5, 0.5])], R = r * p.s;
  const pt = (d: number) => [o[0] + R * Math.cos(d * Math.PI / 180), o[1] - R * Math.sin(d * Math.PI / 180)];
  const [x1, y1] = pt(mid - 45), [x2, y2] = pt(mid), [x3, y3] = pt(mid + 45);
  p.add(`<path d="M${x1} ${y1} A${R} ${R} 0 0 0 ${x2} ${y2}" fill="none" stroke="${col(k)}" stroke-width="1.4"/><path d="M${x2} ${y2} A${R} ${R} 0 0 0 ${x3} ${y3}" fill="none" stroke="${col(k)}" stroke-width="1.4" stroke-dasharray="none"/>`);
  for (const d of [mid - 22.5, mid + 22.5]) { const [x, y] = pt(d); const ux = Math.cos(d * Math.PI / 180), uy = -Math.sin(d * Math.PI / 180); p.add(`<line x1="${x - ux * 4}" y1="${y - uy * 4}" x2="${x + ux * 4}" y2="${y + uy * 4}" stroke="${col(k)}" stroke-width="1.4"/>`); }
  p.label("45° | 45°", lab, tcol(k), "start", 11.5);
}
figure("E-line-onto-line-ambiguous.svg", "spec", foldE, {
  align: ["fold (map ", "--ac onto --bd", ") as --s"],
}, [["0 candidates", true], ["1 heading: no heading item", false], ["2 side: no toward or moving item", false], ["3 moved material", true], ["4 landing: no toward item", false]],
["cand", "mark", "read", "construct", "band"], [
  (p) => {
    p.title("Stage 0 · generate candidates"); prog(p, "align"); p.paper(); p.corners(SQ);
    p.read([0, 0], [1, 1], "--ac", [0.8, 0.9], "end"); p.read([1, 0], [0, 1], "--bd", [0.2, 0.9]);
    p.cand(2, V2a, V2b, "in"); p.cand(1, H1a, H1b, "in");
    halves(p, 1, 0, 0.17, [0.7, 0.54]); halves(p, 2, 90, 0.26, [0.58, 0.8]);
    p.rows([
      ["Constructs", ["The crease mirrors --ac onto --bd, so it makes", "the same angle with both: it halves an angle", "where they cross. Two crossing lines make two", "angles, so there are two candidates."]],
      ["Yields", ["{1} halves the angle on the right", "{2} halves the angle at the top"]],
    ]);
  },
  (p) => {
    p.title("Stage 3 · check what the fold moves"); prog(p, "align");
    const sub = (k: number, dx: number) => {
      const q = new Panel(p.ox, p.oy + (dx / 185) * 330, 220, 80, 50);
      q.paper(); q.read([0, 0], [1, 1], "--ac", [0.34, 0.2]); q.read([1, 0], [0, 1], "--bd", [0.8, 0.3]);
      if (k === 1) { q.cand(1, H1a, H1b, "in"); q.srcBand(1, [0.5, 0.5], [1, 1]); q.imgBand(1, [0.5, 0.5], [1, 0]); q.arrow(1, [0.82, 0.82], [0.82, 0.18], -0.3); q.label("--ac′", [0.55, 0.1], T1, "start", 11.5); }
      else { q.cand(2, V2a, V2b, "in"); q.srcBand(2, [0.5, 0.5], [1, 1]); q.imgBand(2, [0.5, 0.5], [0, 1]); q.arrow(2, [0.82, 0.82], [0.18, 0.82], 0.3); q.label("--ac′", [0.08, 0.66], T2, "start", 11.5); }
      p.out.push(...q.out);
    };
    p.rows([
      ["Checks", ["Does the fold carry out every alignment: an", "object on the folding side lands on the other's", "paper? One square per candidate, as both move", "the same half of --ac."]],
      ["Result", ["{1} passes: the half of --ac from the crossing", "  to .c folds down onto --bd", "{2} passes: the same half folds left onto --bd", "(either side works for both; one is drawn)"]],
      ["Outcome", ["{1}{2} both hold: ambiguous"]],
      ["Next", ["{1} to keep it, add (toward --ab)", "{2} to keep it, add (toward --bc)"]],
    ]);
    sub(1, 0); sub(2, 185);
    (p as any).h = 2 * 330 + 10;
  },
]);

// ---------- Figure F: an input on the boundary, drawn as a rail ----------
const foldF = "fold (map --ac onto --bd) (toward --ab) as --s";
figure("F-toward-edge.svg", "author", foldF, {
  align: ["fold (map ", "--ac onto --bd", ") (toward --ab) as --s"],
  toward: ["fold (map --ac onto --bd) (", "toward --ab", ") as --s"],
}, [["0 candidates", true], ["1 heading: no heading item", false], ["2 side", true], ["3 moved material", true], ["4 landing: one candidate left", false]],
["cand", "removed", "winner", "mark", "read", "construct", "hatch", "rail", "band"], [
  (p) => {
    p.title("Stage 0 · generate candidates"); prog(p, "align"); p.paper(); p.corners(SQ);
    p.read([0, 0], [1, 1], "--ac", [0.8, 0.9], "end"); p.read([1, 0], [0, 1], "--bd", [0.2, 0.9]);
    p.cand(2, V2a, V2b, "in"); p.cand(1, H1a, H1b, "in");
    halves(p, 1, 0, 0.17, [0.7, 0.54]); halves(p, 2, 90, 0.26, [0.58, 0.8]);
    p.rows([["Yields", ["{1} halves the angle on the right", "{2} halves the angle at the top"]]]);
  },
  (p) => {
    p.title("Stage 2 · name the folding side"); prog(p, "toward"); p.paper(); p.corners(SQ); p.mark([0, 0], [1, 1]); p.mark([1, 0], [0, 1]);
    p.hatch(1, [[0, 0.5], [1, 0.5], [1, 1], [0, 1]]);
    p.cand(2, V2a, V2b, "removed"); p.cand(1, H1a, H1b, "in");
    p.numeralAt(1, [0.25, 0.8]);
    p.rail([0, 0], [1, 0], [0, 1], "toward --ab", [0.62, 0.07]);
    p.rows([["Result", ["{1} passes: --ab lies below it and stays", "{2x} eliminated: --ab crosses it, so it", "  names no side"]]]);
  },
  (p) => {
    p.title("Stage 3 · check what the fold moves"); prog(p, "align"); p.paper(); p.corners(SQ);
    p.read([0, 0], [1, 1], "--ac", [0.3, 0.2]); p.read([1, 0], [0, 1], "--bd", [0.12, 0.72]);
    p.cand(1, H1a, H1b, "winner");
    p.srcBand(1, [0.5, 0.5], [1, 1]); p.imgBand(1, [0.5, 0.5], [1, 0]);
    p.arrow(1, [0.8, 0.8], [0.8, 0.2], -0.35);
    p.label("--ac′", [0.66, 0.1], T1);
    p.rows([["Result", ["{1} passes: the half of --ac above the line", "  folds over and lands on --bd"]], ["Outcome", ["{1*} holds"]]]);
  },
]);

// ---------- shared helpers for the full runs ----------
type Ln = [number, number, number];                          // a·x + b·y = c, as the trace writes it
function clipL(L: Ln): [P, P] { return clip([L[0], L[1]], L[2]); }
function parab(F: P, L: Ln): P[] {
  const n2 = L[0] ** 2 + L[1] ** 2, n = Math.sqrt(n2), un: P = [L[0] / n, L[1] / n], dir: P = [-un[1], un[0]];
  const D0: P = [L[0] * L[2] / n2, L[1] * L[2] / n2], out: P[] = [];
  for (let t = -3; t <= 3; t += 0.01) {
    const D: P = [D0[0] + t * dir[0], D0[1] + t * dir[1]], w: P = [D[0] - F[0], D[1] - F[1]];
    const s0 = -(w[0] ** 2 + w[1] ** 2) / (2 * (un[0] * w[0] + un[1] * w[1]));
    const Pp: P = [D[0] + s0 * un[0], D[1] + s0 * un[1]];
    if (Pp[0] > -0.3 && Pp[0] < 1.3 && Pp[1] > -0.3 && Pp[1] < 1.3) out.push(Pp);
  }
  return out;
}
function arcAt(p: Panel, at: P, fromDeg: number, toDeg: number, r: number, k: number | null, lab: string, labAt: P) {
  const o = [p.X(at), p.Y(at)], R = r * p.s, c = k ? col(k) : CON;
  const pt = (d: number) => [o[0] + R * Math.cos(d * Math.PI / 180), o[1] - R * Math.sin(d * Math.PI / 180)];
  const [x1, y1] = pt(fromDeg), [x2, y2] = pt(toDeg), sweep = toDeg > fromDeg ? 0 : 1;
  p.add(`<path d="M${x1} ${y1} A${R} ${R} 0 0 ${sweep} ${x2} ${y2}" fill="none" stroke="${c}" stroke-width="1.4"/>`);
  p.label(lab, labAt, k ? tcol(k) : CON, "start", 11.5);
}
function shortPiece(p: Panel, k: number, L: Ln, lineDir: P, spot: P, target: P, half = 0.09) {
  const lo: P = [spot[0] - lineDir[0] * half, spot[1] - lineDir[1] * half], hi: P = [spot[0] + lineDir[0] * half, spot[1] + lineDir[1] * half];
  p.srcBand(k, lo, hi); p.imgBand(k, refl([L[0], L[1]], L[2], lo), refl([L[0], L[1]], L[2], hi));
  p.arrow(k, spot, target, 0.25); p.src(k, spot); p.image(k, target);
}

// ---------- Figure G: axiom 5, every stage (packages/core/tests/cases/select/heading-tie-toward.bel) ----------
PROG = ["paper square", "mark (map .a onto .b) as --v", "mark (map .a onto .d) as --h", ".u = free on --ab from .b at 1/5"];
const G1: Ln = [1, -1, 0], G2: Ln = [1, 1, 1], U: P = [0.8, 0];
const foldG = "fold (align (--v onto --h) (heading --ab)) (--v toward .u) as --s";
function gBase(p: Panel, reads = true) {
  p.paper(); p.corners(SQ);
  if (reads) { p.read([0.5, 0], [0.5, 1], "--v", [0.53, 0.9]); p.read([0, 0.5], [1, 0.5], "--h", [0.03, 0.53]); }
  else { p.mark([0.5, 0], [0.5, 1]); p.mark([0, 0.5], [1, 0.5]); }
}
figure("G-full-axiom5.svg", "spec", foldG, {
  align: ["fold (align (", "--v onto --h", ") (heading --ab)) (--v toward .u) as --s"],
  heading: ["fold (align (--v onto --h) (", "heading --ab", ")) (--v toward .u) as --s"],
  toward: ["fold (align (--v onto --h) (heading --ab)) (", "--v toward .u", ") as --s"],
}, [["0 candidates", true], ["1 heading", true], ["2 side", true], ["3 moved material", true], ["4 landing", true]],
["cand", "removed", "winner", "mark", "read", "construct", "hatch", "target", "rail", "band", "dim"], [
  (p) => {
    p.title("Stage 0 · generate candidates"); prog(p, "align"); gBase(p);
    p.cand(1, [1, 1], [0, 0], "in"); p.cand(2, [1, 0], [0, 1], "in");
    halves(p, 1, 45, 0.16, [0.64, 0.66]); halves(p, 2, 135, 0.25, [0.12, 0.8]);
    p.rows([
      ["Constructs", ["The crease mirrors --v onto --h, so it makes the", "same angle with both: it halves an angle where", "they cross. Two crossing lines make two angles."]],
      ["Yields", ["{1} halves the angle at the top right", "{2} halves the angle at the top left"]],
    ]);
  },
  (p) => {
    p.title("Stage 1 · compare with the heading"); prog(p, "heading"); gBase(p, false);
    p.cand(1, [1, 1], [0, 0], "in"); p.cand(2, [1, 0], [0, 1], "in");
    p.rail([0, 0], [1, 0], [0, 1], "heading --ab", [0.36, 0.06]);
    arcAt(p, [0, 0], 0, 45, 0.16, 1, "45°", [0.17, 0.05]);
    arcAt(p, [1, 0], 180, 135, 0.16, 2, "45°", [0.72, 0.05]);
    p.rows([
      ["Checks", ["Which candidate makes the smallest angle with", "--ab? Its position plays no part."]],
      ["Result", ["{1} passes: 45° to --ab", "{2} passes: 45° to --ab, a tie passes on"]],
    ]);
  },
  (p) => {
    p.title("Stage 2 · name the folding side"); prog(p, "toward"); gBase(p, false);
    p.hatch(1, [[0, 0], [1, 1], [0, 1]]); p.hatch(2, [[1, 0], [1, 1], [0, 1]]);
    p.cand(1, [1, 1], [0, 0], "in"); p.cand(2, [1, 0], [0, 1], "in");
    p.numeralAt(1, [0.1, 0.6]); p.numeralAt(2, [0.9, 0.6]);
    p.target(U, "toward .u", [0.75, 0.06]);
    p.rows([
      ["Checks", ["Which side of each line holds .u? It stays;", "the other side folds over."]],
      ["Result", ["{1} passes: .u lies on one side", "{2} passes: .u lies on one side"]],
    ]);
  },
  (p) => {
    p.title("Stage 3 · check what the fold moves"); prog(p, "align");
    const sub = (k: number, dx: number) => {
      const q = new Panel(p.ox, p.oy + (dx / 185) * 330, 220, 80, 50);
      q.paper(); q.read([0.5, 0], [0.5, 1], "--v", [0.53, 0.1]); q.read([0, 0.5], [1, 0.5], "--h", [0.03, 0.4]);
      if (k === 1) { q.cand(1, [1, 1], [0, 0], "in"); q.srcBand(1, [0.5, 0.5], [0.5, 1]); q.imgBand(1, [0.5, 0.5], [1, 0.5]); q.arrow(1, [0.5, 0.85], [0.85, 0.5], -0.3); q.label("--v′", [0.75, 0.38], T1, "start", 11.5); }
      else { q.cand(2, [1, 0], [0, 1], "in"); q.srcBand(2, [0.5, 0.5], [0.5, 1]); q.imgBand(2, [0.5, 0.5], [0, 0.5]); q.arrow(2, [0.5, 0.85], [0.15, 0.5], 0.3); q.label("--v′", [0.08, 0.38], T2, "start", 11.5); }
      p.out.push(...q.out);
    };
    p.rows([
      ["Checks", ["Does the fold carry out every alignment: an", "object on the folding side lands on the other's", "paper?"]],
      ["Result", ["{1} passes: the upper half of --v folds right", "  onto --h", "{2} passes: the same half folds left onto --h"]],
    ]);
    sub(1, 0); sub(2, 185);
    (p as any).h = 2 * 330 + 10;
  },
  (p) => {
    p.title("Stage 4 · measure the landing"); prog(p, "toward");
    const sub = (k: number, dx: number) => {
      const q = new Panel(p.ox, p.oy + (dx / 185) * 330, 220, 80, 50);
      q.paper(); q.mark([0.5, 0], [0.5, 1]); q.mark([0, 0.5], [1, 0.5]);
      if (k === 1) {
        q.cand(1, [1, 1], [0, 0], "winner"); q.srcBand(1, [0.5, 0.5], [0.5, 1]); q.imgBand(1, [0.5, 0.5], [1, 0.5]);
        q.arrow(1, [0.5, 0.85], [0.85, 0.5], -0.3); q.dim(1, [0.8, 0.5], [0.8, 0], "0.50", [0.84, 0.22]);
      } else {
        q.cand(2, [1, 0], [0, 1], "removed"); q.srcBand(2, [0.5, 0.5], [0.5, 1]); q.imgBand(2, [0, 0.5], [0.5, 0.5]);
        q.arrow(2, [0.5, 0.85], [0.15, 0.5], 0.3); q.dim(2, [0.5, 0.5], [0.8, 0], "0.58", [0.7, 0.3]);
      }
      q.target(U, "", U);
      p.out.push(...q.out);
    };
    p.rows([
      ["Checks", ["(--v toward .u) measures only --v: where does", "the upper half of --v land, and how far is that", "from .u? The nearest wins."]],
      ["Result", ["{1} passes: --v lands 0.50 from .u", "{2x} eliminated: --v lands 0.58 from .u"]],
      ["Outcome", ["{1*} holds"]],
    ]);
    sub(1, 0); sub(2, 185);
    (p as any).h = 2 * 330 + 10;
  },
]);

// ---------- Figure H: axiom 7, three candidates, every stage (found by search, checked against the kernel) ----------
PROG = ["paper square", "mark (map .a onto .b) as --v", "mark (through .b .d) as --bd", "mark (through .a .c) as --ac", ".u = free on --ab from .a at 1/3", ".w = free on --da from .a at 1/3"];
const H1: Ln = [0.211324865405345, 0.788675134594655, 1 / 3], H2: Ln = [0.5, 0.5, 0.25], H3: Ln = [0.7886751345948824, 0.21132486540511763, 1 / 3];
const HA: P = [0, 0], HU: P = [1 / 3, 0], HW: P = [0, 1 / 3];
const foldH = "fold (align (.a onto --bd) (.u onto --v) (heading --ac)) (toward .w) as --s";
const [h1a, h1b] = clipL(H1), [h2a, h2b] = clipL(H2), [h3a, h3b] = clipL(H3);
function hBase(p: Panel, reads: boolean) {
  p.paper(); p.corners(SQ);
  p.add(`<circle cx="${p.X(HU)}" cy="${p.Y(HU)}" r="2.5" fill="${INK}"/><circle cx="${p.X(HW)}" cy="${p.Y(HW)}" r="2.5" fill="${INK}"/>`);
  p.label(".u", [0.35, -0.08], MUTED); p.label(".w", [-0.1, 0.35], MUTED);
  if (reads) { p.read([1, 0], [0, 1], "--bd", [0.72, 0.36]); p.read([0.5, 0], [0.5, 1], "--v", [0.53, 0.9]); }
  else { p.mark([1, 0], [0, 1]); p.mark([0.5, 0], [0.5, 1]); }
  p.mark([0, 0], [1, 1]);
}
const cH = (p: Panel, st: [string, string, string]) => {
  if (st[0]) p.cand(1, h1a, h1b, st[0] as any);
  if (st[1]) p.cand(2, h2b, h2a, st[1] as any);
  if (st[2]) p.cand(3, h3b, h3a, st[2] as any);
};
figure("H-full-axiom7.svg", "spec", foldH, {
  align: ["fold (align (", ".a onto --bd) (.u onto --v", ") (heading --ac)) (toward .w) as --s"],
  heading: ["fold (align (.a onto --bd) (.u onto --v) (", "heading --ac", ")) (toward .w) as --s"],
  toward: ["fold (align (.a onto --bd) (.u onto --v) (heading --ac)) (", "toward .w", ") as --s"],
}, [["0 candidates", true], ["1 heading", true], ["2 side", true], ["3 moved material", true], ["4 landing", true]],
["cand", "removed", "winner", "mark", "read", "construct", "hatch", "target", "image", "band", "dim"], [
  (p) => {
    p.title("Stage 0 · generate candidates"); prog(p, "align"); hBase(p, true);
    p.curve(parab(HA, [1, 1, 1]), CON); p.curve(parab(HU, [1, 0, 0.5]), CON);
    p.label("parabola: .a, --bd", [-0.3, -0.16], CON, "start", 11); p.label("parabola: .u, --v", [0.58, -0.16], CON, "start", 11);
    p.src(null, HA); p.src(null, HU);
    cH(p, ["in", "in", "in"]);
    p.rows([
      ["Constructs", ["Every crease that folds .a onto --bd touches", "the parabola with focus .a and directrix --bd;", "the same holds for .u and --v. A crease that", "does both touches both parabolas: their common", "tangents, the roots of a cubic, up to three."]],
      ["Yields", ["{1}{2}{3} the three common tangents"]],
    ]);
  },
  (p) => {
    p.title("Stage 1 · compare with the heading"); prog(p, "heading"); p.paper(); p.corners(SQ);
    p.mark([1, 0], [0, 1]); p.mark([0.5, 0], [0.5, 1]);
    p.read([0, 0], [1, 1], "heading --ac", [0.66, 0.74], "end");
    cH(p, ["in", "removed", "in"]);
    const X: P = [1 / 3, 1 / 3];
    arcAt(p, X, 45, -15, 0.2, 1, "60°", [0.58, 0.3]);
    arcAt(p, X, 45, 105, 0.2, 3, "60°", [0.22, 0.6]);
    const q: P = [0.25, 0.25]; const k = 7, ox = p.X(q), oy = p.Y(q);
    p.add(`<path d="M${ox + k * 0.707} ${oy - k * 0.707} l${k * 0.707} ${k * 0.707} l${-k * 0.707} ${k * 0.707}" fill="none" stroke="${col(2)}" stroke-width="1.2"/>`);
    p.label("90°", [0.08, 0.16], tcol(2), "start", 11.5);
    p.rows([
      ["Checks", ["Which candidate makes the smallest angle with", "--ac? Its position plays no part."]],
      ["Result", ["{1} passes: 60° to --ac", "{2x} eliminated: 90° to --ac", "{3} passes: 60° to --ac, a tie passes on"]],
    ]);
  },
  (p) => {
    p.title("Stage 2 · name the folding side"); prog(p, "toward"); hBase(p, false);
    p.hatch(1, [h1a, h1b, [1, 1], [0, 1]]); p.hatch(3, [h3a, [1, 0], [1, 1], h3b]);
    cH(p, ["in", "", "in"]);
    p.numeralAt(1, [0.07, 0.8]); p.numeralAt(3, [0.8, 0.07]);
    p.target(HW, "toward .w", [-0.03, 0.41], "end");
    p.rows([
      ["Checks", ["Which side of each line holds .w? It stays;", "the other side folds over."]],
      ["Result", ["{1} passes: .w lies on one side", "{3} passes: .w lies on one side"]],
    ]);
  },
  (p) => {
    p.title("Stage 3 · check what the fold moves"); prog(p, "align");
    const sub = (k: number, L: Ln, a: P, b: P, dx: number) => {
      const q = new Panel(p.ox, p.oy + (dx / 185) * 330, 220, 80, 50);
      q.paper(); q.read([1, 0], [0, 1], "--bd", [0.7, 0.4]); q.read([0.5, 0], [0.5, 1], "--v", [0.53, 0.92]);
      q.cand(k, b, a, "in");
      shortPiece(q, k, L, [0.7071, -0.7071], refl([L[0], L[1]], L[2], HA), HA);
      shortPiece(q, k, L, [0, 1], refl([L[0], L[1]], L[2], HU), HU, 0.07);
      p.out.push(...q.out);
    };
    p.rows([
      ["Checks", ["Does the fold carry out every alignment: an", "object on the folding side lands on the other's", "paper? .a and .u stay; --bd and --v have to", "bring paper to them."]],
      ["Result", ["{1} passes: --bd lands on .a, --v lands on .u", "{3} passes: --bd lands on .a, --v lands on .u"]],
    ]);
    sub(1, H1, h1a, h1b, 0); sub(3, H3, h3a, h3b, 185);
    (p as any).h = 2 * 330 + 10;
  },
  (p) => {
    p.title("Stage 4 · measure the landing"); prog(p, "toward");
    const sub = (k: number, dx: number) => {
      const q = new Panel(p.ox, p.oy + (dx / 185) * 330, 220, 80, 50);
      q.paper(); q.mark([1, 0], [0, 1]); q.mark([0.5, 0], [0.5, 1]);
      if (k === 1) {
        q.cand(1, h1a, h1b, "removed");
        q.srcBand(1, [0, 1], [0.788675, 0.211325]); q.imgBand(1, [-0.288675, -0.077350], [0.788675, 0.211325]);
        q.srcBand(1, [0.5, 0.288675], [0.5, 1]); q.imgBand(1, [0.144338, -0.327350], [0.5, 0.288675]);
        q.dim(1, [0.083333, 0.022329], HW, "0.32", [0.2, 0.5]);
      } else {
        q.cand(3, h3b, h3a, "winner");
        q.srcBand(3, [1, 0], [0.211325, 0.788675]); q.imgBand(3, [-0.077350, -0.288675], [0.211325, 0.788675]);
        q.srcBand(3, [0.5, 0], [0.5, 1]); q.imgBand(3, [-0.144338, 0.827350], [0.355662, -0.038675]);
        q.dim(3, [0.083333, 0.311004], HW, "0.09", [0.2, 0.5]);
      }
      q.target(HW, "", HW);
      p.out.push(...q.out);
    };
    p.rows([
      ["Checks", ["How far from .w do the objects of the", "alignments land? The nearest wins."]],
      ["Result", ["{1x} eliminated: lands 0.32 from .w", "{3} passes: lands 0.09 from .w"]],
      ["Outcome", ["{3*} holds"]],
    ]);
    sub(1, 0); sub(3, 185);
    (p as any).h = 2 * 330 + 10;
  },
]);

// A4 pages for print: break only between blocks; the legend goes where a page has room
if (MONOPRINT) {
  for (const f of ["H-full-axiom7.svg", "B-moving-a.svg"]) {
    const P0 = PARTS[f], W = P0.W, pw = W * 1.26, pageH = pw * 297 / 210 - 40;
    const cuts = CUTS[f], pages: [number, number][] = [];
    let start = 0;
    for (let k = 1; k < cuts.length; k++) if (cuts[k] - start > pageH) { pages.push([start, cuts[k - 1]]); start = cuts[k - 1]; }
    pages.push([start, cuts.at(-1)!]);
    let lp = pages.findIndex(([a, b]) => b - a + P0.legendH + 20 <= pageH);
    if (lp < 0) { pages.push([cuts.at(-1)!, cuts.at(-1)!]); lp = pages.length - 1; }
    pages.forEach(([a, b], n) => {
      const vb = `${-(pw - W) / 2} ${a - 20} ${pw} ${pageH + 40}`;
      const leg = n === lp ? `<g transform="translate(0 ${b + 20 - P0.legendTop})">${P0.legend}</g>` : "";
      writeFileSync(f.replace(".svg", `-print-${n + 1}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm" viewBox="${vb}"><rect x="${-W}" y="${a - 100}" width="${W * 3}" height="${pageH + 300}" fill="white"/><defs><clipPath id="page"><rect x="${-W}" y="${a}" width="${W * 3}" height="${b - a}"/></clipPath></defs><g clip-path="url(#page)">${P0.body}</g>${leg}<text x="${W + (pw - W) / 2 - 20}" y="${a - 20 + pageH + 30}" font-family="IBM Plex Sans, DejaVu Sans, sans-serif" font-size="11" fill="#64748b" text-anchor="end">${f.replace(".svg", "")} · page ${n + 1} of ${pages.length}</text></svg>`);
    });
  }
}
