## ADDED Requirements

### Requirement: The library that owns a namespace reads its annotations
An output library SHALL read the annotations of the namespace it owns and SHALL decide what a key of that namespace it does not know means for it. The YR library SHALL own the namespace `yr`, and its diagram SHALL report a `yr` key it does not know and draw the program as it would without that annotation.

#### Scenario: An unknown key of the YR library
- **WHEN** `beloch render --view yr` draws a program that writes `@yr:hodl .a`
- **THEN** standard error carries a hint that names the key `yr:hodl` and its line
- **AND** the diagram is the one the program draws without the annotation

#### Scenario: A namespace the YR library does not own
- **WHEN** `beloch render --view yr` draws a program that writes `@cp:hold .a`
- **THEN** the YR diagram reports nothing about the annotation
