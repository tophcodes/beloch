# Examples

Finished showcase models. Every program here evaluates end-to-end and is
expressivity evidence for the paper; a feature has to be load-bearing for the
result, or it doesn't belong in the file. Programs that probe a single
behaviour — including the ones that must be *rejected* — live in
[`packages/core/tests/cases/`](../../packages/core/tests/cases/) with inline
assertions instead.

Many of these will be ports of the 2018 issue examples (crane, bookmark,
triangular dipyramid) — used as the test suite that the ground-up core has to
recover, not as design input (see
[decision 0003](../decisions/0003-restart-from-minimal-core.md)).

The tell for success: the preliminary base, bird base, frog base, and a
traditional crane all express cleanly and emit YR diagrams end-to-end.
