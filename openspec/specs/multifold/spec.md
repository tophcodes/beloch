# multifold Specification

## Purpose
The fan that `flatten` folds at a paper point, in one vertex or several, and the fan machinery `reverse` and `squash` hand their anchor and vertex to: which parts move, how each piece moves, the stayer, and the items that narrow the flat states to one.

## Requirements

### Requirement: A fan folds at a point of the paper
The vertex of a `flatten` fan SHALL be a paper point, and the fan SHALL fold at its table position. `(fan at .p …)` names the vertex; otherwise the vertex SHALL be the paper point where the bundles of the rays meet. Where the rays meet at no common paper point, or at more than one paper point over one table position, the statement SHALL fail.

#### Scenario: The rays pick the layer of a book fold
- **GIVEN** a square folded in half as a book, with four rays near its corner marked `(on #[.a])` on the upper layer alone
- **WHEN** `flatten (--pp & --ab mountain) (--r4 & --ab) (--dg & .a valley) (--r2 & --da) (staying .z)` runs
- **THEN** the corner of the upper layer folds onto the top of the stack
- **AND** the corner of the lower layer stays flat at the bottom of the stack

#### Scenario: The same rays marked on the lower layer
- **WHEN** the four rays are marked `(on #[.d])` on the lower layer and the flatten names them
- **THEN** the corner of the lower layer folds and the upper corner stays on top of the stack

#### Scenario: Rays that meet at two paper points
- **WHEN** the pieces of every ray pass through two paper points over the table vertex and no `fan at` names one
- **THEN** the statement fails with `the vertex lies at several points of the paper`

### Requirement: A ray folds the pieces of its bundle that pass through the vertex
A ray SHALL be a bundle, and the fan SHALL fold the pieces of that bundle that pass through the vertex. A hinge on the table line of a ray that does not pass through the vertex SHALL keep its angle. A ray of a fan item with no piece through the vertex SHALL fail the statement.

#### Scenario: A crease through two layers folds in one of them
- **GIVEN** a square folded in half along `--s`, `.v` the middle of `--s`, `--k` scored through both layers, `--m1` and `--m2` scored on the top layer alone
- **WHEN** `flatten (--s & .r) (--k & .c valley) (--m1 mountain) (--m2 valley) (staying .d)` runs
- **THEN** the bottom layer folds along `--k`, and the piece of `--k` from `.v` to `.b` in the top layer stays flat
- **AND** the top layer folds along `--m1` and `--m2`, and `--s` opens right of `.v` and stays folded left of it

#### Scenario: A fan ray that misses the vertex
- **WHEN** a ray of a fan item names a crease that has no piece through the fan's vertex
- **THEN** the statement fails with `<ray> passes through no point of the vertex`

### Requirement: A fan moves every part the stayer does not hold
The paper SHALL be cut into parts by the hinges of the fan; a path between two pieces crosses hinges and never runs through a single point. Every part other than the stayer SHALL be the tip and move. A tip that holds a layer under the vertex on which no hinge of the fan lies SHALL fail the statement, and the error SHALL name that layer.

#### Scenario: A single sheet
- **WHEN** a flatten folds a fan on the flat sheet
- **THEN** the parts are the sectors between the rays, and every sector but the stayer moves

#### Scenario: The spine drags an unfolded layer
- **GIVEN** a 2:1 rectangle folded in half, the waterbomb creases marked on the top layer alone
- **WHEN** a flatten folds them with `(staying .b .c)`, the sector along the raw edges
- **THEN** the statement fails with `the layer of .a lies under the vertex and moves, but no ray of the fan folds it`

### Requirement: A fan with up to folds every layer down to a flap
A fan item with `(up to <flap>)` SHALL stand for one fan per layer under the vertex's table position, from the topmost layer down to the named flap, each at the paper point of its layer with the same rays. The layers of that stack SHALL keep their order relative to each other in every sector, except a pair an `over` item orders. A layer that faces the other way than the topmost one SHALL take each letter the other way round.

#### Scenario: Fisher's waterbomb base through both layers
- **GIVEN** a 2:1 rectangle folded in half with the waterbomb creases marked through both layers and `.n` the vertex on the bottom layer
- **WHEN** `flatten (fan at .n (--d1 & --ab valley) (--d1 & .s1 valley) (--d2 & .s0 valley) (--d2 & --cd valley) (--v & --ab mountain) (--v & --cd mountain) (up to #[.a])) (staying .b .c)` runs
- **THEN** both layers fold as one stack into 12 faces
- **AND** the faces of the bottom layer in the staying sector stay with the staying face of the top layer

