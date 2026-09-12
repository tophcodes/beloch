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

`Fold_state.t` is abstract and `Fold_state.make` is its only constructor, so
every operation builds a candidate and passes it through `make`: no value of
type `Fold_state.t` exists that is not a legal state. `make` returns
`Error violation` for anything outside the definition of the state and its
non-crossing conditions ([def-noncrossing](/model/#def-noncrossing)); the
`violation` constructors and the conditions they check are listed under
Violations.

::: {.include api="Fold_state.t"}
:::

::: {.include api="Fold_state.make"}
:::

Faces are convex polygons in paper coordinates, one exact 2D isometry each
(`Isometry.t`), the restriction of $f$ to that face. A hinge names the two
faces it joins, its line and its angle in $\{0, \pm 1\}$ units of $\pi$:

::: {.include api="Fold_state.hinge"}
:::

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

One constructor per check `Fold_state.make` runs, each carrying the model
statement it enforces. `Bad_index` and `Bad_line` reject a malformed
representation and answer to no statement of the model.

::: {.include api="Fold_state.violation"}
:::
