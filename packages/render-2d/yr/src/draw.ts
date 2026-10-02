// The marks of the YR notation, in page pixels [lang1991conventions]: the
// valley and mountain lines, the existing crease, the valley arrow, the
// fold-and-unfold arrow, whose tail carries Montroll's hollow double head, the
// arrows of the reverse folds, the mountain arrow, the hooked tail of a fold
// of some layers, and the turn-over arrow.
import type { Vec2 } from "@beloch/scene";
import { el } from "@beloch/render-svg";
import type { SvgNode } from "@beloch/render-svg";

export interface Ink { ink: string; paper: string; }

const fmt = (x: number) => Math.round(x * 100) / 100;
const line = ([p, q]: [Vec2, Vec2]) => ({ x1: fmt(p[0]), y1: fmt(p[1]), x2: fmt(q[0]), y2: fmt(q[1]) });

export function valleyLine(seg: [Vec2, Vec2], statement: number, ink: Ink): SvgNode {
  return el("line", {
    "data-kind": "valley-line", "data-statement": statement,
    ...line(seg),
    stroke: ink.ink, "stroke-width": 2, "stroke-dasharray": "9 6", "stroke-linecap": "butt",
  });
}

export function existingCrease(seg: [Vec2, Vec2], ink: Ink): SvgNode {
  return el("line", {
    "data-kind": "existing-crease",
    ...line(seg),
    stroke: ink.ink, "stroke-width": 1, opacity: 0.55,
  });
}

// The control point of an arrow from `tail` to `head`: off the chord by 0.3
// of its length, on the side of `toward`. A `toward` on the chord, or none,
// bends the arrow up the page.
export function bend(tail: Vec2, head: Vec2, toward: Vec2 | null): Vec2 {
  const mx = (tail[0] + head[0]) / 2, my = (tail[1] + head[1]) / 2;
  const dx = head[0] - tail[0], dy = head[1] - tail[1], L = Math.hypot(dx, dy);
  let nx = -dy / L, ny = dx / L;
  const side = toward ? nx * (toward[0] - mx) + ny * (toward[1] - my) : 0;
  if (Math.abs(side) > 1) {
    if (side < 0) { nx = -nx; ny = -ny; }
  } else if (ny > 0 || (ny === 0 && nx < 0)) {
    nx = -nx; ny = -ny;
  }
  return [mx + nx * 0.3 * L, my + ny * 0.3 * L];
}

// A head at `tip`, pointing away from `from`: filled for a fold, hollow for
// an unfold.
function head(tip: Vec2, from: Vec2, hollow: boolean, ink: Ink): SvgNode {
  const ux0 = tip[0] - from[0], uy0 = tip[1] - from[1], l = Math.hypot(ux0, uy0);
  const ux = ux0 / l, uy = uy0 / l, k = 16, w = 7;
  const pts: Vec2[] = [tip, [tip[0] - ux * k - uy * w, tip[1] - uy * k + ux * w], [tip[0] - ux * k + uy * w, tip[1] - uy * k - ux * w]];
  return el("polygon", {
    points: pts.map((p) => `${fmt(p[0])},${fmt(p[1])}`).join(" "),
    fill: hollow ? ink.paper : ink.ink, stroke: ink.ink, "stroke-width": hollow ? 1.5 : 1, "stroke-linejoin": "round",
  });
}

function arrow(kind: string, tail: Vec2, tip: Vec2, toward: Vec2 | null, unfold: boolean, ink: Ink): SvgNode {
  const c = bend(tail, tip, toward);
  const stem = el("path", {
    d: `M${fmt(tail[0])},${fmt(tail[1])} Q${fmt(c[0])},${fmt(c[1])} ${fmt(tip[0])},${fmt(tip[1])}`,
    fill: "none", stroke: ink.ink, "stroke-width": 2,
  });
  const heads = [head(tip, c, false, ink)];
  if (unfold) heads.push(head(tail, c, true, ink));
  return el("g", { "data-kind": kind }, [stem, ...heads]);
}

