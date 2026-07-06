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
- [0010](0010-constructible-real-numbers.md) — Constructible real numbers
- [0011](0011-action-model.md) — Action model
- [0012](0012-real-algebraic-number-kernel.md) — Real-algebraic number kernel
- [0013](0013-flint-qqbar-backend.md) — FLINT qqbar backend for irrational values
- [0014](0014-crease-is-a-bundle-of-segments.md) — A crease is a bundle of segments
- [0015](0015-flat-folded-states-only.md) — Flat folded states only; 3D is a goal, not carried
- [0016](0016-typed-operands-bundle-values-singleton-slots.md) — Typed operands: bundle values, singleton slots
- [0017](0017-flap-is-coplanar-not-precrease-partition.md) — A flap is a coplanar cluster of faces, not a single precrease polygon *(Proposed)*
