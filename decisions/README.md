# Decision records

Architecture Decision Records (ADRs) for Beloch. One file per major decision,
numbered, append-only. We don't delete ADRs — if a decision is reversed, a later
ADR supersedes it and the old one **moves to `archive/`**.

The directory carries the status, not a banner inside the file: a `Superseded
by` line sits far from any `rg` hit and gets skipped, by people and by agents
alike. `decisions/*.md` is current truth; `decisions/archive/*.md` is not.
The successor names its predecessor going forward.

Scope: semantic and architectural choices (layer model, output format, language
of implementation), **not** cosmetic ones (keyword spelling, file layout).

Format per record — a YAML frontmatter block, then prose:

```yaml
---
id: "0008"                     # quoted: bare 0008 is an invalid octal literal in YAML
title: "Exact rational arithmetic (zarith) for the geometry engine"
date: 2026-06-29               # optional
status: accepted
checks:                        # optional
  - desc: Jede lib/*.ml hat eine .mli
    run: 'for f in lib/*.ml; do [ -f "${f}i" ] || exit 1; done'
---
```

The frontmatter is authoritative for `status`; `arch-check` reads `checks`.
A check belongs to the record that decided it, so the rule cannot drift away
from its reasoning and archiving the record retires the check in one move.

Prose sections below it:

- **Context** — the forces in play, what made the decision necessary
- **Decision** — what we chose
- **Alternatives considered** — what we rejected and why
- **Consequences** — what this commits us to, good and bad

A few records keep a `## Status` section as well, where the status carries
narrative the single word cannot (0012, 0013, 0017, archive/0010).

See also: `../notes/` (design journal), `../antipatterns.md` (dead ends),
`../spec/` (the language specification these decisions shape).
