# Examples

`.bel` programs serving three purposes at once, each tagged with a status:

- `works` — currently evaluates end-to-end. Expressivity evidence for the paper.
- `aspirational` — should work eventually but doesn't yet. The TODO list.
- `anti` — should be *rejected* (by the parser or type checker). Test-suite
  negative cases.

Put the status in a leading comment, e.g. `; status: aspirational`. Many of
these will be ports of the 2018 issue examples (crane, bookmark, triangular
dipyramid) — used as the test suite that the ground-up core has to recover, not
as design input (see [decision 0003](../decisions/0003-restart-from-minimal-core.md)).

The tell for success: the preliminary base, bird base, frog base, and a
traditional crane all express cleanly and emit YR diagrams end-to-end.
