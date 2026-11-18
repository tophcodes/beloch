# Records

`records/` holds what the project keeps for itself; `docs/` holds the pages
for readers of the site ([[ADR-0054]], [[ADR-0062]]). The two trees meet in
`docs/reference/`, which is a page and the binding specification at once.

| What you have | Where it goes |
|---|---|
| How Beloch is built, how the project works, and why | an ADR in `adr/` |
| Why a language rule is what it is, with the case and the alternatives | a BEP in `bep/`, in the pull request that edits `docs/reference/` |
| A proposal that was argued and rejected, or an approach that failed while building | an abandoned ADR or BEP in the `archive/` of its kind |
| Thinking in progress: a failing example, a half-formed idea, a spike | a dated entry in `notes/` |
| An idea set aside untried | an issue with the label `parked` |
| A question that waits for a decision | an issue with the template `design` |
| What the language or the model does now | `docs/reference/`, no record |

ADRs and BEPs take their numbers from one counter. A record's id is its kind
and number, `ADR-0008` or `BEP-0037`; the file name starts with it, the
heading starts with it, and a link names it alone: `[[BEP-0037]]`. A journal
entry's id is `notes/` and its file stem.

## States

| State | Where it is | Who moves it there |
|---|---|---|
| proposed | in an open pull request, never on `main` | its author, by opening the pull request |
| accepted | `adr/` or `bep/` | the maintainer, by merging the pull request |
| superseded | `archive/` of its kind | the pull request that adds the record replacing it |
| abandoned | `archive/` of its kind | the maintainer, by merging the record with this state |

The directory carries the state, and the frontmatter field `status` repeats
it. A superseded record names its successor in `superseded-by`; an abandoned
record adds a section **Why abandoned**. A later record that amends an
accepted one may change that record's frontmatter, never its prose.
