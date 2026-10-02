---
id: "0044"
title: "A fan moves each piece by the creases on its paper path"
date: 2026-09-30
status: accepted
issue: tophcodes/beloch#133
---

# 0044: A fan moves each piece by the creases on its paper path

## Context

By ADR 0040 a fan sits at a table point, and every layer under it is scored
along the fan's lines. `def-flatten` then gives one motion to each wedge of
the table between two neighboring rays: every piece in the wedge moves by
the reflections across the rays between it and the stayer. Around the table
point the motions have to close, which is Kawasaki's condition, and ADR 0041
drops the condition where the vertex lies on the paper's edge, off the paper
or at infinity.

The vertex of a reverse fold and the vertex of a squash lie on a folded edge
(#133). Two things break there.

- **The motions of one wedge differ.** The squash of the flap with spine
  `--h & --da` on the folded preliminary base has its vertex at the base's
  closed corner. The kernel folds the same squash from the flat sheet
  (ADR 0038); compared piece by piece with the base, three pieces move:

  | piece | layer of the base | before, on the table | motion |
  |---|---|---|---|
  | 1 | top | (0.74, 0.83) | reflection across the center line |
  | 2 | top | (0.57, 0.83) | rotation by 45° about the vertex |
  | 7 | second | (0.57, 0.83) | reflection across the axis |

  Pieces 2 and 7 lie in one wedge and move by two reflections and by one.
- **Kawasaki's condition at the table point does not hold.** The layers of
  the tip lie in a 45° wedge and do not surround the table point. For a
  reverse fold the condition at the table point holds only when the axis is
  perpendicular to the spine, while every reverse fold is flat-foldable.

Hull defines the placement of a flat fold by a path on the paper: from a
fixed face to a point, reflect across each crease the path crosses, in
order [hull2020, Def. 6.5]. The placement is well defined because every
closed path gives the identity, which for a flat-foldable crease pattern is
Kawasaki's condition at every vertex the path encloses [hull2020,
Thm. 6.6]. `Fold_state` already places faces this way: a state is built
from hinge angles and a root face, and a state whose cycles do not close is
rejected.

## Decision

**A fan moves each piece by the creases on its paper path.** The fan keeps
its lines on the table through its vertex (ADR 0040, ADR 0041), and every
layer of the tip is scored along them. A hinge on those lines *changes*
when a flat hinge folds or a folded hinge opens, and *keeps* otherwise; a
folded hinge that keeps may turn, as the spine of a reverse fold does. The
motion of a piece is the product of the reflections across the changing
hinges that a path on the paper crosses from the stayer to the piece
[hull2020, Def. 6.5]. The stayer is a piece of paper, named by the program
or its convention as today.

**The closure condition is that every closed path on the paper gives the
identity** [hull2020, Thm. 6.6]. Around a paper point that the paper
surrounds, this is Kawasaki's condition at that point. The fan has no
condition of its own at the table point. Where no paper point is surrounded,
nothing is checked: the vertex on the paper's edge, off the paper and at
infinity of ADR 0041 are cases of this rule. An emergent ray is the crease
that closes the path around a surrounded paper point.

**The sectors of a fan are pieces of paper.** A sector is a piece of the tip
between hinges on the fan's lines. The units the stacking orders are the
pieces of one wedge of the table that share one motion, so two pieces in one
wedge that move differently are ranked apart. The wedges still pick the
stayer and the candidates of the tip (ADR 0037).

**Letters belong to hinges.** An item of a fan names the hinges of its
crease on its ray, in every layer; its paper point picks the ray, as in
`(--s & --da mountain)`. Two hinges on one line of the table that belong to
different creases take different letters, as `--s` and `--t` of a squash
do. The letter of an item holds at its hinge whose face on the clockwise
side of the ray lies lowest; the other hinges it names take the letters the
stacking gives them.

**The write tries the hinges it is not told about both ways.** A flat hinge
an item names folds. A folded hinge an item names keeps or opens, and a
hinge on the fan's lines in the tip that no item names keeps or changes;
the write takes each such hinge both ways and keeps the combinations whose
motions close and whose state satisfies non-crossing. The letters and the
other items select among them. More than one state left makes the fan
ambiguous, and the error offers the items that keep one (#99). Trying the
flat hinges of the items as well would make a flatten on the flat sheet
ambiguous wherever a subset of its rays folds flat on its own: the four
medians of the preliminary base fold the quarter fold.

## Alternatives considered

- **Kawasaki at the table point, dropped on a folded edge**, one motion per
  wedge and letters per hinge. The smallest change to `def-flatten`. Pieces 2
  and 7 of the squash share a wedge and need two motions, so the squash stays
  out of reach of the fan.
- **Separate operations.** `reverse` keeps its opening and blocks (ADR 0043)
  and `squash` gets a path of its own. Against #52, which made the three one
  operation in the kernel.
- **The program names the hinges that change.** A squash would name its
  opening spine and the center line besides its axis, which the bare
  alignment of ADR 0038 exists to leave out.

## Consequences

- `def-flatten` in `spec/MODEL.md` takes its motions from paper paths, its
  closure from closed paths and its sectors as pieces. On the flat sheet a
  piece's path crosses the rays between the stayer and it, so every flatten
  on one sheet keeps its result.
- The blocks of a reverse fold (ADR 0043) follow: every piece of the tip
  reaches the body across the axis once and moves by the reflection across
  it, and the hinges across the opening keep and turn. `reverse` can move
  onto the path of `flatten` without a case of its own.
- The squash of #115 is a fan whose axis, opening spine and center line are
  found by trying the hinges; its bare alignment (ADR 0038) needs no more.
- The kernel builds each candidate as a state from hinge angles, which
  `Fold_state` checks for closure. The number of combinations doubles with
  every hinge on the fan's lines in the tip.
