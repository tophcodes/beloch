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

## Index

- [0001](0001-ocaml-core-typescript-edge.md) — OCaml core, TypeScript edge
- [0002](0002-fold-extended-as-output.md) — Fold Extended as output format
- [0003](0003-restart-from-minimal-core.md) — Restart from minimal core
- [0004](0004-menhir-then-treesitter.md) — Menhir then TreeSitter parsing
- [0005](0005-name-beloch.md) — Name: Beloch
- [0006](0006-permissive-license-mit.md) — MIT license
- [0007](0007-evaluator-not-compiler.md) — Evaluator, not compiler
- [0008](0008-exact-rational-arithmetic.md) — Exact rational arithmetic
- [0009](0009-relationship-to-rabbit-ear.md) — Relationship to Rabbit Ear
- [0010](archive/0010-constructible-real-numbers.md) — Constructible real numbers *(archived, replaced by 0012)*
- [0011](0011-action-model.md) — Action model
- [0012](0012-real-algebraic-number-kernel.md) — Real-algebraic number kernel
- [0013](0013-flint-qqbar-backend.md) — FLINT qqbar backend for irrational values
- [0014](0014-crease-is-a-bundle-of-segments.md) — A crease is a bundle of segments
- [0015](0015-flat-folded-states-only.md) — Flat folded states only; 3D is a goal, not carried
- [0016](0016-typed-operands-bundle-values-singleton-slots.md) — Typed operands: bundle values, singleton slots
- [0017](0017-flap-is-coplanar-not-precrease-partition.md) — A flap is a coplanar cluster of faces, not a single precrease polygon
- [0018](0018-core-module-boundaries.md) — Core module boundaries: Ctx, Resolve, Axiom, Flatten_solve, Eval
- [0019](0019-attribution-carried-by-construction.md) — Attribution is carried by construction
- [0020](0020-multifold-research-package.md) — Multifold research package: a separate library, one-way dependency on core
- [0021](0021-reference-documents-replace-specification.md) — The reference documents replace SPECIFICATION.md
- [0022](0022-constructions-are-alignment-sets.md) — A construction is its alignment set; an axiom number names one
