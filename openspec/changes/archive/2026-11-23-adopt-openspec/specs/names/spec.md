# Spec Delta

## Purpose

What a name with two dashes holds, which values `=` binds, and what a line parameter of a definition receives from a crease or a selection.

## ADDED Requirements

### Requirement: A name with two dashes holds a crease or a paper edge
A name with the sigil `--` SHALL hold a crease or a paper edge and nothing else. An output clause `as --c` of a write SHALL bind the crease the write scored, and `=` SHALL bind a `--` name only to a selection from the creases and edges already there.

#### Scenario: A selection bound by `=`
- **WHEN** `paper square` has both diagonals marked and a program binds `.o = --ac * --bd` and `--e = --ac & .o`
- **THEN** `--e` holds the material of `--ac` that `.o` lies on
- **AND** the binding adds no face to the state

### Requirement: `=` binds no construction
A construction SHALL stand only inside the write that reads it. Binding a construction with `=` SHALL fail with `--l = (…) binds no crease` and the hint `score it with mark (…) as --l`. A line that a later statement aligns to SHALL be scored first, in full or with `(at …)` where it is to subdivide nothing.

#### Scenario: A bound construction
- **WHEN** a program writes `--l = (map .a onto .c)`
- **THEN** evaluation fails with `--l = (…) binds no crease`
- **AND** the hint reads `score it with mark (…) as --l`

#### Scenario: The scored center line
- **WHEN** a program writes `mark (through .c .o) as --mid` and folds a corner onto `--mid`
- **THEN** the fold aligns the corner with the crease `--mid`
- **AND** `--mid` appears in the crease pattern

### Requirement: A selection passed to a line parameter holds its material
A line parameter of a definition SHALL hold the crease when its argument is a crease name, and the material the selection selects when its argument is a selection or a filter. The body SHALL be able to meet that parameter, filter it and fold along it as it could at the call site.

#### Scenario: A body meets a filtered argument
- **WHEN** a program on the square with both diagonals marked defines `def cross(--l --k) { .x = --l * --k }` and runs `$m = apply cross((--ac & .a) --bd)`
- **THEN** the member `.x` of `$m` is the paper point $(1/2, 1/2)$

