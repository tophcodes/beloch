---
id: "0035"
title: "A warning reports a program that runs, in the shape of an error"
date: 2026-09-27
status: accepted
issue: tophcodes/beloch#59
---

# 0035: A warning reports a program that runs, in the shape of an error

## Context

The language reports a rejected program as a span, a message and an optional
hint ([[decision/0028]]), and it has no other kind of report. Some programs contain an
item that changes nothing: the program means the same without it. [[decision/0031]]
names the first such item, a `moving` that agrees with the fold's `toward`
and names the flap the fold would take anyway. Failing the program would
reject a program that means what its author wrote. Saying nothing leaves the
author believing the item does something. The specification marks more such
items as lint candidates: a `staying` that restates the stayer the
convention picks, a `toward` on a `flatten` whose geometry is already
unique, and an `over` that holds in every surviving stacking.

Reports reach the author through four readers today. The command line
prints a rustc-style block on standard error and exits with 1. The FOLD
document carries `beloch:error`, and only with `--trace`, because a program
that fails without it writes no file. The browser evaluator answers the
playground with the FOLD or with the error and its whole span. The
playground underlines the offending word and shows the message and the hint
beneath it. The VS Code extension highlights syntax only, and the language
server is reserved and unbuilt.

## Decision

**A warning is a report on a program that runs to its end.** It has the
shape of an error ([[decision/0028]]): a span, a message and an optional hint. The
span covers the item the warning is about, the message states what that
item does to the program, and the hint states what to write instead. A
warning changes neither the program's result nor the exit code.

**A warning names only what the author can drop or rewrite without
changing what the program means**, and its hint says how. Following the
hint silences the warning. Warnings have no codes, and no annotation or
flag suppresses them.

**Every reader carries a warning as it carries an error:**

- The FOLD document has `beloch:warnings`, a list in the order of the
  statements, each entry with the `message`, the `hint`, the `span` and the
  `statement` index as in `beloch:error`. The field appears with and
  without `--trace` and is absent when the list is empty.
- The command line prints each warning on standard error in the block it
  prints for an error, headed `warning:`, with the hint as the `help:` line,
  and exits with 0. When `beloch fold --trace` runs a program that fails,
  the warnings of the statements before the failing one come first, then
  the error. `beloch fold --watch` and `beloch render` of a `.bel` file
  print warnings the same way.
- The browser evaluator's answer to a program that runs carries
  `warnings`, each with the message, the hint and the whole span, start and
  end.
- The playground shows a warning where it would show an error: the word
  underlined, a row with the message and a row with the hint, in a color
  of its own, and it draws the program's result as usual.
- A language server reports a warning with the severity Warning and the
  same span, and puts the hint where it puts the hint of an error.

**The first warning is the redundant `moving`.** A fold that names both
`toward` and `moving` warns on its `moving` item when the selection without
`moving` keeps the same candidate and folds over the same side. The hint
says to drop the item. The warning is defined by that result, so it follows
whatever the selection does without `moving`. A `moving` in a fold without
`toward` does not warn, even where it names the side the default would take.

## Alternatives considered

- **Warnings only with `--trace`.** The trace records what the selection
  weighed on the way to the result. A warning is about the program as
  written, and a program with warnings writes its file anyway, so a reader
  of that file would never learn of them.
- **Warnings on the entries of `beloch:statements`.** They would sit next to
  the statement they concern, but a reader would have to walk every entry
  to find out whether there are any.
- **Warnings on standard error only.** The playground and every program that
  reads a FOLD file would need a channel of their own.
- **A flag that turns warnings into failures**, such as `--deny-warnings`.
  No user needs one yet, and one can be added without revisiting this
  record.
- **A code per warning, and annotations that suppress one.** Under the rule
  above, the author can silence every warning by following its hint. Codes
  become necessary only for a warning that asks for a judgment, and this
  record admits none.
- **A warning with a message and no hint.** The hint is what the author
  acts on, and the shape of [[decision/0028]] carries it at no cost.
- **Warning on a `moving` without `toward` that names the default side.**
  The default side is the side of the first object of the first alignment
  ([[decision/0031]]). A `moving` that names it states in the write what the order
  inside the alignment decides otherwise, and it keeps the side when
  someone reorders the alignment.

## Consequences

- The kernel collects warnings while it evaluates, alongside the statement
  log. A re-evaluation that reuses the result of unchanged statements
  reports their warnings again, in the command line's watch mode and in the
  playground alike.
- [[reference/fold]] gains `beloch:warnings`, and [[reference/cli]] states how
  warnings print and that they leave the exit code at 0. The browser
  evaluator's answer gains `warnings`; an answer without the field reads as
  before.
- The lint candidates in the specification become warnings when they are
  implemented, each held to the rule that a warning names something the
  author can drop or rewrite.
- The redundant `moving` depends on how the selection treats `moving`.
  Issue tophcodes/beloch#63 leaves open whether `moving` gets a stage of
  its own when several candidates remain. If it does, the warning and its
  tests change with it.
