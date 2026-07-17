// js_of_ocaml runtime shim for lib/qqbar.ml's C stubs (lib/qqbar_stubs.c,
// FLINT/Calcium — see decisions/0013-flint-qqbar-backend.md). jsoo cannot
// compile C, so every `external ... = "ml_qqbar_*"` primitive is backed here
// by calls into a real FLINT-wasm module (web/qqbar_wasm.c, built by
// spike/build.sh into site/public/beloch/qqbar-wasm.js — see
// docs/superpowers/plans/2026-07-18-flint-wasm-phase1.md for the ABI).
//
// Loader contract: the wasm module must already be ready (its emscripten
// `Module` instance, post-`await`) and installed at
// `globalThis.__beloch_qqbar_wasm` *before* any `ml_qqbar_*` primitive is
// called — this file never awaits anything itself, matching the "module
// ready synchronously" requirement from the plan. Wiring that load (worker
// or node harness) is the caller's job; see spike/ for the Phase 1 proof.
//
// Representation: `Qqbar.t` (opaque on the OCaml side) crosses to JS as a
// boxed `{ h: <wasm heap handle int> }` object, NOT a bare number — a bare
// JS number can't be a FinalizationRegistry target, and we need GC-driven
// `wasm_qqbar_free` so folds with many intermediate algebraic numbers don't
// leak the wasm heap. Every op boxes/unboxes at the boundary.
// Strings/arrays/options cross per the plan's ABI: strings as JS strings via
// caml_jsstring_of_string/caml_string_of_jsstring, "\n"-joined lists via the
// wasm heap (UTF8ToString/ccall's automatic string-arg marshalling), OCaml
// arrays built in jsoo block layout ([0, e0, e1, ...]), options as
// 0 (None) / [0, x] (Some x) — matching the native stub's Val_int(0) /
// caml_alloc(1,0) encoding.

//Provides: qqbar_wasm_module
function qqbar_wasm_module() {
  var m = globalThis.__beloch_qqbar_wasm;
  if (!m) {
    throw new Error(
      "beloch: qqbar wasm module not loaded (globalThis.__beloch_qqbar_wasm is unset)",
    );
  }
  return m;
}

//Provides: qqbar_finalizers
//Requires: qqbar_wasm_module
var qqbar_finalizers = new FinalizationRegistry(function (handle) {
  try {
    qqbar_wasm_module().ccall("wasm_qqbar_free", null, ["number"], [handle]);
  } catch (e) {
    /* module already torn down; nothing to free into */
  }
});

//Provides: qqbar_box
//Requires: qqbar_finalizers
function qqbar_box(h) {
  var t = { h: h };
  qqbar_finalizers.register(t, h, t);
  return t;
}

//Provides: qqbar_unbox
function qqbar_unbox(t) {
  return t.h;
}

// reads a malloc'd char* out of the wasm heap and frees it
//Provides: qqbar_read_and_free_str
//Requires: qqbar_wasm_module
function qqbar_read_and_free_str(ptr) {
  var Module = qqbar_wasm_module();
  var s = Module.UTF8ToString(ptr);
  Module.ccall("wasm_free_str", null, ["number"], [ptr]);
  return s;
}

//Provides: qqbar_split_lines
function qqbar_split_lines(s) {
  return s.length === 0 ? [] : s.split("\n");
}

// builds a jsoo-block OCaml array ([0, e0, e1, ...]) from a JS array
//Provides: qqbar_ocaml_array
function qqbar_ocaml_array(elems) {
  var arr = [0];
  for (var i = 0; i < elems.length; i++) arr.push(elems[i]);
  return arr;
}

//Provides: ml_qqbar_of_q
//Requires: caml_jsstring_of_string, caml_failwith, qqbar_wasm_module, qqbar_box
function ml_qqbar_of_q(s) {
  var jsStr = caml_jsstring_of_string(s);
  var h = qqbar_wasm_module().ccall("wasm_qqbar_of_q", "number", ["string"], [jsStr]);
  if (h === 0) caml_failwith("Qqbar.of_q: bad rational string");
  return qqbar_box(h);
}

//Provides: ml_qqbar_to_q_str
//Requires: caml_string_of_jsstring, qqbar_wasm_module, qqbar_unbox, qqbar_read_and_free_str
function ml_qqbar_to_q_str(a) {
  var ptr = qqbar_wasm_module().ccall("wasm_qqbar_to_q_str", "number", ["number"], [qqbar_unbox(a)]);
  return caml_string_of_jsstring(qqbar_read_and_free_str(ptr));
}

