import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import type { Vec2 } from "@beloch/scene";
import { resolveIsometry } from "@beloch/render-svg";
import {
  CREASE_GAP, foldMotion, panelHalves, panels, panelView, renderYr, turnFraction, turnOver, turnOverArrow,
} from "@beloch/yr";

const scene = async (name: string) =>
  parseFold(await Bun.file(new URL(`./fixtures/${name}.fold`, import.meta.url)).text());

const near = (p: Vec2, q: Vec2) => {
  expect(p[0]).toBeCloseTo(q[0], 6);
  expect(p[1]).toBeCloseTo(q[1], 6);
};

// The svg of one panel, cut out of the column at its data-panel attribute.
const panelSvg = (svg: string, number: string): string => {
  const start = svg.indexOf(`data-panel="${number}"`);
  const next = svg.indexOf("data-panel=", start + 1);
  return svg.slice(start, next < 0 ? undefined : next);
};
const count = (s: string, kind: string) => (s.match(new RegExp(`data-kind="${kind}"`, "g")) ?? []).length;

test("the kite is one panel per step group and one for the result", async () => {
  const { panels: ps, hints } = panels(await scene("kite"));
  expect(ps.map((p) => p.number)).toEqual(["1", "2", "3"]);
  expect(ps.map((p) => p.text)).toEqual([
    "Fold in half along the diagonal and unfold.",
    "Fold both lower edges to the center line.",
    "The kite base.",
  ]);
  expect(ps.map((p) => p.writes.map((w) => w.index))).toEqual([[0], [1, 2], []]);
  expect(ps.map((p) => p.base)).toEqual([0, 0, 2]);
  expect(hints).toEqual([]);
});

test("a fold's arrow runs from the center of the moving paper to where it lands", async () => {
  const s = await scene("kite");
  const m = foldMotion(s, s.statements[1]!);
  expect(m.before).toBe(0);
  expect(m.after).toBe(1);
  // fold (map --da onto --ac) moves the triangle .a, .d, (√2 − 1, 1); the
  // arrow starts at its centroid and ends at the centroid's mirror image
  // across the hinge, the line x = (√2 − 1)·y
  const k = Math.SQRT2 - 1;
  near(m.tail, [k / 3, 2 / 3]);
  const u = [k / Math.hypot(k, 1), 1 / Math.hypot(k, 1)] as const;
  const along = m.tail[0] * u[0] + m.tail[1] * u[1];
  near(m.head, [2 * along * u[0] - m.tail[0], 2 * along * u[1] - m.tail[1]]);
  expect(m.hinge.length).toBeGreaterThan(0);
  // the hinge runs from .a through (√2 − 1, 1) on the top edge
  for (const [p, q] of m.hinge) {
    for (const [x, y] of [p, q]) expect(x - (Math.SQRT2 - 1) * y).toBeCloseTo(0, 9);
  }
});

test("the kite draws each step's lines and arrows", async () => {
  const { doc } = renderYr(await scene("kite"));
  const svg = doc.toString();
  const [one, two, three] = ["1", "2", "3"].map((n) => panelSvg(svg, n));
  expect(count(one!, "fold-and-unfold-arrow")).toBe(1);
  expect(count(one!, "valley-line")).toBeGreaterThan(0);
  expect(count(two!, "valley-arrow")).toBe(2);
  expect(count(two!, "existing-crease")).toBeGreaterThan(0);
  const statements = [...two!.matchAll(/data-kind="valley-line" data-statement="(\d+)"/g)].map((m) => m[1]);
  expect(new Set(statements)).toEqual(new Set(["1", "2"]));
  expect(count(three!, "valley-arrow") + count(three!, "valley-line")).toBe(0);
  expect(one).toContain("Fold in half along the diagonal and unfold.");
  expect(two).toContain("Fold both lower edges to the center line.");
  expect(three).toContain("The kite base.");
});

