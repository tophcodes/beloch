import { test, expect } from "bun:test";
import { createRuntime } from "@beloch/runtime";
import { createEvaluator, EVAL_TIMEOUT_MS, LOAD_TIMEOUT_MS } from "../src/index";
import { fakeBackend, fakeScheduler, type Told } from "./harness";

const FOLD = await Bun.file(
  new URL("../../render-dom/test/fixtures/square.fold", import.meta.url),
).text();
const answerWith = (fold: string) => JSON.stringify({ ok: true, fold: JSON.parse(fold) });

const setup = () => {
  const runtime = createRuntime();
  const { backend, spawn } = fakeBackend();
  const clock = fakeScheduler();
  const told: Told = { documents: [], diagnostics: [], states: [] };
  const evaluator = createEvaluator({
    runtime,
    spawn,
    scheduler: clock.scheduler,
    host: {
      document: (scene) => told.documents.push(scene),
      diagnostic: (d) => told.diagnostics.push(d),
      changed: (state) => told.states.push(state),
    },
  });
  return { runtime, backend, clock, told, evaluator };
};

// A run that gets all the way to a document, which every other test cuts
// short somewhere.
const throughToDocument = () => {
  const s = setup();
  s.evaluator.run("paper square");
  s.backend.events().ready();
  s.backend.events().answer(answerWith(FOLD));
  return s;
};

test("the first run boots the evaluator and waits for it", () => {
  const { backend, evaluator } = setup();
  evaluator.run("paper square");
  expect(backend.spawned).toBe(1);
  expect(backend.evaluated).toEqual([]);
  expect(evaluator.state.phase).toBe("loading");
  expect(evaluator.state.running).toBe(true);
});

test("nothing boots before a run asks for it", () => {
  const { backend } = setup();
  expect(backend.spawned).toBe(0);
});

test("a run waiting on the evaluator is dispatched the moment it is ready", () => {
  const { backend, evaluator } = setup();
  evaluator.run("paper square");
  backend.events().ready();
  expect(backend.evaluated).toEqual(["paper square"]);
  expect(evaluator.state.phase).toBe("ready");
});

test("an evaluator booted ahead of any run evaluates nothing when it arrives", () => {
  const { backend, evaluator } = setup();
  // What an eager instance does on mount: pay for the download before the
  // reader asks, so the first run is instant.
  evaluator.boot();
  expect(backend.spawned).toBe(1);
  expect(evaluator.state.running).toBe(false);
  backend.events().ready();
  expect(backend.evaluated).toEqual([]);
  expect(evaluator.state.phase).toBe("ready");
});

test("booting an evaluator that is already there changes nothing", () => {
  const { backend, evaluator } = setup();
  evaluator.boot();
  evaluator.boot();
  expect(backend.spawned).toBe(1);
});

test("a ready evaluator takes the next run straight away", () => {
  const { backend, evaluator } = setup();
  evaluator.run("paper square");
  backend.events().ready();
  backend.events().answer(answerWith(FOLD));
  evaluator.run("paper a5");
  expect(backend.evaluated).toEqual(["paper square", "paper a5"]);
  expect(backend.spawned).toBe(1);
});

test("a run while one is in flight is dropped", () => {
  const { backend, evaluator } = setup();
  evaluator.run("paper square");
  backend.events().ready();
  evaluator.run("paper a5");
  expect(backend.evaluated).toEqual(["paper square"]);
});

test("two runs on the same source are two runs", () => {
  const { backend, evaluator } = setup();
  evaluator.run("paper square");
  backend.events().ready();
  backend.events().answer(answerWith(FOLD));
  evaluator.run("paper square");
  // Re-running unchanged source says nothing about itself, and it is not
  // refused either: the reader pressed Run.
  expect(backend.evaluated).toEqual(["paper square", "paper square"]);
});

test("the share of the transfer that has arrived reaches the state", () => {
  const { evaluator, backend } = setup();
  evaluator.run("paper square");
  backend.events().progress(0.4);
  expect(evaluator.state.progress).toBe(0.4);
  backend.events().progress(null);
  expect(evaluator.state.progress).toBeNull();
});

test("an answer fills the document slot and hands the scene on", () => {
  const { runtime, told, evaluator } = throughToDocument();
  expect(runtime.state.scene).not.toBeNull();
  expect(told.documents).toHaveLength(1);
  expect(runtime.state.scene).toBe(told.documents[0]!);
  expect(told.diagnostics).toEqual([]);
  expect(evaluator.state.running).toBe(false);
});

test("the source of the answered run is what an editor holds its marks against", () => {
  const { evaluator } = throughToDocument();
  expect(evaluator.state.answered).toBe("paper square");
});

