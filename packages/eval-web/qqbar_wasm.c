/* Flat-ABI C shim for lib/qqbar.ml's FLINT/Calcium qqbar backend, compiled to
 * wasm via emscripten.
 * Near-mechanical port of lib/qqbar_stubs.c: same FLINT 3.6 API sequences,
 * but `qqbar_t` crosses the boundary as a plain `int` handle (a heap pointer
 * cast to int) instead of an OCaml custom block, and every op is exposed as
 * a free C function callable from JS via ccall/cwrap. No OCaml here.
 *
 * String/array marshalling (see plan for the full rationale):
 *   - single strings ("num/den", "\n"-joined lists) cross as malloc'd char*;
 *     JS reads with UTF8ToString then must call wasm_free_str to release it.
 *   - arrays cross as ONE "\n"-joined char*. For real_roots the *input*
 *     poly coefficients also arrive as one "\n"-joined char*.
 *   - qqbar-handle arrays cross as "\n"-joined decimal handle strings.
 *   - Option-returning ops (express_in_field, roots_qqbar_poly) use a NULL
 *     char* for None; a non-NULL (possibly empty "") string is Some.
 *   - of_q's bad-input path (native: caml_failwith) returns handle 0.
 *   - real_roots' bad-input path (native: caml_failwith) returns NULL.
 *     (Different sentinel per function is fine: each has its own JS glue.)
 */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <flint/fmpq.h>
#include <flint/fmpz.h>
#include <flint/fmpz_poly.h>
#include <flint/fmpq_poly.h>
#include <flint/arb.h>
#include <flint/qqbar.h>

#define H(h) ((qqbar_ptr) (void *) (long) (h))
#define HANDLE(p) ((int) (long) (p))

/* ---------------------------------------------------------------------- */
/* lifetime                                                                */
/* ---------------------------------------------------------------------- */

static qqbar_ptr new_qqbar(void) {
  qqbar_ptr p = (qqbar_ptr) malloc(sizeof(qqbar_struct));
  qqbar_init(p);
  return p;
}

int wasm_qqbar_alloc(void) { return HANDLE(new_qqbar()); }

void wasm_qqbar_free(int h) {
  if (!h) return;
  qqbar_ptr p = H(h);
  qqbar_clear(p);
  free(p);
}

/* releases a char* returned by any wasm_qqbar_* string-returning function */
void wasm_free_str(char *s) { free(s); }

/* ---------------------------------------------------------------------- */
/* small growable string builder, used for "\n"-joined outputs            */
/* ---------------------------------------------------------------------- */

typedef struct { char *buf; size_t len; size_t cap; } sbuf;

static void sbuf_init(sbuf *b) {
  b->cap = 64;
  b->len = 0;
  b->buf = malloc(b->cap);
  b->buf[0] = 0;
}

static void sbuf_append(sbuf *b, const char *s) {
  size_t n = strlen(s);
  if (b->len + n + 1 > b->cap) {
    while (b->len + n + 1 > b->cap) b->cap *= 2;
    b->buf = realloc(b->buf, b->cap);
  }
  memcpy(b->buf + b->len, s, n);
  b->len += n;
  b->buf[b->len] = 0;
}

static void sbuf_append_handle(sbuf *b, int first, qqbar_ptr rp) {
  char numbuf[32];
  snprintf(numbuf, sizeof(numbuf), "%d", HANDLE(rp));
  if (!first) sbuf_append(b, "\n");
  sbuf_append(b, numbuf);
}

/* split a "\n"-joined string into malloc'd C-string tokens; sets *count.
 * an empty input string yields *count = 0, out = NULL. */
static char **split_lines(const char *s, slong *count) {
  if (s == NULL || s[0] == '\0') {
    *count = 0;
    return NULL;
  }
  slong n = 1;
  for (const char *p = s; *p; p++)
    if (*p == '\n') n++;
  char **out = malloc(n * sizeof(char *));
  slong idx = 0;
  const char *start = s;
  for (const char *p = s;; p++) {
    if (*p == '\n' || *p == '\0') {
      size_t len = (size_t) (p - start);
      char *tok = malloc(len + 1);
      memcpy(tok, start, len);
      tok[len] = 0;
      out[idx++] = tok;
      if (*p == '\0') break;
      start = p + 1;
    }
  }
  *count = idx;
  return out;
}

static void free_lines(char **lines, slong count) {
  for (slong i = 0; i < count; i++) free(lines[i]);
  free(lines);
}

/* ---------------------------------------------------------------------- */
/* construction / conversion                                              */
/* ---------------------------------------------------------------------- */

