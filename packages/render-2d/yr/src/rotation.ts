// The rotation symbol between two panels whose `@orient` turns differ: David
// Shall's circle with two arrowheads and the fraction of a turn inside
// [lang1991conventions, Part III, figures 18 and 19].
import type { Vec2 } from "@beloch/scene";
import { el } from "@beloch/render-svg";
import type { SvgNode } from "@beloch/render-svg";
import type { Ink } from "./draw";

export interface TurnFraction { num: number; den: number; clockwise: boolean; }

const MAX_DEN = 24;

// The turn by `delta` radians, counterclockwise on the page, as the nearest
// fraction of a full turn with a denominator of at most 24, the smallest
// denominator winning a tie. Known limitation: a turn between two such
// fractions is shown as the nearer one, and a turn of less than 1/48 as 1/24.
export function turnFraction(delta: number): TurnFraction {
  const d = Math.atan2(Math.sin(delta), Math.cos(delta));
  const f = Math.abs(d) / (2 * Math.PI);
  let best = { num: 1, den: 1, err: Infinity };
  for (let den = 1; den <= MAX_DEN; den++) {
    const num = Math.max(1, Math.round(f * den));
    const err = Math.abs(f - num / den);
    if (err < best.err - 1e-9) best = { num, den, err };
  }
  return { num: best.num, den: best.den, clockwise: d < 0 };
}

const R = 28;

// An open arrowhead at `tip`, pointing along the unit vector `u`.
function chevron(tip: Vec2, u: Vec2, ink: Ink): SvgNode {
  const k = 10, w = 6;
  const back = (s: number): string =>
    `${tip[0] - u[0] * k - u[1] * w * s},${tip[1] - u[1] * k + u[0] * w * s}`;
  return el("polyline", {
    points: `${back(1)} ${tip[0]},${tip[1]} ${back(-1)}`,
    fill: "none", stroke: ink.ink, "stroke-width": 2, "stroke-linejoin": "round", "stroke-linecap": "round",
  });
}

// The symbol centered on `c`, in page pixels: a circle, an arrowhead on its
// top and one on its bottom pointing the way the model turns, and the fraction.
export function rotationSymbol(c: Vec2, turn: TurnFraction, ink: Ink): SvgNode {
  const s = turn.clockwise ? 1 : -1;
  const text = `${turn.num}/${turn.den}`;
  return el("g", {
    "data-kind": "rotation", "data-turn": text, "data-direction": turn.clockwise ? "clockwise" : "counterclockwise",
  }, [
    el("circle", { cx: c[0], cy: c[1], r: R, fill: "none", stroke: ink.ink, "stroke-width": 2 }),
    chevron([c[0], c[1] - R], [s, 0], ink),
    chevron([c[0], c[1] + R], [-s, 0], ink),
    el("text", {
      x: c[0], y: c[1] + 7, "text-anchor": "middle", "font-size": 20, fill: ink.ink,
    }, [], text),
  ]);
}
