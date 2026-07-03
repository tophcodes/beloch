# 2026-07-03 — FLINT qqbar spike: outsource the algebraic kernel?

Question (from #33 / the slice-2 design): build the D5-style field-join kernel
ourselves, or bind an existing library? Spike: minimal OCaml FFI to FLINT 3.5's
`qqbar` module (`scratch/qqbar_stubs.c` + `scratch/qqbarbench.ml`, ~150 lines,
one afternoon), benchmarked head-to-head against `lib/num.ml`.

## Numbers (endurance, 2026-07-03)

| bench | FLINT qqbar | our kernel |
|---|---|---|
| ε-ladder 5e-20: real_roots | 0.0002 s | 0.011 s |
| ε-ladder 5e-20: equal close roots | ~0 s | 0.31 s |
| build ∛2+√2 (deg 6) | 0.0001 s | 0.0004 s (Alg fallback) |
| g·g in deg 6 | ~0 s | 0.098 s |
| compare g² vs g (deg 6 world) | ~0 s | **>120 s, killed** |
| build ∛2+∛3+∛5 (deg 27) | 0.0007 s | not representable (no factorizer) |
| deg 27: mul / inv / equal | all ~0 s | inv ~3.8 s naive; equal n/a |
| 50-point fold-ish workload, deg 6 | 0.055 s (~140 µs/op) | Field mul deg 6 = 20 µs/op (same-gen only) |

Sanity: FLINT confirms (∛2+√2−√2)³ = 2 **exactly**; degree 27 recognized;
close roots separated correctly.

## Why qqbar and not…

- **CGAL:** wrong layer (geometry predicates — we have that in OCaml over Num);
  its `Algebraic_kernel_d_1` explicitly provides *no* arithmetic on algebraic
  reals; the general-arithmetic backend CORE::Expr is expression-DAG based
  (separation-bound blowups on nested rootOf), template-C++ FFI, licensing
  mixed. Steal the *idea* (lazy float filter) not the code.
- **e-antic:** fast arithmetic *within one fixed* real embedded field — the
  half we already have (`Field`); no joins/mixing (our actual gap); not in
  nixpkgs.
- **qqbar (Calcium, F. Johansson):** closed arithmetic over real ℚ̄ with
  canonical minimal polynomials per value + Arb ball certification. Plain C,
  one type at our `Num` boundary, `flint3` (3.5.0) in nixpkgs, LGPL (linking
  fine for MIT, ADR 0006).

## Consequence

Slice 2 pivots: instead of building D5 joins + subresultant PRS ourselves,
`Num` gets a qqbar backend for the irrational cases. The practical stacked-
cubic ceiling moves from "~4–5 stacked cubics after heavy own work" to
"not the bottleneck". Spec updated in
`docs/superpowers/specs/2026-07-02-exact-kernel-design.md`; the D5 material
(ddd1985/duval1994 refs, fieldbench numbers) stays in the spec history and
`refs/` — it explains *what qqbar does for us* and remains the fallback plan
if the FLINT dependency ever becomes untenable.
