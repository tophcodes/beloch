# FLINT → WASM playground spike

**Date:** 2026-07-18
**Branch:** `spike/flint-wasm-playground` (stacked on `fix/flatten-anchor-parity`)
**Status:** design — approved in shape, Phase 0 gated

## Problem

The site's live playground (`site/src/components/Playground.astro`) evaluates
`.bel` source in a Web Worker running the committed js_of_ocaml bundle
(`site/public/beloch/beloch-eval.js`, built from `web/beloch_web.ml`). That
bundle is OCaml + `zarith_stubs_js` — **rationals only**. Any value that forces
a `Qqbar.t` (algebraic irrational) hits `web/qqbar_shim.js`, which stubs out the
FLINT/Calcium C backend (it can't compile to JS — decisions/0013), and the
playground shows the "braucht native Auswertung" notice instead of folding.

The fish base (`examples/bases/fish-base.bel`) needs √2: its rabbit-ears bisect
the 45° diagonal, and `tan 22.5° = √2 − 1 = 0.41421356…`. This is intrinsic to
22.5° origami — no restructuring of the `.bel` removes it. So the playground
**cannot** fold the fish base by construction. Verified: a fresh `web/` build
still returns `{ok:false, kind:"native", message:"…ml_qqbar_of_q unsupported in
js_of_ocaml build"}`.

## Goal

Make the fish base fold **live** in the playground — edit-and-recompute, not a
precomputed picture — by giving the browser evaluator a real qqbar backend:
FLINT 3.6 compiled to WebAssembly.

Non-goal: replacing the native evaluator, or WASM-ifying the whole OCaml
program. Only the C number floor (`qqbar_shim.js`) is replaced. OCaml stays
js_of_ocaml.

## Rejected alternatives

- **A — precompute fallback (display-only).** On `kind:"native"`, fetch a
  build-time FOLD JSON (the `<Beloch>` render-card pattern). fish base *appears*
  folded but live edits to √2 code still fall back. Kept only as the Phase 0
  fallback if the FLINT build fails.
- **B — pure-OCaml ℚ(√·) fragment.** A second, JS-only algebraic-number kernel
  beside the FLINT one. Duplicates the number kernel, diverges on cube-roots /
  nested radicals, violates the project's single-exact-source principle.
  Rejected.

## Architecture

Three phases, the first a hard gate.

### Phase 0 — de-risk the FLINT emscripten build (throwaway, timeboxed)

The entire gamble is whether FLINT 3.6 (Calcium/Arb/Antic merged in) compiles
to wasm. GMP+MPFR→wasm is well-trodden; FLINT 3.6 is the unknown.

- Toolchain: `nix shell nixpkgs#emscripten` (6.0.2 available). FLINT is already
  a pinned tarball in `flake.nix` (`v3.6.0`, autotools `./configure`).
- Build GMP → MPFR → FLINT 3.6 to wasm via `emconfigure` / `emmake`.
- Export one trivial C entry: `qqbar_set_q(2)` → `qqbar_sqrt` → `qqbar_get_d`,
  wrapped so node can call it (`-sEXPORTED_FUNCTIONS`, `ccall`/`cwrap` or a tiny
  C `main`).
- Run the `.wasm` in node; assert output ≈ `1.41421356` (√2, whose double is
  unambiguous).

**Gate:**
- ✅ compiles + numerically correct → C is proven, proceed to Phase 1.
- ❌ FLINT won't emscripten (build error we can't resolve in the timebox) →
  **stop, report, fall back to alternative A** (display-only precompute). Days
  saved.

Deliverable: a `spike/` scratch dir with the build recipe (shell script or
notes) and the passing node check. Not shipped as-is; informs Phase 1's real
build wiring.

### Phase 1 — marshalling + JS glue (only if Phase 0 passes)

Replace `web/qqbar_shim.js` with glue backed by the wasm module.

- **Handle model.** `qqbar_t` are heap C structs. They live in the emscripten
  heap; the js_of_ocaml side holds opaque integer handles (index into a JS-side
  registry, or the raw wasm pointer). Every `ml_qqbar_*` op takes/returns
  handles.
- **Lifetime.** Allocate via `qqbar_init` on construction; a js_of_ocaml
  finalizer (or the existing OCaml custom-block finalizer path) calls
  `qqbar_clear` + frees the handle so wasm memory doesn't leak.
- **Surface.** ~22 externals to cover (from `web/qqbar_shim.js`):
  `of_q, sqrt, add, sub, mul, div, neg, inv, cmp_re, sgn_re, equal, is_zero,
  is_rational, degree, minpoly, enclosure, get_d, to_q_str, express_in_field,
  real_roots, roots_qqbar_poly`. Each maps to a wasm export.
- **String/poly marshalling.** `to_q_str`, `minpoly`, `express_in_field`,
  `real_roots`, `roots_qqbar_poly` move strings/arrays across the boundary —
  encode via the emscripten heap (`stringToUTF8` / `UTF8ToString`, or typed
  arrays). These are the fiddly ones; the arithmetic ops are one-liners.

Deliverable: `web/qqbar_shim.js` replaced (or a new `qqbar_wasm.js` wired into
`web/dune`'s `javascript_files`), plus the committed `.wasm` and its loader.

### Phase 2 — site wiring

- Emit the wasm build into the site as a committed artifact, same pattern as the
  existing bundle (`site/scripts/build-eval.sh` copies `beloch_web.bc.js`;
  extend it to also emit/copy the `.wasm`).
- Load the wasm module in the worker before evaluation. `eval-worker.js`
  currently does `importScripts('/beloch/beloch-eval.js')`; wasm init is async,
  so the worker must `await` module readiness before answering the first
  `postMessage` (queue the message or reply "loading" until ready). Emscripten
  `MODULARIZE` + `locateFile` to point at `/beloch/…wasm`.
- Rebuild `beloch-eval.js` against the new glue.

**Verification (end-to-end):** paste `examples/bases/fish-base.bel` into the
playground, click Run, see it fold (5 folded frames render). Also confirm a
pure-rational program still works (no regression) and that the timeout path
still recovers a hung worker.

## Testing

- Phase 0: node assertion on the wasm export (√2 correct).
- Phase 1: reuse the existing OCaml qqbar tests, but run them through the
  js_of_ocaml build (a `node` harness over `beloch_web.bc.js` calling a handful
  of qqbar round-trips: `of_q → sqrt → get_d`, `add`, `cmp`, `express_in_field`).
  These already pass natively; the wasm glue must match.
- Phase 2: manual playground check + the existing `site/src/lib/*.test.ts`
  suites still green (`parseFold`/render path unchanged).

## Risks

- **FLINT emscripten build** — the headline risk. Phase 0 exists to hit it
  first. GMP/MPFR are fine; FLINT's configure may need `--disable-assembly`,
  threading off, and hand-holding for its runtime CPU dispatch.
- **wasm bundle size.** FLINT+GMP wasm may be large (MBs). Acceptable for a lazy-
  loaded playground asset; note it, lazy-load, don't block page render.
- **Marshalling correctness.** String/poly ops are the error-prone glue. Covered
  by the Phase 1 node harness.
- **Async worker init.** Must not drop or mis-order the first eval message.

## Stacking note

Branched from `fix/flatten-anchor-parity` HEAD. The spike is orthogonal to the
flatten/`eval.ml` work — it touches only `web/`, `site/`, and a new build recipe.
Stacked PR is fine; the syntax overhaul on the base branch lands regardless.

## Implementation note

Mechanical build/glue/wiring work delegated to Sonnet subagents where possible;
Opus reserved for the FLINT-build diagnosis and marshalling-design calls.
