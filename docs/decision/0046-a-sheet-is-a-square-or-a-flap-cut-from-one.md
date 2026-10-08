---
id: "0046"
title: "A sheet is a square of given size or a flap cut from a folded sheet"
date: 2026-10-01
status: accepted
issue: tophcodes/beloch#151
---

# 0046: A sheet is a square of given size or a flap cut from a folded sheet

## Context

The model admits any simple polygon as a sheet
([def-sheet](/model/#def-sheet)). The language offers one, `paper square`,
the unit square with its corners bound as `.a` to `.d`, and the kernel
builds that square into its starting state, its clipping and its collapse.

Some sequences need another sheet. Fisher's example of a waterbomb base
folded on the top layer alone starts from a 2:1 rectangle folded in half
[fisher1994, §5.3]. On a square folded in half the spine of the base runs
past the sub-square and joins both layers into one tip, so a program cannot
write the variant that leaves the bottom layer flat.

The language has no literal that measures a sheet. Rational numbers appear
in two places only: the position of a `free` point along a line and the
values of annotations. Every length a program uses is otherwise
constructed from points and lines of the sheet.

Whatever a second sheet shape looks like, later sheets build on it: other
polygons, several sheets in one program
([open-several-sheets](/model/#open-several-sheets)), and the circle
([open-sheet-shapes](/model/#open-sheet-shapes)).

## Decision

**A sheet is a value, and its names belong to it.** The names a sheet
binds, its corners among them, are the sheet's. A program still folds one
sheet; holding several, spelled `$$name`, and choosing the one a statement
folds, spelled `on $$name { … }`, are left to tophcodes/beloch#155, which
also decides how the output holds them.

**The one primitive sheet is a square with a side length.** The side
length is a positive rational number without a unit, written as an
integer, a fraction or a decimal. The square has its corners at $(0,0)$,
$(s,0)$, $(s,s)$ and $(0,s)$, bound as `.a` to `.d`. `paper square` is the
square of side 1, so every existing program keeps its meaning.

**Every other sheet is a shape: a folded sheet trimmed to one flap.** A
shape is a definition whose body is a program on one sheet. It opens a
sheet, folds it, and ends with a trim to a flap the body names. That flap
becomes a fresh, unfolded sheet whose outline is the flap's outline in
paper coordinates, and a program opens it the way it opens a square. A
name whose point lies on the flap keeps its meaning and its coordinate; a
name off the flap is gone. Creases marked on the flap stay on it as marks.
A flap whose outline has a hole is an error, because
[def-sheet](/model/#def-sheet) excludes holes.

```
shape rectangle(w h) {
  paper square w
  .p = free on --da from .a by h
  fold (perp --da through .p) (moving .d)
  trim to .a
}

paper rectangle 2 1
```

The spelling above is the one the language page and the grammar state.

The trim is the last statement of a shape and appears nowhere else, so the
sheet it cuts from ends with it. The body names its flap, since the layer
order of a state is partial and a bottom flap exists only when one flap
covers all others ([rem-linear-extension](/model/#rem-linear-extension)).

**A shape takes numbers, and a program writes no arithmetic.** The
parameters of a shape are numbers, named without a sigil. A number reaches
the paper as a side length or as a distance along a line from one end of
its material (`free … by`), beside the fraction of the line that `free …
at` takes. Ratios that are not rational, such as the silver rectangle's
$1 : \sqrt 2$, come from a constructed line, the way a folder makes them
from a square. The kernel holds any such coordinate exactly (ADR 0012,
0013). Which other parameter types a `def` takes stays with
tophcodes/beloch#143.

**A standard library provides the common sheets.** It is Beloch source: a
file of shapes for the rectangle, the silver rectangle, the equilateral
triangle and the others, sized by their parameters.

**Sizes carry no unit in the language; the unit belongs to the file.** A
file may declare its unit before its first statement, as a declaration of
the language. An annotation cannot carry it: removing an annotation leaves
the geometry unchanged (ADR 0029), and the unit of a loaded file scales the
sizes the loading program sees. The FOLD output writes the unit as
`frame_unit`, which the FOLD format defines for that purpose, and writes
`"unit"` when no file declares one. A program that loads another file
converts that file's sizes exactly into its own unit; every physical unit
FOLD names is a rational multiple of the millimeter. A file without a unit
takes the unit of the file that loads it, which is how the standard
library is written. Beloch has no import yet, so this rule binds the import
when it is built.

**A collapse keeps the paper within the outline it started from.** Of the
realizations a collapse finds, it keeps those whose faces lie on the table
inside the convex hull of the state before the collapse. This bound chooses
among realizations: without it the collapse finds several, and six
programs of the corpus stop as ambiguous. On a fresh sheet the hull is the
sheet itself; the bound needs no knowledge of the sheet's shape.

## Alternatives considered

- **A keyword per shape** (`paper rectangle 2 1` as an entry of the
  language). Rejected: every shape becomes part of the language, and the
  silver rectangle needs an irrational literal. A shape gives the same
  spelling from a definition.
- **A polygon given by its corners.** Rejected: it brings coordinates
  into the source, needs algebraic literals for most shapes worth folding,
  and binds no names beyond the corners it lists.
- **The silhouette of the folded state as the new sheet.** Rejected: a
  point of the silhouette stands for several paper points, so no name
  carries over, and where no layer spans the outline the silhouette is a
  stack and no sheet. Where a single flap covers the silhouette, as for
  the rectangle, the triangle and the octagon, the flap and the silhouette
  agree.
- **A trim anywhere in a program**, yielding a sheet value. Deferred with
  several sheets to tophcodes/beloch#155: outside a shape the trimmed
  sheet needs a name and the folded one a rule for what remains of it.
- **A definition that returns a sheet through `def`.** Rejected: a `def`
  body folds the sheet its `apply` stands on, and a body that opens its
  own sheet runs under another evaluation model.
- **A scale operation on sheets.** Rejected for now: the square's side
  length sizes every sheet trimmed from it, and a second way to size a
  sheet adds a construct without a program that needs it.
- **Arithmetic on numbers** (`at h/w`). Rejected for now: a distance
  along a line covers every shape the standard library needs, and
  arithmetic brings expressions and their errors into the language. It
  can be added later without changing `by`.
- **Algebraic literals** such as `sqrt 2`. Rejected: construction reaches
  the same ratios, and the source stays free of numbers it cannot state as
  fractions.
- **The unit as an annotation.** Rejected: see the rule of ADR 0029 above.
- **The sheet's own polygon as the collapse bound.** It behaves the same
  on the corpus. Rejected because the kernel then needs the sheet's
  polygon and a point-in-polygon test, and a non-convex sheet forbids a
  collapse into its own notch.
- **No collapse bound.** Rejected: six programs of the corpus stop with
  an ambiguous collapse, `packages/core/tests/cases/bases/fish-base.bel` among them.

## Consequences

- The kernel loses its unit-square assumptions: the starting state is
  built from the sheet, clipping a line clips it to the sheet, and the
  collapse tests against the hull.
- The language page states the sized square, shapes, the trim, `free …
  by`, decimal numbers and the unit declaration; the grammar page carries
  their rules. Both land with this record.
- The FOLD output gains `frame_unit`.
- The standard library is a new body of Beloch source that the
  repository ships and tests.
- Fisher's top-layer waterbomb base becomes writable on a rectangle.
- The circle stays outside: it is no polygon and cannot be trimmed from
  one. `open-sheet-shapes` keeps it open.
