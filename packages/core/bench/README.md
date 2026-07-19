# Kernel benchmarks

Reusable timing harness for `Num.real_roots` and its primitive-element (Tier-3)
path. Re-run before and after any kernel optimization and diff the CSV.

## Run

```sh
bench/run.sh [per-case-timeout-seconds]   # default 60; whole corpus
# or a single case:
dune exec bench/bench_real_roots.exe -- stacked:6
dune exec bench/bench_real_roots.exe -- list
```

`run.sh` writes a human table to stderr and a `CSV,...` block to stdout:

```
CSV,case,coeff_deg,total_s,merge_s,resultant_s,R_deg,roots_s,ncands,filter_s,nroots
```

To compare an optimization:

```sh
bench/run.sh > before.csv        # on the base commit
# ...apply optimization, rebuild...
bench/run.sh > after.csv
diff before.csv after.csv
```

## What it measures

- **`total_s`** — end-to-end `Num.real_roots`. This is the ground truth.
- **stage breakdown** (`merge_s` / `resultant_s` / `roots_s` / `filter_s`) —
  reproduces the Tier-3 pe path via the public `Field_merge` API to attribute
  cost. `filter_s` is a faithful replica of `num.ml`'s exact `eval_p` check.

Caveat: `total_s` only equals the sum of stages when Tier-3 actually fires
(max coefficient qqbar-degree ≥ 5, or polynomial degree > 3). For the low-degree
cases (`quad`, `independent`, `stacked:3/4`) `Num.real_roots` takes the
`flint_first` fast path instead, so the stage numbers are diagnostic ("what pe
would cost") while `total_s` is what actually ran — a useful view of where the
gate sends each case.

## Corpus

| case | what | routes via |
|---|---|---|
| `rational` | `x³−2` (rational coeffs) | flint_first — regression guard, must stay ~0 |
| `quad` | `x³−√2` (1 quadratic coeff) | flint_first |
| `independent` | `x³ + ∛2·x − √2` — two independent folds, ℚ(√2,∛2) deg 6 | flint_first (deg 3 < gate) |
| `deepstack` | cubic with a single degree-8 coeff `√(√2+√3)` | pe_tier (gate) |
| `stacked:N` | N stacked axiom-7 cubics, coeff field degree doubles (1,1,2,4,8,16,32) | flint_first ≤ deg 4, pe_tier ≥ deg 8 |

## Baseline

Machine-dependent; capture a fresh `before.csv` on your box before comparing.
Representative run (this dev machine), after the eval-interpolation resultant
and the interval filter pre-screen:

```
case          deg  total     merge   resultant (Rdeg)  roots   filter   roots
rational       1   0.000s    0.000   0.000    (0)       0.000   0.000    1
quad           2   0.000s    0.003   0.000    (6)       0.000   0.000    1
independent    3   0.001s    0.037   0.002    (18)      0.035   0.001    1
deepstack      8   0.205s    0.060   0.002    (24)      0.002   0.138    1
stacked:3      2   0.002s    0.012   0.000    (6)       0.000   0.001    3
stacked:4      4   0.057s    0.025   0.000    (12)      0.000   0.011    3
stacked:5      8   0.302s    0.092   0.013    (24)      0.001   0.197    3
stacked:6     16   6.600s    0.379   1.004    (48)      0.005   5.259    3   ← true-root-bound
stacked:7     32   WALLS (intrinsic 3·d³ growth)
```

Optimization targets (see `notes/2026-07-03-calcium-pe-spike.md`):
1. **resultant** — ✅ DONE. `Mpoly.resultant` → univariate eval-interpolation in
   t (`Poly.resultant` per sample, sampled only where `F̃(t_j)` keeps full formal
   x-degree). Measured **10.08s → 1.00s** on `stacked:6`; total 15.8s → 6.8s.
2. **filter** — ✅ PARTIAL. Rigorous rational-interval pre-screen (interval
   Horner over `Qqbar.enclosure`) rejects extraneous candidates before the exact
   `eval_p` qqbar check; never rejects a true root. Big on **extraneous-bound**
   cases (`deepstack` filter **1.72s → 0.14s**, ~12×); negligible on
   **true-root-bound** cases (`stacked:6` 5.4s → 5.3s) where the cost is
   confirming genuine high-degree roots — that is intrinsic to exact evaluation
   and would need number-field (RUR-style) arithmetic in the compositum, a much
   larger change.
3. **stacked-cubic true-root confirm** — OPEN. `stacked:6`'s 5.3s is 3 exact
   `eval_p` evaluations of degree-32 true roots (~1.75s each). Only
   tower/number-field arithmetic in ℚ(γ, z) would cut it.
