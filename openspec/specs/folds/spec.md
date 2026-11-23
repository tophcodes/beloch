# folds Specification

## Purpose
Which layers mark, fold and unfold reach and move: every layer under the axis by default, the depth that up to names, the layers a placed fold takes up to its target, the flap that on names, and unfold turning layers back over a scored crease.

## Requirements

### Requirement: A fold moves every layer on its moving side
A `fold` without `up to` SHALL move every layer under its axis on the side that folds over. The moving set SHALL be closed under hinges off the axis, folded or flat, so that a flap moves whole and no hinge off the axis joins a moving face to a staying one.

#### Scenario: A corner folds through both layers
- **WHEN** a square is folded with `fold (map .b onto .a)`, `.p` and `.q` lie a quarter along `--bc` and `--ab` from `.b`, and the program writes `fold (through .p .q) (moving .b) as --f`
- **THEN** the corner moves on both layers
- **AND** `--f` reads valley on the face-up layer and mountain on the face-down one

### Requirement: The anchor of a fold names its side and nothing more
`moving` SHALL name the side of the axis that folds over and SHALL NOT narrow the layers that move. A point on the axis SHALL name no side, and a flap that straddles the axis without a point SHALL name none either.

#### Scenario: moving selects no flap
- **WHEN** a program folds a stack of two layers with `(moving .b)` and no `up to`
- **THEN** every layer on the side of `.b` moves, the layer under the one that holds `.b` included

### Requirement: up to narrows a fold to a flap and the layers outward of it
`(up to f)` SHALL narrow the moving set to the flap `f`, the layers outward of it (above for a fold placed on top, below for `mountain`) and every layer joined to those by a hinge off the axis. A point on a crease several flaps share SHALL be an error, and a crease as the depth SHALL need `moving` to walk inward from.

#### Scenario: The top layer alone
- **WHEN** a square folded with `fold (map .b onto .a)` is folded again with `fold (through .p .q) (moving .b) (up to .b) as --f`
- **THEN** only the corner of the top layer moves and the layer beneath it stays
- **AND** `--f` reads mountain

#### Scenario: A depth on a shared crease
- **WHEN** a program folds a square in half as `--d`, binds `.s = --d * --ab` and writes `fold (map .a onto .s) (moving .a) (up to .s)`
- **THEN** evaluation fails with ".s lies on a crease shared by 2 flaps" and the hint `name the flap with #[...]`

### Requirement: A placement places the moved layers and selects none
The placement items `mountain`, `over` and `under` SHALL say where the moving set lands in the stack and SHALL NOT change which layers belong to it, apart from the closure up to the target of a placed fold.

#### Scenario: mountain moves the same layers
- **WHEN** a program writes `fold (map .a onto .b) (moving .a) (mountain)`
- **THEN** the same layers move as without `(mountain)`, and the block lands underneath the paper it folded from

### Requirement: A mark without on scores every layer its line crosses
A `mark` without `on` SHALL score every layer under its line or its extent, one piece per flap whose image the extent meets. Its bundle SHALL hold those pieces.

#### Scenario: A mark through two layers
- **WHEN** a square is folded in half and a program marks a line that crosses both layers without `on`
- **THEN** the crease holds one piece on each layer

### Requirement: A mark with on scores the named flap alone
A `mark` with `(on f)` SHALL score the flap `f` and no other layer, also where creasing that flap on the closed model would move other layers hinged to it along the line. Such a mark SHALL stand for a crease made with the model opened partway, and the write SHALL succeed.

#### Scenario: One layer of the book fold
- **WHEN** a program writes `fold (map --ab onto --cd) (moving .a) as --m`, `.f = --m * --bc` and `mark (map --da onto --cd) (toward .f) (on #[.a]) as --x`
- **THEN** `--x` is scored on the layer that holds `.a` alone, and the write succeeds

#### Scenario: A point on a shared crease names no flap
- **WHEN** a square folded along `--bd` takes `mark (perp --bc through .r) (at .r) (on .m)` with `.m` on the hinge
- **THEN** evaluation fails with ".m lies on a crease shared by 2 flaps"

### Requirement: A placed fold takes the layers between its depth and its target
A fold placed `under T` SHALL also take every layer that lies above a face of the moving set and below every face of `T` it overlaps; a fold placed `over T` every layer that lies below a face of the moving set and above every face of `T` it overlaps. This step SHALL alternate with the closure under hinges off the axis until neither adds a face. `T` and the layers beyond it SHALL stay.

#### Scenario: The jumping frog tucks a raw-edged side
- **WHEN** step 13 of the traditional jumping frog writes `fold (map .r onto .mm) (up to #[.r .mm .o]) (under #[.mr .o .pbr]) as --s13r` on the side where the front and back layers end in raw edges
- **THEN** both layers of that side move under the front leg, and the fold succeeds

#### Scenario: A placed fold without up to
- **WHEN** a placed fold has no `up to`
- **THEN** its moving set is every layer on the moving side, and the placement adds nothing to it

