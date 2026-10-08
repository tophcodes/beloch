---
title: "A reverse fold turns the hinges across its opening"
date: 2026-09-30
status: accepted
issue: tophcodes/beloch#119
---

# A reverse fold turns the hinges across its opening

This record supersedes [[decisions/a-reverse-fold-turns-every-spine-of-its-tip]], which is in `archive/`.

## Context

`def-reverse` in [[reference/model]] picks one *spine*: a folded hinge of the
tip whose removal cuts the tip into two halves. It reflects the halves as
two blocks, and every other hinge of the tip keeps its letter.

A square folded in half, then in half again in the same direction, has two
folded hinges nested on one edge. Folded on paper, an inside reverse of the
lower half can open the stack in two places: between the two inner layers,
where both nested hinges turn, and below the outermost layer, where only the
outer hinge turns and the inner layers go in as one packet. Both states are
flat. `def-reverse` reaches only the second.

![The square's tip before the reverse, with its two openings, and the state
each opening gives](figures/0043-square.svg)

The crane's head shows the other side. Its spine encloses two smaller tacos,
which the neck's reverse carried inside it. On paper the head turns the
outer taco alone. [[decisions/a-reverse-fold-turns-every-spine-of-its-tip]], which turned every folded hinge on the spine's
line, leaves no flat state there.

![The crane's head before its reverse: one opening, one hinge across
it](figures/0043-crane-head.svg)

Eos folds an inside reverse by splitting the model into two parts and
folding each as a block [ida2020, §7.4.3]. Smith's notation writes a
reverse as a fold "between layers" of the stack [smith1975oil, p. 8]. Lang
asks where a reverse goes when the open side has eight layers, and answers
with an edge view in the diagram (langorigami.com, "Origami Diagramming
Conventions"; not in `refs/`).

## Decision

**A reverse fold opens its tip at one *opening*.** An opening is a place
between two neighboring layers of the tip where every hinge that joins a
layer above it to a layer below it lies on the line of the spine. The
opening cuts the tip into an upper and a lower block. Each block is
reflected across the axis as a whole; every hinge that joins the two blocks
turns, and every other hinge of the tip keeps its letter. The axis becomes
a new crease through every layer of the tip. For `inside` the blocks go in
between the layers of the body, for `outside` they wrap around it.

**A tip with more than one opening makes the reverse ambiguous**, as a
flatten with more than one state is (#99). The error offers an item per
opening, a letter on a hinge of the spine's line, as `flatten` takes
letters: `(--e & .q valley)`. The square needs one; the crane's neck, tail
and head have one opening each and need none.

A reverse fold is the fan at the point where its axis meets the line of the
spine (#119, [[decisions/a-fan-vertex-may-lie-off-the-paper]]).

## Alternatives considered

- **One spine, as `def-reverse` states.** It reaches only the opening below
  the outermost layer.
- **Every hinge on the spine's line turns**, [[decisions/a-reverse-fold-turns-every-spine-of-its-tip]], or **every hinge
  inside the spine's taco**, an earlier draft of this record. The crane's
  head has no flat state under either.
- **A default opening.** None holds in general: the square folds either
  way, and a folder chooses by where they open the flap.
- **Naming the opening by a layer of the body** (`under #[…]`) or by
  counting layers. A flap selector cannot name many layers of a stacked
  model, and a count changes when an earlier step changes; a hinge can
  always be named by its crease and a paper point on it.

## Consequences

- `def-reverse` and `cor-reverse-letters` in [[reference/model]] define the
  opening and its blocks in place of the spine and its halves.
- The acceptance case of #119 is the square with the opening between the two
  inner layers: 4, 3, 7, 6, 5, 8, 2, 1 along the top edge. The crane keeps
  its output.
