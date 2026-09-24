---
id: "0028"
title: "An error carries its hint apart from its message"
date: 2026-09-24
status: accepted
---

# 0028: An error carries its hint apart from its message

## Context

The evaluator reports every rejected program as one span and one string. Many
of those strings do two jobs. They say what is wrong with the program, and
then, after a semicolon or in parentheses, they say what the author can write
instead: `--x is bent by a fold; narrow it to one piece with &, e.g. --x & .p`,
or `` count (hint: use `fold` for n = 2) ``. About forty messages across the
core carry such a suggestion, each in its own wording and punctuation.

Two readers want the halves apart. The command line prints a rustc-style
block, which has a place for a help line under the caret. The playground
shows a failed run inside the code: the offending word underlined, a caret row
with the message, and a quieter row below it with what to do. Neither can find
the suggestion in the string without guessing at its punctuation, and a guess
breaks with the next message someone writes.

The playground also needs to know where the offending word ends. The core
knows every span's start and end, and the browser evaluator's answer carries
only the start.

## Decision

**A rejected program is reported as a span, a message and an optional hint.**
The message states what is wrong, in terms of the program as written. The hint
states one thing the author can write instead, and may quote code. An error
without a useful suggestion has no hint.

Every reader carries both halves to its reader:

- the command line prints the hint as a `help:` line under the caret line;
- the browser evaluator's answer carries the message, the hint and the whole
  span, start and end;
- the playground shows the message in the caret row and the hint in the row
  beneath it.

No message carries a suggestion of its own. The existing suggestions move into
hints in the same change that introduces them, and the error table in
`spec/SPECIFICATION.md` quotes message and hint in separate columns.

## Alternatives considered

- **Split the string in the reader**, at the first semicolon or at `(hint:`.
  Each message would have to keep the punctuation the splitter expects, and
  nothing checks that it does.
- **A list of notes and helps per error**, as rustc has. No message so far
  needs more than one suggestion, and one optional hint is a strict subset
  that can grow into a list later.
- **Move suggestions as their messages are next touched.** The two styles
  would live side by side for as long as any old message survives, and the
  playground would show some suggestions in the caret row and others beneath
  it.

## Consequences

- Every place that raises an error or matches on one changes once. The
  message tests and the spec table change with them.
- Errors that name something unknown can hint at what is in scope, which is
  what the playground design shows for a mistyped crease name.
- The protocol between the browser evaluator and the playground gains the
  hint and the span's end; an answer without them still reads as before.
