---
id: ADR-0068
title: "The FOLD carries a program's credits, and the repository's check requires them"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#206
checks:
  - desc: Every .bel file states its author; every program in examples/ states its design and a source whose cite keys are in references.bib
    run: 'bash scripts/check-program-credits.sh'
---

# ADR-0068: The FOLD carries a program's credits, and the repository's check requires them

This record holds the architecture part of [[BEP-0051]], which decided both kinds.

## Context

Every `.bel` file in the repository opened with the comment `; AI-generated:
this file was written by Claude (Anthropic).` No tool reads a comment, so
nothing checked that the line was there, and a FOLD file evaluated from the
program did not carry it.

[[ADR-0049]] asks a program in `examples/` to cite the sequence it folds and to
credit the designer of a model that has one. The citation sat in the head
comment, where a regular expression looked for something shaped like a cite
key, and no program said whether its model is traditional. [[ADR-0019]] asks for
a declaration of who designed a model that the emitter carries into every
export, and left its syntax to the annotations.

## Decision

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

## Consequences

- A FOLD file evaluated from a program with its annotations removed differs
  in `file_author` too, besides `beloch:annotations`. The invariance test of
  [[BEP-0029]] compares the documents without both.
- Programs outside the repository need no credits. The kernel accepts a
  program without them; only the repository's `check` requires them.
- This record's check replaces the citation check of [[ADR-0049]].
