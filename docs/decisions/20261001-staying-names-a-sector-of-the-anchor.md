---
title: "staying names a sector of the anchor by points"
date: 2026-10-01
status: accepted
issue: tophcodes/beloch#150
---

# `staying` names a sector of the anchor by points

## Context

A fan folds several creases through one point in one motion. Its rays cut
the paper around the vertex into sectors, and one sector, the stayer, keeps
its place. By [[decisions/a-fan-moves-its-tip]] the stayer also decides which layers move: the
candidates for the tip are the pieces outside the stayer's wedge, and the tip
grows from the anchor over hinges between candidates. Fisher's waterbomb
base on a 2:1 rectangle folded in half [fisher1994, §5.3] separates on the
stayer alone. Held in the sector along the spine, the top layer folds alone.
Held in the sector along the raw edges, the spine joins both layers into one
tip, and both fold.

`def-flatten` defines the stayer as a sector, and so do the sources: Hull's
folding map of a flat vertex fixes one face between two creases and reflects
every other face across the creases between them [hull2020, §5.7, p. 105],
and Fisher's multiple fold ends in `holding Face` [fisher1994, p. 16]. The
language disagrees. `(staying x)` takes a flap, and a flap is every face
joined to another by a flat hinge. The rays of a fan are marked before it
folds, and a mark leaves the layer one flap, so the flap of any point on a
marked layer reaches into every sector. The kernel then admits every sector
as stayer and lets the selection stages choose. On the rectangle, fewest
mountains picks the top layer alone, wherever the program says to hold it:
the kernel counts a ray as a mountain when any layer folds it as one, and a
ray through two layers back to back is a mountain in one of them. The fold
through both layers counts six, the fold of the top layer two.

Among the flattens in `packages/core/tests/cases/` and `examples/`, the
waterbomb through both layers is the only one where a selection stage picks
the stayer. Every other one has a single stayer left before the selection
stages run.

## Decision

**`staying` names a sector of the anchor by one or more points.**
`(staying p1 … pn)` names the sector of the anchor's image whose closed wedge
holds the images of every point. Each point lies on the anchor flap. A point
on a ray lies in both sectors beside it, so two points on the two rays that
bound a sector name it: `(staying .s0 .s1)` holds the sector along the spine
of the rectangle, `(staying .b .c)` the sector along its raw edges.

It is an error when a point lies off the anchor, when no sector holds every
point, when more than one does, or when the named sector holds no material of
the anchor.

**The stayer is fixed before the selection.** The candidates a selection
compares share their stayer. A program that leaves the stayer open with
several sectors possible fails as ambiguous, and the hint suggests a
`staying` item for each.

**The sector is a region of the anchor.** Where several layers lie in the
wedge, the tip rule decides which of them move; the layer a point lies on
only has to be the anchor's.

At an odd fan the sectors are known per candidate fan, after its emergent ray
is placed: a candidate fan contributes states when exactly one of its sectors
holds every point. At a vertex at infinity ([[decisions/a-fan-vertex-may-lie-off-the-paper]]) the sectors are strips
and two half-planes.

## Alternatives considered

- **`staying` keeps the flap.** Every fan on a marked layer then leaves the
  stayer to the selection, and Fisher's two waterbomb bases cannot be told
  apart by what the program holds.
- **The sector as a region of the table, the layer of a point free.** A
  point on another layer than the anchor then names a sector whose layer
  plays no part, and `(staying .a)` with `.a` on the lower layer reads as
  "the lower layer stays" while the tip rule may move it.
- **`#[…]` names a sector in the `staying` slot.** One bracket would name a
  flap in `on` and `moving`, a face in `over`, and a sector in `staying`, all
  three possibly in one statement.
- **Several sectors as alternatives.** The selection stages then pick where
  the paper is held, which is the behavior this record ends.
- **Several sectors held at once.** Two sectors both keep their place only
  when the reflections across the rays between them compose to the identity;
  the second sector then stays without being named, and otherwise no state
  holds both.

## Consequences

- The `staying` row of the selector table in [[reference/beloch]] moves from
  flap to a sort of its own, one or more points, and `def-flatten` in
  [[reference/model]] names the stayer by points with the errors above.
- The fewest-mountains stage loses its effect on the stayer; tophcodes/beloch#99 removes
  the selection stages of `flatten` altogether.
- `flatten-waterbomb-top-layer.bel` holds the rectangle with
  `(staying .s0 .s1)`, and the case through both layers with
  `(staying .b .c)`, without `toward`.
- The `staying` items of the other cases name single points on their anchor
  and keep their meaning.
- Both layers of the rectangle folded while the sector along the spine is
  held take two statements: a flatten of the top layer, then one with `on`
  the bottom layer. The second one has flat states with the bottom layer
  folded outward, below the stack, wrapped around the top layer's folded
  stack, inside the gap between the layers, and interleaved with the top
  layer's pieces. Doing it in one statement waits on the item that widens a
  fan to separate flaps ([[decisions/a-fan-moves-its-tip]]); it changes no geometry, only which layer
  orders the statement admits.