### Requirement: flatten takes no on item
A `flatten` SHALL refuse an `on` item: the vertex and the pieces of the rays through it decide which layers fold.

#### Scenario: A flatten written with on
- **WHEN** a statement `flatten (--a) (--b) (--c) (--d) (on #[.p])` runs
- **THEN** it fails with `flatten takes no (on) item`
- **AND** the hint points to `(staying .p)` and to `(up to <flap>)`

### Requirement: A fan with an anchor moves the tip of its anchor
For `reverse` and `squash`, the fan SHALL score the layers under it along its rays and call the pieces outside the stayer's wedge the candidates. The tip SHALL be the least set of candidates that holds the anchor's pieces and is closed under hinges of any angle between candidates. The tip SHALL move and every other layer SHALL stay, except where a squash's flap ends at its target line.

#### Scenario: One flap of the preliminary base
- **GIVEN** the preliminary base, whose front and back flaps on the side of `--da` both lie under the vertex
- **WHEN** `squash (--h & --da onto --ac)` runs
- **THEN** the front flap folds and the back flap stays in place

#### Scenario: A flap hinged beyond the fan
- **WHEN** a reverse fold turns a flap of several layers that a folded edge joins beyond its axis
- **THEN** every layer of that flap moves as one tip

### Requirement: A reverse or squash fan sits at a point of the projective table
`reverse` and `squash` SHALL hand the fan an anchor flap and a vertex on the projective table: a table point, or a point at infinity, one for each direction. At a point at infinity the lines of the rays SHALL be parallel and the sectors strips. Each layer of the tip SHALL be scored along the rays from that point.

#### Scenario: A reverse fold whose axis runs parallel to its spine
- **GIVEN** a square folded in half, right half onto the left, its crest `--d` at x = 1/2
- **WHEN** `reverse (through .m .n) (moving .t) as --r` runs along the line x = 3/8
- **THEN** the strip between the axis and the crest goes in between the two layers, and the state has 4 faces
- **AND** `--d` reads mountain and `--r` reads valley

### Requirement: The closure condition at the vertex applies inside the sheet
Kawasaki's condition at the vertex and the emergent ray SHALL apply only where the vertex lies inside the sheet; for `reverse` and `squash`, where the anchor's paper point under the vertex lies inside the sheet and on no folded hinge. A vertex on the paper's edge, off the paper or at infinity SHALL have no condition at the vertex; the closure of its paper paths still applies.

#### Scenario: A squash at the closed corner of a base
- **WHEN** `squash (--h & --da onto --ac)` folds at the closed corner of the preliminary base, where the tip's layers span a wedge of 45 degrees around the vertex
- **THEN** no angle condition runs at the vertex, and the squash folds

### Requirement: A fan moves each piece by the changing hinges on its paper path
The motion of a piece SHALL be the composition of the reflections across the changing hinges that a path on the paper crosses from the stayer to the piece, in order, and the identity on the stayer. A choice of hinges SHALL be a candidate only when every path gives each piece the same motion and some piece of the tip moves.

#### Scenario: Two pieces of one wedge move differently
- **WHEN** the squash of the front flap of the preliminary base is folded as a fan
- **THEN** a piece of the top layer turns by 45 degrees about the vertex, and the piece of the second layer at the same table point reflects across the axis

#### Scenario: A single sheet
- **WHEN** a fan folds on the flat sheet
- **THEN** each sector moves by the reflections across the rays between it and the stayer

### Requirement: The fan tries each hinge no item fixes both ways
A flat hinge of a ray's crease SHALL fold. A folded hinge of a ray's crease SHALL keep or open, and a hinge of another crease along a ray SHALL keep or change; each choice SHALL be a candidate fan. A folded hinge that keeps its angle MAY turn to the other letter.

#### Scenario: The spine of a squash written as a fan
- **WHEN** `flatten (--h & --da) (--s & --da mountain) (--t & --da valley) (--ac & .a valley) (staying .q)` runs on the preliminary base
- **THEN** the fan tries the folded spine `--h & --da` both kept and opened, and the states that fold flat open it

