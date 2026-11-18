---
id: BEP-0057
title: "The layers a flap is hinged to hold its squash"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#17
reference:
  - reference/model#def-squash
  - reference/beloch-writes#squash
  - reference/kernel#squash
amends: [BEP-0038]
superseded-by: null
---

# BEP-0057: The layers a flap is hinged to hold its squash

## Summary

A squash opens a flap of two layers and presses it flat. [[BEP-0038]]
holds the model still by the part of the flap beyond the line its folded
edge lands on. Where the flap ends at that line, this record holds the
model still by the layers the flap is hinged to there, and lets both
layers of the flap move.

## Example

Randlett folds the preliminary fold from a square folded diagonally in
half: "Fold the paper in half again, bringing the right side over to the
left. Lift flap A and squash-fold it" [randlett1961art, p. 69]. It is the
first squash most folders learn.

```beloch
paper square
fold (map .a onto .c) as --bd
fold (map .b onto .d) as --ac
squash (--bd & --bc onto --ac) as --s1
```

After the two folds the model is a triangle of 4 layers with its right
angle at the center of the paper, one leg on `--bd` and the other on
`--ac`. The flap is the top two layers: the paper triangle between the
center, `.b` and `.c`, and under it the one between the center, `.a` and
`.b`. A folded hinge on `--bd` joins them, the *spine*, and its end at the
center is the *vertex*. A folded hinge on `--ac` joins each layer of the
flap to one layer below the flap: the upper layer to the bottom layer of
the model, around the outside, and the lower layer to the third layer,
inside that hinge. The *axis* is the bisector of the two legs through the
vertex.

Under [[BEP-0038]] the part of the flap's upper layer beyond `--ac` stays.
The flap ends at `--ac`, so the squash failed with `the flap has no
material beyond --ac; nothing holds the squash`.

![The squashed flap: a triangle with a square beside it, the corners `.a`,
`.b` and `.c` at the square's far corner](figures/0057-triangle-squash.svg)

![The layers of the state: on the left its 6 faces on the paper with the
hinges between them, on the right which face lies on which, top
first](figures/0057-triangle-squash-layers.svg)

With the rule below the squash folds the state a folder makes. The lower
layer keeps its piece between the axis and `--ac` in place and turns its
other piece over the axis onto it (faces 3 and 4 of the second figure,
above the layers 2 and 1 that hold the squash). The upper layer turns over
`--ac`: its hinge to the bottom layer opens to flat, and its two pieces lie
on each other as the half of a square beyond `--ac` (faces 5 and 6). The
spine lies on `--ac`. Lang describes the move as "the layers of a flap are spread to the
sides and the folded edge flattened" [lang2011secrets, ch. 2].

The second squash of the preliminary fold, on the other side of the model,
needs no new rule. After the first squash that flap runs flat across the
target line into the square, and the half beyond the line holds it:

```beloch
paper square
fold (map .d onto .b) as --ac
fold (map .a onto .c) as --bd
squash (--ac & --ab onto --bd) as --s1
flip
squash (--ac & --bc onto --bd) as --s2
```

## Rule

In [[reference/model#def-squash]]: where no part of the flap $\Phi$ of the
upper face at the spine lies beyond the target's line, the faces that
hinges on that line join to $\Phi$ and to the flap $\Phi'$ of the lower
face at the spine are the stayer. The tip is every piece of $\Phi$ and of
$\Phi'$. The spine opens, each of the two flaps folds along its piece of
the axis, and each hinge on the target's line between the tip and the
stayer changes or keeps; each choice is a candidate fan.

On the triangle 2 choices close: the upper layer's hinge on `--ac` opens,
or the lower layer's does. In the second the lower layer would swing out
through the upper layer's hinge, which lies around the outside on the same
line, and the non-crossing conditions remove it.
[[reference/beloch-writes#squash]] states the rule for the program and
[[reference/kernel#squash]] for the kernel.

Where part of $\Phi$ lies beyond the target's line, the stayer of
[[BEP-0038]] stands.

## Alternatives considered

- **The lower layer of the flap holds the squash.** The stayer is the
  lower layer's piece between the axis and the target line. On a flap of 2
  layers it yields the same state without a choice per hinge. It fixes by
  layer order which layer keeps its hinge, where the rule derives it from
  the crossing. On a flap of more layers it has to name one of the lower
  layers, and the order alone does not say which of their hinges can keep
  its fold.
- **A `staying` item on `squash`.** The program names a point on the piece
  that stays. It gives up the rule of [[BEP-0038]] that no item selects
  among the states of a squash, and the first squash a folder learns needs
  an extra point.
- **The explicit fan in place of `squash`.** A fan keeps every piece in its
  stayer's wedge still ([[BEP-0037]]), and the upper layer's piece between
  the axis and `--ac` lies in the same wedge as the lower layer's staying
  piece. The flatten
  `(--bd & --bc) (--h & --bc) (--v & --ab) (--ac & .c) (on #[.q]) (staying .q)`
  finds 4 states, and in every one the spine stays closed. The program
  also needs two marks and a point for a step that `squash` states in one
  item.

## Open questions

- The second squash written without the `flip` before it fails with
  `squash is ambiguous: 8 realizations`. Whether the squash should refuse
  it with a message that names the side, tracked in
  [#17](https://github.com/tophcodes/beloch/issues/17).

## Consequences

- The squash of a flap that ends at its target folds only with
  [[BEP-0058]]: half of the square lies outside the outline of the
  triangle.
- For this case the tip holds pieces inside the stayer's wedge, which the
  tip rule of [[BEP-0037]] leaves out. That rule keeps holding for every
  flatten.
- The squash tries to keep or to open each hinge on the target line. On
  the triangle these are 2 hinges and 4 combinations.
- The message `the flap has no material beyond <target>; nothing holds the
  squash` remains for a flap with neither material beyond the target line
  nor a hinge on it.
- Randlett's preliminary fold is a program of two folds, two squashes and
  a `flip` between the squashes.
