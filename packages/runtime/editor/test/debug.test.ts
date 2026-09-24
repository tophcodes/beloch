import { test, expect } from "bun:test";
import { parseFold, type FoldScene } from "@beloch/scene";
import { debugTargets } from "../src/index";

// bindings.bel, beside the fixture: two marks that bind `--ac` and `--bd`, a
// construction line `--vert` that never becomes a crease, the point `.mid`
// where the two marks meet, and two folds.
const scene: FoldScene = parseFold(
  await Bun.file(new URL("./fixtures/bindings.fold", import.meta.url)).text(),
);

const source = (await Bun.file(
  new URL("./fixtures/bindings.bel", import.meta.url),
).text()).split("\n");

// What a host does to place a box: take the statement's text and find the name
// in it. A statement that does not spell the name it binds gets no box.
const spanText = (target: ReturnType<typeof debugTargets>[number]): string =>
  source[target.span.fromLine - 1]!.slice(target.span.fromCol - 1, target.span.toCol - 1);
const boxable = (target: ReturnType<typeof debugTargets>[number]): boolean =>
  target.spelling === null || spanText(target).includes(target.spelling);

const targets = debugTargets(scene);
const boxes = targets.filter(boxable);

test("every binding the program makes is offered as a target", () => {
  expect(targets.map((t) => t.spelling)).toEqual([
    // line 2 and 3: the marks bind `--ac` and `--bd`, so their creases are
    // targets under those names rather than under the statement.
    "--ac", "--bd",
    // line 4 and 5: the construction line and the point.
    "--vert", ".mid",
    // line 6 and 7: the folds bind no name, so each statement is its own target.
    null, null,
  ]);
});

test("a construction line that never becomes a crease is named by its name", () => {
  const vert = targets.find((t) => t.spelling === "--vert");
  expect(vert!.entity).toEqual({ kind: "construction", name: "vert" });
  expect(spanText(vert!)).toBe("--vert = (map .a onto .b)");
});

test("a named line the paper carries is named by its crease", () => {
  const ac = targets.find((t) => t.spelling === "--ac");
  expect(ac!.entity).toEqual({ kind: "crease", creaseId: "0" });
});

test("a named point is named by the vertex it sits on", () => {
  const mid = targets.find((t) => t.spelling === ".mid");
  expect(mid!.entity).toEqual({ kind: "vertex", index: 3, name: "mid" });
  expect(spanText(mid!)).toBe(".mid = --ac * --bd");
});

test("a write that bound no name is a target for the crease it scored", () => {
  const folds = targets.filter((t) => t.spelling === null);
  expect(folds.map((t) => t.entity)).toEqual([
    { kind: "crease", creaseId: "2" },
    { kind: "crease", creaseId: "3" },
  ]);
  // The whole statement, which is all the source says about that crease.
  expect(folds[0]!.span).toEqual({ fromLine: 6, fromCol: 1, toLine: 6, toCol: 26 });
});

test("a write that bound a name is a target once, under the name", () => {
  const ids = targets.map((t) => (t.entity.kind === "crease" ? t.entity.creaseId : null));
  // Crease 0 is `--ac`, scored by the mark on line 2: one target, not two.
  expect(ids.filter((id) => id === "0")).toEqual(["0"]);
});

test("a name the statement spells is where its box goes", () => {
  // `mark (through .a .c) as --ac` spells the name at its end, so the box sits
  // there rather than over the whole statement.
  expect(boxes.map((t) => t.spelling)).toEqual(targets.map((t) => t.spelling));
  expect(spanText(targets[0]!).indexOf("--ac")).toBe(24);
});

test("a span that binds nothing is offered to nobody", () => {
  // `paper square` on line 1 binds no name and scores nothing.
  expect(targets.some((t) => t.span.fromLine === 1)).toBe(false);
});

// What the stepper marks in the editor: the line of the statement the drawing
// stands at, which is the write's own line at every step, the mark included.
test("a step stands for the line of its own statement", () => {
  expect(scene.writes.map((w) => w.sourceLine)).toEqual([2, 3, 6, 7]);
  expect(scene.writes.map((w) => w.kind)).toEqual(["mark", "mark", "fold", "fold"]);
});
