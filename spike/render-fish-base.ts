#!/usr/bin/env bun
// Phase 1 T5/T6 milestone harness: load the js_of_ocaml bundle
// (site/public/beloch/beloch-eval.js) with the real FLINT-wasm qqbar module
// (site/public/beloch/qqbar-wasm.js) wired in, fold examples/bases/fish-base.bel
// (which forces sqrt(2) through the rabbit-ear bisection) through it, and
// render the result to spike/fish-base.svg. Also re-checks a pure-rational
// program (examples/bases/kite.bel — a diagonal reflection, no qqbar) to
// confirm the new qqbar backend doesn't regress the fast path.
//
// Run: bun spike/render-fish-base.ts
import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { parseFold } from "../render/scene/src/index";
import { renderFolded, WEB_THEME } from "../render/render-svg/src/index";

const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");

// site/{package.json,public/beloch} inherit "type":"module" from
// site/package.json, so `require`/`import` on the committed build artifacts
// (qqbar-wasm.js, an emscripten MODULARIZE UMD bundle; beloch-eval.js, a
// js_of_ocaml script bundle) resolve as ESM and silently drop their
// CJS-style `module.exports`/global assignment. Neither file uses
// import/export syntax, so evaluating the source text directly as a plain
// script (bypassing Node's module-type resolution entirely) works for both.
function loadAsScript(absPath: string): any {
  const src = readFileSync(absPath, "utf8");
  const mod = { exports: {} as any };
  const fn = new Function("module", "exports", "require", "__dirname", "__filename", src);
  fn(mod, mod.exports, require, path.dirname(absPath), absPath);
  return mod.exports;
}

async function main() {
  // --- load the wasm qqbar module and install it where qqbar_shim.js looks ---
  const QqbarWasmFactory = loadAsScript(path.join(repoRoot, "site/public/beloch/qqbar-wasm.js"));
  const qqbarModule = await QqbarWasmFactory();
  (globalThis as any).__beloch_qqbar_wasm = qqbarModule;

  // --- load the js_of_ocaml evaluator bundle (sets globalThis.belochFoldString) ---
  loadAsScript(path.join(repoRoot, "site/public/beloch/beloch-eval.js"));
  const belochFoldString = (globalThis as any).belochFoldString;
  if (typeof belochFoldString !== "function") {
    throw new Error("belochFoldString was not installed by beloch-eval.js");
  }

  // --- T6 regression: pure-rational program must still round-trip ---
  const kiteSrc = readFileSync(path.join(repoRoot, "examples/bases/kite.bel"), "utf8");
  const kiteRaw = belochFoldString(kiteSrc);
  const kiteParsed = JSON.parse(kiteRaw);
  console.log("[T6 rational regression] kite.bel ok =", kiteParsed.ok, "kind =", kiteParsed.kind);
  if (kiteParsed.ok !== true) {
    throw new Error(`T6 regression FAILED: kite.bel did not fold: ${JSON.stringify(kiteParsed)}`);
  }

  // --- T5 milestone: fish-base.bel through the real qqbar-wasm backend ---
  const fishSrc = readFileSync(path.join(repoRoot, "examples/bases/fish-base.bel"), "utf8");
  const fishRaw = belochFoldString(fishSrc);
  const fishParsed = JSON.parse(fishRaw);
  console.log(
    "[T5 milestone] fish-base.bel ok =",
    fishParsed.ok,
    "kind =",
    fishParsed.kind,
    "message =",
    fishParsed.message,
  );
  if (fishParsed.ok !== true) {
    throw new Error(`T5 milestone FAILED: fish-base.bel did not fold: ${JSON.stringify(fishParsed)}`);
  }
  const fold = fishParsed.fold;
  const frameCount = fold.file_frames ? fold.file_frames.length : undefined;
  console.log("[T5 milestone] fold.file_frames.length =", frameCount);
  if (!frameCount || frameCount < 1) {
    throw new Error(`T5 milestone FAILED: expected file_frames.length >= 1, got ${frameCount}`);
  }

  // --- render to SVG ---
  const scene = parseFold(fold);
  const doc = renderFolded(scene, { theme: WEB_THEME });
  const svg = doc.toString();
  const outPath = path.join(repoRoot, "spike/fish-base.svg");
  writeFileSync(outPath, svg);
  console.log(
    `[T5 milestone] wrote ${outPath} (${doc.width}x${doc.height}, ${svg.length} bytes)`,
  );

  console.log("\nALL CHECKS PASSED");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
