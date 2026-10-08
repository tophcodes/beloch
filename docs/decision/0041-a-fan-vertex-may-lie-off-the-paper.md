---
id: "0041"
title: "The vertex of a fan may lie off the paper or at infinity"
date: 2026-09-30
status: accepted
issue: tophcodes/beloch#52
---

# 0041: The vertex of a fan may lie off the paper or at infinity

## Context

By ADR 0040 a fan sits at a table point. `reverse` becomes a fan at the
point where its axis crosses the spine (#119). Three reverse folds in the
test cases fold a sheet in half and reverse it along a line parallel to the
crest: the strip between the axis and the crest goes in between the two
layers, the crest turns, and each layer takes a new crease on the axis. The
axis and the spine never meet. The same state folds from the flat sheet with
three plain folds along parallel lines, so it is a valid state and a valid
reverse fold. A reverse whose axis meets the line of the spine beyond the
paper's edge is the same case with a finite vertex.

The vertex contributes one condition to a fan: the motions of the sectors
close around it, Kawasaki's condition in `def-flatten`, and with an odd
number of rays the emergent ray that makes them close. The condition holds
because the paper surrounds the vertex. When the vertex lies on the edge,
off the paper or at infinity, no path on the paper goes around it.

## Decision

**The vertex of a fan is a point of the projective table**: a point of the
table, or a point at infinity, one for each direction. The rays are the
creases on lines through it. At a point at infinity the lines are parallel
and the sectors are strips.

**The closure condition applies only to a vertex inside the paper.** A fan
whose vertex lies on the paper's edge, off the paper or at infinity has no
condition at its vertex and no emergent ray. What it still has to satisfy
is the non-crossing of its layers, which every state satisfies.

`reverse` needs no case of its own for a parallel axis or a vertex off the
paper: its fan is the fan at the meeting point of its axis and its spine,
wherever that lies.

## Alternatives considered

- **A reverse fold whose axis does not cross the spine on the paper is an
  error.** The parallel reverse is a valid fold, and forbidding it removes a
  state the language can reach only by unfolding to the flat sheet first.
- **Reverse keeps a path of its own for the parallel case.** `reverse` would
  be two operations, against the decision in #52 that it is syntax over the
  fan.

## Consequences

- `def-flatten` in `docs/reference/MODEL.md` takes its vertex on the projective table
  and states the closure condition for a vertex inside the paper.
- Off the paper, that the lines of a fan meet in one point carries no
  physical meaning: any two creases meet somewhere or are parallel. Three creases
  that do not share a point and are folded at once are no fan; they belong
  with folds at several vertices (the petal fold, #16).
- #119 folds the parallel reverse cases through the fan with unchanged
  output.
