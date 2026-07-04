/* Spike FFI: root-finding of a polynomial with algebraic coefficients via
   FLINT 3's Calcium (ca_t), to compare against qqbar's
   _qqbar_roots_poly_squarefree at high coefficient-field degree.

   Coefficients cross the boundary as an OCaml Qqbar.t array (custom blocks
   wrapping qqbar_struct, layout as in lib/qqbar_stubs.c). Real roots come back
   as a Qqbar.t array (converted via ca_get_qqbar), or None when ca_poly_roots
   cannot split the polynomial in the field. Throwaway spike code. */
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <flint/flint.h>
#include <flint/qqbar.h>
#include <flint/ca.h>
#include <flint/ca_poly.h>
#include <flint/ca_vec.h>

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

/* Qqbar.t array (low-first coeffs) -> Qqbar.t array option (real roots) */
CAMLprim value ml_ca_real_roots(value coeffs) {
  CAMLparam1(coeffs);
  CAMLlocal3(result, arr, q);

  slong n = Wosize_val(coeffs);
  ca_ctx_t ctx;
  ca_ctx_init(ctx);
  ca_poly_t poly;
  ca_poly_init(poly, ctx);
  {
    ca_t tmp;
    ca_init(tmp, ctx);
    for (slong i = 0; i < n; i++) {
      ca_set_qqbar(tmp, Qqbar_val(Field(coeffs, i)), ctx);
      ca_poly_set_coeff_ca(poly, i, tmp, ctx);
    }
    ca_clear(tmp, ctx);
  }

  slong deg = n > 0 ? n - 1 : 0;
  ca_vec_t roots;
  ca_vec_init(roots, 0, ctx);
  ulong *exp = deg > 0 ? flint_malloc(sizeof(ulong) * deg) : NULL;

  int ok = ca_poly_roots(roots, exp, poly, ctx);

  if (!ok) {
    if (exp) flint_free(exp);
    ca_vec_clear(roots, ctx);
    ca_poly_clear(poly, ctx);
    ca_ctx_clear(ctx);
    CAMLreturn(Val_int(0)); /* None */
  }

  slong nr = ca_vec_length(roots, ctx);
  /* convert each root to qqbar (C heap), keep the real ones */
  qqbar_ptr rr = nr > 0 ? flint_malloc(sizeof(qqbar_struct) * nr) : NULL;
  slong count = 0;
  int convert_ok = 1;
  for (slong i = 0; i < nr; i++) {
    qqbar_init(rr + count);
    if (!ca_get_qqbar(rr + count, ca_vec_entry(roots, i), ctx)) {
      qqbar_clear(rr + count);
      convert_ok = 0;
      break;
    }
    if (qqbar_is_real(rr + count))
      count++;
    else
      qqbar_clear(rr + count);
  }

  if (!convert_ok) {
    for (slong i = 0; i < count; i++) qqbar_clear(rr + i);
    if (rr) flint_free(rr);
    if (exp) flint_free(exp);
    ca_vec_clear(roots, ctx);
    ca_poly_clear(poly, ctx);
    ca_ctx_clear(ctx);
    CAMLreturn(Val_int(0)); /* None: a root not representable as qqbar */
  }

  arr = caml_alloc(count, 0);
  for (slong i = 0; i < count; i++) {
    q = alloc_qqbar();
    qqbar_set(Qqbar_val(q), rr + i);
    Store_field(arr, i, q);
    qqbar_clear(rr + i);
  }
  if (rr) flint_free(rr);
  if (exp) flint_free(exp);
  ca_vec_clear(roots, ctx);
  ca_poly_clear(poly, ctx);
  ca_ctx_clear(ctx);

  result = caml_alloc(1, 0); /* Some arr */
  Store_field(result, 0, arr);
  CAMLreturn(result);
}
