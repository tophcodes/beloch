# Spec Delta

## Purpose

What the FOLD file shows of a program beyond its frames: the two axes of a position, the flat log of executed statements, the annotations field and the credits, and how a consumer joins them.

## ADDED Requirements

### Requirement: A position in a program is a pair of a state and a statement count
A position in a program SHALL be a pair: the folded state it stands in, and how many statements the program has run since that state began, written `2.3` for a reader. The FOLD file SHALL store no position; one pass over the entries of `beloch:statements` SHALL give both coordinates. A consumer that keeps a position SHALL keep the pair, since a decimal cannot tell `3.10` from `3.1`.

#### Scenario: A binding after a reverse fold
- **WHEN** the bird base runs `reverse (map .d onto .c) as --v` as its third write and then `.o = --h * --v`
- **THEN** the binding stands at position `3.1`, on the same paper as the reverse fold at `3.0`

### Requirement: The first axis counts writes
The first axis of a position SHALL count the writes, every `fold`, `reverse`, `flip`, `flatten` and `mark`. A `mark` SHALL count as a stop of the axis, though it leaves the state standing up to refinement, and its entry SHALL stay distinguishable from a write that moves the paper.

#### Scenario: A mark between two folds
- **WHEN** a program runs a `fold`, a `mark` and a second `fold`
- **THEN** the first axis stops three times, and a stepper shows the mark drawn on the placement of the first fold

### Requirement: The second axis counts every executed statement
The second axis SHALL count every statement in the order it runs, bindings and writes alike. A statement in a `def` body SHALL count once for every `apply` that runs it, and the `def` itself SHALL count nothing.

#### Scenario: A body applied twice
- **WHEN** a program applies a `def` of two statements twice
- **THEN** the second axis counts each body statement twice and the two `apply` statements once each

### Requirement: The FOLD logs every executed statement in one flat list
`beloch:statements` SHALL hold one entry per executed statement, in execution order, whatever the nesting in the source. Each entry SHALL carry its `kind` (a write, a binding or an `apply`), its `source_line` and its `span` where the statement is written, the `frame_index` of the frame it reads against, and its `parent`: the index of the `apply` entry it runs under, or null at the top level.

#### Scenario: A statement in a def body
- **WHEN** a body statement runs under the `apply` at entry 0
- **THEN** its entry has `parent` 0 and a span inside the `def`

#### Scenario: A top-level binding
- **WHEN** a program binds `.o = --h * --v` at the top level
- **THEN** `beloch:statements` holds an entry of kind `bind` with `parent` null

### Requirement: An apply entry precedes its body's entries and names its definition
An `apply` SHALL have an entry of its own before the entries of its body, naming the `def` it runs. Nested applications SHALL chain through the parent index. A consumer SHALL find a repetition by grouping the `apply` entries by the `def` they name.

#### Scenario: The petal fold applied twice
- **WHEN** a program runs `apply petal(.a)` and then `apply petal(.c)` over a body of two statements
- **THEN** entries 0 and 3 are `apply` entries that both name `petal`
- **AND** entries 1 and 2 name entry 0 as their parent, and entries 4 and 5 name entry 3

### Requirement: A consumer joins on the entry index
A consumer SHALL join the FOLD's fields to statements by their index into `beloch:statements`, since one span occurs once per `apply` that ran it and two statements may share a source line. `beloch:edges[].statement` SHALL name the statement that scored the edge. `beloch:named_points[].statement` and `beloch:named_lines[].statement` SHALL name the entry that binds the name, for a body the entry of the binding execution.

#### Scenario: Two statements on one source line
- **WHEN** a program writes two marks on one source line
- **THEN** the crease edges of each name their own entry in `statement`, and a consumer separates them by it

#### Scenario: A name bound in a body
- **WHEN** a body applied twice binds `.t`
- **THEN** the named point's `statement` is the entry of the execution that bound it

### Requirement: A reader accepts a FOLD written before the flat log
A reader SHALL treat an entry of `beloch:statements` without a `parent` as top-level and an entry without a `kind` as a write.

#### Scenario: An old FOLD file
- **WHEN** a reader opens a FOLD file whose entries carry neither `kind` nor `parent`
- **THEN** it reads every entry as a top-level write

### Requirement: The FOLD carries every annotation in one top-level field
`beloch:annotations` SHALL hold one entry per annotation in the order the statements ran, one in a `def` body once per execution. Each entry SHALL carry its `key`, its `namespace` or null, its `span`, its `source_line`, its `args` with their spans and resolved values, and its `target`: the first and the last index into `beloch:statements`, or null for an annotation at the end, whose state `frame_index` names.

#### Scenario: A step group's target
- **WHEN** `@step prelim` stands before three statements and a second `@step` follows them
- **THEN** the entry of `prelim` targets the first and the last of those three entries

#### Scenario: A sentence at the end of the program
- **WHEN** `@say "The crane."` follows the last statement
- **THEN** its entry has `target` null and the `frame_index` of the final state

### Requirement: The program's credits reach the FOLD
The text of `@author` SHALL fill FOLD's own `file_author`, absent when the program has none. `author`, `design` and `source` SHALL reach `beloch:annotations` with the target `"program"` and `frame_index` 0.

#### Scenario: The crane's credits in its FOLD
- **WHEN** `examples/crane.bel` evaluates
- **THEN** `file_author` holds the text of its `@author`
- **AND** `beloch:annotations` holds its `author`, `design` and `source` entries with the target `"program"`

