---
id: "0004"
title: "Menhir for the compiler parser, Tree-sitter later for editors"
status: accepted
---

# 0004 — Menhir for the compiler parser, Tree-sitter later for editors

## Context

Two distinct parsing needs:

- **Compiler-grade:** precise error messages, error recovery, tight integration
  with the typed AST, full control over semantic actions.
- **Editor-grade:** incremental reparsing while typing, resilience to broken
  code, fast, produces a concrete syntax tree for highlighting/folding/nav.

These are different problems. Serious language projects ship both (e.g. OCaml
itself: its own parser for the compiler, `tree-sitter-ocaml` for editors).

## Decision

- **Menhir first.** The Menhir grammar (with sedlex for lexing) is part of the
  language *design* — writing it forces precedence, associativity, and ambiguity
  to be pinned down. Output: a typed AST. Beloch's grammar is small (well under
  ~200 lines for v0.1).
- **Tree-sitter later**, translated from the Menhir grammar, once there's an
  editor extension to justify it. A TextMate grammar is an acceptable half-day
  stopgap for highlighting before then.

Maintain the two grammars by hand. Auto-derivation (`tree-sitter-menhir` and
similar) produces mediocre grammars that drift; manual maintenance of both is
cheaper because surface syntax shouldn't churn after v0.1.

## Alternatives considered

- **Tree-sitter first / only.** Rejected — editor recovery errors aren't
  compiler diagnostics; "this program is wrong, here's why" needs Menhir.
- **Hand-rolled recursive descent as the long-term parser.** Fine as a throwaway
  warm-up for v0.0, but Menhir's precedence/error handling is worth it for the
  real thing.
- **Single source of truth via auto-conversion.** Rejected — quality too low.

## Consequences

- Sequencing: v0.1 = Menhir + sedlex → AST → FOLD CLI. v0.2 = LSP. v0.3 =
  Tree-sitter grammar + editor support everywhere.
- Two grammars to keep in sync; accepted as low-churn maintenance.
