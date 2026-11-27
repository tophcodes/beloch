## ADDED Requirements

### Requirement: A flatten names the part that stays
Every `flatten`, of ray items or of fan items, SHALL hold a `staying` item. A `flatten` without one SHALL fail with `flatten needs (staying .p)`, hint `name a point in the part that stays`, before any state is solved.

#### Scenario: The petal fold without staying
- **WHEN** the petal fold runs without `(staying .o)`
- **THEN** it fails with `flatten needs (staying .p)`

#### Scenario: Collinear leading rays
- **WHEN** `flatten (--d1 & .a) (--d1 & .c) (--d2 & .b mountain) (--d2 & .d)` runs on the open square
- **THEN** it fails with `flatten needs (staying .p)`

### Requirement: The stayer places the result on the table
The stayer SHALL fix where the result lies on the table; where the faces lie relative to each other SHALL not depend on it.

#### Scenario: The rabbit ear keeps its half in place
- **WHEN** `flatten (--ea & .a valley) (--ec & .c) (--eb & .b valley) (staying .d) (emergent beside .a) as --ear` runs on the open square
- **THEN** `.a`, `.c` and `.d` keep their places on the table, and the ear lies on the triangle they span

## MODIFIED Requirements

### Requirement: Every item of a flatten is a condition on its states
The result of a `flatten` SHALL be the set of its legal flat states, narrowed by its items; every item SHALL be a condition on that set and never a ranking. One state left SHALL be the value; more than one SHALL fail with `flatten is ambiguous: <n> realizations`, whose hint names items that would leave one. An item that rules nothing out SHALL be no error.

#### Scenario: A rabbit ear without conditions
- **WHEN** `flatten (--ea) (--ec) (--eb) (staying .d)` runs on the square with the three angle bisectors of the triangle `.a .b .c` marked
- **THEN** it fails with `flatten is ambiguous`

#### Scenario: The fish-base vertex names what stays
- **GIVEN** the square with `--l1` and `--l2` marked through `.b` and `.d` and the fish-base vertex on `--ray`, the diagonal through `.a` and `.c`
- **WHEN** `flatten (--l1 valley) (--l2) (--ray mountain) (staying .c)` runs
- **THEN** it fails with `flatten is ambiguous: 2 realizations`, the two mirror images that take the halves of the lines toward `.b`, `.d` and `.a`
- **AND** with `(emergent beside .b)` added it folds the one whose emergent ray runs toward `--ab`

## REMOVED Requirements

### Requirement: Without staying a default part stays
**Reason**: A default stayer saves the `staying` item only in a fan whose parts differ in size, such as a rabbit ear, and a reader has to know the rule to read any `flatten` that leaves it out. A symmetric collapse from the open sheet, the common case, ties and needs `staying` under any default.
**Migration**: Add `(staying .p)` to every `flatten` that has none, with `.p` in the part the default held still.

### Requirement: The outline ranks the states of every fan
**Reason**: It ranks the states of a fan by whether they lie inside the convex hull of the state before the write, so the states a program gets depend on what else the fan could do. Every item of a flatten is a condition (requirement "Every item of a flatten is a condition on its states").
**Migration**: A program that relied on the outline to drop states names what stays with `(staying …)`, the half of a line with `&`, or the side of the emergent ray with `(emergent beside …)`.

### Requirement: The stayer fixes where the result lies on the table
**Reason**: Its scenario, candidates that hold different parts still without a `staying` item, cannot occur once every `flatten` names its stayer, and its statement named the outline ranking. Requirement "The stayer places the result on the table" keeps the rule without either.
**Migration**: None.
