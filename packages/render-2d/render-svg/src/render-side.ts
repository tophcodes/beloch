// Side view: the layer order of a flat state along one line, drawn as the
// section figures of the literature draw it. The paper the line crosses is one
// path; a piece that runs flat is one horizontal strip, a folded hinge a turn
// that wraps the turns inside it [langdemaine2009facet, Fig. 5; hull2020,
// Fig. 7.9]. Beside it the folded state shows where the cut is taken and, with
// an arrow at each end, which side it is seen from; the crease pattern carries
// the same pieces where they lie on the paper, numbered and colored alike, so
// each strip can be found on the sheet [hull2020, Fig. 7.9; demaine2007,
// Fig. 12.2].
//
// A piece is cut into parts where it crosses the faces of the crease pattern,
// the pattern with every crease the program makes, and the parts are numbered
// by their order on the paper along the cut. Two programs that leave the same
// paper under the cut number it alike, whatever order they score their
// creases in. A folded hinge on a crease the program names carries that
// name at its turn; other hinges carry none.
import type { FoldScene, Vec2 } from "@beloch/scene";
import { pickStep, SceneError } from "@beloch/scene";
import { createDoc, el, SvgDoc } from "./svgdoc";
import type { SvgNode } from "./svgdoc";
import { colorLineStyle, DEFAULT_THEME } from "./theme";
import type { Theme } from "./theme";
import { clipLineToPoly } from "./geometry";
import { resolveIsometry } from "./isometry";
import { sceneLayout } from "./layout";
import { renderScene } from "./render-scene";
import { renderFolded } from "./render-folded";
import type { RenderOptions } from "./render-cp";

export interface SideOptions extends RenderOptions {
  // The named line to cut along, without `--`. It is read on the table of the
  // state drawn, so a line bound with `=` after the last fold fits the final
  // state.
  along: string;
  step?: string | undefined; // frame index; undefined → final state
  // See the section from the other side of the cut than the default one.
  farSide?: boolean | undefined;
}

const EPS = 1e-9;
const SIDE_W = 572, PAD = 56, GAP = 34, SPLIT = 10;
// how far a strip stops short of a raw edge it meets in its own layer
const APART = 4;
// the width of one digit of a strip's number, and the room left between two
// numbers on one level
const DIGIT = 8, NUMBER_GAP = 4;
// the least pitch of the layers, to which they move closer where half
// circles would cross, and how many times its width the section may grow to
// beyond that
const MIN_PITCH = 22, MAX_WIDEN = 3;
// the width of one character of a crease's name beside a turn, and its height
const CHAR = 7, NAME_H = 14;

// The stretch of a piece that lies in one face of the crease pattern. `name`
// is its number in the order of the paper along the cut, counted from 1.
export interface Part { name: number; t0: number; t1: number; paper: [Vec2, Vec2] }
// A face the line crosses: where along the line, and where on the paper.
export interface Piece { face: number; t0: number; t1: number; paper: [Vec2, Vec2]; strip: number; parts: Part[] }
// Pieces that continue each other flat: one horizontal run in the drawing.
export interface Strip { pieces: Piece[]; t0: number; t1: number; level: number }
// A folded hinge on the line: two strips turn into each other at `t`.
// `crease` is the name the program gives the crease of the hinge, without
// `--`, or null where it gives none.
export interface Turn { t: number; strips: [number, number]; out: 1 | -1; crease: string | null }

// A named point of the state drawn that lies on the line, at `t` along it.
// Every layer the line crosses there holds one paper point at that place;
// `own` marks the one the name belongs to, the others only land on it.
export interface Spot { paper: Vec2; strip: number; own: boolean }
export interface SectionPoint { name: string; t: number; spots: Spot[] }

// `ends` are the table points where the line enters and leaves the paper,
// `view` the unit normal of the line that points from it toward the eye.
export interface Section { strips: Strip[]; turns: Turn[]; points: SectionPoint[]; ends: [Vec2, Vec2]; view: Vec2 }

