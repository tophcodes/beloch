---
id: ADR-0062
title: "Records live apart from the pages, and a record's name carries its kind"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#291
---

# ADR-0062: Records live apart from the pages, and a record's name carries its kind

This record amends [[ADR-0054]] in two points: where the records live,
and how a link names a record. The four kinds of page and the id links
between pages stay as [[ADR-0054]] has them.

## Context

[[ADR-0054]] puts every prose document under `docs/` and calls it one
of four kinds of page (guide, manual, reference, explanation) or a record.
The four kinds come from Diátaxis, which orders documentation by what its
reader needs and has no place for decisions or a journal. The records serve
another reader: whoever works on Beloch and asks why it is the way it is.
Under one tree the two orders read as one list of nine places, and a page
for readers sits beside records that no reader of the site sees.

`docs/decision/` holds two sorts of record under one name. Architecture
records decide how Beloch is built: OCaml for the kernel ([[ADR-0001]]),
exact rationals for coordinates ([[ADR-0008]]), the module boundaries
of the core ([[ADR-0018]]). Language records decide what a program
means: which layers a fan moves ([[BEP-0037]]), what `on` scores
([[BEP-0039]]), which names a trim exports ([[BEP-0047]]). An
inventory of the 59 records counts 21 architecture records, 23 language
records and 9 that decide both.

A language record states its rule in the terms of the reference, and the
reference states the same rule ([[ADR-0032]]). The rule then stands in
two places. A later record replaces single sentences of an earlier one, as
[[BEP-0037]] does for [[BEP-0036]], so the record side of a rule
is a chain, and where record and reference disagree nothing says which one
a reader trusts: the squash of [[BEP-0061]] passes a letter to its fan,
while `def-squash` in the model gives it none.

Python and Rust give the two jobs to two documents. A proposal (a PEP, an
RFC) argues for a change, and nobody edits it once it is accepted; PEP 1
calls an accepted PEP "a historical document rather than a living
specification". The language reference states the current rule.

A record's number tells nothing of its kind. "0037" is an ADR only because
of the directory that holds it, and a diff, an editor tab or a search hit
shows the number without the directory.

Beloch keeps three places for what it will not do: `notes/ideas.md` for
ideas set aside, `notes/antipatterns.md` for dead ends, and the records'
own "Alternatives considered".

## Decision

**`records/` holds the records, and `docs/` holds the pages.** `docs/` holds the
pages a reader of the site reads, in the four kinds of [[ADR-0054]].
`records/` holds what the project keeps for itself, in three kinds:

- **ADR** (`records/adr/`): a decision about how Beloch is built, how the
  project works or how its documents are ordered.
- **BEP**, Beloch Evolution Proposal (`records/bep/`): a decision about
  what a program means.
- **Journal** (`records/notes/`): a dated entry of thinking in progress, the
  failing example, the spike, the half-formed idea.

The reference is a page and the binding specification at once
([[ADR-0032]]); it is the one place where the two trees meet.

**A record decides one kind of thing.** A decision that is both
architecture and language is two records, one of each kind.

**A record's name carries its kind.** ADRs and BEPs draw their numbers from
one counter, and the kind stands before the number with a hyphen, in
capitals: `BEP-0037`. The name is the record's id, the start of its file
name (`BEP-0037-which-layers-a-fan-moves.md`), the `id` field of its
frontmatter and the start of its heading:
`# BEP-0037: Which layers a fan moves`. A link names a record by its id alone, `[[BEP-0037]]` and
`[[ADR-0008]]`, with `#` and an anchor where it enters the record; the
directory takes no part in it. A journal entry keeps the id `notes/<stem>`.

**The reference states every rule; a BEP keeps the reasons.** The pull
request that adds a BEP also edits `docs/reference/`, and the BEP names the
reference sections it changed. Nobody edits a BEP's prose after it is
accepted. A later BEP that changes part of the rule edits the reference and
names the earlier BEP under `amends`; the earlier BEP stays accepted.

**A BEP shows before it states.** Its sections, in order: **Summary**, the
decision in two or three sentences without terms the reader has to look
up; **Example**, a program on a real model with its folded state and layer
order, and what the rule makes of it; **Rule**, the text that went into the
reference, with an id link to each section it changed; **Alternatives
considered**; **Open questions**, each naming its issue; **Consequences**.
A BEP's title names its subject ("Which layers a fan moves").

**An ADR or a BEP is in one of four states.**

| State | Where it is | Who moves it there |
|---|---|---|
| proposed | in an open pull request, never on `main` | its author, by opening the pull request |
| accepted | the directory of its kind | the maintainer, by merging the pull request |
| superseded | `archive/` of its kind | the pull request that adds the record replacing it |
| abandoned | `archive/` of its kind | the maintainer, by merging the record with this state |

The directory carries the state, and the frontmatter field `status` repeats
it. A superseded record names its successor in `superseded-by`. An
abandoned record is a proposal that was argued and rejected; it keeps its
sections and adds **Why abandoned**. A pull request that closes without a
merge leaves no record. A later record that amends an accepted one may
change that record's frontmatter (its `checks`, its `status`), never its
prose.

**What Beloch will not do has one place per reason.** A proposal argued and
rejected is an abandoned record, and an approach that failed while
building is one too, written as the proposal it was. An idea set aside
untried is an issue with the label `parked`. `notes/ideas.md` and
`notes/antipatterns.md` end.

## Alternatives considered

- **Keep both trees under `docs/` and separate them in the README only.**
  Rejected: the path is what a search hit, a diff and the site build see,
  and under one tree a record and a page differ by nothing they see.
- **Keep one kind of record and mark language records by a field.**
  Rejected: the field is invisible in every place the number is, and the
  two kinds need different sections.
- **Number in the file name, kind in the directory, as Rust (`text/`) and
  Swift (`proposals/`) do.** Rejected: each of those repositories holds one
  kind of record; Beloch holds two that share a counter, and a bare number
  in a diff or a tab names neither.
- **Keep the link form `[[BEP-0037]]` of [[ADR-0054]].** Rejected:
  a link that names the directory breaks when a record changes kind, and
  `[[BEP-0037]]` is found by the same search as the file.
- **Edit an accepted BEP when its rule changes, as Oxide does with a
  committed RFD.** Rejected: the BEP would be the reference, and two
  documents would state one rule.
- **Keep `notes/antipatterns.md` beside abandoned records.** Rejected: an
  argued idea would have two places, and a search for it finds one of them.

## Consequences

- One change moves the records: `docs/decision/` to `records/adr/` and
  `records/bep/`, `docs/notes/` to `records/notes/`, every record renamed
  to its id, and every link to a record rewritten. The check of
  [[ADR-0054]] that keeps every prose tree under `docs/` changes with
  it. `CLAUDE.md`, the README of each tree and the scripts that name the
  paths follow.
- Each of the nine records that decide both kinds splits. The language
  part keeps the number and becomes a BEP; the architecture part becomes an
  ADR with the next number and names the record it came from.
- The entries of `notes/antipatterns.md` and `notes/ideas.md` move to
  abandoned records and to issues one by one. An entry that was never
  argued as a proposal, such as those inherited from the 2018 attempt, needs
  a decision of its own about where it goes.
- `scripts/id-links.ts` reads `records/` and resolves `[[ADR-NNNN]]` and
  `[[BEP-NNNN]]` by the start of the file name.
- The issue template `design` asks whether the answer is an ADR or a BEP.
- This record states the rule for its own kind of decision and becomes
  `records/adr/ADR-0062-…` in the move.
