---
title: The kernel
description: How packages/core represents the states of the model, which statements it realizes, and where it stops short.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

`MODEL.md` says what a Beloch program talks about. This document says how the
kernel in `packages/core` holds that in memory and which of the model's
statements each part realizes. It refers to the model by the ids of its
statements; the model does not refer back. When the two disagree, the model
wins and the kernel has a bug, or the model has a gap and gets a new
statement.

Entries name OCaml modules and functions as they exist today and are updated
with the code. Anything the kernel cannot represent is stated as a ceiling
with the issue that tracks it.

## Sheet

The language offers one sheet, `paper square`, the unit square with the four
corners bound as `.a` to `.d`. The model's sheet
([def-sheet](/model/#def-sheet)) allows any simple polygon. Faces are convex
polygons in counter-clockwise order because `Geom` clips against half-planes
and tests overlap on convex polygons only; a non-convex sheet would enter as
several convex faces joined by hinges of angle $0$.

## State

`Fold_state.t` realizes the flat folded state
([def-flat-state](/model/#def-flat-state)):

- the face array, each face a convex polygon in paper coordinates;
- one exact 2D isometry per face (`Isometry.t`), the restriction of $f$ to
  that face;
- the hinge array: each hinge names its two faces, its line, and an angle in
  $\{0, \pm 1\}$ in units of $\pi$;
- a rank, a permutation of the faces, from which the layer relation is read
  (see Rank);
- optionally marks (reference creases that do not subdivide) and a whole-sheet
  base placement.

`Fold_state.t` is abstract. `Fold_state.make` is its only constructor; it
returns `Error violation` for anything outside the definition of the state and
its non-crossing conditions ([def-noncrossing](/model/#def-noncrossing)).
Every operation builds a candidate and passes it through `make`, so no value
of type `Fold_state.t` exists that is not a legal state. The `violation`
constructors and the conditions they check are listed under Violations.

Refinement equivalence ([def-refinement](/model/#def-refinement)) is not
quotiented in the representation: `mark` adds faces and hinges of angle $0$,
and two states equal up to refinement are two different values. Comparisons
across programs are made pointwise on the folded geometry, as in the test
that checks the two preliminary-base routes against each other.

## Rank

The kernel does not store $\lambda$. `Fold_state.rank` is a total order of
all faces, and `Fold_state.rel` reads *above*/*below* for a pair off the rank
only when the two table polygons overlap in positive area; otherwise the pair
is `Apart`. The rank is therefore a linear extension of $\lambda$ in the sense
of the model's remark on linear extensions
([rem-linear-extension](/model/#rem-linear-extension)), and two ranks with the
same restriction to overlapping pairs represent the same state.

Ceiling: a linear extension exists only for acyclic layerings, so states with
cyclic layering, the square twist among them, cannot be represented. Tracked
as [issue #83](https://github.com/tophcodes/beloch/issues/83). Nothing on the
crane path needs such a state.

## History

The model's state does not remember how it was reached. The kernel keeps the
history for output: the FOLD file carries one frame per statement in
`file_frames`, and per edge the statement that scored it in `beloch:edges` and
`beloch:source_line` (`SPECIFICATION.md` §7). No operation reads this record.

## Violations

To be filled with the model's non-crossing conditions: one row per
`Fold_state.violation` constructor, naming the condition it checks. Today the
constructors are `Bad_index`, `Bad_rank`, `Bad_angle`, `Bad_line`,
`Disconnected`, `Hinge_not_shared`, `Hinge_not_closed`, `Taco_tortilla`,
`Taco_taco`.
