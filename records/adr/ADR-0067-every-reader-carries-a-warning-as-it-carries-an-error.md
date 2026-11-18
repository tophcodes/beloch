---
id: ADR-0067
title: "Every reader carries a warning as it carries an error"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#59
---

# ADR-0067: Every reader carries a warning as it carries an error

This record holds the architecture part of [[BEP-0035]], which decided both kinds.

## Context

Reports reach the author through four readers today. The command line
prints a rustc-style block on standard error and exits with 1. The FOLD
document carries `beloch:error`, and only with `--trace`, because a program
that fails without it writes no file. The browser evaluator answers the
playground with the FOLD or with the error and its whole span. The
playground underlines the offending word and shows the message and the hint
beneath it. The VS Code extension highlights syntax only, and the language
server is reserved and unbuilt.

## Decision

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

## Consequences

- The kernel collects warnings while it evaluates, alongside the statement
  log. A re-evaluation that reuses the result of unchanged statements
  reports their warnings again, in the command line's watch mode and in the
  playground alike.
- [[reference/fold]] gains `beloch:warnings`, and [[reference/cli]] states how
  warnings print and that they leave the exit code at 0. The browser
  evaluator's answer gains `warnings`; an answer without the field reads as
  before.
