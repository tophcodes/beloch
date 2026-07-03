/* OCaml FFI to FLINT 3 qqbar (exact real algebraic numbers). ℚ values cross
   the boundary as decimal strings ("num/den"); polynomials as arrays of
   integer strings, low-first. GC rule: take Data_custom_val pointers only
   after all OCaml allocations in scope. */
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <flint/fmpq.h>
#include <flint/fmpz.h>
#include <flint/fmpz_poly.h>
#include <flint/arb.h>
#include <flint/qqbar.h>

#define Qqbar_val(v) ((qqbar_ptr) Data_custom_val(v))

static void ml_qqbar_finalize(value v) { qqbar_clear(Qqbar_val(v)); }

static struct custom_operations qqbar_ops = {
  "beloch.qqbar",
  ml_qqbar_finalize,
  custom_compare_default,
  custom_hash_default,
  custom_serialize_default,
  custom_deserialize_default,
  custom_compare_ext_default,
  custom_fixed_length_default
};

static value alloc_qqbar(void) {
  value v = caml_alloc_custom(&qqbar_ops, sizeof(qqbar_struct), 0, 1);
  qqbar_init(Qqbar_val(v));
  return v;
}

CAMLprim value ml_qqbar_of_q(value s) {
  CAMLparam1(s);
  CAMLlocal1(r);
  fmpq_t q;
  fmpq_init(q);
  if (fmpq_set_str(q, String_val(s), 10) != 0) {
    fmpq_clear(q);
    caml_failwith("Qqbar.of_q: bad rational string");
  }
  r = alloc_qqbar();
  qqbar_set_fmpq(Qqbar_val(r), q);
  fmpq_clear(q);
  CAMLreturn(r);
}

/* rational value as "num/den" string; only called when degree = 1 */
CAMLprim value ml_qqbar_to_q_str(value a) {
  CAMLparam1(a);
  CAMLlocal1(r);
  fmpq_t q;
  fmpq_init(q);
  qqbar_get_fmpq(q, Qqbar_val(a));
  char *s = fmpq_get_str(NULL, 10, q);
  r = caml_copy_string(s);
  flint_free(s);
  fmpq_clear(q);
  CAMLreturn(r);
}

CAMLprim value ml_qqbar_is_rational(value a) {
  return Val_bool(qqbar_is_rational(Qqbar_val(a)));
}

CAMLprim value ml_qqbar_is_zero(value a) {
  return Val_bool(qqbar_is_zero(Qqbar_val(a)));
}

#define UNOP(name, fn) \
  CAMLprim value name(value a) { \
    CAMLparam1(a); \
    CAMLlocal1(r); \
    r = alloc_qqbar(); \
    fn(Qqbar_val(r), Qqbar_val(a)); \
    CAMLreturn(r); \
  }

UNOP(ml_qqbar_neg, qqbar_neg)
UNOP(ml_qqbar_inv, qqbar_inv)
UNOP(ml_qqbar_sqrt, qqbar_sqrt)

#define BINOP(name, fn) \
  CAMLprim value name(value a, value b) { \
    CAMLparam2(a, b); \
    CAMLlocal1(r); \
    r = alloc_qqbar(); \
    fn(Qqbar_val(r), Qqbar_val(a), Qqbar_val(b)); \
    CAMLreturn(r); \
  }

BINOP(ml_qqbar_add, qqbar_add)
BINOP(ml_qqbar_sub, qqbar_sub)
BINOP(ml_qqbar_mul, qqbar_mul)
BINOP(ml_qqbar_div, qqbar_div)

CAMLprim value ml_qqbar_equal(value a, value b) {
  return Val_bool(qqbar_equal(Qqbar_val(a), Qqbar_val(b)));
}

CAMLprim value ml_qqbar_cmp_re(value a, value b) {
  return Val_int(qqbar_cmp_re(Qqbar_val(a), Qqbar_val(b)));
}

CAMLprim value ml_qqbar_sgn_re(value a) {
  return Val_int(qqbar_sgn_re(Qqbar_val(a)));
}

CAMLprim value ml_qqbar_degree(value a) {
  return Val_int((int) qqbar_degree(Qqbar_val(a)));
}

CAMLprim value ml_qqbar_get_d(value a) {
  arb_t x;
  arb_init(x);
  qqbar_get_arb(x, Qqbar_val(a), 53);
  double d = arf_get_d(arb_midref(x), ARF_RND_NEAR);
  arb_clear(x);
  return caml_copy_double(d);
}

/* minimal polynomial coefficients as integer strings, low-first (primitive,
   NOT monic — the OCaml wrapper normalizes) */
CAMLprim value ml_qqbar_minpoly(value a) {
  CAMLparam1(a);
  CAMLlocal2(res, tmp);
  slong deg = qqbar_degree(Qqbar_val(a));
  res = caml_alloc(deg + 1, 0);
  for (slong i = 0; i <= deg; i++) {
    /* re-take the pointer each iteration: caml_copy_string allocates */
    char *s = fmpz_get_str(NULL, 10, QQBAR_COEFFS(Qqbar_val(a)) + i);
    tmp = caml_copy_string(s);
    flint_free(s);
    Store_field(res, i, tmp);
  }
  CAMLreturn(res);
}