// The arrow of a valley fold: from the point that moves to where it lands,
// bent toward `toward`, the middle of the fold line.
export const valleyArrow = (tail: Vec2, tip: Vec2, toward: Vec2 | null, ink: Ink) =>
  arrow("valley-arrow", tail, tip, toward, false, ink);

// Fold and unfold: the valley arrow with a hollow head at its tail.
export const foldAndUnfoldArrow = (tail: Vec2, tip: Vec2, toward: Vec2 | null, ink: Ink) =>
  arrow("fold-and-unfold-arrow", tail, tip, toward, true, ink);

// The mountain line: dashes with two dots between them.
export function mountainLine(seg: [Vec2, Vec2], statement: number, ink: Ink): SvgNode {
  return el("line", {
    "data-kind": "mountain-line", "data-statement": statement,
    ...line(seg),
    stroke: ink.ink, "stroke-width": 2, "stroke-dasharray": "10 4 2 4 2 4", "stroke-linecap": "butt",
  });
}

// The push arrow of an inside reverse fold, "push here" [lang1991conventions,
// Part IV]: a hollow stem with a hollow head and a cleft tail, its tip at
// `tip`, pointing along the unit vector `dir`.
export function pushArrow(tip: Vec2, dir: Vec2, ink: Ink): SvgNode {
  const [ux, uy] = dir, nx = -uy, ny = ux;
  const at = (back: number, out: number): Vec2 => [tip[0] - ux * back + nx * out, tip[1] - uy * back + ny * out];
  const pts = [
    at(0, 0), at(22, 15), at(22, 6), at(60, 11), at(52, 0), at(60, -11), at(22, -6), at(22, -15),
  ];
  return el("polygon", {
    "data-kind": "push-arrow",
    points: pts.map((p) => `${fmt(p[0])},${fmt(p[1])}`).join(" "),
    fill: ink.paper, stroke: ink.ink, "stroke-width": 1.5, "stroke-linejoin": "round",
  });
}

// The arrows of an outside reverse fold [lang1991conventions, Part V;
// lang2011secrets, Fig. 2.22]: two loops around the flap, one above and one
// below the push arrow, each starting on the flap near its open edges,
// wrapping around them and running across the flap to beyond its folded
// edge. The upper loop is a valley arrow, in front of the flap; the lower one
// is a mountain arrow, with its hollow head on one side only, and dotted where
// it passes behind the flap. `open` and `folded` are the points where a line
// across the flap at the height of the push arrow meets its open edges and its
// folded edge; `up` is the unit vector along the folded edge toward the tip.
const LOOP_OFFSET = 28, LOOP_HEIGHT = 11, LOOP_OPEN = 22, LOOP_FOLDED = 64;
const LOOP_FROM = (110 * Math.PI) / 180, LOOP_TO = (355 * Math.PI) / 180;

