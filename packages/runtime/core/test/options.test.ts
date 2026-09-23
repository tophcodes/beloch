import { test, expect } from "bun:test";
import { createRuntime, renderCommand, type EntityRef } from "../src/index";
import { sceneOf, statement } from "./scene-fixture";

const crease = (id: string): EntityRef => ({ kind: "crease", creaseId: id });
const folded = { view: "folded", hidden: "hide" } as const;
const cp = { view: "cp", hidden: "hide" } as const;

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
  expect(renderCommand(rt.state, { view: "folded", hidden: "dashed" })).toMatchObject({
    kind: "folded",
    hidden: "dashed",
  });
});

test("the crease-pattern view draws the sheet scored up to the current statement", () => {
  const rt = withDocument();
  expect(renderCommand(rt.state, cp)).toMatchObject({ kind: "flat", upToStatement: 1 });
});

test("the crease-pattern view at step zero has nothing scored yet", () => {
  const rt = withDocument();
  rt.dispatch({ type: "step/to", index: 0 });
  expect(renderCommand(rt.state, cp)).toMatchObject({ kind: "flat", upToStatement: -1 });
});

// The <Beloch> card draws both views of one state side by side, so one state
// has to answer two drawing requests without being changed in between.
test("one state answers both views at once", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3")] });
  const left = renderCommand(rt.state, cp);
  const right = renderCommand(rt.state, folded);
  expect(left).toMatchObject({ kind: "flat", upToStatement: 1 });
  expect(right).toMatchObject({ kind: "folded", frame: 2 });
  expect(left?.highlight).toEqual([crease("3")]);
  expect(right?.highlight).toEqual([crease("3")]);
});
