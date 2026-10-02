---
title: Write statements
description: The verbs that change the state, the items each verb takes, and what becomes of the crease a write scores, with a worked program per verb.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

A write statement is a verb followed by its *items*. An item is a
parenthesized block whose first token names its type; items may stand in
any order. The construction that supplies the axis is an item like the
others, so every slot of a write's signature is one block in the source,
delimited on both sides and classified by its head.

`flip` takes no item. Round parentheses are items and braces are blocks
(`def`, `on`, `export`); no item uses braces. The side items name the side
of the axis that stays, `toward`, and the side that folds over, `moving`,
and select among the candidates of a construction by them
([Selection](/language/constructions/#selection)). The `toward` item of `flatten` selects among
states rather than among lines
([open-flatten-selection](/model/#open-flatten-selection)). The `on` item of
`flatten` names its anchor, the flap anywhere in the stack under the vertex
whose tip the fan moves; without it the anchor is the topmost flap there
([def-flatten](/model/#def-flatten)). The other layers under the vertex stay
where they lie and need no rays. `on` names a flap by incidence for both
writes: the flap a `mark` scores, and the flap a `flatten` folds.

Six blocks follow, one group per verb, each a complete program that this page
evaluates. `fold` and `reverse` take two blocks each, because the second form
of either needs a sheet of its own, and the last block carries `flatten` with
`flip`.

```{.bel .prelude name=sheet}
paper square
mark (map --da onto --bc) as --d
.m = free on --bc from .b at 1/2
.n = free on --ab from .b at 1/2
.p = free on --ab from .a at 1/4
```

```{.bel .frag prelude=sheet}
fold    (--d) (moving .b) (up to .c)               ; along an existing crease
fold    (map .a onto .d) (moving .a)
fold    (through .m .n) (moving .b) (up to .b) (under .p)
fold    (map .a onto .b) (moving .a) (mountain)

; assert steps = 4
; assert faces = 8
```

```{.bel .frag}
fold    (map .c onto .b) (up to .d)                ; the depth needs no moving

; assert steps = 1
; assert faces = 2
```

`moving` names the side that folds over and nothing more: a `fold` takes
every layer under its line on that side, and so does a placed fold.
`(up to …)` narrows it to the flap it names, the layers outward of that
flap, and every layer joined to those by a crease away from the fold line,
which the paper could not leave behind without tearing
([def-fold](/model/#def-fold)). A `mark` without `on` scores every layer
under its line or its extent, one piece per layer; `(on …)` confines it to
one flap ([def-mark](/model/#def-mark)).

```{.bel .prelude name=triangle}
paper square
fold (map .a onto .c) as --bd
```

```{.bel .frag prelude=triangle}
reverse (map .b onto .c)
reverse (map .d onto .c)

; assert .b = .c
; assert .d = .c
; assert faces = 6
```

```{.bel .prelude name=half}
paper square
fold (map .b onto .a) as --d
```

```{.bel .frag prelude=half}
reverse (map .a onto .d) (outside)

; assert .a = .d
; assert faces = 4
```

```{.bel .prelude name=midline}
paper square
mark (through .a .c) as --ac
.m = free on --da from .a at 1/2
.o = free on --ac from .a at 1/2
```

```{.bel .frag prelude=midline}
mark    (through .b .d)
mark    (map --ab onto --cd) (between .m .o) (mountain)

; assert faces = 1
```

```{.bel .prelude name=prelim}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
.q = free on --ab from .a at 1/4
.r = free on --ab from .b at 1/4
```

```{.bel .frag prelude=prelim}
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b) (--bd & .d)
        (.q over .r) (staying .a) (toward .q)
flip

; assert steps = 2
; assert faces = 6
```

A tip of several layers can open in more than one place
([def-reverse](/model/#def-reverse)). The reverse then fails, and its error
offers one letter item per opening: a letter on a hinge of the spine, named
by its crease and a point on it the way a ray of `flatten` is. On a square
folded in half twice, `(--e & .q valley)` keeps the opening between the two
inner layers, and `(--e & .q mountain)` the one below the outermost layer.

```{.bel .prelude name=square-twice}
paper square
fold (map .b onto .a) as --d
fold (map --d onto --da) as --e
.q = free on --cd from .c at 1/4
```

```{.bel .frag prelude=square-twice}
reverse (map .a onto .d)

; expect error "the tip opens at 2 places"
```

```{.bel .frag prelude=square-twice}
reverse (map .a onto .d) (--e & .q valley)

; assert .a = .d
; assert faces = 8
```

The crease a write scores is its one output, and the clause after the
items says what becomes of it, for every verb:

- `as --f` binds it to a new name: `fold (map .a onto .c) (moving .a) as
  --f`, `flatten (--ba \ .a) … as --r`. A name already bound is an error;
  `as --f!` rebinds it, with the `!` of `SPECIFICATION.md` §5a.6.
- `into --l` adds it to the crease `--l`: `mark (--l) into --l` draws the
  full line through a reference mark, `fold (--d) (moving .b) (up to .c)
  into --d` folds some layers of a crease marked through all of them and
  keeps one name for the material. The new material must lie on the table
  line of a segment of `--l`; material on another line is a crease of its
  own, and `[--l --m]` is the read that unites two.
- no clause: an anonymous crease, addressable by incidence only.

`=` binds the value of a read and nothing else, so the sort of a name is
visible at its binding: `--l = (map .a onto .c)` is a line with no
material, `fold (map .a onto .c) as --l` is a crease. A value bound by `=`
is a snapshot and takes no `into`; a new value is a new binding.

A head that does not belong to the verb is an error naming the verb and
the item; an item type given twice is an error at the second occurrence.
`mountain` is a value of the placement type, so `(mountain)` beside `(over
…)` puts two values in one slot; the placement item has already fixed the
direction, and the error says so: `a placed fold derives its direction`,
with the hint `drop mountain`.

```{.bel .frag}
fold (map .a onto .c) (moving .a) (over .b) (mountain)

; expect error "a placed fold derives its direction"
```

Marking every argument as a block is what the model's operation signatures
ask for: one item per parameter, the same shape for every write. For the
tools it means that an item is one node of the syntax tree with a type of
its own, so that highlighting colours an anchor, a placement and a
construction differently, and a malformed item is contained by its
parentheses instead of swallowing the rest of the statement.

::: {.figure #fig-lang-fold caption="The first `fold` carries a single item, the construction `(map .b onto .a)`, and reads its anchor from the corner that alignment moves. The second carries two: `(through .p .q)` is the line the paper turns about, `(moving .b)` the side that folds over, whose layers all travel. With no placement item the block lands on top of the paper it was folded from, and `as --f` gives the crease a name later statements can select." views="cp folded" highlight="--f"}
paper square
fold (map .b onto .a)
.p = free on --bc from .b at 1/4
.q = free on --ab from .b at 1/4
fold (through .p .q) (moving .b) as --f
:::

::: {.figure #fig-lang-reverse caption="Two reverse folds turn the triangle into the preliminary base. `reverse` reads its axis from a construction the way `fold` does, and the anchor is implied by the tip the axis cuts off, so neither write needs a `(moving …)` item." views="cp folded" highlight="--h --v"}
paper square
fold (map .a onto .c) as --bd
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
:::

::: {.figure #fig-lang-mark caption="`mark` scores paper without moving it. `(between .m .o)` cuts the score back to the stretch between two points, `(on #[.c])` names the flap it runs on, and `(mountain)` records the intent the crease pattern draws." views="cp" highlight="--h --ac"}
paper square
mark (through .a .c) as --ac
.m = free on --da from .a at 1/2
.o = free on --ac from .a at 1/2
mark (map --ab onto --cd) (on #[.c]) (between .m .o) (mountain) as --h
:::

::: {.figure #fig-lang-flatten caption="One `flatten` collapses six of the eight rays at the paper centre into the preliminary base, and the diagonal through `.a` and `.c` stays flat. Each ray item picks a piece of a marked crease with `&`, `(.q over .r)` fixes which quarter comes to the front, and `(toward .q)` chooses one of the flat states the rays allow." views="cp folded" highlight=".a .c"}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
.q = free on --ab from .a at 1/4
.r = free on --ab from .b at 1/4
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b) (--bd & .d) (.q over .r) (toward .q)
:::

::: {.figure #fig-lang-flip caption="`flip` takes no item at all. It turns the sheet over, so the fold that follows is placed on what was the back, and `--g` comes out mountain where the same fold on an unflipped sheet would read valley." views="cp folded" highlight="--g"}
paper square
flip
fold (map .a onto .c) as --g
:::
