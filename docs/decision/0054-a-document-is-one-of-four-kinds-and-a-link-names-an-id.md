---
id: "0054"
title: "A document is one of four kinds, and a link names an id"
date: 2026-10-08
status: accepted
checks:
  - desc: Every prose tree lives under docs/
    run: '[ -d docs/reference ] && [ -d docs/decision ] && [ -d docs/notes ] && [ ! -e spec ] && [ ! -e decisions ] && [ ! -e notes ]'
---

# 0054: A document is one of four kinds, and a link names an id

This record keeps the division of ADR 0032 (the specification binds every
implementation, the kernel document describes one) and places it inside a
wider order. ADR 0032's manual, "a separate document with a separate reader,
ordered by the folder's tasks", gets its place here.

## Context

Beloch's prose lives in four places with four different orders. `spec/`
holds the reference, divided by role (ADR 0032). `decisions/` holds the
records of choices, numbered. `notes/` holds a dated design journal. The
site adds two guide pages of
its own and lists the reference under two headings, the specification and
the reference implementation, so its navigation sorts by what binds an
implementation.

The content planned for the coming years does not fit that order. A manual
of the folder's tasks (fold a base, choose among candidate lines, read an
error) has no place: the guide holds tutorials, and a task page is no
tutorial. An explanation of a choice (why seven axioms, why exact numbers,
how layers are modeled) has no place either: a decision record is a
protocol of one moment, and a note is a journal entry nobody publishes. The
rendering libraries and tools need pages of both kinds, and an API
reference, for a reader who embeds Beloch and never folds.

Diátaxis (diataxis.fr) sorts documentation by what the reader needs of it
along two axes, acting against understanding and learning against working,
into four kinds: tutorials, how-to guides, reference and explanation. Each
kind has its own form, and mixing two of them on one page serves neither
reader. Its own guidance warns against creating the four sections empty
and filling them by plan; the structure follows from the pages that exist.

References between documents follow three conventions at once. The kernel's
`@see` tags name site URLs. Prose names decisions by number, "ADR 0032",
in 85 places, and by path in 3. The notes carry links in double
brackets to design documents that were deleted months ago, and nothing has
reported them, because nothing resolves such a link.

## Decision

**Every document under `docs/` is one of four kinds, or a record.** The
kinds are those of Diátaxis, and the compass decides which a page is:

- A **guide** page teaches by doing. The reader follows it from top to
  bottom and folds something they could not fold before. It carries
  programs the site build evaluates, and it explains nothing the reference
  states.
- A **manual** page gets one task done for a reader who already knows the
  language or the libraries: fold a base, choose a candidate line, render a
  FOLD file with the drawing library, adapt a diagram. It carries a program
  or a script the build runs.
- A **reference** page states what a thing does. The specification and the
  description of the reference implementation stay divided as ADR 0032 has
  them, as two groups within the reference. An API reference of a package
  is reference.
- An **explanation** page gives the reader an understanding of a choice or
  a concept. It carries no syntax, cites the model statements and the
  decisions it rests on, and restates neither. When a later record
  supersedes a decision, the explanation page that cites it is the page
  that follows.

A **record** is a decision (`docs/decision/`) or a journal entry
(`docs/notes/`). Records are written once, for the project, and are no
page of the site. The brand documents live in their own repository,
`tophcodes/beloch-brand`.

The site's navigation has one group per kind, and a group appears with the
first page of its kind. No group stands empty. Within a kind, an area that
has its own reader (the language, the rendering libraries) is a subgroup;
it becomes a group of its own when it outgrows the kind.

**The layout follows the kinds.** `spec/` becomes `docs/reference/`,
`decisions/` becomes `docs/decision/`, `notes/` becomes `docs/notes/`;
`docs/guide/`, `docs/manual/` and `docs/explanation/` hold the pages of
their kind. The site's content directory links each page, as it links the
reference today, and every URL ADR 0032 fixed stays.

**A link between documents names an id.** The id is the kind, which is
the directory name under `docs/`, and the document's file stem, with `#`
and an anchor where the link enters the document: `[[decision/0032]]`,
`[[reference/model#def-sheet]]`, `[[guide/first-folds]]`. A decision's
stem is its number. An id names its document for as long as the document
exists, through a rename and through a move into `archive/`; a tool that
reads the documents resolves the same id under its own base. A resolver
turns the id into a link on the site and in the rendered PDFs, and the
reference pages keep the URLs ADR 0032 fixed. A check in `check` fails on
an id that names no document or no anchor. In a file read on GitHub the id
stands unresolved and still names its target. A decision resolves to its
file in the repository.

## Alternatives considered

- **Keep the order of ADR 0032 and add the manual beside the guide.**
  Rejected: the guide would mix tutorials with tasks, and explanations
  would keep landing in decision records, where a reader of the site never
  finds them.
- **Apply the four kinds to the site and leave the repository as it is.**
  Rejected: two orders to maintain, and a link scheme that spans the site
  and the repository needs one layout to resolve against.
- **Link by path.** Rejected: a path breaks on every move and every rename,
  and the 85 references by number against 3 by path show that writers
  already avoid it.
- **Links in double brackets without a resolver and a check.** Rejected: the notes show
  the outcome, links to deleted documents that nobody noticed.

## Consequences

- The move touches about 60 files that name `spec/`, `decisions/` or
  `notes/` as a path, 10 symlinks under the site's content directory and 5
  scripts. It lands in one change, with `check-all` reporting what it
  broke. `CLAUDE.md` and the README of each moved tree follow.
- The resolver and the check are new code: a remark plugin for the site, a
  Lua filter for the PDFs, and a step in `check`.
- A change to the language edits the reference, and the build reports
  which guide or manual page it broke. An explanation page does not break,
  because it carries no syntax.
- The manual starts with its first task page, and the explanation with its
  first page; neither gets an empty section before that.
- Spalier, the decision harness under design in `aleph-garden/spalier`,
  reads decision records from a directory its project profile names, and
  resolves `[[decision/NNNN]]` under the project's base. Adopting it is a
  record of its own: it needs a scope field per decision, `constrains`, and
  a mapping for the frontmatter of the records as they are.
- This record is worth reopening when a second implementation or a second
  author arrives, or when the rendering libraries have more pages than the
  language.
