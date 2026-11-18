# ADRs

An ADR (Architecture Decision Record) records a decision about how Beloch is
built, how the project works or how its documents are ordered: the language
of implementation, the number kernel, module boundaries, output plumbing,
process ([[ADR-0062]]). A decision about what a program means is a BEP in
`../bep/`. Cosmetic choices (keyword spelling, file layout) get no record.
States and numbering: `../README.md`.

## Format

```yaml
---
id: ADR-0008
title: "Exact rational arithmetic (zarith) for the geometry engine"
date: 2026-06-29               # optional
status: accepted               # accepted | superseded | abandoned
issue: tophcodes/beloch#62     # optional: the issue that raised the decision
superseded-by: null            # set when the record moves to archive/ as superseded
checks:                        # optional
  - desc: Every lib/*.ml has an .mli
    run: 'for f in lib/*.ml; do [ -f "${f}i" ] || exit 1; done'
---

# ADR-0008: Exact rational arithmetic (zarith) for the geometry engine
```

`arch-check` reads `checks`. A check belongs to the record that decided it,
so the rule cannot drift away from its reasoning, and archiving the record
retires the check in one move.

A record raised by an issue names it in `issue`, with owner and repository:
inside a file in the repository GitHub links no bare `#n`, and issue numbers
repeat across the repositories Beloch has used. Issues that carry the
decision out name the record in their origin line (`ADR-0031`), so a search
for the id finds them; the record does not list them.

Sections below the heading:

- **Context**: the forces in play, what made the decision necessary
- **Decision**: what we chose
- **Alternatives considered**: what we rejected and why
- **Consequences**: what this commits us to, good and bad
- **Why abandoned**: only in an abandoned ADR

A few records keep a `## Status` section as well, where the status carries
narrative the single word cannot (ADR-0012, ADR-0013, ADR-0010 in
`archive/`).
