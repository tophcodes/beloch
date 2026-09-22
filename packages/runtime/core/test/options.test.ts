import { test, expect } from "bun:test";
import { createRuntime, type EntityRef } from "../src/index";
import { sceneOf, statement } from "./scene-fixture";

const crease = (id: string): EntityRef => ({ kind: "crease", creaseId: id });

const withDocument = () => {
  const rt = createRuntime();
  rt.dispatch({
    type: "document/set",
    scene: sceneOf([statement(0, { frameIndex: 1 }), statement(1, { frameIndex: 2 })]),
  });
  return rt;
};

test("the hidden mode reaches the folded command", () => {
  const rt = withDocument();
  rt.dispatch({ type: "options/hidden", mode: "dashed" });
  const cmd = rt.render;
  expect(cmd?.kind).toBe("folded");
  expect(cmd).toMatchObject({ hidden: "dashed" });
});

test("the crease-pattern view draws the sheet scored up to the current statement", () => {
  const rt = withDocument();
  rt.dispatch({ type: "options/view", view: "cp" });
  expect(rt.render).toMatchObject({ kind: "flat", upToStatement: 1 });
});

test("the crease-pattern view at step zero has nothing scored yet", () => {
  const rt = withDocument();
  rt.dispatch({ type: "options/view", view: "cp" });
  rt.dispatch({ type: "step/to", index: 0 });
  expect(rt.render).toMatchObject({ kind: "flat", upToStatement: -1 });
});

test("toggling the hidden mode leaves the selection standing", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3")] });
  rt.dispatch({ type: "options/hidden", mode: "depth" });
  expect(rt.render?.highlight).toEqual([crease("3")]);
});

test("a new document keeps the view the reader chose", () => {
  const rt = withDocument();
  rt.dispatch({ type: "options/view", view: "cp" });
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0)]) });
  expect(rt.state.options.view).toBe("cp");
});
