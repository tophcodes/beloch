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
reflects it. `SPECIFICATION.md` remains the reference for the concrete
grammar and every keyword; this document explains the shape behind it and is
where changes to that shape are decided first.

The language refers to the model by statement ids and to the specification
by section. The model does not refer to the language.

## A program is a path

A program starts from a sheet ([def-sheet](/model/#def-sheet)) and applies
operations one after another. Each operation takes the current flat folded
state ([def-flat-state](/model/#def-flat-state)) and either produces the next
one or fails with a reason. The program's meaning is the finite sequence of
states it passes through; its result is the last state.

## Reads and writes

One law organises the surface syntax (`SPECIFICATION.md` §4.10): an
operation that changes the state is a keyword verb, sequenced in program
order; an operation that only computes something from the current state is
an operator, a bracket, or a motion, and may appear anywhere a value is
needed.

In the terms of the model, the writes are the partial functions from states
to states, and the reads are functions from a state into the value sorts. A
read never fails silently: where the state has no answer, such as a point
that lies on no face or a construction with two solutions and no way to pick
one, the read is an error.

**Sorts.** Point, line, flap, and bundle (a set of crease segments); each a
value computed in the current state and carried in paper coordinates, so it
survives later folds. Their definitions belong to the model's section on
values, which is not yet written.

**Writes.** `mark`, `fold`, `reverse`, `flatten`, `flip`. Each is a partial
function on states with its own domain; the domain is the language's notion
of a safe operation, and the model states it. Their definitions belong to the
model's section on operations, which is not yet written.

**Reads.** Motions (`map … onto …`, `through`, `perp`, the Huzita-Justin
constructions), selectors (`#[…]`, `*`, `--[…]`, `free on`), and the filter
operators (`&`, `\`, `[…]`), which form a Boolean algebra on the segments of
a bundle: intersection with an incidence predicate, difference, union.

## Arguments of writes

A write takes, besides the state, a small fixed set of arguments: the axis (a
line or an existing crease), the anchor (`moving`), the scope (`up to`), the
placement (`over`, `under`), the direction (`mountain`), a solution choice
(`toward`), and for `reverse` the side (`outside`). They narrow the domain of
the write or select among its solutions. None of them changes the state on
its own.

::: {.open #open-argument-syntax name="marking the arguments of writes"}
The arguments above are written as bare keywords after the verb, in the same
visual register as the verbs themselves, and readers confuse the two. The
syntax should mark them as arguments of the verb they belong to. The shape of
that marking is open, and it should be decided from the model's operation
signatures once those are written, so that every argument slot in the syntax
corresponds to a parameter of a partial function and to a slot a graphical
editor could fill by selection.
:::

## What this document will grow into

One section per sort and one per write, each pointing at the model statement
that defines it and at the specification section that spells its syntax,
with a worked example rendered live on this page. That is the material a
graphical editor binds its actions to.
