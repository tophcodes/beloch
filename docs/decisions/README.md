# Decision records

Architecture Decision Records (ADRs) for Beloch. One file per major decision,
named by its date and slug, append-only. We don't delete ADRs: if a decision is reversed, a later
ADR supersedes it and the old one **moves to `archive/`**.

The directory carries the status, not a banner inside the file: a `Superseded
by` line sits far from any `rg` hit and gets skipped, by people and by agents
alike. `docs/decisions/*.md` is current truth; `docs/decisions/archive/*.md` is not.
The successor names its predecessor going forward.

Scope: semantic and architectural choices (layer model, output format, language
of implementation), **not** cosmetic ones (keyword spelling, file layout).

Format per record: a YAML frontmatter block, then prose:

```yaml
---
title: "Exact rational arithmetic (zarith) for the geometry engine"
date: 2026-06-29               # the date in the file name
status: accepted
issue: tophcodes/beloch#62     # optional: the issue that raised the decision
checks:                        # optional
  - desc: Jede lib/*.ml hat eine .mli
    run: 'for f in lib/*.ml; do [ -f "${f}i" ] || exit 1; done'
---
```

The frontmatter is authoritative for `status`; `arch-check` reads `checks`.
A check belongs to the record that decided it, so the rule cannot drift away
from its reasoning and archiving the record retires the check in one move.

A record raised by an issue names it in `issue`, with owner and repository:
inside a file in the repository GitHub links no bare `#n`, and issue numbers
repeat across the repositories Beloch has used. Issues that carry the decision
out name the record in their origin line (`decisions/toward-names-the-side-that-stays`), so a search for the
number finds them; the record does not list them.

Prose sections below it:

- **Context**: the forces in play, what made the decision necessary
- **Decision**: what we chose
- **Alternatives considered**: what we rejected and why
- **Consequences**: what this commits us to, good and bad

A few records keep a `## Status` section as well, where the status carries
narrative the single word cannot (`real-algebraic-number-kernel`,
`flint-qqbar-backend`, `flap-is-coplanar-not-precrease-partition`,
`archive/constructible-real-numbers`).

A document links to a record as `[[decisions/<slug>]]`
([[decisions/a-document-is-one-of-four-kinds-and-a-link-names-an-id]]), or as
`[[decisions/<slug>|text]]` with its own text; in a table cell the pipe is `\|`.
The id stays valid when the record moves to `archive/`.

See also: `../notes/` (design journal), `../antipatterns.md` (dead ends),
`../reference/` (the language specification these decisions shape).
