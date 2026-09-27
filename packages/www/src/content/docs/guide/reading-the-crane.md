---
title: Reading the crane
description: The traditional crane as a Beloch program, read section by section. Introduces perpendiculars, moving flaps, mountain folds, filters and free points where the crane first needs them.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

This page reads a whole model: the traditional crane, folded flat, by the
sequence Ida gives in her book [@ida2020, Fig. 7.19]. It reaches the bird
base with reverse folds and uses no petal fold, so it differs from the
diagrams most folders learnt the crane from, and ends in the same bird base.
It assumes
[First folds](/guide/first-folds/), and it adds the rest of what the crane
needs where it first appears. The full program is
[`examples/crane.bel`](https://github.com/tophcodes/beloch/blob/main/examples/crane.bel)
in the repository; the figures below build it up section by section, and
each shows only the lines it adds.

Beloch describes paper that lies flat. The crane ends where its last flat
step ends, with the wings still closed; spreading them makes the model
three-dimensional, which the language does not model.

## The base and its centre line

The program starts where the first page ended: the preliminary base, with
the centre of the paper named `.o`.

::: {.figure #fig-crane-base caption="The preliminary base. `--mid` runs from the loose corners at `.c` to the closed tip `.o`." views="cp folded" highlight=".o --mid"}
paper square
fold (map .a onto .c) as --bd
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
.o = --h * --v
--mid = (through .c .o)
:::

On the table the base is a small square. The four corners of the sheet lie
together at one of its corners, `.c`, the *loose corners*. The centre of the
sheet is the opposite corner, `.o`, the *closed tip*, where no paper edge
reaches. `--mid` is the line between them, the *centre line* of the base.
It is bound with `=`, so it has no crease under it. The next folds bring
paper onto it, and a line you only fold onto never needs to be scored.

## The side corners

The two remaining corners of the base square are its *side corners*. Each
is two layers thick, one on the front of the base and one on the back, so
there are four: `.sr` and `.sl` on the front, right and left, `.br` and
`.bl` on the back. Each is reverse-folded inside, so that its edge lies
along the centre line.

::: {.figure #fig-crane-sides caption="The four side corners reversed onto the centre line. Each crease runs from the loose corners at `.c`." views="cp folded" highlight="--mid" after="fig-crane-base"}
.sr = --ab * --h
reverse (map .sr onto --mid through .c) as --rsr
.sl = --da * --v
reverse (map .sl onto --mid through .c) as --rsl
.br = --bc * --h
reverse (map .br onto --mid through .c) as --rbr
.bl = --cd * --v
reverse (map .bl onto --mid through .c) as --rbl
:::

`.sr = --ab * --h` finds a side corner as a crossing on the unfolded sheet.
[First folds](/guide/first-folds/#points-from-creases) showed that `--h`
left two scars, one of them running from the centre down to the bottom
edge. That scar meets the bottom edge `--ab` at $(1/2, 0)$, the middle of
the bottom edge, and on the base this spot is the right side corner of the
front layer. `.sl`, `.br` and `.bl` are the other three the same way, each
where an edge of the sheet meets a scar of `--h` or `--v`.

`(map .sr onto --mid through .c)` is the axiom that folds a point onto a
line with a fold line through a second point. It has up to two solutions.
Here only one of them crosses the folded paper, so the program needs no
item to choose.

## The bird base

The front flap and the back flap are folded over along the same line,
square to the centre line through the side corners. That leaves the two long
points, the future neck and tail, standing up in the middle: the bird base.

::: {.figure #fig-crane-bird caption="The bird base. `--pf` folds the front flap, `--pb` the back flap along the same line." views="cp folded" highlight="--pf --pb" after="fig-crane-sides"}
fold (perp --mid through .sr) (moving .a) as --pf
fold (perp --mid through .sr) (moving .c) (mountain) as --pb
:::

`(perp --mid through .sr)` is the axiom for the line through a point,
square to another line.

The two folds follow the rule of
[Which layers move](/guide/first-folds/#which-layers-move). `(moving .a)`
anchors the first on the front flap, and a valley fold takes that flap and
the layers on top of it, which is the front alone. The second is anchored
on `.c`, which lies on the back, and `(mountain)` makes it fold away from
the viewer, taking the back flap and the layers beneath it. Seen from the
front, its crease is a ridge.

The two long points left standing are the *legs* of the bird base. Their
tips are the corners `.b` and `.d`.

## Narrowing the legs

Each of the two long points gets narrower by folding its outer edges onto
the centre line, on the front and on the back. That is four folds, and each
has to move exactly one layer.

::: {.figure #fig-crane-legs caption="The legs narrowed. The front edges fold as valleys (`--n1`, `--n2`), the back edges as mountains." views="cp folded" highlight="--n1 --n2" after="fig-crane-bird"}
.e1 = (--rsr & .b) * --pf
fold (map --rsr & .b onto --mid) (moving .e1) as --n1
.e2 = (--rsl & .d) * --pf
fold (map --rsl & .d onto --mid) (moving .e2) as --n2
.e3 = (--rbr & .b) * --pb
fold (map --rbr & .b onto --mid) (moving .e3) (mountain) as --n3
.e4 = (--rbl & .d) * --pb
fold (map --rbl & .d onto --mid) (moving .e4) (mountain) as --n4
:::

`&` does the work here, as it picked the rays of the collapse on the first
page: it narrows a crease to one of its pieces. Once a crease has been
folded over, its scars point in different directions, and "the line of
`--rsr`" no longer names one line.
`--rsr & .b` is the piece of `--rsr` that touches `.b`: the outer edge of
the leg that ends in `.b`. That piece is straight, so it can be folded onto
`--mid`.

Each fold is anchored with `moving` on a point bound on the line before it,
`.e1` to `.e4`: the point where that edge meets the crease of the flap it
lies on. `.e1` lies on the front layer, so the valley fold takes the front
layer and nothing beneath it. Anchored on the edge instead, the fold would
take the back layers too, because the edge runs through them as well. The
two back folds are anchored on the back layer and fold as mountains.

## Neck and tail

Each narrowed leg is inside reverse-folded, so that it turns up between the
layers of the body: one becomes the neck, the other the tail.

::: {.figure #fig-crane-neck caption="The neck and the tail, each reversed about a line square to its narrowed edge." views="cp folded" highlight="--neck --tail" after="fig-crane-legs"}
reverse (perp --n1 through .sr) (moving .b) as --neck
reverse (perp --n2 through .sr) (moving .d) as --tail
:::

A perpendicular moves nothing by itself, so unlike a `map`, it does not say
which side goes, and the reverse fold needs `(moving .b)`: the tip of the
leg that becomes the neck.

## The head

The last fold bends the tip of the neck into a head. Where exactly it bends
is a choice the folder makes by eye, and the program says so.

::: {.figure #fig-crane-head caption="The finished crane. `.hp` is where the head bends, `.ht` sets its angle." views="cp folded" highlight=".hp .ht --head" after="fig-crane-neck"}
.hp = free on --bd & .b from .b at 1/4
.ht = free on --rsl & .a from .a at 1/2
reverse (through .hp .ht) (moving .b) as --head
:::

`free on --bd & .b from .b at 1/4` names a spot a quarter of the way along
the piece of `--bd` that touches `.b`, counted from `.b`, measured on the
paper. As in the collapse on the first page, `free` records that the
position was a choice and follows from no construction; the program folds
with the point like with any other. Two such points pin down the line of
the head fold.

## References
