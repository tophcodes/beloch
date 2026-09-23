// The invariants the playground used to keep by hand at every call site, as
// the sequences that break them. Each one drives the whole interaction rather
// than a single event, because what these guard is what survives the event
// after next.
import { test, expect } from "bun:test";
import { createRuntime, renderCommand, type EntityRef, type RenderOptions } from "../src/index";
import { sceneOf, statement } from "./scene-fixture";

const folded: RenderOptions = { view: "folded", hidden: "hide" };
const crease = (id: string): EntityRef => ({ kind: "crease", creaseId: id });

const program = () => sceneOf([statement(0), statement(1), statement(2)]);

const started = () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene: program() });
  return rt;
};

test("a pin outlives the hover that moves on", () => {
  const rt = started();
  rt.dispatch({ type: "hover/set", entity: crease("1") });
  rt.dispatch({ type: "selection/set", entities: [crease("1")] });
  rt.dispatch({ type: "hover/set", entity: crease("2") });
  // The pointer is over another crease and the state says so, but the answer
  // the reader settled on is what the drawing shows.
  expect(rt.state.hover).toEqual(crease("2"));
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("1")]);
  expect(renderCommand(rt.state, folded)?.settled).toBe(true);
});

test("a pin survives a step change and still names what it named", () => {
  const rt = started();
  rt.dispatch({ type: "selection/set", entities: [crease("1")] });
  rt.dispatch({ type: "step/to", index: 1 });
  rt.dispatch({ type: "step/to", index: 2 });
  const command = renderCommand(rt.state, folded);
  expect(command?.kind === "folded" && command.frame).toBe(2);
  expect(command?.highlight).toEqual([crease("1")]);
});

test("a step that draws nothing the pin names keeps the pin anyway", () => {
  const rt = started();
  rt.dispatch({ type: "step/to", index: 3 });
  rt.dispatch({ type: "selection/set", entities: [crease("9")] });
  rt.dispatch({ type: "step/to", index: 0 });
  // Whether the drawing has a line for crease 9 at step 0 is the renderer's
  // to see. Clearing the selection here would answer that question in the
  // core, and a step back would not bring the answer back.
  expect(rt.state.selection).toEqual([crease("9")]);
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("9")]);
});

test("toggling the hidden mode redraws and leaves the selection alone", () => {
  const rt = started();
  rt.dispatch({ type: "selection/set", entities: [crease("1")] });
  const before = rt.state;
  const hidden = renderCommand(rt.state, folded);
  const shown = renderCommand(rt.state, { view: "folded", hidden: "depth" });
  expect(hidden?.kind === "folded" && hidden.hidden).toBe("hide");
  expect(shown?.kind === "folded" && shown.hidden).toBe("depth");
  expect(shown?.highlight).toEqual([crease("1")]);
  // Drawing the same state another way is no event at all.
  expect(rt.state).toBe(before);
});

test("a source change empties the document, the step and the pin together", () => {
  const rt = started();
  rt.dispatch({ type: "step/to", index: 2 });
  rt.dispatch({ type: "selection/set", entities: [crease("1")] });
  rt.dispatch({ type: "hover/set", entity: crease("2") });
  rt.dispatch({ type: "document/set", scene: null });
  expect(rt.state).toEqual({ scene: null, step: 0, selection: [], hover: null });
  expect(renderCommand(rt.state, folded)).toBeNull();
});

test("a run that fails leaves the last good document standing", () => {
  const rt = started();
  rt.dispatch({ type: "step/to", index: 1 });
  rt.dispatch({ type: "selection/set", entities: [crease("1")] });
  const good = rt.state;
  // A failure raises no document event: the reader is holding the diagnostic
  // against the drawing that is still there, and keeps pointing at it. The
  // message itself belongs to whoever ran the program (@beloch/runtime-eval).
  rt.dispatch({ type: "hover/set", entity: crease("2") });
  expect(rt.state.scene).toBe(good.scene);
  expect(rt.state.step).toBe(1);
  expect(renderCommand(rt.state, folded)?.highlight).toEqual([crease("1")]);
});

test("a run that succeeds with a new document starts the reader over", () => {
  const rt = started();
  rt.dispatch({ type: "step/to", index: 1 });
  rt.dispatch({ type: "selection/set", entities: [crease("1")] });
  rt.dispatch({ type: "document/set", scene: program() });
  // The entities the old answer named are gone with the document that had
  // them, and the step lands on the end of the new program.
  expect(rt.state.selection).toEqual([]);
  expect(rt.state.hover).toBeNull();
  expect(rt.state.step).toBe(3);
});
