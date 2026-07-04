# 2026-07-03 — Spike: Calcium vs. primitive-element root-finding for stacked axiom-7 cubics

**Question (from the #33 verdict's open follow-up):** can we push the stacked-cubic
ceiling past round 3 — either by a Calcium (`ca_t`) backend or by
primitive-element merging of the coefficient generators?

**Answer:** **Primitive-element merge wins big; Calcium loses.** A single-generator
resultant makes the coefficient-degree-8 cubic **43× faster** than qqbar's native
root-finder (9.1s → 0.21s) and solves degrees qqbar rejects outright. Calcium's
`ca_poly_roots` is *weaker* than the status quo — it caps out one round earlier.

Spike code (throwaway, `scratch/`, not merged): `spike_diag.ml` (H1/H2 diagnosis),
`ca_stubs.c`/`ca.ml`/`spike_ca.ml` (Calcium FFI + driver), `spike_pe.ml`
(primitive-element resultant). Branch `worktree-spike+calcium-pe-merge` off `main`.

## Setup

Stacked axiom-7 cubics: the same doubling-the-cube geometry as `scratch/probe.ml`
(`d: y=0`, `q=(1,½)`, `e: x=0`), feeding one real root of round *k*'s cubic `F(t)`
back as round *k+1*'s `p.x`. Each round the fed-back coordinate is a **single**
qqbar whose degree roughly doubles: coeff-deg 1, 1, 2, 4, 8, 16, 32 over rounds
1–7. (This differs from the #33 verdict's *tripling* stack — see the mapping at the
end — but reports everything against the unambiguous coefficient field degree.)

`F(t)` is always a **degree-3** polynomial in `t`; the wall is entirely in
*root-finding a cubic whose coefficients live in a high-degree field*, never in the
arithmetic.

## Diagnosis first: why does round 4 wall? (H1 vs H2)

The #33 verdict never isolated whether FLINT's `_qqbar_roots_poly_squarefree`
*rejects* the field (returns `None` → fallback to the hopeless deg-2187 `R`) or
*hangs* inside. `spike_diag.ml` instruments the primitive directly:

| coeff-deg | `real_roots_of_qqbar_poly` |
|---|---|
| ≤ 4 | fast (0.043s) |
| 8 | **9.2s — accepted but intrinsically heavy (H2)** |
| 16 | **`None`, instant — limit reject (H1)** |

**Both walls are real.** qqbar grinds (H2) at degree 8 and gives up (H1) at
degree 16. The wall is the qqbar root-finder's cost as a function of the
*compositum degree of the coefficients* — exactly what a representation change can
attack.

## Calcium (`ca_t`) — loses

FFI to FLINT's Calcium: coefficients as `ca_t` (via `ca_set_qqbar`), roots via
`ca_poly_roots`, converted back with `ca_get_qqbar` and filtered to real.

| round | coeff-deg | qqbar | ca | gate |
|---|---|---|---|---|
| 1–3 | 1–2 | ✓ | ✓ (0.001–0.017s) | MATCH |
| 4 | 4 | 3 roots, 0.044s | **None (couldn't split), 0.013s** | — |
| 5 | 8 | 3 roots, 9.2s | **None, 0.083s** | — |

Sanity check (`spike_ca.exe sanity`): Calcium *does* solve canonical cubics —
`x³−2` (∛2), `x³−x−1`, `x³−√2`, both monic and non-monic. So the round-4 `None`
is **not** a bug or a normalization artifact: it is a genuine
field-complexity wall. `ca_poly_roots` only returns roots it can express in the
field tower it is willing to build; for the irreducible cubics over a degree-4
field that axiom 7 produces, it declines rather than constructing the extension.

**Calcium is a symbolic-simplification / exact-equality engine, not an industrial
algebraic root isolator.** Its ceiling here (round 3) is *below* the status quo
(round 5). Not worth wiring in for this problem. `ca_t` remains potentially useful
for exact equality/sign of closed-form expressions, but that is not where #33
lives.

## Primitive-element merge — wins

**Key observation:** in a stacked chain the coefficient field is `ℚ(px)` for a
*single* qqbar `px` — `px` itself is the primitive element, `μ = minpoly(px)`. The
current kernel's Mpoly fallback rediscovers a fresh generator per distinct
coefficient value (only degree-2 pairs affine-merge), inflating `R` to degree
`3·d³`. Instead build `F(t)` symbolically over the ring `ℚ[x]/μ` (`x ↦ px`; every
division in `F` is by a *rational* constant, so no inverse-mod is needed) and
eliminate `x` with **one** resultant:

```
R(t) = Res_x(μ(x), F(t, x))     degree 3·d, not 3·d³
```

`R ∈ ℚ[t]`; real roots come from FLINT on the *integer* polynomial (fast), each
filtered by exact `eval_p = 0` in qqbar. `R` is a superset of the true roots, so
nothing is missed and nothing spurious survives — correctness holds **without** a
qqbar baseline to compare to.

| round | coeff-deg | qqbar | PE-merge (R deg) | gate |
|---|---|---|---|---|
| 3 | 2 | 0.001s | 0.001s (6) | MATCH |
| 4 | 4 | 0.045s | **0.013s** (12) | MATCH |
| 5 | 8 | **9.101s** | **0.209s** (24) | MATCH |
| 6 | 16 | **None (limit)** | **5.517s** (48) | 3 roots, exact-filtered |
| 7 | 32 | None | walls (R deg 96, >280s) | — |

- Round 5: **9.1s → 0.21s, 43×**, roots identical to qqbar (gate MATCH).
- Round 6: qqbar gives up; PE returns 3 exact-verified roots in 5.4s.
- The gate MATCHes qqbar at every round qqbar can do; beyond that the exact
  `eval_p` filter guarantees correctness on its own.

PE-merge does **not** remove the wall — `R`'s degree still grows (`3·2^k` here) and
PE's own ceiling is round 6 (round 7's R deg 96 walls). It **moves the ceiling out
~2 rounds and is 40×+ faster in the overlap.**

## #33 answered

- The #33 verdict's **round 4** — the case it measured at **>300s, killed** — has
  coefficients over a degree-9 field (verdict's tripling stack). PE's resultant is
  then `R` of degree `3·9 = 27`, between this spike's round-5 (R 24, 0.21s) and
  round-6 (R 48, 5.4s): an estimated **~0.5–2s. That specific wall is cracked.**
- Tripling means round-*k* coefficients have degree `3^(k−2)`, so `R` has degree
  `3^(k−1)`: round 5 → R deg 81 (~10–30s), round 6 → R deg 243 (walls). PE pushes
  the interactive stacked-cubic ceiling from **round 3 to ~round 5**.
- The full #33 **20-step budget remains out of reach** — the degree growth is
  intrinsic and PE only lowers the exponent's base cost, it can't stop the
  growth. But every currently-walling case up to ~round 5 becomes tractable, and
  the round-4 target is solidly interactive.

## Caveats / what the real slice still owes

1. **The spike assumes the primitive element is known** (`px`, the single fed-back
   coordinate). This is exactly right for the single-chain stacked-cubic benchmark
   (#33), but a general Beloch program's axiom-7 coefficients can span a
   *compositum of several independent prior folds*. The real slice must either (a)
   track the generating field through fold evaluation, or (b) compute a primitive
   element of the compositum and re-express each coefficient over it. (a) is cheap
   for single chains; (b) is the general primitive-element theorem work.
2. **The resultant is NOT the bottleneck — the exact filter is.** Instrumented
   split at round 6 (coeff-deg 16, R deg 48):

   | stage | time |
   |---|---|
   | `Mpoly.resultant` (build R) | 0.058s |
   | `real_roots_of_poly` (FLINT isolate R, 4 candidates) | 0.005s |
   | **`eval_p` filter (exact qqbar zero-test of candidates)** | **5.400s** |

   The resultant and root-isolation are cheap even at degree 48. All the cost is
   verifying candidates: `eval_p` does Horner in qqbar with degree-16 coefficients
   against degree-≤48 candidate roots, i.e. qqbar multiplication of high-degree
   algebraic numbers. **A faster resultant (FLINT `fmpz_poly_resultant`,
   eval-interpolation) would buy nothing** — the resultant was never the wall.
   This filter is the *same* exact check the current kernel already runs
   (`lib/num.ml:516`); at high rounds it dominates. Pushing PE's own ceiling past
   round 6 needs a cheaper candidate verification (e.g. arb-interval pre-screen +
   certified exact confirm, or exploiting the known generator `px` to avoid
   re-deriving high-degree qqbar products) — but that is **beyond** the #33
   round-4 target, whose filter cost (coeff-deg 9) is a fraction of a second.

## Recommendation

Pursue a **primitive-element / single-generator resultant path in
`Num.real_roots`** for the case where the algebraic coefficients share a simple
field (the common case in stacked constructions), gated behind the existing
FLINT-first fast path. **No new FFI needed** — the profiling above shows the
existing `Mpoly.resultant` is already cheap; the slice reuses it. Drop Calcium —
it is a net regression for this workload.
Concretely, the real slice: recognize/track a shared generator `px` for the
coefficient set → build `R = Res(μ_px, F)` → FLINT roots on ℤ[t] → exact
`eval_p` filter → `field_upgrade`. Expected: the #33 round-4 case from ~300s+ to
~1s, ceiling round 3 → ~5.
