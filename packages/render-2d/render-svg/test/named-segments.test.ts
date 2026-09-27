// Where a named crease or line lies on the paper, and where a highlight draws
// it. reverse-scar.fold folds the triangle and reverses `.b` onto `.c` as `--h`:
// the crease goes through two layers and leaves an L of scars on the sheet.
// folded-chord.fold binds `--m = (through .b .c)` after the book fold, so the
// line lies on the table over both layers: the right edge of the sheet and the
// left edge, folded over onto it.
import { test, expect } from "bun:test";
import { parseFold, pickStep } from "@beloch/scene";
import type { Vec2 } from "@beloch/scene";
import { renderCP, renderFolded } from "@beloch/render-svg";
import { namedSegments, segmentsInFrame } from "../src/geometry";

const load = async (name: string) =>
  parseFold(await Bun.file(new URL(`./fixtures/${name}`, import.meta.url)).text());

const scar = await load("reverse-scar.fold");
const chord = await load("folded-chord.fold");

const round = ([[x1, y1], [x2, y2]]: [Vec2, Vec2]) => {
  const r = (v: number) => Math.round(v * 1e6) / 1e6;
  const ends = [[r(x1), r(y1)], [r(x2), r(y2)]].sort((p, q) => p[0]! - q[0]! || p[1]! - q[1]!);
  return JSON.stringify(ends);
};
const sorted = (segs: [Vec2, Vec2][]) => segs.map(round).sort();

test("a crease is where its scars are on the sheet", () => {
  expect(sorted(namedSegments(scar, "h"))).toEqual(
    sorted([[[0.5, 0.5], [1, 0.5]], [[0.5, 0], [0.5, 0.5]]]),
  );
});

test("a line bound on folded paper is the paper under it, in every layer", () => {
  expect(sorted(namedSegments(chord, "m"))).toEqual(
    sorted([[[1, 0], [1, 1]], [[0, 0], [0, 1]]]),
  );
});

test("a name that is neither a crease nor a line has no pieces", () => {
  expect(namedSegments(scar, "nope")).toEqual([]);
});

test("in a folded frame the pieces land where the paper lies", () => {
  const frame = pickStep(scar)!.frame;
  const onTable = segmentsInFrame(frame, namedSegments(scar, "h"));
  // Both scars lie on the table line y = 1/2 of the fold that made them.
  expect(onTable.length).toBeGreaterThan(0);
  for (const [[, y1], [, y2]] of onTable) {
    expect(y1).toBeCloseTo(0.5, 9);
    expect(y2).toBeCloseTo(0.5, 9);
  }
});

const highlighted = (svg: string, name: string) => {
  const group = svg.match(new RegExp(`<g class="construction" data-construction="${name}"[^>]*>([\\s\\S]*?)</g>`));
  return [...(group?.[1] ?? "").matchAll(/<line [^>]*>/g)].length;
};

test("a highlighted crease is drawn along its scars in both views", () => {
  expect(highlighted(renderCP(scar, { highlight: ["--h"] }).toString(), "h")).toBe(2);
  expect(highlighted(renderFolded(scar, { highlight: ["--h"] }).toString(), "h")).toBeGreaterThan(0);
});
