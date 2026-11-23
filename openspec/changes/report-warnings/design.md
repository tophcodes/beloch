## Context

The kernel reports a rejected program as a span, a message and an optional
hint, and it has no other kind of report. Reports reach the author through
four readers: the command line prints a block on standard error and exits
with 1; the FOLD file carries `beloch:error`, only with `--trace`; the
browser evaluator answers the playground with the FOLD or the error and its
whole span; the playground underlines the offending word and shows the
message and the hint beneath it. The language server is reserved and not
built.

The rules come from BEP-0035, the language part, and ADR-0067, the readers.
Their reason:

- BEP-0035: Failing a program for a redundant item rejects a program that
  means what its author wrote, and silence leaves the author believing the
  item does something; a hint that silences the warning makes codes and
  suppression unnecessary.
- ADR-0067: A program with warnings writes its file anyway, so a warning
  only on standard error or only under `--trace` would never reach a reader
  of the FOLD or the playground.

## Goals / Non-Goals

**Goals:** the warning as a kind of report, its first case, and every
reader carrying it.

**Non-Goals:** the other items the model marks as candidates for a warning,
a `staying` that restates the stayer the convention picks, a `toward` on a
`flatten` whose geometry is already unique and an `over` that holds in every
surviving stacking. Each becomes a warning in a change of its own, held to
the rule that a warning names something the author can drop or rewrite.

## Decisions

- **A warning has the shape of an error.** It reuses the span, the message
  and the hint, so every reader of an error reads a warning without a new
  layout.
  - Rejected: a warning with a message and no hint; the hint is what the
    author acts on, and the shape of an error carries it at no cost.
- **No codes, no suppression.** The author silences every warning by
  following its hint.
  - Rejected: a code per warning and annotations that suppress one; codes
    are needed only for a warning that asks for a judgment, and none does.
- **The redundant `moving` warns only beside `toward`.**
  - Rejected: warning on a `moving` without `toward` that names the default
    side; such a `moving` keeps the side when someone reorders the alignment
    whose first object decides the default.
- **`beloch:warnings` is one top-level list.**
  - Rejected: warnings only with `--trace`; a program with warnings writes
    its file anyway, so a reader of that file would never learn of them.
  - Rejected: warnings on the entries of `beloch:statements`; a reader would
    walk every entry to learn whether there are any.
  - Rejected: warnings on standard error only; the playground and every
    program that reads a FOLD file would need a channel of their own.
  - Rejected: a flag that turns warnings into failures; no user needs one
    yet, and one can be added later without changing this decision.

## Risks / Trade-offs

- [The redundant `moving` depends on how the selection treats `moving`] →
  if `moving` gets a stage of its own when several candidates remain, the
  warning and its tests change with it.
- [A re-evaluation that reuses the result of unchanged statements] → it
  reports their warnings again, in the watch mode of the command line and in
  the playground alike.
