---
id: "0051"
title: "A program states who wrote it, who designed its model and what it follows, as annotations of the program"
date: 2026-10-02
status: accepted
issue: tophcodes/beloch#206
checks:
  - desc: Every .bel file states its author; every program in examples/ states its design and a source whose cite keys are in references.bib
    run: 'bash scripts/check-program-credits.sh'
---

# 0051: A program states who wrote it, who designed its model and what it follows, as annotations of the program

## Context

Every `.bel` file in the repository opened with the comment `; AI-generated:
this file was written by Claude (Anthropic).` No tool reads a comment, so
nothing checked that the line was there, and a FOLD file evaluated from the
program did not carry it.

[[decision/0049]] asks a program in `examples/` to cite the sequence it folds and to
credit the designer of a model that has one. The citation sat in the head
comment, where a regular expression looked for something shaped like a cite
key, and no program said whether its model is traditional. [[decision/0019]] asks for
a declaration of who designed a model that the emitter carries into every
export, and left its syntax to the annotations.

An annotation ([[decision/0029]]) belongs to the statement after it, or at the end of
a program to the final state. Who wrote a program, who designed its model and
which diagram it follows are facts about the whole program, and no statement
is their target.

## Decision

**Three annotation keys belong to the program as a whole.**

- `author` takes `TEXT`: who wrote the program.
- `design` takes the word `traditional`, for a model with no known designer,
  or `TEXT` naming the designer.
- `source` takes `TEXT`: a published sequence the program follows, in
  whatever form names it for a reader.

**They stand at the top level before the first statement**: at the head of
the file, before `unit`, the shapes and `paper`, or after `paper`. `author`
and `design` stand once each; `source` stands once per sequence the program
follows. The kernel refuses one in a `def` body, one after the first
statement and a second `author` or `design`, each with an error that names
the key. A library file of shapes carries them at its head.

**The FOLD carries them.** `author` fills FOLD's own `file_author`. All three
appear in `beloch:annotations` with the target `"program"`, a string where
the other annotations have a range of statements, or null at the end of a
program.

**`check` enforces a convention of this repository.** The language asks
for none of the three. In this repository every `.bel` file states
`author`, and every program in `examples/` states `design` and at least one
`source`. A source cites in the repository's bracket form inside the text,
`@source "[ida2020, Fig. 7.19]"`, and every cite key in its brackets names an
entry of `bibliography/references.bib`. The kernel checks the form and the
place of the annotations; the script checks that they are there and that
the cite keys resolve. The `author` annotation replaces the
`; AI-generated` header comment.

## Alternatives considered

**Keep the comment header.** It costs nothing and every file has it. Nothing
reads it: a file without it passes every check, and a FOLD file evaluated
from the program says nothing about who wrote it.

**A cite key as the argument of `source`.** The kernel could take a
`WORD` and the script look it up. A cite key means something only beside
one bibliography, and the language would be tied to this repository's.
Text names a source for any reader, and a repository that keeps a
bibliography checks its own form of citation inside the text.

**Put the credits in the bibliography only.** A model's entry in
`bibliography/references.bib` could name its designer and the program's
author. Most programs are test cases with no entry, the FOLD file would not
carry the credit, and a reader of the program would have to look in a second
file.

## Consequences

- A FOLD file evaluated from a program with its annotations removed differs
  in `file_author` too, besides `beloch:annotations`. The invariance test of
  [[decision/0029]] compares the documents without both.
- A `design` or `source` changes no geometry, and an output library can show
  the credit beside a drawing, which [[decision/0019]] asks of Beloch's own tools.
- Programs outside the repository need no credits. The kernel accepts a
  program without them; only the repository's `check` requires them.
- This record's check replaces the citation check of [[decision/0049]].
