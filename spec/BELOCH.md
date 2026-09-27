---
title: Language
description: Beloch as the signature of the model. Which sorts a program names, which operations it applies, and how the surface syntax marks the difference.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

Three documents specify Beloch (ADR 0032). `MODEL.md` is the mathematics:
the states, the values and the operations, stated so that they can be proven
about. `FOLD.md` is the output format. This document is the language: the
signature of the model, and how the written form of a program reflects it.
How the reference implementation in `packages/core` realizes the model is
the subject of `KERNEL.md`, which binds no other implementation. This
document is also the language reference: the concrete grammar,
every keyword, how an operand resolves, and the errors, one section per
sort and per write. `SPECIFICATION.md` holds the sections that have not
moved here yet.

The language refers to the model by statement ids and to the specification
by section. The model does not refer to the language.

Each section states its part of the grammar in the notation of the
collected [grammar](#grammar) at the end: `:=` defines, `|` separates
alternatives, `[ … ]` is optional, `( … )` groups, `*` and `+` repeat,
quoted strings are keywords, upper-case names are tokens, and `;` starts a
comment that runs to the end of the line. The collected grammar is
assembled from the fragments; the parsers in `packages/core` and
`packages/grammar` are held to it.

## A program is a path

A program starts from a sheet ([def-sheet](/model/#def-sheet)) and applies
operations one after another. Each operation takes the current flat folded
state ([def-flat-state](/model/#def-flat-state)) and either produces the next
one or fails with a reason. The program's meaning is the finite sequence of
states it passes through; its result is the last state.

```grammar
program := "paper" "square" stmt*
stmt    := annotation* ( write_stmt | bind_stmt | def_stmt | apply_stmt | export_stmt )
```

## Reads and writes

One law organises the surface syntax (`SPECIFICATION.md` §4.10): an
operation that changes the state is a keyword verb, sequenced in program
order; an operation that only computes something from the current state is
an operator, a bracket, or a construction, and may appear anywhere a value
is needed.

In the terms of the model, the writes are the partial functions from states
to states ([def-write](/model/#def-write)), and the reads are functions from
a state into the value sorts ([def-read](/model/#def-read)). A read never
fails silently: where the state has no answer, such as a point that lies on
no face or a construction with two solutions and no way to pick one, the
read is an error.

**Sorts.** Point, line, flap, and bundle (a set of crease segments), the
value sorts of the model's section on values; each a value computed in the
current state and carried in paper coordinates, so it survives later folds.

**Writes.** The operations of the model's section on operations, named by
the verbs `mark`, `fold`, `reverse`, `flatten` and `flip`. Each is a
partial function on states with its own domain; the domain is the
language's notion of a safe operation, and the model states it. A *write
statement* is a verb followed by its arguments; its shape is given under
[Write statements](#write-statements).

**Reads.** Constructions (below), selectors (`#[…]`, `*`, `--[…]`, `free
on`), and the filter operators (`&`, `\`, `[…]`), which form a Boolean
algebra on the segments of a bundle: intersection with an incidence
predicate, difference, union.

**The meet.** `--x * --y`, and `.[--x --y --z]` for more operands, is the
one paper point the operands have in common as sets of paper points
([def-meet](/model/#def-meet)). An operand may lie on several paper lines,
as a crease scored through several layers does; on the preliminary base
`--h * --v` is the centre of the paper. A paper edge such as `--ab` counts
as its side of the sheet. The meet is an error when the operands have no
common point, when they share a stretch of paper, and when they have two or
more common points; the last message lists the points in paper coordinates,
and `&` narrows an operand to the pieces that cross at the one meant.

## Parameter types

A write takes typed arguments. Four of the types are value sorts of the
model and are supplied by a read; the others are enumerations that occur
only as an argument of a write. The type of a slot is what a graphical
editor binds to: a slot of type flap gets a flap picker, a slot of type
placement a menu of four entries.

| type | values | slots |
|---|---|---|
| line | a construction, a name bound by `=`, or a crease whose segments lie on one table line ([def-line](/model/#def-line)) | the operands of a construction, `heading`, `toward`, the axis of `mark` |
| crease | a name bound by `as`: the material scored under that name ([def-bundle](/model/#def-bundle)), or a selection from one | the axis `(--d)` of `fold` and `reverse`, the rays of `flatten`, the meet `*`, the filters `&` `\` `[…]`, `free on` |
| flap | a point, a line, or `#[…]`, resolved by incidence ([def-selector](/model/#def-selector)) | `moving`, `up to`, `on`, `staying`, the target of `over` and `under` |
| point | a named or selected point | `at`, `between`, `toward` |
| placement | top, bottom, over a flap, under a flap ([def-reflection](/model/#def-reflection)) | `fold` |
| kind | inside, outside ([def-reverse](/model/#def-reverse)) | `reverse` |
| extent | the whole line, between two points, at a point ([def-mark](/model/#def-mark)) | `mark` |
| intent | mountain, valley; the direction the crease pattern draws, no part of the state | `mark` |
| letter | mountain, valley as a constraint on a ray ([def-letter](/model/#def-letter)) | `flatten` |
| order | one sector over another | `flatten` |
| selection | `toward` a point or a line, the side that stays; `moving` a flap, the side that folds over; `heading` a line, the direction of the crease ([def-selection](/model/#def-selection)) | `toward` and `moving`: `mark`, `fold`, `reverse` and a binding over a construction; `toward` a point: `flatten`; `heading`: `align` |

Line and crease are two sorts under one sigil, and the binding tells them
apart: `--l = …` is a line, `… as --l` is a crease. A crease stands where a
line is wanted by projection to its table line, which exists while its
segments are collinear (ADR 0014) and is an error once a fold has bent it.
A line stands nowhere a crease is wanted: it has no material until a
`mark` scores it. The check needs no geometry, so a program's sorts can be
verified before it is evaluated.

```grammar
flap_operand  := point_operand | line_operand | "#[" point_operand+ "]"
```

## Write statements

A write statement is a verb followed by its *items*. An item is a
parenthesised block whose first token names its type; items may stand in
any order. The construction that supplies the axis is an item like the
others, so every slot of a write's signature is one block in the source,
delimited on both sides and classified by its head.

```grammar
write_stmt := verb item* [ "as" CREASE_NAME [ "!" ] | "into" CREASE_NAME ]
verb       := "mark" | "fold" | "reverse" | "flatten" | "flip"
item       := "(" item_body ")"
item_body  := fold_item | reverse_item | mark_item | flatten_item
```

Which item bodies a verb accepts is stated with the verb; the bodies of the
current writes, ahead of their own sections:

```grammar
fold_item    := axis
              | side_item
              | "up" "to" flap_operand
              | "mountain"
              | ( "over" | "under" ) flap_operand
reverse_item := axis
              | side_item
              | "outside"
mark_item    := axis
              | side_item
              | "on" flap_operand
              | "between" point_operand point_operand
              | "at" point_operand
              | "mountain" | "valley"
flatten_item := line_operand [ "mountain" | "valley" ]
              | flap_operand "over" flap_operand
              | "staying" flap_operand
              | "toward" point_operand
side_item    := [ toward_subject ] "toward" ( point_operand | line_operand )
              | "moving" flap_operand
axis         := construction_body | line_operand
```

`flip` takes no item. Round parentheses are items and braces are blocks
(`def`, `on`, `export`); no item uses braces. The side items name the side
of the axis that stays, `toward`, and the side that folds over, `moving`,
and select among the candidates of a construction by them
([Selection](#selection)). The `toward` item of `flatten` selects among
states rather than among lines
([open-flatten-selection](/model/#open-flatten-selection)).

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
fold    (through .m .n) (moving .b) (under .p)
fold    (map .a onto .b) (moving .a) (mountain)

; assert steps = 4
; assert faces = 8
```

```{.bel .frag}
fold    (map .c onto .b) (up to .d)                ; the depth names the anchor

; assert steps = 1
; assert faces = 2
```

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

::: {.figure #fig-lang-fold caption="The first `fold` carries a single item, the construction `(map .b onto .a)`, and reads its anchor from the corner that alignment moves. The second carries two: `(through .p .q)` is the line the paper turns about, `(moving .b)` the corner that travels. With no placement item the block lands on top of the paper it was folded from, and `as --f` gives the crease a name later statements can select." views="cp folded" highlight="--f"}
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

## Constructions

A construction is the read of sort line that a write's axis comes from: a
set of *alignments* that together determine one fold line, or several. An
alignment is an incidence between two objects, each a point, a line, or the
folded image of one: a point onto a point, a point onto a line, a line onto
a line, the fold line through a point, the fold line perpendicular to a
line. Alperin and Lang show that the seven Huzita-Justin axioms are exactly
the minimal sets of such alignments that determine one fold line with
finitely many solutions [@alperin2006, §3], and that the same alignments,
distributed over two fold lines, give the 489 two-fold axioms [@alperin2006,
§4]. The construction with its alignments is the canonical form; an axiom
number is the name of one such set.

```grammar
construction_body := "align" CREASE_NAME* align_part+
                   | prose_axiom
align_part        := alignment
                   | "(" "heading" line_operand ")"
alignment         := "(" [ CREASE_NAME ] object "onto" [ CREASE_NAME ] object ")"
                   | "(" [ CREASE_NAME ] "through" point_operand ")"
                   | "(" [ CREASE_NAME ] "perp" line_operand ")"
object            := point_operand | line_operand
prose_axiom       := "through" point_operand point_operand
                   | "map" point_operand "onto" point_operand
                   | "perp" line_operand "through" point_operand
                   | "map" point_operand "onto" line_operand "perp" line_operand
                   | "map" line_operand "onto" line_operand
                   | "map" point_operand "onto" line_operand "through" point_operand
                   | "map" point_operand "onto" line_operand
                         "and" point_operand "onto" line_operand
line_binding      := CREASE_NAME "=" "(" construction_body ")" side_item*
```

```{.bel .prelude name=axioms}
paper square
mark (through .a .b) as --l
mark (through .b .c) as --m
mark (through .a .c) as --ac
.p = free on --ac from .a at 1/2
.q = free on --ab from .a at 1/2
```

```{.bel .construction prelude=axioms}
(align (.a onto .c))                            ; axiom 2
(align (through .a) (through .b))               ; axiom 1
(align (perp --l) (through .p))                 ; axiom 3
(align (.p onto --l) (through .q)) (toward .a)  ; axiom 6, and the side that stays
(align (.p onto --l) (perp --m))                ; axiom 4
(align (--l onto --m)) (toward .c)              ; axiom 5, and the side that stays
(align (.p onto --l) (.q onto --m))             ; axiom 7

; assert .p = (1/2, 1/2)
; assert .q = (1/2, 0)
```

The prose forms of the seven axioms are sugar for these, the
`prose_axiom` alternatives: `(through .a .b)`, `(map .a onto .c)`, `(perp
--l through .p)`, `(map .p onto --l perp --m)`, `(map --l onto --m)`,
`(map .p onto --l through .q)`, `(map .p onto --l and .q onto --m)`. A
prose form means what its `align` spelling means. The axiom number names
one alignment set, recognised by the kinds of its alignments; it appears in
error messages, in provenance (`"axiom": "axiom6"` in `beloch:edges`) and
here, and it is no type of its own. A set that is none of the seven is an
error naming its alignments.

A construction holds what determines the line: its alignments and its
`heading`. What determines the fold, `toward`, `moving` and the placement,
are items of the statement that reads the construction (ADR 0031). A
binding takes the side items as a write does, `--k = (map --v onto --h)
(toward .b)`, so a bound line is selected the way a fold along it would
be. A construction inside an expression takes no selection; it is bound
first. A `toward` written inside a construction is an error, with the hint
`write it as an item of the write: (toward .p)`.

A construction over several fold lines names them and lets each alignment
say which line folds: `(align --a --b (--a .p onto --l) (--b .q onto --m)
(--a .r onto --b .s))` is the two-fold axiom Alperin and Lang call
`AL6ab8`. Its name is composed from the kinds of its alignments, as every
two-fold name is [@alperin2006, §4]; `packages/multifold` computes the
same names. No two-fold construction is evaluated by the kernel yet; the
syntax is fixed here so that it needs no second form when one is.

::: {.open #open-multifold-syntax name="naming fold lines inside a construction"}
The two-fold form above writes the folding line in front of the object it
folds, `(--a .p onto --l)`, and a doubly folded alignment as `(--a .r onto
--b .s)`. Whether the fold lines of a construction are declared in the
`align` head, as above, or are the names the binding form gives, and how an
alignment on a virtual point (Alperin and Lang's `AL10`) is written, is not
decided and waits for the first two-fold construction the kernel can solve.
:::

### Selection

Axioms 5, 6 and 7 leave finitely many candidate lines, usually more than
one, and the statement that reads the construction keeps one of them
([def-selection](/model/#def-selection)). A candidate creases a face of
the current state; a line off the paper, or one grazing an edge or a
corner, creases nothing and is no candidate. An `onto` alignment is an
incidence: after the fold, one of its two objects lies on the other, and
either may be the one that moves, so `(--l onto .p)` means `(.p onto
--l)`. The stages run in order, numbered as in the model, and each error
below names the stage that left no line or several.

1. `(heading --l)` keeps the candidates whose line makes the smallest
   angle with `--l`. The position of `--l` plays no part, and a tie passes
   on to `toward`.
2. `(toward …)` names the side of each candidate that stays: the side that
   holds the point, or the side the line lies on. A point on the
   candidate, or a line the candidate crosses on the paper, names no side
   of it. `(moving …)` names the side that folds over: the side of its
   first anchor point off the candidate, or the side of a line's material.
   With both items, `moving` has to name the side opposite `toward`.
3. A candidate remains when the fold with that side carries out every
   alignment: one of its objects lies on the side that folds over and lands
   on the other, where a line landing on a point needs paper at the place
   that lands, or a point lies on the candidate and on its target line
   already. A candidate for which stage 2 names no side does not remain.
   With neither item, a candidate remains when either side carries the
   construction out.
4. Among several remaining candidates, `toward` keeps the one that lands
   its material nearest it: everything that folds over, or with `(x toward
   …)` only the part of `x`. Distances are between sets and compared
   exactly.

The side that stage 2 names is the side the fold moves. With no side item,
the side that alone carries the construction out folds over, and where both
do, the side of the first object as the program writes it: `fold (map .a
onto .b)` folds `.a` onto `.b`, and `fold (map .a onto .b) (toward .a)`
folds `.b` onto `.a`. Where that object names no side either, a line lying
across the candidate or a point on it, the write needs `toward` or
`moving`. `toward` names the side that stays on every write: on a
construction of one line, on a fold along an existing crease, `fold (--v)
(toward .b)`, on `reverse (--h) (toward .d)`, whose tip lies opposite `.d`,
and on a placed fold, whose block is the material opposite the `toward`
where the write has no anchor.

```{.bel .frag}
fold (map .a onto .b) (toward .a)

; assert .b = (0, 0)
```

`(x toward .u)` names what goes toward `.u`. `x` is one of the objects of
the construction's alignments, compared by place, and the candidates that
do not fold `x` over drop out at stage 3.

```grammar
toward_subject := point_operand | line_operand
```

Errors, with the stage that raises them:

- no candidate crosses the paper: "map .p onto --d through .q: no crease
  lands on the paper, so there is no fold to make";
- no candidate carries out the construction: with `toward`, "no fold of map
  .p onto --d through .q keeps .x on the side that stays and carries out
  its alignments"; with `moving` alone, "no fold of … moves .c and carries
  out its alignments"; with neither, "no fold of … carries out all its
  alignments at once";
- `toward` and `moving` naming the same side: "toward .x and moving .c name
  the same side of the fold line", hint "drop one of them";
- a `toward` on a line that determines one: "toward .x names no side of the
  fold line";
- `(x toward …)` with an `x` that is no object of the construction: "x is
  none of the objects of …";
- two candidates landing their material equally near `toward`: "toward .x
  lies as near to where one fold of … lands its material as to where
  another does", hint "name what goes toward .x, e.g. (.p toward .x)";
- several candidates remaining without `toward`: "map .p onto --d through .q
  is ambiguous: 2 folds carry it out, all landing on the paper", hint "add
  (toward .x) or a heading";
- `heading` on a construction that determines one line, a parallel axiom 5
  among them: "this construction determines one line", hint "drop heading";
- `toward` or `moving` on a `mark` along an existing line, which selects
  nothing and moves nothing.

### Axiom 5, a line onto a line

`(map --l1 onto --l2)` folds `--l1` onto `--l2` along an angle bisector
[@justin1986, §8.1, operation ⑤], [@hull2020, §1.5]. Two lines that cross
have two bisectors, perpendicular to each other. Two parallel lines have
one midline, and two identical lines are an error, "lines are identical".
A line's material is the segments of a crease, or the chord of the paper
under a line bound by `=`. The kite base folds an edge onto the long
diagonal; one bisector crosses the paper and the other touches it only at
`.a`, so only the first is a candidate.

```{.bel .frag}
mark (through .a .c) as --ac
fold (map --da onto --ac)

; assert steps = 1
```

Where the two lines cross inside the material of `--l1`, each bisector has
material of both lines on both sides. `(--l1 toward .x)` measures the part
of `--l1` on the side away from `.x`: the two folds land it on the two rays
of `--l2` from the crossing, and the nearer landing is kept. Two landings
on the same ray, as long as each other, are equally near every point, and
so are two landings on opposite rays for a point on the perpendicular to
`--l2` through the crossing
([lem-crossing-landing](/model/#lem-crossing-landing)). A bare `toward`
measures the part of `--l2` that folds over too, and ties more often.
`moving` then separates the candidates by the flap it names. A fold with no
side item whose `--l1` lies across the fold line is an error, "--l1
straddles the fold line", hint "add `moving` to pick the swinging flap".

```{.bel .frag}
mark (through .a .c) as --ac
mark (through .b .d) as --bd
fold (map --ac onto --bd) (toward .b) (moving .c)

; assert .c = .b
```

The bisector of two rational lines is irrational in general, slope
$\sqrt2 - 1$ for $y = 0$ and $y = x$; equality, parallelism and the paper
tests stay exact (`SPECIFICATION.md` §6).

### Axiom 6, a point onto a line through a point

`(map .p onto --d through .q)` folds `.p` onto `--d` with a crease through
`.q` [@justin1986, §8.1, operation ⑥]. `.q` lies on the crease, so it is as
far from `.p` as from the landing on `--d`, which lies on the circle about
`.q` through `.p`: up to two landings, and a crease for each, the
perpendicular bisector of `.p` and its landing. Square roots suffice; cube
roots first appear with axiom 7.

The bird base's kite crease is the case the paper settles: on the
preliminary base, `map .sr onto --mid through .c` has two candidates, and
the outward one meets the folded base only at `.c`
(`examples/bases/bird-base.bel`). The largest equilateral triangle in the
square needs `toward`, since both candidates cross the paper
([fig-candidates](/model/#fig-candidates)).

Errors of its own: `.p` and `.q` the same point, "…: .p and .q are the
same point, so no fold exists"; the circle missing `--d`, "cannot fold .p
onto --d through .q: out of reach". When `.p` lies on `--d` already, the
identity landing is dropped and the mirror landing gives the crease.

### Axiom 7, two points onto two lines

`(map .p onto --d and .q onto --e)` folds `.p` onto `--d` and `.q` onto
`--e` with one crease [@justin1986, §8.1, operation ⑦]. Each alignment
traces a parabola with focus the point and directrix the line, and the
crease is a common tangent of the two, a root of a cubic: up to three
candidates [@hull2020, §2.3–2.4]. This is the operation that doubles the
cube and trisects an angle, beyond ruler and compass. The crease is
irrational in general, its coordinates in a field $\mathbb{Q}(\alpha)$ with
$\alpha$ algebraic of degree 3, and they are compared exactly.

A candidate with `.p` and `.q` on opposite sides still carries out both
alignments when the side of `.p` folds over and has paper of `--e` at the
place that lands on `.q`: `.p` lands on `--d`, and `--e` lands on `.q`.
`(.p toward .x)` measures where `.p` lands.

```{.bel .frag}
mark (through .a .c) as --diag
mark (through .b .d) as --anti
fold (map .a onto --anti and .d onto --diag) (.a toward .b)

; assert .a = (1, 0)
; assert .d = (1, 1)
```

Errors of its own: `.q` on `--e` already, "…: .q already lies on --e",
with a hint to use axiom 6 and axiom 4 instead; `--d` parallel to `--e`,
"…: --d and --e are parallel, so the cubic degenerates and no fold exists";
no common tangent, "cannot fold .p onto --d and .q onto --e: out of reach
(no common tangent)".

## Annotations

An annotation tells a reader of the program something the geometry does not
contain: which folds a diagram shows as one step, the sentence that tells
the folder what to do, the name a reader knows a corner by, how the model is
turned on the page. It never changes the geometry. A program with its
annotations removed evaluates to the same FOLD without the annotations, and
the evaluator passes them into the FOLD unchanged (ADR 0029).

```grammar
annotation := "@" WORD arg* NEWLINE
            | "@" WORD ":" WORD value* NEWLINE
arg        := value | WORD
value      := flap_operand | TEXT | RATIONAL
```

An annotation is one line. It starts with `@`, and the end of the line ends
it; a `;` comment may follow on the same line. `WORD` is a name without a
sigil. `TEXT` is text in double quotes on one line, with `\"` and `\\` as
its only escapes. `RATIONAL` is a number as everywhere else.

An annotation belongs to the statement that follows it. It may stand at the
top level and inside a `def` body; in a body it applies once per `apply`
that runs the body, to the statements of that execution (ADR 0030). An
annotation with no statement after it is an error.

A value is any read the language has: a name, a selector such as `#[.c]` or
`--a \ .b`, a meet, a construction. It is evaluated against the state the
following statement starts from, and a read that fails is an error at the
annotation. Reads write nothing, so the rule above holds for every value.

### The vocabulary

An annotation without a namespace takes its key from this table. Another
key is an error, and so are arguments that do not fit the key.

| key | arguments | meaning |
|---|---|---|
| `step` | `[WORD] [TEXT]` | opens a step group: the following statements are one step for the reader. The word labels the step, the text is its instruction. |
| `label` | `WORD` | names the following statement, so that an output can refer to it |
| `say` | `TEXT` | the instruction sentence for the following statement |
| `call` | `value TEXT` | the name a reader knows the entity by |
| `orient` | `value [value] direction`, or `value axis` | how the model is turned on the page |

**`step`.** A step group runs from the statement after `@step` to the next
`@step` in the order the statements execute, or to the end of the program.
Groups do not nest and do not scope anything: names bound inside a group
stay visible after it, and a `def` body is still the only scope. Statements
before the first `@step` belong to no group, and an output shows each write
among them as a step of its own.

**`label`.** A label is unique among the labels at the top level, and among
those of one `def` body. A label in a body names one statement per
execution of the body. Labels live apart from the names of points, lines,
defs and instances, so a label can never shadow one of them.

**`call`.** The name holds from the following statement on, for the entity
the value resolves to, whatever name the program reaches it by. A later
`@call` on the same entity replaces it. Two entities may carry the same
name at once, which is what a repetition wants: each application of a `def`
has its own "petal tip".

**`orient`.** A direction is `up`, `right`, `down` or `left`, an axis is
`vertical` or `horizontal`, both on the page. The three forms:

- `@orient .a up`: the direction from the centroid of the outline of the
  folded state to `.a` points up.
- `@orient .a .b up`: the direction from `.a` to `.b` points up.
- `@orient --l vertical`: the line lies vertical. Of the two rotations that
  achieve it, the smaller one from the current orientation wins. The line
  must be a single table line in the state; a crease a fold has bent is an
  error, as it is wherever a line is wanted.

The orientation holds until the next `@orient`. An output turns its
drawing; the frames of the FOLD stay where the evaluator put them.

### Annotations of an output

A key with a namespace, `@yr:hold .a`, belongs to the output library that
owns the namespace, and the kernel does not know its key. It checks that
every argument is a value and resolves it, and passes the annotation on.
A bare word is not an argument here, because only the key could say what
it means; an output that wants a keyword takes text, `@yr:arrow "push"`.

```beloch
paper square

@step "Fold the square in half along the diagonal."
fold (map .a onto .c) as --bd

@step prelim "Reverse-fold both sides into the preliminary base."
@call .a "top corner"
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
.o = --h * --v
--mid = (through .c .o)

@step sides
@orient .o .c down
.sr = --ab * --h
@say "Reverse-fold the right side corner to the centre line."
@yr:hold .o
reverse (map .sr onto --mid through .c)
```

::: {.open #open-annotation-say-lines name="a sentence over several lines"}
`TEXT` ends with its line, so a long sentence makes a long line. Whether
consecutive `@say` lines join into one sentence waits for a program that
needs it.
:::

## What this document will grow into

One section per sort and one per write, each pointing at the model
statement that defines it, with its grammar fragment, the resolution of its
operands, its errors, and a worked example rendered live on this page. That
is the material a graphical editor binds its actions to.

## Grammar

The fragments of the sections above, collected. A rule a fragment refers to
and no section of this document states is listed under *Defined elsewhere*,
with its home.

```grammar-collected
```

```grammar-external
point_operand   ; SPECIFICATION.md Appendix A
line_operand    ; SPECIFICATION.md Appendix A
bind_stmt       ; SPECIFICATION.md Appendix A
def_stmt        ; SPECIFICATION.md Appendix A
apply_stmt      ; SPECIFICATION.md Appendix A
export_stmt     ; SPECIFICATION.md Appendix A
```

## References
