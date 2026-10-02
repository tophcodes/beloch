---
title: Annotations
description: What a program tells its reader beyond the geometry, from step groups and instruction sentences to the annotations an output library owns.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

An annotation tells a reader of the program something the geometry does not
contain: which folds a diagram shows as one step, the sentence that tells
the folder what to do, the name a reader knows a corner by, how the model is
turned on the page. It never changes the geometry. A program with its
annotations removed evaluates to the same FOLD without the annotations, and
the evaluator passes them into the FOLD unchanged (ADR 0029).

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

## The vocabulary

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

The orientation holds until the next `@orient`. It turns the drawing of
the state its statement starts from and of every later state by one
rotation, the one fixed on that first state. The centroid of the outline is
the centroid of the area the folded state covers on the table, each point
counted once however many layers lie on it. An output turns its
drawing; the frames of the FOLD stay where the evaluator put them.

## Annotations of an output

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
@say "Reverse-fold the right side corner to the center line."
@yr:hold .o
reverse (map .sr onto --mid through .c)
```

::: {.open #open-annotation-say-lines name="a sentence over several lines"}
`TEXT` ends with its line, so a long sentence makes a long line. Whether
consecutive `@say` lines join into one sentence waits for a program that
needs it.
:::
