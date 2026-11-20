---
id: ADR-0081
title: "The number kernel holds values up to a measured degree over one generator"
date: 2026-11-20
status: proposed
issue: tophcodes/beloch#342
---

# ADR-0081: The number kernel holds values up to a measured degree over one generator

This record amends [[ADR-0013]] in one point: how the kernel decides which
irrational values it holds as `Field`. [[ADR-0013]] names a fixed degree
for that bound. The rest of that record stands.

## Context

[[ADR-0013]] gives the kernel two representations of an irrational number.
`Field` writes a value as a polynomial with rational coefficients in one
generator α, reduced modulo the minimal polynomial of α. Adding two values
of one field adds their coefficients, and multiplying them multiplies and
reduces; the kernel does both in OCaml with exact rationals. `Qq` hands the
value to FLINT's qqbar, which stores the value's own minimal polynomial and
computes it anew, with a resultant and a factorization, in every operation.

Folding raises the degree of its values with every construction that
solves a cubic over coordinates that are already irrational. An axiom-7
crease through points that an earlier axiom-7 crease placed is one such
construction (tophcodes/beloch#342). While the bound sat below the degree
of its roots, those values stayed `Qq`, and the evaluation spent its time
in qqbar's arithmetic.

## Decision

**The kernel holds an irrational value as `Field` when its degree lies at
or below a cap.** A `Qq` value within the cap becomes the generator of its
own field when it first meets another value in an addition or
multiplication. A value above the cap stays `Qq`. Within the cap, the
arithmetic over one generator is faster than qqbar's arithmetic, which
computes a minimal polynomial for every result.

**The cap is a constant in the kernel's code and follows a measurement.** The benchmark in
`packages/core/bench` times the same operations on the same values in both
representations, by degree. The cap moves when a run of it shows a
different crossover, or when programs reach degrees the last run did not
cover. The comment at the cap states what the last measurement found.

**A field is ruled out by degree before the long lattice searches.** Two
values over different generators α and β share a field when β is a
polynomial in α. FLINT finds that polynomial with a lattice search at a
rising precision, and for a β outside ℚ(α) the searches at the highest
precisions cost the most. Before them the kernel computes the degree of
α + β: every element of ℚ(α) has a degree that divides the degree of α, so
a sum whose degree does not divide it shows that β lies outside ℚ(α), and
the search stops.

## Alternatives considered

- **A fixed degree in this record.** A measurement or a new program moves
  the cap, and an accepted record keeps its prose ([[ADR-0062]]), so the
  number in it would go stale.
- **Speed up qqbar instead.** qqbar's cost is the minimal polynomial it
  computes for every result, and no setting of FLINT turns that off.
- **A tower of fields**, a field over a field in place of one generator.
  It keeps the coefficients of a subfield small and needs a second level of
  polynomial arithmetic in the kernel, a larger change than moving a cap.

## Consequences

- Programs that stack axiom-7 constructions stay in `Field` arithmetic as
  long as their degree stays within the cap.
- The floats the kernel writes for a value it holds as `Field` come from
  its own enclosure of the value, so they may differ from qqbar's in the
  last digit.
- A field of composite degree has proper subfields. A value over its
  generator may lie in a subfield that another field shares, so the kernel
  expresses such a value over the other generator on its own, and FLINT
  verifies every polynomial it reports.
- A cap above the degrees the examples and test cases reach rests on the
  benchmark and on the kernel's tests of composite degrees alone.
