---
id: "0009"
title: "Relationship to Rabbit Ear; a constrained declarative language, not a library or eDSL"
status: accepted
---

# 0009 — Relationship to Rabbit Ear; a constrained declarative language, not a library or eDSL

## Context

[Rabbit Ear](https://rabbitear.org) (Robby Kraft) is a mature JavaScript origami
library: the seven axioms as functions, FOLD manipulation, crease-pattern math,
SVG/WebGL rendering, and folding simulation. It is the closest existing work to
Beloch and the obvious "why exist / why not just use it" challenge. Two sharp
objections came up:

1. Any `.bel` program could be written as an imperative Rabbit Ear `.js` script,
   so the `.js` file is "also the model" — the source-as-artifact point seems to
   collapse.
2. JavaScript is Turing-complete, so Rabbit Ear is "more capable" than a small
   declarative language.

## Decision

Beloch is a **standalone, declarative, deliberately non-Turing-complete**
language that compiles to FOLD. **Rabbit Ear is a consumer/backend, not a
competitor.** We do **not** build Beloch as an embedded DSL inside JS/Rabbit Ear.

### Why Turing-completeness is the wrong metric

For a *model description*, value comes from what you **cannot** do. Constraint
enables analysis, optimization, and generation. Precedent: SQL (not TC) beats
hand-rolled loops in C (TC); [Dhall](https://dhall-lang.org) advertises
non-Turing-completeness as a feature (total, terminating, analyzable); TikZ,
regex, Datalog all thrive beside TC hosts. "More computation" is precisely what
you do not want in a model description.

### Why `.js` is not equivalent to `.bel`

Both are text files; the difference is **guarantees**. A `.bel` file is, by
construction, a total, analyzable, declarative sequence of axiom operations —
the source *is* the folding journey, diffs are semantically meaningful (one line
= one changed fold), and there is no escape hatch. A general `.js` program
guarantees none of this: loops, randomness, I/O, and abstraction make the diff
noise, make "the steps" unextractable, and make static analysis the halting
problem.

### What the constraint enables (and `.js`-against-an-API structurally cannot)

- Step-by-step YR folding-instruction generation (the program *is* a linear,
  analyzable op sequence).
- Static / precondition analysis — cf. Caruana & Pace 2007
  ([caruana2007](../bibliography.md)), who did exactly this for their embedded
  origami DSL.
- A clean LLM generation target (small grammar, every token meaningful).
- Formal operational semantics → the paper.
- Multiple backends from one source (FOLD, YR diagrams, Rabbit Ear, 3D sim,
  print). A Rabbit Ear `.js` program is nailed to RE's runtime.

### When computation is genuinely needed

Use a host language that **emits** `.bel` (parametric families, swept
parameters), keeping Beloch declarative — TC generation *and* a clean artifact.
Reaffirms [ADR 0007](0007-evaluator-not-compiler.md) (keep the language
declarative; put cleverness in a host language).

### Rabbit Ear as consumer/backend

RE is the ideal downstream consumer of Beloch's FOLD: rendering, folding
simulation, and **face population** — it solves exactly what v0.0 defers (faces,
mountain/valley folding, viewer), and it accepts our faces-less FOLD by computing
faces itself. Implication: Beloch need not rebuild RE's presentation/compute
stack in OCaml. The exact-rational OCaml core's value is **authoring and
evaluation** (RE is floating-point); presentation can be delegated to RE.
Whether to lean on RE for planarization/faces versus doing it in-core is an open
architectural question for a later slice.

## Alternatives considered

- **Just use Rabbit Ear; don't build Beloch.** Rejected: a library is not a
  language; the declarative axiom-source-language niche stays empty (lineage:
  [0003](0003-restart-from-minimal-core.md), [0005](0005-name-beloch.md), and
  the April 2026 design conversation).
- **Embedded DSL in JS/Haskell** (cf. Caruana-Pace in Haskell). Rejected: an
  eDSL inherits the host's escape hatch and loses the totality/analyzability
  guarantee. Only a standalone language with no escape hatch delivers it — that
  *is* the differentiation.

## Consequences

- Differentiation is **"language vs library,"** not feature parity. Lean into the
  declarative / instruction-generation / LLM-target / formal-semantics angles;
  do not reimplement RE's engine for its own sake.
- Beloch's core stays non-TC (reaffirms [0007](0007-evaluator-not-compiler.md)).
- Rabbit Ear is the recommended viewer/folder today (takes faces-less FOLD).
- The paper's related-work section must cite and position against Rabbit Ear
  honestly: a JS library, floating-point, no standalone source format.