export function wrapArrows(open: Vec2, folded: Vec2, up: Vec2, ink: Ink): SvgNode[] {
  const w = Math.hypot(folded[0] - open[0], folded[1] - open[1]);
  const across: Vec2 = [(folded[0] - open[0]) / w, (folded[1] - open[1]) / w];
  // along `across`, measured from `open`: the loop spans [-LOOP_OPEN, w + LOOP_FOLDED]
  const mid = (w + LOOP_FOLDED - LOOP_OPEN) / 2, reach = (w + LOOP_FOLDED + LOOP_OPEN) / 2;
  const loop = (offset: number) => {
    const c: Vec2 = [open[0] + across[0] * mid + up[0] * offset, open[1] + across[1] * mid + up[1] * offset];
    return Array.from({ length: 49 }, (_, i) => {
      const th = LOOP_FROM + ((LOOP_TO - LOOP_FROM) * i) / 48;
      const a = reach * Math.cos(th), b = LOOP_HEIGHT * Math.sin(th);
      const p: Vec2 = [c[0] + across[0] * a + up[0] * b, c[1] + across[1] * a + up[1] * b];
      return { p, behind: b < 0 && mid + a > 0 && mid + a < w };
    });
  };
  const path = (pts: Vec2[], dashed: boolean) => el("path", {
    d: pts.map((p, i) => `${i === 0 ? "M" : "L"}${fmt(p[0])},${fmt(p[1])}`).join(" "),
    fill: "none", stroke: ink.ink, "stroke-width": 2, ...(dashed ? { "stroke-dasharray": "2 4" } : {}),
  });

  const front = loop(LOOP_OFFSET);
  const tipF = front.at(-1)!.p, fromF = front.at(-3)!.p;
  const valley = el("g", { "data-kind": "valley-arrow" }, [path(front.map((x) => x.p), false), head(tipF, fromF, false, ink)]);

  // the back loop, cut into runs in front of the flap and behind it
  const back = loop(-LOOP_OFFSET);
  const runs: { pts: Vec2[]; behind: boolean }[] = [];
  for (const x of back) {
    const last = runs.at(-1);
    if (last && last.behind === x.behind) last.pts.push(x.p);
    else runs.push({ pts: last ? [last.pts.at(-1)!, x.p] : [x.p], behind: x.behind });
  }
  const tipM = back.at(-1)!.p, fromM = back.at(-3)!.p;
  const ux0 = tipM[0] - fromM[0], uy0 = tipM[1] - fromM[1], l = Math.hypot(ux0, uy0);
  const ux = ux0 / l, uy = uy0 / l;
  // the barb on the outer side of the loop, away from `up`
  const s = -uy * -up[0] + ux * -up[1] > 0 ? 1 : -1;
  const barb: Vec2[] = [tipM, [tipM[0] - ux * 16 - uy * 8 * s, tipM[1] - uy * 16 + ux * 8 * s], [tipM[0] - ux * 16, tipM[1] - uy * 16]];
  const halfHead = el("polygon", {
    points: barb.map((p) => `${fmt(p[0])},${fmt(p[1])}`).join(" "),
    fill: ink.paper, stroke: ink.ink, "stroke-width": 1.5, "stroke-linejoin": "round",
  });
  const mountain = el("g", { "data-kind": "mountain-arrow" }, [...runs.map((r) => path(r.pts, r.behind)), halfHead]);
  return [valley, mountain];
}

const unit = (v: Vec2): Vec2 => { const l = Math.hypot(v[0], v[1]); return [v[0] / l, v[1] / l]; };
const at = (p: Vec2, ...terms: [number, Vec2][]): Vec2 =>
  terms.reduce<Vec2>((q, [k, v]) => [q[0] + k * v[0], q[1] + k * v[1]], p);
const pt = (p: Vec2) => `${fmt(p[0])},${fmt(p[1])}`;
const cubic = (from: Vec2, ...rest: Vec2[]) => `M${pt(from)} C${rest.map(pt).join(" ")}`;

// The hook at the tail of an arrow that moves some layers of a stack: the
// stem runs on past `tail`, away from `from`, and curls back to the edge
// against the direction `away`, around the layers that move
// [lang1991conventions, Part II].
function hook(tail: Vec2, from: Vec2, away: Vec2, ink: Ink): SvgNode {
  const t = unit([tail[0] - from[0], tail[1] - from[1]]);
  let n: Vec2 = [-t[1], t[0]];
  if (n[0] * away[0] + n[1] * away[1] > 0) n = [-n[0], -n[1]];
  const r = 16;
  return el("path", {
    "data-kind": "hook",
    d: cubic(tail, at(tail, [1.5 * r, t]), at(tail, [1.5 * r, t], [r, n]), at(tail, [r, n])),
    fill: "none", stroke: ink.ink, "stroke-width": 2,
  });
}

// The arrow of a valley fold with its tail hooked around the layers that move.
export function hookedValleyArrow(tail: Vec2, tip: Vec2, toward: Vec2 | null, ink: Ink): SvgNode {
  const node = valleyArrow(tail, tip, toward, ink);
  // the hook keeps turning the way the stem bends, away from its bulge
  const c = bend(tail, tip, toward);
  node.children.push(hook(tail, c, [c[0] - (tail[0] + tip[0]) / 2, c[1] - (tail[1] + tip[1]) / 2], ink));
  return node;
}

