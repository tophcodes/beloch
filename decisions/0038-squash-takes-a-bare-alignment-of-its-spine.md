---
id: "0038"
title: "squash takes a bare alignment of its spine; the vertex completes the axis"
date: 2026-09-29
status: accepted
issue: tophcodes/beloch#52
---

# 0038: squash takes a bare alignment of its spine; the vertex completes the axis

## Context

A squash opens a flap of two layers hinged at a folded edge, its *spine*,
and presses it flat so that the spine lands on a target. On the preliminary
base the kernel folds the squash of one flap as an eight-ray fan at the
paper center:

```beloch
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
mark (align (--h onto --ac) (heading --h)) as --s
mark (align (--h onto --bd) (heading --h)) as --t
.z = free on --cd from .c at 1/4
flatten (--h & --bc valley) (--v & --cd valley) (--bd & .d mountain) (--t & --da valley) (--s & --da mountain) (--ac & .a valley) (--v & --ab valley) (--bd & .b mountain) (staying .z)
```

The spine `--h & --da` opens and lands on the center line of the base, where
`--ac` and `--bd` lie. The new creases `--s & --da` and `--t & --da` lie one
on each layer of the flap. Before the squash the two layers lie on each
other, mirrored at the spine, and the mirror image of `--s` is `--t`: the two
new creases are one line on the table, the bisector of the spine and its
target. A squash is fixed by that line and the flap it moves.

Written as a `flatten`, the squash takes eight rays for a step a diagram
gives with one word and an arrow. The anchor of a fan is the flap that
carries its point, and a fan moves its tip (ADR 0037).

The axis of a squash passes through the *vertex*: the end of the spine
inside the paper, where the other folded hinges of the flap meet. A spine
laid onto a line fixes the axis up to the choice of bisector, which passes
through the vertex already. A spine laid onto a point leaves a family of
lines, and the vertex picks from it. Written as a construction, that is
`align (--h & --da onto .p) (through .o)`, which states the vertex the write
already knows.

## Decision

**`squash` takes a bare alignment of its spine.** The item is an alignment
without `map` or `align`, its first object a line on the spine and its
second the target, a line or a point:

```beloch
squash (--h onto --ac)
squash (--h onto .p)
```

The write completes the alignment with the fold line through the vertex. The
axis is the line that satisfies both. The anchor is the flap whose spine the
first object names, and the squash moves the tip of that flap: the spine
opens, and each layer of the tip folds along its piece of the axis. The
missing `map` marks the item as incomplete on its own; a construction with
`map` or `align` keeps determining its lines by itself.

**The spine is found by incidence.** When several flaps have a spine on the
named line that the target admits, the write fails as ambiguous and the
error offers the items that keep one, as `flatten` does (#99).

**Only `squash` takes a bare alignment.** A reverse fold crosses its spine
at any point along it, so nothing in the write fixes a second condition, and
`reverse` keeps its complete constructions.

## Alternatives considered

- **The explicit fan**, a `flatten` with a letter that opens the spine. It is
  the general form and exists today; it takes eight rays for the squash of
  one flap of the preliminary base.
- **A construction as axis, `squash (map --h onto --ac)`.** It is the same
  line for a spine onto a line. For a spine onto a point, `map` would have
  to be completed by the write, and `map` would mean something under
  `squash` that it means nowhere else.
- **`squash --h onto --ac` without parentheses.** A statement form outside
  the items, which every write so far is made of.
- **A bare alignment for `reverse` as well.** `reverse (--x onto .p)` leaves
  a family of axes, since a reverse fold has no vertex to complete it.

## Consequences

- The grammar gains the verb `squash` and its item, a bare alignment beside
  the side items. `spec/BELOCH.md` states it when the kernel folds it.
- `spec/MODEL.md` defines the squash as a fan (#52): its axis, its anchor and
  the spine it opens.
- A spine whose two ends both lie inside the paper has two vertices. Which
  one a bare alignment completes with is open until a model needs it.
