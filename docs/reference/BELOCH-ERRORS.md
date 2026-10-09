---
title: Errors
description: How a rejected program is reported, and the catalog of the errors a program meets, each with the message the kernel prints, its hint, and the page that states the rule it breaks.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

Every error is a compile error: a program that breaks a rule is rejected
as a whole, and no output is written for it. A rejected program is
reported as a span, a message and an optional hint ([[decision/0028]]).
The message states what is wrong in the terms of the program as written,
and the hint states one thing the author can write instead; an error
without a useful suggestion has no hint. This page states how an error is
reported and lists the errors by the construct that raises them, with the
message as the kernel prints it and the page that states the rule.

## Reporting

A file is parsed whole before any statement runs, and its annotations are
checked with it ([[reference/beloch-annotations]]), so a syntax error is
reported before the error of any statement, wherever in the file it
stands. Then the statements run in program order, and the first statement
that fails ends the run: an error in a later statement stays unreported
until the earlier one is fixed. The span covers the statement, or the
operand the kernel can blame on its own, such as an undefined name or a
meet.

The command line prints the message with the source line and a caret
under the span, prints the hint as a `help:` line beneath it, and exits
with 1 ([[reference/cli#beloch-fold]]).

A program on a page of the language that ends in `; expect error "…"`
fails with a message that contains the quoted text, and the build checks
that it does; the programs below are such programs. In a message, a name
in angle brackets stands for what the program wrote in that place.

## Syntax

| message | hint |
|---|---|
| `syntax error` | |
| `unexpected character "<c>"` | |
| `a text runs to its closing quote on the same line; \" and \\ are its only escapes` | |

The parser reports the place where it stopped, and the grammar it holds
the program to stands on [[reference/beloch-grammar]]. A text is the
quoted argument of an annotation ([[reference/beloch-annotations]]). This
program lacks the closing parenthesis of its construction and stops at
the end of its second line with `syntax error`; it carries no tag on
this page, because every tagged program is also held to the grammar:

```
paper square
mark (through .a .c
```

## Names

| message | hint |
|---|---|
| `undefined point .<name>` | `in scope: <names>` |
| `undefined crease --<name>` | `in scope: <names>` |
| `undefined instance $<name>` | |

A reference to a name no statement bound
([[reference/beloch-names#names]]). The hint lists the names of that kind
in scope, sorted, at most 12 before an ellipsis; an instance gets no
hint. The errors of a second binding, of a definition, an application and
an export stand on [[reference/beloch-names]].

```{.bel .frag}
mark (through .a .x)

; expect error "undefined point .x"
```

## Two points at one place

| message | hint |
|---|---|
| `<p> and <q> are at the same place, so there is no line through them` | |
| `<p> and <q> are already at the same place` | |

Axiom 1, `through <p> <q>`, and axiom 2, `map <p> onto <q>`, take two
points that lie apart. The points are compared where they lie in the
current state, so the error meets the same name written twice, and two
material points a fold has brought together (`SPECIFICATION.md` §4.1 and
§4.2):

```{.bel .frag}
fold (map .b onto .a) (moving .b)
mark (through .a .b)

; expect error "at the same place"
```

## The meet

| message | hint |
|---|---|
| `<l> and <m> are parallel; they have no common point` | |
| `<l> and <m> have no common point; the lines they lie on cross beyond their marks or off the paper` | |
| `the meet of <l> and <m> is ambiguous: they cross at <n> points, <the points>` | `narrow an operand with & so that one crossing remains` |
| `<l> and <m> overlap from <p> to <q>; a meet needs a single common point` | |
| `<l> and <m> lie on one line; a meet needs a single common point` | |

The meet, `--l * --m` and `.[--l --m …]`, is the one paper point its
operands have in common ([[reference/beloch#reads-and-writes]],
`SPECIFICATION.md` §4.3). It fails with no common point, with 2 or more,
and when the operands share a stretch of paper or lie on one boundary
line; the ambiguous case lists the points in paper coordinates.

```{.bel .frag}
.x = --ab * --cd

; expect error "are parallel"
```

The programs of this page that need the two diagonals start from this
sheet:

```{.bel .prelude name=diagonals}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
```

A crease scored through several layers lies on several paper lines, so a
line that crosses it may cross it twice:

```{.bel .frag prelude=diagonals}
fold (--bd) (moving .a)
.m = free on --bc from .b at 3/4
mark (perp --bc through .m) as --h    ; through both layers
.x = --h * --ac

; expect error "they cross at 2 points"
```

## Selection

| message | hint |
|---|---|
| `<construction> is ambiguous: <n> folds carry it out, all landing on the paper` | `add (toward .x) or a heading` |
| `<construction>: no crease lands on the paper, so there is no fold to make` | |
| `no fold of <construction> carries out all its alignments at once` | |

A construction of axiom 5, 6 or 7 may have several candidate lines, and
`toward`, `moving` and `heading` select among them
([[reference/beloch-constructions#selection]]). The selection fails when
no candidate is left and when several are; the page states every message
of the selection, with the stage that raises it.

```{.bel .frag prelude=diagonals}
mark (map --ac onto --bd)

; expect error "is ambiguous: 2 folds"
```

## Folds

| message | hint |
|---|---|
| `` this fold needs `moving .p` to choose the side `` | |
| `moving <p> names no side of the fold line of <construction>` | |
| `` `up to` a crease needs `moving` to walk inward from `` | `name the flap with a point instead` |

A fold along a line construction, `fold (through …)` or `fold (perp …)`,
and a fold along existing material, `fold (--c)`, derive no side from
their line: `moving` or `toward` names it, and a `moving` point on the
axis names none. A fold whose `up to` names a crease walks inward from
its moving flap, and the axiom 5 fold `fold (map --l onto --m)` derives
no `moving` from its construction, so it needs one written
([[reference/beloch-writes]], `SPECIFICATION.md` §4.6).

```{.bel .frag}
fold (through .a .c)

; expect error "needs `moving .p`"
```

```{.bel .frag}
fold (map .b onto .a) (moving .b) as --v
fold (map --ab onto --v) (up to --v)

; expect error "needs `moving` to walk inward from"
```

## Marks

| message | hint |
|---|---|
| `<p> is not on the mark's line` | |
| `the mark's extent needs two distinct points` | |
| `the mark's extent from <p> to <q> crosses a folded crease (it leaves its flap)` | |

The extent of a partial mark, `between <p> <q>` or `at <p>`, is cut from
the mark's line, so each of its points lies on that line, and `between`
takes two points apart. An extent is written onto one flap when `on`
names it, and it stays on that flap: an extent that would cross a folded
crease to reach its endpoint is an error. Without `on`, the mark writes a
piece onto every flap under the extent, each clipped to its flap, and no
extent crosses a crease ([[decision/0036]], [[reference/beloch-writes]],
`SPECIFICATION.md` §4.6).

```{.bel .frag}
mark (through .a .c) (between .a .b)

; expect error "is not on the mark's line"
```

```{.bel .frag prelude=diagonals}
.o = --ac * --bd
fold (map .a onto .o) (moving .a) as --f   ; the corner .a folds onto the center
.q = free on --ac from .a at 1/8            ; on the folded corner
mark (--ac) (between .q .c) (on .c)         ; .q lies on the corner, .c on the base

; expect error "crosses a folded crease"
```

## Stated elsewhere

The errors above are the ones every program can meet, from its syntax to
its first folds and marks. The errors of a construct's own items stand on
its page, beside its syntax and its example:

- sheets, shapes, units and free points: [[reference/beloch]];
- bindings, temps, definitions, applications and exports:
  [[reference/beloch-names]];
- the constructions of axioms 5 to 7 and their selection:
  [[reference/beloch-constructions]];
- the items of a write, and `unfold`, `reverse` and `flatten`:
  [[reference/beloch-writes]]; the checks of `flatten`, `reverse` and
  `unfold`, with the message and hint each ships, stand in the kernel's
  tables ([[reference/kernel#fan]], [[reference/kernel#reverse]],
  [[reference/kernel#unfold]]);
- annotations: [[reference/beloch-annotations]].
