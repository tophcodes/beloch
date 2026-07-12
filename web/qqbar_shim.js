// js_of_ocaml runtime shim for lib/qqbar.ml's C stubs (lib/qqbar_stubs.c,
// FLINT/Calcium — see decisions/0013-flint-qqbar-backend.md). jsoo cannot
// compile C, so every `external ... = "ml_qqbar_*"` primitive gets a JS
// stand-in here. None of them do real algebra: they all raise a Failure
// exception with a recognizable message, so a caller that reaches an
// irrational (qqbar) value in the browser build fails loudly instead of
// silently producing a wrong answer. lib/num.ml's Rat/Rat fast path never
// calls these, so pure-rational programs never hit this file at runtime.
//
// One function per `external` in lib/qqbar.ml, spike-scoped (all 20 as of
// 2026-07-13):

//Provides: ml_qqbar_of_q
//Requires: caml_failwith
function ml_qqbar_of_q(_q_str) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_of_q unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_to_q_str
//Requires: caml_failwith
function ml_qqbar_to_q_str(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_to_q_str unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_is_rational
//Requires: caml_failwith
function ml_qqbar_is_rational(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_is_rational unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_is_zero
//Requires: caml_failwith
function ml_qqbar_is_zero(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_is_zero unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_neg
//Requires: caml_failwith
function ml_qqbar_neg(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_neg unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_inv
//Requires: caml_failwith
function ml_qqbar_inv(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_inv unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_sqrt
//Requires: caml_failwith
function ml_qqbar_sqrt(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_sqrt unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_add
//Requires: caml_failwith
function ml_qqbar_add(_x, _y) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_add unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_sub
//Requires: caml_failwith
function ml_qqbar_sub(_x, _y) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_sub unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_mul
//Requires: caml_failwith
function ml_qqbar_mul(_x, _y) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_mul unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_div
//Requires: caml_failwith
function ml_qqbar_div(_x, _y) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_div unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_equal
//Requires: caml_failwith
function ml_qqbar_equal(_x, _y) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_equal unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_cmp_re
//Requires: caml_failwith
function ml_qqbar_cmp_re(_x, _y) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_cmp_re unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_sgn_re
//Requires: caml_failwith
function ml_qqbar_sgn_re(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_sgn_re unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_degree
//Requires: caml_failwith
function ml_qqbar_degree(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_degree unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_get_d
//Requires: caml_failwith
function ml_qqbar_get_d(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_get_d unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_minpoly
//Requires: caml_failwith
function ml_qqbar_minpoly(_x) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_minpoly unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_express_in_field
//Requires: caml_failwith
function ml_qqbar_express_in_field(_gen, _x, _prec) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_express_in_field unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_enclosure
//Requires: caml_failwith
function ml_qqbar_enclosure(_x, _prec) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_enclosure unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_real_roots
//Requires: caml_failwith
function ml_qqbar_real_roots(_coeff_strs) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_real_roots unsupported in js_of_ocaml build)");
}

//Provides: ml_qqbar_roots_qqbar_poly
//Requires: caml_failwith
function ml_qqbar_roots_qqbar_poly(_coeffs) {
  return caml_failwith("beloch: irrational value requires the native evaluator (ml_qqbar_roots_qqbar_poly unsupported in js_of_ocaml build)");
}
