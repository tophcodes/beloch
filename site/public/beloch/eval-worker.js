// Playground eval worker. Loads the committed jsoo bundle (a plain top-level
// script, not ESM/CJS — see site/scripts/build-eval.sh) and evaluates one
// Beloch source string per message, replying with the raw JSON result string
// from belochFoldString. Caller (Playground.astro) owns the timeout: if the
// evaluator hangs (e.g. a runaway program), the caller terminates this worker
// and spins up a fresh one.
importScripts('/beloch/beloch-eval.js');

self.onmessage = (e) => {
  try {
    self.postMessage({ raw: self.belochFoldString(e.data) });
  } catch (err) {
    self.postMessage({ raw: JSON.stringify({ ok: false, kind: "error", message: String(err) }) });
  }
};
