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
([[reference/beloch-constructions#selection]]). The `toward` item of `flatten` selects among
states rather than among lines
([[reference/model#open-flatten-selection|open-flatten-selection]]). The `on` item of
`flatten` names its anchor, the flap anywhere in the stack under the vertex
whose tip the fan moves; without it the anchor is the topmost flap there
([[reference/model#def-flatten|def-flatten]]). The other layers under the vertex stay
where they lie and need no rays. `on` names a flap by incidence for both
writes: the flap a `mark` scores, and the flap a `flatten` folds.

A head that does not belong to the verb is an error naming the verb and
the item (`` fold takes no (between) item ``), and an item type given
twice is an error at the second occurrence (`` only one moving item per
fold ``). Each section below states one verb, with complete programs that
this page evaluates; a prelude block is a sheet that several of them start
from.

```{.bel .frag}
fold (map .a onto .c) (moving .a) (moving .c)

; expect error "only one moving item per fold"
```

## `mark`

`mark` scores its line and moves nothing. The crease reads `F` in the
output, and a `(mountain)` or `(valley)` item records the intent the crease
pattern draws, which is no part of the state
([[reference/model#def-mark|def-mark]], [[reference/fold]]). Without `on`, a
`mark` scores every layer under its line or its extent, one piece per
layer; `(on …)` confines it to one flap ([[decision/0036]], [[decision/0039]]).

**Extent.** The extent of a mark is its whole line, the stretch
`(between .p .q)` or the point `(at .p)`; each point lies on the mark's
line (`` .p is not on the mark's line ``), and `between` takes two points
apart (`` the mark's extent needs two distinct points ``). An extent that
runs from boundary to boundary of its flap subdivides the flap; one that
ends inside a face subdivides nothing and dangles there as a record, which
later reads select and later folds carry like any material
([[decision/0033]]). A record is written to `beloch:marks` in the output,
and the crease pattern draws it apart from the creases
([[reference/fold]]). The extent lies on the paper
(`` the mark's extent is not on the paper ``), and with `on` it stays on
the named flap: an extent that would cross a folded crease to reach its
endpoint is an error (`` the mark's extent from .p to .q crosses a folded
crease (it leaves its flap) ``). A point of the extent that lies on a
crease several flaps share needs `on` with a second point to settle the
flap (`` .m lies on a crease shared by 2 flaps ``, hint `` name the flap
with #[...] ``).

A line bound by `=` has no material until a `mark` scores it, and the meet
reads material only ([[reference/beloch-operands#points]]): a line that
serves to locate a point is marked, with `(at …)` where it is to subdivide
nothing, and a line that only feeds a construction stays a value.

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

```{.bel .prelude name=triangle}
paper square
fold (map .a onto .c) as --bd
```

```{.bel .frag prelude=triangle}
.r = free on --bc from .b at 1/2
.m = free on --bd from .b at 1/2             ; on the hinge, under both layers
mark (perp --bc through .r) (at .r) (on .m)

; expect error "lies on a crease shared by 2 flaps"
```

```{.bel .frag prelude=triangle}
.r = free on --bc from .b at 1/2
.m = free on --bd from .b at 1/2
mark (perp --bc through .r) (at .r) (on #[.m .c])   ; the layer that holds .c

; assert faces = 2
```

## `fold`

A `fold` has four parts ([[reference/model#def-fold|def-fold]]):

| part | item | what it is |
|---|---|---|
| axis | a construction, or a crease | the line the paper turns about |
| side | `moving`, `toward`, or derived | the side of the axis that folds over |
| depth | `up to` | the deepest flap that moves; without it, every layer on the side |
| placement | `mountain`, `over`, `under` | where the moved block lands: on top, underneath, or beside a flap |

**Side.** `moving` takes a flap operand and names the side of the axis
its image lies on, nothing more ([[reference/beloch-operands#flaps]]).
`(map .p onto .q)` and `(map .p onto --l …)` derive the side from the
point they move, and `(map --l onto --m)` from the material of `--l` that
swings ([[reference/beloch-constructions#axiom-5-a-line-onto-a-line]]); a
written `moving` overrides the derived side. A fold along
`(through …)`, along `(perp …)` or along an existing crease derives none
and needs `moving` or `toward` (`` this fold needs `moving .p` to choose
the side ``). A point on the axis names no side (`` moving .p names no
side of the fold line of <construction> ``), and a flap that straddles the
axis names none without a point.

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

**Depth.** `moving` names the side that folds over and nothing more: a
`fold` takes every layer under its line on that side, and so does a
placed fold. `(up to …)` narrows it to the flap it names, the layers
outward of that flap, and every layer joined to those by a crease away
from the fold line, which the paper could not leave behind without tearing
([[reference/model#def-fold|def-fold]]). For a fold placed `over` or `under` a flap,
the layers outward of the `up to` flap end at that flap: the fold takes
every layer between the two, hinged to the `up to` flap or not, and the
target and the layers beyond it stay. The depth is a flap, so its point
settles one flap: a point on a crease that several flaps share is an
error (`` .s lies on a crease shared by 2 flaps ``, hint `` name the flap
with #[...] ``), and a crease as the depth needs `moving` to walk inward
from (`` `up to` a crease needs `moving` to walk inward from ``, hint
`` name the flap with a point instead ``).

```{.bel .prelude name=half}
paper square
fold (map .b onto .a) as --d
```

```{.bel .frag prelude=half}
.s = --d * --ab                        ; on the hinge, under both layers
fold (map .a onto .s) (moving .a) (up to .s)

; expect error "lies on a crease shared by 2 flaps"
```

**Placement.** The moved block lands on top of the paper it folded from,
or underneath with `(mountain)`. `(over <flap>)` and `(under <flap>)`
slide it into the stack beside a flap that stays
([[decision/0052]]): the target lies where the block lands, and the block
goes right above or right below it. The direction of a placed fold follows
from the placement, so `(mountain)` beside it is an error (`` a placed
fold derives its direction ``, hint `` drop mountain ``). The target
stays (`` the placement target moves with the fold ``, hint `` name a
stationary flap ``) and covers the landing (`` .p's flap does not cover
where the moved material lands ``), and a block that would have to pass
through a layer on its way is refused (`` placing the moved material
under .p would pierce another layer ``). The letter of the crease a fold
scores follows from the state it leaves
([[reference/model#def-letter|def-letter]]): a fold through a stack reads
valley on a face-up layer and mountain on a face-down one, and `flip`
changes no letter.

```{.bel .frag prelude=sheet}
fold (map .a onto .d) (moving .a)
fold (through .m .n) (moving .b) (under .p)      ; without (up to .b) the whole layer would go

; expect error "would pierce another layer"
```

**Along an existing crease.** `fold (--d)` folds along a crease the
program has scored, without restating its construction. The crease has to
lie on one line under the layers the fold reaches (`` the crease is bent
under the moving flaps ``, hint `` select a straight segment with `&` or
move fewer flaps ``, [[reference/beloch-operands#filters]]), and it is
one crease: a union is refused (`` fold folds along one existing crease; a
union spans several ``). With `up to` and `into`, a crease marked through
every layer folds some of them and keeps its name (The output clause,
below).

```{.bel .frag}
mark (through .a .c) as --ac
mark (through .b .d) as --bd
fold ([--ac --bd]) (moving .a)

; expect error "a union spans several"
```

## `unfold`

`unfold` turns layers back over a crease that every one of them lies
beside, and opens the folded hinges on it between the layers that turn and
the layers that stay ([[reference/model#def-unfold|def-unfold]]). Its axis is a crease
the program has scored, and it scores none, so it takes no `as` or `into`.
`(moving …)` names the flap the turning layers grow from, and a word after
the flap says which layers turn with it: `(moving .b up)` the layers above
it, `(moving .b down)` the layers below it; `(moving .b)` is `up`. `fold`
takes neither word, and `unfold` takes no `(mountain)`. `(up to …)` names a deeper flap to grow from. `(toward …)`
names a layer that stays; alone, it turns every layer on its side of the
crease that the same closure, run inward from it, leaves behind.

```{.bel .prelude name=two-folds}
paper square
fold (map .b onto .a) as --d
.m = --d * --ab
fold (map .m onto .a) as --q
```

```{.bel .frag prelude=two-folds}
unfold (--q) (moving .b)                   ; the layer of .b and the two above it

; assert .b = (1/2, 0)
; assert .a = (0, 0)
; assert steps = 3
```

```{.bel .frag prelude=two-folds}
unfold (--q) (toward .a)                   ; every layer but the one of .a

; assert .b = (1/2, 0)
; assert .a = (0, 0)
```

```{.bel .frag prelude=two-folds}
unfold (--q) (moving .b down)              ; the layer of .b and the one below it

; assert .a = (1/2, 0)
; assert .b = (1/2, 0)
```

A fold along a line with all of the paper on one side of it fails, and its
message names `unfold`. A fold along hinges with paper on both sides of
them folds: the hinges on the line between the moving and the staying layers
open where they were folded and fold where they were flat. An `unfold` whose
layers would fold a flat hinge fails, and its message names `fold`.

```{.bel .frag prelude=two-folds}
fold (--q) (moving .b)

; expect error "write unfold"
```

## `reverse`

`reverse` runs an inside or an outside reverse fold: the tip a line cuts
off a folded edge turns through its spine, as two placed folds over one
line ([[reference/model#def-reverse|def-reverse]], [[decision/0043]]). It reads its axis
from a construction the way `fold` does, the tip the axis cuts off implies
the side, and `(outside)` asks for the outside reverse fold.

```{.bel .frag prelude=triangle}
reverse (map .b onto .c)
reverse (map .d onto .c)

; assert .b = .c
; assert .d = .c
; assert faces = 6
```

```{.bel .frag prelude=half}
reverse (map .a onto .d) (outside)

; assert .a = .d
; assert faces = 4
```

A tip of several layers can open in more than one place
([[reference/model#def-reverse|def-reverse]]). The reverse then fails, and its error
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

## `flatten` and `flip`

`flatten` folds the rays around one vertex in one move
([[reference/model#def-flatten|def-flatten]]). Some flat states are out of
reach of one simple fold at a time: the three angle bisectors of a
triangle with the altitude from their meeting point fold flat, the rabbit
ear [@hull2020, Thm. 8.5], and no sequence of single folds reaches that
state [@demaine2007, §14.1.1]. A statement folds one vertex; deciding
flat-foldability for a sheet of many vertices is NP-hard
[@hull2020, §6.6].

**Items.** A *ray* item names a piece of a marked crease at the vertex,
`(--l)` or `(--l & .p)`, with `mountain` or `valley` after it where the
program fixes its letter; a bare ray is left to the solver. `(.p over .q)`
orders two sectors in the result, `(staying <flap>)` names the stayer,
the wedge that keeps its place, `(on <flap>)` names the anchor, and
`(toward .p)` selects among the states that remain. Every item but
`toward` is a constraint that narrows the set of states; `toward` picks
one of them. `staying` and `toward` stand at most once (`` only one
staying item per flatten ``, `` only one toward item per flatten ``), and
an item that rules nothing out is no error.

**The stayer.** Without `staying`, the stayer is the wedge of less than a
half-turn between the folded rays of the first two ray items, so the
order of those two is part of the fold; the other items stand in any
order. Two leading rays on one line leave no such wedge
(`` collinear leading creases don't pick a stayer ``, hint `` add
(staying .p) ``). With `staying`, the stayer is the one wedge whose
closure holds every named point, and the order of the rays says nothing
(`` <point> does not lie on the anchor ``, hint `` name a point on the
flap the fan folds ``; `` no sector of the fan holds every staying
point ``; `` the staying points lie in more than one sector ``, hint
`` add a point inside the sector that stays ``).

**Resolution.** A ray item resolves to every piece of its crease at the
vertex: a crease an earlier fold split at the vertex carries two, and
both are tried, with the states that keep the stayer still deciding
between them. `&` narrows a ray to one piece where both combinations
leave states (`` <name> is ambiguous at the vertex ``, hint `` select a
segment with `&` ``). A ray with no material (`` --<name> has no material
segment ``, `` no segment of <expr> matches ``) and an operand that is no
marked crease (`` collapse folds along existing creases; <operand> is not
a material crease ``) are errors. The checks a flatten runs, with every
message, stand in the kernel's tables ([[reference/kernel#fan]]).

**Selection.** Where several states remain, `toward .p` selects in three
steps ([[reference/model#open-flatten-selection|open-flatten-selection]]): the
states whose moved material lies toward `.p`, among them those with the
fewest mountains on the rays the program gave, among those the one whose material
toward `.p` lies on top. A point on the line of a crease through the
vertex names no side (`` `toward` does not pick a side — the point is
collinear with a crease through the vertex ``, hint `` aim it off the
creases ``). Without `toward`, only the mountain count runs, and more than
one state left is an error (`` flatten is ambiguous: <n> realizations ``,
hint `` add (toward .p) to pick the fold direction ``); states that hold
different wedges still are one too (`` flatten is ambiguous: its
candidates hold different sectors still ``, hint `` add (staying .p) with
.p in the sector that stays ``). An `over` no state satisfies is
`` contradictory `over` ``.

**The crease.** With an even number of rays the crease a flatten scores
is the bundle of the rays the program gave; with an odd number it is the emergent
ray, the one crease no construction names, so a meet against the bound
name finds where it reaches the edge. The letters in the output are those
of the state ([[reference/model#def-letter|def-letter]]).

```{.bel .prelude name=ear}
paper square
mark (through .a .c) as --diag
mark (map --ab onto --diag) as --ea
mark (map --ab onto --bc) as --eb
mark (map --bc onto --diag) as --ec
```

```{.bel .frag prelude=ear}
flatten (--ea) (--ec) (--eb) (toward .a) as --ear   ; three rays: the fourth emerges
.t = --ear * --ab                                   ; where the ear reaches the edge

; assert --ear is mountain
```

```{.bel .frag prelude=ear}
flatten (--ea) (--ec) (--eb)

; expect error "flatten is ambiguous"
```

```{.bel .frag prelude=ear}
flatten (--ea) (--ec) (--eb) (toward .b)      ; .b lies on the line of --eb

; expect error "does not pick a side"
```

```{.bel .frag prelude=ear}
flatten (--eb & .b) (--ea & .a) (--ec & .c) (staying .d) (toward .a) as --ear

; assert --ear is mountain
```

```{.bel .frag}
mark (through .a .c) as --d1
mark (through .b .d) as --d2
flatten (--d1 & .a) (--d1 & .c) (--d2 & .b mountain) (--d2 & .d)

; expect error "collinear leading creases"
```

`flip` turns the whole sheet over and takes no item
([[reference/model#def-flip|def-flip]]): every face changes between face up
and face down, and the stack reverses, so the layer at the bottom of a
pile is on top afterwards. Every hinge keeps its angle and its letter
([[reference/model#lem-flip|lem-flip]]); a fold that follows lands on what was
the back, and its crease reads mountain against the front where the same
fold before the flip would read valley. `flip` takes no axis: where the
sheet comes to lie on the table is settled up to a motion of the table,
and the kernel reflects it across a line of its own
([[reference/kernel#flip]]).

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

## The output clause

The crease a write scores is its one output, and the clause after the
items says what becomes of it, for every verb:

- `as --f` binds it to a new name: `fold (map .a onto .c) (moving .a) as
  --f`, `flatten (--ba \ .a) … as --r`. A name already bound is an error;
  `as --f!` rebinds it, with the `!` of [[reference/beloch-names#the-rule-of-rebinding]].
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

`into` takes a crease the program has scored: a name no statement bound
(`` --zz is not bound ``, hint `` write as --zz to name a new crease ``), a
line bound by `=` (`` into needs a crease; --l is a line ``), a selection
from other creases (`` into needs a crease of its own; --s is a selection
from others ``) and a paper edge (`` into needs a scored crease; --ab is a
paper edge ``) are errors, and so is new material off every segment of the
crease (`` the material this scores lies on no segment of --ac ``, hint
`` name it with as instead ``).

```{.bel .frag}
mark (through .a .c) as --ac
mark (through .b .d) into --ac

; expect error "lies on no segment of --ac"
```

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
its own, so that highlighting colors an anchor, a placement and a
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

::: {.figure #fig-lang-flatten caption="One `flatten` collapses six of the eight rays at the paper center into the preliminary base, and the diagonal through `.a` and `.c` stays flat. Each ray item picks a piece of a marked crease with `&`, `(.q over .r)` fixes which quarter comes to the front, and `(toward .q)` chooses one of the flat states the rays allow." views="cp folded" highlight=".a .c"}
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