export function sideSection(scene: FoldScene, along: string, stepLabel?: string, farSide = false): Section {
  const named = scene.namedLines.find((l) => l.name === along);
  if (!named) throw new SceneError(`the program names no line --${along}`);
  const step = pickStep(scene, stepLabel);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  const { frame, faceUp } = resolveIsometry(scene, { kind: "step", index: step.index });
  const [a, b, c] = named.coeffs;
  const len = Math.hypot(a, b);
  // The section is seen from outside the paper: from the side of the line on
  // which the outline of the state reaches less far, which is the outside of
  // the edge when the line runs along one. Where both sides reach equally far,
  // from the side that makes the section run left to right on the table,
  // bottom to top on a vertical line.
  const reach = (sign: number) => Math.max(0, ...frame.vertices.map(([x, y]) => sign * (a * x + b * y - c) / len));
  const tie = b > EPS || (b > -EPS && a < 0) ? -1 : 1;
  const near = reach(1) < reach(-1) - 1e-7 ? 1 : reach(-1) < reach(1) - 1e-7 ? -1 : tie;
  const eye = farSide ? -near : near;
  const view: Vec2 = [eye * a / len, eye * b / len];
  // seen along -view with the table's normal up, the section runs to the
  // eye's right: `view` turned a quarter anticlockwise
  const dir: Vec2 = [-view[1], view[0]];
  const at = ([x, y]: Vec2) => x * dir[0] + y * dir[1];
  // a table point of a face, back on the paper: the linear part of the face's
  // isometry is orthogonal, so its inverse is its transpose
  const toPaper = (face: number, [x, y]: Vec2): Vec2 => {
    const m = frame.facesMatrix?.[face];
    if (!m) return [x, y];
    const [m00, m01, m10, m11, tx, ty] = m;
    const dx = x - tx, dy = y - ty;
    return [m00 * dx + m10 * dy, m01 * dx + m11 * dy];
  };

  // A face the line runs along an edge of, without entering it, is drawn when
  // it lies on the side away from the default eye, where the paper reaches
  // farther: the section is taken just inside such an edge, and `farSide`
  // mirrors that same section. Otherwise the faces on both sides of a crease
  // the line runs along would each give the same stretch of paper, and the
  // section would draw that layer twice.
  const side = ([x, y]: Vec2) => near * (a * x + b * y - c) / len;
  const pieces: Piece[] = [];
  frame.facesVertices.forEach((f, face) => {
    const poly = f.map((i) => frame.vertices[i]!);
    const seg = clipLineToPoly(a, b, c, poly);
    if (!seg) return;
    if (!poly.some((v) => side(v) < -1e-7)) return;
    const [p, q] = at(seg[0]) <= at(seg[1]) ? seg : [seg[1], seg[0]];
    if (at(q) - at(p) <= EPS) return;
    pieces.push({ face, t0: at(p), t1: at(q), paper: [toPaper(face, p), toPaper(face, q)], strip: -1, parts: [] });
  });
  if (pieces.length === 0) throw new SceneError(`--${along} crosses no face of this state`);

  // each piece cut where the faces of the crease pattern meet on the paper; a
  // stretch that runs along a crease belongs to the first face that holds it
  const cpFaces = scene.cp.facesVertices.map((f) => f.map((i) => scene.cp.vertices[i]!));
  for (const piece of pieces) {
    const [[px, py], [qx, qy]] = piece.paper;
    const [dx, dy] = [qx - px, qy - py];
    const d2 = dx * dx + dy * dy;
    const u = ([x, y]: Vec2) => ((x - px) * dx + (y - py) * dy) / d2;
    for (const poly of cpFaces) {
      const chord = clipLineToPoly(-dy, dx, -dy * px + dx * py, poly);
      if (!chord) continue;
      const [u0, u1] = [Math.max(0, Math.min(u(chord[0]), u(chord[1]))), Math.min(1, Math.max(u(chord[0]), u(chord[1])))];
      if (u1 - u0 < 1e-7 || piece.parts.some((r) => {
        const [r0, r1] = [(r.t0 - piece.t0) / (piece.t1 - piece.t0), (r.t1 - piece.t0) / (piece.t1 - piece.t0)];
        return Math.min(r1, u1) - Math.max(r0, u0) > 1e-7;
      })) continue;
      const on = (s: number): Vec2 => [px + s * dx, py + s * dy];
      const t = (s: number) => piece.t0 + s * (piece.t1 - piece.t0);
      piece.parts.push({ name: 0, t0: t(u0), t1: t(u1), paper: [on(u0), on(u1)] });
    }
    piece.parts.sort((r, s) => r.t0 - s.t0);
  }

  // two pieces are hinged where their faces share an edge the line crosses at
  // an end of both; flat when they run on to opposite sides, folded when both
  // run away to one side
  const edgeKey = (i: number, j: number) => (i < j ? `${i},${j}` : `${j},${i}`);
  const edgesOf = (face: number) => {
    const f = frame.facesVertices[face]!;
    return new Map(f.map((v, k) => [edgeKey(v, f[(k + 1) % f.length]!), [v, f[(k + 1) % f.length]!] as const]));
  };
  const crossing = ([i, j]: readonly [number, number]): number | undefined => {
    const [p, q] = [frame.vertices[i]!, frame.vertices[j]!];
    const sp = a * p[0] + b * p[1] - c, sq = a * q[0] + b * q[1] - c;
    if (Math.abs(sp - sq) < EPS) return undefined; // parallel to the line, or on it
    const s = sp / (sp - sq);
    if (s < -EPS || s > 1 + EPS) return undefined;
    return at([p[0] + s * (q[0] - p[0]), p[1] + s * (q[1] - p[1])]);
  };
  const endsAt = (p: Piece, t: number) => Math.abs(p.t0 - t) < EPS || Math.abs(p.t1 - t) < EPS;
  const away = (p: Piece, t: number): 1 | -1 => (Math.abs(p.t0 - t) < EPS ? 1 : -1);
  const edges = pieces.map((p) => edgesOf(p.face));
  const hinges: { p: number; q: number; t: number; folded: boolean; edge: string }[] = [];
  pieces.forEach((p, i) => pieces.forEach((q, j) => {
    if (j <= i) return;
    const hit = [...edges[i]!].filter(([k]) => edges[j]!.has(k))
      .map(([k, e]) => ({ k, t: crossing(e) }))
      .find(({ t: s }) => s !== undefined && endsAt(p, s) && endsAt(q, s));
    if (hit) hinges.push({ p: i, q: j, t: hit.t!, folded: away(p, hit.t!) === away(q, hit.t!), edge: hit.k });
  }));
  // the name of the crease each edge of the frame lies on, where it has one
  const creaseOf = new Map(frame.edgesVertices.map(([i, j], e) => [edgeKey(i, j), frame.edgesProvenance[e]?.name ?? null]));

  // strips: the pieces joined by flat hinges
  const parent = pieces.map((_, i) => i);
  const find = (i: number): number => (parent[i] === i ? i : (parent[i] = find(parent[i]!)));
  for (const h of hinges) if (!h.folded) parent[find(h.p)] = find(h.q);
  const roots = [...new Set(pieces.map((_, i) => find(i)))];
  const strips: Strip[] = roots.map((r) => {
    const ps = pieces.filter((_, i) => find(i) === r);
    return { pieces: ps, t0: Math.min(...ps.map((p) => p.t0)), t1: Math.max(...ps.map((p) => p.t1)), level: 0, number: 0 };
  });
  pieces.forEach((p, i) => { p.strip = roots.indexOf(find(i)); });
  const turns: Turn[] = hinges.filter((h) => h.folded).map((h) => {
    const p = pieces[h.p]!;
    return {
      t: h.t, strips: [p.strip, pieces[h.q]!.strip], out: away(p, h.t) === 1 ? -1 : 1,
      crease: creaseOf.get(h.edge) ?? null,
    };
  });

  // The parts numbered in the order of the paper along the cut. Parts that
  // share a point on the paper continue each other there, across a hinge or a
  // crease of the pattern, so the cut traces paths on the paper. Each path is
  // walked from one end, the one that lies first along the cut on the table,
  // and where two ends lie at one place there, the one with the smaller paper
  // x, then y. The paths are numbered one after another in the order of their
  // starting ends; a path that closes on itself starts at its first point by
  // the same order. Every part gets a number of its own, also where one piece
  // spans several faces of the crease pattern, since the drawing labels parts.
  // The numbers depend on the paper under the cut and its folded state alone:
  // two programs that reach them by creases in another order number alike.
  const parts = pieces.flatMap((p) => p.parts);
  const spot = ([x, y]: Vec2) => `${Math.round(x * 1e6)},${Math.round(y * 1e6)}`;
  const meeting = new Map<string, Part[]>();
  for (const r of parts) for (const e of r.paper) meeting.set(spot(e), [...meeting.get(spot(e)) ?? [], r]);
  // an end of a part: the part and which of its two ends
  type End = { r: Part; k: 0 | 1 };
  // where an end lies: along the cut on the table, then on the paper
  const place = (r: Part, k: 0 | 1) => [k === 0 ? r.t0 : r.t1, r.paper[k][0], r.paper[k][1]];
  const order = (p: number[], q: number[]) => {
    const i = p.findIndex((z, j) => Math.abs(z - q[j]!) > 1e-7);
    return i < 0 ? 0 : p[i]! - q[i]!;
  };
  // two parts from one point: the one whose far end comes first
  const first = (u: End, v: End) =>
    order(place(u.r, u.k), place(v.r, v.k)) || order(place(u.r, (1 - u.k) as 0 | 1), place(v.r, (1 - v.k) as 0 | 1));
  const numbered = new Set<Part>();
  const open = (e: Vec2) => meeting.get(spot(e))!.filter((r) => !numbered.has(r));
  while (numbered.size < parts.length) {
    const ends: End[] = parts.filter((r) => !numbered.has(r)).flatMap((r) => [{ r, k: 0 as const }, { r, k: 1 as const }]);
    const loose = ends.filter((u) => open(u.r.paper[u.k]).length === 1);
    let next: End | undefined = (loose.length > 0 ? loose : ends).sort(first)[0];
    while (next) {
      const { r, k }: End = next;
      r.name = numbered.size + 1;
      numbered.add(r);
      const far: Vec2 = r.paper[1 - k]!;
      next = open(far).map((s): End => ({ r: s, k: spot(s.paper[0]) === spot(far) ? 0 : 1 })).sort(first)[0];
    }
  }

  // f above g, globally: faceOrders' sign is keyed to g's normal
  const above = new Set<string>();
  for (const [f, g, s] of frame.faceOrders) {
    if (s === 0) continue;
    above.add((s > 0) === faceUp[g] ? `${f},${g}` : `${g},${f}`);
  }
  const overlaps = (p: Piece, q: Piece) => Math.min(p.t1, q.t1) - Math.max(p.t0, q.t0) > EPS;
  const over = (s: number) => strips.map((_, r) => r).filter((r) => r !== s &&
    strips[s]!.pieces.some((p) => strips[r]!.pieces.some((q) => overlaps(p, q) && above.has(`${q.face},${p.face}`))));
  // each strip lies one level below the lowest strip over it, so strips that
  // never overlap share a level
  const depth = new Map<number, number>();
  const visiting = new Set<number>();
  const levelOf = (s: number): number => {
    const known = depth.get(s);
    if (known !== undefined) return known;
    if (visiting.has(s)) throw new SceneError("the layer order along this line has a cycle");
    visiting.add(s);
    const l = Math.max(-1, ...over(s).map(levelOf)) + 1;
    visiting.delete(s);
    depth.set(s, l);
    return l;
  };
  strips.forEach((s, i) => { s.level = levelOf(i); });
  const points = scene.namedPoints
    .filter((p) => p.step === step.index && Math.abs(a * p.table[0] + b * p.table[1] - c) / len < 1e-7)
    .map((p) => {
      const t = at(p.table);
      const spots: Spot[] = [];
      for (const q of pieces) {
        if (t < q.t0 - EPS || t > q.t1 + EPS) continue;
        const k = (t - q.t0) / (q.t1 - q.t0);
        const [[ax, ay], [bx, by]] = q.paper;
        const spot: Vec2 = [ax + k * (bx - ax), ay + k * (by - ay)];
        const near = (u: Vec2) => Math.hypot(u[0] - spot[0], u[1] - spot[1]) < 1e-7;
        // two pieces that meet at a hinge share the paper point there
        if (!spots.some((s) => near(s.paper))) spots.push({ paper: spot, strip: q.strip, own: near(p.paper) });
      }
      return { name: p.name, t, spots };
    });
  const foot: Vec2 = [(a * c) / (len * len), (b * c) / (len * len)];
  const on = (t: number): Vec2 => [foot[0] + t * dir[0], foot[1] + t * dir[1]];
  const ends: [Vec2, Vec2] = [on(Math.min(...pieces.map((p) => p.t0))), on(Math.max(...pieces.map((p) => p.t1)))];
  return { strips, turns, points, ends, view };
}

