# 0007 — Beloch is an evaluator, not a compiler; CLI shape

**Status:** Accepted

## Context

A compiler translates source → machine code. Beloch translates source → a data
artifact describing a folded-paper *state*. It does real computation in between
but produces no executable. The precedent that fits is the functional-language
**evaluator**, and specifically **Nix**:

- Nix: evaluator (`.nix` → derivation) + builder (derivation → output)
- Beloch: evaluator (`.bel` → FOLD-extended) + renderers (→ YR diagrams, SVG,
  Three.js, print)

That split tells us where the complexity lives: the evaluator is the whole
ballgame (layer model, axiom disambiguation, geometry); renderers are thin
consumers of a well-specified artifact.

## Decision

- Call it an **evaluator** in prose, design docs, and the paper. "Compiler" is
  fine colloquially, but strict use confuses PL-literate readers.
- Internally, three phases: (1) front-end — lex, parse, name-resolve,
  type-check → typed AST (standard, boring); (2) **geometric evaluation** — walk
  the AST applying folds to a geometric state, resolve multi-solution axioms,
  track layer ordering (the novel phase, what a paper is about); (3) emitter —
  serialize to FOLD-extended (mechanical).
- **CLI:** a single `beloch` binary with git/nix-style subcommands:
  - `beloch fold file.bel` — evaluate, emit FOLD-extended (primary op; reads as
    English; "fold" = the domain word = the FP reduce the evaluator performs)
  - `beloch check file.bel` — front-end only, no geometric eval (editor/CI)
  - `beloch lsp` — run as an LSP server
  - `beloch render file.fold --as=yr` — render to a visual output (probably a
    separate binary/tool eventually; subcommand is fine to start)

## Alternatives considered

- **Call it a compiler.** Colloquially OK; rejected as the canonical term
  because it misleads PL readers about what the artifact is.

## Consequences

- Keeps the language declarative (see scope discipline in
  [0003](0003-restart-from-minimal-core.md)); resist Turing-completeness
  temptation in the core — put generation in a host language emitting `.bel`.
- The "fold" subcommand triple-puns (paper fold / FP reduce / English verb),
  which is the kind of vocabulary coherence worth keeping.
