# sheets Specification

## Purpose
The sheet a program opens: the square of given side, shapes trimmed from a folded square, their exports and the standard library of shapes.

## Requirements

### Requirement: The primitive sheet is a square of given side
`paper square s` SHALL open the square of side `s` with its corners `.a` $(0,0)$, `.b` $(s,0)$, `.c` $(s,s)$ and `.d` $(0,s)$ and its edges `--ab` to `--da`. `paper square` SHALL open the square of side 1. A side that is not positive SHALL fail with `the side of a square is a positive number`.

#### Scenario: A square of side 15
- **WHEN** a program opens `paper square 15`
- **THEN** `.c` is the paper point $(15, 15)$

#### Scenario: The unit square
- **WHEN** a program opens `paper square`
- **THEN** `.c` is the paper point $(1, 1)$

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

### Requirement: The standard library provides the common sheets
Every program SHALL see the shapes of the standard library, Beloch source shipped with the kernel, as if defined before its first line. They SHALL include the rectangle, the silver rectangle and the equilateral triangle, sized by their parameters. A program that defines a shape of one of their names SHALL fail with `shape <name> is already defined`.

#### Scenario: Redefining a library shape
- **WHEN** a program defines `shape rectangle(w h) { … }`
- **THEN** evaluation fails with `shape rectangle is already defined`

### Requirement: A trim lists the names it exports
A trim MAY list names in braces after its flap operand, each a name of the body with its sigil, optionally `as` a landing name of the same sigil. With a list, exactly the listed names SHALL reach the trimmed sheet under their landing names. An entry SHALL take no `!`, a listed name off the flap, a temp and two entries with one landing name SHALL each fail.

#### Scenario: A rectangle exports a square's names
- **WHEN** a shape ends with `trim to .a { .a .b .q as .c .p as .d --ab --bc --top as --cd --da }`
- **THEN** a program that opens it has corners `.a` to `.d` and edges `--ab` to `--da`

#### Scenario: A listed name off the flap
- **WHEN** a trim lists `.c` and the body's `.c` does not lie on the flap
- **THEN** evaluation fails with `` `.c` does not lie on the flap ``
