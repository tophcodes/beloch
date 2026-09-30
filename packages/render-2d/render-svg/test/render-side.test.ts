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

test("each piece is named by its face of the crease pattern, and the crease pattern carries the same names", async () => {
  const scene = await fixture(1);
  const { strips } = sideSection(scene, "s");
  const parts = strips.flatMap((s) => s.pieces.flatMap((p) => p.parts));
  // the line crosses each of the ten faces of the pattern it meets once
  expect(new Set(parts.map((r) => r.name)).size).toBe(parts.length);
  // a part's paper lies in the face it is named by
  for (const r of parts) {
    const face = scene.cp.facesVertices[r.name - 1]!.map((i) => scene.cp.vertices[i]!);
    const [mx, my] = [(r.paper[0][0] + r.paper[1][0]) / 2, (r.paper[0][1] + r.paper[1][1]) / 2];
    const sides = face.map(([ax, ay], k) => {
      const [bx, by] = face[(k + 1) % face.length]!;
      return Math.sign((bx - ax) * (my - ay) - (by - ay) * (mx - ax));
    });
    expect(sides.every((z) => z >= 0) || sides.every((z) => z <= 0)).toBe(true);
  }
  const svg = renderSide(scene, { along: "s" }).toString();
  for (const r of parts) {
    expect(svg).toContain(`data-kind="layer" data-name="${r.name}"`);
    expect(svg).toContain(`data-kind="piece" data-name="${r.name}"`);
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

test("a line across the middle of the state is seen from the same side, whatever sign its coefficients carry", async () => {
  const scene = await fixture(1);
  const order = (s: typeof scene) => sideSection(s, "s").points.sort((p, q) => p.t - q.t).map((p) => p.name);
  const line = scene.namedLines.find((l) => l.name === "s")!;
  const flipped = { ...scene, namedLines: [{ ...line, coeffs: line.coeffs.map((k) => -k) as typeof line.coeffs }] };
  expect(order(flipped)).toEqual(order(scene));
  // the line is a diagonal of the base, which reaches as far on both sides; the
  // section then runs left to right on the table
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

// The half-folded sheet reversed (#119), cut along its top edge:
//
//   paper square
//   fold (map .b onto .a) as --d
//   .s = free on --cd from .d at 1/4
//   --k = (perp --da through .s)
//   reverse (map .a onto .d)
//
// Step 1 is the half-folded sheet, step 2 the reversed one; --k is the top
// edge of both.
const reverse = async () =>
  parseFold(await Bun.file(new URL("./fixtures/side-reverse.fold", import.meta.url)).text());

// The names of the layers over the whole line, top layer first.
const layers = (strips: Strip[]) =>
  [...strips].sort((p, q) => p.level - q.level).map((s) => s.pieces.flatMap((p) => p.parts.map((r) => r.name)).join("+"));

test("a piece keeps its name before and after a write, and each hinge is named by the pieces it joins", async () => {
  const scene = await reverse();
  const before = sideSection(scene, "k", "1"), after = sideSection(scene, "k", "2");
  // the reverse leaves the upper halves where they were and tucks the lower
  // halves between them
  expect(layers(before.strips)).toEqual(["2", "1"]);
  expect(layers(after.strips)).toEqual(["2", "4", "3", "1"]);
  expect(before.turns.map((u) => u.name)).toEqual(["1|2"]);
  expect(after.turns.map((u) => u.name).sort()).toEqual(["1|2", "3|4"]);
  // hinge 1|2 is the same place on the paper in both
  expect(before.turns[0]!.paper).toEqual(after.turns.find((u) => u.name === "1|2")!.paper);
  // both are named in the section and in the crease pattern
  const svg = renderSide(scene, { along: "k" }).toString();
  for (const n of ["1|2", "3|4"]) expect(svg.split(`data-kind="hinge" data-name="${n}"`).length - 1).toBe(2);
});

test("a line along an edge of the state is seen from outside that edge", async () => {
  const scene = await reverse();
  for (const step of ["1", "2"]) {
    const { view, turns, strips } = sideSection(scene, "k", step);
    // --k is y = 1, the top edge: the eye stands above it and looks down, so
    // the fold at x = 1/2 lies on the eye's left, at the start of the section
    expect(view[0]).toBeCloseTo(0);
    expect(view[1]).toBeCloseTo(1);
    const t0 = Math.min(...strips.map((s) => s.t0));
    for (const u of turns) expect(u.t).toBeCloseTo(t0);
  }
});

test("seen from the far side, the section is mirrored and the arrows turn round", async () => {
  const scene = await reverse();
  const near = sideSection(scene, "k", "2"), far = sideSection(scene, "k", "2", true);
  expect(far.view.map((v) => v + 0)).toEqual(near.view.map((v) => -v + 0));
  // the same layers, the hinges at the other end
  expect(layers(far.strips)).toEqual(layers(near.strips));
  const t1 = Math.max(...far.strips.map((s) => s.t1));
  for (const u of far.turns) expect(u.t).toBeCloseTo(t1);
  expect(far.turns.map((u) => u.out as number)).toEqual(near.turns.map((u) => -u.out));
  // each arrow on the folded state points the way the eye looks: down on the
  // page from above the edge by default, up from below it on the far side
  const arrows = (farSide: boolean) => [...renderSide(scene, { along: "k", farSide }).toString()
    .matchAll(/data-kind="view"><line x1="[\d.]+" y1="([\d.]+)" x2="[\d.]+" y2="([\d.]+)"/g)]
    .map((m) => Math.sign(Number(m[2]) - Number(m[1])));
  expect(arrows(false)).toEqual([1, 1]);
  expect(arrows(true)).toEqual([-1, -1]);
});

test("the crease pattern beside an earlier state draws the creases of that state alone", async () => {
  const scene = await reverse();
  // the panels in order: the folded state, then the crease pattern
  const panel = (step: string) => renderSide(scene, { along: "k", step }).toString().split("<svg ")[3]!;
  const creases = (svg: string) => (svg.match(/data-kind="crease"/g) ?? []).length;
  // the sheet's outline in eight segments and --d in two; the reverse adds
  // two more
  expect(creases(panel("1"))).toBe(10);
  expect(creases(panel("2"))).toBe(12);
});

// Both sides folded to the middle and cut across, the cupboard fold:
//
//   paper square
//   mark (map --da onto --bc) as --m
//   .s = --m * --ab
//   .t = free on --m from .s at 1/4
//   fold (map --da onto --m)
//   fold (map --bc onto --m)
//   --k = (perp --m through .t)
//
// The two flaps meet on --m raw edge against raw edge; under them the sheet
// runs flat across the mark --m.
const cupboard = async () =>
  parseFold(await Bun.file(new URL("./fixtures/side-cupboard.fold", import.meta.url)).text());

// The layer lines of one level of the section, left to right, and the ticks.
function drawn(svg: string, level: number) {
  const lines = [...svg.matchAll(/data-kind="layer" data-name="(\d+)" data-level="(\d+)" x1="([\d.]+)" y1="[\d.]+" x2="([\d.]+)"/g)]
    .filter((m) => Number(m[2]) === level)
    .map((m) => ({ name: Number(m[1]), x1: Number(m[3]), x2: Number(m[4]) }))
    .sort((p, q) => p.x1 - q.x1);
  const ticks = [...svg.matchAll(/data-kind="seam" x1="([\d.]+)"/g)].map((m) => Number(m[1]));
  return { lines, ticks };
}

test("two pieces of a layer that meet without a hinge are drawn with a gap between them", async () => {
  const svg = renderSide(await cupboard(), { along: "k" }).toString();
  const top = drawn(svg, 0), bottom = drawn(svg, 1);
  // the flaps 3 and 4 on top: apart, and no tick between them
  expect(top.lines.map((l) => l.name)).toEqual([3, 4]);
  expect(top.lines[1]!.x1 - top.lines[0]!.x2).toBeGreaterThan(6);
  // the sheet under them runs on across --m, with a tick there
  expect(bottom.lines.map((l) => l.name)).toEqual([1, 2]);
  expect(bottom.lines[1]!.x1).toBe(bottom.lines[0]!.x2);
  expect(bottom.ticks).toEqual([bottom.lines[1]!.x1]);
});

test("a piece a later crease splits keeps its tick", async () => {
  // the flat sheet before the first fold: one piece that --d splits into 2
  // and 1, drawn as one run with a tick between them
  const svg = renderSide(await reverse(), { along: "k", step: "0" }).toString();
  const { lines, ticks } = drawn(svg, 0);
  expect(lines.map((l) => l.name)).toEqual([2, 1]);
  expect(lines[1]!.x1).toBe(lines[0]!.x2);
  expect(ticks).toEqual([lines[1]!.x1]);
});
