# Spec Delta

## Purpose

What a program computes: a sequence of flat folded states, changed only by verbs, with mountain and valley derived from the state and flaps as the sets of faces that lie flat as one.

## ADDED Requirements

### Requirement: A program is a sequence of folded states
A program SHALL start from its sheet and apply its statements in source order. Each write SHALL take the current folded state and yield the next state or fail with a reason. The meaning of a program SHALL be the finite sequence of states it passes through, and its result SHALL be the last of them.

#### Scenario: Two folds give two further states
- **WHEN** a program reads `paper square`, then `fold (map .a onto .c) (moving .a)`, then `fold (map .b onto .d) (moving .b)`
- **THEN** the program passes through three states: the unfolded square and one state after each fold
- **AND** its result is the state after the second fold

#### Scenario: A failing write ends the program
- **WHEN** a write is outside its domain in the current state
- **THEN** evaluation stops at that statement with an error that states the reason

### Requirement: Only a verb changes the state
A read (a construction, a meet, a join, a filter, a flap selector or a free point) SHALL compute a value from the current state and SHALL leave the state unchanged. Only the verbs `mark`, `fold`, `unfold`, `reverse`, `flatten`, `squash` and `flip` SHALL produce a new state, and they SHALL run in program order.

#### Scenario: A meet adds no face
- **WHEN** a program marks both diagonals of `paper square` as `--ac` and `--bd` and then binds `.o = --ac * --bd`
- **THEN** `.o` is the center $(1/2, 1/2)$
- **AND** the state after the binding has the same faces as the state before it

### Requirement: Mountain and valley follow from the state
The letter of a folded crease SHALL be derived from the folded state the program leaves: a fold through a stack SHALL read valley on a face-up layer and mountain on a face-down one. The program SHALL NOT store a letter as part of the state, and the crease pattern SHALL be computed from the states.

#### Scenario: One fold through two layers gives two letters
- **WHEN** a program folds the square in half and then folds both layers together along one line
- **THEN** the new crease reads valley on the face-up layer and mountain on the face-down layer

#### Scenario: A flip changes no letter
- **WHEN** `flip` follows a fold
- **THEN** every crease keeps the letter it had before the flip

### Requirement: Paper has no thickness
Every geometric decision of the kernel SHALL treat the paper as having zero thickness. A renderer MAY offset stacked layers for display, and that offset SHALL NOT change any state, value or output coordinate.

#### Scenario: Stacked layers share their table coordinates
- **WHEN** `paper square` is folded with `fold (map .a onto .c) (moving .a)`
- **THEN** the folded state places `.a` and `.c` at the same table point

### Requirement: Every folded state is flat
Every state a program passes through SHALL be a flat folded state: each face placed on the table by a plane isometry, each hinge at an angle of 0 or ±180 degrees, and a layer order over each pair of overlapping faces. No statement SHALL turn a flap to an angle short of flat.

#### Scenario: The output holds flat angles only
- **WHEN** any program evaluates
- **THEN** every edge of every frame of its FOLD output has `edges_foldAngle` 0, 180 or -180

### Requirement: A flap is a set of faces joined flat
A flap SHALL be a maximal set of faces in which any 2 are joined by a chain of hinges of angle 0. A mark that splits a face SHALL leave its flap whole. A fold SHALL split a flap at the hinges it turns, and an unfold that returns a hinge to angle 0 SHALL join the 2 flaps it separated.

#### Scenario: Marked creases do not split the sheet
- **WHEN** `paper square` has both diagonals marked as `--ac` and `--bd`
- **THEN** `#[.a .c]` resolves to one flap of 4 faces

#### Scenario: A fold splits the flap at its crease
- **WHEN** the same program continues with `fold (--bd) (moving .a)` and reads `#[.a .c]`
- **THEN** the read fails with `those points aren't all on one flap`

### Requirement: A flap operand names a flap at every slot
The operand `#[…]` and a point or line in a flap slot SHALL resolve to a flap wherever they stand: `moving`, `up to`, `on`, the target of `over` and `under`, `trim to`, and the filter `--l & #[…]`. No operand SHALL name a single face.

#### Scenario: A filter keeps the piece on one flap
- **WHEN** the square is folded along `--bd` with `.a` moving and `--h` is marked through both layers
- **THEN** `--h & #[.c]` keeps the one piece of `--h` that lies on the flap of `.c`

