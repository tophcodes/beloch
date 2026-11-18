---
id: BEP-0060
title: "A rule that picks one of several results reads the pairs only"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#3
---

# BEP-0060: A rule that picks one of several results reads the pairs only

The architecture part of this decision is [[ADR-0069]].

## Decision

- A fold that places paper `over` or `under` a named flap lays the moved
  block directly on every face of that flap it lands on. The faces of one
  flap lie flat as one piece of paper, and the block lies on all of them
  alike.

**A rule that picks one of several results reads the pairs only.**

- A `flatten` with `toward` picks the result whose material toward the
  point lies on top. It weighs a face by the number of faces it lies above
  less the number of faces it lies below.
- A reverse fold takes the results of its openings that agree on every
  pair as one state and returns that state. No list of them is compared.
- `over` and `under` read the pairs as above.

## Consequences

- A squash of one flap of the preliminary base folds flat in three states,
  where the check on list heights left one. [[BEP-0061]] states how a
  verb chooses among them.
