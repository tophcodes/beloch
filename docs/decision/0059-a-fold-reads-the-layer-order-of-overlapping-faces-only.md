---
id: "0059"
title: "A fold reads the layer order of overlapping faces only"
date: 2026-11-18
status: proposed
issue: tophcodes/beloch#3
---

# 0059: A fold reads the layer order of overlapping faces only

## Context

A flat folded state orders two faces only where they overlap on the table
(`def-flat-state`). The kernel stores one total order of all faces, the
*rank*, and reads the order of an overlapping pair from it. The model
states that two ranks with the same order on every overlapping pair
describe the same state (`rem-linear-extension`).

A fold that places a moved block next to a face broke that statement. The
inside reverse fold and a fold with `over` or `under` put the block
directly above or below one face, the *anchor*, and the kernel spliced the
block into the rank at the anchor's place. The block then lands on faces
it did not overlap before. Where such a face overlaps the anchor, or a
chain of overlapping faces joins the two, the state says on which side of
the block the face lies. Where no chain joins them, the state says
nothing, and the splice took the side from the rank.

The crane showed the consequence (issue 274). The bird base by four
reverse folds and the bird base by two petal folds are the same state on
every overlapping pair, with different ranks. The reverse fold of the neck
found one opening of the leg on the first and two on the second.

## Decision

**A fold decides the side of a face from the overlapping pairs of the
state it folds, and from nothing else.** For a block placed next to an
anchor:

- A stationary face that is above the anchor, directly or through a chain
  of overlapping faces, is above the block. A face below the anchor the
  same way is below the block.
- A stationary face the block lands on that no chain joins to the anchor
  is *free*. The kernel folds the block with each free face above it and
  below it, in every combination the order of the stationary faces
  allows, and keeps each stacking that passes the checks of a flat state.

**Each stacking kept is a state of the fold.** A fold with one is that
state. A fold with several fails and names their number; the program
chooses with the items the write has. A reverse fold counts them among
its openings, so its message stays `the tip opens at <n> places`, and its
letter items choose.

**The rank stays the stored form for now.** It is read where two faces
overlap or a chain joins them, and its order of other pairs changes no
result of a fold. Storing the pairs in its place is the second step
(issue 72).

## Alternatives considered

- **A fixed rule for a free face**, such as the side that keeps the block
  nearest to its anchor in the rank. The program needs no extra item. The
  rule hides states that fold flat, and which one it hides follows from
  an order the state does not have: the fault of issue 274 by design.
- **A canonical rank**, built from the overlapping pairs with ties broken
  by the position of a face on the paper. Two routes to one state then
  give one result. The result is still one of several, chosen by the tie
  rule.
- **The pairwise relation first, the fold after it.** The search for the
  free faces is the same on either stored form, and the crane needs it
  now.

## Consequences

- The neck and the tail of the crane each open at three places: in the
  middle, between the top two layers and the six beneath them, and
  between the bottom two layers and the six above them. Each reverse fold
  takes two letter items. Before, the program folded with none on one
  route and with one on the other.
- A program that folded with a block placed `over` or `under` a face can
  stop with several stackings. The corpus has no such program.
- The search doubles with each free face. Above 12 free faces the kernel
  keeps the order the rank holds; the bound goes when the pairs replace
  the rank.
- States with a cyclic layer order, such as the square twist
  [hull2020, §6.5, p. 119], stay out of reach until the pairs are stored.
