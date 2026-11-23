## Why

A program can hold an item that changes nothing: a `moving` that names the
side the fold moves anyway means the same program without it. The kernel
knows only errors, so it can reject such a program, which means what its
author wrote, or say nothing, which leaves the author believing the item
does something. A warning reports the item and lets the program run.

## What Changes

- A warning reports an item of a program that runs, in the shape of an
  error: a span, a message and a hint. It changes neither the folded result
  nor the exit code, and following its hint silences it.
- The first warning is a `moving` that a fold with `toward` does not need.
- The FOLD file carries `beloch:warnings`. The command line, the browser
  evaluator, the playground and a language server show a warning where they
  show an error.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `diagnostics`: the warning, its first case and the field that carries
  warnings in the FOLD file.
- `architecture`: the command line and the browser readers carry a warning
  as they carry an error.

## Impact

The kernel's evaluator and emitter, `beloch fold` and `beloch render`, the
browser evaluator and the playground. The pages `BELOCH-ERRORS.md`,
`FOLD.md` and `CLI.md` under `docs/reference/` explain the rules.
