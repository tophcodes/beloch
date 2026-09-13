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
alternatives, `[ … ]` is optional, `*` and `+` repeat, quoted strings are
keywords, upper-case names are tokens. The collected grammar is assembled
from the fragments; the parsers in `packages/core` and `packages/grammar`
are held to it.

## A program is a path

A program starts from a sheet ([def-sheet](/model/#def-sheet)) and applies
operations one after another. Each operation takes the current flat folded
state ([def-flat-state](/model/#def-flat-state)) and either produces the next
one or fails with a reason. The program's meaning is the finite sequence of
states it passes through; its result is the last state.

```
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
| line | a construction, or a crease selection that yields one segment | the axis of `mark`, `fold`, `reverse` |
| flap | a point, a line, or `#[…]`, resolved by incidence ([def-selector](/model/#def-selector)) | `moving`, `up to`, `on`, `staying`, the target of `over` and `under` |
| point | a named or selected point | `at`, `between`, `toward` |
| bundle | the segments of a crease ([def-bundle](/model/#def-bundle)) | the rays of `flatten` |
| placement | top, bottom, over a flap, under a flap ([def-reflection](/model/#def-reflection)) | `fold` |
| kind | inside, outside ([def-reverse](/model/#def-reverse)) | `reverse` |
| extent | the whole line, between two points, at a point ([def-mark](/model/#def-mark)) | `mark` |
| intent | mountain, valley; an annotation for the crease pattern, no part of the state | `mark` |
| letter | mountain, valley as a constraint on a ray ([def-letter](/model/#def-letter)) | `flatten` |
| order | one sector over another | `flatten` |
| selection | toward a point ([def-motion](/model/#def-motion)) | constructions, `flatten` |

```
flap_operand  := point_operand | line_operand | "#[" point_operand+ "]"
```

## Write statements

A write statement is a verb followed by its *items*. An item is a
parenthesised block whose first token names its type; items may stand in
any order. The construction that supplies the axis is an item like the
others, so every slot of a write's signature is one block in the source,
delimited on both sides and classified by its head.

```
write_stmt := verb [ CREASE_NAME "=" ] item*
verb       := "mark" | "fold" | "reverse" | "flatten" | "flip"
item       := "(" item_body ")"
item_body  := fold_item | reverse_item | mark_item | flatten_item
```

Which item bodies a verb accepts is stated with the verb; the bodies of the
current writes, ahead of their own sections:

```
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

```
fold    (map .a onto .c) (moving .a)
fold    (map .a onto .c) (moving .a) (mountain)
fold    (through .m .n) (moving .b) (under .p)
fold    (map .c onto .b) (up to .d)
fold    (--d) (moving .b) (up to .c)               ; along an existing crease
reverse (map .b onto .c)
reverse (map .b onto .c) (outside)
mark    (through .a .c)
mark    (map --ab onto --cd) (on #[.c]) (between .a .m) (mountain)
flatten (--h & --bc) (--v & --cd) (.q over .r) (staying .a) (toward .q)
flip
```

The binding form puts the name after the verb, for every verb: `fold --f =
(map .a onto .c) (moving .a)`, `flatten --r = (--ba \ .a) …`.

A head that does not belong to the verb is an error naming the verb and
the item; an item type given twice is an error at the second occurrence.
`mountain` is a value of the placement type, so `(mountain)` beside `(over
…)` is two values in one slot and rejected on that ground alone.

Marking every argument as a block is what the model's operation signatures
ask for: one item per parameter, the same shape for every write. For the
tools it means that an item is one node of the syntax tree with a type of
its own, so that highlighting colours an anchor, a placement and a
construction differently, and a malformed item is contained by its
parentheses instead of swallowing the rest of the statement.

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

```
construction_body := "align" CREASE_NAME* alignment+ [ "toward" point_operand ]
                   | prose_axiom
alignment         := "(" [ CREASE_NAME ] object "onto" [ CREASE_NAME ] object ")"
                   | "(" [ CREASE_NAME ] "through" point_operand ")"
                   | "(" [ CREASE_NAME ] "perp" line_operand ")"
object            := point_operand | line_operand
```

```
(align (.a onto .c))                       ; axiom 2
(align (through .a) (through .b))          ; axiom 1
(align (perp --l) (through .p))            ; axiom 3
(align (.p onto --l) (through .q))         ; axiom 6
(align (.p onto --l) (perp --m))           ; axiom 4
(align (--l onto --m) toward .p)           ; axiom 5, with its selection
(align (.p onto --l) (.q onto --m))        ; axiom 7
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

The fragments of the sections above, collected. Rules not yet stated in a
section of this document are in `SPECIFICATION.md`, Appendix A.

```
program           := "paper" "square" stmt*
stmt              := write_stmt | bind_stmt | def_stmt | apply_stmt | export_stmt

write_stmt        := verb [ CREASE_NAME "=" ] item*
verb              := "mark" | "fold" | "reverse" | "flatten" | "flip"
item              := "(" item_body ")"
item_body         := fold_item | reverse_item | mark_item | flatten_item

fold_item         := axis
                   | "moving" flap_operand
                   | "up" "to" flap_operand
                   | "mountain"
                   | ( "over" | "under" ) flap_operand
reverse_item      := axis
                   | "moving" flap_operand
                   | "outside"
mark_item         := axis
                   | "on" flap_operand
                   | "between" point_operand point_operand
                   | "at" point_operand
                   | "mountain" | "valley"
flatten_item      := line_operand [ "mountain" | "valley" ]
                   | flap_operand "over" flap_operand
                   | "staying" flap_operand
                   | "toward" point_operand
axis              := construction_body | line_operand

construction_body := "align" CREASE_NAME* alignment+ [ "toward" point_operand ]
                   | prose_axiom
alignment         := "(" [ CREASE_NAME ] object "onto" [ CREASE_NAME ] object ")"
                   | "(" [ CREASE_NAME ] "through" point_operand ")"
                   | "(" [ CREASE_NAME ] "perp" line_operand ")"
object            := point_operand | line_operand

flap_operand      := point_operand | line_operand | "#[" point_operand+ "]"
```

## References
