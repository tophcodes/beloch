# Spec Delta

## Purpose

How Beloch reports a program to its author: an error as a span, a message and a hint, a warning on a program that runs, the first warning, and the fields that carry both in the FOLD file.

## ADDED Requirements

### Requirement: A rejected program is reported as a span, a message and an optional hint
A rejected program SHALL be reported as a span, a message and an optional hint. The message SHALL state what is wrong in the terms of the program as written. The hint SHALL state one thing the author can write instead and may quote code; an error without a useful suggestion has no hint. No message SHALL carry a suggestion of its own.

#### Scenario: An unknown annotation key
- **WHEN** a program writes `@colour .a "red"`
- **THEN** the message reads `unknown annotation @colour`
- **AND** the hint lists the vocabulary and names the namespaced form, and the message holds no suggestion

#### Scenario: The error catalog
- **WHEN** a reader opens the error catalog of the language
- **THEN** it quotes each error's message and hint in separate columns

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

### Requirement: The FOLD carries the warnings and the error
A FOLD file SHALL carry `beloch:warnings`, a list in statement order, each entry with the `message`, the `hint`, the `span` and the `statement` index, with and without `--trace`, and absent when the list is empty. A FOLD file of a failed program, written with `--trace`, SHALL carry `beloch:error` with the same four fields for the failing statement.

#### Scenario: A program without warnings
- **WHEN** a program runs and reports no warning
- **THEN** its FOLD file has no field `beloch:warnings`

#### Scenario: A traced failure
- **WHEN** `beloch fold --trace` runs a program whose third statement fails
- **THEN** the file carries `beloch:error` with the message, the hint, the span and the index of the failing entry in `beloch:statements`

