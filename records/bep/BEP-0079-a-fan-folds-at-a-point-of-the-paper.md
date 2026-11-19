---
id: BEP-0079
title: "A fan folds at a point of the paper"
date: 2026-11-19
status: accepted
issue: tophcodes/beloch#189
reference:
  - reference/model#def-flatten
  - reference/model#term-tip
  - reference/beloch
  - reference/beloch-writes
  - reference/beloch-writes#flatten-and-flip
  - reference/beloch-grammar
amends: [BEP-0037, BEP-0040, BEP-0041, BEP-0044, BEP-0048, BEP-0055]
superseded-by: null
---

# BEP-0079: A fan folds at a point of the paper

## Summary

A fan of `flatten` folds several creases through one point in one motion.
Until now that point was a point of the table, and every layer under it took
every ray. This record puts the point on the paper: a fan folds the creases
that pass through that paper point, in the layers that meet there, and the
paper decides which parts move. A fan that is to fold several layers stacked
under one table point says so with `(up to <flap>)`. `flatten` takes no
`on` item any more.

## Example

A unit square is folded in half along `--s`, the half with `.a` on top.
`.v` is the middle of `--s`, a paper point where both layers meet. The
program scores `--k` through both layers and `--m1` and `--m2` in the top
layer alone, then folds one fan at `.v`:

```beloch
paper square
fold (map --ab onto --cd) (moving .a) as --s
.l = --s * --da
.r = --s * --bc
.v = free on --s from .l at 1/2
.e = free on --ab from .a at 1/2
mark (through .v .c) as --k
mark (through .v .a) (on #[.a]) as --m1
mark (through .v .e) (on #[.a]) as --m2
flatten (--s & .r) (--k & .c valley) (--m1 mountain) (--m2 valley) (staying .d)
```

![Figure 1: the crease pattern after the fan, on the unit square. --s runs
from .l through .v to .r, folded left of .v and flat right of it. --k runs
from .v to .c as a valley in the bottom layer and from .v to .b, flat, in
the top layer; its name stands near .c. --m1 runs from .v to .a as a
mountain, --m2 from .v to .e as a valley.](figures/0079-crease-pattern.svg)

![Figure 2: before the fan. Left, the folded square with a cut across it;
middle, the crease pattern with --s, --k, --m1, --m2 and the points
labeled, and the pieces the cut crosses numbered; right, the section. The
top layer, pieces 1 to 4, carries --m1, --m2 and --k; the bottom layer,
pieces 5 and 6, carries --k alone.](figures/0079-before-the-fan.svg)

![Figure 3: after the fan, with the same cut. In the section the moved
pieces 6, 5 and 4 lie on top and turn at --k into piece 3 of the bottom
layer; pieces 2 and 1 of the top layer turn at --m1 and lie
between.](figures/0079-after-the-fan.svg)

`(--k & .c)` takes the piece of `--k` from `.v` to `.c`, in the bottom
layer; the piece from `.v` to `.b` in the top layer also passes through
`.v` and stays flat (Figure 1). The bottom layer folds along `--k`, and the
top layer folds along `--m1` and `--m2`. The part that holds `.d` stays,
and the triangle `.v` `.l` `.a` stays with it: `--s` left of `.v` joins
them and is no ray. The rest moves: the part that holds `.r` and `.b`
turns over about `--k` and lands on top, the triangle `.v` `.a` `.e` turns
about `--m1`, the two fold against each other at `--m2`, and `--s` opens
right of `.v` (Figure 3).

Under the rule of [[BEP-0055]] the fan folds every ray in every layer under
`.v`. It scores `--m1` and `--m2` into the bottom layer as well and folds
`--k` in the top layer, `--s` stays folded on both sides of `.v`, and the
whole square stacks into one triangle, a fold the program does not
describe.

