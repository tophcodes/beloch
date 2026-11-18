---
id: BEP-0030
title: "A program has two axes, and the FOLD logs every executed statement on them"
date: 2026-09-25
status: accepted
---

# BEP-0030: A program has two axes, and the FOLD logs every executed statement on them

The architecture part of this decision is [[ADR-0066]].

Supersedes [[BEP-0026]], which logged the top-level statements only.

## Context

[[BEP-0026]] split a position in a program into two axes. The model counts
states, and a state changes with every write. The language counts statements,
and a binding moves the program without moving paper. In the opening of the
bird base, the first number is the folded state and the second counts the
statements since that state began:

```beloch
fold (map .a onto .c) as --bd             ; 1.0
reverse (map .b onto .c) as --h           ; 2.0
reverse (map .d onto .c) as --v           ; 3.0
.o = --h * --v                            ; 3.1  new point, same paper
--mid = (through .c .o)                   ; 3.2  new line, same paper
.sr = --ab * --h                          ; 3.3  new point, same paper
reverse (map .sr onto --mid through .c)   ; 4.0
```

A stepper walks the first axis and shows a new drawing at every stop. An
editor walks the second and can say at `3.1` that `.o` appears, which the
first axis has no stop for.

## Decision

**A position in a program is a pair,** the state it stands in and how far
the program has moved since that state began, written `2.3` for a reader.
The FOLD stores no position. One pass over the entries gives both
coordinates, since each entry carries its kind. A consumer that keeps a
position keeps the pair, because a decimal number cannot tell the tenth
statement after a state, `3.10`, from the first, `3.1`.

**The first axis counts writes.** Every `fold`, `reverse`, `flip`, `flatten`
and `mark`. A score changes the paper as a fold does, and the axis stops at
both. The difference that an effective write moves the state and a score
leaves it standing up to refinement ([[BEP-0025]]) stays inside the axis, where a
renderer needs it: a fold crossfades between two placements, a mark draws on
the placement already there.

**The second axis counts executed statements,** all of them, in the order
they run. A statement inside a `def` body counts once for every `apply` that
runs it, and never at the `def`, which runs nothing.
