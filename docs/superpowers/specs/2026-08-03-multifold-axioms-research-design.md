# Multifold Axioms Research Track — Design

**Date:** 2026-08-03
**Status:** Draft, pending user review

## Goal

Produce a genuinely new mathematical result on top of Beloch's exact
real-algebraic kernel, targeted at 9OSME 2027 (Xi'an, August 2027; CFP
announcement overdue since 2026-08-01, watch https://osme.info).

Primary result: a complete classification of **3-fold origami axioms** —
the alignment systems possible with three simultaneous, coupled creases —
as the analogue of Alperin & Lang's classification of the 489 two-fold
operations. No such classification is published (to be verified in
Phase 0).

Secondary results, in descending priority:

1. A **minimal-fold-count table**: for concrete targets (regular n-gons,
   specific algebraic numbers / polynomials), the smallest number of
   simultaneous folds known to construct them — upper bounds via explicit
   Beloch programs, lower bounds via Galois-theoretic arguments. In Beloch
   terms this is a program-synthesis question: "the shortest `.bel`
   program constructing X".
2. The integer sequence "number of k-fold alignment systems" (k=2 term
   is 489). If absent from OEIS, submit it.

## Success criteria

- **Machinery validated:** our enumeration reproduces Alperin & Lang's
  489 two-fold operations exactly. This is the gate before any 3-fold
  claim.
- **Novelty verified:** Phase 0 literature check confirms the 3-fold
  classification does not already exist. Abort criterion: if it exists,
  pivot to the minimal-fold-count track as primary result.
- **Result reproducible:** enumeration and verification run from the repo;
  a reader can re-derive the classification.
- **Paper:** an 8–12 page draft suitable for the 9OSME Mathematics or
  Computation track. Calibration: 8OSME Vol. III accepted "Yet Another
  Axiomatisation of 1-Fold-Origami"; this project's bar is above that.

## Non-goals

- No proofs requiring graduate-level machinery. Bachelor-level Galois
  theory (field extensions, degree towers, solvability) is in scope and
  is learned demand-driven as the project needs it; Galois-group
  *computations* are delegated to PARI.
- No changes to Beloch's user-facing language semantics in this track
  until the mathematics is settled; multifold syntax is a later, separate
  design (own ADR/spec) informed by the classification.
- Not blocked on the existing paper plan in `paper/README.md` (the
  system/language paper); that plan stays as is. This track can feed it
  or become a second paper — decided when results exist.

## Approach

A k-fold axiom is a system of k simultaneous crease lines whose defining
incidence constraints (point→point, point→line, line→line) are coupled —
constraints may reference the creases themselves, so the lines' positions
are interdependent and cannot be produced by k sequential single folds.
Classification means: enumerate the combinatorially possible constraint
systems, quotient by equivalence (symmetry / relabeling), and discard
degenerate systems (over-/under-determined or generically inconsistent).

- **Enumeration** is combinatorial: generate candidate constraint
  systems modulo equivalence.
- **Non-degeneracy** is checked exactly: instantiate generic rational
  parameters and solve on the FLINT qqbar kernel (ADR 0012/0013); a
  system is admissible iff it has finitely many solutions generically.
- **Algebraic degree** of each admissible system is read off from
  minimal polynomials (qqbar); Galois groups via PARI as an external
  tool where needed.

Work lives in a research package alongside `core` (exact boundaries are
a planning-phase decision, ADR'd per project process). OCaml throughout;
PARI called as a subprocess, not linked.

AI division of labour: small models grind literature and cross-checks;
the main model assists with formalization and proof sketches; the user
owns architecture and decisions. Every proof appearing in the paper is
human-readable and human-checked — nothing rests on "the model said so".

## Phases

0. **Novelty gate.** Read Alperin & Lang 2006 and successors (König &
   Nedrenco, Nishimura, Lucero); confirm the 3-fold classification is
   absent. Sources go into `refs/` + `paper/references.bib` per the
   citation discipline in CLAUDE.md.
   → verify: written novelty memo with sources.
1. **Two-fold machinery.** Formalize alignments; enumerate; reproduce
   489. → verify: exact count match against Alperin & Lang.
   Early milestone: a crude combinatorial **upper bound** on the number
   of k-fold systems (count constraint multisets consuming 2k degrees of
   freedom, before equivalence/degeneracy filtering). Cheap to compute
   once the alignment alphabet is fixed; validated by evaluating it at
   k=2 against 489; tells us early whether k=3 is ~10⁴ or ~10⁸ and thus
   whether the Phase 2 fallback triggers.
2. **Three-fold enumeration.** Run the machinery at k=3.
   → verify: classification with per-class non-degeneracy witnesses.
   Risk fallback: if the space explodes, restrict scope to a defensible
   subclass (e.g. systems yielding field extensions unreachable at k=2)
   and state the restriction precisely.
3. **Galois bounds & fold-count table.** Upper bounds from explicit
   constructions, lower bounds from Galois groups of target polynomials.
4. **Paper.** Draft per `paper/README.md` venue strategy; submit when
   the 9OSME CFP opens.

## Risks

- **Novelty risk:** someone classified 3-fold already → Phase 0 catches
  it; pivot path defined above.
- **Explosion risk:** 3-fold constraint space too large → scoped
  subclass fallback, still novel.
- **Equivalence-notion risk:** Alperin & Lang's 489 depends on their
  equivalence relation; reproducing it forces us to pin the notion down
  precisely before extending it. Treat mismatches as findings, not
  failures.
- **Timeline risk:** 9OSME deadline unknown until CFP opens; expect
  months after announcement. Phases 0–2 are the critical path.
