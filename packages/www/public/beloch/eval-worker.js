// Playground eval worker. Loads the committed jsoo bundle (a plain top-level
// script, not ESM/CJS — see packages/www/scripts/build-eval.sh) plus the FLINT-wasm
// qqbar backend, and evaluates one Beloch source string per message, replying
// with the raw JSON result string from belochFoldString. Three message shapes go
// out: `{ loaded, total }` while the runtime is still transferring, `{ ready: true }`
// once it is instantiated, then `{ raw }` per evaluated message. Caller
// (Playground.astro) owns the timeouts and keeps them apart on that signal: the
// runtime download is a network cost, the evaluation that follows runs locally.
// If the evaluator hangs (e.g. a runaway program), the caller
// terminates this worker and spins up a fresh one — which re-runs the wasm
// instantiation below from scratch.
//
// Load order matters. beloch-eval.js has qqbar_shim.js baked in (dune lists it
// as a javascript_files input), so the shim's ml_qqbar_* primitives ship inside
// the bundle. Those primitives never await — they require a ready emscripten
// Module at globalThis.__beloch_qqbar_wasm *before the first call* (see the
// loader contract in packages/eval-web/qqbar_shim.js). So we instantiate QqbarWasm once here
// and gate every eval on it. Both files are classic scripts and have to enter
// this worker's global scope as such: qqbar-wasm.js defines self.QqbarWasm (a
// MODULARIZE factory, -sEXPORT_NAME), beloch-eval.js defines
// self.belochFoldString. The site's package.json "type":"module" does not
// affect either.

const FALLBACK_PARTS = [
  { url: "/beloch/qqbar-wasm.js" },
  { url: "/beloch/beloch-eval.js" },
];

// Fetching the two files by hand, rather than handing their URLs to
// importScripts directly, is what makes the transfer measurable: the reader
// counts the bytes as they arrive, and the finished text enters the global
// scope through a blob URL, which importScripts loads with exactly the same
// classic-script semantics and without a second request. The denominator comes
// from runtime-manifest.json, which build-eval.sh writes from the files it just
// produced, so it cannot drift from what is served. Without the manifest the
// runtime still loads; only the progress does not.
async function loadRuntime() {
  let parts = null;
  try {
    const res = await fetch("/beloch/runtime-manifest.json");
    if (res.ok) parts = (await res.json()).parts;
  } catch (e) {
    /* no manifest: fall through to the unmeasured path */
  }
  if (!parts) {
    for (const part of FALLBACK_PARTS) importScripts(part.url);
    return;
  }

  const total = parts.reduce((n, p) => n + p.bytes, 0);
  let loaded = 0;
  // Reported once per percent. A 6 MB transfer arrives in thousands of
  // chunks, and the status line reads the same at 41.3 % as at 41.4 %.
  let reported = -1;
  const report = () => {
    const pct = Math.floor((loaded / total) * 100);
    if (pct === reported) return;
    reported = pct;
    self.postMessage({ loaded, total });
  };

  for (const part of parts) {
    const res = await fetch(part.url);
    if (!res.ok) throw new Error(`${part.url}: HTTP ${res.status}`);
    const chunks = [];
    const reader = res.body.getReader();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      loaded += value.byteLength;
      report();
    }
    const url = URL.createObjectURL(new Blob(chunks, { type: "text/javascript" }));
    try {
      importScripts(url);
    } finally {
      URL.revokeObjectURL(url);
    }
  }
}

// Kick off the transfer and instantiation at worker-creation time so both
// overlap with the user reading the page; the first eval awaits them
// regardless. WASM_ASYNC_COMPILATION is off, so instantiation resolves quickly
// (synchronous compile of the inlined wasm).
const qqbarReady = loadRuntime()
  .then(() => QqbarWasm())
  .then((mod) => {
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
