---
title: "A decision is named by its date and slug"
date: 2026-10-08
status: accepted
issue: tophcodes/beloch#241
checks:
  - desc: Every decision record is named YYYYMMDD-slug.md
    run: '! ls docs/decisions/*.md docs/decisions/archive/*.md | grep -v README.md | grep -vE "/[0-9]{8}-[a-z0-9-]+\.md$"'
  - desc: No record carries a number in its front matter
    run: '! grep -l "^id:" docs/decisions/*.md docs/decisions/archive/*.md'
---

# A decision is named by its date and slug

This record replaces one sentence of
[[decisions/a-document-is-one-of-four-kinds-and-a-link-names-an-id]], the
one that makes a decision's stem its number, and the numbering rule of the
records' README. The rest of that record stands.

## Context

A decision record was named by a number, `0032-the-specification-binds-every-implementation.md`, and the number was its id: the front matter carried it, the heading repeated it, prose named a record as "ADR 0032", and the id links of the record above used it, `[[decision/0032]]`.

The number orders the records and nothing else, and it fails at that on a branch. Two branches that each add a record take the same next number, and whichever merges second renumbers; the record above was written as 0049 and landed as 0054 that way, with every reference to it rewritten. A number also says nothing about the record it names, so a reader of "ADR 0032" in a kernel comment has to open the file to learn what it decided.

The tools around the records look for a directory named `decisions`: `arch-check` searches `decisions/` and `docs/decisions/` and found nothing under `docs/decision/`, and Spalier's project profile defaults to the same name.

## Decision

**A record's file is `YYYYMMDD-slug.md` under `docs/decisions/`**, the date the one in its `date:` field, which every record carries. The slug is the record's id: a link to it is `[[decisions/<slug>]]`, and its default text is the record's title. No record carries a number, in its file name, its front matter or its heading, and no two records share a slug; a check holds both.

A reference to a record outside `docs/`, in a code comment, a program, the agent instructions or an issue, names it as `decisions/<slug>`.

A record that moves to `archive/` keeps its file name and its id.

## Alternatives considered

- **Keep the number as the id and the slug beside it.** Rejected: two names for one record, and the number still collides across branches.
- **Name the file by the slug alone, without the date.** Rejected: the directory listing would lose the order of the records, which the date keeps without a counter.
- **Number records on merge, by a script.** Rejected: every reference written on the branch would be rewritten on landing, which is the rewrite this record ends.

## Consequences

- The 54 records are renamed, 15 of them get the `date:` of their first commit, and about 400 references to a number in documents, comments, programs and the agent instructions name the slug instead.
- The default text of a link to a record is its title, so a sentence that wants a shorter handle writes `[[decisions/<slug>|text]]`.
- `arch-check` finds the records again.
- Spalier, the decision harness under design in `aleph-garden/spalier`, reads a record as `<slug>.md` with an optional date prefix and resolves `[[decisions/<slug>]]` the same way, so adopting it needs its `decisions ::` setting pointed at `docs/decisions/` and nothing else here.
