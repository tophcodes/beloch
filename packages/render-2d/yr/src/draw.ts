// The marks of the YR notation, in page pixels [lang1991conventions]: the
// valley line, the existing crease, the valley arrow and the fold-and-unfold
// arrow, whose tail carries Montroll's hollow double head.
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

// The arrow of a valley fold: from the corner that moves to where it lands,
// bent toward `toward`, the middle of the fold line.
export const valleyArrow = (tail: Vec2, tip: Vec2, toward: Vec2 | null, ink: Ink) =>
  arrow("valley-arrow", tail, tip, toward, false, ink);

// Fold and unfold: the valley arrow with a hollow head at its tail.
export const foldAndUnfoldArrow = (tail: Vec2, tip: Vec2, toward: Vec2 | null, ink: Ink) =>
  arrow("fold-and-unfold-arrow", tail, tip, toward, true, ink);
