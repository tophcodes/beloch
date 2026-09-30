// Side view: the layer order of a flat state along one line, drawn as the
// section figures of the literature draw it. The paper the line crosses is one
// path; a piece that runs flat is one horizontal strip, a folded hinge a turn
// that wraps the turns inside it [langdemaine2009facet, Fig. 5; hull2020,
// Fig. 7.9]. Beside it the folded state shows where the cut is taken and, with
// an arrow at each end, which side it is seen from; the crease pattern carries
// the same pieces where they lie on the paper, named and coloured alike, so
// each strip can be found on the sheet [hull2020, Fig. 7.9; demaine2007,
// Fig. 12.2].
//
// A piece is named after the face of the crease pattern it lies in, the
// pattern with every crease the program makes, and a hinge after the two
// pieces it joins. Every state of one program reads the same pattern, so a
// piece keeps its name in the drawing of each state it appears in; a piece
// that a later crease splits shows the names of the parts it splits into.
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
// the room a hinge's name takes beside the crown of its turn
const HINGE_LABEL = 30;
// how far a strip stops short of a raw edge it meets in its own layer
const APART = 4;

// The stretch of a piece that lies in one face of the crease pattern, named by
// that face: its index in the crease pattern, counted from 1.
export interface Part { name: number; t0: number; t1: number; paper: [Vec2, Vec2] }
// A face the line crosses: where along the line, and where on the paper.
export interface Piece { face: number; t0: number; t1: number; paper: [Vec2, Vec2]; strip: number; parts: Part[] }
// Pieces that continue each other flat: one horizontal run in the drawing.
export interface Strip { pieces: Piece[]; t0: number; t1: number; level: number }
// A folded hinge on the line: two strips turn into each other at `t`. It is
// named by the parts it joins, the smaller name first; `paper` is where it
// crosses the line on the paper.
export interface Turn { t: number; strips: [number, number]; out: 1 | -1; name: string; paper: Vec2 }

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

  const pieces: Piece[] = [];
  frame.facesVertices.forEach((f, face) => {
    const seg = clipLineToPoly(a, b, c, f.map((i) => frame.vertices[i]!));
    if (!seg) return;
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
    cpFaces.forEach((poly, k) => {
      const chord = clipLineToPoly(-dy, dx, -dy * px + dx * py, poly);
      if (!chord) return;
      const [u0, u1] = [Math.max(0, Math.min(u(chord[0]), u(chord[1]))), Math.min(1, Math.max(u(chord[0]), u(chord[1])))];
      if (u1 - u0 < 1e-7 || piece.parts.some((r) => {
        const [r0, r1] = [(r.t0 - piece.t0) / (piece.t1 - piece.t0), (r.t1 - piece.t0) / (piece.t1 - piece.t0)];
        return Math.min(r1, u1) - Math.max(r0, u0) > 1e-7;
      })) return;
      const on = (s: number): Vec2 => [px + s * dx, py + s * dy];
      const t = (s: number) => piece.t0 + s * (piece.t1 - piece.t0);
      piece.parts.push({ name: k + 1, t0: t(u0), t1: t(u1), paper: [on(u0), on(u1)] });
    });
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
  const hinges: { p: number; q: number; t: number; folded: boolean }[] = [];
  pieces.forEach((p, i) => pieces.forEach((q, j) => {
    if (j <= i) return;
    const t = [...edges[i]!].filter(([k]) => edges[j]!.has(k))
      .map(([, e]) => crossing(e))
      .find((s) => s !== undefined && endsAt(p, s) && endsAt(q, s));
    if (t !== undefined) hinges.push({ p: i, q: j, t, folded: away(p, t) === away(q, t) });
  }));

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
  // the part of a piece that reaches the hinge at `t`
  const partAt = (p: Piece, t: number) =>
    p.parts.find((r) => Math.abs(r.t0 - t) < EPS || Math.abs(r.t1 - t) < EPS) ?? p.parts[0];
  const turns: Turn[] = hinges.filter((h) => h.folded).map((h) => {
    const [p, q] = [pieces[h.p]!, pieces[h.q]!];
    const [r, s] = [partAt(p, h.t), partAt(q, h.t)];
    const names = [r?.name, s?.name].map((n) => n ?? "?").sort((m, n) => Number(m) - Number(n));
    const end = r ? (Math.abs(r.t0 - h.t) < EPS ? r.paper[0] : r.paper[1]) : p.paper[0];
    return {
      t: h.t, strips: [p.strip, q.strip], out: away(p, h.t) === 1 ? -1 : 1,
      name: names.join("|"), paper: end,
    };
  });

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
  const colour = (name: number) => theme.highlightPalette[(name - 1) % theme.highlightPalette.length]!.stroke;
  const halo = { stroke: theme.background, "stroke-width": 4, "paint-order": "stroke" };
  const y = (level: number) => PAD + level * GAP;
  const radius = (u: Turn) => Math.abs(strips[u.strips[0]]!.level - strips[u.strips[1]]!.level) * GAP / 2;

  // where turns meet from both sides at one place, the drawing opens a gap
  // there wide enough for both and their names, and a strip running through it
  // stretches
  const tMin = Math.min(...strips.map((s) => s.t0)), tMax = Math.max(...strips.map((s) => s.t1));
  const widen = new Map<number, number>();
  for (const u of turns) {
    const both = turns.filter((v) => Math.abs(v.t - u.t) < EPS);
    if (both.some((v) => v.out === 1) && both.some((v) => v.out === -1)) {
      const reach = (o: 1 | -1) => Math.max(0, ...both.filter((v) => v.out === o).map(radius));
      widen.set(u.t, reach(1) + reach(-1) + SPLIT + 2 * HINGE_LABEL);
    }
  }
  const gaps = [...widen.entries()].sort(([s], [t]) => s - t);
  const outer = (o: 1 | -1) => Math.max(0, ...turns.filter((u) => u.out === o && !widen.has(u.t)).map(radius));
  const left = PAD + outer(-1), right = PAD + outer(1);
  const room = SIDE_W - left - right - gaps.reduce((w, [, g]) => w + g, 0);
  const scale = room / (tMax - tMin || 1);
  // x of a place along the line; at a gap, the side a strip's material lies on
  const x = (t: number, side: 1 | -1 = 1) =>
    left + (t - tMin) * scale + gaps.reduce((w, [g, width]) =>
      w + (g < t - EPS || (Math.abs(g - t) < EPS && side === 1) ? width : 0), 0);
  const levels = Math.max(...strips.map((s) => s.level)) + 1;
  const sideH = 2 * PAD + (levels - 1) * GAP + 28;

  const nodes: SvgNode[] = [];
  const at = (t: number, s: Strip) => (Math.abs(t - s.t1) < EPS ? -1 : 1);
  // two strips of one level that meet share no hinge there, only raw edges:
  // each stops short of the place, so a gap stands between them
  const meets = (s: Strip, t: number) => strips.some((o) => o !== s && o.level === s.level &&
    (Math.abs(o.t0 - t) < EPS || Math.abs(o.t1 - t) < EPS));
  for (const s of strips) {
    const parts = s.pieces.flatMap((p) => p.parts).sort((p, q) => p.t0 - q.t0);
    for (const r of parts) {
      // a part that ends inside the strip runs on to where the next one starts,
      // across a gap the strip stretches through
      const [first, last] = [Math.abs(r.t0 - s.t0) < EPS, Math.abs(r.t1 - s.t1) < EPS];
      const x0 = x(r.t0, 1) + (first && meets(s, s.t0) ? APART : 0);
      const x1 = x(r.t1, last ? -1 : 1) - (last && meets(s, s.t1) ? APART : 0);
      nodes.push(el("line", {
        "data-kind": "layer", "data-name": r.name, "data-level": s.level,
        x1: x0, y1: y(s.level), x2: x1, y2: y(s.level),
        stroke: colour(r.name), "stroke-width": 3, "stroke-linecap": "round",
      }));
      // at the start of the part, clear of the points and names over its middle
      nodes.push(el("text", {
        "data-kind": "layer-name", x: x0 + (Math.abs(r.t0 - s.t0) < EPS ? 14 : 8), y: y(s.level) - 7, "text-anchor": "start",
        "font-size": 13, "font-weight": 600, fill: colour(r.name),
      }, [], String(r.name)));
      if (Math.abs(r.t0 - s.t0) > EPS) {
        nodes.push(el("line", {
          "data-kind": "seam", x1: x0, y1: y(s.level) - 5, x2: x0, y2: y(s.level) + 5,
          stroke: theme.ink, "stroke-width": 1.2,
        }));
      }
    }
  }
  for (const u of turns) {
    const [p, q] = [strips[u.strips[0]]!, strips[u.strips[1]]!];
    const xh = x(u.t, at(u.t, p));
    const [y0, y1] = [y(p.level), y(q.level)];
    const r = radius(u);
    nodes.push(el("path", {
      "data-kind": "turn", "data-out": u.out,
      d: `M ${xh} ${y0} A ${r} ${r} 0 0 ${(u.out === 1) === (y0 < y1) ? 1 : 0} ${xh} ${y1}`,
      fill: "none", stroke: theme.ink, "stroke-width": 2,
    }));
    // the hinge's name beside the crown of its turn
    nodes.push(el("text", {
      "data-kind": "hinge", "data-name": u.name,
      x: xh + u.out * (r + 4), y: (y0 + y1) / 2 + 4, "text-anchor": u.out === 1 ? "start" : "end",
      "font-size": 12, fill: theme.ink, ...halo,
    }, [], u.name));
  }
  // a named point on the line: where it stands across the whole stack, as Ida
  // marks the place of a fold line [ida2007modeling, Fig. 7]
  for (const p of points) {
    const xp = (x(p.t, -1) + x(p.t, 1)) / 2;
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
        ? [x(u.t, at(u.t, strips[u.strips[0]]!)) + u.out * radius(u),
          (y(strips[u.strips[0]]!.level) + y(strips[u.strips[1]]!.level)) / 2]
        : [xp, y(strips[s.strip]!.level)];
      nodes.push(el("circle", { "data-kind": "point-own", "data-name": p.name, cx, cy, r: 4.5, fill: theme.ink }));
    }
  }
  nodes.push(el("text", {
    x: SIDE_W / 2, y: sideH - 12, "text-anchor": "middle", "font-size": 15, fill: theme.ink,
  }, [], opts.title ?? `along --${opts.along}, top layer first`));

  // the crease pattern with the pieces of the paper the line crosses
  const lay = sceneLayout(scene);
  // with the creases of the state drawn alone: a crease a later write scores
  // has no line yet, though the pieces it will split already carry its names
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
      stroke: colour(r.name), "stroke-width": 5, "stroke-linecap": "round",
    }));
    marks.push(el("text", {
      "data-kind": "piece-name", x: (lay.tx(ax) + lay.tx(bx)) / 2, y: (lay.ty(ay) + lay.ty(by)) / 2 - 8,
      "text-anchor": "middle", "font-size": 15, "font-weight": 600, fill: colour(r.name), ...halo,
    }, [], String(r.name)));
  }
  // each hinge named where it crosses the line on the paper, above and to the
  // left, since a point's name stands below and to the right
  for (const u of turns) {
    const [hx, hy] = u.paper;
    marks.push(el("text", {
      "data-kind": "hinge", "data-name": u.name, x: lay.tx(hx) - 6, y: lay.ty(hy) - 6,
      "text-anchor": "end", "font-size": 13, fill: theme.ink, ...halo,
    }, [], u.name));
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
  const doc = createDoc(2 * lay.W + SIDE_W, H);
  doc.root.children.push(
    el("rect", { width: 2 * lay.W + SIDE_W, height: H, fill: theme.background }),
    el("svg", { ...folded.attrs, x: 0, y: 0 }, [...folded.children, ...cut]),
    el("svg", { ...cp.attrs, x: lay.W, y: 0 }, [...cp.children, ...marks]),
    el("g", { transform: `translate(${2 * lay.W} ${(H - sideH) / 2})` }, nodes),
  );
  return doc;
}
