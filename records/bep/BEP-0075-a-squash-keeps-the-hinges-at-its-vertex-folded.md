---
id: BEP-0075
title: "A squash keeps the hinges at its vertex folded"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#189
reference:
  - reference/model#def-squash
  - reference/beloch-writes#squash
  - reference/kernel#squash
  - reference/fold#the-trace
amends: [BEP-0057]
superseded-by: null
---

# BEP-0075: A squash keeps the hinges at its vertex folded

## Summary

A squash folds at its vertex, where the hinges of earlier folds often meet
it. [[BEP-0057]] lets each such hinge keep its fold or open, and every
choice that folds flat is a result. This record keeps a hinge at the
vertex folded wherever some result keeps it folded: of the results, the
squash drops each one that opens a hinge another result keeps folded.

## Example

The traditional frog, after the diagram by Kelly Tan on origami.me, squashes
the four flaps of the preliminary base. Between the squashes the model
turns over, and a half of an earlier squash turns over like the page of a
book to uncover the next flap:

```beloch
paper square
mark (map --da onto --bc) as --v
mark (map --ab onto --cd) as --h
mark (through .a .c) as --ac
mark (through .b .d) as --bd
.k = free on --bc from .b at 1/4
.e = free on --da from .d at 1/4
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b mountain) (--bd & .d)

squash (--h & --da onto --ac) as --s1
flip
squash (--h & --bc onto --ac) as --s2
fold (--h & --bc) (moving .k) (up to .k)
squash (--v & --ab onto --bd) as --s3
flip
fold (--h & --da) (moving .e) (up to .e)
squash (--v & --cd onto --bd) as --s4
```

The last squash folds at the paper center, where four hinges of earlier
folds lie on the lines of its fan: one each of `--bd`, `--h` and `--ac` on
the center line, and one of `--s2` on the line of the spine. Before the
squash all four are folded. Under [[BEP-0057]] the squash finds 8 states,
4 placements of the paper with 2 layer orders each, and fails with
`squash is ambiguous: 8 realizations`. The states differ in which of the
four hinges open:

| states | `--s2` | `--bd` | `--h` | `--ac` |
|---|---|---|---|---|
| 2 | folded | open | open | folded |
| 2 | folded | folded | open | open |
| 2 | folded | open | folded | open |
| 1 | open | folded | folded | folded |
| 1 | folded | folded | folded | folded |

A folder who squashes the flap moves the flap and nothing else: the layers
under it stay as they lie, and their hinges stay folded. That is the last
row, the state the diagram shows at step 9. Letters on the rays of the fan
do not reach it: the four hinges are no rays of the squash, and the
explicit fan with valleys on both flanks still finds 8 states.

## Rule

In [[reference/model#def-squash]]: a hinge at $f(O)$ that is no ray of the
fan keeps its fold or opens. Of the candidate states, a state $S$ is
removed where another candidate keeps folded every such hinge that $S$
keeps folded, and one more. The hinges on the target's line between the
tip and the stayer of [[BEP-0057]] are among them.

[[reference/beloch-writes#squash]] states the rule for the program,
[[reference/kernel#squash]] for the kernel, and [[reference/fold#the-trace]]
names the removed states `"opened"`.

## Alternatives considered

- **Letter items on `squash`**, as issue 269 asks. A letter names a ray of the
  fan, and the hinges that decide here are no rays. An item that names them
  would ask the program to list the hinges a folder never thinks about.
- **The explicit fan with `toward`.** It reaches the state with `(toward
  .z)` on two marks and a `flatten`, but issue 99 removes `toward` from
  `flatten`.
- **The fewest open hinges, counted.** A count ranks two states that open
  different hinges, one each, and keeps neither or both by accident of the
  numbers. The rule above removes a state only for another that keeps more
  of the same hinges folded, so two states that open different hinges both
  stay and the squash is ambiguous.
- **Only the hinges on the target's line**, as the issue first put it.
  On the frog it leaves the last two rows: the hinge of `--s2` lies on the
  line of the spine.

## Open questions

- Whether `flatten` should apply the same condition to the hinges at its
  vertex that are no rays. It would change the states of programs that
  `flatten` folds today; issue 99 decides what selects among those states.

## Consequences

- The fourth squash of the frog is one statement, and the frog base reaches
  its squashes without `toward`.
- `Flatten_solve.solve` takes a condition from the verb that calls it. It
  runs before the selection stages of `flatten`, and it stays when issue 99
  removes those stages.
- The squashes of the crane, of Randlett's preliminary fold and of the
  squash cases fold as before: each of them has one state left before this
  condition runs.
