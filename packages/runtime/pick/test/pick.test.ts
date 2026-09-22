import { test, expect } from "bun:test";
import { createRuntime, type EntityRef } from "@beloch/runtime";
import { createPick } from "../src/index";
import { sceneOf, statement } from "../../core/test/scene-fixture";

const crease = (id: string): EntityRef => ({ kind: "crease", creaseId: id });
const edge = (name: string): EntityRef => ({ kind: "edge", name });

const withDocument = () => {
  const runtime = createRuntime();
  runtime.dispatch({ type: "document/set", scene: sceneOf([statement(0)]) });
  return { runtime, pick: createPick(runtime) };
};

test("one entity under the pointer settles it", () => {
  const { runtime, pick } = withDocument();
  const outcome = pick.report([crease("3")], "settle");
  expect(outcome).toEqual({ kind: "one", entity: crease("3") });
  expect(runtime.state.selection).toEqual([crease("3")]);
  expect(pick.state.open).toBe(false);
});

test("two entities at one point open the choice with both of them", () => {
  const { runtime, pick } = withDocument();
  const outcome = pick.report([crease("3"), edge("ab")], "settle");
  expect(outcome).toEqual({ kind: "several", candidates: [crease("3"), edge("ab")] });
  expect(pick.state.open).toBe(true);
  expect(pick.state.candidates).toEqual([crease("3"), edge("ab")]);
  // Nothing is settled while the reader is being asked.
  expect(runtime.state.selection).toEqual([]);
});

test("choosing a candidate settles it and closes the choice", () => {
  const { runtime, pick } = withDocument();
  pick.report([crease("3"), edge("ab")], "settle");
  expect(pick.choose(1)).toEqual(edge("ab"));
  expect(runtime.state.selection).toEqual([edge("ab")]);
  expect(pick.state.open).toBe(false);
  expect(pick.state.candidates).toEqual([]);
});

test("choosing a candidate that is not offered settles nothing", () => {
  const { runtime, pick } = withDocument();
  pick.report([crease("3"), edge("ab")], "settle");
  expect(pick.choose(7)).toBeNull();
  expect(runtime.state.selection).toEqual([]);
  expect(pick.state.open).toBe(true);
});

test("a report with nothing in it leaves the selection alone", () => {
  const { runtime, pick } = withDocument();
  pick.report([crease("3")], "settle");
  const outcome = pick.report([], "settle");
  expect(outcome).toEqual({ kind: "none" });
  expect(runtime.state.selection).toEqual([crease("3")]);
});

test("a report with nothing in it leaves an open choice standing", () => {
  const { pick } = withDocument();
  pick.report([crease("3"), edge("ab")], "settle");
  pick.report([], "settle");
  expect(pick.state.open).toBe(true);
  expect(pick.state.candidates).toEqual([crease("3"), edge("ab")]);
});

test("a hover over several entities offers them without asking", () => {
  const { runtime, pick } = withDocument();
  const outcome = pick.report([crease("3"), edge("ab")], "hover");
  expect(outcome).toEqual({ kind: "several", candidates: [crease("3"), edge("ab")] });
  // The candidates are known, so a preview can light them, but the reader has
  // not been asked and nothing is settled.
  expect(pick.state.candidates).toEqual([crease("3"), edge("ab")]);
  expect(pick.state.open).toBe(false);
  expect(runtime.state.selection).toEqual([]);
});

test("a hover over one entity settles nothing", () => {
  const { runtime, pick } = withDocument();
  const outcome = pick.report([crease("3")], "hover");
  expect(outcome).toEqual({ kind: "one", entity: crease("3") });
  expect(runtime.state.selection).toEqual([]);
});

test("a report over one entity forgets the candidates a report before it offered", () => {
  const { pick } = withDocument();
  pick.report([crease("3"), edge("ab")], "hover");
  pick.report([crease("3")], "hover");
  expect(pick.state.candidates).toEqual([]);
});

test("closing the choice forgets the candidates and leaves the selection alone", () => {
  const { runtime, pick } = withDocument();
  pick.report([crease("3")], "settle");
  pick.report([crease("3"), edge("ab")], "hover");
  pick.close();
  expect(pick.state.candidates).toEqual([]);
  expect(pick.state.open).toBe(false);
  expect(runtime.state.selection).toEqual([crease("3")]);
});

test("a new document closes an open choice", () => {
  const { runtime, pick } = withDocument();
  pick.report([crease("3"), edge("ab")], "settle");
  runtime.dispatch({ type: "document/set", scene: sceneOf([statement(0)]) });
  expect(pick.state.open).toBe(false);
  expect(pick.state.candidates).toEqual([]);
});

test("the entities a report offers are the candidates, in the order it gave them", () => {
  const { pick } = withDocument();
  pick.report([edge("ab"), crease("3")], "settle");
  expect(pick.state.candidates).toEqual([edge("ab"), crease("3")]);
});
