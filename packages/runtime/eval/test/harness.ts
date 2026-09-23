// A backend that answers when a test says so, and a scheduler whose timers
// fire on demand. Together they make every phase, both limits and the queue
// instant and exact: no worker, no wasm, no waiting.
import type { BackendEvents, Diagnostic, EvaluatorState, Scheduler, SpawnEvaluator } from "../src/index";
import type { FoldScene } from "@beloch/scene";

export interface FakeBackend {
  spawned: number;
  terminated: number;
  evaluated: string[];
  // The events the live backend reports through, so a test can play the
  // worker's side: progress, ready, an answer, a failure.
  events(): BackendEvents;
}

export function fakeBackend(): { backend: FakeBackend; spawn: SpawnEvaluator } {
  let events: BackendEvents | null = null;
  const backend: FakeBackend = {
    spawned: 0,
    terminated: 0,
    evaluated: [],
    events: () => {
      if (!events) throw new Error("nothing has been spawned yet");
      return events;
    },
  };
  const spawn: SpawnEvaluator = (e) => {
    backend.spawned++;
    events = e;
    return {
      evaluate: (source) => backend.evaluated.push(source),
      terminate: () => backend.terminated++,
    };
  };
  return { backend, spawn };
}

export function fakeScheduler() {
  const timers: { ms: number; fn: () => void; live: boolean }[] = [];
  const scheduler: Scheduler = {
    after: (ms, fn) => {
      const timer = { ms, fn, live: true };
      timers.push(timer);
      return () => {
        timer.live = false;
      };
    },
  };
  return {
    scheduler,
    // Fires the timer waiting on `ms`, as the clock reaching it would.
    fire(ms: number) {
      const timer = timers.find((t) => t.live && t.ms === ms);
      if (!timer) throw new Error(`no timer waiting on ${ms} ms`);
      timer.live = false;
      timer.fn();
    },
    waiting: () => timers.filter((t) => t.live).map((t) => t.ms),
  };
}

export interface Told {
  documents: FoldScene[];
  diagnostics: Diagnostic[];
  states: EvaluatorState[];
}
