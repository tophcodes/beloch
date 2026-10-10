---
title: Operands
description: How a statement names a point, a line or a flap. By name, by the meet of creases, by the join through points, by filtering a crease to its pieces, and by the points a flap carries.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

A statement takes its arguments as operands, each of the sort its slot
takes ([[reference/beloch#parameter-types]]). A name is one operand. The
others are reads: they select geometry that is already there, by
incidence in paper coordinates, and score nothing
([[reference/model#def-selector|def-selector]]). A read stands wherever
its sort is wanted, nests in another read, and binds to a name with `=`;
the grammar of the forms stands under [[reference/beloch-grammar#operands]].
The constructions, the reads that compute a new line from points and
lines, have a page of their own ([[reference/beloch-constructions]]), and
the free point stands under [[reference/beloch#free-points]].

Every program on this page starts from a square with its two diagonals
marked:

```{.bel .prelude name=diagonals}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
```

## Points

A point operand is a name, a meet or a free point. The *meet* of two or
more creases, `--l * --m` and `.[--l --m …]`, is the one paper point they
have in common as sets of paper points
([[reference/model#def-meet|def-meet]]). The two spellings are one read,
and the bracket takes any number of operands from 2 up:

```{.bel .frag prelude=diagonals}
mark (map .a onto .b) as --m
.o = .[--ac --bd --m]

; assert .o = (1/2, 1/2)
```

- An operand is a crease, or a paper edge such as `--ab`, which counts
  as its side of the sheet. A line bound by `=` has no material and is no
  operand of a meet (`` --l is a line; the meet needs a crease ``).
- The common point lies on the material of every operand, endpoints
  included. Two creases whose lines cross beyond their material have no
  common point.
- The intersection is taken in paper coordinates, so a fold never
  changes a meet: it moves the point on the table and leaves the creases
  the paper they are. An operand may lie on several paper lines, as a
  crease scored through several layers does, and only the number of
  common points counts. On the preliminary base `--h` and `--v` each lie
  on two paper lines, a scar and its mirror image, and have one point in
  common:

```{.bel .frag prelude=diagonals}
fold (--bd) (moving .a)
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
.o = --h * --v

; assert .o paper = (1/2, 1/2)
```

The meet is an error when the operands have no common point, when they
have 2 or more, and when they share a stretch of paper or lie on one
boundary line; the ambiguous case lists the points in paper coordinates,
and a filter (below) narrows an operand to the piece that crosses at the
one meant ([[reference/beloch-errors#the-meet]]).

## Lines

A line operand is a name, a join, a construction or a filter. A name
bound by `=` is a line, a name bound by `as` is a crease, and a crease
stands where a line is wanted as long as its pieces lie on one table line
([[reference/beloch#parameter-types]]).

The *join* `--[.p .q …]`, and `.p * .q` for two points, is the one
existing crease or paper edge that runs through every listed point. It
selects, as the meet does, and conjures no line: the line through two
points that no crease or edge runs along is a construction,
`(through .p .q)`.

```{.bel .frag prelude=diagonals}
.o = --ac * --bd
mark (perp --[.a .b] through .o) as --v   ; --[.a .b] is the edge --ab
.x = --v * --cd

; assert .x = (1/2, 1)
```

Errors: no crease or edge through all the points
(`` no crease or edge is incident to all of (.p and .q) ``), and several
(`` --[…] is ambiguous: <n> creases/edges match .p ``, hint
`` add a constraint ``). A flap is no constraint of a join
(`` a flap is not a valid --[…] constraint ``, hint `` use & to filter a
crease ``), and a join is a line and no bundle, so no filter applies to
it (`` a --[…] result is a single line, not a segment bundle ``, hint
`` filter a named crease with & instead ``).

## Filters

A crease is a bundle: the paper it scored, in pieces, one straight stretch
per flap ([[reference/model#def-bundle|def-bundle]]). Its pieces lie on one
table line in the state that scored it; a fold across the crease bends
it, and on the crease pattern they point every which way. The filters are
the reads that pick pieces out of a bundle by incidence
([[reference/model#def-filter|def-filter]]):

| form | keeps |
|---|---|
| `--l & .p` | the pieces the point `.p` lies on |
| `--l & --a` | the pieces whose span holds the crossing of `--a` with `--l` |
| `--l & #[.p .q …]` | the pieces that lie on that flap (Flaps, below) |
| `--l \ c` | the pieces `--l & c` drops |
| `[--l --m …]` | every piece of every listed bundle, as one bundle |

Filtering is incidence: `&` keeps the pieces the constraint is *on*. The
side items `toward` and `moving` name a side of a fold line, which is a
different question ([[reference/beloch-constructions#selection]]). A
constraint is a point, a bare crease name or a flap. A chain
`--l & .p & --a` keeps the pieces that satisfy every constraint, which
pins one piece where two pieces share the point `.p`. `&` binds
tighter than the keywords of a construction, so `perp --l & .p through .q`
reads as `perp (--l & .p) through .q`, and a parenthesized operand is that
operand.

Where a slot takes one line, as the axis of a write or a ray of
`flatten`, the result must be one piece: `` no segment of --l & .p
matches `` when none is left, and `` --l & .p is ambiguous: <n> segments
match `` (hint `` add a selector ``) when several are. A name bound to a
bundle stands at no such slot without a filter (`` --u is a bundle, not a
single crease ``, hint `` restrict it with & or \ ``), and a crease a fold
has bent is refused there with the hint to narrow it (`` --l is no longer
straight after folding ``, hint `` narrow it to one piece with &, e.g.
--l & .p ``). Where a slot takes a bundle, as in a meet, the result stands
as it is, and a meet of two pieces reports its two crossings.

Folding the square along one diagonal and scoring a line through both
layers leaves a crease of two pieces at a right angle in the paper, which
share the point where the line crossed the fold:

```{.bel .prelude name=two-layers}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
fold (--bd) (moving .a)
.m = free on --bc from .b at 3/4
mark (perp --bc through .m) as --h     ; through both layers
```

```{.bel .frag prelude=two-layers}
.x = (--h & .m) * --ac         ; the piece through .m, on the base
.y = (--h \ .m) * --ac         ; the other piece, on the folded corner
.j = --h * --bd                ; the point the two pieces share
.z = (--h & .j & --ab) * --ac  ; .j is on both pieces; --ab crosses one
.w = (--h & #[.c]) * --ac      ; the piece on the flap of .c

; assert .x paper = (3/4, 3/4)
; assert .y paper = (1/4, 1/4)
; assert .z paper = (1/4, 1/4)
; assert .w paper = (3/4, 3/4)
```

```{.bel .frag prelude=two-layers}
.j = --h * --bd
.z = (--h & .j) * --ac         ; both pieces hold .j

; expect error "they cross at 2 points"
```

## Flaps

A flap operand names a flap by what lies on it: a point, the flap that
carries it; a line, the flap hinged on it; `#[.p .q …]`, the one flap
whose faces hold every listed point
([[reference/model#def-selector|def-selector]]). It stands at the slots of
type flap, `moving`, `up to`, `on` and the target of `over` and `under`,
and in the filter `--l & #[…]`. The point and the line form, and their
errors, stand with the anchor of a fold (`SPECIFICATION.md` §4.6,
"Anchor"). `#[…]` is an error when its points lie on different flaps
(`` those points aren't all on one flap ``) and when they all lie on a
crease that several flaps share (`` ambiguous flap ``, hint `` add
another point ``); a second point off the crease settles it.

```{.bel .frag prelude=two-layers}
mark (--h) (at .m) (on #[.b .c])     ; the base, which .b and .c lie on

; assert faces = 2
```
