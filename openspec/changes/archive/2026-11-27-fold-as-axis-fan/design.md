## Context

A fan needs a vertex. A fold has a line and no point on it that the program
names, and it moves every layer on its moving side, also layers the axis
crosses far apart (spec `folds`, "A fold moves every layer on its moving
side"). A fan at a paper point folds only the pieces of its rays that pass
through the vertex (spec `multifold`, "A ray folds the pieces of its bundle
that pass through the vertex").

## Decision

A fold has its vertex at the point at infinity of its axis on the projective
table. Its rays are the two halves of the axis, its sectors the two
half-planes, and every layer the axis crosses lies under the vertex. This is
the fan `reverse` hands a vertex at infinity already. `unfold` is the same
fan with a moving set the axis cuts nowhere.

Rejected alternatives:

- A vertex on the paper, one per flap the axis crosses: a fold of k flaps
  needs k vertices no program names, and the reach of `fold` would change.

## Risks

The faces and hinges of a fold come out in the order the fan gives them. If
that order differs from the order of today, the FOLD files of programs
change without a change in what they mean; the corpus snapshot shows it.
