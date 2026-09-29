import { test, expect } from "bun:test";
import { parseFold, SceneError } from "@beloch/scene";
import { renderSide, sideSection } from "@beloch/render-svg";
import type { Strip } from "@beloch/render-svg";
import { sceneLayout } from "@beloch/render-svg";

// Written with `beloch fold`: the three flat states of the six rays of the
// preliminary base (#52), each picked by the letter of one ray, then a line
// across the folded base, perpendicular to the diagonal:
//
//   flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b) (--bd & .d)
//   .m = free on --bd from .b at 1/4
//   --s = (perp --bd through .m)
//   mark (--s) as --sm
//   .e = --sm * --h
//   .f = --sm * --v
//
// with `mountain` on `(--bd & .b)` in 1, on `(--v & --cd)` in 2 and on
// `(--h & --da)` in 3.
const fixture = async (n: number) =>
  parseFold(await Bun.file(new URL(`./fixtures/side-preliminary-${n}.fold`, import.meta.url)).text());

// The quarter of the unit square a strip lies in, named by its corner.
function quarter(s: Strip): string {
  const [[ax, ay], [bx, by]] = s.pieces[0]!.paper;
  const [x, y] = [(ax + bx) / 2, (ay + by) / 2];
  return x < 0.5 ? (y < 0.5 ? "a" : "d") : (y < 0.5 ? "b" : "c");
}

// The quarters of the strips over the part of the line where `side` lies, top
// layer first.
function stack(strips: Strip[], side: string): string[] {
  const own = strips.filter((s) => quarter(s) === side);
  const [t0, t1] = [Math.min(...own.map((s) => s.t0)), Math.max(...own.map((s) => s.t1))];
  return strips.filter((s) => Math.min(s.t1, t1) - Math.max(s.t0, t0) > 1e-9)
    .sort((p, q) => p.level - q.level).map(quarter);
}

test("the preliminary base lies a, b, b, c on the .b side and a, d, d, c on the .d side", async () => {
  const { strips } = sideSection(await fixture(1), "s");
  expect(stack(strips, "b")).toEqual(["a", "b", "b", "c"]);
  expect(stack(strips, "d")).toEqual(["a", "d", "d", "c"]);
});

test("the other two flat states of the same rays lie b, b, a, c and a, c, b, b", async () => {
  expect(stack(sideSection(await fixture(2), "s").strips, "b")).toEqual(["b", "b", "a", "c"]);
  expect(stack(sideSection(await fixture(3), "s").strips, "b")).toEqual(["a", "c", "b", "b"]);
});

test("paper that runs flat across a hinge is one strip, and every other hinge is a turn", async () => {
  const { strips, turns } = sideSection(await fixture(2), "s");
  // the quarters of .a and .c lie flat across the diagonal, the quarters of .b
  // and .d are folded along it
  expect(strips.length).toBe(6);
  expect(strips.filter((s) => s.pieces.length === 2).map(quarter).sort()).toEqual(["a", "c"]);
  // the section of the base is a closed path around its point: as many turns
  // as strips
  expect(turns.length).toBe(6);
});

test("the strips are numbered along the paper, and the crease pattern carries the same numbers", async () => {
  const scene = await fixture(1);
  const { strips, turns } = sideSection(scene, "s");
  const byNumber = new Map(strips.map((s, i) => [s.number, i]));
  for (let n = 1; n < strips.length; n++) {
    const [p, q] = [byNumber.get(n)!, byNumber.get(n + 1)!];
    expect(turns.some((u) => u.strips.includes(p) && u.strips.includes(q))).toBe(true);
  }
  const svg = renderSide(scene, { along: "s" }).toString();
  for (let n = 1; n <= strips.length; n++) {
    expect(svg).toContain(`data-kind="layer" data-number="${n}"`);
    expect(svg).toContain(`data-kind="piece" data-number="${n}"`);
  }
});

