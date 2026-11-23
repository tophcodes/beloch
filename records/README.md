# Records

`records/` holds what the project keeps for itself: the design journal in
`notes/`. `docs/` holds the pages for readers of the site, and `openspec/`
holds the binding specification and the changes to it.

| What you have | Where it goes |
|---|---|
| A decision about how Beloch is built or how the project works | a change under `openspec/changes/` whose requirements go into the capability `architecture` |
| A decision about what a program means | a change under `openspec/changes/` whose requirements go into the capability of its topic, in the pull request that edits `docs/reference/` |
| A proposal that was argued and rejected, or an approach that failed while building | a dated entry in `notes/` |
| Thinking in progress: a failing example, a half-formed idea, a spike | a dated entry in `notes/` |
| An idea set aside untried | an issue with the label `parked` |
| A question that waits for a decision | an issue with the template `design` |
| What the language or the model does now | `openspec/specs/` and `docs/reference/` |

A change is proposed, reviewed and archived with the OpenSpec workflow;
`openspec/config.yaml` holds the rules this repository adds to it. Archiving
a change merges its requirements into `openspec/specs/` and moves the change,
its design included, to `openspec/changes/archive/`.

A journal entry's id is `notes/` and its file stem; a link names it as
`[[notes/2026-06-28]]`.
