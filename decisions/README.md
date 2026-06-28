# Decision records

Architecture Decision Records (ADRs) for Beloch. One file per major decision,
numbered, append-only. We don't delete ADRs — if a decision is reversed, a later
ADR supersedes it and the old one is marked `Superseded by NNNN`.

Scope: semantic and architectural choices (layer model, output format, language
of implementation), **not** cosmetic ones (keyword spelling, file layout).

Format per record:

- **Status** — Accepted / Superseded by NNNN / Proposed
- **Context** — the forces in play, what made the decision necessary
- **Decision** — what we chose
- **Alternatives considered** — what we rejected and why
- **Consequences** — what this commits us to, good and bad

See also: `../notes/` (design journal), `../antipatterns.md` (dead ends),
`../spec/` (the language specification these decisions shape).
