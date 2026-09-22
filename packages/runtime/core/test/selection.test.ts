import { test, expect } from "bun:test";
import { createRuntime, renderCommand, type EntityRef } from "../src/index";

const folded = { view: "folded", hidden: "hide" } as const;
import { sceneOf, statement } from "./scene-fixture";

const crease = (id: string): EntityRef => ({ kind: "crease", creaseId: id });
const edge = (name: string): EntityRef => ({ kind: "edge", name });

const withDocument = () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0)]) });
  return rt;
};

test("a settled selection is what the drawing highlights", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3")] });
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("3")]);
});

test("several entities can be selected at once", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3"), edge("ab")] });
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("3"), edge("ab")]);
});

test("hover highlights while nothing is selected", () => {
  const rt = withDocument();
  rt.dispatch({ type: "hover/set", entity: crease("7") });
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("7")]);
});

test("a settled selection outranks hover", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3")] });
  rt.dispatch({ type: "hover/set", entity: crease("7") });
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("3")]);
});

test("clearing the hover leaves the selection standing", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3")] });
  rt.dispatch({ type: "hover/set", entity: null });
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("3")]);
});

test("a step change leaves the selection standing", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0), statement(1)]) });
  rt.dispatch({ type: "selection/set", entities: [crease("3")] });
  rt.dispatch({ type: "step/to", index: 1 });
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("3")]);
});

test("a new document clears selection and hover", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3")] });
  rt.dispatch({ type: "hover/set", entity: crease("7") });
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0)]) });
  expect(rt.state.selection).toEqual([]);
  expect(rt.state.hover).toBeNull();
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([]);
});

test("the command says whether the highlight is settled or under the pointer", () => {
  const rt = withDocument();
  rt.dispatch({ type: "hover/set", entity: crease("7") });
  expect(renderCommand(rt.state, folded)?.settled).toBe(false);
  rt.dispatch({ type: "selection/set", entities: [crease("3")] });
  expect(renderCommand(rt.state, folded)?.settled).toBe(true);
});