/* exact dyadic enclosure of the (real) value at precision prec:
   returns (a_str, b_str, exp_str) meaning [a*2^exp, b*2^exp] */
CAMLprim value ml_qqbar_enclosure(value av, value precv) {
  CAMLparam2(av, precv);
  CAMLlocal4(res, sa, sb, se);
  arb_t x;
  fmpz_t a, b, e;
  arb_init(x);
  fmpz_init(a); fmpz_init(b); fmpz_init(e);
  qqbar_get_arb(x, Qqbar_val(av), Int_val(precv));
  arb_get_interval_fmpz_2exp(a, b, e, x);
  char *s1 = fmpz_get_str(NULL, 10, a);
  char *s2 = fmpz_get_str(NULL, 10, b);
  char *s3 = fmpz_get_str(NULL, 10, e);
  sa = caml_copy_string(s1);
  sb = caml_copy_string(s2);
  se = caml_copy_string(s3);
  flint_free(s1); flint_free(s2); flint_free(s3);
  res = caml_alloc_tuple(3);
  Store_field(res, 0, sa);
  Store_field(res, 1, sb);
  Store_field(res, 2, se);
  arb_clear(x);
  fmpz_clear(a); fmpz_clear(b); fmpz_clear(e);
  CAMLreturn(res);
}

/* real roots (ascending is NOT guaranteed here; OCaml sorts) of the integer
   polynomial given as decimal strings, low-first */
CAMLprim value ml_qqbar_real_roots(value coeffs) {
  CAMLparam1(coeffs);
  CAMLlocal2(res, tmp);
  slong n = Wosize_val(coeffs);
  fmpz_poly_t p;
  fmpz_poly_init(p);
  for (slong i = 0; i < n; i++) {
    fmpz_t c;
    fmpz_init(c);
    if (fmpz_set_str(c, (char *) String_val(Field(coeffs, i)), 10) != 0) {
      fmpz_clear(c);
      fmpz_poly_clear(p);
      caml_failwith("Qqbar.real_roots_of_poly: bad integer string");
    }
    fmpz_poly_set_coeff_fmpz(p, i, c);
    fmpz_clear(c);
  }
  slong deg = fmpz_poly_degree(p);
  if (deg < 1) {
    fmpz_poly_clear(p);
    CAMLreturn(Atom(0));
  }
  qqbar_ptr roots = _qqbar_vec_init(deg);
  qqbar_roots_fmpz_poly(roots, p, 0);
  slong nreal = 0;
  for (slong i = 0; i < deg; i++)
    if (qqbar_is_real(roots + i)) nreal++;
  res = caml_alloc(nreal, 0);
  slong j = 0;
  for (slong i = 0; i < deg; i++) {
    if (qqbar_is_real(roots + i)) {
      tmp = alloc_qqbar();
      qqbar_set(Qqbar_val(tmp), roots + i);
      Store_field(res, j, tmp);
      j++;
    }
  }
  _qqbar_vec_clear(roots, deg);
  fmpz_poly_clear(p);
  CAMLreturn(res);
}

/* Roots of the SQUAREFREE polynomial with qqbar coefficients (low-first
   array of qqbar values). Returns Some (real roots) on success, None if
   FLINT's degree/bits limits would be exceeded (caller falls back).
   FLINT >= 3.6. */
CAMLprim value ml_qqbar_roots_qqbar_poly(value coeffs) {
  CAMLparam1(coeffs);
  CAMLlocal3(res, arr, tmp);
  slong len = Wosize_val(coeffs);
  if (len < 2) {
    /* constant polynomial: no roots; report success with empty array */
    res = caml_alloc(1, 0); /* Some */
    Store_field(res, 0, Atom(0));
    CAMLreturn(res);
  }
  qqbar_ptr cs = _qqbar_vec_init(len);
  for (slong i = 0; i < len; i++)
    qqbar_set(cs + i, Qqbar_val(Field(coeffs, i)));
  slong d = len - 1;
  qqbar_ptr roots = _qqbar_vec_init(d);
  int ok = _qqbar_roots_poly_squarefree(roots, cs, len, 10000, 100000);
  if (!ok) {
    _qqbar_vec_clear(roots, d);
    _qqbar_vec_clear(cs, len);
    CAMLreturn(Val_int(0)); /* None */
  }
  slong nreal = 0;
  for (slong i = 0; i < d; i++)
    if (qqbar_is_real(roots + i)) nreal++;
  arr = caml_alloc(nreal, 0);
  slong j = 0;
  for (slong i = 0; i < d; i++) {
    if (qqbar_is_real(roots + i)) {
      tmp = alloc_qqbar();
      qqbar_set(Qqbar_val(tmp), roots + i);
      Store_field(arr, j, tmp);
      j++;
    }
  }
  _qqbar_vec_clear(roots, d);
  _qqbar_vec_clear(cs, len);
  res = caml_alloc(1, 0); /* Some */
  Store_field(res, 0, arr);
  CAMLreturn(res);
}
