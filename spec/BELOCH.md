---
title: The language
description: Beloch as the signature of the model. Which sorts a program names, which operations it applies, and how the surface syntax marks the difference.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

Three documents describe Beloch. `MODEL.md` is the mathematics: the states,
the values and the operations, stated so that they can be proven about.
`KERNEL.md` is the implementation: how `packages/core` holds a state and
which statements of the model each part realizes. This document is the
language: the signature of the model, and how the written form of a program
reflects it. It is the language reference (ADR 0021): the concrete grammar,
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
stmt    := write_stmt | bind_stmt | def_stmt | apply_stmt | export_stmt
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

## Parameter types

A write takes typed arguments. Four of the types are value sorts of the
model and are supplied by a read; the others are enumerations that occur
only as an argument of a write. The type of a slot is what a graphical
editor binds to: a slot of type flap gets a flap picker, a slot of type
placement a menu of four entries.

| type | values | slots |
|---|---|---|
| line | a construction, a name bound by `=`, or a crease whose segments lie on one table line ([def-line](/model/#def-line)) | the operands of a construction, the axis of `mark` |
| crease | a name bound by `as`: the material scored under that name ([def-bundle](/model/#def-bundle)), or a selection from one | the axis `(--d)` of `fold` and `reverse`, the rays of `flatten`, the meet `*`, the filters `&` `\` `[…]`, `free on` |
| flap | a point, a line, or `#[…]`, resolved by incidence ([def-selector](/model/#def-selector)) | `moving`, `up to`, `on`, `staying`, the target of `over` and `under` |
| point | a named or selected point | `at`, `between`, `toward` |
| placement | top, bottom, over a flap, under a flap ([def-reflection](/model/#def-reflection)) | `fold` |
| kind | inside, outside ([def-reverse](/model/#def-reverse)) | `reverse` |
| extent | the whole line, between two points, at a point ([def-mark](/model/#def-mark)) | `mark` |
| intent | mountain, valley; an annotation for the crease pattern, no part of the state | `mark` |
| letter | mountain, valley as a constraint on a ray ([def-letter](/model/#def-letter)) | `flatten` |
| order | one sector over another | `flatten` |
| selection | toward a point ([def-selection](/model/#def-selection)) | constructions, `flatten` |

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
              | "moving" flap_operand
              | "up" "to" flap_operand
              | "mountain"
              | ( "over" | "under" ) flap_operand
reverse_item := axis
              | "moving" flap_operand
              | "outside"
mark_item    := axis
              | "on" flap_operand
              | "between" point_operand point_operand
              | "at" point_operand
              | "mountain" | "valley"
flatten_item := line_operand [ "mountain" | "valley" ]
              | flap_operand "over" flap_operand
              | "staying" flap_operand
              | "toward" point_operand
axis         := construction_body | line_operand
```

`flip` takes no item. Round parentheses are items and braces are blocks
(`def`, `on`, `export`); no item uses braces. The `toward` item of
`flatten` selects among states rather than among lines
([open-flatten-selection](/model/#open-flatten-selection)); a construction
carries its own selection inside its item.

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
direction, and the error says so: `a placed fold derives its direction;
drop mountain`.

```{.bel .frag}
fold (map .a onto .c) (moving .a) (over .b) (mountain)

; expect error "a placed fold derives its direction; drop mountain"
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
construction_body := "align" CREASE_NAME* alignment+ [ "toward" point_operand ]
                   | prose_axiom
alignment         := "(" [ CREASE_NAME ] object "onto" [ CREASE_NAME ] object ")"
                   | "(" [ CREASE_NAME ] "through" point_operand ")"
                   | "(" [ CREASE_NAME ] "perp" line_operand ")"
object            := point_operand | line_operand
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
(align (.p onto --l) (through .q) toward .a)    ; axiom 6, with its selection
(align (.p onto --l) (perp --m))                ; axiom 4
(align (--l onto --m) toward .p)                ; axiom 5, with its selection
(align (.p onto --l) (.q onto --m))             ; axiom 7

; assert .p = (1/2, 1/2)
; assert .q = (1/2, 0)
```

The prose forms of the seven axioms are sugar for these and stay as they
are; they are the `prose_axiom` alternatives, spelled in `SPECIFICATION.md`
§4.1 to §4.5c until their sections move here: `(map .a onto .c)`,
`(through .a .b)`, `(perp --l through .p)`, `(map .p onto --l through
.q)`, `(map .p onto --l perp --m)`, `(map --l onto --m toward .p)`, `(map
.p onto --l and .q onto --m)`. A selection belongs to the construction and
is written inside its item, because a bound line (`--l = (map --a onto --b
toward .p)`) needs it without any write.

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
prose_axiom     ; SPECIFICATION.md §4.1 to §4.5c
bind_stmt       ; SPECIFICATION.md Appendix A
def_stmt        ; SPECIFICATION.md Appendix A
apply_stmt      ; SPECIFICATION.md Appendix A
export_stmt     ; SPECIFICATION.md Appendix A
```

## References
