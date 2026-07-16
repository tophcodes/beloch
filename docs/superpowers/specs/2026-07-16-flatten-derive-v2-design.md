# flatten derive V2: solve M/V and direction, `toward` picks the realization (design)

## Status

Approved (2026-07-16, with Toph). Builds directly on the two-tier opposite-ray
fix (`feat/flatten-opposite-ray`, commit 364660f) and supersedes the derive
part of its `toward` semantics. Validate mode is untouched.

## Motivation

At the fish-base vertex (`flatten (--l1 & .b) (--l2 & .d) (--ray & .a) toward …`)
the emergent ray is unique (the diagonal's continuation, tier-2), but the fold
still has **two** physical realizations — the ear swings to the b-side or the
d-side. That choice lives in the **M/V pattern of the given rays** (Maekawa
3:1: `--l1` mountain vs `--l2` mountain), not in the emergent ray. Under V1
the given rays carry default-valley as *semantics*, so Maekawa forces the one
remaining pattern and `toward .b` ≡ `toward .d` — useless as a direction
choice. The swivel-rabbit vertex masked this: there, ray choice and side
choice coincide, so "toward picks the ray" looked right.

The user's model is simpler and it wins: **in derive mode the user supplies
only the topology (which rays hinge) and `toward` (which way it folds);
everything else — emergent ray, M/V pattern, stacking — is derived.**

## Semantics (derive mode V2)

- Given rays are **topology only**. Their M/V is *unspecified* by default and
  solved for. An explicit `mountain` on an element remains legal and becomes a
  **constraint** on the search (never required; YAGNI-user never writes it).
  `(x over y)` clauses likewise remain constraints.
- The solver enumerates **realizations**: emergent-ray candidate (from the V1
  candidate machinery, same-direction filter and all) × Maekawa-consistent M/V
  assignment over ALL rays (given + emergent) × stacking — each checked by the
  existing collapse oracle (Kawasaki closure, non-crossing, in-bounds anchor).
  Only feasible realizations survive.
- **`toward` picks the fold direction**: among feasible realizations, maximize
  `(centroid(final placement of the MOVED faces) − O) · (toward − O)`, exact
  over `Num`. Moved faces = faces whose final placement differs from their
  pre-flatten placement (the anchor sector's faces stay). This is the same
  idea `fold`/axiom `toward` already implements ("moves its material toward
  .p"), lifted to the multi-crease move.
- **Tier rule retained underneath** (from 364660f): realizations on line-NEW
  emergent candidates outrank realizations on an opposite-ray candidate;
  opposite-ray realizations compete only when no line-new one is feasible.
  `toward` chooses within the deciding set.
- Errors: no feasible realization → `e_infeasible`. Top score tied →
  the existing `e_toward_ambiguous` ("aim it off the creases" — a tie means
  `toward` sits on a symmetry axis of the surviving realizations).
  Duplicate-signature dedup (as in validate's `e_ambig`) applies BEFORE
  scoring so mirror-identical stackings don't fake a tie.
- **Validate mode unchanged**: all rays given, M/V binding (default valley),
  `over` disambiguates stacking — `collapse` verbatim.

## Resolution algorithm (evaluator)

1. Emergent-ray candidates from `Flatten.derive`'s candidate list (V1
   machinery minus the final toward choice — derive V2 returns the candidate
   list with tier tags instead of choosing).
2. Per candidate ray: materialize (one pre-minted cid, local state, no ctx
   mutation — the 364660f probe helper), then enumerate M/V patterns over the
   rays with |M−V| = 2 (both polarities of the full pattern; explicit
   `mountain` constraints filter), run the collapse kernel per pattern.
   **Kernel change required:** today's kernel errors with `e_ambig` when more
   than one distinct stacking survives; V2 needs them AS realizations. Add an
   enumerating entry point (`collapse_all : … -> (t * signature) list` or an
   `~all:true` flag) that returns every distinct-signature Ok realization; the
   validate path keeps the old single-or-`e_ambig` contract on top of it.
3. Collect all Ok realizations with their (candidate, tier, pattern, folded
   state). Empty → error differentiation as in 364660f (out-of-paper vs
   does-not-close).
4. Deciding set = tier-1 realizations if any, else tier-2. Score each by the
   moved-material centroid dot; max wins; tie → `e_toward_ambiguous`.
5. Commit the winner's folded state; `emergent_bind` = winner's (cid, line).

Combinatorics: n rays (n ≤ 6 realistic) → C(n,1)+C(n,n−1) = 2n patterns per
candidate ray, ≤ 3 candidate rays — bounded and cheap at Beloch scales.

## Risk: swivel-rabbit golden

`swivel-rabbit.bel` writes its three given rays bare (V1: default-valley
semantics; V2: unspecified). V2 enlarges its search space; the material-
centroid metric should still pick the same right-hand swivel for `toward .c`
(the golden is the regression anchor). If a different realization scores
higher, STOP and adjudicate — either the metric is wrong or the old choice
was; do not regenerate silently.

## Scope / deferred

- Single vertex only — multi-vertex flatten (the true fish base) stays
  deferred (spec §4.9, Appendix B).
- `#{…}` solution-space surface (issue #46) untouched; V2 changes *selection*,
  not the operand language.
- SPECIFICATION.md §4.9 prose update ships with the implementation (derive =
  topology + direction; M/V derived; mountain = constraint).

## References

- Two-tier fix: `feat/flatten-opposite-ray` 364660f (this branch).
- `docs/superpowers/specs/2026-07-15-flatten-generalizes-collapse-design.md` (V1).
- Kawasaki/Maekawa: [hull2020, §5.3, Thm 8.5]; single-vertex NP-hard context §6.6.
- spec/SPECIFICATION.md §4.9.
