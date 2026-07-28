---
id: "0013"
title: "FLINT qqbar backend for irrational values"
status: accepted
---

# 0013 — FLINT qqbar backend for irrational values

**Status:** Accepted (supersedes the `Alg` representation of
[0012](0012-real-algebraic-number-kernel.md); `Rat`/`Field` fast paths and
the Mpoly elimination pipeline of 0012 remain)

## Context

ADR 0012's `Alg` (squarefree polynomial + isolating interval, resultant
arithmetic) was correct but had two walls, measured in
`notes/2026-07-03-flint-kernel-spike.md`: cross-field chains grow degree
multiplicatively without normalization (comparing (∛2+√2)² against ∛2+√2:
>120 s), and composite extensions of degree ≥ 4 were not representable
without a polynomial factorizer. Building the D5-style fix ourselves
(dynamic evaluation, subresultant PRS, pairwise joins — see the spec's
appendix and refs ddd1985/duval1994) would re-implement what FLINT 3's
`qqbar` module (Calcium) already does: canonical minimal polynomials per
value (LLL-based), Arb ball certification, exact comparison. The spike
measured qqbar at ~1000× our speed on the cliff cases and sub-millisecond
on degree-27 arithmetic we could not represent at all.

## Decision

Irrational `Num` values are backed by FLINT `qqbar` (`Qq of Qqbar.t`, FFI in
`lib/qqbar.ml` + `lib/qqbar_stubs.c`). `Rat` stays pure OCaml; `Field`
(single monic irreducible generator of degree ≤ 3) stays as the pure-OCaml
hot path for same-field arithmetic (~7× faster per op than qqbar's
canonicalizing arithmetic; keeps `cube-root.bel` at ~90 ms). Cross-field and
composite cases convert to qqbar (`to_qq`), compute there, and collapse back
(`Rat` when rational). `real_roots` keeps 0012's Mpoly elimination for algebraic coefficients, with
candidate roots verified by exact qqbar re-evaluation of P (the former
interval-certification pipeline was removed); roots enter the representation
through `make` (Rat | Field via `minimal_poly_in` | Qq). FLINT 3.6's
`_qqbar_roots_poly_squarefree` is tried first for degree ≤ 3 with a nonzero
discriminant; the elimination path remains as fallback when FLINT's limits
reject the field degree.

Dependency: `flint3` (LGPL — linking is compatible with MIT, ADR 0006),
wired through the flake.

## Alternatives considered

- **Build D5 dynamic evaluation ourselves** — the previous plan of record;
  kept as the spec's fallback appendix should the FLINT dependency become
  untenable. Rejected: re-implements a decade of specialist optimization.
- **CGAL** — wrong layer (geometry predicates; its `Algebraic_kernel_d_1`
  provides no arithmetic on algebraic reals); CORE::Expr is expression-DAG
  C++ with separation-bound blowups on nested roots; licensing mixed.
- **e-antic** — fast arithmetic within one fixed real embedded field, i.e.
  the half we already have (`Field`); no joins; not in nixpkgs.

## Consequences

- The >120 s cross-field cliff and the composite-degree wall are gone
  (suite: cross-field sequence and deg-27 smoke tests, each < 1 s).
- `Num`'s public API is unchanged; geometry and evaluator are untouched.
- The kernel is no longer self-contained OCaml: builds need FLINT headers/
  libs (nix dev shell / flake). `to_float` gains a sibling
  (`Qqbar.to_float`), still output-only.
- #33's stacked-cubic ceiling question is re-answered by benchmark
  (`notes/2026-07-03-flint-kernel-spike.md` + the #33 verdict note).
