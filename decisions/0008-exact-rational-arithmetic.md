# 0008 — Exact rational arithmetic (zarith) for the geometry engine

**Status:** Accepted

## Context

Beloch's geometry must be exact — a stated goal: intersection points should
"fall out" analytically and on-paper membership be decided exactly, with no
sampling and no fuzzy tolerance. The v0.0 operations are axiom 1 (line through
two points), axiom 2 (perpendicular bisector), and line intersection, over the
rational corners of a unit square.

## Decision

Represent all coordinates and line coefficients as **exact rationals** (ℚ) using
the `zarith` library (`Q`). A line is `a·x + b·y = c` with `a, b, c ∈ ℚ`.

For axioms 1 and 2 over rational inputs, ℚ is **closed**: perpendicular bisectors
of rational points are rational lines, intersections of rational lines are
rational points. So equality, parallelism, and point-in-polygon are exact
comparisons — no epsilon anywhere.

## Alternatives considered

- **float64 + epsilon.** Simpler, faster, no dependency. Rejected: tolerance
  comparisons everywhere reintroduce fuzziness at the foundation and accumulate
  error across folds — the opposite of the exactness goal.
- **float now, exact later.** Rejected: rework cost, and the fuzziness is most
  harmful early while the foundation is being established.

## Consequences

- Adds a `zarith` dependency.
- Output FOLD coordinates are still rendered to JSON decimal at serialization
  (FOLD consumers expect JSON numbers); non-terminating rationals round *in the
  output only*, internal values stay exact.
- ℚ stops being closed at axioms 5 and 6 (square roots, cubic roots). That is a
  **known future boundary** — it will force a move to a constructible/algebraic
  number representation or a hybrid, decided when those axioms are implemented.
  Recorded as a watch-point in [antipatterns.md](../antipatterns.md).
