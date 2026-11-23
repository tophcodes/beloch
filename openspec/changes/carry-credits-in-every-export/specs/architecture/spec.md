## ADDED Requirements

### Requirement: Declared credits reach every export without loss
Every SVG and PNG that Beloch writes from a program, through `beloch render` or the export of the playground, SHALL carry the credits the program declares, who wrote it, who designed its model and which sequence it follows, without loss, as text a reader of the file finds without drawing it. A program without credits SHALL export none. Introduced by the change carry-credits-in-every-export; the design of the change adopt-openspec gives the reason under ADR-0019.

#### Scenario: An SVG of a credited program
- **WHEN** `beloch render` draws a program that states `@author "Ann"` and `@design traditional` as SVG
- **THEN** the SVG file holds the text of both credits in its metadata

#### Scenario: A PNG of a credited program
- **WHEN** `beloch render` draws the same program as PNG
- **THEN** the text chunks of the PNG file hold both credits

#### Scenario: The playground's download
- **WHEN** the playground downloads the SVG of a program that states `@source "[ida2020, Fig. 7.19]"`
- **THEN** the SVG file holds the source in its metadata

#### Scenario: A program without credits
- **WHEN** `beloch render` draws a program that declares no credits
- **THEN** the SVG file holds no credit