### Requirement: unfold turns layers back over a scored crease
`unfold` SHALL take as its axis a crease the program has scored, named or narrowed with `&`. A construction as its axis SHALL be refused. `unfold` SHALL score no crease and SHALL refuse `as` and `into`.

#### Scenario: A construction as the axis
- **WHEN** a program writes `unfold (map .a onto .b) (moving .a)`
- **THEN** evaluation fails with "unfold opens hinges on a crease the program already has; it takes a crease, not a construction"

#### Scenario: An output clause on unfold
- **WHEN** a program writes `unfold (--q) (moving .b) as --x`
- **THEN** evaluation fails with "unfold scores no crease, so it takes no as or into"

### Requirement: unfold selects its layers by moving, up to and toward
`(moving p up)` SHALL take the flap of `p` and every layer above it, `(moving p down)` the flap and every layer below it, and `(moving p)` SHALL mean `up`. `(up to f)` SHALL name a deeper flap to grow from. Every layer joined to the selected ones by a hinge off the axis SHALL move with them. `(toward p)` alone SHALL keep the flap of `p` and the layers the same closure reaches inward from it, and move every other layer on its side.

#### Scenario: The layer of .b and the layers above it
- **WHEN** a square takes `fold (map .b onto .a) as --d`, `.m = --d * --ab`, `fold (map .m onto .a) as --q` and then `unfold (--q) (moving .b)`
- **THEN** `.b` lies at (1/2, 0) and `.a` at (0, 0)

#### Scenario: The layers below
- **WHEN** the same program ends with `unfold (--q) (moving .b down)`
- **THEN** `.a` and `.b` both lie at (1/2, 0)

#### Scenario: A layer that stays
- **WHEN** the same program ends with `unfold (--q) (toward .a)`
- **THEN** every layer but the one of `.a` turns over, and `.b` lies at (1/2, 0)

#### Scenario: toward names a moving layer
- **WHEN** an unfold names a layer with `toward` that its `moving` or `up to` selection would move
- **THEN** evaluation fails with "the layer of" the point "that toward names would turn with the moving layers"

### Requirement: unfold turns its layers as one block and opens the hinges on the axis
`unfold` SHALL reflect its moving set across the axis as one block, on top of the stack there with `up` and at the bottom with `down`. Every hinge on the axis between a moving and a staying layer SHALL open, and no hinge SHALL fold. An unfold with no folded hinge on the axis between a moving and a staying layer SHALL fail.

#### Scenario: Two hinges and one opens
- **WHEN** the two-fold program above ends with `unfold (--q) (moving .b)`
- **THEN** the hinge on `--q` between the moving layers and the bottom layer opens, and the hinge on `--q` among the moving layers stays folded

#### Scenario: Nothing to open
- **WHEN** an unfold selects every layer
- **THEN** evaluation fails with "no hinge on the axis lies between a layer that moves and one that stays, so unfold would open none"

### Requirement: unfold refuses a layer that would not cross the axis
An `unfold` SHALL fail where a moving layer runs across the axis, or lies beside a staying layer joined to it by a flat hinge on the axis; turning it over would fold that layer or that hinge, and the error SHALL name `fold`.

#### Scenario: A layer cut by the axis
- **WHEN** an unfold selects a layer that its axis cuts
- **THEN** evaluation fails with "a layer that unfold moves runs across the axis, so part of it would not cross it; unfold turns layers over whole" and the hint "fold along the line to crease that layer"

### Requirement: fold refuses a line with all of the paper on one side
A `fold` SHALL fail when every layer lies on one side of its line, and its message SHALL name `unfold`. A fold along hinges with paper on both sides SHALL fold: the hinges on the line between moving and staying layers SHALL open where they were folded and fold where they were flat.

#### Scenario: A fold along a crease every layer lies beside
- **WHEN** the two-fold program ends with `fold (--q) (moving .b)`
- **THEN** evaluation fails with an error that ends "write unfold"

### Requirement: fold and unfold keep their items apart
`fold` SHALL refuse a direction word on `moving`, `up` or `down`, with an error that says so. `unfold` SHALL refuse `(mountain)` with an error that names `(moving … down)`, and SHALL refuse `over` and `under`.

#### Scenario: mountain on unfold
- **WHEN** a program writes `unfold (--q) (moving .b) (mountain)`
- **THEN** evaluation fails with "unfold takes no (mountain): the direction of its layers goes on moving, as (moving … down)"

#### Scenario: A direction on fold
- **WHEN** a program writes `fold (--q) (moving .b down)`
- **THEN** evaluation fails with an error starting "fold takes no direction on moving"

### Requirement: A write is effective when it changes the state
A write SHALL be effective in a state when its value is a different state up to refinement. Scoring SHALL be the write that is never effective: a `mark` SHALL leave the state unchanged up to refinement and add only a crease value. A read SHALL be no write.

#### Scenario: A mark is not effective
- **WHEN** a program writes `mark (through .a .c) as --ac` on a square
- **THEN** the state is the square up to refinement, and `--ac` holds one piece

#### Scenario: A fold is effective
- **WHEN** a program writes `fold (map .a onto .c)` on a square
- **THEN** the state differs from the square up to refinement
