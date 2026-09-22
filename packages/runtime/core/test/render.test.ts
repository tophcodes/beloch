import { test, expect } from "bun:test";
import { createRuntime, renderCommand, initialState } from "../src/index";

const folded = { view: "folded", hidden: "hide" } as const;
import { sceneOf, statement } from "./scene-fixture";

test("the folded view draws the frame the current statement folds against", () => {
  const rt = createRuntime();
  rt.dispatch({
    type: "document/set",
    scene: sceneOf([statement(0, { frameIndex: 1 }), statement(1, { frameIndex: 4 })]),
  });
  expect(renderCommand(rt.state, folded)).toEqual({
    kind: "folded",
    frame: 4,
    hidden: "hide",
    marks: [],
    newestCreaseId: null,
    highlight: [],
  });
});

test("the flat sheet is frame zero, before any statement", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0, { frameIndex: 1 })]) });
  rt.dispatch({ type: "step/to", index: 0 });
  expect(renderCommand(rt.state, folded)).toEqual({
    kind: "folded",
    frame: 0,
    hidden: "hide",
    marks: [],
    newestCreaseId: null,
    highlight: [],
  });
});

test("a scene with no statements has one drawing, the crease pattern", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([]) });
  expect(renderCommand(rt.state, folded)).toEqual({ kind: "cp-only", highlight: [] });
});

test("without a document there is nothing to draw", () => {
  expect(renderCommand(initialState, folded)).toBeNull();
});
