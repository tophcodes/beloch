---
id: "0032"
title: "The specification binds every implementation; the kernel document describes one"
date: 2026-09-27
status: accepted
---

# 0032: The specification binds every implementation; the kernel document describes one

This record supersedes ADR 0021 and carries forward its migration of
`SPECIFICATION.md`, which is still under way.

## Context

ADR 0021 made four reference documents the specification: `MODEL.md`,
`BELOCH.md`, `KERNEL.md` and `FOLD.md`. Three of them state what any
implementation of Beloch has to do. `KERNEL.md` states how one
implementation, the OCaml kernel in `packages/core`, holds a state in memory,
which model statements it realizes and where it stops short. Its own opening
settles the order between them: when the kernel and the model disagree, the
kernel has a bug.

Counting `KERNEL.md` into the specification would bind a second
implementation to the data structures and ceilings of the first. The site
repeats the error: its navigation lists all four documents under one heading,
so a reader cannot tell the contract from the notes on one realization of it.

`BELOCH.md` is also due to grow by most of `SPECIFICATION.md`: the grammar,
the keywords, the resolution rules, program structure and the error
catalog. One page of that size is hard to navigate.

## Decision

**The specification is three documents.** Every implementation of Beloch is
bound by them:

- `MODEL.md` is the meaning. A semantic claim that is not a statement of the
  model is not part of the contract.
- `BELOCH.md` is the language: one section per sort and per write, each with
  the model statement it realizes, the concrete syntax, the resolution rules
  for its operands, its errors, and a worked example rendered from the
  program. The grammar appendix of `SPECIFICATION.md` moves here whole.
- `FOLD.md` is the output format.

**The reference implementation is documented beside the specification and
binds nothing.** `KERNEL.md` describes the OCaml kernel: how it represents
the model's states, which statements each part realizes, and its ceilings.
The command-line interface of the `beloch` binary is documented in the same
group. A statement in these documents that contradicts the specification is a
bug in the implementation or a gap in the model, never a rule.

**The language may span several pages.** It is divided along its own
sections, by sort, by write, and with the collected grammar and the error
catalog on pages of their own. It is never divided by layer into
vocabulary, syntax and semantics: each construct keeps its syntax,
resolution, errors and example together, and its meaning stays in the model.

The rule of `docs/reference/README.md` holds: the documents are divided by role and
reader, never by increment. A slice that changes the language edits the
document whose role it touches.

A manual is a separate document with a separate reader, ordered by the
folder's tasks rather than by the language's structure. It is written after
the crane path runs, so that it promises no example the language cannot
fold.

## Migration of `SPECIFICATION.md`

`SPECIFICATION.md` is dissolved and deleted once empty. The reference
content must arrive in the language document before `SPECIFICATION.md`
shrinks, so that at no point the grammar is nowhere.

1. The language document absorbs the grammar, keywords, resolution rules,
   program structure and error catalog, section by section, each pointing
   at its model statement. The corresponding sections of `SPECIFICATION.md`
   are deleted as they land.
2. Implementation mechanics worth stating as ceilings move to `KERNEL.md`,
   the rest to doc comments that reach the site through the API register.
   Version history moves to the changelog, the appendix of deferred features
   to issues, one per entry.
3. `SPECIFICATION.md` is deleted; the links to it in ADRs, notes, the README
   and `docs/reference/` are redirected to the section that now holds the content.

Until step 3 completes, a section still in `SPECIFICATION.md` is
authoritative for the surface syntax, never for the meaning.

## Alternatives considered

- **Keep the four documents as one specification (ADR 0021).** Rejected:
  it makes the representation choices of one kernel normative.
- **Name the model something other than a specification, since it reads as
  a mathematical theory.** Rejected: its form is a theory, its role is the
  contract. It binds an implementation more strictly than the grammar does.
- **Split the language document by layer into vocabulary, grammar and
  semantics.** Rejected: every construct would be spread over three pages,
  and the semantics already has its document in the model.
- **Keep `SPECIFICATION.md` as the single source and treat the other
  documents as commentary.** Rejected in ADR 0021 and still rejected: the
  model is the part that can be checked, cited by id, and realized by `@see`
  tags in the kernel; prose that restates it is the copy that drifts.

## Consequences

- The site's navigation has two groups: the specification (model, language,
  output format) and the reference implementation (kernel, command-line
  interface).
- File names and URLs of the documents stay as they are.
- `KERNEL.md` may name modules, functions and data structures freely; the
  three specification documents name none of them as requirements.
- Splitting the language document touches everything that reads
  `BELOCH.md` as one file: the reference corpus, the grammar register and
  the collected grammar.
