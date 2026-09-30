---
title: Language
description: Beloch as the signature of the model. Which sorts a program names, which operations it applies, and how the surface syntax marks the difference.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

The language spans several pages. This page states what a program is and
the sorts and types a statement works with.
[Write statements](/language/writes/) gives the verbs,
[Constructions](/language/constructions/) the reads a write's axis comes
from, [Annotations](/language/annotations/) what a program tells its
reader beyond the geometry, and [Grammar](/language/grammar/) the grammar
of the language.

The language refers to the model by statement ids and to the specification
by section. The model does not refer to the language.

## A program is a path

A program starts from a sheet ([def-sheet](/model/#def-sheet)) and applies
operations one after another. Each operation takes the current flat folded
state ([def-flat-state](/model/#def-flat-state)) and either produces the next
one or fails with a reason. The program's meaning is the finite sequence of
states it passes through; its result is the last state.

## Reads and writes

One law organises the surface syntax (`SPECIFICATION.md` §4.10): an
operation that changes the state is a keyword verb, sequenced in program
order; an operation that only computes something from the current state is
an operator, a bracket, or a construction, and may appear anywhere a value
is needed.

In the terms of the model, the writes are the partial functions from states
to states ([def-write](/model/#def-write)), and the reads are functions from
a state into the value sorts ([def-read](/model/#def-read)). A read never
fails silently: where the state has no answer, such as a point that lies on
no face or a construction with two solutions and no way to pick one, the
read is an error.

**Sorts.** Point, line, flap, and bundle (a set of crease segments), the
value sorts of the model's section on values; each a value computed in the
current state and carried in paper coordinates, so it survives later folds.

**Writes.** The operations of the model's section on operations, named by
the verbs `mark`, `fold`, `reverse`, `flatten` and `flip`. Each is a
partial function on states with its own domain; the domain is the
language's notion of a safe operation, and the model states it. A *write
statement* is a verb followed by its arguments; its shape is given under
[Write statements](/language/writes/).

**Reads.** Constructions (below), selectors (`#[…]`, `*`, `--[…]`, `free
on`), and the filter operators (`&`, `\`, `[…]`), which form a Boolean
algebra on the segments of a bundle: intersection with an incidence
predicate, difference, union.

**The meet.** `--x * --y`, and `.[--x --y --z]` for more operands, is the
one paper point the operands have in common as sets of paper points
([def-meet](/model/#def-meet)). An operand may lie on several paper lines,
as a crease scored through several layers does; on the preliminary base
`--h * --v` is the centre of the paper. A paper edge such as `--ab` counts
as its side of the sheet. The meet is an error when the operands have no
common point, when they share a stretch of paper, and when they have two or
more common points; the last message lists the points in paper coordinates,
and `&` narrows an operand to the pieces that cross at the one meant.

## Parameter types

A write takes typed arguments. Four of the types are value sorts of the
model and are supplied by a read; the others are enumerations that occur
only as an argument of a write. The type of a slot is what a graphical
editor binds to: a slot of type flap gets a flap picker, a slot of type
placement a menu of four entries.

| type | values | slots |
|---|---|---|
| line | a construction, a name bound by `=`, or a crease whose segments lie on one table line ([def-line](/model/#def-line)) | the operands of a construction, `heading`, `toward`, the axis of `mark` |
| crease | a name bound by `as`: the material scored under that name ([def-bundle](/model/#def-bundle)), or a selection from one | the axis `(--d)` of `fold` and `reverse`, the rays of `flatten`, the meet `*`, the filters `&` `\` `[…]`, `free on` |
| flap | a point, a line, or `#[…]`, resolved by incidence ([def-selector](/model/#def-selector)) | `moving`, `up to`, `on`, `staying`, the target of `over` and `under` |
| point | a named or selected point | `at`, `between`, `toward` |
| placement | top, bottom, over a flap, under a flap ([def-reflection](/model/#def-reflection)) | `fold` |
| kind | inside, outside ([def-reverse](/model/#def-reverse)) | `reverse` |
| extent | the whole line, between two points, at a point ([def-mark](/model/#def-mark)) | `mark` |
| intent | mountain, valley; the direction the crease pattern draws, no part of the state | `mark` |
| letter | mountain, valley as a constraint on a ray, or on a hinge of the spine ([def-letter](/model/#def-letter)) | `flatten`, `reverse` |
| order | one sector over another | `flatten` |
| selection | `toward` a point or a line, the side that stays; `moving` a flap, the side that folds over; `heading` a line, the direction of the crease ([def-selection](/model/#def-selection)) | `toward` and `moving`: `mark`, `fold`, `reverse` and a binding over a construction; `toward` a point: `flatten`; `heading`: `align` |

Line and crease are two sorts under one sigil, and the binding tells them
apart: `--l = …` is a line, `… as --l` is a crease. A crease stands where a
line is wanted by projection to its table line, which exists while its
segments are collinear (ADR 0014) and is an error once a fold has bent it.
A line stands nowhere a crease is wanted: it has no material until a
`mark` scores it. The check needs no geometry, so a program's sorts can be
verified before it is evaluated.
