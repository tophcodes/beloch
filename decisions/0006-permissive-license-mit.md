# 0006 — Permissive license (MIT)

**Status:** Accepted

## Context

The project will not be monetized — in the LLM era, funding niche OSS via
licensing isn't viable, and closed source defeats the purpose. So the license
choice is not "income vs. none" but "optimize for adoption" vs. "optimize for
control". The audience is academic-adjacent (origami math, PL, education).

## Decision

Ship under a **permissive license — MIT** (already in `LICENSE.md`).

## Alternatives considered

- **AGPLv3 / GPLv2** (the author floated "AGPLv2", which doesn't exist —
  Affero's first FSF version was AGPLv3). Rejected: copyleft targets
  SaaS-ification, which nobody will do to an origami DSL in a way worth
  preventing; meanwhile universities and corporate labs (exactly the people we
  want citing/extending) often have AGPL restrictions. Carrying copyleft's
  ideological weight for no defensive benefit.
- **Apache-2.0.** Reasonable alternative — adds an explicit patent grant,
  slightly nicer if any disambiguation/layer-resolution algorithm turns out
  novel. MIT chosen for simplicity; revisit if patent concerns ever arise.

## Consequences

- Minimal friction for academic/lab adoption and citation.
- Pairs with the publication strategy (arXiv preprint + JOSS + eventually 9OSME,
  ~2028) — see a future ADR / `../paper/` when that work begins.
