// Source to document: the phases, the in-flight run, both limits and the
// evaluator's own envelope.
//
// The core holds a document slot and never asks where a document came from.
// This module is what fills it for a consumer that evaluates, and the reason
// the card and the tour compose without carrying a worker they never use.
import { parseFold, type FoldScene } from "@beloch/scene";
import type { Runtime } from "@beloch/runtime";
import {
  systemScheduler,
  type Diagnostic,
  type EvaluatorBackend,
  type EvaluatorHost,
  type EvaluatorState,
  type ProgramSpan,
  type Scheduler,
  type SpawnEvaluator,
} from "./backend";

export * from "./backend";
export * from "./ui";

// Two separate limits. Spawning pulls the wasm evaluator over the network
// (megabytes, once per visitor); the evaluation itself then runs locally. The
// evaluation limit starts only once the backend reports itself ready, so a
// slow line stays distinguishable from a hung evaluator.
export const LOAD_TIMEOUT_MS = 60000;
export const EVAL_TIMEOUT_MS = 8000;

// Before anything has been spawned. A host renders its run button from this
// until the first run moves it.
export const initialEvaluatorState: EvaluatorState = {
  phase: "cold",
  running: false,
  loadStalled: false,
  progress: null,
  answered: null,
};

export interface Evaluator {
  readonly state: EvaluatorState;
  // Spawn the backend without asking it for anything. What an eager consumer
  // does on mount, so the first run pays no download.
  boot(): void;
  // Evaluate `source`. Spawns the backend on first use and queues the run
  // until it is ready. A run while one is in flight is dropped: the reader
  // gets the answer to the one already asked.
  run(source: string): void;
}

export interface EvaluatorOptions {
  runtime: Runtime;
  spawn: SpawnEvaluator;
  host: EvaluatorHost;
  scheduler?: Scheduler;
  loadTimeoutMs?: number;
  evalTimeoutMs?: number;
}

// The envelope the evaluator answers in. `ok` carries a FOLD document;
// anything else carries a message, and `kind` tells the refusals apart.
interface Envelope {
  ok?: boolean;
  fold?: unknown;
  kind?: string;
  message?: string;
  hint?: string;
  line?: number;
  column?: number;
  endLine?: number;
  endColumn?: number;
}

const said = (err: unknown): string => (err instanceof Error ? err.message : String(err));

// An answer from before the span's end was carried names a line and a column
// only, and makes no span.
const spanOf = (e: Envelope): ProgramSpan | null =>
  e.line === undefined || e.column === undefined || e.endLine === undefined || e.endColumn === undefined
    ? null
    : { fromLine: e.line, fromCol: e.column, toLine: e.endLine, toCol: e.endColumn };

export function createEvaluator(options: EvaluatorOptions): Evaluator {
  const { runtime, spawn, host } = options;
  const scheduler = options.scheduler ?? systemScheduler;
  const loadLimit = options.loadTimeoutMs ?? LOAD_TIMEOUT_MS;
  const evalLimit = options.evalTimeoutMs ?? EVAL_TIMEOUT_MS;

  let state: EvaluatorState = initialEvaluatorState;
  let backend: EvaluatorBackend | null = null;
  // The run waiting for the backend to arrive, and the one it is holding.
  let queued: string | null = null;
  let dispatched: string | null = null;
  let cancelTimer: (() => void) | null = null;

  const change = (over: Partial<EvaluatorState>) => {
    state = { ...state, ...over };
    host.changed(state);
  };
  const stopClock = () => {
    cancelTimer?.();
    cancelTimer = null;
  };

  const spawnBackend = () => {
    backend = spawn({
      progress(share) {
        change({ progress: share });
      },
      ready() {
        // Whatever was waiting on the network waits no longer, so the load
        // limit stops and the short evaluation limit may start.
        stopClock();
        const waiting = queued;
        queued = null;
        state = { ...state, phase: "ready", loadStalled: false, progress: null };
        if (waiting === null) {
          host.changed(state);
          return;
        }
        startEval(waiting);
      },
      answer(raw) {
        // Only an answered request moves the source an editor marks against.
        // A timeout or a broken backend leaves it where it was.
        const source = dispatched;
        settle({ answered: source });
        report(raw);
      },
      failed(message) {
        settle({});
        host.diagnostic({ kind: "backend", message });
      },
    });
  };

  // A run is over: the clock stops, nothing is in flight, and the host is
  // told before it is handed the result.
  const settle = (over: Partial<EvaluatorState>) => {
    stopClock();
    queued = null;
    dispatched = null;
    change({ running: false, ...over });
  };

  const startEval = (source: string) => {
    dispatched = source;
    stopClock();
    cancelTimer = scheduler.after(evalLimit, () => {
      cancelTimer = null;
      // A hung evaluation needs a fresh backend; it re-reads the evaluator
      // from the HTTP cache. A slow arrival never reaches this path.
      backend?.terminate();
      backend = null;
      dispatched = null;
      queued = null;
      state = { ...state, phase: "loading", running: false };
      spawnBackend();
      host.changed(state);
      host.diagnostic({ kind: "timeout" });
    });
    change({ running: true });
    backend!.evaluate(source);
  };

  const report = (raw: string) => {
    let envelope: Envelope;
    try {
      envelope = JSON.parse(raw) as Envelope;
    } catch (err) {
      host.diagnostic({ kind: "protocol", message: said(err) });
      return;
    }
    if (!envelope.ok) {
      if (envelope.kind === "native") {
        host.diagnostic({ kind: "native" });
        return;
      }
      host.diagnostic({
        kind: "program",
        message: envelope.message ?? "Unknown error.",
        hint: envelope.hint ?? null,
        line: envelope.line ?? null,
        span: spanOf(envelope),
      });
      return;
    }
    let scene: FoldScene;
    try {
      scene = parseFold(envelope.fold as object);
    } catch (err) {
      // The program ran; what came back is not a document this version can
      // draw. The last good drawing stands, as after any failed run.
      host.diagnostic({ kind: "document", message: said(err) });
      return;
    }
    runtime.dispatch({ type: "document/set", scene });
    host.document(scene);
  };

  // Spawns unless something is already there, and answers whether it did.
  // Silent, so a run that spawns on its way tells the host once rather than
  // twice inside one tick.
  const ensureBackend = (): boolean => {
    if (backend) return false;
    spawnBackend();
    state = { ...state, phase: "loading" };
    return true;
  };

  const boot = () => {
    if (ensureBackend()) host.changed(state);
  };

  return {
    get state() {
      return state;
    },
    boot,
    run(source) {
      if (state.running) return;
      ensureBackend();
      if (state.phase === "ready") {
        state = { ...state, loadStalled: false };
        startEval(source);
        return;
      }
      // Still arriving: the run waits under the generous load limit. On
      // expiry the backend keeps its transfer running, so pressing Run again
      // picks it up where it stands.
      queued = source;
      stopClock();
      cancelTimer = scheduler.after(loadLimit, () => {
        cancelTimer = null;
        queued = null;
        change({ running: false, loadStalled: true });
      });
      change({ running: true, loadStalled: false });
    },
  };
}
