---
id: "0042"
title: "A reverse fold turns every folded hinge of its tip on the spine's line"
date: 2026-09-30
status: accepted
issue: tophcodes/beloch#119
---

# 0042: A reverse fold turns every folded hinge of its tip on the spine's line

## Context

`def-reverse` in `docs/reference/MODEL.md` picks one *spine*: a folded hinge of the tip
whose removal cuts the tip into two halves. It reflects the two halves as
two blocks, one against each body, and every other hinge of the tip keeps
its letter. The write is defined when exactly one admissible spine yields a
state.

A tip of several layers can carry several folded hinges on the line of the
spine. Folded on paper: a square folded in half, then in half again in the
same direction, gives four layers with two folded hinges nested on one edge
and one on the other. An inside reverse of the lower half along the
horizontal middle turns both nested hinges. Seen along the top edge, from
the top down, with the pieces numbered 1 to 4 across the upper half and 5
to 8 across the lower half, the paper reads 4, 3, 7, 6, 5, 8, 2, 1: four
nested tacos on the edge that carried the two hinges, and on the other edge
two tacos above four single layers. The definition gives 4, 3, 2, 8, 7, 6,
5, 1: one hinge turns, and the lower half's other three layers go up as one
block.

The neck, tail and head of the crane are reverse folds through several
layers. Their geometry was checked against Ida's figures; their layer order
was not.

## Decision

**A reverse fold turns every folded hinge of its tip that lies on the line
of the spine.** The tip is unchanged: the material beyond the axis joined to
the anchor. Every folded hinge between two faces of the tip on the table
line of the spine reverses its letter, and every other hinge of the tip
keeps its letter. For *inside* the tip goes in between the layers of the
body, for *outside* it wraps around them.

A reverse fold is the fan at the point where its axis meets the line of the
spine (#119, ADR 0041). Its rays are the spine's line in the body, where
every hinge stays, the spine's line in the tip, where every hinge turns, and
the axis on each side of the spine's line, where each layer takes a new
crease. `inside` and `outside` are placements the write hands to the fan.

## Alternatives considered

- **One spine, as `def-reverse` states.** It gives a state the paper does not
  reach on a tip of several layers, and it leaves the choice of spine to an
  admissibility test that fails on the crane's outside reverse as ambiguous.
- **Every hinge of the tip turns, on any line.** A hinge of the tip off the
  spine's line folds a layer onto itself inside the tip; a reverse fold
  carries it along without turning it, as the left edge of the paper case
  shows.

## Consequences

- `def-reverse` and `cor-reverse-letters` in `docs/reference/MODEL.md` change to the
  rule above; the halves and the admissible spine go.
- The paper case above is the acceptance case of #119: `paper square`, two
  folds in half in the same direction, then `reverse (map .a onto .d)`, with
  the layer order 4, 3, 7, 6, 5, 8, 2, 1 along the top edge.
- The crane's neck, tail and head may change their layer order. #119
  compares them with the kernel's current output and states each change.
