// Run-button and status-line state for the playground (Playground.astro).
// DOM-free so the decision itself is unit testable; the caller owns the eval
// Worker, both timers and the actual DOM writes.

// The eval Worker's lifecycle. Run is available in every phase; the phases
// differ in what a run has to wait for first.
export type RuntimePhase =
  // no Worker yet — the next run pays for the runtime download
  | "cold"
  // Worker created, wasm runtime still booting
  | "loading"
  // runtime booted, an evaluation can start immediately
  | "ready";

export interface RunState {
  phase: RuntimePhase;
  // A run is in flight: either waiting for the runtime, or evaluating.
  running: boolean;
  // The run that just finished re-evaluated source identical to the previous
  // completed run's, so it reproduced that run's result.
  repeat: boolean;
  // The runtime's load limit elapsed while a run was waiting for it. The
  // Worker keeps loading; the run was dropped.
  loadStalled: boolean;
  // How much of the runtime has arrived, 0 to 1, or null while that is
  // unknown (the worker reports it from runtime-manifest.json; without the
  // manifest it loads the runtime without measuring it).
  progress?: number | null;
}

export interface RunUi {
  disabled: boolean;
  title: string;
  // Text for the role="status" line; "" hides it.
  status: string;
}

// Transfer size of the wasm runtime the first run downloads: brotli over
// `public/beloch/qqbar-wasm.js` plus `beloch-eval.js`, which the worker pulls
// via importScripts. Hand-measured, so it goes stale when the runtime is
// rebuilt; re-measure with `gzip -9 -c <file> | wc -c` as an upper bound
// (2 447 364 B today, brotli lands near 2.3 MB).
export const RUNTIME_SIZE = "2.3 MB";

export function runUi(s: RunState): RunUi {
  if (s.running) {
    if (s.phase === "ready") {
      return { disabled: true, title: "evaluating …", status: "computing geometry …" };
    }
    // A share of the runtime, against the size of the transfer it costs. The
    // share is measured on the decoded bytes and the size is what goes over
    // the wire, so the percentage moves with the download without claiming a
    // byte count the reader could hold against the network panel.
    const share =
      s.progress === null || s.progress === undefined
        ? null
        : Math.round(Math.max(0, Math.min(1, s.progress)) * 100);
    return {
      disabled: true,
      title: "loading runtime …",
      status:
        share === null
          ? `loading runtime (${RUNTIME_SIZE}) …`
          : `loading runtime · ${share} % of ${RUNTIME_SIZE}`,
    };
  }
  if (s.loadStalled) {
    return {
      disabled: false,
      title: "Run",
      status: "runtime still loading; press Run to retry",
    };
  }
  return {
    disabled: false,
    title: "Run",
    status: s.repeat ? "same code as the last run, result unchanged" : "",
  };
}