test.each([1, 2, 3])("no two turns of state %i cross or touch, unless one wraps the other", async (n) => {
  const svg = renderSide(await fixture(n), { along: "s" }).toString();
  // the box of each turn: from its hinge out by its radius, between its levels
  const boxes = [...svg.matchAll(/data-kind="turn" data-out="(-?1)" d="M ([\d.]+) ([\d.]+) A ([\d.]+) [\d.]+ 0 0 \d [\d.]+ ([\d.]+)"/g)]
    .map((m) => {
      const [out, x, y0, r, y1] = [1, 2, 3, 4, 5].map((k) => Number(m[k]));
      return { x: out! > 0 ? [x!, x! + r!] : [x! - r!, x!], y: [Math.min(y0!, y1!), Math.max(y0!, y1!)] };
    });
  expect(boxes.length).toBe(6);
  // closer than 5 px counts as touching
  const near = (m: number) => ([a0, a1]: number[], [b0, b1]: number[]) => Math.min(a1!, b1!) - Math.max(a0!, b0!) > -m;
  // two turns may share a box only when one wraps the other, from the same hinge
  boxes.forEach((p, i) => boxes.forEach((q, j) => {
    if (i < j && near(5)(p.x, q.x) && near(-1e-6)(p.y, q.y)) expect(p.x[0] === q.x[0] || p.x[1] === q.x[1]).toBe(true);
  }));
});

test("a line the program does not name is an error", async () => {
  const scene = await fixture(1);
  expect(() => renderSide(scene, { along: "nope" })).toThrow(SceneError);
});

test("a named point is one paper point, and the other layers only land on it", async () => {
  const scene = await fixture(1);
  const { points, strips } = sideSection(scene, "s");
  // .e and .f at the two ends of the line, .m on the diagonal between them
  expect(points.map((p) => p.name).sort()).toEqual(["e", "f", "m"]);
  const t = Object.fromEntries(points.map((p) => [p.name, p.t]));
  expect((t.m! - t.e!) * (t.f! - t.m!)).toBeGreaterThan(0);
  const at = Object.fromEntries(points.map((p) => [p.name, p]));
  // the diagonal crosses all four quarters; each end is a folded edge, where
  // two hinges meet the line
  expect([at.m!, at.e!, at.f!].map((p) => p.spots.length)).toEqual([4, 2, 2]);
  for (const p of points) expect(p.spots.filter((s) => s.own).length).toBe(1);
  // .m was placed on --bd in the quarter of .b
  expect(quarter(strips[at.m!.spots.find((s) => s.own)!.strip]!)).toBe("b");
  // the crease pattern names the point once, at its own place
  const svg = renderSide(scene, { along: "s" }).toString();
  expect((svg.match(/<circle data-kind="point" data-name="m"/g) ?? []).length).toBe(3);
  expect((svg.match(/>\.m</g) ?? []).length).toBe(2); // over the stack and in the crease pattern
});

test("the section runs left to right on the table, whatever sign the line's coefficients carry", async () => {
  const scene = await fixture(1);
  const order = (s: typeof scene) => sideSection(s, "s").points.sort((p, q) => p.t - q.t).map((p) => p.name);
  const line = scene.namedLines.find((l) => l.name === "s")!;
  const flipped = { ...scene, namedLines: [{ ...line, coeffs: line.coeffs.map((k) => -k) as typeof line.coeffs }] };
  expect(order(flipped)).toEqual(order(scene));
  // the points of the cut, in the order the section draws them, left to right
  const x = (n: string) => scene.namedPoints.find((p) => p.name === n && p.step === scene.steps.length - 1)!.table[0];
  const names = order(scene);
  for (let i = 1; i < names.length; i++) expect(x(names[i]!)).toBeGreaterThan(x(names[i - 1]!));
});

test("the folded state beside the section carries the cut", async () => {
  const scene = await fixture(1);
  const svg = renderSide(scene, { along: "s" }).toString();
  const cut = svg.match(/data-kind="cut" x1="([\d.]+)" y1="[\d.]+" x2="([\d.]+)"/);
  expect(cut).not.toBeNull();
  // the folded state is the first panel, left of the crease pattern
  const W = sceneLayout(scene).W;
  expect(Math.max(Number(cut![1]), Number(cut![2]))).toBeLessThan(W);
  expect(svg).toContain(`width="${2 * W + 572}"`);
});
