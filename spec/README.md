# Beloch language specification

Human-readable specification of the Beloch language. Grows one increment at a
time alongside the implementation — **never spec further than what's implemented,
never implement further than what's spec'd** (see
[decision 0003](../decisions/0003-restart-from-minimal-core.md)).

## Planned files (added as each increment lands)

- `00-overview.md` — what Beloch is, the evaluator model, artifact pipeline.
- `10-core-v0.md` — the minimal core: paper model, axiom 1, crease line type,
  FOLD-extended output. (The first thing to write; nothing else exists until
  this is solid.)
- `20-axioms.md` — the seven Huzita-Justin axioms as primitives, with
  multi-solution disambiguation for axioms 5 and 6.
- `30-folded-state.md` — folded state and face/layer partial ordering (the hard
  one).
- `40-grammar.md` — the formal grammar (mirrors the Menhir grammar).
- `fold-extensions.md` — the `beloch:*` FOLD extension fields.
- `instructions-schema.md` — the custom JSON schema for YR-style step diagrams.

Each increment carries: formal grammar fragment, type rules, operational
semantics, and worked examples that the implementation must satisfy.
