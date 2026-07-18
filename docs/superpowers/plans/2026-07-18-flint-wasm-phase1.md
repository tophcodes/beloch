# FLINT→WASM Phase 1 — qqbar in the browser bundle

**Goal:** fish-base folds through the js_of_ocaml bundle backed by a real
FLINT-wasm qqbar module. Milestone = `examples/bases/fish-base.bel` evaluated via
the browser bundle in node yields folded FOLD frames, rendered to an SVG we can
look at. Full worker/site wiring (Phase 2) is deferred.

**Reference:** `lib/qqbar_stubs.c` is the working native FFI — the wasm C shim is
a near-mechanical port of it (OCaml custom-block glue → flat handle ABI). Read it.

## Architecture

`type t` (OCaml, opaque) crosses to JS as a **handle** = an `int` pointer into
the emscripten heap holding a `qqbar_struct`. Three pieces must agree on this ABI:

1. **`web/qqbar_wasm.c`** — flat C shim, one function per `ml_qqbar_*`, taking/
   returning `int` handles / `double` / `char*`. Mirrors `qqbar_stubs.c` op-for-op
   but strips `CAMLparam`/`Data_custom_val`/`Store_field` — plain C instead.
   - `int wasm_qqbar_alloc(void)` = `malloc(sizeof(qqbar_struct)); qqbar_init; return`.
   - `void wasm_qqbar_free(int h)` = `qqbar_clear; free`.
   - UNOP/BINOP → `int f(int a[,int b]){ int r=alloc; qqbar_op((ptr)r,(ptr)a,..); return r; }`
   - bool/int/degree/cmp/sgn → return `int` directly.
   - `double wasm_qqbar_get_d(int h)` → the `arb`/`arf_get_d` path from the stub.
   - **strings out** (`to_q_str`, one coeff of minpoly, enclosure parts) → return
     `char*` malloc'd by FLINT/strdup; JS reads via `UTF8ToString` then calls a
     `wasm_free_str(char*)`.
   - **arrays** (`minpoly`, `express_in_field`, `enclosure`, `real_roots`,
     `roots_qqbar_poly`) → serialize to ONE delimited `char*` (e.g. `\n`-joined;
     for handle-arrays return a `\n`-joined list of int handles as decimal). JS
     splits. For `real_roots` the input `string[]` comes in as one `\n`-joined
     `char*`. Options (`None`) → sentinel (empty string / `"none"`).
   - Bad-input paths that `caml_failwith` natively → return a sentinel the JS
     shim turns into `caml_failwith` (keep the SAME message strings).

2. **`web/qqbar_shim.js`** (replaces the failing stub) — keeps every existing
   `//Provides: ml_qqbar_*` entry point (OCaml side unchanged), bodies now call
   the wasm module. Handle lifetime: wrap each handle so a `FinalizationRegistry`
   calls `wasm_qqbar_free`. Marshal OCaml strings ↔ JS (`caml_jsstring_of_string`
   / `caml_string_of_jsstring`) and JS ↔ wasm heap (`stringToUTF8`/`UTF8ToString`).
   Build OCaml arrays with the block layout jsoo expects (`[0, e0, e1, ...]`).
   The wasm `Module` must be ready synchronously before any `ml_qqbar_*` call.

3. **build** — extend the Phase 0 recipe (`spike/build.sh`) into a real build that
   compiles gmp+mpfr+flint (cached) **plus `web/qqbar_wasm.c`** into an emscripten
   module. Build with `-O2 -sWASM_ASYNC_COMPILATION=0` (module ready synchronously
   — matters for both the node harness and the future worker) and export the
   `wasm_qqbar_*` + `wasm_qqbar_alloc/free` + `wasm_free_str` symbols
   (`-sEXPORTED_FUNCTIONS`, `-sEXPORTED_RUNTIME_METHODS=ccall,cwrap,UTF8ToString,stringToUTF8,lengthBytesUTF8`).
   Try `-sMODULARIZE=1 -sSINGLE_FILE=1` so it's one loadable JS. Shrink later if
   huge; correctness first. Output committed under `site/public/beloch/` (name it
   e.g. `qqbar-wasm.js`).

## Tasks

- [ ] **T1 — C shim.** Port all 22 ops from `lib/qqbar_stubs.c` into
  `web/qqbar_wasm.c` per the ABI above. Compile it alone against the Phase-0
  prefix to a `.o` first to catch API errors early (reuse the FLINT-3.6 API
  choices Phase 0 already validated, e.g. the `arb`/`arf_get_d` path for get_d).
- [ ] **T2 — build.** Produce `site/public/beloch/qqbar-wasm.js` (+ `.wasm` if not
  SINGLE_FILE). Node smoke test: load it, `alloc`→ set 2 →`sqrt`→`get_d` = 1.41421356.
- [ ] **T3 — JS glue.** Rewrite `web/qqbar_shim.js` bodies to call the module
  (handles + FinalizationRegistry + string/array marshalling). Keep failure
  messages identical.
- [ ] **T4 — rebuild bundle.** `nix develop --command dune build web/ --profile
  release`, copy `_build/default/web/beloch_web.bc.js` →
  `site/public/beloch/beloch-eval.js` (this is what `site/scripts/build-eval.sh`
  does — extend that script to also emit the wasm module).
- [ ] **T5 — end-to-end proof.** Node harness: load `beloch-eval.js` + the wasm
  module (await ready), call `belochFoldString(fishBaseSrc)`, assert
  `ok:true` and `fold.file_frames.length >= 1` (folded, not the `kind:"native"`
  bailout). Then render the FOLD to SVG (reuse `site/`'s `@beloch/scene`
  `parseFold` + `@beloch/render-svg` `renderFolded`) and write
  `spike/fish-base.svg`.
- [ ] **T6 — regression.** Confirm a pure-rational program still round-trips
  (e.g. a simple `map` diagonal-free fold) — the shim must not break the
  rational fast path (it never calls qqbar).
- [ ] Commit after each task. Do NOT do Phase 2 (worker async-load, site build,
  in-browser render) — stop at the SVG.

## Out of scope / defer
- wasm size tuning beyond `-O2` (5.86MB Phase-0 baseline; note final size).
- Worker/site wiring, async module init in `eval-worker.js`, browser render.
- Parallel fan-out — this is one coupled ABI, authored coherently.
