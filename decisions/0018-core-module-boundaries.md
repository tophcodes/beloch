---
id: "0018"
title: "Core module boundaries: Ctx, Resolve, Axiom, Flatten_solve, Eval"
date: 2026-07-28
status: accepted
checks:
  - desc: The five decomposed core modules each have an .mli
    run: 'for m in ctx resolve axiom flatten_solve eval; do [ -f "packages/core/lib/$m.mli" ] || exit 1; done'
  - desc: eval.ml stays under 900 lines
    run: '[ "$(wc -l < packages/core/lib/eval.ml)" -lt 900 ]'
---

# 0018 — Core module boundaries: Ctx, Resolve, Axiom, Flatten_solve, Eval

## Context

The evaluator grew as one file. `eval.ml` held `eval_program`, a single
function of 2416 lines: the evaluation context lived in its closure, and every
statement kind, every name lookup, every axiom construction and the whole
flatten solver were nested `let`s inside it.

The cost was not aesthetic. Every slice — new axiom, new selector, fold-scope
change — landed in that one function, so each one had to carry the entire file
as context to change forty lines of it, and no interface existed to say which
of the surrounding forty helpers a change was allowed to touch. Nesting also
suppressed the compiler's usual warnings: a value reachable from a closure is
never unused.

The phases were already there in reading order — build a context, resolve
names against it, construct an axis, solve a flattening, apply the result.
They just had no names.

## Decision

The core splits into five modules, each with an `.mli` that is the module's
contract, in the dependency order

```
Ctx → Resolve → { Axiom, Flatten_solve } → Eval
```

- **`Ctx`** owns the evaluation context: the fold state, scopes, frames, the
  statement log, and snapshot/restore at statement boundaries.
- **`Resolve`** turns names and selectors into geometry and material against
  the current context.
- **`Axiom`** constructs axis lines for the seven Huzita-Justin axioms, and
  owns the axiom-5 path where bisector choice is deferred to the fold state.
- **`Flatten_solve`** owns the flatten/collapse solver arm.
- **`Eval`** holds the statement handlers, one named top-level function per
  statement kind, plus `run_fold*`.

Every stateful function takes `(ctx : Ctx.ctx)` as its first parameter rather
than closing over it. Types crossing a module boundary are abstract unless a
caller demonstrably reads them.

The graph is acyclic and must stay so; `Eval` is the only module allowed to
depend on all four others.

## Alternatives considered

**Leave it as one file.** Defensible while the evaluator was small, and it
kept every helper one screen away from its caller. Rejected because the cost
scales with the number of slices, not the size of any one slice: the file had
already outgrown what a single change could hold in context.

**A functor over the context.** Parameterise the phases over a context
signature instead of passing `ctx` explicitly. Rejected as a heavier
abstraction than the problem needs — there is exactly one context type and no
prospect of a second, so the functor would buy nothing but indirection at
every call site.

**Split by statement kind instead of by phase** — a module per `mark`, `fold`,
`def`, `apply`. Rejected because the statement kinds share the phases rather
than the other way round: `mark` and `fold` both resolve names, both construct
an axis, and a split by kind would duplicate all four phases five times over
while leaving the solver with no home of its own.

## Consequences

- Interfaces now constrain refactors: a change that widens a module's surface
  has to say so in the `.mli`, where it is visible in review.
- Abstract types surface dead code that nesting hid. Sealing `Axiom.ax5_pending`
  immediately exposed a record field with no reader (warning 69), which the
  fully-exported record had masked.
- `run_fold*` deliberately stayed in `Eval`. Splitting the action model
  (`mark`, `fold`, `run_fold*` — ADR 0011) from the instance machinery
  (`def`, `apply`, `export`) is a plausible sixth module, deferred rather than
  rejected.
- `Flatten_solve` may absorb more of `Flatten`'s caller-side logic later;
  `Flatten_solve.run` is now the largest single function in the core and is
  the next decomposition candidate.
- The `.mli` check is scoped to these five modules, not to `packages/core/lib`
  as a whole: `geom.ml`, `num.ml`, `collapse.ml` and their neighbours predate
  this record and have no interfaces. A repo-wide check would be red the day
  it landed, which teaches everyone to ignore checks.
- These are the repository's first executable `checks:`. Records 0001–0017
  carry prose only.
