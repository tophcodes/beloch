import { test, expect } from "bun:test";
import { createRuntime, type EntityRef } from "../src/index";
import { sceneOf, statement } from "./scene-fixture";

// An event that changes nothing must leave the state object itself alone, so
// `prev === next` answers "did anything move" for a renderer that diffs, and
// a pointer resting on one crease does not restart a running animation.

const crease = (id: string): EntityRef => ({ kind: "crease", creaseId: id });

const withDocument = () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0), statement(1)]) });
  return rt;
};

test("hovering what is already hovered changes nothing", () => {
  const rt = withDocument();
  rt.dispatch({ type: "hover/set", entity: crease("3") });
  const before = rt.state;
  rt.dispatch({ type: "hover/set", entity: crease("3") });
  expect(rt.state).toBe(before);
});

test("clearing a hover that is already clear changes nothing", () => {
  const rt = withDocument();
  const before = rt.state;
  rt.dispatch({ type: "hover/set", entity: null });
  expect(rt.state).toBe(before);
});

test("stepping to the current step changes nothing", () => {
  const rt = withDocument();
  const before = rt.state;
  rt.dispatch({ type: "step/to", index: 2 });
  expect(rt.state).toBe(before);
});

test("a clamped step that lands where it already is changes nothing", () => {
  const rt = withDocument();
  const before = rt.state;
  rt.dispatch({ type: "step/to", index: 99 });
  expect(rt.state).toBe(before);
});

test("selecting what is already selected changes nothing", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3"), { kind: "edge", name: "ab" }] });
  const before = rt.state;
  rt.dispatch({ type: "selection/set", entities: [crease("3"), { kind: "edge", name: "ab" }] });
  expect(rt.state).toBe(before);
});

test("selecting the same entities in another order is a change", () => {
  const rt = withDocument();
  rt.dispatch({ type: "selection/set", entities: [crease("3"), crease("4")] });
  const before = rt.state;
  rt.dispatch({ type: "selection/set", entities: [crease("4"), crease("3")] });
  expect(rt.state).not.toBe(before);
});

test("setting the same document again changes nothing", () => {
  const rt = createRuntime();
  const scene = sceneOf([statement(0), statement(1)]);
  rt.dispatch({ type: "document/set", scene });
  rt.dispatch({ type: "step/to", index: 0 });
  const before = rt.state;
  rt.dispatch({ type: "document/set", scene });
  expect(rt.state).toBe(before);
});

test("a listener is not called when nothing changed", () => {
  const rt = withDocument();
  rt.dispatch({ type: "hover/set", entity: crease("3") });
  let calls = 0;
  rt.subscribe(() => calls++);
  rt.dispatch({ type: "hover/set", entity: crease("3") });
  expect(calls).toBe(0);
  rt.dispatch({ type: "hover/set", entity: crease("9") });
  expect(calls).toBe(1);
});
