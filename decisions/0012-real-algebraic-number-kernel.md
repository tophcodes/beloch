# 0012 — Real-algebraic number kernel

**Status:** Accepted (supersedes [0010](archive/0010-constructible-real-numbers.md); `Alg` representation superseded by [0013](0013-flint-qqbar-backend.md))

## Context

[ADR 0010](archive/0010-constructible-real-numbers.md) gave `Num` a quadratic-extension
tower (`Rat | Ext(a,b,d)` = a+b√d) — the constructible reals, enough for axioms
1–6 (square roots only) — and explicitly deferred the degree-3 kernel until
axioms 6/7 forced it.

Axiom 7 (Justin ⑦, the Beloch fold) forces it. Its crease is a common tangent to
two parabolas, i.e. a root of a general cubic `[justin1986 §2–3]` with 1 or 3
real roots `[justin1986 §4, remark]`. When there are three real roots the *casus
irreducibilis* applies: the real roots cannot be written with real radicals
(Cardano routes through complex cube roots). A `Cbrt` generator is therefore
provably insufficient. Justin names the target field exactly: K₃ is the smallest
real field closed under the real roots of `x³ + px + q = 0` `[justin1986 §8.4d]`;
`[hull2020]` characterises origami numbers by their minimal polynomials.

## Decision

Represent every Beloch number as a **real algebraic number** in the standard
isolating-interval form `[bpr2006 Ch. 10]`:

    type t = Rat of Q.t | Alg of { poly : Poly.t; lo : Q.t; hi : Q.t }

`Alg` is the unique real root of the squarefree ℚ-polynomial `poly` inside the
open interval `(lo, hi)`; the root is irrational (rationals collapse to `Rat`).

- **Arithmetic** builds the result's defining polynomial by resultant, computed
  via evaluation + Lagrange interpolation (numeric Sylvester determinants only,
  no symbolic polynomial determinants) `[bpr2006 Ch. 4]`, then re-isolates the
  result interval.
- **Sign / compare** refine the interval (`compare x y = sign (x−y)`); **equal**
  is `sign (x−y) = 0`. Sturm sequences count and isolate roots
  `[bpr2006 Ch. 2, 9, 10]`.
- **Rational fast-path** (`Rat`) keeps axioms 1–4 in ℚ with no resultant cost.
- New constructor `real_roots` returns the real roots (ascending) of a
  polynomial with `Num` coefficients — what axiom 7 calls.

The elegant `Ext` tower is **retired**: one representation for all irrationals.

## Alternatives considered

- **`Cbrt` generator.** Rejected: casus irreducibilis — real radicals cannot
  express the 3-real-root case, which is exactly trisection / heptagon.
- **Keep `Ext` as a quadratic fast-path under the algebraic layer.** Rejected
  now (YAGNI): reintroduces the dual-irrational-path complexity we are
  collapsing; revisit only if profiling demands it.
- **Thom encoding** instead of isolating intervals. Deferred: intervals suffice
  `[bpr2006 Ch. 10]`.

## Consequences

- √-heavy axioms 5/6 lose the closed-form `a+b√d` speed (resultants are
  heavier); deep nesting grows defining-polynomial degree. Accepted —
  correctness over speed, the same bargain as ADR 0010, now paid in full. The
  `Rat` fast-path keeps the common case free.
- The public `Num` interface is unchanged (plus `real_roots`), so the geometry
  core migrated without API churn.
- `to_float` stays the only float, output-only.
- Unblocks axiom 7 (Justin ⑦) with no further kernel change.
