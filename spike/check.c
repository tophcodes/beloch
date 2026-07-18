/* Phase 0 spike: prove FLINT 3.6's qqbar (algebraic-number) backend runs
 * correctly under wasm/node. Computes sqrt(2) via qqbar and prints its
 * double approximation. Expected output: 1.41421356
 *
 * qqbar_get_d isn't a public qqbar.h entry point (it lives behind the `gr`
 * ring wrapper in src/gr/qqbar.c); the public path it uses internally is
 * qqbar_get_arb() + arf_get_d(arb_midref(...), ARF_RND_NEAR), reproduced
 * here directly against qqbar.h + arb.h.
 */
#include <stdio.h>
#include <flint/qqbar.h>
#include <flint/arb.h>

int main(void) {
    qqbar_t x;
    arb_t t;

    qqbar_init(x);
    qqbar_set_ui(x, 2);      /* x = 2 */
    qqbar_sqrt(x, x);        /* x = sqrt(2), exact algebraic number */

    arb_init(t);
    qqbar_get_arb(t, x, 64); /* numerical enclosure at 64 bits */
    double d = arf_get_d(arb_midref(t), ARF_RND_NEAR);

    printf("%.8f\n", d);     /* expect 1.41421356 */

    arb_clear(t);
    qqbar_clear(x);
    return 0;
}
