---
title: Reading the crane
description: The traditional crane as a Beloch program, read section by section. Introduces fans, joins, mountain folds, perpendiculars, letters on a reverse fold, filters and free points where the crane first needs them.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

This page reads a whole model: the traditional crane, folded flat. It
reaches the bird base the way most folders learned it, by two petal folds,
and then places the neck, the tail and the head where Ida's crane program
places them [@ida2020, Fig. 7.19]. It assumes
[[guide/first-folds]], and it adds the rest of what the crane
needs where it first appears. The full program is
[`examples/crane.bel`](https://github.com/tophcodes/beloch/blob/main/examples/crane.bel)
in the repository; the figures below build it up section by section, and
each shows only the lines it adds.

Beloch describes paper that lies flat. The crane ends where its last flat
step ends, with the wings still closed; spreading them makes the model
three-dimensional, which the language does not model.

## The base and its center line

The program starts where the first page ended: the preliminary base, with
the center of the paper named `.o`.

::: {.figure #fig-crane-base caption="The preliminary base. `--mid` runs from the loose corners at `.c` to the closed tip `.o`." views="cp folded" highlight=".o --mid"}
paper square
fold (map .a onto .c) as --bd
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
.o = --h * --v
--mid = (through .c .o)
:::

On the table the base is a small square. The four corners of the sheet lie
together at one of its corners, `.c`, the *loose corners*. The center of the
sheet is the opposite corner, `.o`, the *closed tip*, where no paper edge
reaches. `--mid` is the line between them, the *center line* of the base.
It is bound with `=`, so it has no crease under it. The next folds bring
paper onto it, and a line you only fold onto never needs to be scored.

## The side corners

The two remaining corners of the base square are its *side corners*. Each
is two layers thick, one on the front of the base and one on the back, so
there are four: `.sr` and `.sl` on the front, right and left, `.br` and
`.bl` on the back.

::: {.figure #fig-crane-sides caption="The four side corners. On the sheet each is the middle of an edge." views="cp folded" highlight=".sr .sl .br .bl" after="fig-crane-base"}
.sr = --ab * --h
.sl = --da * --v
.br = --bc * --h
.bl = --cd * --v
:::

`.sr = --ab * --h` finds a side corner as a crossing on the unfolded sheet.
[[guide/first-folds#points-from-creases|First folds]] showed that `--h`
left two scars, one of them running from the center down to the bottom
edge. That scar meets the bottom edge `--ab` at $(1/2, 0)$, the middle of
the bottom edge, and on the base this spot is the right side corner of the
front layer. `.sl`, `.br` and `.bl` are the other three the same way, each
where an edge of the sheet meets a scar of `--h` or `--v`.

## The bird base

A *petal fold* lifts the loose corner of the front flap up past the closed
tip, and the two side corners swing in to the center line as it rises. Lang
describes it as two squash folds made side by side
[@lang2011secrets, ch. 2, Fig. 2.31]. One petal fold on the front and one on
the back make the bird base.

The paper turns about two points at once in this move, one on each side
edge of the flap. Two reverse folds and a valley fold reach the same state
in three flat steps [@lang2011secrets, ch. 2, Fig. 2.34]. The program
writes the petal fold as the one move it is: one `flatten` that folds both
points together.

::: {.figure #fig-crane-bird caption="The bird base. `--pf` is the crease the front flap is lifted on, `--pb` the one on the back." views="cp folded" highlight="--pf --pb .e1 .e2" after="fig-crane-sides"}
flatten (fan (--h & .sr) (map .sr onto --mid through .a) as .e1)
        (fan (--v & .sl) (map .sl onto --mid through .a) as .e2)
        (on #[.a]) (staying .o) as --pf
flatten (fan (--h & .br) (map .br onto --mid through .c) as .e3)
        (fan (--v & .bl) (map .bl onto --mid through .c) as .e4)
        (on #[.c]) (staying .o) as --pb
:::

On the first page `flatten` took the rays of one vertex. Here each
`(fan …)` item holds the rays of one vertex, and the statement folds its
two fans in one move.

The first fan has two rays. `--h & .sr` is the half of the folded side edge
that runs out to the side corner `.sr`; in the petal fold it opens.
`(map .sr onto --mid through .a)` is the axiom that folds a point onto a
line with a fold line through a second point: it is the crease that brings
the side corner onto the center line, and it runs from the loose corners.
The two rays meet at one point of the side edge, and `as .e1` gives that
point a name. The second fan does the same on the left and names `.e2`.

A third crease runs from `.e1` to `.e2`: the one the flap is lifted on.
Neither fan names it. Beloch works it out, since both vertices have to
fold flat, and the `as --pf` at the end of the statement names it.

`(on #[.a])` says which flap the move folds. `#[.a]` is the flap that holds
the corner `.a`, the front flap; the second statement names the back flap
by `.c`. `(staying .o)` names paper that keeps its place, here the closed
tip.

The two long points left standing are the *legs* of the bird base. Their
tips are the corners `.b` and `.d`.

## Narrowing the legs

Each of the two long points gets narrower by folding its outer edges onto
the center line, on the front and on the back. That is four folds, and each
has to move exactly one layer.

::: {.figure #fig-crane-legs caption="The legs narrowed. The front edges fold as valleys (`--n1`, `--n2`), the back edges as mountains. `.ht` waits for the head." views="cp folded" highlight="--n1 --n2 .ht" after="fig-crane-bird"}
.ht = free on --[.e2 .a] from .a at 1/3
fold (map --[.e1 .b] onto --mid) (moving .e1) (up to #[.e1 .b .o]) as --n1
fold (map --[.e2 .d] onto --mid) (moving .e2) (up to #[.e2 .d .o]) as --n2
fold (map --[.e3 .b] onto --mid) (moving .e3) (up to #[.e3 .b .o]) (mountain) as --n3
fold (map --[.e4 .d] onto --mid) (moving .e4) (up to #[.e4 .d .o]) (mountain) as --n4
:::

The petal folds left their creases without names, and a *join* reads them
back. `--[.e1 .b]` is the one crease that runs through every point it
lists: here the crease from the fan's point `.e1` to the tip `.b`, the
outer edge of the leg that ends in `.b`. `(map --[.e1 .b] onto --mid)`
folds that edge onto the center line.

Each fold names its side with `(moving .e1)`, a point on the edge it folds
over. Its `up to` follows the rule of
[[guide/first-folds#which-layers-move]]: `#[.e1 .b .o]` is the layer of the
leg that holds the fan's point, the leg's tip and the paper center, so the
valley fold takes the front layer and nothing beneath it. Without `up to`
the fold would take the back layers too, because the edge runs through
them as well. The two back folds name the back layer, and `(mountain)`
makes them fold away from the viewer, taking that layer and the layers
beneath it. Seen from the front, their creases are ridges.

The first line of the figure belongs to the head. `--[.e2 .a]` is the edge
of the front petal from `.e2` to the corner `.a`, and `.ht` is a point a
third of the way along it from `.a`. The narrowing folds cut that edge into
pieces, so the program reads the point while the edge is whole.

## Neck and tail

Each narrowed leg is inside reverse-folded, so that it turns up between the
layers of the body: one becomes the neck, the other the tail.

::: {.figure #fig-crane-neck caption="The neck and the tail, each reversed about a line square to its narrowed edge." views="cp folded" highlight="--neck --tail" after="fig-crane-legs"}
.pn = free on --n1 & #[.sr .b] from .b at 1/4
.qn = free on --n3 & #[.br .b] from .b at 1/4
reverse (perp --n1 through .sr) (moving .b)
  (--n1 & .pn mountain) (--n3 & .qn mountain) as --neck
.pt = free on --n2 & #[.sl .d] from .d at 1/4
.qt = free on --n4 & #[.bl .d] from .d at 1/4
reverse (perp --n2 through .sr) (moving .d)
  (--n2 & .pt mountain) (--n4 & .qt mountain) as --tail
:::

`(perp --n1 through .sr)` is the axiom for the line through a point, square
to another line. A perpendicular moves nothing by itself, so unlike a
`map`, it does not say which side goes, and the reverse fold needs
`(moving .b)`: the tip of the leg that becomes the neck.

A narrowed leg is eight layers thick, and a reverse fold has to open it
somewhere. This leg opens at three places: in the middle, with four layers
on each side, which is where a folder opens it, between its top two layers
and the six beneath them, and between its bottom two layers and the six
above them. Without further items the statement stops with
`the tip opens at 3 places`.

Two letter items choose. `--n1` has more than one piece by now;
`--n1 & #[.sr .b]` is the piece
on the flap that holds `.sr` and `.b`, and `.pn` is a point on that piece.
Each opening leaves the piece with a letter, and
`(--n1 & .pn mountain)` keeps the openings that make it a mountain. Two of
the three do, so `(--n3 & .qn mountain)` says the same of the narrowing
crease on the back of the leg, and the opening in the middle is left. The
tail is chosen the same way.

## The head

The last fold bends the tip of the neck into a head. Where exactly it bends
is a choice the folder makes by eye, and the program says so.

::: {.figure #fig-crane-head caption="The finished crane. `.hp` is where the head bends, `.ht` sets its angle." views="cp folded" highlight=".hp .ht --head" after="fig-crane-neck"}
.hp = free on --bd & .b from .b at 1/4
reverse (through .hp .ht) (moving .b) as --head
:::

`free on --bd & .b from .b at 1/4` names a spot a quarter of the way along
the piece of `--bd` that touches `.b`, counted from `.b`, measured on the
paper. As in the collapse on the first page, `free` records that the
position was a choice and follows from no construction; the program folds
with the point like with any other. Two such points pin down the line of
the head fold: `.hp` here, and `.ht` from the section on the legs.

## References
