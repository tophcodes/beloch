# Spec Delta

## Purpose

The sheet a program opens: the square of given side, shapes trimmed from a folded square, their exports, the standard library of shapes, numbers and the unit a file declares.

## ADDED Requirements

### Requirement: The primitive sheet is a square of given side
`paper square s` SHALL open the square of side `s` with its corners `.a` $(0,0)$, `.b` $(s,0)$, `.c` $(s,s)$ and `.d` $(0,s)$ and its edges `--ab` to `--da`. `paper square` SHALL open the square of side 1. A side that is not positive SHALL fail with `the side of a square is a positive number`.

#### Scenario: A square of side 15
- **WHEN** a program opens `paper square 15`
- **THEN** `.c` is the paper point $(15, 15)$

#### Scenario: The unit square
- **WHEN** a program opens `paper square`
- **THEN** `.c` is the paper point $(1, 1)$

### Requirement: A number is an exact rational written without arithmetic
A number in the source SHALL be an integer, a fraction or a decimal, each an exact rational, and a decimal SHALL start with a digit. The language SHALL hold no arithmetic on numbers and no irrational literal; an irrational ratio SHALL come from a constructed line.

#### Scenario: A decimal and a point name
- **WHEN** a program writes `paper square 7.5`
- **THEN** the side is the rational $15/2$
- **AND** the lexer takes `.5` as the point name `.5` and no number

### Requirement: A free point lies at a distance along a line
`free on --l from .x by d` SHALL place the point at the distance `d` from the end `.x` of the material of `--l`, measured along the line, for $0 \le d$ up to the length of that material. A longer distance SHALL fail with `the distance is longer than the line's material`.

#### Scenario: Three units along an edge
- **WHEN** a program opens `paper square 4` and binds `.e = free on --ab from .a by 3`
- **THEN** `.e` is the paper point $(3, 0)$

### Requirement: A shape is a folded square trimmed to one flap
A shape SHALL be a top-level definition whose body opens its own sheet, folds it and ends with `trim to <flap>`. The trimmed sheet SHALL be the part of the body's sheet that the flap covers, in paper coordinates, unfolded, and a program SHALL open it with `paper <shape> <numbers>`. The body's states SHALL belong to no program's path.

#### Scenario: Opening a rectangle
- **WHEN** a program opens `paper rectangle 2 1`
- **THEN** its first state is the unfolded rectangle with corners $(0,0)$, $(2,0)$, $(2,1)$ and $(0,1)$
- **AND** the program's path holds none of the states of the shape's body

### Requirement: A trim is the last statement of a shape
`trim to` SHALL be the last statement of a shape body and SHALL stand nowhere else. A body that does not end with it SHALL fail with ``a shape ends with `trim to` ``, and a trim elsewhere with `` `trim to` is the last statement of a shape ``. Its flap operand SHALL resolve against the last state of the body as for `moving`.

#### Scenario: A trim at the top level
- **WHEN** a program writes `trim to .a` outside a shape body
- **THEN** evaluation fails with `` `trim to` is the last statement of a shape ``

### Requirement: Names on the trimmed flap survive the trim
Without an export list, every name of the body whose point or line lies on the trimmed flap SHALL keep its meaning and its coordinates on the new sheet, a line as its part on the flap. Every other name and every temp SHALL be gone. Creases the body marked on the flap SHALL stay as unfolded marks, and a crease the body folded SHALL be no crease of the new sheet.

#### Scenario: A corner off the flap is gone
- **WHEN** a shape folds the strip of `.d` away and trims to `.a` without an export list
- **THEN** a program that opens the shape may name `.a` and `.b`
- **AND** naming `.d` fails as an undefined point

### Requirement: A flap with a hole is no sheet
A trim whose flap outline has a hole SHALL fail with `the flap has a hole and is no sheet`, since a sheet is a simple polygon.

#### Scenario: A trimmed ring
- **WHEN** the flap a trim names has an outline of 2 loops
- **THEN** evaluation fails with `the flap has a hole and is no sheet`

### Requirement: The parameters of a shape are numbers
A shape's parameters SHALL be numbers named without a sigil, matched by position to the numbers of an opening. A count mismatch SHALL fail with `` `<shape>` takes <n> numbers, <m> given ``. A bare name where a number stands SHALL fail outside a shape body and, inside one, where it names no parameter. A shape body SHALL hold no `def` and no annotation.

#### Scenario: Too few numbers
- **WHEN** a program opens `paper rectangle 2`
- **THEN** evaluation fails with `` `rectangle` takes 2 numbers, 1 given ``

### Requirement: The standard library provides the common sheets
Every program SHALL see the shapes of the standard library, Beloch source shipped with the kernel, as if defined before its first line. They SHALL include the rectangle, the silver rectangle and the equilateral triangle, sized by their parameters. A program that defines a shape of one of their names SHALL fail with `shape <name> is already defined`.

#### Scenario: Redefining a library shape
- **WHEN** a program defines `shape rectangle(w h) { … }`
- **THEN** evaluation fails with `shape rectangle is already defined`

### Requirement: A file declares the unit of its numbers
A file MAY name its unit before its first statement with `unit <u>`, `<u>` being one of `in`, `pt`, `m`, `cm`, `mm`, `um`, `nm`. The unit SHALL change no coordinate. The FOLD output SHALL write it as `frame_unit`, and SHALL write `"unit"` when the file names none. Any other unit SHALL fail with `` `<u>` is no unit; the units are in, pt, m, cm, mm, um, nm ``.

#### Scenario: A square in millimeters
- **WHEN** a file reads `unit mm` and `paper square 150`
- **THEN** the FOLD output has `frame_unit` `"mm"` and the corner `.c` at $(150, 150)$

#### Scenario: No unit declared
- **WHEN** a file declares no unit
- **THEN** the FOLD output has `frame_unit` `"unit"`

### Requirement: A trim lists the names it exports
A trim MAY list names in braces after its flap operand, each a name of the body with its sigil, optionally `as` a landing name of the same sigil. With a list, exactly the listed names SHALL reach the trimmed sheet under their landing names. An entry SHALL take no `!`, a listed name off the flap, a temp and two entries with one landing name SHALL each fail.

#### Scenario: A rectangle exports a square's names
- **WHEN** a shape ends with `trim to .a { .a .b .q as .c .p as .d --ab --bc --top as --cd --da }`
- **THEN** a program that opens it has corners `.a` to `.d` and edges `--ab` to `--da`

#### Scenario: A listed name off the flap
- **WHEN** a trim lists `.c` and the body's `.c` does not lie on the flap
- **THEN** evaluation fails with `` `.c` does not lie on the flap ``

