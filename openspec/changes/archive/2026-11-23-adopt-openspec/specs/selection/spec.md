# Spec Delta

## Purpose

How a write keeps one of the candidate lines of a construction: the alignments as incidences, heading, the side items toward and moving, the check that a fold carries out every alignment, the landing stage, and the errors and suggestions of an ambiguous selection.

## ADDED Requirements

### Requirement: A construction yields candidates and a selection keeps one
A construction SHALL be a finite set of alignments on one sought line. Its candidates in a state SHALL be the table lines that satisfy every alignment and cross paper; a line off the paper, or one grazing an edge or a corner, SHALL be no candidate. A line SHALL be reached only through a selection that keeps exactly one candidate, and the value of the construction SHALL be the material of that line.

#### Scenario: Two candidates and one selected
- **WHEN** a program marks `--ef` with `mark (map .a onto .b) as --ef` and writes `fold (map .d onto --ef through .a) (toward .c)`
- **THEN** the construction has 2 candidates, the two tangents from `.a` to the parabola with focus `.d` and directrix `--ef`
- **AND** the selection keeps the steep one

#### Scenario: No candidate crosses the paper
- **WHEN** no line that satisfies the alignments of `map .p onto --d through .q` crosses the paper
- **THEN** the statement fails with "map .p onto --d through .q: no crease lands on the paper, so there is no fold to make"

### Requirement: An alignment names no object as the one that moves
An `onto` alignment SHALL be an incidence: `x onto y` SHALL hold when the reflection of `x` across the candidate lies on `y`, which is the same as the reflection of `y` passing through `x`. `x onto y` and `y onto x` SHALL be one alignment. The side that moves SHALL come from the side items of the write or from the default side, never from the word order of the alignment alone.

#### Scenario: The order of onto is immaterial
- **WHEN** a construction writes `(--l onto .p)`
- **THEN** it means `(.p onto --l)`

#### Scenario: Axiom 7 keeps a candidate with its points on opposite sides
- **WHEN** a construction of two points onto two lines has a candidate with one point on each side
- **THEN** that candidate remains when its fold lands one point on its line and the other line on its point

### Requirement: A construction is one of the seven alignment sets
A construction SHALL be its set of alignments together with its `heading`. The prose forms of the seven Huzita-Justin axioms SHALL mean what their `align` spelling means. An axiom number SHALL name one alignment set, recognized by the kinds of its alignments, and SHALL appear in errors and in the `axiom` field of `beloch:edges` without being a type of its own. A set that is none of the seven SHALL be an error naming its alignments. A `toward` written inside a construction SHALL be an error.

#### Scenario: Prose form and align form agree
- **WHEN** a program writes `(map .p onto --l through .q)` and another writes `(align (.p onto --l) (through .q))`
- **THEN** both evaluate to the same construction, axiom 6

#### Scenario: toward inside a construction
- **WHEN** a construction contains a `toward`
- **THEN** evaluation fails with the hint "write it as an item of the write: (toward .p)"

### Requirement: heading keeps the candidates nearest in direction
`(heading --l)` SHALL keep the candidates whose line makes the smallest angle with `--l`, as the first stage of the selection. The position of `--l` SHALL play no part. A tie SHALL pass the tied candidates on to `toward`; without `toward` they SHALL leave the construction ambiguous. `heading` SHALL sit inside the construction, and a construction that determines one line SHALL refuse it.

#### Scenario: heading selects by angle
- **WHEN** a statement writes `(align (.p onto --l) (through .q) (heading --m))`
- **THEN** the candidate whose line makes the least angle with `--m` remains, wherever `--m` lies on the paper

#### Scenario: heading on a single line
- **WHEN** `heading` is given on a construction that determines one line
- **THEN** evaluation fails with "this construction determines one line" and the hint "drop heading"

### Requirement: toward names the side that stays
For each candidate, `(toward …)` SHALL name the side of its line that stays: the side that holds the point, or the side a line's bundle lies on. A point on the candidate, or a line whose bundle the candidate crosses on the paper, SHALL name no side of that candidate, and a candidate for which `toward` names no side SHALL NOT remain.

#### Scenario: A toward point keeps its side in place
- **WHEN** a program evaluates `fold (map .a onto .b) (toward .a)` on a square
- **THEN** `.b` folds onto `.a`, and `.b` lies at (0, 0)

#### Scenario: toward names no side of a determined line
- **WHEN** the `toward` point lies on the one line a construction determines
- **THEN** evaluation fails with "toward .x names no side of the fold line"

### Requirement: moving names the side that folds over
`(moving …)` SHALL name the side of a candidate that folds over: the side of its anchor point, or of the first point of a `#[…]` selector that lies off the line, or of the bundle of a line. A point on the candidate SHALL name no side of it.

#### Scenario: A moving point on the axis
- **WHEN** a fold writes `(moving .p)` with `.p` on its fold line
- **THEN** evaluation fails with "moving .p names no side of the fold line of" followed by the construction

### Requirement: toward and moving name opposite sides
Where a write gives both `toward` and `moving`, a candidate for which they name the same side SHALL NOT remain. Where that removes every candidate the write SHALL fail.

#### Scenario: toward and moving on one side
- **WHEN** a fold writes `(toward .x)` and `(moving .c)` with `.x` and `.c` on the same side of the only candidate
- **THEN** evaluation fails with "toward .x and moving .c name the same side of the fold line" and the hint "drop one of them"

