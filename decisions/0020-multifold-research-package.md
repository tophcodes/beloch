---
id: "0020"
title: "Multifold research package: a separate library, one-way dependency on core"
date: 2026-08-04
status: accepted
checks:
  - desc: core never depends on multifold
    run: '! grep -rl "multifold" packages/core/lib'
---

# 0020 — Multifold research package: a separate library, one-way dependency on core

## Context

The multifold axioms research track
[docs/superpowers/specs/2026-08-03-multifold-axioms-research-design.md] needs
to enumerate Alperin-Lang two-fold alignments, then extend the enumeration to
three simultaneous coupled creases, and eventually check non-degeneracy by
solving polynomial systems on the exact kernel. This is research code:
exploratory, expected to churn, and not part of the language a `.bel` program
runs against ([0018]'s five-module core stays as decided).

The research track does need real machinery from the core: `Mpoly` for
constraint polynomials, `Q` (zarith's exact rationals) for generic parameter
instantiation. It has no need of anything the evaluator owns — no `Ctx`, no
`Resolve`, no statement handlers.

## Decision

A new dune library `multifold` lives under `packages/multifold/`, alongside
`core` as a sibling package, not inside it.

- `multifold` depends on `beloch` (the core lib) and `zarith`, and nothing
  else in core's internals it doesn't need — it reaches into `Mpoly` and `Q`,
  not into `Ctx`/`Resolve`/`Eval`.
- `core` never depends on `multifold`. The dependency edge is one-way, same
  direction as `packages/eval-web` and the other packages already sitting
  beside `core`.
- External solvers (PARI, for Galois-group computation) are invoked as
  subprocesses, never linked in. The spec already commits to this
  ("PARI called as a subprocess, not linked").
- Every module in `packages/multifold/lib/` has an `.mli`, from the first
  module on — unlike `packages/core/lib`, which grandfathers a few
  interface-less modules predating [0018]'s check.

## Alternatives considered

**Put it inside `packages/core/lib`.** Rejected: it would blur the module
boundaries [0018] just drew, and every churn-prone research experiment would
sit one directory away from the evaluator's stable module graph, tempting a
convenience dependency the wrong way (`Eval` reaching into research code, or
research code reaching past `Mpoly`/`Q` into `Ctx`).

**A separate top-level repo.** Rejected: the research track depends on the
exact kernel that only exists in this repo (ADR 0012/0013), and a separate
repo would need to vendor or pin it, adding release-coordination overhead for
work that is still exploratory.

## Consequences

- Research code stays out of the evaluator: nothing in `packages/core/lib`
  changes because of this track, and nothing in `multifold` can be reached
  from a `.bel` program.
- Deleting `packages/multifold/` must leave `core` building — the dependency
  graph guarantees this by construction, and the check above catches a
  reversed edge.
- The research package can be as messy or fast-iterating as the work
  demands without dragging [0018]'s interface discipline down with it,
  while still being held to "every module has an `.mli`" from day one, since
  it starts clean rather than inheriting grandfathered debt.
