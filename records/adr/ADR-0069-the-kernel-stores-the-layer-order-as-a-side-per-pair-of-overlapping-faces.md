---
id: ADR-0069
title: "The kernel stores the layer order as a side per pair of overlapping faces"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#3
---

# ADR-0069: The kernel stores the layer order as a side per pair of overlapping faces

This record holds the architecture part of [[BEP-0060]], which decided both kinds.

## Context

A folded state is made of faces, the flat pieces of paper between creases,
each lying at some place on the table. Where two faces overlap on the table,
one of them lies on top of the other. The model calls the record of which
one lies on top the layer order $\lambda$
([[reference/model#def-flat-state|def-flat-state]]). The layer order has an
entry for every two faces that overlap and none for two faces that lie
apart.

The kernel, the program that evaluates Beloch, stored the layers as one list
of all faces from the bottom of the stack to the top. A face's place in the
list was its height, and of two overlapping faces the higher one lay above.
This form has two faults.

A list orders every two faces, also two that do not overlap. The paper does
not order those. [[BEP-0059]] stopped one fold from reading that order:
when a fold pushes paper between layers, the kernel decides the side of each
layer from the paper. Other operations still read heights. A fold that
places paper `over` or `under` a named flap took the face of that flap with
the highest or the lowest height. A reverse fold whose openings gave the
same state kept the list that put the new hinges closest together. A
`flatten` with `toward` weighed each face by its height. Each of these reads
gives a result that depends on the route by which the state was reached.

A list cannot hold a state whose layers overlap in a cycle. The square twist
is such a state. In the square twist, four pleats leave the four sides of a
square in the middle of the sheet; folded flat, the square turns against
the rest of the paper. Its four large faces, one at each corner of the sheet
between two pleats, each overlap the next one around the square, and they
lie over, under, over, under around the twist. A list from bottom to top
would have to put each of them above the one before it and below the one
after it, which no list does, and the square twist folds flat
[@hull2020, §6.5, p. 119]. The model states the consequence: a
representation that stores one list cannot hold every state
([[reference/model#rem-linear-extension|rem-linear-extension]]).

## Decision

**A state stores, for every two faces that overlap on the table, which one
lies above.** Two faces overlap when their places on the table share a
region of positive area. Two faces that touch along an edge or at a point
lie apart, and the state has no entry for them. This is $\lambda$ of the
model and the form of `faceOrders` in the FOLD output ([[reference/fold]]).
The list is removed, and no operation reads a height of a face.

A caller can still describe a state by a list from bottom to top, since a
stack is often easiest to write down that way. The kernel then keeps the
side of every overlapping pair and drops the rest of the list, so two lists
that agree on every overlapping pair give one state. A state whose layers
lie in a cycle has no such list; a caller builds it from its pairs.

**The kernel checks the pairs against three conditions of the model.**

1. **Order** ([[reference/model#cond-order|cond-order]]): three faces that
   share a region of positive area do not lie in a cycle. Three faces
   suffice. All faces over one point of the table overlap pairwise, and an
   order on faces that overlap pairwise has a cycle only if it has a cycle
   of three.
2. **Taco-tortilla**
   ([[reference/model#cond-taco-tortilla|cond-taco-tortilla]]): a face that
   crosses a folded crease does not lie between the two faces the crease
   joins.
3. **Taco-taco** ([[reference/model#cond-taco-taco|cond-taco-taco]]): two
   folded creases that lie on one line of the table do not interleave
   their faces.

The two taco conditions compare only faces that overlap where they are
compared. Take two folded creases on one table line whose pairs of faces
open to opposite sides of the line. The two pairs share no region, and no
condition relates them [@hullzakharevich2023, §2.1, "Taco-Taco Property";
@akitaya2016, §2]. With heights, the kernel compared such pairs too and
rejected states that the model allows.

**A fold computes the pairs of the new state from the pairs of the old
one.**

- Two faces that stay keep their side.
- Two faces of one moved block exchange sides, since the block turns over.
- A plain fold puts the moved face above every staying face it lands on
  for a valley fold, and below every such face for a mountain fold.
- A fold that pushes paper between layers decides the new pairs by the
  three conditions of [[BEP-0059]].

**The stacking search of `flatten` keeps its lists.** A `flatten` folds
several pieces of paper around one point at once. The kernel searches the
orders of those pieces, the units of the search, as lists from bottom to
top, and turns each list it keeps into pairs as the constructor does. The
search finds no state whose layers lie in a cycle.

## Alternatives considered

- **Keep the list beside the pairs for a transition**, and move each
  operation to the pairs on its own. Every operation left reading the list
  keeps the dependence on the route that [[BEP-0059]] removed for one
  fold, and while the list is stored, no state with a cycle exists.
- **Store one list per region of the table**, a region being a part of the
  table that the same faces cover. Inside one region every two faces
  overlap, so such a list orders nothing that the paper leaves open. The
  regions change with every fold, and a face that reaches into several
  regions stands in several lists that have to agree. The pairs are what
  the model and FOLD name.

## Consequences

- The kernel accepts the square twist built by hand from its pairs: 9
  faces, 12 folded hinges and 28 overlapping pairs, in which the four
  corner faces lie in a cycle. A test holds that. No Beloch program folds
  the square twist yet.
- The taco conditions follow the model. Two folds on one table line that
  open to opposite sides no longer reject a state.
- The point [[BEP-0059]] left open is closed: a fold that places paper
  `over` or `under` a named flap reads no list.
- The renderers sort `faceOrders` into one drawing order. A state with a
  cycle has none. This decision does not address that.
- The inspector output `beloch:inspect` carries no height per face. The
  playground's stack picker reads `faceOrders`.
- The crane evaluates in about 1.75 s, where it took about 1.9 s.
- The stacking search of `flatten` has two ceilings. It finds no state with
  a cycle and cannot start from one: it derives its list from the pairs,
  and a state with a cycle has none. Its list also orders faces that do not
  overlap, the faces free to come next in the order of their index, and
  the pruning of the search reads that order. A search over pairs removes
  both (issue 285).
- The constructor that takes pairs checks no condition at a flat hinge, a
  hinge of angle 0: a face that covers part of such a hinge has to lie on
  one side of both of its faces, and a list of pairs that says otherwise
  passes. Every state an operation builds satisfies it (issue 284).
