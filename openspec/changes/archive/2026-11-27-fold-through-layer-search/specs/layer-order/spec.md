## ADDED Requirements

### Requirement: The search decides every side no condition decides
The sides the three conditions leave open SHALL be searched, however many groups of layers they form: every combination that gives a flat state SHALL count. One state left SHALL be the result. Several states left SHALL be an error that states their number.

#### Scenario: Several stackings
- **WHEN** a placed fold leaves 2 combinations of open sides that both fold flat
- **THEN** evaluation fails with "layer ordering: the moved layers fold flat in 2 stackings; nothing in the state decides on which side of them some layers they land on lie"

#### Scenario: Many open groups
- **WHEN** a flap folds over a comb placed `over` one square of its spine, and 13 teeth folded onto the spine each leave a pocket the flap may go into
- **THEN** the search finds 8192 states, one per choice of pockets

## MODIFIED Requirements

### Requirement: A verb gives the units of its fan's layer search
The layer search of a fan SHALL order the units the verb gives. Two overlapping faces of one unit SHALL keep their side, exchanged where the unit turns over; the side of two faces of different units SHALL be open or fixed by a condition of the verb. `flatten` and `squash` SHALL give the pieces of one motion as units, the faces the fan leaves in place forming one piece. `fold` SHALL give the faces that stay and each moved block as units, and a block placed on top of the model or under it SHALL fix its side against every face it lands on.

#### Scenario: A flatten keeps a piece together
- **WHEN** a `flatten` moves two overlapping faces by the same motion
- **THEN** the two faces keep their side in the result, exchanged where the motion turns them over

#### Scenario: A plain fold leaves the search nothing to decide
- **WHEN** a square takes `fold (map .b onto .a)`
- **THEN** the layer search gets the side of the moved half above the half that stays, and returns that one state

## REMOVED Requirements

### Requirement: A side no condition decides is the folder's choice
**Reason**: It bounds the search at 10 groups of layers whose side nothing decides, a bound only a placed fold had; `flatten`, `squash` and `reverse` search without one.
**Migration**: None. A placed fold that failed with "the kernel searches at most 10" now folds, or fails with the number of its stackings. Requirement "The search decides every side no condition decides" keeps the rest of the rule.
