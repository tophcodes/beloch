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

test("the parts are numbered 1 to n in the order of the paper along the cut, and the crease pattern carries the same numbers", async () => {
  const scene = await fixture(1);
  const { strips } = sideSection(scene, "s");
  const parts = strips.flatMap((s) => s.pieces.flatMap((p) => p.parts)).sort((r, s) => r.name - s.name);
  expect(parts.map((r) => r.name)).toEqual(parts.map((_, i) => i + 1));
  // the section of the base is one closed path on the paper: each part starts
  // where the one numbered before it ends
  const same = (u: number[], v: number[]) => Math.hypot(u[0]! - v[0]!, u[1]! - v[1]!) < 1e-7;
  for (let i = 1; i < parts.length; i++) {
    expect(parts[i]!.paper.some((e) => parts[i - 1]!.paper.some((f) => same(e, f)))).toBe(true);
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
  const boxes = [...svg.matchAll(/data-kind="turn" data-out="(-?1)" data-x="([\d.]+)" data-r="([\d.]+)" data-y0="([\d.]+)" data-y1="([\d.]+)"/g)]
    .map((m) => {
      const [out, x, r, y0, y1] = [1, 2, 3, 4, 5].map((k) => Number(m[k]));
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
  // the section beside it is at least 572 px wide, wider where turns bulge
  // out past the ends of the line
  expect(Number(svg.match(/^<svg[^>]* width="([\d.]+)"/)![1])).toBeGreaterThanOrEqual(2 * W + 572);
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

test("the reverse tucks the lower halves between the upper ones, and no hinge is named", async () => {
  const scene = await reverse();
  const before = sideSection(scene, "k", "1"), after = sideSection(scene, "k", "2");
  // step 1: the top edge of the sheet, numbered from .d; step 2 adds the
  // bottom edge, numbered first since it starts at .a
  expect(layers(before.strips)).toEqual(["2", "1"]);
  expect(layers(after.strips)).toEqual(["4", "2", "1", "3"]);
  expect(before.turns.length).toBe(1);
  expect(after.turns.length).toBe(2);
  expect(renderSide(scene, { along: "k" }).toString()).not.toContain(`data-kind="hinge"`);
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
  // the flaps 1 and 4 on top: apart, and no tick between them
  expect(top.lines.map((l) => l.name)).toEqual([1, 4]);
  expect(top.lines[1]!.x1 - top.lines[0]!.x2).toBeGreaterThan(6);
  // the sheet under them runs on across --m, with a tick there
  expect(bottom.lines.map((l) => l.name)).toEqual([2, 3]);
  expect(bottom.lines[1]!.x1).toBe(bottom.lines[0]!.x2);
  expect(bottom.ticks).toEqual([bottom.lines[1]!.x1]);
});

test("a piece a later crease splits keeps its tick", async () => {
  // the flat sheet before the first fold: one piece that --d splits into 1
  // and 2, drawn as one run with a tick between them
  const svg = renderSide(await reverse(), { along: "k", step: "0" }).toString();
  const { lines, ticks } = drawn(svg, 0);
  expect(lines.map((l) => l.name)).toEqual([1, 2]);
  expect(lines[1]!.x1).toBe(lines[0]!.x2);
  expect(ticks).toEqual([lines[1]!.x1]);
});

test("two programs that fold the same flaps in another order number the layers alike", async () => {
  // the swapped cupboard folds --bc to the middle before --da, so the crease
  // pattern holds the two flaps' faces in the other order
  const swapped = parseFold(await Bun.file(new URL("./fixtures/side-cupboard-swapped.fold", import.meta.url)).text());
  const scene = await cupboard();
  const flaps = (s: typeof scene) => s.cp.facesVertices.map((f) => f.map((i) => s.cp.vertices[i]![0]))
    .map((xs) => xs.reduce((m, x) => m + x, 0) / xs.length);
  expect(flaps(swapped)).not.toEqual(flaps(scene));
  // each strip by its level and its numbers
  const drawnAs = (s: typeof scene) => sideSection(s, "k").strips
    .map((st) => `${st.level}: ${st.pieces.flatMap((p) => p.parts.map((r) => r.name)).join("+")}`).sort();
  expect(drawnAs(swapped)).toEqual(drawnAs(scene));
});

// Two marks 1/64 of the sheet apart, and a line across both:
//
//   paper square
//   .p = free on --ab from .a at 1/2
//   .q = free on --ab from .a at 33/64
//   mark (perp --ab through .p) as --u
//   mark (perp --ab through .q) as --w
//   .e = free on --da from .a at 1/2
//   --k = (perp --da through .e)
test("the numbers of one level stand apart where two faces of the crease pattern lie close together", async () => {
  const scene = parseFold(await Bun.file(new URL("./fixtures/side-close.fold", import.meta.url)).text());
  const svg = renderSide(scene, { along: "k" }).toString();
  const numbers = [...svg.matchAll(/data-kind="layer-name" data-name="(\d+)" x="([\d.]+)"/g)]
    .map((m) => ({ name: m[1]!, x: Number(m[2]) })).sort((m, n) => m.x - n.x);
  expect(numbers.map((m) => m.name)).toEqual(["1", "2", "3"]);
  // the part between the marks, 1/64 of the line, is narrower than its
  // number, since the drawing keeps the proportions of the paper
  const lines = drawn(svg, 0).lines;
  expect(lines[1]!.x2 - lines[1]!.x1).toBeLessThan(8);
  // each number starts past the end of the one before it, at 8 px a digit
  for (let i = 1; i < numbers.length; i++) {
    expect(numbers[i]!.x - numbers[i - 1]!.x).toBeGreaterThanOrEqual(8 * numbers[i - 1]!.name.length);
  }
});

// A sheet with a mark down its middle, folded in half across it, cut along
// the mark:
//
//   paper square
//   mark (map --da onto --bc) as --m
//   fold (map --ab onto --cd)
test("a line along a crease draws each layer once", async () => {
  const scene = parseFold(await Bun.file(new URL("./fixtures/side-along.fold", import.meta.url)).text());
  const { strips, turns } = sideSection(scene, "m");
  // the faces on both sides of --m touch the line; one side of each layer is
  // drawn, the two layers joined by the fold
  expect(strips.length).toBe(2);
  expect(strips.map((s) => s.level).sort()).toEqual([0, 1]);
  expect(turns.length).toBe(1);
});

// A sheet folded in half along a crease the program names, then in half
// again along one it does not name, cut across both:
//
//   paper square
//   fold (map .b onto .a) as --d
//   .m = --d * --ab
//   fold (map .m onto .a)
//   .e = free on --da from .a at 1/2
//   --k = (perp --da through .e)
test("a turn on a crease the program names carries that name, and a turn on an unnamed crease none", async () => {
  const scene = parseFold(await Bun.file(new URL("./fixtures/side-named.fold", import.meta.url)).text());
  const { turns } = sideSection(scene, "k");
  // one turn on --d, two on the unnamed second crease
  expect(turns.map((u) => u.crease).sort()).toEqual(["d", null, null]);
  const svg = renderSide(scene, { along: "k" }).toString();
  expect([...svg.matchAll(/data-kind="crease-name" data-name="([^"]+)"/g)].map((m) => m[1])).toEqual(["--d"]);
});

test.each(["side-preliminary-1", "side-preliminary-2", "side-preliminary-3", "side-reverse", "side-cupboard", "side-named"])(
  "no strip of %s reaches into a turn", async (name) => {
    const scene = parseFold(await Bun.file(new URL(`./fixtures/${name}.fold`, import.meta.url)).text());
    const svg = renderSide(scene, { along: (scene.namedLines.find((l) => l.name === "s") ? "s" : "k") }).toString();
    // each turn a half circle of radius data-r from data-x, between y0 and y1
    const turns = [...svg.matchAll(/data-kind="turn" data-out="(-?1)" data-x="([\d.]+)" data-r="([\d.]+)" data-y0="([\d.]+)" data-y1="([\d.]+)"/g)]
      .map((m) => [1, 2, 3, 4, 5].map((k) => Number(m[k])) as [number, number, number, number, number]);
    expect(turns.length).toBeGreaterThan(0);
    const lines = [...svg.matchAll(/data-kind="layer" data-name="\d+" data-level="\d+" x1="([\d.]+)" y1="([\d.]+)" x2="([\d.]+)"/g)]
      .map((m) => ({ x: [Number(m[1]), Number(m[3])].sort((p, q) => p - q), y: Number(m[2]) }));
    // a strip at a level strictly between the ends of a turn shares no width
    // with the inside of the turn at that level
    for (const [out, x, r, y0, y1] of turns) for (const l of lines) {
      const [mid, h] = [(y0 + y1) / 2, Math.abs(y1 - y0) / 2];
      if (Math.abs(l.y - mid) >= h - 1e-6) continue;
      const reach = x + out * r * Math.sqrt(1 - ((l.y - mid) / h) ** 2);
      const [a, b] = [Math.min(x, reach), Math.max(x, reach)];
      expect(Math.min(l.x[1]!, b) - Math.max(l.x[0]!, a)).toBeLessThanOrEqual(1e-6);
    }
  });
