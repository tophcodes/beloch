---
id: "0001"
title: "OCaml for the evaluator core, TypeScript for the tooling edge"
status: accepted
---

# 0001 — OCaml for the evaluator core, TypeScript for the tooling edge

## Context

Beloch has several layers with different needs: the evaluator (lexing, parsing,
name resolution, type checking, geometric evaluation, axiom disambiguation,
layer ordering), the editor tooling (LSP server, editor extensions), and the
visualization layer (crease-pattern rendering, YR diagrams, web playground).

The evaluator is the hard part and the research contribution — it has to be
correct and easy to evolve. It is overwhelmingly tree-shaped, owned, immutable
data with many node variants and many passes over them.

Rust was considered as the single implementation language, partly for the
career/fluency payoff. That argument conflates "use Rust for *some* project"
with "use Rust for *this* project" — the second doesn't follow from the first.

## Decision

- **Evaluator core in OCaml.** Algebraic data types with exhaustive matching,
  no borrow checker fighting tree traversals, mature compiler-writing toolchain
  (menhir, sedlex, dune, ppx_deriving, merlin).
- **Tooling edge in TypeScript.** LSP server wrapper, editor extensions,
  visualization/rendering, CLI polish, web playground.
- **Boundary:** OCaml → JS via js_of_ocaml or Melange, exposing a typed API;
  process boundaries cross via FOLD-extended / custom JSON (see [0002](0002-fold-extended-as-output.md)).

## Alternatives considered

- **Rust for everything.** `enum + Box` + pattern matching gets ~80% of ML for
  compiler work, and Rust is the stated long-term language to learn. Rejected
  for the core: doing three hard things at once (learn Rust, design a novel
  language, solve the layer problem) conflates "can't express in Rust" with
  "can't express in the language" — distinct failure modes we want separable.
  Rust fluency will be earned on a Rust-shaped project, not this one.
- **TypeScript/Bun prototype, Rust rewrite.** Fast to iterate, but the rewrite
  cost is real and OCaml gets the same iteration speed *and* is the better
  long-term home for compiler code.

## Consequences

- Accept a fourth-ish language with a smaller ecosystem for non-compiler tasks
  (native GUI, systems work). Beloch needs none of those in the core.
- Web/playground path goes through js_of_ocaml/Melange — works, slightly more
  friction than Rust→WASM.
- Rust gets learned elsewhere (infra tooling, iotame), not forced onto Beloch.
- The OCaml core stays a clean, well-specified producer of artifacts; anyone can
  write a consumer in any language.
