---
title: First folds
description: A first program, one fold at a time, up to the preliminary base. For folders who have never read a grammar and programmers who have never folded a base.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

A Beloch program describes how a sheet of paper is folded. Each line is one
step, and the program's result is the paper after the last one. Beloch
reads the program step by step and computes where every layer of paper
goes, which creases come out mountain or valley, and draws the result. You
describe each fold by what it brings together, and Beloch works out the
lines.

This page builds one program up to the preliminary base. A *base* is a
standard folded shape that many models start from; the preliminary base is
one of the most common, and the crane starts from it. Every figure shows two
drawings of the same moment. On the left is the *crease pattern*: the sheet
unfolded flat again, with every crease the folds have made so far. On the
right is the *folded form*: the paper as it lies on the table, each
*layer* of paper stacked on the one beneath. A crease is either a *valley*,
folded towards you so the paper forms a trough, or a *mountain*, folded
away from you so it forms a ridge. The drawings use the notation of origami
diagrams: a valley is dashed, a mountain dash-dotted, and a crease that was
made and left flat is dotted.

The programs on this page are checked every time the site is built, so what
you read here is what the language does today.

## The sheet

Every program starts by naming its paper.

::: {.figure #fig-guide-sheet caption="The unit square. Its corners are named `.a` to `.d`, counter-clockwise from the bottom left." views="cp" highlight=".a .b .c .d"}
paper square
:::

`paper square` is a square of side 1 with its corners at $(0, 0)$, $(1, 0)$,
$(1, 1)$ and $(0, 1)$. It also names them: `.a` is the bottom left, and the
names continue counter-clockwise to `.d` at the top left.

Names in Beloch carry their kind in front. A name starting with a dot is a
*point*. A name starting with two dashes is a *line* or a *crease*. The
four edges of the square are named after the corners they join: `--ab` is
the bottom edge, `--bc` the right one, `--cd` the top, `--da` the left.

## One fold

Folding the square corner to corner is one line.

::: {.figure #fig-guide-triangle caption="`.a` folded onto `.c`. The crease runs along the other diagonal, from `.b` to `.d`, and the triangle covers the upper right half of where the square was." views="cp folded" highlight=".a .c"}
paper square
fold (map .a onto .c)
:::

A statement starts with a verb, here `fold`, followed by *items* in round
brackets. The item `(map .a onto .c)` says where the fold line goes: it is
the line that carries `.a` onto `.c` when the paper is folded along it. You
never write coordinates for a fold line. You say what it has to bring
together, and Beloch works out the line.

Origami geometry knows seven such ways to pin down a single fold line from
points and lines already on the paper: through two points, one point onto
another, one line onto another, and four more. They are the Huzita-Justin
axioms. Beloch writes each as a *construction* in round brackets, and the
language reference lists all seven under
[Constructions](/language/constructions/).

The fold moves the side that holds `.a`, the first thing the construction
names, and lays it over the rest. A fold without further items is a valley
fold, which is what a folder means by "fold" unless they say otherwise.

## Naming a crease

A statement that makes a crease can give it a name with `as`:

::: {.figure #fig-guide-named caption="The same fold, with its crease named `--bd` after the two corners it runs between." views="cp folded" highlight="--bd"}
paper square
fold (map .a onto .c) as --bd
:::

Later statements can refer to `--bd` the way they refer to a corner. A name
is bound once; binding the same name again is an error, so a name always
means the thing it was first given.

## Marking a line

Folders often crease a line and unfold it again, to have a reference for a
later step. That is `mark`: it scores the paper and moves nothing.

::: {.figure #fig-guide-mark caption="`mark` scores the diagonal from `.a` to `.c`. The paper stays flat, so the folded form is the square itself." views="cp folded" highlight="--ac"}
paper square
mark (through .a .c) as --ac
:::

`(through .a .c)` is another of the seven axioms: the line through two
points. A marked crease is scored into the paper and moves nothing. It
splits the square into two *faces*, the regions of paper that the creases
and edges bound; the crease pattern shows every face of the sheet. Later
statements can fold along the mark, fold something onto it, or read points
off it.

## The kite

With a marked diagonal, the kite base is two more folds. Each lays an edge
of the square along the diagonal.

::: {.figure #fig-guide-kite caption="The kite: the left edge and the bottom edge folded onto the diagonal `--ac`." views="cp folded" highlight="--ac"}
paper square
mark (through .a .c) as --ac
fold (map --da onto --ac)
fold (map --ab onto --ac)
:::

`(map --da onto --ac)` is the axiom that folds one line onto another. Two
lines that cross have two fold lines that do this, the lines that halve the
angles between them. Here one of them runs across the paper, and the other
touches the square only at the corner `.a`. A line that creases no paper is
no fold at all, so one candidate is left, and that is the fold.

## Choosing the side that moves

Not every construction says which side of the fold line travels. A fold
line through two points is symmetric; nothing in `(through .a .c)` says
whether the half with `.b` or the half with `.d` goes over. Beloch does not
guess. This program fails:

```{.bel}
paper square
fold (through .a .c)

; expect error "this fold needs `moving .p` to choose the side"
```

The error points at the statement and says what is missing. A `moving` item
names a point on the side that travels:

::: {.figure #fig-guide-moving caption="`(moving .b)` sends the half with `.b` over the diagonal." views="cp folded" highlight=".b"}
paper square
fold (through .a .c) (moving .b)
:::

The opposite item is `toward`: it names a point on the side that stays.
`fold (through .a .c) (toward .d)` is the same fold. When a construction
has several solutions that all crease paper, the same two items choose among
them, and the reference explains how under
[Selection](/language/constructions/#selection).

A crease that is already there can be the fold line itself. The crease goes
in round brackets like a construction, and it needs a side for the same
reason:

::: {.figure #fig-guide-along caption="The marked diagonal `--ac` folded, with the half holding `.b` moving." views="cp folded" highlight="--ac .b" after="fig-guide-mark"}
fold (--ac) (moving .b)
:::

Every error works this way. A program that asks for something the paper
cannot do, or that leaves a choice open, stops at the statement where that
happens, with a message and often a hint.

## Which layers move

Once the paper is folded, a fold line crosses more than one layer. A fold
takes every layer under its line on the side that folds over, as a finger
pressing a crease through the stack does. The point that says which side
moves, the named corner of a `map` or the point of a `moving` item, names
that side and nothing more.

The book fold shows it. Folding the left edge onto the right edge puts the
left half on top, so `.a` is on the top layer and `.b` on the bottom one.
Folding the bottom onto the top takes both layers, whichever of the two
corners the program names:

::: {.figure #fig-guide-book caption="The book fold, then the bottom onto the top. Both layers move." views="cp folded" highlight=".a .b"}
paper square
fold (map --da onto --bc)
fold (map .b onto .c)
:::

`(map --da onto --bc)` folds one edge onto the opposite one. The two edges
are parallel, so there is one fold line, halfway between them. The same
second fold written as `fold (map .a onto .d)` gives the same state.

To fold fewer layers, `(up to …)` names the deepest one the fold takes. That
layer moves with every layer on top of it, or beneath it for a mountain
fold. A layer joined to those by a crease away from the fold line goes
along too, because the paper would have to tear to leave it behind. Here
the corner of the top layer folds alone:

::: {.figure #fig-guide-up-to caption="The sheet folded in half, then the corner of the top layer. `(up to .b)` names the top layer as the deepest the fold takes." views="cp folded" highlight=".b"}
paper square
fold (map .b onto .a)
.p = free on --bc from .b at 1/4
.q = free on --ab from .b at 1/4
fold (through .p .q) (moving .b) (up to .b)
:::

A `mark` works the same way: it scores every layer its line crosses, and
`(on …)` confines it to one.

The piece of paper that moves as a whole is a *flap*: faces joined by
creases that are not folded, so that they lie flat against each other.

## A reverse fold

The preliminary base starts from the triangle and needs a fold that is not
a plain valley or mountain: the *inside reverse fold*. The triangle's
corner `.b` is folded down between the two layers of the triangle, so that
it ends up inside. Along the old crease `--bd` the direction of the fold
flips where the corner turns in.

::: {.figure #fig-guide-reverse caption="The corner `.b` reverse-folded inside, onto `.c`." views="cp folded" highlight="--h" after="fig-guide-named"}
reverse (map .b onto .c) as --h
:::

This figure continues the program of the named triangle above; from here on
a figure shows only the lines it adds. `reverse` takes a construction the
way `fold` does. It needs no `moving`, because `(map .b onto .c)` already
says that `.b` travels. `(outside)` would wrap the corner
around the outside of the layers instead of tucking it between them.

## The preliminary base

One more reverse fold for the corner `.d` finishes the base.

::: {.figure #fig-guide-prelim caption="The preliminary base. The paper is a square a quarter the size of the sheet, all four corners lie together at `.c`, and the creases `--h` and `--v` cross at the paper's centre." views="cp folded" highlight="--v" after="fig-guide-reverse"}
reverse (map .d onto .c) as --v
:::

The whole program is four lines:

```{.bel}
paper square
fold (map .a onto .c) as --bd
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
```

`--h` is named for the horizontal line it was folded along, halfway up the
triangle, and `--v` for the vertical one.

## Collapsing a vertex

Folders often reach the preliminary base another way: crease the diagonals
and the middle lines first, then push the paper together so that all the
creases around the centre fold at once. `flatten` does that. It folds every
crease through one point, the *vertex*, in a single step.

::: {.figure #fig-guide-flatten caption="The preliminary base in one `flatten`. Six rays around the centre fold; the diagonal from `.a` to `.c` stays flat. `(.q over .r)` puts the quarter with `.q` in front of the one with `.r`." views="cp folded" highlight=".q .r"}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
.q = free on --ab from .a at 1/4
.r = free on --ab from .b at 1/4
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab)
  (--bd & .b) (--bd & .d) (.q over .r) (toward .q)
:::

The four `mark` lines score the creases. The items of `flatten` then name
the *rays*, the pieces of crease that run out from the vertex. Each marked
line through the centre is two rays, and `&` picks one of them:
`--h & --bc` is the piece of `--h` that reaches the right edge `--bc`.

The rays say where the paper folds; Beloch works out which of them become
mountains and which valleys, and how the layers stack, so that everything
lies flat. A ray can be pinned by writing its letter, as in
`(--h & --bc mountain)`. With an odd number of rays, Beloch adds the one
that is missing, since a flat vertex needs an even number.

Several flat results can remain, and the other items choose among them.
`(.q over .r)` says that the paper around `.q` lies over the paper around
`.r`, and `(toward .q)` picks one of the results that are still left. Both
need points that lie in one quarter of the sheet and on none of the
creases through the centre. The corners and crossings named so far all lie
on such a crease. `free on --ab from .a at 1/4`
is a point a quarter of the way along the bottom edge from `.a`; `free`
records that any spot on that stretch would do, and the program uses this
one.

`flatten` handles one vertex per statement. The reference describes the
rest under [Write statements](/language/writes/).

## Points from creases

A point does not have to be a corner. `*` gives the point where two creases
cross on the paper:

::: {.figure #fig-guide-centre caption="`.o`, the point where `--h` and `--v` cross: the centre of the sheet, and the closed tip of the base." views="cp folded" highlight=".o" after="fig-guide-prelim"}
.o = --h * --v
:::

`=` binds a name to something computed from the paper as it is, and changes
nothing. That is the difference between the two ways to name: `as` names
the crease a statement makes, `=` names a value the program reads off the
paper. `--mid = (through .c .o)` binds a line with no crease under it yet,
which a later fold can use as its fold line or its target.

A point name belongs to the paper. `.o` is a spot on the sheet, and it
travels with the paper wherever later folds take it. A construction such as
`(map .b onto .c)` works with where its points lie on the table at that
step, since that is where the fold happens. A crossing `*` is found on the
unfolded sheet, where the creases are scored.

On the unfolded sheet, one crease can be several lines. `--h` was folded
through both layers of the triangle at once and left a *scar* in each.
Unfolded, the scar in the upper layer runs from the centre to the right
edge, and the scar in the lower layer, which lay folded over the diagonal,
runs from the centre down to the bottom edge. A crease is all of its scars
together, and `*` looks for a crossing among all of them. The crease pattern
of the preliminary base shows this: `--h` and `--v` each bend at the
centre.

## Where to go from here

[Reading the crane](/guide/reading-the-crane/) continues this program into a
traditional crane and introduces the rest of what it needs along the way.
The [playground](/playground/) runs any program in the browser. The
[language reference](/language/) defines every statement this page used.
