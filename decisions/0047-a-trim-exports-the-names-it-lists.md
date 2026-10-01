---
id: "0047"
title: "A trim exports the names it lists"
date: 2026-10-01
status: accepted
issue: tophcodes/beloch#156
---

# 0047: A trim exports the names it lists

## Context

A shape ends with `trim to` a flap, and every name of its body that lies on
the flap reaches the trimmed sheet under the name the body gave it (ADR
0046). The body opens a square of its own, and that square binds `.a` to
`.d` and `--ab` to `--da`. A rectangle trimmed from the lower part of a
square keeps `.a` and `.b`, while its two upper corners lie where `.c` and
`.d` never were, and the body cannot bind a new point as `.c` while the
square's `.c` is bound. A reader who opens `paper rectangle 2 1` expects the
corners `.a` to `.d` and the edges `--ab` to `--da` of a square, and the
shape cannot give them.

## Decision

**A trim may list the names it exports.** The list follows the flap
operand, in braces, with the entries of `export`
(SPECIFICATION.md §5a.5): a name of the body with its sigil, optionally
`as` a landing name with its sigil.

```
shape rectangle(w h) {
  paper square w
  .p = free on --da from .a by h
  fold (perp --da through .p) (moving .d) as --top
  .q = --top * --bc
  trim to .a { .a .b .q as .c .p as .d --ab --bc --top as --cd --da }
}
```

- With a list, exactly the listed names reach the trimmed sheet, under
  their landing names. Without one, every name of the body that lies on the
  flap does, as ADR 0046 states.
- An entry takes no `!`. The trimmed sheet is a fresh namespace, so a
  landing name may be one the body used for something off the flap, as
  `.q as .c` does.
- A listed name that does not lie on the flap is an error, as is a temp in
  the list, which `export` refuses as a source too, and two entries that
  land on the same name.

## Alternatives considered

- **Ordinal corner selectors**, `vertex n from .a` for the corners of the
  outline counted from a named one, as the draft of paper as a value had
  them. Deferred: they name corners and nothing else, and they pay off for
  shapes with many corners, which the standard library does not hold yet.
- **Rebinding the square's names in the body** with `!`. Rejected: the body
  still needs the square's `.c` and `.d` while it folds, and a body name
  then means two points over its course.
- **Renaming after opening the sheet**, in the program. Rejected: every
  program that opens a shape would repeat the renaming the shape's author
  knows.

## Consequences

- The grammar's `shape_def` ends with an optional export list, and the
  language page states the list and its errors.
- The standard library's rectangles export the corners `.a` to `.d` and the
  edges `--ab` to `--da`, and the triangle exports `.a`, `.b`, `.t` and its
  three sides.
