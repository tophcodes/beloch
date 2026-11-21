---
id: BEP-0084
title: "A program unites no bundles"
date: 2026-11-21
status: accepted
issue: tophcodes/beloch#352
reference:
  - reference/beloch-operands#filters
  - reference/beloch-grammar#operands
  - reference/beloch
  - reference/beloch-writes#fold
  - reference/beloch-errors
amends: []
superseded-by: null
---

# BEP-0084: A program unites no bundles

## Summary

The read `[--l --m …]`, which united the pieces of every listed bundle
into one bundle, leaves the language. A `[` without a sigil before it is
an error, `` a bare [ opens no read ``, whose hint names the three
bracket forms that remain. A bundle that spans several creases still
arises in one place, the crease of a `flatten` with an even number of
rays, and the program reaches it through the name the flatten binds.

## Example

Three bracket forms select one thing of the sort their sigil names, the
one that lies on every listed operand: `.[--l --m]` selects the point
both creases pass through, `--[.p .q]` the crease through both points,
and `#[.p .q]` the flap that holds both. The union looked like the first
of them and collected every piece instead of selecting one thing. On a
square with both diagonals and the vertical midline `--m` marked, the
two lines below differ in one character:

```beloch
.o = .[--ac --bd --m]      ; the center: the one point on all three
.o = [--ac --bd] * --m     ; also the center: both diagonals, met with --m
```

The kernel accepts the second line and computes the same point, so a
reader of the program cannot tell from the result whether its author
meant a union or dropped the `.` of a meet.

No program in `examples/` uses the union. One kernel test did, to build
a bundle that crosses a line twice, and the reference used it twice: to
show that `fold` refuses a bundle of several creases, and in one sentence
of the output clause. A crease scored through two layers crosses a line
twice as well, and the bundle a `flatten` binds shows the refusal.

## Rule

In [[reference/beloch-operands#filters]] and
[[reference/beloch-grammar#operands]] the union is gone; the filters `&`
and `\` keep and drop the pieces of one bundle, and
[[reference/beloch]] lists them without the union. In
[[reference/beloch-writes#fold]] the axis `(--d)` names one crease, and
the bundle of a `flatten` is refused with
`` --x is a bundle, not a single crease ``. [[reference/beloch-errors]]
lists the error of a bare `[`.

## Alternatives considered

- **Give the union an operator**, `--l | --m`, beside `&` and `\`. It no
  longer looks like a meet, but no program needs it, and a read without
  a use case is one more form to document and test.
- **Give the union a sigil of its own.** The same objection holds, and
  every sigil in use already names the sort of the result.
