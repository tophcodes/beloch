---
id: BEP-0083
title: "A name with two dashes holds a crease"
date: 2026-11-21
status: accepted
issue: tophcodes/beloch#354
reference:
  - reference/beloch-names
  - reference/beloch
  - reference/beloch-operands#lines
  - reference/beloch-writes
  - reference/beloch-constructions
  - reference/model#def-line
  - reference/fold
amends: []
superseded-by: null
---

# BEP-0083: A name with two dashes holds a crease

## Summary

A name with `--` holds a crease or a paper edge, and nothing else. `=`
binds no construction: `--l = (map .a onto .c)` is an error,
`` --l = (…) binds no crease ``, with the hint
`` score it with mark (…) as --l ``. A construction stands only inside the
write that reads it. A line that a later statement aligns to is scored
first, in full or with `(at …)` where it is to subdivide nothing. `=` still
binds a point, and a selection from the creases and edges already there,
`--e = --ac & .o`.

A selection passed to a line parameter of a definition holds the material
it selects, as the selection does where it is written. Before this record
the kernel froze such an argument to its table line, and the body could
then not meet it, filter it or fold along it.

## Example

The crane bound the center line of its preliminary base with `=` and
folded the side corners onto it:

```beloch
--mid = (through .c .o)                       ; before
mark (through .c .o) as --mid                 ; after
flatten (fan (--s1 & .sr) (map .sr onto --mid through .a valley) as .e1)
        …
```

A folder who lays a corner onto a line sees that line on the paper: a
crease, an edge or a folded edge. An unscored line is a value the program
knows and the paper does not show. In the crane, the flapping bird and the
traditional frog the center line lies on the diagonal creased before, and
scoring it adds no line to the crease pattern. In the cicada and the
samurai helmet the bound line ran where nothing was creased; it now
appears in their crease patterns, as it does on a sheet folded by hand.

## Rule

[[reference/beloch-names]] states which names `=` binds and the error of a
bound construction. [[reference/beloch]] tells the sorts apart by the
source alone: a construction is a line, and a name with `--` holds a crease
or a paper edge. [[reference/beloch-operands#lines]],
[[reference/beloch-writes]] and [[reference/beloch-constructions]] drop the
line bound by `=`, and a construction carries its `toward` and `moving` as
items of the write that reads it. [[reference/model#def-line]] states that
a name holds a crease, which a fold bends, and [[reference/fold]] drops the
entry of a bound line from `beloch:named_lines`.

A line parameter of a definition holds a crease when its argument is a
crease name, and the selected material when its argument is a selection.
No name holds a bare line, so the errors of the form
`` --l is a line; <slot> needs a crease `` are gone.

## Alternatives considered

- **Keep the line bound by `=`.** A program could then align to a line
  that no folder can see, and every slot that wants material needs a
  second check of the name's sort.
- **Let a name stand for its construction, evaluated where it is used.**
  The name would carry a line in one slot and fail in the next, which is
  the two sorts under one sigil this record removes.
- **Keep freezing a selection argument to its table line.** One way to
  hold a bare line would remain, and with it the errors of a line where a
  crease is wanted.
