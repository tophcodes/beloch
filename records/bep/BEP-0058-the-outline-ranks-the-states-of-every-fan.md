---
id: BEP-0058
title: "The outline ranks the states of every fan"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#17
reference:
  - reference/model#def-flatten
  - reference/beloch-writes#flatten-and-flip
  - reference/kernel#fan
amends: [BEP-0046]
superseded-by: null
---

# BEP-0058: The outline ranks the states of every fan

## Summary

A `flatten` or a `squash` can fold to several flat states. Of these, the
states that keep the paper inside the outline it had before the statement
are kept where there are any. Where every state reaches past that outline,
all of them stay. Until this record a statement with one vertex removed
every state past the outline and failed when none was left.

## Example

Randlett folds the preliminary fold from a square folded diagonally in
half: "Fold the paper in half again, bringing the right side over to the
left. Lift flap A and squash-fold it" [randlett1961art, p. 69].

```beloch
paper square
fold (map .a onto .c) as --bd
fold (map .b onto .d) as --ac
squash (--bd & --bc onto --ac) as --s1
```

![The square folded in half twice with its top flap squashed: a triangle
with a square beside it, half of the square beyond the triangle's edge on
`--ac`](figures/0057-triangle-squash.svg)

The two folds leave a triangle with its right angle at the center of the
paper. The squash opens the top flap into a square, and half of that
square lies beyond the triangle's edge on `--ac`, outside the convex hull
of the triangle. It is the only state the squash has ([[BEP-0057]]). Under
the bound of [[BEP-0046]] the statement fails with `collapse folds a flap
off the paper`; under this rule it folds.

## Rule

In [[reference/model#def-flatten]]: of all candidate states of all
candidate fans, those whose faces lie on the table inside the convex hull
of the state before the write are kept where there are any, and all of
them where there are none. The selection works on that set. A `flatten` of
several fans and a `squash` take the rule from there.
[[reference/beloch-writes#flatten-and-flip]] states it for the program,
and [[reference/kernel#fan]] for the solver.

A reverse fold folds without an outline, as before.

## Alternatives considered

- **The ranking for a squash only.** It folds the squash of the triangle
  and leaves every flatten of one vertex as it is. A flatten that writes
  the same fan as a squash then removes a state the squash keeps, so the
  rule would differ by the verb that reaches the solver.
- **The bound of [[BEP-0046]] for one vertex, as before.** The squash of
  the triangle fails, and the preliminary fold as Randlett folds it has no
  program.
- **No outline.** [[BEP-0046]] records 6 programs that the outline decides
  and that stop as ambiguous without it, the fish base among them.

## Open questions

None.

## Consequences

- [[BEP-0056]], which gave this rule to a flatten of several fans, is
  superseded. The bound of [[BEP-0046]] is replaced; the rest of 0046
  stands.
- The message `collapse folds a flap off the paper (no seating keeps it in
  the sheet)` no longer exists.
- A flatten of one vertex whose states all reach past the outline folds or
  is ambiguous where it failed before. The reordered rabbit ear of the
  kernel's cases, `flatten-order-load-bearing.bel`, fails with `--ea is
  ambiguous at the vertex`: both segments of `--ea` fold a state past the
  sheet, and the outline prefers neither.
- The outline ranks the states of all segment combinations of a statement
  together, before any other stage of the selection.
