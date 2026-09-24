// What the runtime needs from whatever actually evaluates a program, and what
// it needs from a clock.
//
// The web consumers pass a wasm worker; a VS Code preview would pass a
// subprocess running the native `beloch fold`. The module knows neither: it
// hands over a source string and is told what came back.
import type { FoldScene } from "@beloch/scene";

// The evaluator's lifecycle. A run is offered in every phase; the phases
// differ in what it has to wait for first.
export type EvaluatorPhase =
  // Nothing spawned yet. The next run pays for the download.
  | "cold"
  // Spawned, still arriving.
  | "loading"
  // Arrived. An evaluation starts at once.
  | "ready";

// What a backend tells the runtime, as it happens.
export interface BackendEvents {
  // The share of the transfer that has arrived, 0 to 1, or null where it is
  // not measured.
  progress(share: number | null): void;
  // Arrived and able to evaluate.
  ready(): void;
  // One request answered, as the evaluator's own envelope.
  answer(raw: string): void;
  // The backend itself broke, rather than the program in it.
  failed(message: string): void;
}

export interface EvaluatorBackend {
  evaluate(source: string): void;
  // Stops it for good. A hung evaluation is cut off this way, and a fresh
  // backend spawned beside it.
  terminate(): void;
}

export type SpawnEvaluator = (events: BackendEvents) => EvaluatorBackend;

// Timers, injected so a test drives both limits without waiting for them.
export interface Scheduler {
  // Runs `fn` after `ms`. The returned function cancels it.
  after(ms: number, fn: () => void): () => void;
}

export const systemScheduler: Scheduler = {
  after(ms, fn) {
    const handle = setTimeout(fn, ms);
    return () => clearTimeout(handle);
  },
};

// A stretch of the source, 1-based, its end one past the last character. The
// field names are the ones the editor reads spans in.
export interface ProgramSpan {
  fromLine: number;
  fromCol: number;
  toLine: number;
  toCol: number;
}

// What went wrong, said in kinds rather than in sentences: the wording is the
// host's, because it is the one with a reader.
export type Diagnostic =
  // The evaluator rejected the program, with its own message, the one thing
  // it suggests writing instead where it has one (ADR 0028), the line it named
  // and the whole span where the answer carries one.
  | {
      kind: "program";
      message: string;
      hint: string | null;
      line: number | null;
      span: ProgramSpan | null;
    }
  // Beyond the browser fragment: an irrational through √ or ∛.
  | { kind: "native" }
  // The evaluation ran past its limit and was cut off.
  | { kind: "timeout" }
  // The backend broke.
  | { kind: "backend"; message: string }
  // An answer this version cannot read.
  | { kind: "protocol"; message: string }
  // A FOLD document the scene parser rejected.
  | { kind: "document"; message: string };

// What a run produced, told to the host as it happens. The document slot is
// already filled when `document` is called; the scene comes with it for the
// furniture a host builds around a drawing.
export interface EvaluatorHost {
  document(scene: FoldScene): void;
  diagnostic(diagnostic: Diagnostic): void;
  // The run state moved. A host redraws its run button and its status line.
  changed(state: EvaluatorState): void;
}

export interface EvaluatorState {
  phase: EvaluatorPhase;
  // A run is in flight: waiting for the evaluator, or evaluating.
  running: boolean;
  // The load limit elapsed while a run was waiting. The backend keeps
  // arriving; the run was dropped.
  loadStalled: boolean;
  // The share of the evaluator that has arrived, or null while unmeasured.
  progress: number | null;
  // The source of the last run that was answered, or null before the first
  // answer. An editor holds its marks against this rather than against the
  // text, which has moved on.
  answered: string | null;
}
