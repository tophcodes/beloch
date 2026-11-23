# Spec Delta

## Purpose

How a statement names what it works on: typed slots, numbers and the unit a file declares, free points, creases as bundles of pieces, the meet, the filters and the join, the paper a line reads, and the errors of a slot that resolves to no or several referents.

## ADDED Requirements

### Requirement: A crease is a bundle of pieces
A crease name SHALL denote the bundle its write scored: a set of paper points with one piece per flap the scored line crossed. A later fold across the crease SHALL split a piece in 2 and leave the bundle the same set of paper points. A crease SHALL serve as a line only through the table line its pieces lie on.

#### Scenario: A crease scored through two layers has two pieces
- **WHEN** a program folds the square along `--bd` with `.a` moving, binds `.m = free on --bc from .b at 3/4` and marks `(perp --bc through .m) as --h`
- **THEN** `(--h & .m) * --ac` is the paper point $(3/4, 3/4)$
- **AND** `(--h \ .m) * --ac` is the paper point $(1/4, 1/4)$

### Requirement: A slot that takes one line takes one piece
Where a slot takes one line, as the axis of a write or a ray of `flatten` does, its operand SHALL resolve to exactly 1 piece. No piece SHALL fail with `no segment of <operand> matches`, and several pieces SHALL fail with `<operand> is ambiguous: <n> segments match` and the hint `add a selector`.

#### Scenario: A filter that keeps nothing
- **WHEN** a write takes as its axis a filter that keeps no piece of its crease
- **THEN** evaluation fails with `no segment of` and the filter, then `matches`

#### Scenario: A filter that keeps two pieces
- **WHEN** a write takes as its axis a filter that keeps 2 pieces
- **THEN** evaluation fails with `is ambiguous: 2 segments match` and the hint `add a selector`

### Requirement: A crease serves as a line only while it is straight
A crease SHALL take a slot of type line only while all its pieces lie on one table line. Once a fold has bent it, using it as a line SHALL fail with `--l is no longer straight after folding` and the hint to narrow it to one piece with `&`.

#### Scenario: A bent crease as the axis of a fold
- **WHEN** the square has both diagonals marked, a program marks `(map .a onto .b) as --m`, folds `(--bd) (moving .a)` and then writes `fold (--m) (moving .c)`
- **THEN** evaluation fails with `--m is no longer straight after folding` and the hint `narrow it to one piece with &, e.g. --m & .p`

#### Scenario: One piece of a bent crease
- **WHEN** the same fold takes `--m & .p` for a point `.p` on one piece of `--m`
- **THEN** the piece supplies its own table line as the axis

### Requirement: Every operand slot has a type
Every slot of a statement SHALL take one parameter type of the language, such as point, line, crease, flap or number. The sort of an operand SHALL follow from its source alone: the sigil of a name, or the form of a read. A program whose operand sort does not match its slot SHALL fail before the slot is resolved.

#### Scenario: A crease where a point is wanted
- **WHEN** a definition `def corner(.p .o)` is applied as `apply corner(--ac .o)`
- **THEN** evaluation fails with `parameter .p of corner needs a point argument`

### Requirement: A name holds a point or a bundle, never a single piece
A name SHALL hold a point or a bundle, values whose identity no later fold changes. A single piece or a single flap SHALL exist only as the result of resolving a slot against the state in which the slot is used, and no name SHALL hold one.

#### Scenario: A name survives the fold that splits it
- **WHEN** a program folds the square along `--bd` with `.a` moving and then reverse-folds `(map .b onto .c) as --h` and `(map .d onto .c) as --v`
- **THEN** `--h` and `--v` each lie on 2 paper lines
- **AND** `--h * --v` is the paper point $(1/2, 1/2)$

### Requirement: An underdetermined slot fails naming its candidates
Each operand SHALL resolve to exactly one referent in its slot. An operand that matches none SHALL fail with an error saying so. An operand that matches several SHALL fail with an error that lists the candidates or their number and asks for a further constraint.

#### Scenario: A flap on a shared crease
- **WHEN** every point of a `#[…]` lies on a crease that several flaps share
- **THEN** evaluation fails with `ambiguous flap` and the hint `add another point`

#### Scenario: A meet with two crossings
- **WHEN** a meet has 2 common points
- **THEN** the error lists both points in paper coordinates

### Requirement: Material is selected by incidence
The filters `&` and `\`, the join `--[…]` and the flap selector `#[…]` SHALL select geometry that is already there, by incidence in paper coordinates, and SHALL score nothing. A point in a flap slot SHALL name the flap that carries it, and a line SHALL name the flap hinged on it.

#### Scenario: A join that finds no crease
- **WHEN** a program writes `--[.p .q]` for 2 points that no crease or paper edge runs through
- **THEN** evaluation fails with `no crease or edge is incident to all of`

#### Scenario: The join of two corners is their edge
- **WHEN** a program writes `--[.a .b]` on `paper square`
- **THEN** the join is the paper edge `--ab`

### Requirement: A slot may supply its own constraint
A slot SHALL count the constraint its own position contributes toward resolving its operand. `up to` a crease SHALL resolve to the flap reached by walking inward from the side `moving` names, and without `moving` it SHALL fail with `` `up to` a crease needs `moving` to walk inward from `` and the hint to name the flap with a point.

#### Scenario: A crease as the depth without a side
- **WHEN** a fold takes `(up to --d)` and no `moving`
- **THEN** evaluation fails with `` `up to` a crease needs `moving` to walk inward from ``

