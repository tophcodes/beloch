## ADDED Requirements

### Requirement: A warning reports a program that runs, in the shape of an error
A warning SHALL report an item of a program that runs to its end. It SHALL have the shape of an error: a span over the item, a message that states what the item does to the program, and an optional hint that states what to write instead. A warning SHALL change neither the program's result nor the exit code.

#### Scenario: A program that warns
- **WHEN** a program with one warning runs
- **THEN** it writes the same FOLD frames it writes without the warned item
- **AND** the command exits with 0

### Requirement: A warning names only what the author can drop or rewrite
A warning SHALL name only an item the author can drop or rewrite without changing what the program means, and its hint SHALL say how. Following the hint SHALL silence the warning. Warnings SHALL carry no codes, and no annotation or flag SHALL suppress one.

#### Scenario: Following the hint
- **WHEN** the author rewrites a program as a warning's hint says
- **THEN** the program means the same and the warning is gone

### Requirement: A redundant moving warns
A fold that names both `toward` and `moving` SHALL warn on its `moving` item when the selection without `moving` keeps the same candidate and folds over the same side, with a hint to drop the item. A `moving` in a fold without `toward` SHALL NOT warn, even where it names the side the default takes.

#### Scenario: A moving that agrees with toward
- **WHEN** a fold names `toward` and a `moving` that the selection would take without it
- **THEN** the program runs, and a warning on the `moving` item hints to drop it

#### Scenario: A moving without toward
- **WHEN** a fold names `moving` with the side the default would take and no `toward`
- **THEN** no warning is reported

### Requirement: The FOLD carries the warnings
A FOLD file SHALL carry `beloch:warnings`, a list in statement order, each entry with the `message`, the `hint`, the `span` and the `statement` index, as in `beloch:error`. The field SHALL appear with and without `--trace`, and SHALL be absent when the list is empty.

#### Scenario: A program without warnings
- **WHEN** a program runs and reports no warning
- **THEN** its FOLD file has no field `beloch:warnings`

#### Scenario: A program that warns, without trace
- **WHEN** `beloch fold` runs a program whose second statement warns, without `--trace`
- **THEN** its FOLD file carries `beloch:warnings` with one entry whose `statement` index is that of the second statement
