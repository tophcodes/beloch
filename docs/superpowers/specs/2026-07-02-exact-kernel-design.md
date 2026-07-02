# Exact kernel: correct comparisons + field joins

**Date:** 2026-07-02 · **Issues:** #23, #33 · **Status:** approved design

Two slices. Slice 1 restores the kernel's one hard guarantee (exact sign
determination) and removes the root-isolation wall. Slice 2 removes the
cross-field Alg fallback by joining fields pairwise with a primitive element,
under a relaxed (squarefree, D5-style) generator invariant. Slice 1 ships
before Slice 2 and provides the measurement baseline for #33's verdict.

## Motivation (measured, 2026-07-02)

- **Correctness (#23):** `Num.equal x y` returns `true` for two *distinct*
  roots x ≈ +10⁻⁴, y ≈ −10⁻⁴ of the quartic x⁴ − 5x² + 5·10⁻⁸. Root cause is
  in `select_root` (`lib/num.ml:216`): a zero-shortcut declares the result 0
  when the defining polynomial has 0 as a root *and* a fixed width-1 enclosure
  straddles 0. For `sub x y` with x, y roots of the same polynomial, the
  resultant always has 0 as a root, so any |x−y| < ~1 collapses to `zero`.
- **Isolation wall (#23):** `Num.real_roots` on the same quartic: 0.07 s →
  0.39 s → 3.47 s → timeout (>150 s) for ε = 5·10⁻¹² … 5·10⁻²⁰. Prime suspect:
  `divisors` (`lib/num.ml:69`) does trial division up to √n; clearing
  denominators at ε = 5·10⁻²⁰ makes n ~ 2·10¹⁹ → ~4.5·10⁹ divisions. The
  resultant is *not* the slow step at these degrees.
- **Cross-field cliff (#33):** `scratch/probe.ml`: axiom 7 with rational
  coordinates completes in ~0 ms; the same fold with p.x = √2/4 (one prior
  square-root fold) exceeds a 120 s timeout via the documented
  Field→Alg fallback (`log_alg_fallback`) and its unnormalized resultant
  chains (degree multiplies per operation).
- **Field arithmetic is cheap at realistic degrees** (`scratch/fieldbench.ml`,
  small-coefficient generators, grown coordinate numerators): mul at degree 4
  ≈ 6 µs, degree 9 ≈ 76 µs, degree 27 ≈ 2.4 ms. A fold ≈ 2000 mul + ~20 inv,
  so ℚ(√2,√5) costs ~15 ms/fold. **But `Poly.inv_mod` blows up** (degree 12:
  36–144 ms; degree 27: 3.8 s): the naive Euclidean remainder sequence has
  exponential coefficient growth. Join construction at low degree is trivial
  (deg 2×3 or 3×3: < 1 ms total).

Conclusion: exactness is not the cost — the naive algorithms are. All fixes
below stay exact.

## Slice 1 — #23: exact comparisons + isolation

### 1a. `select_root` zero handling

Remove the zero-shortcut. Treat 0 as an ordinary root candidate: refine the
result enclosure until it lies inside exactly one isolating interval of the
squarefree defining polynomial s; if that interval is the one containing the
root 0 (i.e. s(0) = 0 and 0 ∈ interval), return `zero`, otherwise `make` the
Alg. Termination: distinct roots of s have positive separation, and the
enclosure width halves per step — no fixed cutoffs anywhere.

### 1b. Rational-root search without trial division

Replace the `divisors`-based candidate enumeration in `rational_roots_in`. A
rational root p/q of the integer-cleared polynomial has q | aₙ. Per isolating
interval: refine until width < 1/aₙ², at which point the interval contains at
most one rational with denominator ≤ aₙ; find it (if any) by continued-fraction
best approximation (Stern–Brocot), verify by exact evaluation. O(log) refinement
steps instead of O(√aₙ) divisions. `divisors` is deleted.

### 1c. Descartes-based isolation

Replace the Sturm-bisection loop in `Poly.isolate_roots` with Descartes'
rule of signs on (0,1) via Möbius transforms (VCA / bpr2006-style 0/1 test)
[bpr2006, Ch. 10; Descartes' law Ch. 2]. Sturm sequences remain for
`count_roots_in` (counting in externally supplied intervals).

### 1d. Tests

- The close-roots quartic as an equal/compare regression (issue repro:
  `Num.equal x y = false`, `Num.compare x y = 1` for the two roots near 0).
- The ε-ladder (5·10⁻⁸ … 5·10⁻²⁰) on `Num.real_roots`, with a per-case time
  budget of 1 s in the test.
- Existing suite stays green (`make` collapse-to-Rat behavior unchanged).

## Slice 2 — pairwise field joins (D5-style)

### 2a. Relaxed generator invariant

`Field.gen` becomes **squarefree + isolating interval** (the structure already
carries `lo`/`hi`); irreducibility is no longer required. Consequences, per
Lazard's remark [ddd1985; duval1994, §2–3]:

- **Zero-test** becomes semantic: interval-Horner fast path (refine α's
  interval; if the value's enclosure excludes 0, done); exact fallback:
  g = gcd(gen, coords), value is 0 iff g has a root in (lo, hi) (Sturm count).
  When it does, gen := g (representation shrinks).
- **Inversion** splits lazily: g = gcd(gen, coords); if g has no root in the
  interval, gen := gen/g (still has α as root, now coprime to coords), then
  extended Euclid as today.
- `mk_field`'s coords-normalization and rational-collapse checks route through
  the semantic zero-test.

### 2b. Subresultant PRS (prerequisite)

`Poly.gcd` and `Poly.inv_mod` move from the naive remainder sequence to a
content-stripped / subresultant PRS [bpr2006, Ch. 8] to bound coefficient
growth. Measured requirement: without this, inv at degree ≥ 9 is 8–144 ms and
degree 27 is seconds — dead with *any* join policy. Target: inv within a small
constant factor of mul at the same degree. `fieldbench` re-run confirms.

### 2c. The join

When two `Field` values with different generators (or a `Field` and a foreign
`Alg`) meet in +/·:

1. For k = 1, 2, …: candidate γ = α + kβ. Defining polynomial
   R = squarefree(Res_y(A(x − ky), B(y))) via the existing `res_interp`;
   isolating interval for γ from the operands' intervals, refined until
   isolating.
2. Re-express the operands: compute gcd over ℚ(γ) of A(x) and B((γ − x)/k)
   in ℚ(γ)[x] (arithmetic = the new field's own ops, including 2a inversion).
   If the gcd is linear, α = −c₀/c₁ gives embed_α : Poly.t (coords of α in γ),
   and embed_β = (γ − α)/k. If the gcd has degree > 1, k was bad — try the
   next k (only finitely many bad k exist).
3. Memoize: cache (gen_α, gen_β) → (gen_γ, embed_α, embed_β). Coordinate
   migration of a value is compose + rem — cheap. The cache is the only state
   in `Num`. The key is the full generator identity **including the isolating
   interval** — two roots of the same polynomial are different generators and
   must not share a cache entry.

`log_alg_fallback` call sites are replaced by the join. The fallback path
(`to_alg` + resultant arithmetic) remains as the correctness baseline and
escape hatch, but should no longer be reachable from geometry code.

### 2d. Alg ≅ Field

An `Alg {poly; lo; hi}` is exactly a field element: gen = (poly, lo, hi),
coords = x. Cross Alg/Field and Alg/Alg operations route through the same join
machinery. The `Alg` constructor stays as a representation (values whose field
nobody joined yet); only operation routing changes.

### 2e. Tests + #33 verdict

- Unit: arithmetic identities in ℚ(√2,√5) — e.g. (√2+√5)² = 7+2√10,
  (√2·√5)² = 10, 1/(√2+√5) exact; sign/compare across joined values.
- Regression: `examples/double-cube.bel` stays ~ms; ε-ladder from Slice 1
  stays within budget.
- Benchmark (`scratch/probe.ml` extended into a small suite): axiom 7 with
  p.x = √2/4 and p.x = (√2+√3)/8 (today: >120 s timeout; target:
  milliseconds); a ~20-step model with stacked cubic folds (degrees 9, 27).
- Deliverable for #33: the measured table (degree vs. per-fold cost) and a
  verdict whether ADR 0012 needs an addendum. Expected outcome: an addendum
  documenting the squarefree-generator invariant and the join (this spec is
  its draft); the intrinsic 3^k degree growth of genuinely stacked cubics is
  documented as a limit, not capped artificially.

## Non-goals

- No polynomial factorization (Zassenhaus/Hensel) — D5 exists to avoid it.
- No global/session ambient field — joins are pairwise and memoized; `Num`'s
  public API is unchanged.
- No degree cap; no subfield/degree-compression pass (noted in `ideas.md` as a
  future option if #33 benchmarks show degree creep in long models —
  Szutkoski–van Hoeij would be the reference to pull in then).
- No Thom encodings, no floating-point filters beyond the existing
  interval-refinement fast paths.

## Sources

[bpr2006, Ch. 2, 8, 9, 10, §12.4] — Descartes/Sturm, subresultants, isolation,
RUR/primitive element. [ddd1985] — D5: squarefree modulus, gcd zero-test,
lazy splitting (transcription in `refs/ddd1985.md`). [duval1994, §2–3, §5] —
dynamic evaluation tutorial (OCR in `refs/duval1994.txt`).