// A hollow half head on the end of a stem at `base`, pointing along `dir`:
// one barb, on the side of `side` only, 1.5 times the length of a valley head.
function hollowHalfHead(base: Vec2, dir: Vec2, side: Vec2, ink: Ink): SvgNode {
  const u = unit(dir);
  let n: Vec2 = [-u[1], u[0]];
  if (n[0] * side[0] + n[1] * side[1] < 0) n = [-n[0], -n[1]];
  return el("polygon", {
    points: [base, at(base, [24, u]), at(base, [12, n])].map(pt).join(" "),
    fill: ink.paper, stroke: ink.ink, "stroke-width": 1.5, "stroke-linejoin": "round",
  });
}

// The arrow of a mountain fold [lang1991conventions, Part II]: from the
// centroid `tail` of the moving paper straight away from the crease to the
// paper's outer edge at `edge`, over that edge, and down behind it into a
// hollow half head. The head lies behind the paper `paper` (polygons in page
// pixels): its point reaches a third of its length past the edge, and the
// part of it over the paper is hidden, so the paper's edge passes in front of
// it. `id` names the mask that hides it and must be unique in the document. A
// hooked fold also hooks the tail around the layers that move.
export function mountainArrow(
  tail: Vec2, edge: Vec2, hooked: boolean, paper: Vec2[][], id: string, ink: Ink,
): SvgNode {
  const d = unit([edge[0] - tail[0], edge[1] - tail[1]]);
  // the curl turns toward the right of the page, or up the page when the
  // arrow runs across it
  let n: Vec2 = [-d[1], d[0]];
  if (n[0] < -1e-9 || (Math.abs(n[0]) <= 1e-9 && n[1] > 0)) n = [-n[0], -n[1]];
  const r = 17;
  const end = at(edge, [16, d], [3 * r, n]);
  const c1 = at(edge, [2.8 * r, d]), c2 = at(end, [1.8 * r, d]);
  const stem = el("path", { d: cubic(tail, c1, c2, end), fill: "none", stroke: ink.ink, "stroke-width": 2 });
  const mask = el("mask", { id, maskUnits: "userSpaceOnUse", x: -10000, y: -10000, width: 20000, height: 20000 }, [
    el("rect", { x: -10000, y: -10000, width: 20000, height: 20000, fill: "white" }),
    ...paper.map((poly) => el("polygon", { points: poly.map(pt).join(" "), fill: "black" })),
  ]);
  const behind = el("g", { mask: `url(#${id})` }, [hollowHalfHead(end, [end[0] - c2[0], end[1] - c2[1]], n, ink)]);
  const children = [mask, stem, behind];
  if (hooked) children.push(hook(tail, c1, n, ink));
  return el("g", { "data-kind": "mountain-arrow" }, children);
}

export type TurnDirection = "side-to-side" | "top-to-bottom";

// Turn the model over: a valley arrow with a loop in its stem, lying across
// the page for a turn from side to side and along it for a turn from top to
// bottom, centered on `center` [lang1991conventions, Part III].
export function turnOverArrow(center: Vec2, direction: TurnDirection, ink: Ink): SvgNode {
  const [cx, cy] = center, a = 60, b = 20, r = 13;
  // drawn across the page, then turned a quarter for top to bottom
  const place = ([x, y]: Vec2): Vec2 => (direction === "side-to-side" ? [x, y] : [cx - (y - cy), cy + (x - cx)]);
  const apex: Vec2 = [cx, cy - b], low: Vec2 = [cx, cy - b + 2 * r];
  const across: Vec2[] = [
    [cx - a, cy + b], [cx - a, cy - 0.6 * b], [cx - 0.45 * a, cy - b], apex,
    [cx + 1.33 * r, cy - b], [cx + 1.33 * r, low[1]], low,
    [cx - 1.33 * r, low[1]], [cx - 1.33 * r, cy - b], apex,
    [cx + 0.45 * a, cy - b], [cx + a, cy - 0.6 * b], [cx + a, cy + b],
  ];
  const pts = across.map(place);
  const stem = el("path", { d: cubic(pts[0]!, ...pts.slice(1)), fill: "none", stroke: ink.ink, "stroke-width": 2 });
  return el("g", { "data-kind": "turn-over-arrow", "data-direction": direction }, [
    stem, head(pts[12]!, pts[11]!, false, ink),
  ]);
}
