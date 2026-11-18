---
id: BEP-0051
title: "A program states who wrote it, who designed its model and what it follows, as annotations of the program"
date: 2026-10-02
status: accepted
issue: tophcodes/beloch#206
---

# BEP-0051: A program states who wrote it, who designed its model and what it follows, as annotations of the program

The architecture part of this decision is [[ADR-0068]].

## Context

An annotation ([[BEP-0029]]) belongs to the statement after it, or at the end of
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

## Alternatives considered

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

- A `design` or `source` changes no geometry, and an output library can show
  the credit beside a drawing, which [[ADR-0019]] asks of Beloch's own tools.
