// Playground eval worker. Loads the committed jsoo bundle (a plain top-level
// script, not ESM/CJS — see packages/www/scripts/build-eval.sh) plus the FLINT-wasm
// qqbar backend, and evaluates one Beloch source string per message, replying
// with the raw JSON result string from belochFoldString. Two message shapes go
// out: `{ ready: true }` once the runtime is instantiated, then `{ raw }` per
// evaluated message. Caller (Playground.astro) owns the timeouts and keeps
// them apart on that signal: the runtime download is a network cost, the
// evaluation that follows runs locally. If the evaluator hangs (e.g. a runaway program), the caller
// terminates this worker and spins up a fresh one — which re-runs the wasm
// instantiation below from scratch.
//
// Load order matters. beloch-eval.js has qqbar_shim.js baked in (dune lists it
// as a javascript_files input), so the shim's ml_qqbar_* primitives ship inside
// the bundle. Those primitives never await — they require a ready emscripten
// Module at globalThis.__beloch_qqbar_wasm *before the first call* (see the
// loader contract in packages/eval-web/qqbar_shim.js). So we instantiate QqbarWasm once here
// and gate every eval on it. importScripts loads classic scripts, so the site's
// package.json "type":"module" does not affect these two files in a Worker.
importScripts('/beloch/qqbar-wasm.js');   // defines self.QqbarWasm (MODULARIZE factory, -sEXPORT_NAME)
importScripts('/beloch/beloch-eval.js');  // defines self.belochFoldString (jsoo bundle + embedded shim)

// Kick off instantiation at worker-creation time so it overlaps with the user
// reading the page; the first eval awaits it regardless. WASM_ASYNC_COMPILATION
// is off, so this resolves quickly (synchronous compile of the inlined wasm).
const qqbarReady = QqbarWasm().then((mod) => {
  globalThis.__beloch_qqbar_wasm = mod;
});

// Tell the caller the runtime is up, so it can stop timing the download and
// start timing the evaluation. A rejected instantiation sends nothing; the
// caller's load limit covers that, and the first eval reports the error.
qqbarReady.then(() => self.postMessage({ ready: true }));

self.onmessage = async (e) => {
  try {
    await qqbarReady;
    self.postMessage({ raw: self.belochFoldString(e.data) });
  } catch (err) {
    self.postMessage({ raw: JSON.stringify({ ok: false, kind: "error", message: String(err) }) });
  }
};
