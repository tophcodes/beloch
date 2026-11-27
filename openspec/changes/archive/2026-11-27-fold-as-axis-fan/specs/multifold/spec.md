## ADDED Requirements

### Requirement: A fold is the fan at the point at infinity of its axis
`fold` and `unfold` SHALL fold through the fan whose vertex lies at the point at infinity of their axis: one line, the two half-planes as its sectors, and every layer the axis crosses under the vertex. The moving set SHALL be the tip. A cut hinge SHALL fold, and a hinge on the axis between the tip and a layer that stays SHALL change. `unfold` SHALL be that fan on a tip the axis cuts nowhere, so that it scores no crease and only opens hinges.

#### Scenario: A corner folds through both layers
- **WHEN** a square is folded with `fold (map .b onto .a)` and the program writes `fold (through .p .q) (moving .b) as --f`, `.p` and `.q` a quarter along `--bc` and `--ab` from `.b`
- **THEN** each piece of the corner moves by the reflection across `--f`, the one changing hinge on its paper path

#### Scenario: An unfold opens the hinge it crosses
- **WHEN** a square takes `fold (map .b onto .a) as --d` and then `unfold (--d) (moving .b)`
- **THEN** the fan opens the hinge on `--d` and the square lies flat