test("a rejected program is a diagnostic and leaves the document standing", () => {
  const { runtime, backend, told } = throughToDocument();
  const before = runtime.state.scene;
  told.documents.length = 0;
  backend.events().answer(
    JSON.stringify({ ok: false, message: "unknown point .z", line: 4 }),
  );
  expect(told.diagnostics).toEqual([{ kind: "program", message: "unknown point .z", line: 4 }]);
  expect(runtime.state.scene).toBe(before);
  expect(told.documents).toEqual([]);
});

test("a rejected program without a line is a diagnostic without one", () => {
  const { backend, told } = throughToDocument();
  backend.events().answer(JSON.stringify({ ok: false, message: "no paper declared" }));
  expect(told.diagnostics).toEqual([{ kind: "program", message: "no paper declared", line: null }]);
});

test("a program the browser fragment cannot evaluate says so on its own", () => {
  const { backend, told } = throughToDocument();
  backend.events().answer(JSON.stringify({ ok: false, kind: "native", message: "needs qqbar" }));
  expect(told.diagnostics).toEqual([{ kind: "native" }]);
});

test("an answer that is not an answer is a diagnostic of its own kind", () => {
  const { backend, told } = throughToDocument();
  backend.events().answer("<html>502</html>");
  expect(told.diagnostics[0]?.kind).toBe("protocol");
});

test("a FOLD the scene parser rejects is a diagnostic of its own kind", () => {
  const { backend, told, runtime } = throughToDocument();
  const before = runtime.state.scene;
  backend.events().answer(JSON.stringify({ ok: true, fold: { nonsense: true } }));
  expect(told.diagnostics[0]?.kind).toBe("document");
  expect(runtime.state.scene).toBe(before);
});

test("a backend that fails outright is a diagnostic and ends the run", () => {
  const { backend, told, evaluator } = setup();
  evaluator.run("paper square");
  backend.events().failed("importScripts failed");
  expect(told.diagnostics).toEqual([{ kind: "backend", message: "importScripts failed" }]);
  expect(evaluator.state.running).toBe(false);
});

test("the evaluator taking too long to arrive drops the run and keeps loading", () => {
  const { backend, clock, evaluator, told } = setup();
  evaluator.run("paper square");
  clock.fire(LOAD_TIMEOUT_MS);
  expect(evaluator.state.running).toBe(false);
  expect(evaluator.state.loadStalled).toBe(true);
  // The transfer is never thrown away: pressing Run again picks it up where
  // it stands.
  expect(backend.terminated).toBe(0);
  expect(told.diagnostics).toEqual([]);
  // The dropped run is not resurrected when the evaluator finally arrives.
  backend.events().ready();
  expect(backend.evaluated).toEqual([]);
});

test("a stalled load is forgotten by the next run", () => {
  const { clock, evaluator } = setup();
  evaluator.run("paper square");
  clock.fire(LOAD_TIMEOUT_MS);
  evaluator.run("paper square");
  expect(evaluator.state.loadStalled).toBe(false);
  expect(evaluator.state.running).toBe(true);
});

test("a hung evaluation is cut off and a fresh evaluator started", () => {
  const { backend, clock, evaluator, told } = setup();
  evaluator.run("paper square");
  backend.events().ready();
  clock.fire(EVAL_TIMEOUT_MS);
  expect(told.diagnostics).toEqual([{ kind: "timeout" }]);
  expect(backend.terminated).toBe(1);
  expect(backend.spawned).toBe(2);
  expect(evaluator.state.running).toBe(false);
  // The fresh one re-reads the runtime, so it is loading rather than ready.
  expect(evaluator.state.phase).toBe("loading");
});

test("a timed-out run leaves the source an editor marks against where it was", () => {
  const { backend, clock, evaluator } = throughToDocument();
  evaluator.run("paper a5");
  clock.fire(EVAL_TIMEOUT_MS);
  expect(evaluator.state.answered).toBe("paper square");
  expect(backend.spawned).toBe(2);
});

test("the evaluation limit does not run while the evaluator is still arriving", () => {
  const { clock, evaluator, backend } = setup();
  evaluator.run("paper square");
  expect(clock.waiting()).toEqual([LOAD_TIMEOUT_MS]);
  backend.events().ready();
  expect(clock.waiting()).toEqual([EVAL_TIMEOUT_MS]);
});

test("an answer stops the clock", () => {
  const { backend, clock } = throughToDocument();
  expect(clock.waiting()).toEqual([]);
  expect(backend.terminated).toBe(0);
});

test("every state the run passes through is told to the host", () => {
  const { told } = throughToDocument();
  expect(told.states.map((s) => `${s.phase}/${s.running}`)).toEqual([
    "loading/true",
    "ready/true",
    "ready/false",
  ]);
});
