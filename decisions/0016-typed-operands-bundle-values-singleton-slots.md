---
id: "0016"
title: "Typed operands: bundle values, singleton slots"
date: 2026-07-05
status: accepted
---

# 0016 — Typed operands: bundle values, singleton slots

## Context
Designing the fold-scope refinement (`moving`, `up to`, `@fold` — see
`docs/superpowers/specs/2026-07-05-fold-scope-design.md`) surfaced a question the
language had been answering ad hoc: what does an operand *denote*, and who
resolves ambiguity?

The evidence was scattered but consistent:

- `moving .b` was always flap-valued with a point as sugar — "move the flap
  carrying `.b`", never "move `.b`". The evaluator even discards the material
  identity today (`eval.ml` projects to table space and keeps only the side).
- ADR 0014 already established the pattern for creases: a name denotes a
  **bundle** of segments, operations consume **length-1** bundles, and `at`
  projects by incidence with 0-match/multi-match errors.
- Axioms ⑤/⑥ already carry a metric disambiguator: `toward .x` picks among
  2–3 geometric solutions, and its omission raises an ambiguity error naming
  the candidates (spec §4).
- A segment cannot be a first-class value: a later fold may split it, and a
  stored "this segment" would silently go stale. The same holds for a single
  flap.

## Decision
One operand model for the whole language:

1. **Every operand slot is typed** — point, line (segment-bundle), flap
   (flap-bundle), segment. Every axiom/statement is a function with typed
   slots.

2. **Bindable values are time-stable identities only**: points and bundles.
   Splits stay inside the name — a segment splits and its bundle grows; a flap
   splits and its flap-bundle contains both parts. Cardinality is a function of
   time; identity is not.

3. **Singletons are never values.** A single segment or single flap exists only
   as a *slot-resolution result*, computed against the material state of the
   step where it is used. Nothing stored can go stale, because selections are
   not stored.

4. **Slots demand uniqueness, programs supply constraints.** An operand must
   come with a *minimal sufficient set* of constraints so the slot resolves to
   exactly one referent. Underdetermined → error naming the candidates and
   asking for more constraints (the existing `at` 0-match/multi-match and
   axiom-⑥ ambiguity errors are instances of this one rule).

5. **Two resolution mechanisms, both already in the language:**
   - **Incidence** for material selection: `at (…)` for segments, `#(…)` for
     flaps — the same operation at two types: "the unique X coincident with all
     listed constructs". A bare point or line in a bundle-typed slot is sugar
     for a one-element constraint list (`.p` ≡ `#(.p)`, `--d` ≡ `#(--d)`).
   - **Metric** (`toward .x`) only where incidence cannot discriminate:
     multiple geometric solutions of one construction are all equally
     coincident.

6. **Slot context counts toward the minimum.** A slot may contribute semantic
   constraints of its own: `up to --d` is unique although `#(--d)` alone has
   two sides, because the range anchor fixes the walk direction. The universal
   requirement is only "unique at the end, else a candidate-naming error".

## Consequences
- A line is a legal flap operand everywhere. `moving --d` will usually fail
  with a multi-match ("two sides — add a constraint: `#(--d .p)`"); `up to
  --d` resolves. No position-specific grammar rules, no fold history needed.
- Flap-bundles get the same tooling as segment-bundles: cardinality-over-time
  is known per step, so the LSP can show bundle lifetimes (#65) and lint
  redundant or fragile operand forms (#64).
- Error messages get a single shape across the language: list the candidates,
  name the missing constraint kind.
- `toward` stays exceptional and scoped: it exists only where coincidence is
  provably insufficient. New disambiguation needs should be met with incidence
  first.

## References
- ADR 0011 (action model), ADR 0014 (crease = bundle of segments)
- `notes/2026-07-03-crease-layer-selection.md` (pinch/at convergence)
- [demaine2007, §14] for the simple-fold models motivating fold scope
