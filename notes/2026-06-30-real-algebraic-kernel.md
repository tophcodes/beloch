# 2026-06-30 — Real-algebraic number kernel (slice 1 of axiom 7)

Retired the quadratic `Ext` tower (ADR 0010) for a real-algebraic kernel
(ADR 0012): a number is `Rat q` or the unique real root of a squarefree
ℚ-polynomial in an isolating interval. New `lib/poly.ml` (ℚ-polynomials,
Sylvester resultant, Euclidean gcd/squarefree, Sturm, isolation). `lib/num.ml`
rewritten; public interface frozen (+ `real_roots`), so the geometry core
migrated with no API churn.

## Why the rewrite, not a Cbrt bolt-on

Axiom 7's crease is a common tangent to two parabolas → a general cubic with 1 or
3 real roots `[justin1986 §2–3, §4]`. The 3-root case is the casus irreducibilis:
real roots that are not real radicals. So `Cbrt` is provably too weak; we need
roots of arbitrary integer polynomials. Field target: K₃, closed under real roots
of x³+px+q `[justin1986 §8.4d]`.

## How

Arithmetic builds the result's defining polynomial by resultant via
evaluation+interpolation (numeric determinants only), then re-isolates; sign by
interval refinement; equal = sign(diff)=0; rationals collapse (0 critically).
Algorithms grounded to `[bpr2006]`. Cost: slower √-heavy axioms (resultants vs
a+b√d), accepted — the `Rat` fast-path keeps axioms 1–4 free.

## Squaring shortcut — deliberate deviation from the plan

The `Alg×Alg` squaring shortcut (`even_poly_half` in `mul a a`) was added beyond
the original plan to avoid a degree-16 resultant blowup that made `sqrt`-of-`sqrt`
(nested radicals) non-terminating. Without it, `mul a a` where `a` has a degree-4
defpoly produces a degree-16 result, and subsequent arithmetic escalates
uncontrollably. The shortcut is guarded to fire only on provably-same values
(physical poly equality `==` + identical interval endpoints), so two distinct roots
of the same polynomial cannot accidentally match. If the guard does not fire, `mul`
falls through to the exact resultant path, which is correct but slower — so
mis-firing conservatively is the only risk, and it is correctness-preserving.

## Next

Axiom 7 surface (`map .p onto --d and .q onto --e [toward .x]`) on top of this,
its own slice; parabola algebra pinned to `[hull2020]` then.