//Provides: ml_qqbar_is_rational
//Requires: qqbar_wasm_module, qqbar_unbox
function ml_qqbar_is_rational(a) {
  return qqbar_wasm_module().ccall("wasm_qqbar_is_rational", "number", ["number"], [qqbar_unbox(a)]);
}

//Provides: ml_qqbar_is_zero
//Requires: qqbar_wasm_module, qqbar_unbox
function ml_qqbar_is_zero(a) {
  return qqbar_wasm_module().ccall("wasm_qqbar_is_zero", "number", ["number"], [qqbar_unbox(a)]);
}

//Provides: ml_qqbar_neg
//Requires: qqbar_wasm_module, qqbar_unbox, qqbar_box
function ml_qqbar_neg(a) {
  var h = qqbar_wasm_module().ccall("wasm_qqbar_neg", "number", ["number"], [qqbar_unbox(a)]);
  return qqbar_box(h);
}

//Provides: ml_qqbar_inv
//Requires: qqbar_wasm_module, qqbar_unbox, qqbar_box
function ml_qqbar_inv(a) {
  var h = qqbar_wasm_module().ccall("wasm_qqbar_inv", "number", ["number"], [qqbar_unbox(a)]);
  return qqbar_box(h);
}

//Provides: ml_qqbar_sqrt
//Requires: qqbar_wasm_module, qqbar_unbox, qqbar_box
function ml_qqbar_sqrt(a) {
  var h = qqbar_wasm_module().ccall("wasm_qqbar_sqrt", "number", ["number"], [qqbar_unbox(a)]);
  return qqbar_box(h);
}

//Provides: ml_qqbar_add
//Requires: qqbar_wasm_module, qqbar_unbox, qqbar_box
function ml_qqbar_add(a, b) {
  var h = qqbar_wasm_module().ccall(
    "wasm_qqbar_add", "number", ["number", "number"], [qqbar_unbox(a), qqbar_unbox(b)],
  );
  return qqbar_box(h);
}

//Provides: ml_qqbar_sub
//Requires: qqbar_wasm_module, qqbar_unbox, qqbar_box
function ml_qqbar_sub(a, b) {
  var h = qqbar_wasm_module().ccall(
    "wasm_qqbar_sub", "number", ["number", "number"], [qqbar_unbox(a), qqbar_unbox(b)],
  );
  return qqbar_box(h);
}

//Provides: ml_qqbar_mul
//Requires: qqbar_wasm_module, qqbar_unbox, qqbar_box
function ml_qqbar_mul(a, b) {
  var h = qqbar_wasm_module().ccall(
    "wasm_qqbar_mul", "number", ["number", "number"], [qqbar_unbox(a), qqbar_unbox(b)],
  );
  return qqbar_box(h);
}

//Provides: ml_qqbar_div
//Requires: qqbar_wasm_module, qqbar_unbox, qqbar_box
function ml_qqbar_div(a, b) {
  var h = qqbar_wasm_module().ccall(
    "wasm_qqbar_div", "number", ["number", "number"], [qqbar_unbox(a), qqbar_unbox(b)],
  );
  return qqbar_box(h);
}

//Provides: ml_qqbar_equal
//Requires: qqbar_wasm_module, qqbar_unbox
function ml_qqbar_equal(a, b) {
  return qqbar_wasm_module().ccall(
    "wasm_qqbar_equal", "number", ["number", "number"], [qqbar_unbox(a), qqbar_unbox(b)],
  );
}

//Provides: ml_qqbar_cmp_re
//Requires: qqbar_wasm_module, qqbar_unbox
function ml_qqbar_cmp_re(a, b) {
  return qqbar_wasm_module().ccall(
    "wasm_qqbar_cmp_re", "number", ["number", "number"], [qqbar_unbox(a), qqbar_unbox(b)],
  );
}

//Provides: ml_qqbar_sgn_re
//Requires: qqbar_wasm_module, qqbar_unbox
function ml_qqbar_sgn_re(a) {
  return qqbar_wasm_module().ccall("wasm_qqbar_sgn_re", "number", ["number"], [qqbar_unbox(a)]);
}

