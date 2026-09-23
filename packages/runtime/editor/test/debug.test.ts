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

// What a host does before it draws a box: read the text under the span and
// check it spells the name the target claims.
const spelled = (target: ReturnType<typeof debugTargets>[number]): string =>
  source[target.span.fromLine - 1]!.slice(target.span.fromCol - 1, target.span.toCol - 1);

const targets = debugTargets(scene);
const boxes = targets.filter((t) => t.spelling === null || t.spelling === spelled(t));

test("every binding the program makes is offered as a target", () => {
  expect(targets.map((t) => t.spelling)).toEqual([
    // line 2 and 3: the marks bind `--ac` and `--bd`, and each statement is a
    // write that scored a crease.
    "--ac", null, "--bd", null,
    // line 4 and 5: the construction line and the point.
    "--vert", ".mid",
    // line 6 and 7: the folds, each binding the crease it scored.
    null, null,
  ]);
});

test("a construction line that never becomes a crease is named by its name", () => {
  const vert = targets.find((t) => t.spelling === "--vert");
  expect(vert!.entity).toEqual({ kind: "construction", name: "vert" });
  expect(vert!.span).toEqual({ fromLine: 4, fromCol: 1, toLine: 4, toCol: 7 });
});

test("a named line the paper carries is named by its crease", () => {
  const ac = targets.find((t) => t.spelling === "--ac");
  expect(ac!.entity).toEqual({ kind: "crease", creaseId: "0" });
});

test("a named point is named by the vertex it sits on", () => {
  const mid = targets.find((t) => t.spelling === ".mid");
  expect(mid!.entity).toEqual({ kind: "vertex", index: 3, name: "mid" });
  expect(mid!.span).toEqual({ fromLine: 5, fromCol: 1, toLine: 5, toCol: 5 });
});

test("a write is a target for the crease it scored", () => {
  const folds = targets.filter((t) => t.spelling === null && t.span.fromLine >= 6);
  expect(folds.map((t) => t.entity)).toEqual([
    { kind: "crease", creaseId: "2" },
    { kind: "crease", creaseId: "3" },
  ]);
  // The whole statement, which is what bound the crease.
  expect(folds[0]!.span).toEqual({ fromLine: 6, fromCol: 1, toLine: 6, toCol: 26 });
});

test("a name the statement does not spell is no box", () => {
  // `mark (through .a .c) as --ac` binds `--ac` at its end, and the head of
  // that statement spells `mark`. The write's own target covers the crease.
  expect(boxes.map((t) => t.spelling)).toEqual([null, null, "--vert", ".mid", null, null]);
});

test("a span that binds nothing is offered to nobody", () => {
  // `paper square` on line 1 binds no name and scores nothing.
  expect(targets.some((t) => t.span.fromLine === 1)).toBe(false);
});
