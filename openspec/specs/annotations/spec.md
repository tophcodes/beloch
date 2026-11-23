# annotations Specification

## Purpose
What a program tells its reader beyond the geometry: the annotation lines, their fixed vocabulary, the namespaced annotations of output libraries, the credits of a program, and the rule that no annotation changes the folded result.

## Requirements

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

### Requirement: The key step makes its group one step for the reader
`@step` SHALL take an optional `WORD` and an optional `TEXT`, in that order. It SHALL open a step group, whose statements an output shows as one step: the word labels the step as `@label` labels a statement, and the text is the instruction for the whole step. At most one `step` SHALL stand before one statement.

#### Scenario: A step of two folds in the YR diagram
- **WHEN** `@step "Fold in half twice."` stands before two folds
- **THEN** the YR diagram gives both folds one step number and shows the sentence under the first panel of that step

#### Scenario: A text before the word
- **WHEN** a program writes `@step "Fold in half." half`
- **THEN** the program is rejected with an error that reads `@step takes an optional label and an optional text, in that order`

#### Scenario: Two steps before one statement
- **WHEN** `@step one` and `@step two` stand on consecutive lines before one fold
- **THEN** the program is rejected with the error `a statement opens at most one step` at the second

### Requirement: A label names one statement in its scope
`@label` SHALL take one `WORD`, which names the statement after it so that an output can refer to it. A label, the word of a `label` or of a `step`, SHALL be unique among the labels at the top level, and among those of one `def` body, where it names one statement per execution. Labels SHALL stand apart from the names of points, lines, defs and instances, so that a label shadows none of them.

#### Scenario: Two labels with one word
- **WHEN** two top-level `@label prelim` annotations stand in one program
- **THEN** the program is rejected with an error at the second

#### Scenario: A figure of a document shows a labeled statement
- **WHEN** a figure block of a document writes `at="choose"` and its program writes `@label choose` before a fold
- **THEN** each view of the figure that shows one statement shows that fold

#### Scenario: A label that shares a point's name
- **WHEN** a program writes `@label a` and also uses the point `.a`
- **THEN** both names hold, and the label does not shadow the point

### Requirement: A step group groups and scopes nothing
A `step` SHALL open a step group that runs from the statement after it to the next `step` in execution order, or to the end of the program. Groups SHALL NOT nest and SHALL scope nothing: names bound inside a group stay visible after it. Statements before the first `step` SHALL belong to no group, and an output shows each write among them as a step of its own.

#### Scenario: A name bound inside a step group
- **WHEN** `.o = --h * --v` stands in the group of `@step prelim` and a later group reads `.o`
- **THEN** the later statement resolves `.o`

### Requirement: The key say gives the instruction sentence for a statement
`@say` SHALL take one `TEXT`: the instruction sentence for the statement after it. After the last statement of the program or of a body it SHALL be the sentence for the state there, such as the name of the finished model.

#### Scenario: A sentence for a fold outside any step group
- **WHEN** `@say "Fold in half."` stands before a fold that belongs to no step group
- **THEN** the YR diagram shows the sentence under the panel of that fold

#### Scenario: A sentence for the final state
- **WHEN** `@say "The finished crane."` is the last line of a program
- **THEN** the YR diagram shows the sentence under the panel of the final state

#### Scenario: A say without a text
- **WHEN** a program writes `@say .a`
- **THEN** the program is rejected with an error that reads `@say takes one text`

### Requirement: The key call names an entity for the reader
`@call` SHALL take a value that reads a point, a line or a flap, and a `TEXT`: the name a reader knows that entity by. The value SHALL be read against the state the statement after it starts from, and `beloch:annotations` SHALL carry the entity it reads with the text. Two entities MAY carry the same text.

#### Scenario: A named corner
- **WHEN** `@call .a "top corner"` stands before a fold
- **THEN** `beloch:annotations` holds a `call` entry whose arguments are the point with its paper and its table coordinates and the text `top corner`

#### Scenario: One name on two points
- **WHEN** `@call .a "tip"` and `@call .b "tip"` stand before one fold
- **THEN** the program evaluates

#### Scenario: A call without a value
- **WHEN** a program writes `@call "tip"`
- **THEN** the program is rejected with an error that reads `@call takes a point, a line or a flap, and the text a reader knows it by`

### Requirement: The key orient turns the drawing on the page
`@orient` SHALL take a point and a direction, two points and a direction, or a line and an axis; a direction is `up`, `right`, `down` or `left`, an axis `vertical` or `horizontal`, both on the page. With one point, the direction from the centroid of the outline of the folded state to the point SHALL be the direction the annotation names; with two points, the direction from the first to the second. A line SHALL be a single table line, and it SHALL lie along the axis.