The case comes from the traditional frog's first petal fold [tanfrog]
(tophcodes/beloch#189). Tan creases the kite crease of step 9 through both
layers of the front flap; the petal fold folds it in the lower layer alone
and leaves it flat in the top layer, which folds along other creases
through the same point.

Fisher's waterbomb base through both layers of a rectangle folded in half
[fisher1994, §5.3] folds one fan through two layers that lie under one table
point. One fan item with `up to` states it:

```beloch
.n = (--d1 & .b) * --d2
flatten (fan at .n (--d1 & --ab valley) (--d1 & .s1 valley)
                   (--d2 & .s0 valley) (--d2 & --cd valley)
                   (--v & --ab mountain) (--v & --cd mountain)
                   (up to #[.a]))
        (staying .b .c)
```

![Figure 4: a section across the folded waterbomb base. Left, the folded
triangle with the cut drawn across both flaps; middle, the rectangle with
the creases --d1, --d2 and --v labeled and the pieces the cut crosses
numbered 1 to 6 on one half and 7 to 12 on the other; right, the twelve
pieces stacked, with a hinge at every turn labeled --d1, --d2 or
--v.](figures/0079-waterbomb-section.svg)

Figure 4 shows a section across the folded base: the pieces 1 to 6 of one
layer and 7 to 12 of the other turn at the same creases `--d1`, `--d2` and
`--v`, and the two layers fold as one stack.
`packages/core/tests/cases/collapse/flatten-waterbomb-both-layers.bel` folds
this statement.

## Rule

In [[reference/model#def-flatten]]:

- The vertex of a fan of `flatten` is a paper point $v$, and the fan folds
  at its table position $f(v)$. `fan at` names it; otherwise it is the
  paper point where the bundles of the rays meet. `reverse` and `squash`
  keep their vertex on the table and their anchor.
- A ray is a bundle. The fan uses the pieces of the bundle that pass
  through $v$, and a ray with no such piece makes the write undefined. A
  ray given as a construction is scored through every layer that meets at
  $v$. A hinge on the table line of a ray that does not pass through $v$ is
  no hinge of the fan and keeps its angle. The write scores the emergent
  ray of an odd fan, whose wedge `(emergent beside .p)` names
  ([[BEP-0078]]), as it scores a ray given as a construction: through every
  layer that meets at $v$.
- What moves: every part of the paper that no path on the paper joins to
  the stayer without crossing a hinge of the fan. A path runs across
  hinges and never through a single point. The write is undefined when
  the moving part holds a layer under the vertex on which no hinge of the
  fan lies, and the error names that layer.
- With several fans, the crease between two vertices is the paper segment
  between them. A statement of two fans derives it where neither fan names
  it; a statement of three or more fans derives nothing.
- Without `staying`, a statement of fan items holds the part of largest
  area on the paper still. A statement of ray items holds the wedge
  between its first two rays still, as before. The
  stayer fixes where the result lies on the table and which state the
  outline ranks first ([[BEP-0058]]); where the faces lie relative to each
  other does not depend on it. A staying point no longer has to lie on an
  anchor.
- A fan with `(up to Ψ)` stands for one fan per layer under $f(v)$, from
  the topmost down to the flap $Ψ$, each at its own paper point and with
  the same rays. Those layers keep their order relative to each other in
  every sector, and `(.p over .q)` reorders single pairs.

In [[reference/beloch-writes#flatten-and-flip]] the items and the part on
fans state the same for the program: a fan item takes `(up to <flap>)`,
and a statement takes at least two fan items or one with `up to`.
`flatten` takes no `on` item, and a statement with one fails with
`` flatten takes no (on) item ``, whose hint points to `staying` and to
`up to`. The sort of `staying` in [[reference/beloch]] names points of the
paper, with no anchor. The introduction of [[reference/beloch-writes]] and the
term tip in [[reference/model]] follow. In [[reference/beloch-grammar]] the
fan item gains `up to`.

## Alternatives considered

- **The table regions of [[BEP-0055]].** A ray runs through every layer
  of the moving part under it, and the regions the rays cut the table into
  decide what moves. At `.v` the bottom layer takes `--m1` and `--m2`, the
  top layer folds along `--k`, and the square stacks into one triangle
  that the program does not describe.
- **Several flaps in `on`.** The program lists the flaps the fan folds,
  and the anchor is all of them; the example names both layers. Each ray
  still runs through every named layer under it, so both layers take
  `--k`, `--m1` and `--m2`. The list also repeats what the rays already
  say: the pieces that meet at one paper point name the layers that fold
  there.
- **A ray narrowed to a layer by a flap filter, the vertex a table point.**
  `(--k & #[.d] valley)` keeps `--k` out of the top layer. The program then
  writes on every ray a layer that the vertex fixes once, and a ray without
  a filter falls back to every layer under the table point, the reading
  that stacks the square into one triangle at `.v`.

## Open questions

- A stack under `up to` whose flaps go one into the other's pocket. The
  rule keeps the layers of a stack in their order; whether a pocket needs
  more is checked on the first model that needs it (tophcodes/beloch#189).
- The default of `fold` and `mark`: every layer under the line. The fan now
  reaches the layers that meet at its vertex, and whether `fold` and `mark`
  keep their default stays open (tophcodes/beloch#189).
- Repetition: a program that folds one fan pattern at several places
  writes one fan item per place. An item that repeats a pattern may become
  writable later (tophcodes/beloch#189).

## Consequences

- Five test cases under `packages/core/tests/cases/collapse/` change; each
  lays its fan over two paper points under one table point.
  - `flatten-waterbomb-both-layers` takes the `up to` form of the example.
    As written, its rays meet at the bottom layer's point, and the top
    layer, which the spine joins to the bottom layer, carries no ray of the
    fan.
  - `flatten-waterbomb-rays-on-top-layer` and
    `flatten-waterbomb-emergent-on-top-layer` fail. The fan stands at the
    top layer's point, the spine drags the bottom layer along, and the
    bottom layer carries no ray; the error names it.
  - `flatten-ray-on-folded-edge` fails as written for the same reason, and
    folds both layers with `(up to #[.d])` in a fan item at `.p`, with rays
    that name their halves in both layers.
  - `flatten-fan-reaches-spine` differs from `flatten-ray-on-folded-edge`
    only by its `on` item, which `flatten` no longer takes, and loses its
    subject.
- `on` leaves `flatten`: the grammar drops it, and a `flatten` with `on`
  fails. The vertex and the pieces of the rays through it decide which
  layers fold. The programs in `examples/` and the test cases that write
  `on` in a `flatten` change with the kernel, and so does the guide page
  that reads the crane, whose petal folds write `(on #[.a])` and
  `(on #[.c])`.
- The squash folds and every example under `examples/` keep their states.
- [[BEP-0037]] left the item that widens a fan to separate flaps open;
  `up to` settles it.
- The kernel change follows in its own pull request.
