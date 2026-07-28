# 0010 — Constructible real numbers for the irrational axioms

**Status:** Superseded by [0012](0012-real-algebraic-number-kernel.md)

## Context

[ADR 0008](0008-exact-rational-arithmetic.md) established ℚ (zarith) as the
number representation and noted explicitly that ℚ stops being closed at axiom 5
(the angle bisector) and axiom 6 (the cubic). Axioms 1–4 are all rational: line
through two points, perpendicular bisector, perpendicular through a point, and
the parallel — none require square roots over rational inputs. Axiom 5 (fold
placing one line onto another; Hull's O4) produces crease lines whose
coefficients lie in a degree-2-or-less extension of the base field
[hull2020, Lemma 3.9, ll. 2046–2052]. Repeated application builds a tower of
quadratic extensions: exactly the constructible numbers.

[hull2020] §3.2 Theorem 3.10 characterises the full origami number field: a
number is constructible by origami (all seven axioms) if and only if it lies in a
2-3 tower of field extensions over ℚ. The degree-2 part of that tower — the
quadratic tower — covers Beloch axioms 1–5 completely; cube roots arise only at
axiom 6 (the Beloch fold, Hull's O7). Axiom 5 lives entirely in the quadratic
sub-tower.

## Decision

Introduce `lib/num.ml` with a recursive type `t = Rat of Q.t | Ext of t * t * t`
where `Ext(a, b, d)` represents a + b√d (a, b, d ∈ `Num.t`). This is the full
tower of quadratic extensions over ℚ — i.e. the constructible real numbers —
sufficient for all axioms through axiom 5.

Key properties:

- **Exact sign.** `sign` recurses structurally: sign of `Rat q` is the sign of
  `q`; sign of `Ext(a, b, d)` reduces to `sign(a² − b²d)` at the `Rat` base via
  a canonical generator-ordering invariant that ensures generators always compare
  equal before nesting, keeping the recursion well-founded and terminating on
  tower height.
- **Equality without canonicalization.** Two values are equal iff
  `sign(x − y) = 0`. There is no attempt to put values into a canonical form
  (e.g. `√8` and `2√2` are recognised equal only via the sign test on their
  difference, not by rewriting). This avoids the complexity of a canonical form
  while keeping equality exact.
- **Rational fast-path.** Arithmetic on two `Rat` values stays `Rat`; the `Ext`
  constructor is only introduced by `sqrt` when the radicand is not a perfect
  rational square. Axioms 1–4 therefore produce no `Ext` nodes and pay no
  overhead over the previous ℚ representation.

The `Num` module exposes a narrow interface: constructors, `add`, `sub`, `mul`,
`neg`, `inv`, `div`, `sqrt`, `sign`, `compare`, `equal`, `to_float`. The
geometry core migrates onto this interface in v0.4.

## Alternatives considered

- **float64 + epsilon.** Rejected for the same reason as ADR 0008: tolerance
  comparisons reintroduce fuzziness at the foundation. Exact sign is the whole
  point.
- **Real-algebraic numbers via minimal polynomial + interval arithmetic.** Correct
  and general (covers cube roots, arbitrary algebraic numbers). Rejected for now:
  heavier than necessary — axiom 5 is a square-root-only axiom, and a
  min-poly+interval library is overkill for a quadratic tower. YAGNI until axioms
  6/7 force it.
- **Multi-quadratic extension ℚ(√d₁, √d₂, …) stored as a flat vector of
  rational coefficients.** Correct for the pure multi-quadratic case. Rejected:
  a strict incomplete subset of the constructible numbers per Theorem 3.10 — it
  cannot represent nested radicals like √(1 + √2) that axiom 5 can construct.

## Consequences

- `Num.t` is the new exact scalar. The geometry core (`Geom`, `Point`, `Line`)
  migrates from `Q.t` to `Num.t` in v0.4 alongside the axiom 5 implementation.
- Representation **blowup** on deep nesting is the accepted cost. Repeated
  applications of axiom 5 can produce `Ext` trees that grow exponentially in
  depth. This is a speed/size issue, never a correctness issue, and is not
  optimized — the project's correctness goal takes precedence and deep nesting
  is rare in practice.
- Axioms 6/7 extend `Num` to the degree-3 part of the 2-3 tower (cube roots via
  `Cbrt` or a polynomial-root constructor). The narrow `Num` interface is
  designed to absorb this extension without changing callers.
- `to_float` is the only place a `float` appears in the numeric core; it is
  output-only (serialisation to FOLD JSON), never fed back into computation.