test("@orient .a .c up puts .a at the bottom of every panel", async () => {
  const s = await scene("kite");
  for (const p of panels(s).panels) {
    const { px } = panelView(s, p);
    const a = px([0, 0]), c = px([1, 1]);
    expect(a[0]).toBeCloseTo(c[0], 6);
    expect(a[1]).toBeGreaterThan(c[1]);
  }
});

test("a group whose second fold folds paper the first moved splits into 1a and 1b", async () => {
  const { panels: ps, hints } = panels(await scene("book-twice"));
  expect(ps.map((p) => p.number)).toEqual(["1a", "1b", "2"]);
  const text = "Fold in half, then in half again.";
  // the step's sentence covers both folds, so it stands once
  expect(ps.map((p) => p.text)).toEqual([text, null, null]);
  expect(ps.map((p) => p.base)).toEqual([0, 1, 2]);
  expect(hints).toHaveLength(1);
  expect(hints[0]).toContain("1a and 1b");
  expect(hints[0]).toContain("@say");
});

test("a split step's parts take the sentences of their own folds", async () => {
  const { panels: ps } = panels(await scene("book-twice-said"));
  expect(ps.map((p) => p.text)).toEqual(["Fold in half.", "Fold in half again.", null]);
});

test("a fold that lays the moving paper on top is a valley fold", async () => {
  const s = await scene("kite");
  const m = foldMotion(s, s.statements[1]!);
  expect(m.kind).toBe("valley");
  expect(m.reverse).toBeNull();
});

// The fixtures fold the kite base in half along --ac, a narrow flap with its
// tip at .a and the folded edge on --ac, and reverse the tip along a crease
// from (1/4, 1/4) on the folded edge to the open edges.
test("a fold that tucks the tip between the layers is an inside reverse fold", async () => {
  const s = await scene("inside-reverse");
  const m = foldMotion(s, s.writes.at(-1)!);
  expect(m.kind).toBe("inside-reverse");
  // the crease x = 1/4 reflects the tip .a onto (1/2, 0)
  near(m.tail, [0, 0]);
  near(m.head, [0.5, 0]);
  const r = m.reverse!;
  near(r.at, [0.25, 0.25]);
  near(r.open, [0.25, (Math.SQRT2 - 1) / 4]);
  // the folded edge is the fold along --ac, its end at the tip second
  for (const [x, y] of r.edge) expect(x).toBeCloseTo(y, 9);
  near(r.edge[1], [0, 0]);
  expect(r.near.length).toBeGreaterThan(0);
  for (const [p, q] of r.near) for (const [x] of [p, q]) expect(x).toBeCloseTo(0.25, 9);
  // the layers of the tip lie on each other, so nothing of the far one shows
  expect(r.far).toEqual([]);
});

test("a fold that wraps the tip around the layers is an outside reverse fold", async () => {
  const s = await scene("outside-reverse");
  const m = foldMotion(s, s.writes.at(-1)!);
  expect(m.kind).toBe("outside-reverse");
  near(m.reverse!.at, [0.25, 0.25]);
  near(m.reverse!.edge[1], [0, 0]);
  near(m.tail, [0, 0]);
});

// The drawn reverse fold of a fixture: its panel's svg, and the ends of the
// crease line on the near layer, the one at the folded edge first. Both
// fixtures turn the folded edge up the page, so that end lies nearer the tip
// of the push arrow across the page.
async function reversePanel(name: string, line: string) {
  const s = await scene(name);
  const panel = panels(s).panels.find((p) => p.writes.some((w) => w.index === s.writes.at(-1)!.index))!;
  const svg = panelSvg(renderYr(s).doc.toString(), panel.number);
  const [x1, y1, x2, y2] = svg.match(new RegExp(`data-kind="${line}" data-statement="\\d+" x1="([\\d.-]+)" y1="([\\d.-]+)" x2="([\\d.-]+)" y2="([\\d.-]+)"`))!.slice(1).map(Number);
  const push = svg.match(/data-kind="push-arrow" points="(-?[\d.]+),(-?[\d.]+)/)!.slice(1).map(Number) as Vec2;
  const ends: Vec2[] = [[x1!, y1!], [x2!, y2!]];
  const d = (p: Vec2) => Math.abs(p[0] - push[0]);
  const [at, open] = d(ends[0]!) < d(ends[1]!) ? ends : [ends[1]!, ends[0]!];
  return { svg, at: at!, open: open!, push };
}
// The points of every stem path of the arrow of kind `kind`.
const pathPoints = (svg: string, kind: string): Vec2[] => {
  const group = svg.slice(svg.indexOf(`data-kind="${kind}"`)).split("</g>")[0]!;
  return [...group.matchAll(/<path d="([^"]+)"/g)].flatMap((d) =>
    [...d[1]!.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)].map((m): Vec2 => [Number(m[1]), Number(m[2])]));
};

