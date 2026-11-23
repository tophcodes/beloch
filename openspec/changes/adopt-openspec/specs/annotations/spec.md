# Spec Delta

## Purpose

What a program tells its reader beyond the geometry: the annotation lines, their fixed vocabulary, the namespaced annotations of output libraries, the credits of a program, and the rule that no annotation changes the folded result.

## ADDED Requirements

### Requirement: An annotation is a source line that belongs to the statement after it
An annotation SHALL be one line of the source that starts with `@` and ends with the line; a `;` comment may follow it. It SHALL belong to the statement after it. In a `def` body it SHALL apply once per `apply` that runs the body. After the last statement of the program or of a body it SHALL belong to the state there, and a `step` or `label` with no statement after it SHALL be an error.

#### Scenario: An annotation before a fold
- **WHEN** a program reads `@say "Fold in half."` on the line before `fold (map .a onto .c)`
- **THEN** the sentence belongs to that fold

#### Scenario: An annotation in a body applied twice
- **WHEN** a `def` body holds `@label petal` before its fold and the program applies the `def` twice
- **THEN** the label names the fold of each execution, once per execution

#### Scenario: A label at the end of the program
- **WHEN** `@label done` is the last line of a program
- **THEN** the program is rejected with an error at the annotation

### Requirement: An annotation never changes the geometry
The front end SHALL separate the annotations from the program, and the geometric evaluation SHALL run on the program without them. A program with its annotations removed SHALL evaluate to the same FOLD file without `beloch:annotations` and without `file_author`. A test SHALL hold the kernel to this rule.

#### Scenario: The invariance test
- **WHEN** the kernel suite replaces every annotation of a program with spaces, which keeps every span and line, and evaluates both versions
- **THEN** the two FOLD documents are equal once `beloch:annotations` and `file_author` are removed from both

### Requirement: An annotation without a namespace takes a key of the fixed vocabulary
An annotation without a namespace SHALL take one of the keys `step`, `label`, `say`, `call`, `orient`, `author`, `design` and `source`, with the arguments the key admits. Another key, or arguments that do not fit the key, SHALL be an error. `TEXT` SHALL be text in double quotes on one line, with `\"` and `\\` as its only escapes.

#### Scenario: An unknown key
- **WHEN** a program writes `@colour .a "red"`
- **THEN** the program is rejected with an error at the annotation

#### Scenario: A text that runs past its line
- **WHEN** a `@say` text has no closing quote on its line
- **THEN** the program is rejected with a syntax error that names the closing quote

### Requirement: A label names one statement in its scope
A label, the word of a `label` or of a `step`, SHALL be unique among the labels at the top level, and among those of one `def` body, where it names one statement per execution. Labels SHALL stand apart from the names of points, lines, defs and instances, so that a label shadows none of them.

#### Scenario: Two labels with one word
- **WHEN** two top-level `@label prelim` annotations stand in one program
- **THEN** the program is rejected with an error at the second

#### Scenario: A label that shares a point's name
- **WHEN** a program writes `@label a` and also uses the point `.a`
- **THEN** both names hold, and the label does not shadow the point

### Requirement: A step group groups and scopes nothing
A `step` SHALL open a step group that runs from the statement after it to the next `step` in execution order, or to the end of the program. Groups SHALL NOT nest and SHALL scope nothing: names bound inside a group stay visible after it. Statements before the first `step` SHALL belong to no group, and an output shows each write among them as a step of its own.

#### Scenario: A name bound inside a step group
- **WHEN** `.o = --h * --v` stands in the group of `@step prelim` and a later group reads `.o`
- **THEN** the later statement resolves `.o`

### Requirement: An annotation's value is a read against the next state
A value of an annotation SHALL be any read of the language, a name, a selector, a meet or a construction. It SHALL be evaluated against the state the following statement starts from, or the state an annotation at the end belongs to. A read that fails SHALL be an error at the annotation.

#### Scenario: A value that names an unbound point
- **WHEN** a program writes `@call .z "tip"` and binds no point `.z`
- **THEN** the program is rejected with an error at the annotation

### Requirement: An output annotation carries a namespace and the kernel checks only its shape
An annotation whose key carries a namespace, as in `@yr:hold .a`, SHALL belong to the output library that owns the namespace. The kernel SHALL NOT know its key; it SHALL check that every argument is a value, resolve it and pass the annotation on. A bare word SHALL NOT be an argument of such an annotation; a keyword is passed as text.

#### Scenario: An unknown key of an output
- **WHEN** a program writes `@yr:hodl .a`
- **THEN** the kernel accepts it and passes it into the FOLD file, and only the YR library can report the key

#### Scenario: A bare word as argument
- **WHEN** a program writes `@yr:arrow push`
- **THEN** the program is rejected with an error at the argument, and `@yr:arrow "push"` passes

### Requirement: Three keys credit the program as a whole
The keys `author`, `design` and `source` SHALL belong to the whole program. `author` takes `TEXT`, who wrote the program. `design` takes the word `traditional` for a model with no known designer, or `TEXT` naming the designer. `source` takes `TEXT` naming a published sequence the program follows, in whatever form names it for a reader.

#### Scenario: The credits of the crane
- **WHEN** a program opens with `@author "Claude (Anthropic)"`, `@design traditional` and `@source "[ida2020, Fig. 7.19]"`
- **THEN** the program evaluates and its credits name the author, a traditional design and the source

### Requirement: Credits stand at the top level before the first statement
`author`, `design` and `source` SHALL stand at the top level before the first statement, at the head of the file before `unit`, the shapes and `paper`, or right after `paper`. `author` and `design` SHALL stand once each and `source` once per sequence. One in a `def` body, one after the first statement and a second `author` or `design` SHALL be errors that name the key.

#### Scenario: A credit after the first statement
- **WHEN** `@source "[ida2020]"` stands after `fold (map .a onto .c)`
- **THEN** the program is rejected with an error that names `source`

#### Scenario: Two designs
- **WHEN** a program states `@design traditional` and then `@design "Yoshizawa"`
- **THEN** the program is rejected with an error that names `design`

#### Scenario: A library file of shapes
- **WHEN** a file of shapes such as the standard library states `@author` at its head
- **THEN** the kernel accepts it

### Requirement: The language asks for no credits
The kernel SHALL accept a program that states none of `author`, `design` and `source`. A rule that requires them belongs to a repository that keeps programs, outside the language.

#### Scenario: A scratch program
- **WHEN** a program outside the repository states no credits
- **THEN** it evaluates as it would with them, without an error or a warning