int wasm_qqbar_of_q(const char *s) {
  fmpq_t q;
  fmpq_init(q);
  if (fmpq_set_str(q, s, 10) != 0) {
    fmpq_clear(q);
    return 0; /* sentinel: bad rational string */
  }
  qqbar_ptr r = new_qqbar();
  qqbar_set_fmpq(r, q);
  fmpq_clear(q);
  return HANDLE(r);
}

/* rational value as "num/den" string; only called when degree = 1 */
char *wasm_qqbar_to_q_str(int a) {
  fmpq_t q;
  fmpq_init(q);
  qqbar_get_fmpq(q, H(a));
  char *s = fmpq_get_str(NULL, 10, q);
  char *r = strdup(s);
  flint_free(s);
  fmpq_clear(q);
  return r;
}

int wasm_qqbar_is_rational(int a) { return qqbar_is_rational(H(a)); }
int wasm_qqbar_is_zero(int a) { return qqbar_is_zero(H(a)); }

/* ---------------------------------------------------------------------- */
/* arithmetic                                                              */
/* ---------------------------------------------------------------------- */

#define UNOP(name, fn) \
  int name(int a) { \
    qqbar_ptr r = new_qqbar(); \
    fn(r, H(a)); \
    return HANDLE(r); \
  }

UNOP(wasm_qqbar_neg, qqbar_neg)
UNOP(wasm_qqbar_inv, qqbar_inv)
UNOP(wasm_qqbar_sqrt, qqbar_sqrt)

#define BINOP(name, fn) \
  int name(int a, int b) { \
    qqbar_ptr r = new_qqbar(); \
    fn(r, H(a), H(b)); \
    return HANDLE(r); \
  }

BINOP(wasm_qqbar_add, qqbar_add)
BINOP(wasm_qqbar_sub, qqbar_sub)
BINOP(wasm_qqbar_mul, qqbar_mul)
BINOP(wasm_qqbar_div, qqbar_div)

int wasm_qqbar_equal(int a, int b) { return qqbar_equal(H(a), H(b)); }
int wasm_qqbar_cmp_re(int a, int b) { return qqbar_cmp_re(H(a), H(b)); }
int wasm_qqbar_sgn_re(int a) { return qqbar_sgn_re(H(a)); }
int wasm_qqbar_degree(int a) { return (int) qqbar_degree(H(a)); }

double wasm_qqbar_get_d(int a) {
  arb_t x;
  arb_init(x);
  qqbar_get_arb(x, H(a), 53);
  double d = arf_get_d(arb_midref(x), ARF_RND_NEAR);
  arb_clear(x);
  return d;
}

/* ---------------------------------------------------------------------- */
/* minimal polynomial: integer-string coefficients, low-first, "\n"-joined */
/* ---------------------------------------------------------------------- */

char *wasm_qqbar_minpoly(int a) {
  qqbar_ptr x = H(a);
  slong deg = qqbar_degree(x);
  sbuf b;
  sbuf_init(&b);
  for (slong i = 0; i <= deg; i++) {
    if (i > 0) sbuf_append(&b, "\n");
    char *s = fmpz_get_str(NULL, 10, QQBAR_COEFFS(x) + i);
    sbuf_append(&b, s);
    flint_free(s);
  }
  return b.buf;
}

/* ---------------------------------------------------------------------- */
/* express_in_field: x as a "\n"-joined "num/den" poly in gen, or NULL     */
/* ---------------------------------------------------------------------- */

char *wasm_qqbar_express_in_field(int gen, int x, int max_bits) {
  slong mb = max_bits;
  fmpq_poly_t p;
  fmpq_poly_init(p);
  int ok = qqbar_express_in_field(p, H(gen), H(x), mb, 0, 4 * mb);
  if (!ok) {
    fmpq_poly_clear(p);
    return NULL; /* None */
  }
  slong len = fmpq_poly_length(p);
  sbuf b;
  sbuf_init(&b);
  fmpq_t c;
  fmpq_init(c);
  for (slong i = 0; i < len; i++) {
    if (i > 0) sbuf_append(&b, "\n");
    fmpq_poly_get_coeff_fmpq(c, p, i);
    char *s = fmpq_get_str(NULL, 10, c);
    sbuf_append(&b, s);
    flint_free(s);
  }
  fmpq_clear(c);
  fmpq_poly_clear(p);
  return b.buf; /* Some (possibly "") */
}

/* ---------------------------------------------------------------------- */
/* exact dyadic enclosure: "a\nb\ne" meaning [a*2^e, b*2^e]                */
/* ---------------------------------------------------------------------- */

