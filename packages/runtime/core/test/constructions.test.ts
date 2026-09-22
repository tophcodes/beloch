import { test, expect } from "bun:test";
import { createRuntime, renderCommand, type RenderOptions } from "../src/index";
import { namedLine, sceneOf, statement } from "./scene-fixture";

const folded: RenderOptions = { view: "folded", hidden: "hide" };
const cp: RenderOptions = { view: "cp", hidden: "hide" };

// Two folds, and a line named before each of them.
const withLines = () =>
  sceneOf(
    [statement(0, { frameIndex: 1 }), statement(1, { frameIndex: 2 })],
    [namedLine("diag", 0), namedLine("slant", 1), namedLine("late", 2)],
  );

const at = (step: number, options = folded) => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: withLines() });
  rt.dispatch({ type: "step/to", index: step });
  return renderCommand(rt.state, options)!.constructions;
};

test("the sheet before any statement carries the lines named before it", () => {
  expect(at(0)).toEqual(["diag"]);
});

test("a step carries every line named up to the frame it folds against", () => {
  expect(at(1)).toEqual(["diag", "slant"]);
  expect(at(2)).toEqual(["diag", "slant", "late"]);
});

test("both views of one step name the same constructions", () => {
  expect(at(1, cp)).toEqual(at(1, folded));
});

test("a program with no timeline carries every construction it named", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([], [namedLine("diag", 0)]) });
  expect(renderCommand(rt.state, folded)?.constructions).toEqual(["diag"]);
});
