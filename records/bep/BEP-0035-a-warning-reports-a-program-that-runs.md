---
id: BEP-0035
title: "A warning reports a program that runs, in the shape of an error"
date: 2026-09-27
status: accepted
issue: tophcodes/beloch#59
---

# BEP-0035: A warning reports a program that runs, in the shape of an error

The architecture part of this decision is [[ADR-0067]].

## Context

The language reports a rejected program as a span, a message and an optional
hint ([[ADR-0028]]), and it has no other kind of report. Some programs contain an
item that changes nothing: the program means the same without it. [[BEP-0031]]
names the first such item, a `moving` that agrees with the fold's `toward`
and names the flap the fold would take anyway. Failing the program would
reject a program that means what its author wrote. Saying nothing leaves the
author believing the item does something. The specification marks more such
items as lint candidates: a `staying` that restates the stayer the
convention picks, a `toward` on a `flatten` whose geometry is already
unique, and an `over` that holds in every surviving stacking.

## Decision

**A warning is a report on a program that runs to its end.** It has the
shape of an error ([[ADR-0028]]): a span, a message and an optional hint. The
span covers the item the warning is about, the message states what that
item does to the program, and the hint states what to write instead. A
warning changes neither the program's result nor the exit code.

**A warning names only what the author can drop or rewrite without
changing what the program means**, and its hint says how. Following the
hint silences the warning. Warnings have no codes, and no annotation or
flag suppresses them.

**The first warning is the redundant `moving`.** A fold that names both
`toward` and `moving` warns on its `moving` item when the selection without
`moving` keeps the same candidate and folds over the same side. The hint
says to drop the item. The warning is defined by that result, so it follows
whatever the selection does without `moving`. A `moving` in a fold without
`toward` does not warn, even where it names the side the default would take.

## Alternatives considered

- **A code per warning, and annotations that suppress one.** Under the rule
  above, the author can silence every warning by following its hint. Codes
  become necessary only for a warning that asks for a judgment, and this
  record admits none.
- **A warning with a message and no hint.** The hint is what the author
  acts on, and the shape of [[ADR-0028]] carries it at no cost.
- **Warning on a `moving` without `toward` that names the default side.**
  The default side is the side of the first object of the first alignment
  ([[BEP-0031]]). A `moving` that names it states in the write what the order
  inside the alignment decides otherwise, and it keeps the side when
  someone reorders the alignment.

## Consequences

- The lint candidates in the specification become warnings when they are
  implemented, each held to the rule that a warning names something the
  author can drop or rewrite.
- The redundant `moving` depends on how the selection treats `moving`.
  Issue tophcodes/beloch#63 leaves open whether `moving` gets a stage of
  its own when several candidates remain. If it does, the warning and its
  tests change with it.
