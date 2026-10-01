---
title: Language
description: Beloch as the signature of the model. Which sorts a program names, which operations it applies, and how the surface syntax marks the difference.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

The language spans several pages. This page states what a program is and
the sorts and types a statement works with.
[Write statements](/language/writes/) gives the verbs,
[Constructions](/language/constructions/) the reads a write's axis comes
from, [Annotations](/language/annotations/) what a program tells its
reader beyond the geometry, and [Grammar](/language/grammar/) the grammar
of the language.

The language refers to the model by statement ids and to the specification
by section. The model does not refer to the language.

## A program is a path

A program starts from a sheet ([def-sheet](/model/#def-sheet)) and applies
operations one after another. Each operation takes the current flat folded
state ([def-flat-state](/model/#def-flat-state)) and either produces the next
one or fails with a reason. The program's meaning is the finite sequence of
states it passes through; its result is the last state.

## Sheets

A program opens its sheet with `paper`, followed by the sheet: the square,
or a shape defined earlier in the file.

```
paper square            ; the square of side 1
paper square 15         ; the square of side 15
paper rectangle 2 1     ; the shape rectangle, opened with w = 2 and h = 1
```

**The square.** `square s` is the square of side $s$, and `square` alone is
the square of side 1. Its corners are bound counter-clockwise from the
origin, and its edges by the corners they join, `--ab` to `--da`:

| name | coordinates |
|------|-------------|
| `.a` | $(0, 0)$ |
| `.b` | $(s, 0)$ |
| `.c` | $(s, s)$ |
| `.d` | $(0, s)$ |

The side length is a positive number. A number is an integer (`15`), a
fraction (`15/2`) or a decimal (`7.5`), each an exact rational. A decimal
starts with a digit: `0.5` is a number and `.5` is a point name.

**Shapes.** A shape is a definition whose body is a program on one sheet,
ending with a trim to one flap of that sheet. The flap is the new sheet
([def-flap](/model/#def-flap)):

```
shape rectangle(w h) {
  paper square w
  .p = free on --da from .a by h
  fold (perp --da through .p) (moving .d)
  trim to .a
}
```

- A shape stands at the top level of a file, and its name is a bare
  identifier in the namespace of definitions. A second shape or `def` of
  the same name is an error.
- Its parameters are numbers, named without a sigil, and an opening
  `paper rectangle 2 1` supplies one number per parameter, matched by
  position. Inside the body a parameter stands wherever a number does.
- The body sees its parameters and the definitions written earlier in the
  file, nothing else, so a shape cannot open itself. It holds the
  statements of a program and no `def`, `shape` or annotation, and it
  starts with its own `paper` line.
- `trim to` takes a flap operand, resolved against the last state of the
  body as for `moving` ([def-selector](/model/#def-selector)). It is the
  last statement of the body and stands nowhere else.

Every program sees the shapes of the standard library as if they were
defined before its first line. Their names are taken: a program that
defines a shape of one of them gets `` shape <name> is already defined ``.

The trimmed sheet is the part $F \subseteq P$ of the body's sheet that the
flap covers, in paper coordinates. It is unfolded: the program that opens
it starts from the flat state of $F$. A name whose point or line lies in
$F$ keeps its meaning and its coordinates, for a line the part of it in
$F$; every other name of the body, and every temp, is gone. Creases the
body marked on $F$ stay on it as unfolded marks, and a crease the body
folded is no crease of the new sheet. The body's states belong to no
program's path: a program that opens a shape starts at the trimmed sheet.

**Exports.** A trim may list the names it exports, in braces after the flap
operand (ADR 0047). An entry is a name of the body with its sigil,
optionally `as` a landing name with its sigil, as in `export`, and takes no
`!`: the trimmed sheet
starts with no names, so a landing name may be one the body used off the
flap.

```
trim to .a { .a .b .q as .c .p as .d --ab --bc --top as --cd --da }
```

With a list, exactly the listed names reach the trimmed sheet, under their
landing names; a listed bundle reads the exported names. Without one, every
name on the flap does. Errors: a listed name that does not lie on the flap
(`` `.c` does not lie on the flap ``), a temp in the list
(`` `._r` is a temp; a trim exports no temp ``), two entries with one
landing name (`` two entries land on `.c` ``), a `!` (`` a trimmed sheet
starts with no names, so a trim shadows none; drop the ! ``), and a listed
bundle whose expression reads a name the list leaves out
(`` `--edge` reads a name the trim does not export ``).

Errors: `` `<name>` is no shape ``, an opening whose number of values
differs from the parameters (`` `rectangle` takes 2 numbers, 1 given ``),
a body that does not end with `trim to` (`` a shape ends with `trim to` ``),
a trim elsewhere (`` `trim to` is the last statement of a shape ``), and a
flap whose outline has a hole (`` the flap has a hole and is no sheet ``),
which [def-sheet](/model/#def-sheet) excludes. A square whose side is not
positive is an error (`` the side of a square is a positive number ``), and
so is a unit the format does not name (`` `<unit>` is no unit; the units are
in, pt, m, cm, mm, um, nm ``). A bare name where a number stands is an error
outside a shape body (`` `<name>` is no number; a name stands for a number
only in a shape body ``) and, inside one, where it names no parameter
(`` `<name>` is no parameter of this shape ``). A shape body that holds an
annotation or a `def` is an error (`` a shape body holds no annotation ``,
`` a shape body holds no def ``). A second shape of a name is an error
(`` shape <name> is already defined ``), and so is a `def` of a shape's name
(`` <name> is already defined as a shape ``).

A library file holds shapes and no `paper` line; the standard library is
one.

**Units.** A file may name the unit of its numbers in a declaration before
its first statement:

```
unit mm
paper square 150
```

The unit is one of the physical units the FOLD format names: `in`, `pt`,
`m`, `cm`, `mm`, `um`, `nm`. It changes no coordinate; the output writes
it as `frame_unit` ([Output format](/output/)), and as `"unit"` when the file names
none. A file without a declaration takes the unit of the file that loads
it, and a loaded file with another unit has its numbers converted exactly,
each of these units being a rational multiple of the millimetre. Beloch
does not load files yet, so these two rules wait for the import
(ADR 0046).

## Reads and writes

One law organises the surface syntax (`SPECIFICATION.md` §4.10): an
operation that changes the state is a keyword verb, sequenced in program
order; an operation that only computes something from the current state is
an operator, a bracket, or a construction, and may appear anywhere a value
is needed.

In the terms of the model, the writes are the partial functions from states
to states ([def-write](/model/#def-write)), and the reads are functions from
a state into the value sorts ([def-read](/model/#def-read)). A read never
fails silently: where the state has no answer, such as a point that lies on
no face or a construction with two solutions and no way to pick one, the
read is an error.

**Sorts.** Point, line, flap, and bundle (a set of crease segments), the
value sorts of the model's section on values; each a value computed in the
current state and carried in paper coordinates, so it survives later folds.

**Writes.** The operations of the model's section on operations, named by
the verbs `mark`, `fold`, `reverse`, `flatten` and `flip`. Each is a
partial function on states with its own domain; the domain is the
language's notion of a safe operation, and the model states it. A *write
statement* is a verb followed by its arguments; its shape is given under
[Write statements](/language/writes/).

**Reads.** Constructions (below), selectors (`#[…]`, `*`, `--[…]`, `free
on`), and the filter operators (`&`, `\`, `[…]`), which form a Boolean
algebra on the segments of a bundle: intersection with an incidence
predicate, difference, union.

**The meet.** `--x * --y`, and `.[--x --y --z]` for more operands, is the
one paper point the operands have in common as sets of paper points
([def-meet](/model/#def-meet)). An operand may lie on several paper lines,
as a crease scored through several layers does; on the preliminary base
`--h * --v` is the centre of the paper. A paper edge such as `--ab` counts
as its side of the sheet. The meet is an error when the operands have no
common point, when they share a stretch of paper, and when they have two or
more common points; the last message lists the points in paper coordinates,
and `&` narrows an operand to the pieces that cross at the one meant.

## Free points

```
.p = free on --l from .x
.p = free on --l from .x at 2/5
.p = free on --l from .x by 3
```

A free point is a point placed on the material of a line without a
construction that says why it lies there. `free` records how the point was
placed and that the author chose its position by eye; the point is an
exact point like any other and stands wherever a point does.

**Domain.** The point lies on the material of `--l` in the current state,
taken as one bundle: its two furthest-out points are the ends of the
range, and gaps between its segments are bridged. For a line no `mark` has
scored, the bundle is where the line crosses the sheet. `from .x` names
one of the two ends, matched by exact incidence, and that end is where the
range starts.

**Position.** `at t` places the point at the fraction $t$ of the range,
$P_0 + t\,(P_1 - P_0)$ for $t \in [0, 1]$. `by d` places it at the
distance $d$ from the start, measured along the line, for
$0 \le d \le |P_1 - P_0|$; the point is exact whatever $d$ is, since the
kernel holds the length of the range exactly (ADR 0012, 0013). Without
either, the point is the midpoint.

```
paper square 4
mark (through .a .c) as --diag
.m = free on --diag from .a           ; the midpoint, (2, 2)
.q = free on --diag from .a at 1/4    ; (1, 1)
.e = free on --ab from .a by 3        ; (3, 0)
```

Errors: `` the line has no material on the paper ``, `` the anchor is not
an endpoint of the line's material ``, `` t is out of range (must be
between 0 and 1) ``, and `` the distance is longer than the line's
material ``.

Each free point is written to the output as a `beloch:free` field, so that
a renderer can offer a slider over the range; no renderer reads it yet.

## Parameter types

A statement takes typed arguments. Four of the types are value sorts of the
model and are supplied by a read; a number is written in the source; the
others are enumerations that occur only as an argument of a write. The type of a slot is what a graphical
editor binds to: a slot of type flap gets a flap picker, a slot of type
placement a menu of four entries.

| type | values | slots |
|---|---|---|
| line | a construction, a name bound by `=`, or a crease whose segments lie on one table line ([def-line](/model/#def-line)) | the operands of a construction, `heading`, `toward`, the axis of `mark` |
| crease | a name bound by `as`: the material scored under that name ([def-bundle](/model/#def-bundle)), or a selection from one | the axis `(--d)` of `fold` and `reverse`, the rays of `flatten`, the meet `*`, the filters `&` `\` `[…]`, `free on` |
| flap | a point, a line, or `#[…]`, resolved by incidence ([def-selector](/model/#def-selector)) | `moving`, `up to`, `on`, `staying`, the target of `over` and `under` |
| point | a named or selected point | `at`, `between`, `toward` |
| number | a number, or inside a shape one of its parameters | the side of `square`, `at` and `by` of `free on`, the values that open a shape |
| placement | top, bottom, over a flap, under a flap ([def-reflection](/model/#def-reflection)) | `fold` |
| kind | inside, outside ([def-reverse](/model/#def-reverse)) | `reverse` |
| extent | the whole line, between two points, at a point ([def-mark](/model/#def-mark)) | `mark` |
| intent | mountain, valley; the direction the crease pattern draws, no part of the state | `mark` |
| letter | mountain, valley as a constraint on a ray, or on a hinge of the spine ([def-letter](/model/#def-letter)) | `flatten`, `reverse` |
| order | one sector over another | `flatten` |
| selection | `toward` a point or a line, the side that stays; `moving` a flap, the side that folds over; `heading` a line, the direction of the crease ([def-selection](/model/#def-selection)) | `toward` and `moving`: `mark`, `fold`, `reverse` and a binding over a construction; `toward` a point: `flatten`; `heading`: `align` |

Line and crease are two sorts under one sigil, and the binding tells them
apart: `--l = …` is a line, `… as --l` is a crease. A crease stands where a
line is wanted by projection to its table line, which exists while its
segments are collinear (ADR 0014) and is an error once a fold has bent it.
A line stands nowhere a crease is wanted: it has no material until a
`mark` scores it. The check needs no geometry, so a program's sorts can be
verified before it is evaluated.
