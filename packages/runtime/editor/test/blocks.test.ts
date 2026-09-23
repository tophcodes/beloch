import { test, expect } from "bun:test";
import { parseFold, type FoldScene } from "@beloch/scene";
import { blockAtLine, blockOfStep, entitiesIn } from "../src/index";

// paper square / --diag / fold as --bd / .m / --slant / fold as --ac
const scene: FoldScene = parseFold(
  await Bun.file(
    new URL("../../render-dom/test/fixtures/constructions.fold", import.meta.url),
  ).text(),
);

test("step 0 stands for the source above the first statement", () => {
  expect(blockOfStep(scene, 0)).toEqual({ statement: -1, fromLine: 1, toLine: 2 });
});

test("a step stands for its own line and what follows it", () => {
  expect(blockOfStep(scene, 1)).toEqual({ statement: 0, fromLine: 3, toLine: 5 });
});

test("the last step runs to the end of the program", () => {
  expect(blockOfStep(scene, 2)).toEqual({ statement: 1, fromLine: 6, toLine: null });
});

test("a line lands in the block it sits in", () => {
  expect(blockAtLine(scene, 1).statement).toBe(-1);
  expect(blockAtLine(scene, 2).statement).toBe(-1);
  expect(blockAtLine(scene, 3).statement).toBe(0);
  expect(blockAtLine(scene, 5).statement).toBe(0);
  expect(blockAtLine(scene, 6).statement).toBe(1);
  expect(blockAtLine(scene, 99).statement).toBe(1);
});

test("the leading block names the paper's corners and the line drawn on it", () => {
  const found = entitiesIn(scene, blockOfStep(scene, 0));
  expect(found.points.sort()).toEqual(["a", "b", "c", "d"]);
  expect(found.lines).toEqual(["diag"]);
  expect(found.creases).toEqual([]);
});

test("a fold's block names the crease it made and what was declared under it", () => {
  const found = entitiesIn(scene, blockOfStep(scene, 1));
  expect(found.points).toEqual(["m"]);
  expect(found.lines.sort()).toEqual(["bd", "slant"]);
  // The crease this statement scored, by its bundle id.
  expect(found.creases.length).toBe(1);
});

test("the crease of a block is the one whose span sits in it", () => {
  const first = entitiesIn(scene, blockOfStep(scene, 1)).creases;
  const second = entitiesIn(scene, blockOfStep(scene, 2)).creases;
  expect(first).not.toEqual(second);
  expect(second.length).toBe(1);
});

// A mark draws against one frame and leaves the counter elsewhere, so a named
// line in such a program cannot be placed in a block from its frame alone.
const withMarks: FoldScene = parseFold(
  await Bun.file(
    new URL(
      "../../../render-2d/render-svg/test/fixtures/mark-overlay-regression.fold",
      import.meta.url,
    ),
  ).text(),
);

test("a program with a mark places no construction line in a block", () => {
  expect(withMarks.namedLines.length).toBeGreaterThan(0);
  for (let step = 0; step <= withMarks.statements.length; step++) {
    expect(entitiesIn(withMarks, blockOfStep(withMarks, step)).lines).toEqual([]);
  }
});

// The same document was written before named points carried the statement
// they were declared under, which is the other way a block can come up empty.
test("a point with no statement recorded stays out of every block", () => {
  expect(withMarks.namedPoints.every((p) => p.statement === null)).toBe(true);
  const blocks = [0, 1, 2, 3].map((step) => entitiesIn(withMarks, blockOfStep(withMarks, step)));
  expect(blocks.every((b) => b.points.length === 0)).toBe(true);
});
