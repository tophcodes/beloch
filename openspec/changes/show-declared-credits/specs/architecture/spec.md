## ADDED Requirements

### Requirement: Beloch's own tools show declared credits by default
The playground, the document cards and the renderers this project ships SHALL show the credits a program declares, by default, beside what they draw. Introduced by the change show-declared-credits; the design of the change adopt-openspec gives the reason under ADR-0019.

#### Scenario: The playground draws a credited model
- **WHEN** the playground draws a program that states `@design traditional` and `@source "[ida2020, Fig. 7.19]"`
- **THEN** the design and the source appear beside the drawing without a setting turned on

#### Scenario: A program without credits
- **WHEN** the playground draws a program that declares no credits
- **THEN** no credit line appears beside the drawing
