---
id: BEP-0078
title: "A point names the wedge of the emergent ray, and flatten takes no toward"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#99
reference:
  - reference/beloch-writes#flatten-and-flip
  - reference/beloch-grammar
  - reference/model#def-flatten
  - reference/kernel#fan
amends: [BEP-0031, BEP-0055]
superseded-by: null
---

# BEP-0078: A point names the wedge of the emergent ray, and flatten takes no toward

## Summary

A `flatten` with an odd number of rays adds one more ray, the *emergent
ray*, so that the vertex folds flat. Where the emergent ray can lie in
two places, the item `(emergent beside .p)` keeps the states whose
emergent ray lies in a wedge between the rays the program names that
holds `.p`. It
replaces `toward`, which picked a state by a score, and `flatten` takes
no `toward` any more. A construction ray of a fan takes a letter, as a
line ray does.

## Example

The rabbit ear of a square, with the three angle bisectors of the
triangle `.a`, `.b`, `.c` as rays:

```beloch
paper square
mark (through .a .c) as --diag
mark (map --ab onto --diag) as --ea
mark (map --ab onto --bc) as --eb
mark (map --bc onto --diag) as --ec
flatten (--ea & .a valley) (--ec & .c) (--eb & .b valley) (staying .d)
        (emergent beside .a) as --ear
```

The emergent ray runs from the incenter to `--ab`, between `--ea` and
`--eb`, the wedge whose edge `--ea` ends at `.a`. With `(emergent beside
.c)` it runs to `--bc`, the mirror ear. Before this record the program
wrote `flatten (--ea) (--ec) (--eb) (toward .a)`. Three ranking stages
chose the state: the emergent ray on a new line over one on the far side
of a given ray, the fewest mountains, and the class of the moved material
nearest `.a`.

Without the stayer the statement has five states, one with the emergent
ray on a new line and four with it on the far side of `--eb`, and they
hold different wedges still:

![The five candidate states of the rabbit ear without a staying item, as
crease patterns: one with the emergent ray to the bottom edge, four with
it to the corner .d](figures/0078-ear-without-staying.svg)

`(staying .d)` leaves one:

![The one state with staying .d: the emergent ray runs from the incenter
straight down to the bottom edge](figures/0078-ear-with-staying.svg)

![The rabbit ear folded flat, the ear lying toward
.a](figures/0078-ear-folded.svg)

## Rule

In [[reference/beloch-writes#flatten-and-flip]]: `(emergent beside .p)`
keeps the states whose emergent ray lies in a wedge between the rays the
program names that holds the table point of `.p`, the two rays that bound
the wedge included. A point on a given ray lies on the edge of two wedges and names
neither side. An even fan and a flatten of several fans have no emergent
ray, and the item is an error there; a point that no state puts its
emergent ray beside is an error too. `flatten` refuses `toward`. More
than one state left is an error whose hint names the items that would
leave one. [[reference/model#def-flatten]] states the item as a condition,
[[reference/kernel#fan]] where the solver applies it, and
[[reference/beloch-grammar]] the syntax.

A ray of a fan item is a line operand or a construction, each with an
optional letter: `(map .sr onto --mid through .a valley)`.

## Alternatives considered

- **A sector notation**, `#{…}`. It waits on issue 12, and a point says
  the same for the wedges of one vertex.
- **Only the inside of a wedge.** On the rabbit ears and the fish bases
  of the kernel's cases a corner of the paper names the side, and the
  corner is the end of a ray the program names. The edges of a wedge
  count so that `.a` names the ear beside `--ea`.
- **Keep `toward` as a ranking.** [[BEP-0061]] rules rankings out: a
  ranking gives an answer on every input and hides the other states.

## Open questions

- Suggestions of `over` items in the hint of an ambiguous flatten, and a
  suggestion per candidate in the trace, are not built.
- The outline preference of [[BEP-0058]] is a ranking still; issue 325
  asks which condition replaces it.

## Consequences

- The ranking stages of `flatten` are gone: fewest mountains, the
  preference for an emergent ray on a new line, and both stages of
  `toward`. A program states the condition a stage chose.
- Without the preference for a new line, the states that close the vertex
  on the far side of a given ray count, and their stayers can differ: most
  rabbit ears need `(staying …)`.
- The crane's petal folds letter their kite creases, which are
  constructions, as valleys.
- `toward` keeps its meaning for the writes that select a line
  ([[BEP-0031]]); this record removes it from `flatten` only.
