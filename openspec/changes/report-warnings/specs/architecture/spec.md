## ADDED Requirements

### Requirement: The command line prints a warning as it prints an error
The command line SHALL print each warning on standard error in its error block, headed `warning:`, with the hint as the `help:` line, and exit with 0 when the program runs. When `beloch fold --trace` runs a failing program, the warnings of the statements before the failing one SHALL come first, then the error. `beloch fold --watch` and `beloch render` of a `.bel` file SHALL print warnings the same way. Introduced by the change report-warnings; its design gives the reason under ADR-0067.

#### Scenario: A program with a warning
- **WHEN** `beloch fold` runs a program that warns and runs to its end
- **THEN** standard error shows a block headed `warning:` with a `help:` line
- **AND** the command exits with 0 and writes the FOLD file

#### Scenario: A traced program that warns and then fails
- **WHEN** `beloch fold --trace` runs a program whose second statement warns and whose fourth fails
- **THEN** the warning prints before the error, and the command exits with 1

### Requirement: The browser readers carry a warning as they carry an error
The browser evaluator's answer to a program that runs SHALL carry `warnings`, each with the message, the hint and the whole span, start and end. The playground SHALL show a warning where it would show an error, in a color of its own, and draw the program's result as usual. A language server SHALL report a warning with the severity Warning and the same span, with the hint where it puts an error's hint. Introduced by the change report-warnings; its design gives the reason under ADR-0067.

#### Scenario: The playground shows a warning
- **WHEN** the playground runs a program that warns
- **THEN** the offending word is underlined with the message and the hint in rows beneath it, in the warning color
- **AND** the drawing shows the program's result

#### Scenario: An answer from before warnings existed
- **WHEN** the playground reads an answer of the browser evaluator without the field `warnings`
- **THEN** it reads the answer as a run without warnings