test("an inside reverse fold draws a mountain line, a valley line beyond the edge, a push arrow and a valley arrow", async () => {
  const { svg, at, open, push } = await reversePanel("inside-reverse", "mountain-line");
  expect(count(svg, "mountain-line")).toBeGreaterThan(0);
  expect(count(svg, "valley-line")).toBeGreaterThan(0);
  expect(count(svg, "push-arrow")).toBe(1);
  expect(count(svg, "valley-arrow")).toBe(1);
  expect(count(svg, "mountain-arrow")).toBe(0);
  // the push arrow comes from the side away from the open edges; the arrow of
  // motion bends away from the crease
  expect(Math.sign(push[0] - at[0])).toBe(-Math.sign(open[0] - at[0]));
  const [tail, control, tip] = pathPoints(svg, "valley-arrow");
  const side = (p: Vec2) => Math.sign((tip![0] - tail![0]) * (p[1] - tail![1]) - (tip![1] - tail![1]) * (p[0] - tail![0]));
  expect(side(control!)).toBe(-side([(at[0] + open[0]) / 2, (at[1] + open[1]) / 2]));
});

test("an outside reverse fold draws a push arrow and two arrows that wrap around the flap", async () => {
  const { svg, at, open } = await reversePanel("outside-reverse", "valley-line");
  expect(count(svg, "valley-line")).toBeGreaterThan(0);
  expect(count(svg, "push-arrow")).toBe(1);
  expect(count(svg, "valley-arrow")).toBe(1);
  expect(count(svg, "mountain-arrow")).toBe(1);
  // each loop reaches beyond the open edges and beyond the folded edge
  const [lo, hi] = [Math.min(at[0], open[0]), Math.max(at[0], open[0])];
  for (const kind of ["valley-arrow", "mountain-arrow"]) {
    const xs = pathPoints(svg, kind).map((p) => p[0]);
    expect(Math.min(...xs)).toBeLessThan(lo);
    expect(Math.max(...xs)).toBeGreaterThan(hi);
  }
});

// The drawings beside the programs are what the pull request shows; this
// keeps them equal to what the library draws. To write them again:
//   for f in kite book-twice rotate shrink inside-reverse outside-reverse mountain top-layer turn-over; do bun cli/bin/fold2svg.ts yr/test/fixtures/$f.fold yr/test/fixtures/$f-yr.svg --view yr; done
test("the committed drawings are the library's output", async () => {
  for (const name of ["kite", "book-twice", "rotate", "shrink", "inside-reverse", "outside-reverse", "mountain", "top-layer", "turn-over"]) {
    const drawn = renderYr(await scene(name)).doc.toString();
    const committed = await Bun.file(new URL(`./fixtures/${name}-yr.svg`, import.meta.url)).text();
    expect(drawn).toBe(committed);
  }
});

test("a quarter turn clockwise between two panels is Shall's symbol with 1/4", async () => {
  const svg = renderYr(await scene("rotate")).doc.toString();
  const symbols = [...svg.matchAll(/data-kind="rotation" data-turn="([^"]+)" data-direction="([^"]+)"/g)];
  expect(symbols.map((m) => [m[1], m[2]])).toEqual([["1/4", "clockwise"]]);
  // between the first panel and the second
  const at = svg.indexOf('data-kind="rotation"');
  expect(svg.indexOf('data-panel="1"')).toBeLessThan(at);
  expect(at).toBeLessThan(svg.indexOf('data-panel="2"'));
});