### Requirement: The meet is the one paper point its operands share
The meet `--x * --y` and `.[--x --y …]` with 2 or more operands SHALL be the one paper point common to all operands as sets of paper points. A paper edge SHALL count as its side of the sheet. The intersection SHALL be taken in paper coordinates, so no fold changes a meet, and the number of paper lines an operand lies on SHALL play no part.

#### Scenario: The center of the preliminary base
- **WHEN** a program folds the square along `--bd` with `.a` moving, reverse-folds `--h` and `--v` and binds `.o = --h * --v`
- **THEN** `.o` is the paper point $(1/2, 1/2)$

#### Scenario: Three creases meet at one point
- **WHEN** the square has both diagonals and `mark (map .a onto .b) as --m` marked and a program binds `.o = .[--ac --bd --m]`
- **THEN** `.o` is $(1/2, 1/2)$

### Requirement: An undefined meet fails by its cause
A meet SHALL fail when its operands have no common point, when they have 2 or more, and when they share a stretch of paper or lie on one boundary line, each with its own message. The message for several points SHALL list them in paper coordinates and suggest narrowing an operand with `&`.

#### Scenario: Two pieces meet a crease twice
- **WHEN** a crease `--h` of 2 pieces that share the point `.j` is filtered to `--h & .j` and met with `--ac`
- **THEN** evaluation fails with `they cross at 2 points`

#### Scenario: Parallel creases
- **WHEN** a program meets 2 parallel creases
- **THEN** evaluation fails with the error for operands with no common point

### Requirement: The paper of a line is the bundle held under its name
Every read of the paper of a line SHALL take the bundle the program holds under its name: the side a `toward` or `moving` line names, whether a moved line carries out an alignment, its landing, the meet and the filters. A crease's bundle SHALL be its scored pieces, a mark's bundle its extent in the flap it was marked on, and a construction or paper edge SHALL hold all the paper on its line.

#### Scenario: A partial mark names the side it lies on
- **WHEN** a program marks `(through .a .c) as --ac`, binds `.o = free on --ac from .a at 1/2`, marks `(through .a .c) (between .a .o) as --half` and folds `(map .c onto .o) (toward --half)`
- **THEN** the fold folds the corner `.c` onto the center

### Requirement: A moved mark aligns only with marked paper
A mark that moves SHALL carry out an alignment only where marked paper lands; a candidate that would land the unmarked continuation of the mark's line SHALL NOT remain. A point folded onto a mark or a crease SHALL need paper on that line in the current state, marked or not.

#### Scenario: A pinch too short to land
- **WHEN** a pinch `--pinch` runs from the middle of `--ab` to the center and a program writes `fold (map .d onto --pinch through .a) (moving --pinch)`
- **THEN** evaluation fails with an error that names the point of the mark's line that has to land and a hint to extend the mark to it

#### Scenario: The corner moves onto the pinch's line
- **WHEN** the same fold takes `(moving .d)` in place of `(moving --pinch)`
- **THEN** the fold succeeds and lands `.d` on the line of the pinch

### Requirement: A program unites no bundles
A `[` without a sigil before it SHALL be an error, `a bare [ opens no read`, with a hint that names the 3 bracket forms: the meet `.[--l --m]`, the join `--[.p .q]` and the flap `#[.p .q]`. Each bracket form SHALL select one thing of the sort its sigil names.

#### Scenario: A bare bracket
- **WHEN** a program writes `.o = [--ac --bd] * --m`
- **THEN** evaluation fails with `a bare [ opens no read`

### Requirement: A bundle of several creases arises only from a flatten
The crease of a `flatten` with an even number of rays SHALL be the only bundle that spans several creases. A slot that takes one crease SHALL refuse it with `--x is a bundle, not a single crease` and the hint `restrict it with & or \`.

#### Scenario: Folding along a flatten's bundle
- **WHEN** a program flattens 4 rays `as --x` and then writes `fold (--x) (moving .b)`
- **THEN** evaluation fails with `--x is a bundle, not a single crease`

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

### Requirement: The parameters of a shape are numbers
A shape's parameters SHALL be numbers named without a sigil, matched by position to the numbers of an opening. A count mismatch SHALL fail with `` `<shape>` takes <n> numbers, <m> given ``. A bare name where a number stands SHALL fail outside a shape body and, inside one, where it names no parameter. A shape body SHALL hold no `def` and no annotation.

#### Scenario: Too few numbers
- **WHEN** a program opens `paper rectangle 2`
- **THEN** evaluation fails with `` `rectangle` takes 2 numbers, 1 given ``

### Requirement: A file declares the unit of its numbers
A file MAY name its unit before its first statement with `unit <u>`, `<u>` being one of `in`, `pt`, `m`, `cm`, `mm`, `um`, `nm`. The unit SHALL change no coordinate. The FOLD output SHALL write it as `frame_unit`, and SHALL write `"unit"` when the file names none. Any other unit SHALL fail with `` `<u>` is no unit; the units are in, pt, m, cm, mm, um, nm ``.

#### Scenario: A square in millimeters
- **WHEN** a file reads `unit mm` and `paper square 150`
- **THEN** the FOLD output has `frame_unit` `"mm"` and the corner `.c` at $(150, 150)$

#### Scenario: No unit declared
- **WHEN** a file declares no unit
- **THEN** the FOLD output has `frame_unit` `"unit"`

