---
id: "0021"
title: "The reference documents replace SPECIFICATION.md"
date: 2026-09-13
status: accepted
---

# 0021: The reference documents replace SPECIFICATION.md

## Context

`spec/README.md` fixed one rule for the language documentation: there is one
living specification, `SPECIFICATION.md`, and every implementation slice
folds its language-facing content into it under a version tag. The rule was
aimed at fragmentation by increment, which had produced a per-slice spec
file for every feature before it.

Since then four reference documents have grown beside it, each with one
reader and one role: `MODEL.md` states what a program means, as numbered
definitions and lemmas that can be proven about; `KERNEL.md` states how
`packages/core` realizes those statements and where it stops short;
`BELOCH.md` states the language as the signature of the model and how the
written form reflects it; `FOLD.md` states the output contract. The model's
sections on values, reads and operations now carry the semantics that
`SPECIFICATION.md` §4 carried in prose.

`SPECIFICATION.md` holds four kinds of content today, and each has a better
home than a single file ordered by feature:

- semantics: what a write does, which layers move, how a letter is derived.
  This is the model.
- the language reference: the grammar, every keyword, how an operand
  resolves to a side and a flap, program structure (`def`, `apply`,
  `export`, temporary names), the error catalogue. This is what `BELOCH.md`
  announces it will grow into.
- implementation mechanics: the order in which checks run, the solver
  pipeline of `flatten`, the messages the evaluator ships. This belongs
  with the code, in the doc comments `KERNEL.md` embeds, or in `KERNEL.md`
  itself as a ceiling.
- history: the "since vX.Y" tags, retired forms, the appendix of things not
  yet in the language. This is a changelog and an issue list.

Keeping the file alive beside the four documents means every semantic
change is written twice, once as a statement and once as prose, and the two
drift. It also leaves the reference content, the one kind the model does not
cover, buried in a file that reads as the semantics.

## Decision

The four reference documents are the specification. `SPECIFICATION.md` is
dissolved into them and deleted once empty.

- `MODEL.md` is the meaning. A semantic claim that is not a statement of the
  model is not part of the contract.
- `BELOCH.md` is the language reference: one section per sort and per
  write, each with the model statement it realizes, the concrete syntax, the
  resolution rules for its operands, its errors, and a worked example
  rendered from the program. The grammar appendix moves here whole.
- `KERNEL.md` takes the implementation mechanics that are worth stating as
  ceilings; the rest stays in doc comments and reaches the site through the
  API register.
- Version history moves to the log and the changelog; the appendix of
  deferred features moves to issues, one per entry.

The rule of `spec/README.md` is restated: the documents are divided by role
and reader, never by increment. A slice that changes the language edits the
document whose role it touches and adds no file.

A manual is a separate document with a separate reader, ordered by the
folder's tasks rather than by the language's structure. It is written after
the crane path runs, so that it promises no example the language cannot
fold.

## Migration order

The reference content must arrive in `BELOCH.md` before `SPECIFICATION.md`
shrinks, so that at no point the grammar is nowhere.

1. `BELOCH.md` absorbs the grammar, keywords, resolution rules, program
   structure and error catalogue, section by section, each pointing at its
   model statement. The corresponding sections of `SPECIFICATION.md` are
   deleted as they land.
2. Mechanics move to `KERNEL.md` or to doc comments; history to the
   changelog and to issues.
3. `SPECIFICATION.md` is deleted; the twenty-odd links to it in ADRs, design
   documents, notes and the README are redirected to the section that now
   holds the content.

## Alternatives considered

- **Keep `SPECIFICATION.md` as the single source and treat the four
  documents as commentary.** Rejected: the model is the part that can be
  checked, cited by id, and realized by `@see` tags in the kernel; prose that
  restates it is the copy that drifts.
- **Shrink `SPECIFICATION.md` to the language reference and keep the name.**
  Rejected: that document already exists as `BELOCH.md`, which is the
  language as the model's signature. Two documents for the surface would
  reproduce the drift this decision removes.
- **Delete `SPECIFICATION.md` now and migrate afterwards.** Rejected: the
  grammar and the error catalogue live nowhere else yet.

## Consequences

- `spec/README.md` changes from "one living specification" to the division
  by role. This ADR is the record that reverses that rule.
- `BELOCH.md` grows from a sketch into the reference and becomes the
  document a graphical editor binds its actions to, as it announces.
- Until step 3 completes, `SPECIFICATION.md` is in transit: a section that
  has moved is gone from it, a section that has not is still authoritative
  for the surface, never for the meaning.
- Links from 25 files have to be redirected at deletion. Design documents
  under `docs/superpowers/specs/` are point-in-time and may keep dead
  section numbers; ADRs, notes and `spec/` itself are updated.
- The number 0021 was informally reserved for the diagram annotation schema;
  that decision takes the next number when it is written.