test("an orient in force from the first panel on draws no rotation symbol", async () => {
  expect(renderYr(await scene("kite")).doc.toString()).not.toContain('data-kind="rotation"');
});

test("a turn is the nearest fraction with a denominator of at most 24", () => {
  expect(turnFraction(-Math.PI / 2)).toEqual({ num: 1, den: 4, clockwise: true });
  expect(turnFraction(Math.PI / 4)).toEqual({ num: 1, den: 8, clockwise: false });
  expect(turnFraction(Math.PI)).toEqual({ num: 1, den: 2, clockwise: false });
  expect(turnFraction((-3 * Math.PI) / 4)).toEqual({ num: 3, den: 8, clockwise: true });
  expect(turnFraction(Math.PI / 8)).toEqual({ num: 1, den: 16, clockwise: false });
});

test("the scale doubles once the model is less than half its size on the first panel", async () => {
  const s = await scene("shrink");
  const ps = panels(s).panels;
  // diameters 1.41, 1.12, 0.71 (exactly half: no change), 0.56, 0.35
  const h = panelHalves(s, ps);
  [0.5, 0.5, 0.5, 0.25, 0.25].forEach((x, i) => expect(h[i]).toBeCloseTo(x, 9));
});

test("the kite keeps one scale", async () => {
  const s = await scene("kite");
  const h = panelHalves(s, panels(s).panels);
  for (const x of h) expect(x).toBeCloseTo(Math.SQRT1_2, 9);
});

// The end points of the existing creases of a panel, in page pixels.
const creaseEnds = (svg: string): number[][] =>
  [...svg.matchAll(/data-kind="existing-crease" x1="([^"]+)" y1="([^"]+)" x2="([^"]+)" y2="([^"]+)"/g)]
    .map((m) => m.slice(1, 5).map(Number));

test("an existing crease ends short of the edges it ends on", async () => {
  const two = panelSvg(renderYr(await scene("kite")).doc.toString(), "2");
  // the diagonal runs from corner to corner, 56 to 516 on the page
  const [[x1, y1, x2, y2]] = creaseEnds(two) as [number[]];
  expect(x1).toBeCloseTo(286, 2);
  expect(x2).toBeCloseTo(286, 2);
  const ys = [y1!, y2!].sort((a, b) => a - b);
  expect(ys[0]).toBeCloseTo(56 + CREASE_GAP, 2);
  expect(ys[1]).toBeCloseTo(516 - CREASE_GAP, 2);
});

test("an existing crease touches the edge it runs under", async () => {
  const three = panelSvg(renderYr(await scene("kite")).doc.toString(), "3");
  // the diagonal shows from the top corner down to the edges of the two flaps
  const ends = creaseEnds(three);
  expect(ends).toHaveLength(1);
  const [, y1, , y2] = ends[0]!;
  const ys = [y1!, y2!].sort((a, b) => a - b);
  expect(ys[0]).toBeCloseTo(56 + CREASE_GAP, 2);
  expect(ys[1]).toBeCloseTo(190.73, 2);
  // the renderer under the panel draws no crease of its own
  expect(three).not.toMatch(/class="crease-F"[^>]*opacity="0.55"/);
});

test("a fold that lays its paper under the paper that stays is a mountain fold", async () => {
  const s = await scene("mountain");
  const m = foldMotion(s, s.statements[0]!);
  expect(m.kind).toBe("mountain");
  expect(m.hooked).toBe(false);
  // the arrow runs from the centroid of the upper half to its top edge
  near(m.tail, [0.5, 0.75]);
  near(m.edge, [0.5, 1]);
  const one = panelSvg(renderYr(s).doc.toString(), "1");
  expect(count(one, "mountain-line")).toBeGreaterThan(0);
  expect(count(one, "mountain-arrow")).toBe(1);
  expect(count(one, "valley-line") + count(one, "valley-arrow")).toBe(0);
});