### Requirement: A candidate remains only when its fold carries out every alignment
A candidate SHALL remain only when the fold along it, with the side that folds over, carries out every `onto` alignment: one object lies on the side that folds over and lands on the paper of the other, or a point lies on the candidate and on its target line already. A point that folds onto a line SHALL land on the part of the line that lies on the paper; a landing on the extension beyond the edge SHALL NOT count.

#### Scenario: A landing beside the paper removes the candidate
- **WHEN** a square has its midlines marked as `--v` and `--h` and a program writes `fold (map .a onto --v and .c onto --h)`
- **THEN** no candidate remains, since each would land a point beside the paper of its line

#### Scenario: No fold carries out the alignments
- **WHEN** a fold with `toward .x` has no candidate whose fold keeps `.x` and carries out its alignments
- **THEN** evaluation fails with "no fold of" the construction "keeps .x on the side that stays and carries out its alignments"

### Requirement: A write without side items folds the side that carries out the construction
With neither `toward` nor `moving`, a candidate SHALL remain when a fold with either side carries out the construction. The side that alone does so SHALL fold over; where both do, the side of the first object of the first alignment as the program writes it SHALL fold over. Where that object names no side, the write SHALL need `toward` or `moving`. This default SHALL belong to the write and give the alignment no direction.

#### Scenario: The first object folds by default
- **WHEN** a program evaluates `fold (map .a onto .b)` on a square
- **THEN** `.a` folds onto `.b`

#### Scenario: A fold along a line with no derived side
- **WHEN** a program writes a fold along `(through …)`, `(perp …)` or an existing crease without `moving` or `toward`
- **THEN** evaluation fails with "this fold needs `moving .p` to choose the side"

### Requirement: toward keeps the candidate that lands the objects nearest
Among several remaining candidates, `(toward .u)` SHALL keep those whose landing of the objects of the alignments lies nearest `.u` or the line it names, measured as the least distance between the two sets and compared exactly. The landing SHALL be the points and the parts of lines that fold over, where they land; the rest of the flap SHALL go unmeasured. Equal distances SHALL leave the construction ambiguous.

#### Scenario: Equal landing distances
- **WHEN** two candidates land the objects of their alignments equally near `.x`
- **THEN** evaluation fails with an error saying that toward .x lies as near to where one fold lands the objects as to where another does
- **AND** the hint reads "name what goes toward .x, e.g. (.p toward .x)"

### Requirement: A subject of toward measures that object alone
`(x toward .u)` SHALL measure only the landing of `x`, one of the objects of the alignments, compared by place. Candidates whose fold does not fold `x` over SHALL drop out at the landing stage, also when no other candidate remains to compare. An `x` that is none of the objects SHALL be an error.

#### Scenario: The landing stage decides by the subject
- **WHEN** a program marks `--ef` and `--bd`, places `.p` a quarter of the way along `--bd` from `.d`, and writes `fold (map .d onto --ef through .p) (.d toward .c)`
- **THEN** both candidates keep the side of `.c`, and the one that lands `.d` on the top edge remains

#### Scenario: A subject that is no object
- **WHEN** a fold writes `(x toward .u)` with an `x` that appears in none of its alignments
- **THEN** evaluation fails with "x is none of the objects of" the construction

### Requirement: Several remaining candidates make the selection ambiguous
Where more than one candidate remains after every stage, and the statement has no `toward` to decide, the write SHALL fail, state the number of folds that carry the construction out, and hint at `toward` or `heading`. `moving` SHALL have no landing stage.

#### Scenario: Two folds carry out a construction
- **WHEN** a fold of `map .p onto --d through .q` without `toward` leaves 2 candidates
- **THEN** evaluation fails with "map .p onto --d through .q is ambiguous: 2 folds carry it out, all landing on the paper" and the hint "add (toward .x) or a heading"

### Requirement: An ambiguous selection suggests an item per candidate
When several candidates remain, the trace SHALL carry one suggestion per remaining candidate: the first added item after which exactly that candidate remains. Without `toward` the items tried SHALL be `(toward x)` over the named points in scope, then the named lines, in program order. After a tie of a bare `toward` they SHALL be `(x toward …)` over the objects of the alignments in program order. A suggestion SHALL be checked for its own statement only.

#### Scenario: A suggestion keeps one candidate
- **WHEN** a selection without `toward` ends with 2 candidates
- **THEN** the trace names, for each candidate, the first named point or line whose `toward` keeps it alone
- **AND** a candidate that no such item keeps alone has no suggestion

### Requirement: toward names the side that stays on every write
`toward` without `moving` SHALL name the side that stays on every write that takes it: on a construction of one line, on a fold along an existing crease, on `reverse` and on a placed fold. Where the write has no anchor, the material on the other side SHALL be the flap, the tip or the block that moves.

#### Scenario: toward on an existing crease
- **WHEN** a program writes `fold (--v) (toward .b)`
- **THEN** the side of `--v` that holds `.b` stays and the other side folds over

#### Scenario: toward on a reverse fold
- **WHEN** a program writes `reverse (--h) (toward .d)`
- **THEN** the tip that turns lies on the side of `--h` opposite `.d`

### Requirement: A mark selects its line as a fold along it would
`mark` SHALL take `toward` and `moving` and SHALL select its line with them as a fold along that line would. Where no paper moves, `moving` SHALL name a side and no flap. On a `mark` along an existing line, which selects nothing, `toward` and `moving` SHALL be errors.

#### Scenario: A mark selected by toward
- **WHEN** a program writes `mark (map --v onto --h) (toward .b) as --k`
- **THEN** `--k` is scored along the candidate a fold with `(toward .b)` would take, and no paper moves

