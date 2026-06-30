# 2026-06-30 — Shared-field RUR kernel (`Field` in `Num.t`)

## The problem — irrational-crease blowup

Axiom 7's cubic root is irrational. Before this slice, `Num` used an `Ext(a,b,d)`
tower: every operation on an `Ext` value potentially doubles its representation
depth. Folding an irrational crease — which involves reflecting all face vertices
across it — produced nested `Ext` trees. A sequence of cross/fold operations on
such a crease triggered multivariate resultant chains; the doubling-the-cube fold
timed out at >25 minutes. This is the doubly-exponential blowup of naive
multivariate arithmetic described in [bpr2006 §12].

## The fix — `Field of {gen; coords}`, one shared generator

A `Field` value represents an element of `ℚ(α)`: a polynomial in `α` with rational
coefficients, where `α` is fixed by its irreducible minimal polynomial `gen`.
Concretely:

```
Field { gen : Q.t array;     (* coefficients of μ(x), irreducible over ℚ *)
        coords : Q.t array } (* coords.(i) = coefficient of αⁱ *)
```

`gen` has degree ≥ 2 (degree 3 for a typical axiom-7 root). All arithmetic
(`add`, `mul`, `neg`, `inv`) stays inside `ℚ(α)`: multiplication reduces modulo
`gen` (polynomial division); inversion uses the extended Euclidean algorithm in
`ℚ[x]/(gen)` — always succeeds because `gen` is irreducible. Zero-test is
syntactic (all coords zero).

The key insight is that **all coordinates of a single axiom-7 crease share the
same `α`**, so reflecting a point across that crease never leaves `ℚ(α)`. The
field arithmetic is bounded-degree throughout the fold sequence. This is the
single-generator / Rational Univariate Representation principle [bpr2006 §12.4].

## Exact certification of roots

`Num.real_roots` computes the cubic's roots exactly:

1. `Mpoly` eliminates variables by resultant to produce a ℚ-coefficient
   univariate polynomial whose roots are a superset of the real roots.
2. Cauchy/separation bounds [bpr2006 §10.1-10.2] isolate each root in a rational
   interval.
3. Sign-at-roots evaluation [bpr2006 §10.4] certifies the correct count and
   ordering within each interval.

Roots that factor out (rational roots, degree-2 irreducible factors) are extracted
by `minimal_poly_in`: the irreducible factor of the superset polynomial containing
that root becomes `gen`. This gives the tightest possible `Field` representation
and keeps the irreducibility guarantee that makes inversion and zero-test cheap.

## The payoff — >25 min → ~0.1 ms

With `Field`, the double-cube fold (`examples/double-cube.bel`) finishes in ~0.1 ms.
Without it (bare `Ext` tower on the cubic root), the same fold timed out after
>25 minutes via growing resultant chains. The `Field` branch is triggered only for
axiom-7 roots; all earlier axioms are unaffected.

## Documented limitation

Cross-field and higher-degree cases (where the minimal polynomial has degree ≥ 4
or involves a composite / non-primitive extension — e.g. `∛2 + √3`) fall back to
the slower-but-exact `Alg` path. A general factorizer and primitive-element
computation (to always find the single shared generator for a mix of algebraic
numbers) would handle these; that is a future follow-up. The fallback is
documented in the kernel source and in ADR 0012.

## References

[bpr2006 §12] — doubly-exponential blowup of naive multivariate arithmetic.
[bpr2006 §12.4] — Rational Univariate Representation; single-generator field.
[bpr2006 §10.1-10.2] — Cauchy/separation bounds for root isolation.
[bpr2006 §10.4] — sign-at-roots certification in a real closed field.