char *wasm_qqbar_enclosure(int a, int prec) {
  arb_t x;
  fmpz_t fa, fb, fe;
  arb_init(x);
  fmpz_init(fa);
  fmpz_init(fb);
  fmpz_init(fe);
  qqbar_get_arb(x, H(a), prec);
  arb_get_interval_fmpz_2exp(fa, fb, fe, x);
  char *s1 = fmpz_get_str(NULL, 10, fa);
  char *s2 = fmpz_get_str(NULL, 10, fb);
  char *s3 = fmpz_get_str(NULL, 10, fe);
  sbuf b;
  sbuf_init(&b);
  sbuf_append(&b, s1);
  sbuf_append(&b, "\n");
  sbuf_append(&b, s2);
  sbuf_append(&b, "\n");
  sbuf_append(&b, s3);
  flint_free(s1);
  flint_free(s2);
  flint_free(s3);
  arb_clear(x);
  fmpz_clear(fa);
  fmpz_clear(fb);
  fmpz_clear(fe);
  return b.buf;
}

/* ---------------------------------------------------------------------- */
/* real roots of an integer polynomial (input coeffs: one "\n"-joined     */
/* decimal-string char*, low-first); output: "\n"-joined qqbar handles.   */
/* NULL on a bad integer-string input (mirrors native caml_failwith).     */
/* ---------------------------------------------------------------------- */

char *wasm_qqbar_real_roots(const char *coeffs_joined) {
  slong n;
  char **lines = split_lines(coeffs_joined, &n);
  fmpz_poly_t p;
  fmpz_poly_init(p);
  int bad = 0;
  for (slong i = 0; i < n; i++) {
    fmpz_t c;
    fmpz_init(c);
    if (fmpz_set_str(c, lines[i], 10) != 0) {
      fmpz_clear(c);
      bad = 1;
      break;
    }
    fmpz_poly_set_coeff_fmpz(p, i, c);
    fmpz_clear(c);
  }
  free_lines(lines, n);
  if (bad) {
    fmpz_poly_clear(p);
    return NULL; /* sentinel: bad integer string */
  }
  slong deg = fmpz_poly_degree(p);
  if (deg < 1) {
    fmpz_poly_clear(p);
    return strdup("");
  }
  qqbar_ptr roots = _qqbar_vec_init(deg);
  qqbar_roots_fmpz_poly(roots, p, 0);
  sbuf b;
  sbuf_init(&b);
  int first = 1;
  for (slong i = 0; i < deg; i++) {
    if (qqbar_is_real(roots + i)) {
      qqbar_ptr rp = new_qqbar();
      qqbar_set(rp, roots + i);
      sbuf_append_handle(&b, first, rp);
      first = 0;
    }
  }
  _qqbar_vec_clear(roots, deg);
  fmpz_poly_clear(p);
  return b.buf;
}

/* ---------------------------------------------------------------------- */
/* real roots of a SQUAREFREE qqbar-coefficient polynomial (input: "\n"-  */
/* joined decimal qqbar handles, low-first); output: "\n"-joined qqbar    */
/* handles, or NULL if FLINT's degree/bits limits would be exceeded.      */
/* ---------------------------------------------------------------------- */

char *wasm_qqbar_roots_qqbar_poly(const char *coeffs_joined) {
  slong n;
  char **lines = split_lines(coeffs_joined, &n);
  if (n < 2) {
    free_lines(lines, n);
    return strdup(""); /* constant polynomial: no roots, Some [] */
  }
  qqbar_ptr cs = _qqbar_vec_init(n);
  for (slong i = 0; i < n; i++) {
    long h = strtol(lines[i], NULL, 10);
    qqbar_set(cs + i, H((int) h));
  }
  free_lines(lines, n);
  slong d = n - 1;
  qqbar_ptr roots = _qqbar_vec_init(d);
  int ok = _qqbar_roots_poly_squarefree(roots, cs, n, 10000, 100000);
  if (!ok) {
    _qqbar_vec_clear(roots, d);
    _qqbar_vec_clear(cs, n);
    return NULL; /* None */
  }
  sbuf b;
  sbuf_init(&b);
  int first = 1;
  for (slong i = 0; i < d; i++) {
    if (qqbar_is_real(roots + i)) {
      qqbar_ptr rp = new_qqbar();
      qqbar_set(rp, roots + i);
      sbuf_append_handle(&b, first, rp);
      first = 0;
    }
  }
  _qqbar_vec_clear(roots, d);
  _qqbar_vec_clear(cs, n);
  return b.buf; /* Some (possibly "") */
}