test("a fold of the top layer of a stack hooks the tail of its arrow", async () => {
  const s = await scene("top-layer");
  const [first, second] = [0, 1].map((i) => foldMotion(s, s.writes[i]!));
  expect(first!.kind).toBe("valley");
  expect(first!.hooked).toBe(false);
  expect(second!.kind).toBe("valley");
  expect(second!.hooked).toBe(true);
  // the hook wraps the top layer's upper edge, which lands on the middle line
  near(second!.edge, [0.5, 1]);
  near(second!.edgeHead, [0.5, 0.5]);
  const svg = renderYr(s).doc.toString();
  expect(count(panelSvg(svg, "1"), "hook")).toBe(0);
  expect(count(panelSvg(svg, "2"), "hook")).toBe(1);
  expect(count(panelSvg(svg, "2"), "valley-arrow")).toBe(1);
});

test("a flip turns the model over from side to side", async () => {
  const s = await scene("turn-over");
  const flip = s.writes[1]!;
  expect(turnOver(s, flip)).toEqual({ statement: flip.index, before: 1, after: 2, axis: expect.any(Array) });
  expect(() => foldMotion(s, flip)).toThrow();
  const { panels: ps, hints } = panels(s);
  // the flip takes a panel of its own, on the state the fold leaves; that
  // split is the rule and earns no hint
  expect(ps.map((p) => p.number)).toEqual(["1a", "1b", "2", "3"]);
  expect(ps.map((p) => p.writes.map((w) => w.index))).toEqual([[0], [1], [2], []]);
  expect(ps.map((p) => p.base)).toEqual([0, 1, 2, 3]);
  expect(ps.map((p) => p.text)).toEqual([
    "Fold in half upward.", "Turn the model over.", "Fold in half from left to right.", "Done.",
  ]);
  expect(hints).toEqual([]);
  const svg = renderYr(s).doc.toString();
  const [fold, turn] = ["1a", "1b"].map((n) => panelSvg(svg, n));
  expect(count(fold!, "valley-arrow")).toBe(1);
  expect(count(fold!, "turn-over-arrow")).toBe(0);
  expect(count(turn!, "valley-arrow") + count(turn!, "valley-line")).toBe(0);
  expect(turn).toContain('data-kind="turn-over-arrow" data-direction="side-to-side"');
  // the panel after the flip shows the other side of every face
  const up = (i: number) => resolveIsometry(s, { kind: "step", index: i }).faceUp;
  expect(up(2).filter((x) => x).length).toBe(up(1).filter((x) => !x).length);
});

test("the turn-over arrow lies across the page for side to side and along it for top to bottom", () => {
  const ink = { ink: "#000", paper: "#fff" };
  const side = turnOverArrow([100, 100], "side-to-side", ink);
  const top = turnOverArrow([100, 100], "top-to-bottom", ink);
  expect(side.attrs["data-direction"]).toBe("side-to-side");
  expect(top.attrs["data-direction"]).toBe("top-to-bottom");
  // the width and height of the points the stem's path passes through
  const span = (n: typeof side) => {
    const d = String(n.children[0]!.attrs["d"]);
    const pts = [...d.matchAll(/(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/g)].map((m) => [Number(m[1]), Number(m[2])]);
    const xs = pts.map((p) => p[0]!), ys = pts.map((p) => p[1]!);
    return [Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)];
  };
  const [sw, sh] = span(side), [tw, th] = span(top);
  expect(sw).toBeGreaterThan(sh!);
  expect(th).toBeGreaterThan(tw!);
});

test("a fold that lays its paper between layers that stay is refused", async () => {
  const s = await scene("between");
  expect(() => foldMotion(s, s.writes[1]!)).toThrow(/between layers/);
  expect(() => renderYr(s)).toThrow(/between layers/);
});

test("a turn-over inside a step is a panel of its own, without a hint", async () => {
  const { panels: ps, hints } = panels(await scene("turn-over-split"));
  expect(ps.map((p) => p.number)).toEqual(["1a", "1b", "1c", "2"]);
  expect(ps.map((p) => p.writes.map((w) => w.index))).toEqual([[0], [1], [2], []]);
  expect(hints).toEqual([]);
});