//Provides: ml_qqbar_degree
//Requires: qqbar_wasm_module, qqbar_unbox
function ml_qqbar_degree(a) {
  return qqbar_wasm_module().ccall("wasm_qqbar_degree", "number", ["number"], [qqbar_unbox(a)]);
}

//Provides: ml_qqbar_get_d
//Requires: qqbar_wasm_module, qqbar_unbox
function ml_qqbar_get_d(a) {
  return qqbar_wasm_module().ccall("wasm_qqbar_get_d", "number", ["number"], [qqbar_unbox(a)]);
}

//Provides: ml_qqbar_minpoly
//Requires: caml_string_of_jsstring, qqbar_wasm_module, qqbar_unbox
//Requires: qqbar_read_and_free_str, qqbar_split_lines, qqbar_ocaml_array
function ml_qqbar_minpoly(a) {
  var ptr = qqbar_wasm_module().ccall("wasm_qqbar_minpoly", "number", ["number"], [qqbar_unbox(a)]);
  var parts = qqbar_split_lines(qqbar_read_and_free_str(ptr));
  return qqbar_ocaml_array(parts.map(caml_string_of_jsstring));
}

//Provides: ml_qqbar_express_in_field
//Requires: caml_string_of_jsstring, qqbar_wasm_module, qqbar_unbox
//Requires: qqbar_read_and_free_str, qqbar_split_lines, qqbar_ocaml_array
function ml_qqbar_express_in_field(gen, x, max_bits) {
  var ptr = qqbar_wasm_module().ccall(
    "wasm_qqbar_express_in_field", "number", ["number", "number", "number"],
    [qqbar_unbox(gen), qqbar_unbox(x), max_bits],
  );
  if (ptr === 0) return 0; // None
  var parts = qqbar_split_lines(qqbar_read_and_free_str(ptr));
  return [0, qqbar_ocaml_array(parts.map(caml_string_of_jsstring))]; // Some arr
}

//Provides: ml_qqbar_enclosure
//Requires: caml_string_of_jsstring, qqbar_wasm_module, qqbar_unbox, qqbar_read_and_free_str
function ml_qqbar_enclosure(a, prec) {
  var ptr = qqbar_wasm_module().ccall(
    "wasm_qqbar_enclosure", "number", ["number", "number"], [qqbar_unbox(a), prec],
  );
  var parts = qqbar_read_and_free_str(ptr).split("\n");
  return [0, caml_string_of_jsstring(parts[0]), caml_string_of_jsstring(parts[1]), caml_string_of_jsstring(parts[2])];
}

//Provides: ml_qqbar_real_roots
//Requires: caml_jsstring_of_string, caml_failwith, qqbar_wasm_module, qqbar_box
//Requires: qqbar_read_and_free_str, qqbar_split_lines, qqbar_ocaml_array
function ml_qqbar_real_roots(coeff_strs) {
  var jsStrs = [];
  for (var i = 1; i < coeff_strs.length; i++) jsStrs.push(caml_jsstring_of_string(coeff_strs[i]));
  var joined = jsStrs.join("\n");
  var ptr = qqbar_wasm_module().ccall("wasm_qqbar_real_roots", "number", ["string"], [joined]);
  if (ptr === 0) caml_failwith("Qqbar.real_roots_of_poly: bad integer string");
  var handles = qqbar_split_lines(qqbar_read_and_free_str(ptr)).map(Number);
  return qqbar_ocaml_array(handles.map(qqbar_box));
}

//Provides: ml_qqbar_roots_qqbar_poly
//Requires: qqbar_wasm_module, qqbar_unbox, qqbar_box
//Requires: qqbar_read_and_free_str, qqbar_split_lines, qqbar_ocaml_array
function ml_qqbar_roots_qqbar_poly(coeffs) {
  var handleStrs = [];
  for (var i = 1; i < coeffs.length; i++) handleStrs.push(String(qqbar_unbox(coeffs[i])));
  var joined = handleStrs.join("\n");
  var ptr = qqbar_wasm_module().ccall("wasm_qqbar_roots_qqbar_poly", "number", ["string"], [joined]);
  if (ptr === 0) return 0; // None
  var handles = qqbar_split_lines(qqbar_read_and_free_str(ptr)).map(Number);
  return [0, qqbar_ocaml_array(handles.map(qqbar_box))]; // Some arr
}
