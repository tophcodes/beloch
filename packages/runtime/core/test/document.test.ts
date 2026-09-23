import { test, expect } from "bun:test";
import { createRuntime } from "../src/index";
import { sceneOf, statement } from "./scene-fixture";

test("setting a document steps to the last statement", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0), statement(1), statement(2)]) });
  expect(rt.state.step).toBe(3);
});

test("a step past the last statement clamps to it", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0), statement(1)]) });
  rt.dispatch({ type: "step/to", index: 9 });
  expect(rt.state.step).toBe(2);
});

test("a negative step clamps to the flat sheet", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0), statement(1)]) });
  rt.dispatch({ type: "step/to", index: -3 });
  expect(rt.state.step).toBe(0);
});

test("a step arriving without a document is ignored", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "step/to", index: 4 });
  expect(rt.state.step).toBe(0);
});

test("emptying the slot takes the step and the selection with it", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0), statement(1)]) });
  rt.dispatch({ type: "selection/set", entities: [{ kind: "crease", creaseId: "3" }] });
  rt.dispatch({ type: "document/set", scene: null });
  expect(rt.state.scene).toBeNull();
  expect(rt.state.step).toBe(0);
  expect(rt.state.selection).toEqual([]);
});

test("emptying an already empty slot is no news", () => {
  const rt = createRuntime();
  let told = 0;
  rt.subscribe(() => told++);
  rt.dispatch({ type: "document/set", scene: null });
  expect(told).toBe(0);
});
