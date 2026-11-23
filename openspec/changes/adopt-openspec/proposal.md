## Why

Beloch recorded every project decision as an ADR and every language decision
as a BEP, each 40 to 270 lines of prose with no before and after. Reviewing
one cost more than the change it described, so the records went unreviewed.
OpenSpec keeps one binding specification and states every change as a delta
of requirements with WHEN/THEN scenarios, which a reviewer reads in minutes.

## What Changes

- The ADRs and BEPs in force become the requirements of fourteen
  capabilities. `architecture` holds how Beloch is built; the others hold
  what a program means, by topic.
- `records/adr/` and `records/bep/` leave the tree; the Git history keeps
  them. This change's design keeps one or two lines of reason per record.
- Code, tests, pages and agent instructions point at requirements instead of
  record ids. The id link form `[[ADR-…]]` and `[[BEP-…]]` is retired; links
  to pages and journal entries stay.
- The `checks:` of the ADRs become scenarios that name their command.
- The devshell turns off the usage report of the `openspec` command.

Out of scope: the content of `docs/reference/`, which stays as it is; deriving
it from the specification is a change of its own.

## Capabilities

### New Capabilities

- `architecture`: languages, number kernel, kernel modules, data layer, readers, documents and repository checks.
- `annotations`: annotation lines, their vocabulary and the credits of a program.
- `output`: what the FOLD file shows beyond its frames.
- `diagnostics`: errors and warnings and where they appear.
- `folded-state`: flat folded states, verbs as the only change, flaps.
- `operands`: typed slots, bundles, the meet, filters and joins.
- `names`: what a name holds and what `=` binds.
- `sheets`: the sheet a program opens, shapes and their exports.
- `selection`: how a write keeps one candidate line of a construction.
- `folds`: which layers `mark`, `fold` and `unfold` reach and move.
- `layer-order`: how a write decides which of two overlapping faces lies above.
- `flatten`: the fan of `flatten` and the fan machinery of `reverse` and `squash`.
- `squash`: the `squash` write.
- `reverse-fold`: the `reverse` write.

### Modified Capabilities

None.

## Impact

Every reader of `records/adr/` and `records/bep/`: the id link index and its
tests, one kernel test that read two BEPs, the CI step that looked for
records named by dune files, the issue templates and the agent instructions.
