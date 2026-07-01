# Design: rustc-style diagnostic error rendering

**Date:** 2026-07-01
**Status:** approved (brainstorming) — pending implementation plan

## Problem

A `Beloch_error` prints as one terse line:

```
examples/cube-root.bel:28:1: lines are identical
```

No source context, no pointer to the offending operation, no visual anchor. For
a spatial language where the error is about a specific fold/operand, this is hard
to read. We want a source-context diagnostic: line numbers, a few lines of prior
context, and a caret underline under the offending span, with the message.

This is a **mini ad-hoc slice** — improve how *all* existing errors render, using
the spans they already carry. Not the coincidence-provenance backtrace ("since
line N …"), which is deferred.

## Decisions made during brainstorming

| Question | Decision |
|---|---|
| What | Render every `Beloch_error` as a source-context block (header, location, gutter, ~3 prior context lines, error line, caret underline, message). |
| Spans | Use the spans errors already carry. No per-error-site span surgery. |
| Precision | Inline-construction errors carry operand spans (caret lands exactly on `--(.a .b)`); axiom degeneracies carry the statement span (caret underlines the whole `map … onto …`); messages already name the operands via `pstr`/`lstr`. |
| Color | Out of scope (needs TTY detection / `unix` dep) — fast-follow. |
| UTF-8 columns | `pos_cnum - pos_bol` is a byte offset; exact for ASCII `.bel`, slight caret drift under multibyte comment text — accepted, fast-follow. |
| Backtrace | Coincidence-provenance ("coincided since line N", coordinates) — deferred to a later slice. |

## Data available (verified)

- `lib/error.ml`: `type span = Lexing.position * Lexing.position` — start AND end,
  each with `pos_fname`, `pos_lnum` (line), `pos_cnum` (absolute byte offset),
  `pos_bol` (offset of line start). Enough for exact line, column, and length.
- `bin/main.ml:27-29` is the single catch site: `Error.Beloch_error (span, msg)`
  → currently `Printf.eprintf "%s: %s\n" (span_to_string span) msg`.
- Error messages already embed operand names (`pstr`/`lstr`), e.g. "`.a` and `.b`
  are at the same place …".

## Architecture

### New module `lib/diagnostic.ml` (one purpose: render a diagnostic)

```
val render : source:string -> span:Error.span -> msg:string -> string
```

- `source` is the full source text of the file (the CLI already reads it).
- Derive `(line, col)` for start and end from the two `Lexing.position`s.
- Slice the source into lines; take up to 3 lines before the start line plus the
  start line (and, if the span is multi-line, up to the end line — but statements
  are single-line, so the common path is one error line).
- Build a **gutter**: right-aligned line numbers, a ` | ` separator, matching the
  width of the largest line number shown.
- Build the **caret line**: spaces up to the start column, then `^` repeated for
  the span width (end col − start col, min 1), followed by ` ` + `msg` as the
  underline label. If the span crosses lines, underline from start col to the end
  of the start line.
- Compose:

```
error: <msg>
  --> <file>:<line>:<col>
   |
 N | <context line>
 N | <context line>
 N | <error line>
   |     ^^^^^^ <msg>
```

The module is pure (string in, string out) — unit-testable without a filesystem.

### Wiring `bin/main.ml`

The CLI already has the source path/text. In the `Beloch_error` arm, read the
source (via `span`'s `pos_fname`, or the text it already loaded) and print
`Diagnostic.render` to stderr instead of the one-liner. Keep `exit 1`. The
`Sys_error` arm is unchanged. If the source can't be read (e.g. stdin), fall back
to the current one-line format.

## Edge cases

- **Top of file:** fewer than 3 prior lines → show what exists.
- **Multi-line span:** underline start col → end of start line (statements are
  single-line, so this is a rare graceful path).
- **Empty span (start == end):** caret width 1.
- **Missing/unreadable source:** fall back to `span_to_string`-style one-liner.
- **Tabs:** rendered as-is; caret column counts characters (accepted minor drift).

## Testing

- **Unit (`lib/diagnostic.ml` via alcotest in `tests/`):** feed a known multi-line
  source string + a span + a message; assert the output contains `error: <msg>`,
  the correct gutter line number for the error line, a caret line whose `^` starts
  at the expected column and has the expected width, and the expected number of
  context lines. A top-of-file case (fewer context lines). A multi-column span
  case.
- **e2e:** run a degenerate `.bel` (e.g. `through .a .a`) through the CLI; assert
  stderr contains the block (`error:`, `-->`, a caret line).

## Out of scope

- Coincidence-provenance backtrace ("coincided since line N", coordinate deltas).
- ANSI color / TTY detection.
- Finer operand spans for the axiom-degeneracy sites (caret currently underlines
  the whole operation there; the message names the operands).
- UTF-8 column correctness for multibyte comment text.