### Requirement: A letter holds at the lowest hinge of its ray
A letter item SHALL name the hinges of its crease on its ray in every layer. Of those hinges that do not open, the one whose face on the clockwise side of the ray lies lowest SHALL have that letter; the other hinges the item names SHALL take the letters the layer order gives them.

#### Scenario: A ray through two layers
- **WHEN** `(--bd & .b mountain)` names a ray whose crease has a hinge in two layers of the tip
- **THEN** the hinge whose clockwise face lies lower reads mountain, and the other hinge reads what the stacking gives it

### Requirement: flatten folds several fans in one motion
A `flatten` whose items start with the word `fan` SHALL fold every fan in one motion, each fan holding the rays of one vertex. The items `staying` and `over` SHALL stand beside the fans and apply to the whole statement.

#### Scenario: The petal fold
- **GIVEN** the preliminary base by a diagonal fold and two reverse folds, `--mid` through `.c` and `.o`
- **WHEN** `flatten (fan (--h & .sr) (map .sr onto --mid through .a valley) as .r) (fan (--v & .sl) (map .sl onto --mid through .a valley) as .l) (staying .o) as --pf` runs
- **THEN** the state has 11 faces and `--pf` reads mountain

### Requirement: A fan item names or binds its vertex
`(fan at .p ray+)` SHALL read a bound point as its vertex, and the statement SHALL fail when the rays do not pass through it. `(fan ray+ as .p)` SHALL bind the paper point where the rays meet to a new name; `as` is optional. A fan item SHALL never bind a name it reads.

#### Scenario: A named vertex off the rays
- **WHEN** `(fan at .p …)` names a point the rays do not pass through
- **THEN** the statement fails with `the rays of the fan do not meet at .p`

#### Scenario: A bound vertex
- **WHEN** `(fan (--h & .sr) (map .sr onto --mid through .a valley) as .r)` folds
- **THEN** `.r` names the paper point where the two rays meet

### Requirement: A ray of a fan item is a line or a construction
A ray of a fan item SHALL be a line operand or a construction, each with an optional letter. The statement SHALL score a construction before it folds, through every layer that meets at the vertex. `&` SHALL narrow a line to the half or the piece that holds the point it names.

#### Scenario: A lettered construction ray
- **WHEN** a fan item holds `(map .sr onto --mid through .a valley)`
- **THEN** the statement scores that line from the vertex through the layers that meet there and folds it as a valley

### Requirement: A crease between two vertices is a ray of both fans
The crease between two vertices SHALL be the paper segment between them. A statement where one fan names it and the other does not SHALL fail. In a statement of two fans where neither names it, the statement SHALL score the segment as one crease on both fans, and the output clause SHALL bind it. A statement of three or more fans SHALL derive no crease.

#### Scenario: The petal fold derives its crossing crease
- **WHEN** the petal fold names neither the segment between `.r` and `.l` in either fan
- **THEN** the statement scores that segment and binds it to `--pf`

#### Scenario: One fan names the shared crease
- **WHEN** one fan names the segment between the two vertices and the other does not
- **THEN** the statement fails with `a crease between two vertices is a ray of both fans`

### Requirement: A flatten takes ray items or fan items
A `flatten` SHALL take ray items or fan items and SHALL fail when it holds both. A statement of fan items SHALL hold at least two fan items or one with `up to`; one vertex without `up to` is written with ray items.

#### Scenario: Ray items beside a fan item
- **WHEN** a flatten holds `(fan …)` and a ray item `(--a)`
- **THEN** it fails with `a flatten takes ray items or fan items, not both`

#### Scenario: One fan item alone
- **WHEN** a flatten holds one fan item without `up to`
- **THEN** it fails, and the hint says to write the rays as items of the flatten or to add `(up to <flap>)`

### Requirement: staying names the part that holds every point
`(staying p1 … pn)` SHALL name the part of the paper whose closure holds every named point; a point on a ray lies in the parts on both sides of it. The statement SHALL fail when no part holds every point, when more than one does, and when `staying` stands more than once. A staying point MAY lie on any layer.

#### Scenario: Two points on the bounding rays
- **WHEN** the waterbomb fan on the top layer of a folded 2:1 rectangle runs with `(staying .s0 .s1)`
- **THEN** the sector along the spine stays and the top layer folds alone

