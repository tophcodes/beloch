# layer-order Specification

## Purpose
How a write decides which of two overlapping faces lies above the other in its result: only from faces that overlap and the creases between them, the conditions that fix sides, the search over open sides, and the units a verb gives that search.

## Requirements

### Requirement: A fold orders two faces only where they overlap
When a write places or pushes paper between layers, the side of every layer the moved paper lands on SHALL follow from the paper: from faces that overlap and from the creases between them. The result SHALL never depend on an order of two faces that do not overlap, so two routes to one state SHALL give the same results for the same write.

#### Scenario: The crane's neck on both routes to the bird base
- **WHEN** the bird base is folded once by reverse folds and once by two petal folds, the legs are narrowed, and each program writes `reverse (perp --n1 through .sr) (moving .b) as --neck`
- **THEN** both fail with "the tip opens at 3 places": in the middle, between the top 2 layers and the 6 beneath them, and between the bottom 2 layers and the 6 above them

### Requirement: Three conditions decide the side of a layer the moved paper lands on
The kernel SHALL decide sides by three conditions, applied until no side changes: the moved paper lies directly on the layers it is placed or pushed between; a layer under or over one of those, where the three share a region, lies on the same side of the moved paper; a layer across a crease lies on one side of both faces that meet in it, folded or flat. Where two conditions give one layer opposite sides, the write SHALL fail.

#### Scenario: Every side decided on the crane's neck
- **WHEN** the crane's neck is reversed with `reverse (perp --n1 through .sr) (moving .b) (--n1 & .pn mountain) (--n3 & .pn3 mountain) as --neck`
- **THEN** the three conditions decide the side of every layer the tip lands on, and the reverse fold yields one state

### Requirement: A placed block lies directly on every face of its target flap
A fold placed `over` or `under` a flap SHALL lay the moved block directly on every face of that flap it lands on, above every such face for `over` and below every such face for `under`. The faces of one flap lie flat as one piece of paper, and the block SHALL lie on all of them alike.

#### Scenario: A pocket tuck
- **WHEN** a square folded with `fold (map .a onto .d)` takes `fold (through .m .n) (moving .b) (up to .b) (under .p)` with `.p` on the top layer away from its corner `.b`
- **THEN** the corner lies directly under every face of the flap of `.p` it lands on, between the two layers
- **AND** the crease it scores reads valley, since the layer of `.p` lies face down

### Requirement: Results that agree on every overlapping pair are one state
Where a write finds several results, two results that order every overlapping pair of faces alike SHALL be one state, and the write SHALL return it. No stacking of the results SHALL be compared.

#### Scenario: Two openings with one state
- **WHEN** two openings of a reverse fold give results that agree on every overlapping pair
- **THEN** the reverse fold returns that one state and reports no ambiguity

### Requirement: A verb gives the units of its fan's layer search
The layer search of a fan SHALL order the units the verb gives. Two overlapping faces of one unit SHALL keep their side, exchanged where the unit turns over; the side of two faces of different units SHALL be open or fixed by a condition of the verb. `flatten` and `squash` SHALL give the pieces of one motion as units, the faces the fan leaves in place forming one piece. `fold` SHALL give the faces that stay and each moved block as units, and a block placed on top of the model or under it SHALL fix its side against every face it lands on.

#### Scenario: A flatten keeps a piece together
- **WHEN** a `flatten` moves two overlapping faces by the same motion
- **THEN** the two faces keep their side in the result, exchanged where the motion turns them over

#### Scenario: A plain fold leaves the search nothing to decide
- **WHEN** a square takes `fold (map .b onto .a)`
- **THEN** the layer search gets the side of the moved half above the half that stays, and returns that one state

### Requirement: A reverse fold gives three units per opening
A reverse fold SHALL give the layer search three units per opening: the faces that stay and each of its two blocks. Its conditions SHALL fix the side of the two blocks, the lower one below, and the sides that `inside` or `outside` gives each block against its body. The search SHALL decide the rest.

#### Scenario: Each layer of the strip goes in beside its own layer
- **WHEN** a square takes `fold (map .b onto .a) as --d`, `.m = free on --ab from .a at 3/8`, `.n = free on --cd from .d at 3/8`, `.t = free on --d from .[--d --ab] at 1/2` and `reverse (through .m .n) (moving .t) as --r`
- **THEN** read from the bottom the state is the bottom layer, the lower layer of the strip, the upper layer of the strip, the top layer
- **AND** `--d` takes the other letter

### Requirement: The search decides every side no condition decides
The sides the three conditions leave open SHALL be searched, however many groups of layers they form: every combination that gives a flat state SHALL count. One state left SHALL be the result. Several states left SHALL be an error that states their number.

#### Scenario: Several stackings
- **WHEN** a placed fold leaves 2 combinations of open sides that both fold flat
- **THEN** evaluation fails with "layer ordering: the moved layers fold flat in 2 stackings; nothing in the state decides on which side of them some layers they land on lie"

#### Scenario: Many open groups
- **WHEN** a flap folds over a comb placed `over` one square of its spine, and 13 teeth folded onto the spine each leave a pocket the flap may go into
- **THEN** the search finds 8192 states, one per choice of pockets