export function renderSide(scene: FoldScene, opts: SideOptions): SvgDoc {
  const { strips, turns, points, ends, view } = sideSection(scene, opts.along, opts.step, opts.farSide);
  const theme: Theme = { ...DEFAULT_THEME, ...opts.theme };
  const color = (name: number) => theme.highlightPalette[(name - 1) % theme.highlightPalette.length]!.stroke;
  const halo = { stroke: theme.background, "stroke-width": 4, "paint-order": "stroke" };
  // A turn is a half circle on the place of its hinge along the line, from
  // the end of one strip to the end of the other, bulging out past them; its
  // radius is half the height between the two. Turns at one place that open to
  // one side nest inside each other.
  const span = (u: Turn) => {
    const [l0, l1] = [strips[u.strips[0]]!.level, strips[u.strips[1]]!.level];
    return [Math.min(l0, l1), Math.max(l0, l1)] as const;
  };
  // the crease names of the turns at one place on one side, one per crease,
  // and the room they take
  const namesAt = (us: Turn[]) => [...new Set(us.map((v) => v.crease).filter((c): c is string => c !== null))];
  const nameW = (c: string) => (c.length + 2) * CHAR;
  const named = (us: Turn[]) => Math.max(0, ...namesAt(us).map((c) => nameW(c) + 4));
  type Group = { t: number; o: 1 | -1; us: Turn[] };
  const groups: Group[] = [];
  for (const u of turns) {
    const g = groups.find((h) => Math.abs(h.t - u.t) < EPS && h.o === u.out);
    if (g) g.us.push(u);
    else groups.push({ t: u.t, o: u.out, us: [u] });
  }
  const groupAt = (t: number, o: 1 | -1) => groups.find((g) => Math.abs(g.t - t) < EPS && g.o === o)!;
  const tMin = Math.min(...strips.map((s) => s.t0)), tMax = Math.max(...strips.map((s) => s.t1));

  // The layout for one pitch of the layers. Along the line the section keeps
  // the proportions of the paper: one scale for the whole line, and the
  // section grows wider for the turns that bulge out past its ends, so places that lie above one
  // another in the folded state lie above one another in the section. Where
  // turns open to both sides of one place, the half circles of one side would
  // cover the strips that end there from the other side at every pitch and
  // width; there alone the drawing opens a gap wide enough for both, and the
  // strips that run on through the place stretch across it.
  const twoSided = [...new Set(groups.filter((g) => g.o === 1 && groupAt(g.t, -1)).map((g) => g.t))].sort((m, n) => m - n);
  const layout = (pitch: number, widen = 1) => {
    const radius = (u: Turn) => (span(u)[1] - span(u)[0]) * pitch / 2;
    const reach = (g: Group | undefined) => g ? Math.max(...g.us.map(radius)) + named(g.us) : 0;
    const gaps = twoSided.map((t) => [t, reach(groupAt(t, 1)) + reach(groupAt(t, -1)) + SPLIT] as const);
    const open = (g: Group) => !twoSided.some((t) => Math.abs(t - g.t) < EPS);
    // the line itself takes the default width less the margins, stretched by
    // `widen`; the margins, the gaps and the turns past the ends come on top
    const scale = widen * (SIDE_W - 2 * PAD) / (tMax - tMin || 1);
    const left = PAD + Math.max(0, ...groups.filter((g) => g.o === -1 && open(g)).map((g) => reach(g) - (g.t - tMin) * scale));
    const right = PAD + Math.max(0, ...groups.filter((g) => g.o === 1 && open(g)).map((g) => reach(g) - (tMax - g.t) * scale));
    const width = left + right + (tMax - tMin) * scale + gaps.reduce((w, [, d]) => w + d, 0);
    // x of a place along the line; at a gap, on the side a strip's material
    // lies on
    const X = (t: number, side: 1 | -1 = 1) => left + (t - tMin) * scale + gaps.reduce((w, [g, d]) =>
      w + (g < t - EPS || (Math.abs(g - t) < EPS && side === 1) ? d : 0), 0);
    // the place the turns of a group stand on: the end of the strips they join
    const foot = (g: Group) => X(g.t, (-g.o) as 1 | -1);
    return { pitch, width, radius, X, foot, y: (level: number) => PAD + level * pitch };
  };
  // Whether a turn of this layout crosses a strip or the turn of another
  // place: a strip at a level strictly between the ends of a turn must stay
  // out of its half circle, and two half circles must not cut each other.
  const crosses = ({ radius, X, foot, y }: ReturnType<typeof layout>) => {
    const circles = turns.map((u) => {
      const [lo, hi] = span(u);
      return { u, o: u.out, cx: foot(groupAt(u.t, u.out)), cy: (y(lo) + y(hi)) / 2, r: radius(u), lo, hi };
    });
    for (const c of circles) {
      for (const s of strips) {
        if (s.level <= c.lo || s.level >= c.hi) continue;
        const d = y(s.level) - c.cy;
        const ext = Math.sqrt(Math.max(0, c.r * c.r - d * d));
        const [a0, a1] = c.o === 1 ? [c.cx, c.cx + ext] : [c.cx - ext, c.cx];
        if (Math.min(X(s.t1, -1), a1) - Math.max(X(s.t0, 1), a0) > 1) return true;
      }
      for (const e of circles) {
        if (e === c || Math.abs(e.u.t - c.u.t) < EPS) continue;
        const dd = Math.hypot(e.cx - c.cx, e.cy - c.cy);
        if (dd >= c.r + e.r || dd <= Math.abs(c.r - e.r) || dd < 1e-9) continue;
        // the two points where the circles meet, each on both half circles?
        const k = (c.r * c.r - e.r * e.r + dd * dd) / (2 * dd);
        const h = Math.sqrt(Math.max(0, c.r * c.r - k * k));
        const [ux, uy] = [(e.cx - c.cx) / dd, (e.cy - c.cy) / dd];
        for (const sgn of [1, -1]) {
          const [px, py] = [c.cx + k * ux - sgn * h * uy, c.cy + k * uy + sgn * h * ux];
          if (c.o * (px - c.cx) > 1 && e.o * (px - e.cx) > 1) return true;
        }
      }
    }
    return false;
  };
  // Where the half circles at the default pitch would cross, the layers move
  // closer together, which makes every half circle smaller, down to a pitch of
  // MIN_PITCH, the least that still holds a strip's number between two layers.
  // Where they cross even there, the whole line grows longer at one scale,
  // by a tenth at a time up to MAX_WIDEN times its length, which moves places
  // apart and leaves the half circles as they are. Past that the half circles
  // are drawn crossing.
  let fit = layout(GAP);
  for (let p = GAP - 2; p >= MIN_PITCH && crosses(fit); p -= 2) fit = layout(p);
  for (let w = 1.1; w <= MAX_WIDEN + 1e-9 && crosses(fit); w += 0.1) fit = layout(MIN_PITCH, w);
  const { radius, X, foot, y, pitch, width: sideW } = fit;
  const levels = Math.max(...strips.map((s) => s.level)) + 1;
  const sideH = 2 * PAD + (levels - 1) * pitch + 28;

  const nodes: SvgNode[] = [];
  // two strips of one level that meet share no hinge there, only raw edges:
  // each stops short of the place, so a gap stands between them
  const meets = (s: Strip, t: number) => strips.some((o) => o !== s && o.level === s.level &&
    (Math.abs(o.t0 - t) < EPS || Math.abs(o.t1 - t) < EPS));
  const numbers: { name: number; level: number; x: number; end: number }[] = [];
  for (const s of strips) {
    const parts = s.pieces.flatMap((p) => p.parts).sort((p, q) => p.t0 - q.t0);
    for (const r of parts) {
      // a part that ends inside the strip runs on to where the next one starts,
      // across a gap the strip stretches through
      const [first, last] = [Math.abs(r.t0 - s.t0) < EPS, Math.abs(r.t1 - s.t1) < EPS];
      const x0 = X(r.t0, 1) + (first && meets(s, s.t0) ? APART : 0);
      const x1 = X(r.t1, last ? -1 : 1) - (last && meets(s, s.t1) ? APART : 0);
      nodes.push(el("line", {
        "data-kind": "layer", "data-name": r.name, "data-level": s.level,
        x1: x0, y1: y(s.level), x2: x1, y2: y(s.level),
        stroke: color(r.name), "stroke-width": 3, "stroke-linecap": "round",
      }));
      // at the start of the part, clear of the points and names over its middle
      numbers.push({ name: r.name, level: s.level, x: x0 + 6, end: x1 });
      if (Math.abs(r.t0 - s.t0) > EPS) {
        nodes.push(el("line", {
          "data-kind": "seam", x1: x0, y1: y(s.level) - 5, x2: x0, y2: y(s.level) + 5,
          stroke: theme.ink, "stroke-width": 1.2,
        }));
      }
    }
  }
  // The numbers of one level stand in the order of their parts, each where its
  // part starts and short of its end, unless the number before it on the
  // level would overlap it: then it moves right until it stands clear of that
  // number. Numbers move; strips do not.
  numbers.sort((m, n) => m.level - n.level || m.x - n.x);
  numbers.forEach((m, i) => {
    m.x = Math.max(m.x - 6, Math.min(m.x, m.end - String(m.name).length * DIGIT));
    const before = numbers[i - 1];
    if (before && before.level === m.level) {
      m.x = Math.max(m.x, before.x + String(before.name).length * DIGIT + NUMBER_GAP);
    }
    nodes.push(el("text", {
      "data-kind": "layer-name", "data-name": m.name, x: m.x, y: y(m.level) - 7, "text-anchor": "start",
      "font-size": 13, "font-weight": 600, fill: color(m.name),
    }, [], String(m.name)));
  });
  for (const g of groups) {
    const xf = foot(g), sweep = g.o === 1 ? 1 : 0;
    for (const u of g.us) {
      const [lo, hi] = span(u);
      const [ya, yb, r] = [y(lo), y(hi), radius(u)];
      nodes.push(el("path", {
        "data-kind": "turn", "data-out": g.o, "data-x": xf, "data-r": r, "data-y0": ya, "data-y1": yb,
        d: `M ${xf} ${ya} A ${r} ${r} 0 0 ${sweep} ${xf} ${yb}`,
        fill: "none", stroke: theme.ink, "stroke-width": 2,
      }));
    }
  }
  // A crease's name stands once for each place and side, outside the
  // outermost turn there, level with the middle of the outermost turn on that
  // crease. Where it would overlap a name placed before it, it moves down by
  // the height of a name until it stands clear of all of them.
  const creaseNames: { name: string; x: number; y: number; w: number }[] = [];
  for (const g of groups) {
    const out = Math.max(...g.us.map(radius));
    for (const c of namesAt(g.us)) {
      const top = g.us.filter((v) => v.crease === c).sort((u, v) => radius(v) - radius(u))[0]!;
      const [lo, hi] = span(top);
      const w = nameW(c);
      creaseNames.push({ name: `--${c}`, x: g.o === 1 ? foot(g) + out + 4 : foot(g) - out - 4 - w, y: (y(lo) + y(hi)) / 2 + 4, w });
    }
  }
  const placed: { x: number; y: number; w: number }[] = [];
  const clash = (m: { x: number; y: number; w: number }) => placed.some((o) =>
    Math.min(o.x + o.w, m.x + m.w) - Math.max(o.x, m.x) > 0 && Math.abs(o.y - m.y) < NAME_H);
  for (const m of creaseNames.sort((a, b) => a.y - b.y || a.x - b.x)) {
    while (clash(m)) m.y += NAME_H;
    placed.push(m);
    nodes.push(el("text", {
      "data-kind": "crease-name", "data-name": m.name, x: m.x, y: m.y, "text-anchor": "start",
      "font-size": 12, fill: theme.ink, ...halo,
    }, [], m.name));
  }
  // a named point on the line: where it stands across the whole stack, as Ida
  // marks the place of a fold line [ida2007modeling, Fig. 7]
  for (const p of points) {
    const xp = (X(p.t, -1) + X(p.t, 1)) / 2;
    nodes.push(el("line", {
      "data-kind": "point", "data-name": p.name,
      x1: xp, y1: y(0) - 18, x2: xp, y2: y(levels - 1) + 10,
      stroke: theme.ink, "stroke-width": 1.2, "stroke-dasharray": "4 3",
    }));
    nodes.push(el("text", {
      x: xp, y: y(0) - 24, "text-anchor": "middle", "font-size": 14, fill: theme.ink,
    }, [], `.${p.name}`));
    // the layer the point belongs to, the others only lie under or over it;
    // a point on a folded hinge sits on the crown of its turn
    for (const s of p.spots.filter((s) => s.own)) {
      const u = turns.find((v) => Math.abs(v.t - p.t) < EPS && v.strips.includes(s.strip));
      const [cx, cy] = u
        ? [foot(groupAt(u.t, u.out)) + u.out * radius(u),
          (y(strips[u.strips[0]]!.level) + y(strips[u.strips[1]]!.level)) / 2]
        : [xp, y(strips[s.strip]!.level)];
      nodes.push(el("circle", { "data-kind": "point-own", "data-name": p.name, cx, cy, r: 4.5, fill: theme.ink }));
    }
  }
  nodes.push(el("text", {
    x: sideW / 2, y: sideH - 12, "text-anchor": "middle", "font-size": 15, fill: theme.ink,
  }, [], opts.title ?? `along --${opts.along}, top layer first`));

  // the crease pattern with the pieces of the paper the line crosses
  const lay = sceneLayout(scene);
  // with the creases of the state drawn alone: a crease a later write scores
  // has no line yet, though the pieces it will split already carry the
  // numbers of its parts
  const stepIndex = pickStep(scene, opts.step)!.index;
  const write = stepIndex === 0 ? null : scene.writes[stepIndex - 1] ?? null;
  const cp = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: {
      upToStatement: write ? write.index : -1,
      creases: true, marks: true, points: true, lines: true, faces: "outline",
    },
    markOverlay: { marks: write ? write.keptMarks : [] },
    labels: opts.labels,
    theme: { lineStyle: colorLineStyle, ...opts.theme },
  }).node();
  const marks: SvgNode[] = [];
  for (const r of strips.flatMap((s) => s.pieces.flatMap((p) => p.parts))) {
    const [[ax, ay], [bx, by]] = r.paper;
    marks.push(el("line", {
      "data-kind": "piece", "data-name": r.name,
      x1: lay.tx(ax), y1: lay.ty(ay), x2: lay.tx(bx), y2: lay.ty(by),
      stroke: color(r.name), "stroke-width": 5, "stroke-linecap": "round",
    }));
    marks.push(el("text", {
      "data-kind": "piece-name", x: (lay.tx(ax) + lay.tx(bx)) / 2, y: (lay.ty(ay) + lay.ty(by)) / 2 - 8,
      "text-anchor": "middle", "font-size": 15, "font-weight": 600, fill: color(r.name), ...halo,
    }, [], String(r.name)));
  }
  // the point where it is on the paper, named; the paper points of the other
  // layers that land on it after folding, small and unnamed
  for (const p of points) {
    for (const { paper: [sx, sy], own } of p.spots) {
      marks.push(el("circle", {
        "data-kind": own ? "point-own" : "point", "data-name": p.name, cx: lay.tx(sx), cy: lay.ty(sy),
        r: own ? 4.5 : 3, fill: own ? theme.ink : theme.background, stroke: own ? theme.ink : theme.flat,
        "stroke-width": own ? 2 : 1.5,
      }));
      if (!own) continue;
      marks.push(el("text", {
        x: lay.tx(sx) + 8, y: lay.ty(sy) + 16, "font-size": 14, fill: theme.ink, ...halo,
      }, [], `.${p.name}`));
    }
  }

  // the folded state the section is taken from, with the cut across it. Solid,
  // since a dashed line on a folded state reads as a valley fold; it runs a
  // little past the paper on both ends, as a section line does, and at each
  // end an arrow on the side the section is seen from points the way the eye
  // looks
  const folded = renderFolded(scene, {
    step: opts.step, labels: opts.labels, theme: opts.theme, highlight: opts.highlight, layout: lay,
  }).node();
  const [[e0x, e0y], [e1x, e1y]] = ends;
  const over = 0.06 * lay.span / Math.hypot(e1x - e0x, e1y - e0y);
  const tips: Vec2[] = [
    [e0x - over * (e1x - e0x), e0y - over * (e1y - e0y)],
    [e1x + over * (e1x - e0x), e1y + over * (e1y - e0y)],
  ];
  const cut: SvgNode[] = [el("line", {
    "data-kind": "cut",
    x1: lay.tx(tips[0]![0]), y1: lay.ty(tips[0]![1]), x2: lay.tx(tips[1]![0]), y2: lay.ty(tips[1]![1]),
    stroke: theme.ink, "stroke-width": 2.5, "stroke-linecap": "round",
  })];
  for (const [ex, ey] of tips) {
    const [tipX, tipY] = [lay.tx(ex + 0.02 * lay.span * view[0]), lay.ty(ey + 0.02 * lay.span * view[1])];
    const [tailX, tailY] = [lay.tx(ex + 0.11 * lay.span * view[0]), lay.ty(ey + 0.11 * lay.span * view[1])];
    const l = Math.hypot(tipX - tailX, tipY - tailY);
    const [ux, uy] = [(tipX - tailX) / l, (tipY - tailY) / l];
    const [bx, by] = [tipX - 10 * ux, tipY - 10 * uy];
    cut.push(el("g", { "data-kind": "view" }, [
      el("line", { x1: tailX, y1: tailY, x2: bx, y2: by, stroke: theme.ink, "stroke-width": 2 }),
      el("path", {
        d: `M ${tipX} ${tipY} L ${bx - 5 * uy} ${by + 5 * ux} L ${bx + 5 * uy} ${by - 5 * ux} Z`, fill: theme.ink,
      }),
    ]));
  }

  const H = Math.max(lay.H, sideH);
  const doc = createDoc(2 * lay.W + sideW, H);
  doc.root.children.push(
    el("rect", { width: 2 * lay.W + sideW, height: H, fill: theme.background }),
    el("svg", { ...folded.attrs, x: 0, y: 0 }, [...folded.children, ...cut]),
    el("svg", { ...cp.attrs, x: lay.W, y: 0 }, [...cp.children, ...marks]),
    el("g", { transform: `translate(${2 * lay.W} ${(H - sideH) / 2})` }, nodes),
  );
  return doc;
}
