import { test, expect } from "bun:test";
import { createRuntime, renderCommand, type State } from "../src/index";

const folded = { view: "folded", hidden: "hide" } as const;
import { sceneOf, statement } from "./scene-fixture";

test("a listener hears the state after a dispatch", () => {
  const rt = createRuntime();
  const heard: { step: number; kind: string | null }[] = [];
  rt.subscribe((state: State) =>
    heard.push({ step: state.step, kind: renderCommand(state, folded)?.kind ?? null }),
  );
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0), statement(1)]) });
  rt.dispatch({ type: "step/to", index: 0 });
  expect(heard).toEqual([
    { step: 2, kind: "folded" },
    { step: 0, kind: "folded" },
  ]);
});

test("several listeners all hear the same dispatch", () => {
  const rt = createRuntime();
  let a = 0;
  let b = 0;
  rt.subscribe(() => a++);
  rt.subscribe(() => b++);
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0)]) });
  expect([a, b]).toEqual([1, 1]);
});

test("unsubscribing stops the calls", () => {
  const rt = createRuntime();
  let calls = 0;
  const stop = rt.subscribe(() => calls++);
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0)]) });
  stop();
  rt.dispatch({ type: "step/to", index: 0 });
  expect(calls).toBe(1);
});

test("a listener subscribing during a dispatch does not hear that one", () => {
  const rt = createRuntime();
  const heard: number[] = [];
  rt.subscribe(() => {
    rt.subscribe(() => heard.push(2));
    heard.push(1);
  });
  rt.dispatch({ type: "document/set", scene: sceneOf([statement(0)]) });
  expect(heard).toEqual([1]);
});
