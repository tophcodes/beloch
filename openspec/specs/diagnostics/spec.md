# diagnostics Specification

## Purpose
How Beloch reports a program to its author: an error as a span, a message and a hint, and the field that carries a traced failure in the FOLD file.

## Requirements

### Requirement: A rejected program is reported as a span, a message and an optional hint
A rejected program SHALL be reported as a span, a message and an optional hint. The message SHALL state what is wrong in the terms of the program as written. The hint SHALL state one thing the author can write instead and may quote code; an error without a useful suggestion has no hint. No message SHALL carry a suggestion of its own.

#### Scenario: An unknown annotation key
- **WHEN** a program writes `@colour .a "red"`
- **THEN** the message reads `unknown annotation @colour`
- **AND** the hint lists the vocabulary and names the namespaced form, and the message holds no suggestion

#### Scenario: The error catalog
- **WHEN** a reader opens the error catalog of the language
- **THEN** it quotes each error's message and hint in separate columns

### Requirement: A traced failure carries its error in the FOLD
A FOLD file of a failed program, written with `--trace`, SHALL carry `beloch:error` with the `message`, the `hint`, the `span` and the `statement` index of the failing statement. A FOLD file of a program that runs SHALL carry no `beloch:error`.

#### Scenario: A traced failure
- **WHEN** `beloch fold --trace` runs a program whose third statement fails
- **THEN** the file carries `beloch:error` with the message, the hint, the span and the index of the failing entry in `beloch:statements`

#### Scenario: A traced program that runs
- **WHEN** `beloch fold --trace` runs a program to its end
- **THEN** its FOLD file has no field `beloch:error`
