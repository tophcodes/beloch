# reverse-fold Specification

## Purpose
The `reverse` write: the opening at which the tip splits into two blocks, the placement of the blocks for inside and outside reverse folds, and the letter item that picks one opening.

## Requirements

### Requirement: A reverse fold opens its tip at one opening
An opening SHALL be a place between two consecutive layers of the tip where every hinge joining a layer below to a layer above is folded and lies on one table line, the spine. The opening SHALL cut the tip into a lower and an upper block, each reflected across the axis as a whole. Every hinge across the opening SHALL turn, every other hinge of the tip SHALL keep its letter, and the axis SHALL become a crease through every layer of the tip.

#### Scenario: The preliminary base by two inside reverse folds
- **GIVEN** `paper square` and `fold (map .a onto .c) as --bd`
- **WHEN** `reverse (map .b onto .c) as --h` and `reverse (map .d onto .c) as --v` run
- **THEN** `.b` and `.d` land on `.c`, and the state has 6 faces

#### Scenario: An outside reverse
- **GIVEN** a square folded in half
- **WHEN** `reverse (map .a onto .d) (outside)` runs
- **THEN** both blocks wrap around the body, `.a` lands on `.d`, and the state has 4 faces

### Requirement: Inside and outside place the blocks at their bodies
For `inside`, the lower block SHALL land over its body and the upper block under its body, in the gap between the two bodies. For `outside`, the lower block SHALL go under every face that stays and the upper block over them. An opening whose two bodies are empty or interleaved SHALL give no state.

#### Scenario: Interleaved bodies
- **WHEN** the only opening of a reverse fold joins its blocks to interleaved layers
- **THEN** the fold fails with `the two halves are hinged to interleaved layers; that is not a reverse fold`

### Requirement: A tip with several openings needs a letter
A reverse fold whose tip opens at more than one place SHALL fail, and the hint SHALL offer one letter item per opening: a letter on a hinge of the spine, named by its crease and a point on it. A letter item SHALL keep the openings after which each hinge it names has that letter.

#### Scenario: A square folded in half twice
- **GIVEN** a square folded in half along `--d`, then in half again along `--e` in the same direction, `.q` on `--cd`
- **WHEN** `reverse (map .a onto .d)` runs
- **THEN** it fails with `the tip opens at 2 places`

#### Scenario: The letter picks the inner opening
- **WHEN** `reverse (map .a onto .d) (--e & .q valley)` runs on the same square
- **THEN** the tip opens between its two inner layers, both hinges on the spine turn, and the state has 8 faces

#### Scenario: The letter picks the outer opening
- **WHEN** `reverse (map .a onto .d) (--e & .q mountain)` runs
- **THEN** the tip opens below its outermost layer, and the three inner layers of the lower half go in as one block

### Requirement: A reverse fold is the fan where its axis meets its spine
A reverse fold SHALL be the fan at the point where its axis meets the line of its spine, a point of the projective table. A reverse fold whose axis meets that line off the paper, or runs parallel to it, SHALL fold through the same fan.

#### Scenario: An axis parallel to the crest
- **GIVEN** a square folded in half along `--d`
- **WHEN** `reverse (through .m .n) (moving .t) as --r` runs along a line parallel to `--d`
- **THEN** the strip between the axis and the crest goes in between the two layers, and each layer takes a crease on the axis

### Requirement: A reverse fold folds without an outline
A reverse fold SHALL keep its states whether or not they reach past the convex hull of the state before it; the outline ranking of `flatten` and `squash` SHALL not apply.

#### Scenario: A tip reversed past the outline
- **WHEN** a reverse fold carries its tip beyond the outline of the state before it
- **THEN** the write keeps the state of its opening as its value
