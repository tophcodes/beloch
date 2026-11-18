---
id: BEP-0056
title: "The outline ranks the states of several fans"
date: 2026-11-17
status: accepted
issue: tophcodes/beloch#16
---

# BEP-0056: The outline ranks the states of several fans

This record replaces the collapse bound of [[BEP-0046]] for a
`flatten` of several fans ([[BEP-0055]]). The rest of 0046 stands, so
0046 stays in place.

## Context

[[BEP-0046]] keeps, of the states a collapse finds, those whose faces
lie on the table inside the convex hull of the state before the collapse.
The bound chooses among states: without it six programs of the corpus stop
as ambiguous.

The petal fold lifts the front flap of the preliminary base past the
center of the paper. Its tip lands outside the square the base covers, so
the bound removes every state of the petal fold, and the statement fails
with `collapse folds a flap off the paper`. The two reverse folds and the
valley fold that reach the same state pass no such bound. A fold that
reaches past the outline it started from is ordinary folding; the bound
holds for the programs it was measured on, not for folding in general.

## Decision

**For a flatten of several fans, the outline ranks the states and removes
none.** Of the states the fans fold to, those whose faces lie inside the
convex hull of the state before the statement are kept where there are
any; where there are none, every state stays. The selection after it
works on what remains.

## Alternatives considered

- **No outline at all for several fans.** On the petal fold and the bird
  base it changes nothing, since no state of either stays inside. It gives
  up the tie the outline breaks between a state that stays inside and one
  that does not, which the corpus of one fan shows to matter.
- **The ranking for every flatten, one fan included.** It is the same rule
  everywhere. It changes a case of the corpus that expects
  `collapse folds a flap off the paper` from one fan, and it was not
  needed for the fans of [[BEP-0055]]; it stays open.

## Consequences

- The petal fold and the bird base by two petal folds are one statement
  per petal.
- A flatten of one fan still removes the states outside the outline, so
  the two kinds of flatten differ in this rule until a record settles
  the case of one fan.
- [[reference/model]] states the rule in `def-flatten`, and
  [[reference/kernel]] in its section on fans.
