import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import type { Vec2 } from "@beloch/scene";
import { CREASE_GAP, foldMotion, panelHalves, panels, panelView, renderYr, turnFraction } from "@beloch/yr";

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

test("a fold's arrow runs from the moving corner to where it lands", async () => {
  const s = await scene("kite");
  const m = foldMotion(s, s.statements[1]!);
  expect(m.before).toBe(0);
  expect(m.after).toBe(1);
  // fold (map --da onto --ac) carries .d onto the diagonal
  near(m.tail, [0, 1]);
  near(m.head, [Math.SQRT1_2, Math.SQRT1_2]);
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

// The drawings beside the programs are what the pull request shows; this
// keeps them equal to what the library draws. To write them again:
//   for f in kite book-twice rotate shrink; do bun cli/bin/fold2svg.ts yr/test/fixtures/$f.fold yr/test/fixtures/$f-yr.svg --view yr; done
test("the committed drawings are the library's output", async () => {
  for (const name of ["kite", "book-twice", "rotate", "shrink"]) {
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
