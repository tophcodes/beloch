// Run button and status line, as a pure function of the run state. The host
// owns the DOM writes; what the two say is decided here so a test can read it
// without a button existing.

import type { EvaluatorPhase, EvaluatorState } from "./backend";

// What the button and the status line need, which is less than an evaluator
// holds.
export interface RunState {
  phase: EvaluatorPhase;
  running: boolean;
  loadStalled: boolean;
  progress?: number | null;
}

export interface RunUi {
  disabled: boolean;
  title: string;
  // Text for the role="status" line; "" hides it.
  status: string;
}

// Transfer size of the wasm evaluator the first run downloads: brotli over
// `public/beloch/qqbar-wasm.js` plus `beloch-eval.js`, which the worker pulls
// via importScripts. Hand-measured, so it goes stale when the evaluator is
// rebuilt; re-measure with `gzip -9 -c <file> | wc -c` as an upper bound
// (2 447 364 B today, brotli lands near 2.3 MB).
//
// The reader meets no module name, so the line keeps saying "runtime".
export const EVALUATOR_SIZE = "2.3 MB";

export function runUi(s: RunState | EvaluatorState): RunUi {
  if (s.running) {
    if (s.phase === "ready") {
      return { disabled: true, title: "evaluating …", status: "computing geometry …" };
    }
    // A share of the evaluator, against the size of the transfer it costs.
    // The share is measured on the decoded bytes and the size is what goes
    // over the wire, so the percentage moves with the download without
    // claiming a byte count the reader could hold against the network panel.
    const share =
      s.progress === null || s.progress === undefined
        ? null
        : Math.round(Math.max(0, Math.min(1, s.progress)) * 100);
    return {
      disabled: true,
      title: "loading runtime …",
      status:
        share === null
          ? `loading runtime (${EVALUATOR_SIZE}) …`
          : `loading runtime · ${share} % of ${EVALUATOR_SIZE}`,
    };
  }
  if (s.loadStalled) {
    return {
      disabled: false,
      title: "Run",
      status: "runtime still loading; press Run to retry",
    };
  }
  return { disabled: false, title: "Run", status: "" };
}
