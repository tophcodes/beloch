---
id: BEP-0059
title: "A fold orders two faces only where they overlap"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#274
---

# BEP-0059: A fold orders two faces only where they overlap

## Context

Fold a crane as far as the narrowed legs and look at it from the side. One
leg is a stack of eight layers. The body is a second stack next to it. The
two stacks do not touch.

![A section through the crane before the neck is folded. On the right the
eight layers of one leg, on the left the layers of the body beside
it](figures/0059-crane-leg-section.svg)

On paper, "this layer lies on top of that one" means something only for
two layers that overlap. A layer of the leg and a layer of the body beside
it are neither above nor below each other. The model says the same: the
layer order relates overlapping faces only
([[reference/model#def-flat-state|def-flat-state]]).

The kernel, the program that evaluates Beloch, stores the layers as one
list of all faces, the flat pieces of paper between creases, from the
bottom to the top. A list has to put the leg's layers and the body's layers in some
order, so it holds an order the paper does not have. The model allows
that, on one condition: two lists that agree on every overlapping pair are
the same state ([[reference/model#rem-linear-extension|rem-linear-extension]]).

The neck of the crane broke that condition. An inside reverse fold opens
the leg between two of its layers and pushes its tip in between them. The
tip comes to rest on layers of the body that it never touched before. To
say whether the tip goes over such a layer or under it, the kernel looked
at where the layer stood in the list. The bird base folded by reverse
folds and the bird base folded by two petal folds are the same paper with
different lists, and for the same neck fold the kernel found one way to
open the leg on
the first and two on the second (issue 274).

## Decision

**When a fold pushes paper between layers, the kernel decides the side of
every layer the paper lands on from the paper, and reads the list only for
two layers that overlap.** Three conditions decide a side:

1. **The paper lies on the layers it is pushed between.** In a reverse
   fold these are the outermost layers of the two halves of the opened
   stack. The pushed paper lies directly on them.
2. **A layer keeps its side.** Take a layer that lies under one of the
   layers of condition 1. Where the two and the pushed paper all lie over
   the same spot, the layer lies under the pushed paper too. A layer that
   lies over one of them lies over the pushed paper the same way
   ([[reference/model#cond-order|cond-order]]).
3. **A sheet is not pierced.** A layer that lies across a crease is on one
   side of both faces that meet in the crease, whether the crease is
   folded or flat
   ([[reference/model#cond-taco-tortilla|cond-taco-tortilla]]). A side
   known for one face carries over the crease to the next.

The kernel applies the conditions until no side changes. If two of them give one
layer opposite sides, the paper cannot be folded that way, and the fold is
invalid.

**A side that no condition decides is a choice of the folder.** The kernel
folds every combination of the open sides and keeps those that give a flat
state. One left is the result. Several left are an error that states their
number, and the program chooses; for a reverse fold they count among its
openings, and its letter items choose. With more than 10 open choices the
fold fails and says so. The kernel never falls back to the list.

**A reverse fold reads the openings of a stack from layers that overlap.**
Which layers of the tip lie on which is taken where they overlap, so the
openings are the same for every list of one state.

## Alternatives considered

- **Keep the list and make it the same for both routes**, by rebuilding it
  after each fold with a fixed rule for layers that do not overlap. Two
  routes then agree. The rule still picks a side the paper does not
  determine, and it hides the other ways the paper folds.
- **Try both sides of every undetermined layer and keep what folds flat.**
  This was built first. It concluded a side from chains of layers that
  overlap in different places, which the order condition does not allow,
  and it tested 512 combinations where the three conditions above leave
  none open.
- **Store a side for each overlapping pair in place of the list.** This is
  the form of `faceOrders` in the FOLD format, and the kernel is to move to it (issue
  72). The three conditions are what decides the new pairs of a fold in
  that form too, so they come first.

## Consequences

- The leg of the crane opens at three places for its neck: in the middle,
  between its top two layers and the six beneath them, and between its
  bottom two layers and the six above them. This holds on both routes to
  the bird base. The program names the middle one with two letter items,
  for the neck and for the tail. A letter item names a crease of the leg
  and the letter, mountain or valley, the crease has after the fold;
  each opening leaves the two narrowing creases of a leg with its own
  pair of letters:

  ```beloch
  reverse (perp --n1 through .sr) (moving .b)
    (--n1 & .pn mountain) (--n3 & .pn3 mountain) as --neck
  ```
- On the crane's neck the three conditions decide every side, and nothing
  is left to try.
- The list stays the stored form. A state whose layers overlap in a cycle,
  such as the square twist, stays out of reach until the pairs replace it
  (issue 3).
- A fold that places paper `over` or `under` a named flap still picks the
  layer of that flap by the list. That is open.