#### Scenario: One point on a ray
- **WHEN** the same fan runs with `(staying .s0)`, `.s0` on a ray
- **THEN** it fails with `the staying points lie in more than one sector`

#### Scenario: Points in no common part
- **WHEN** the same fan runs with `(staying .b .s0)`
- **THEN** it fails with `no sector of the fan holds every staying point`

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

### Requirement: emergent beside names the wedge of the emergent ray
`(emergent beside .p)` SHALL keep the states whose emergent ray lies in a wedge between consecutive given rays that holds the table point of `.p`, the two bounding rays included. The item SHALL fail on an even fan, on a flatten of several fans, and when no state puts its emergent ray beside `.p`. It SHALL stand at most once.

#### Scenario: The rabbit ear toward a corner
- **WHEN** `flatten (--ea & .a valley) (--ec & .c) (--eb & .b valley) (staying .d) (emergent beside .a) as --ear` runs
- **THEN** the emergent ray runs from the incenter to `--ab`, and `--ear` reads mountain

#### Scenario: An even fan
- **WHEN** a flatten of four rays takes `(emergent beside .p)`
- **THEN** it fails with `flatten with an even ray count has no emergent ray`, hint `drop the emergent item`

### Requirement: An odd fan scores its emergent ray through every layer at the vertex
A fan with an odd number of rays inside the sheet SHALL add the emergent ray that closes the vertex, each of the two candidate positions a candidate fan, and SHALL score it through every layer that meets at the vertex. With an odd count, the crease the statement scores and binds SHALL be the emergent ray.

#### Scenario: The rabbit ear binds its emergent ray
- **WHEN** the rabbit ear flatten ends in `as --ear`
- **THEN** `--ear` names the emergent ray, and `--ear * --ab` finds where it reaches the edge

### Requirement: flatten takes no toward item
A `flatten` SHALL refuse a `toward` item; the side of an emergent ray is named with `emergent beside`, and other choices with letters.

#### Scenario: A flatten written with toward
- **WHEN** `flatten (--ea) (--ec) (--eb) (toward .a)` runs
- **THEN** it fails with `flatten takes no (toward) item: an item is a condition`
- **AND** the hint names `(emergent beside .p)` and letters

### Requirement: An over item orders the faces of its two points
`(.p over .q)` SHALL keep the states in which the face that holds `.p` lies above the face that holds `.q`, and the two faces SHALL overlap; no other face is compared. A point on a crease shared by two faces SHALL be an error. An item that no state satisfies, including a pair that overlaps in no state, SHALL fail with `` contradictory `over` ``.

#### Scenario: The swivel fold of a folded flap
- **GIVEN** the preliminary base and the swivel fan `flatten (--h & --da) (--s & --da mountain) (--t & --da valley) (--ac & .a valley) (staying .q)`, which leaves 2 states
- **WHEN** the statement adds `(.p over .w)`, `.p` in the moving flap and `.w` in a face of the staying part
- **THEN** one state is left, the one with the flap above the face of `.w`

#### Scenario: Two faces that lie apart
- **WHEN** an `over` item names two points whose faces overlap in no state
- **THEN** the statement fails with `` contradictory `over` ``

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

### Requirement: A fold is the fan at the point at infinity of its axis
`fold` and `unfold` SHALL fold through the fan whose vertex lies at the point at infinity of their axis: one line, the two half-planes as its sectors, and every layer the axis crosses under the vertex. The moving set SHALL be the tip. A cut hinge SHALL fold, and a hinge on the axis between the tip and a layer that stays SHALL change. `unfold` SHALL be that fan on a tip the axis cuts nowhere, so that it scores no crease and only opens hinges.

#### Scenario: A corner folds through both layers
- **WHEN** a square is folded with `fold (map .b onto .a)` and the program writes `fold (through .p .q) (moving .b) as --f`, `.p` and `.q` a quarter along `--bc` and `--ab` from `.b`
- **THEN** each piece of the corner moves by the reflection across `--f`, the one changing hinge on its paper path

#### Scenario: An unfold opens the hinge it crosses
- **WHEN** a square takes `fold (map .b onto .a) as --d` and then `unfold (--d) (moving .b)`
- **THEN** the fan opens the hinge on `--d` and the square lies flat
