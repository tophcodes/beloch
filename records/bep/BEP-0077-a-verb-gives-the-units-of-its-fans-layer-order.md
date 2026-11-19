---
id: BEP-0077
title: "A verb gives the units of its fan's layer order"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#137
reference:
  - reference/kernel#fan
  - reference/kernel#reverse
amends: [BEP-0044]
superseded-by: null
---

# BEP-0077: A verb gives the units of its fan's layer order

## Summary

A fan moves each piece of its tip and then searches the layer order of the
result. Two faces of one unit of that search keep their order, turned over
where the unit turns over; the search decides every other pair.
[[BEP-0044]] made the units the pieces of one wedge that share one motion.
This record lets the verb name the units: `flatten` and `squash` keep the
pieces of one motion, and `reverse` gives the two blocks of its opening
and the faces that stay.

## Example

A square folded in half, right half onto the left, has its folded edge
`--d` at $x = 1/2$. An inside reverse along $x = 3/8$ moves the strip
between the line and the edge, two layers joined at `--d`:

```beloch
paper square
fold (map .b onto .a) as --d
.m = free on --ab from .a at 3/8
.n = free on --cd from .d at 3/8
.t = free on --d from .[--d --ab] at 1/2
reverse (through .m .n) (moving .t) as --r
```

Both layers of the strip move by the same reflection, across $x = 3/8$,
so they are one piece. Under [[BEP-0044]] the search keeps their order
turned over, and the upper layer of the strip lands under the lower one.
The search finds two states: the strip folded as one over the top of the
stack, and the strip folded as one under its bottom. Neither is the
reverse fold.

On paper the strip opens at its folded edge, and each layer goes in
beside its own layer of the body ([[BEP-0043]]). Read from the bottom, the
state is the bottom layer, the lower layer of the strip, the upper layer
of the strip, the top layer. The two layers of the strip keep their order,
and `--d` takes the other letter. Each layer of the strip is a block of
its own here; on the crane's neck a block holds four layers, which turn
over as one while the two blocks keep their order.

## Rule

In [[reference/kernel#fan]]: the search orders the units the verb gives.
Two faces of one unit that overlap keep their side, exchanged where the
unit turns over; the side of two faces of different units is open, or
fixed by a condition of the verb. A `flatten` and a `squash` give the
pieces of one motion, the faces the fan leaves in place forming one
piece.

In [[reference/kernel#reverse]]: a reverse fold gives three units per
opening, the faces that stay and each of the two blocks. Its conditions
fix the side of the two blocks, the lower one below, and the sides that
inside or outside put each block on against its body. The search of the
fan decides the rest, on one folded state for every opening, since every
block moves by the reflection across the axis.

## Alternatives considered

- **Units cut at the hinges on the fan's lines.** The faces of one motion
  joined across a hinge on a ray would be two units, so the blocks of a
  reverse fold come out of the rule, and the search finds the openings.
  Every flatten whose ray runs along a folded hinge that keeps would then
  search sides it keeps today, and may become ambiguous. It is a change of
  its own, to be tried against the corpus.
- **`reverse` on its own path.** The kernel folded the two blocks with a
  layer search of its own, beside the one of the fan. Two searches decide
  the same kind of state, and the claim that a reverse fold is a fan holds
  in the reference only.

## Open questions

None.

## Consequences

- `reverse` folds through the motion and the layer search of the fan; the
  blocks and the conditions of [[BEP-0043]] reach the search as units and
  sides. Its results stay as they are.
- A reverse fold folds without an outline ([[BEP-0058]]): the verb gives
  the units and the sides, and ranks nothing.
