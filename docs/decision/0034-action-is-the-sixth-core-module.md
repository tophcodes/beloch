---
id: "0034"
title: "Action is the sixth core module: the disposition verbs, split from Eval"
date: 2026-09-27
status: accepted
checks:
  - desc: Action has an .mli
    run: '[ -f "packages/core/lib/action.mli" ]'
  - desc: eval.ml stays under 900 lines
    run: '[ "$(wc -l < packages/core/lib/eval.ml)" -lt 900 ]'
---

# 0034: Action is the sixth core module: the disposition verbs, split from `Eval`

## Context

[[decision/0018]] named this split and deferred it: `run_fold*` stayed in `Eval`
because splitting the action model (`mark`, `fold`, `run_fold*`, [[decision/0011]])
from the instance machinery (`def`, `apply`, `export`) was a plausible
sixth module, not yet a necessary one.

`eval.ml` crossed the 900-line limit that same ADR's `checks:` set (#50).
Nothing ran that check, so nothing failed until the crossing was found by
hand.

## Decision

`Action` owns the disposition verbs, the writes that touch the fold state:
`eval_mark`, `eval_fold`, `eval_reverse`, and the checked-fold primitive
`fold` and `reverse` share (`run_fold`, `run_fold_checked`). `reverse`
joins `mark` and `fold` here rather than staying in `Eval`, because it
mutates `ctx.state` the same way they do; [[decision/0011]]'s "disposition verb"
covers all three.

`free_point` stays in `Eval`. It binds a name to a point on a line and
never touches `ctx.state`, so it reads as a binding, not an action.

The dependency chain gains a stage:

```
Ctx → Resolve → { Axiom, Flatten_solve } → Action → Eval
```

`Action` depends on `Ctx`, `Resolve` and `Axiom`, not on `Flatten_solve`:
none of the disposition verbs construct or solve a flatten. `Eval` keeps
the statement dispatch, the def/apply/export machinery (a mutually
recursive group that cannot cross a module boundary without a heavier
mechanism than the problem needs, the same reasoning [[decision/0018]] gave against
a functor), and the assembly of the evaluated program into its output
record.

## Alternatives considered

**Move `build_output` beside `Fold_emit` instead.** #50 raised this as the
other candidate seam. Rejected: `build_output` reads `Ctx` internals to
assemble the `folded` record, which is `Eval`'s job (state to domain
value), not `Fold_emit`'s (domain value to FOLD JSON). Moving it would
give `Fold_emit` a `Ctx` dependency it does not otherwise need, and
`Action` alone gives `eval.ml` enough headroom that the second move buys
nothing.

**Fold `free_point` into `Action` too**, so the module holds every
non-instance statement handler rather than only the ones that write to
`ctx.state`. Rejected: `Action`'s boundary is "touches the fold state",
and folding in a function that does not would blur the one property that
makes the module worth naming.

## Consequences

- `eval.ml` has headroom again: the disposition verbs and the checked-fold
  primitive were the bulk of what stood between it and the 900-line limit.
- `Action` is the reusable half: any future entry point that evaluates
  disposition verbs without the def/apply/export machinery (a REPL that
  runs one statement at a time, say) depends on `Action` and not on all of
  `Eval`.
- `Ctx`'s doc comment already named `Resolve`, `Axiom`, `Flatten_solve` and
  `Eval` as modules that read its concrete types directly; `Action` joins
  that list.
