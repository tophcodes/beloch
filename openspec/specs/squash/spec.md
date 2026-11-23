# squash Specification

## Purpose
The `squash` write: its bare alignment item, how it finds its spine, vertex and axis, which part holds it still, and the condition that its two flanks fold as valleys.

## Requirements

### Requirement: squash takes a bare alignment of its spine
`squash` SHALL take one item, a bare alignment written without `map` or `align`: a line on the spine, then `onto`, then the target, a line or a point. The write SHALL complete the alignment with the fold line through the vertex. A construction in its place SHALL be refused, and so SHALL every other item.

#### Scenario: Onto a line
- **GIVEN** the preliminary base with `--ac` marked
- **WHEN** `squash (--h & --da onto --ac) as --s` runs
- **THEN** the front flap on the side of `--da` opens onto the center line, and the state has 10 faces

#### Scenario: Onto a point
- **WHEN** `squash (--h & --da onto .m)` runs with `.m` on `--ac`
- **THEN** it folds the same state as the squash onto `--ac`

#### Scenario: A construction as item
- **WHEN** `squash (map --h onto --ac)` runs
- **THEN** it fails with `squash completes the alignment with the fold line through the vertex; it takes no construction`

### Requirement: The squash finds its spine by incidence
The spine SHALL be the folded hinge on the named line whose one end lies inside the paper and on no raw edge, and whose target lies on its flap's side of the spine's line. The anchor SHALL be the flap of the upper face at that hinge. Several flaps with such a spine SHALL make the squash ambiguous, and the hint SHALL name the items that keep one.

#### Scenario: Two flaps on one edge
- **GIVEN** the preliminary base, whose front and back flaps on that side have spines on one table edge
- **WHEN** `squash (--h onto --ac)` runs
- **THEN** it fails with `squash is ambiguous: 2 flaps have a spine on --h that lands on --ac`
- **AND** the hint names each flap by its spine filtered by a line through its far end

### Requirement: The axis of a squash bisects the spine and its target at the vertex
The vertex SHALL be the end of the spine inside the paper. The axis SHALL be the line through the vertex that reflects the far end of the spine onto the target's ray, a bisector of the spine's line and the target's line. With a target point, a crease through the vertex and the point SHALL exist, and the write SHALL score the axis as one crease with a piece on each layer of the flap.

#### Scenario: A target point without a crease
- **WHEN** `squash (--h & --da onto .n)` runs and no crease lies on the line from the vertex through `.n`
- **THEN** it fails with `no crease lies on the line from the vertex through .n`, hint `mark it first`

#### Scenario: One piece of the axis
- **WHEN** a squash binds its axis `as --s`
- **THEN** `--s & #[.p]` names the piece of the axis on the layer of `.p`

### Requirement: A spine with two inner ends is refused
A squash whose spine has both ends inside the paper SHALL fail: which end is the vertex is not decided.

#### Scenario: Both ends inside
- **WHEN** a squash names a spine whose two ends lie inside the paper
- **THEN** it fails with `both ends of the spine on <l> lie inside the paper; which one is the vertex is not decided`

### Requirement: The flap beyond the target line holds the squash
Where part of the anchor flap lies beyond the target's line, the squash SHALL fold the fan at the vertex with rays on the spine, the axis and the target's line: the sector of the anchor beyond the target's line, away from the spine, SHALL stay, the spine SHALL open, each layer of the tip SHALL fold along its piece of the axis, and the anchor's hinge on the target's line SHALL fold.

#### Scenario: The front flap of the preliminary base
- **WHEN** `squash (--h & --da onto --ac)` runs on the preliminary base
- **THEN** the half of the front face beyond `--ac` keeps its place, and the flap's two layers fold along the two pieces of the axis

### Requirement: The layers a flap is hinged to hold its squash
Where no part of the anchor flap lies beyond the target's line, the faces that hinges on that line join to the anchor and to the flap of the lower face at the spine SHALL stay. The tip SHALL be every piece of both flaps; the spine SHALL open, each flap SHALL fold along its piece of the axis, and each hinge on the target's line between tip and stayer SHALL keep or change. A flap with neither material beyond nor a hinge on that line SHALL fail.

#### Scenario: Randlett's first squash
- **WHEN** `fold (map .a onto .c) as --bd`, `fold (map .b onto .d) as --ac`, `squash (--bd & --bc onto --ac) as --s` run
- **THEN** the state has 6 faces, `.b` lies at (1, 1) and `.a` on `.b`
- **AND** the upper layer of the flap turns over `--ac`, its hinge to the bottom layer opening flat, and the lower layer folds in half

#### Scenario: Nothing holds the squash
- **WHEN** the flap has no material beyond the target line and no hinge on it
- **THEN** the squash fails with `the flap has no material beyond <target>; nothing holds the squash`

### Requirement: A squash folds both flanks as valleys
The two pieces of the axis, the flanks of the opened spine, SHALL fold as valleys: of the states the fan folds flat in, the squash SHALL keep those with both flanks valleys. More than one state left SHALL fail with `squash is ambiguous: <n> realizations`.

#### Scenario: The front flap of the preliminary base
- **WHEN** `squash (--h & --da onto --ac)` runs, whose four creases fold flat in 8 states
- **THEN** the squash keeps the one state with both flanks valleys and `--ac` under the flap a mountain

#### Scenario: The swivel fold
- **WHEN** the same creases are written as `flatten (--h & --da) (--s & --da mountain) (--t & --da valley) (--ac & .a valley) (staying .q)`
- **THEN** the swivel states with one flank a mountain are reached, which `squash` does not give

### Requirement: A squash folds toward the viewer
Where the lower layer of the flap runs on beyond the target line and the upper layer does not, the squash SHALL fail and name the side, with the hint `flip first`.

#### Scenario: The second squash of the preliminary fold without a flip
- **WHEN** `fold (map .d onto .b) as --ac`, `fold (map .a onto .c) as --bd`, `squash (--ac & --ab onto --bd) as --s1`, `squash (--ac & --bc onto --bd) as --s2` run
- **THEN** the second squash fails with `the squash of --ac & --bc onto --bd folds from the other side of the model`, hint `flip first`

#### Scenario: With the flip
- **WHEN** a `flip` stands between the two squashes
- **THEN** both squashes fold