#### Scenario: One point and a direction
- **WHEN** `@orient .a up` stands before a fold
- **THEN** the drawing of the state that fold starts from turns so that the direction to `.a` from the centroid of the area the state covers on the table, each point counted once however many layers lie on it, points up

#### Scenario: A line and an axis
- **WHEN** `@orient --l vertical` stands before a fold
- **THEN** of the two rotations that lay `--l` vertical, the drawing takes the one that differs less from the rotation in force before

#### Scenario: A crease a fold has bent
- **WHEN** a program writes `@orient --bd vertical` after a fold has bent `--bd`
- **THEN** the program is rejected with the error `--bd is bent by a fold` at the line

#### Scenario: A word that is no direction
- **WHEN** a program writes `@orient .a sideways`
- **THEN** the program is rejected with an error that names the three forms, the directions and the axes

### Requirement: An orientation holds until the next orient
The rotation an `@orient` fixes on the state its values are read against SHALL turn the drawing of that state and of every later state, until the next `@orient`. The YR diagram and the view `folded` of the command line SHALL turn their drawing. The frames of the FOLD SHALL stay where the evaluator put them.

#### Scenario: Two points and a direction
- **WHEN** `@orient .o .c down` stands before a reverse fold
- **THEN** the YR diagram turns the panel of that fold so that `.c` lies straight below `.o`, and turns every later panel by the same rotation up to the next `@orient`

#### Scenario: The frames of the FOLD
- **WHEN** a program with an `@orient` evaluates
- **THEN** its frames are those of the same program without the annotation

### Requirement: An annotation's value is a read against the next state
A value of an annotation SHALL be any read of the language, a name, a selector, a meet or a construction. It SHALL be evaluated against the state the following statement starts from, or the state an annotation at the end belongs to. A read that fails SHALL be an error at the annotation.

#### Scenario: A value that names an unbound point
- **WHEN** a program writes `@call .z "tip"` and binds no point `.z`
- **THEN** the program is rejected with an error at the annotation

### Requirement: An output annotation carries a namespace and the kernel checks only its shape
An annotation whose key carries a namespace, as in `@yr:hold .a`, SHALL be an annotation of an output. The kernel SHALL NOT know its key; it SHALL check that every argument is a value, resolve it and pass the annotation into `beloch:annotations`. A bare word SHALL NOT be an argument of such an annotation; a keyword is passed as text.

#### Scenario: An unknown key of an output
- **WHEN** a program writes `@yr:hodl .a`
- **THEN** the kernel accepts it and passes it into `beloch:annotations` with its namespace `yr` and its key `hodl`

#### Scenario: A bare word as argument
- **WHEN** a program writes `@yr:arrow push`
- **THEN** the program is rejected with an error at the argument, and `@yr:arrow "push"` passes

### Requirement: Three keys credit the program as a whole
The keys `author`, `design` and `source` SHALL belong to the whole program and to none of its statements. Together they credit the program: who wrote it, who designed its model and which published sequences it follows.

#### Scenario: The credits of the crane
- **WHEN** a program opens with `@author "Claude (Anthropic)"`, `@design traditional` and `@source "[ida2020, Fig. 7.19]"`
- **THEN** the program evaluates and its credits name the author, a traditional design and the source

### Requirement: The key author names who wrote the program
`@author` SHALL take one `TEXT`, the name of who wrote the program.

#### Scenario: An author without quotes
- **WHEN** a program writes `@author Ann`
- **THEN** the program is rejected with an error that reads `@author takes one text, the name of who wrote the program`

### Requirement: The key design names who designed the model
`@design` SHALL take the word `traditional` for a model with no known designer, or a `TEXT` naming the designer.

#### Scenario: A designer without quotes
- **WHEN** a program writes `@design Yoshizawa`
- **THEN** the program is rejected with an error that reads `@design takes the word traditional or one text, the name of the model's designer`

### Requirement: The key source names a published sequence the program follows
`@source` SHALL take one `TEXT` naming a published sequence the program follows, in whatever form names it for a reader.

#### Scenario: A program that follows two sequences
- **WHEN** a program opens with `@source "[ida2020, Fig. 7.19]"` and `@source "[lang2011secrets]"`
- **THEN** the program evaluates and `beloch:annotations` holds both entries

#### Scenario: A source without quotes
- **WHEN** a program writes `@source ida2020`
- **THEN** the program is rejected with an error that reads `@source takes one text, the published sequence the program follows`

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
- **THEN** it evaluates as it would with them, without an error
