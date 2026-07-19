# Incremental Evaluation Cache — Design

**Date:** 2026-07-19
**Status:** Approved (brainstorm) — pending implementation plan
**Branch:** `feat/incremental-eval-cache`

## Problem

Every edit in the Playground triggers a full re-evaluation of the `.bel`
program (jsoo worker calls `belochFoldString(src)` fresh per keystroke). The
expensive per-step work — the qqbar number kernel and the `flatten`/`collapse`
combinatorial solver — is redone from scratch even when the user only *appends*
a fold. This makes the Playground sluggish for anything past a few steps and
wastes the CLI's time on re-runs of unchanged prefixes.

We want step-level result caching: change or append one fold, recompute only
from that point onward.

## Key finding — why this is safe

Evaluation is strictly sequential: `eval_folded` threads a single `ctx` through
`List.iter eval_stmt prog` (`lib/eval.ml:2359`). Each material statement
transforms the state functionally and writes it back.

**The only global mutable state in the entire evaluator is
`Fold_state.next_id` (`lib/fold_state.ml:53`)** — one id counter, reset once per
eval via `reset_ids ()`. There are no module-level memo tables or hidden caches
in the number kernel (`num.ml`/`qqbar.ml`/`field_merge.ml`/`poly.ml`).
Everything else lives in `ctx` (local to `eval_folded`) or is purely functional.

Therefore: **the evaluation state after statement `k` is a pure function of
statements `1..k`.** The prefix is stable, so memoizing along the statement
spine is correct — no aliasing, no spooky cross-step dependence.

Correctness rests on Beloch being single-pass with declare-before-use: an
`apply` statement sits *after* the `def` it invokes, a name is bound before it
is referenced. Editing a `def` or binding changes its own spine node and
invalidates everything after it (the suffix), which is exactly what its later
users occupy. No forward reference can retroactively alter an earlier prefix.
*(Implementation must assert this — see Open Questions.)*

## Scope

Phased, engine in the **core library** (`lib/`) so both the Playground and the
CLI benefit:

- **Phase 1 — in-memory incremental re-eval.** No serialization. A `Session.t`
  memoizes `ctx` snapshots along a hash-chained statement spine. Directly
  delivers Playground interactivity. This is the bulk of the value.
- **Phase 2 — on-disk `.beli` checkpoint file.** Persists the spine across
  process runs (cold Playground load, CLI, sharing). Requires full
  `Fold_state` + `Num` (de)serialization. Deferred; specced separately.

## Phase 1 — architecture

### What a checkpoint is

A resumable checkpoint is **not** just a `Fold_state` — it is the whole `ctx`
plus the id counter:

- `scopes` (points / lines / instances / point_steps / line_steps hashtables)
- `defs`, `name_ctx`, `cur_def_idx`, `next_def_idx`, `panel`, `panels`,
  `frames_rev`, `pending`
- **`!Fold_state.next_id`** (the one global counter)

A **snapshot** is a shallow copy of each hashtable (their values — `Geom`
points, `crease_val`, AST fragments — are immutable), a deeper copy of the inner
per-`instance` tables, the scalar fields, `frames_rev` (an immutable list,
structurally shared), and the captured `next_id` value. Snapshot cost is a
handful of hashtable copies — cheap against a single qqbar or `flatten` step.

### The hash-chain spine (invalidation)

```
key₀ = h(∅)
keyᵢ = h(keyᵢ₋₁ ++ canon(stmtᵢ))
```

`canon(stmtᵢ)` is a canonical hash of the **parsed** statement (AST), not raw
source text, so whitespace and comment edits do not bust the cache. The session
stores `keyᵢ → snapshotᵢ`.

- **Append** a statement at the end → every existing `keyᵢ` is unchanged →
  full prefix reuse, only the new step computes.
- **Edit** statement `k` → `keyₖ` and all keys after it change → snapshots
  `k..n` invalidated and recomputed; `1..k-1` reused.

### Module cut

`lib/eval.ml` refactor — hoist the per-statement loop out of the `eval_folded`
closure and expose a small incremental interface (the 2415 lines of statement
logic are untouched; only their enclosure changes):

```ocaml
type snapshot
val make_ctx : unit -> ctx
val step     : ctx -> Ast.stmt -> unit     (* the lifted loop body *)
val snapshot : ctx -> snapshot             (* deep-copy + !next_id *)
val restore  : ctx -> snapshot -> unit
val finalize : ctx -> folded
```

`eval_folded` then becomes `make_ctx` → `List.iter step` → `finalize`,
preserving current behavior exactly (regression-checked against goldens).

New `lib/session.ml`:

```ocaml
type t                             (* holds the spine: (hashᵢ, snapshotᵢ) array *)
val create : unit -> t
val eval   : t -> string -> folded (* parse, diff against spine, resume *)
```

`Session.eval`:
1. parse `src` → `Ast.program`
2. compute per-statement AST hashes → the new key chain
3. find the longest prefix whose keys match the stored spine
4. `restore` the `ctx` to that boundary's snapshot (or `make_ctx` if none match)
5. `step` over the remaining suffix, appending a fresh snapshot per statement
6. truncate the spine at the divergence point and `finalize`

### Wiring

- **Playground.** `web/beloch_web.ml` holds one persistent `Session.t` (the
  worker already lives across `importScripts`). Per message: `Session.eval s
  src` instead of `fold_string`. The `{ok, fold}` envelope is unchanged — the
  UI only observes that re-eval got faster.
- **CLI.** `beloch fold --watch FILE` keeps a `Session.t` and re-evaluates only
  the changed suffix on file change. Falls out almost for free once the engine
  is in the core.

## Phase 2 — `.beli` on-disk (deferred)

A sidecar file `foo.beli` next to `foo.bel` (gitignore candidate) persisting the
**full spine** — every intermediate snapshot — so a cold start can resume
mid-program: after a restart, editing statement `k` recomputes only `k..n`
rather than re-running from the top.

Header carries: format version + `beloch` version + source-file hash. On version
bump or source-hash mismatch the `.beli` is discarded and a cold full-eval runs.
That is the entire cross-version invalidation story — no migration, stale means
throw away.

The hard part is serializing a snapshot, verlustfrei (unlike the float-lossy
FOLD export):

- **`Num.t`**, per representation: `Rat` → zarith num/den as strings; `Field` →
  extension minimal polynomial (ℚ coefficients) + the coordinate as a polynomial
  in α; `Qq` (qqbar) → minimal polynomial + isolating interval (rational
  endpoints), from which FLINT reconstructs the canonical qqbar.
- **`Fold_state.t`** — the hinge graph (vertices / faces / creases + ids). Ids
  are "never serialized" today because they are a function of the program; in a
  checkpoint they may be persisted since the source hash pins the context.
  Needs `to_json` / `of_json` at the `.mli` boundary.

Persistence choice (recorded now, revisited with Phase 1 measurements): **full
spine** — big file, one serialized `Fold_state` per step, in exchange for
resume-anywhere after a cold start.

## Open questions / risks

- **Snapshot memory & cadence.** Phase 1 snapshots every statement (simplest,
  correct). For very long programs this is memory-heavy; a later optimization
  may snapshot sparsely (every N steps, or only at frame boundaries) and replay
  the gap. Start dense, measure, optimize only if needed.
- **Declare-before-use assertion.** The correctness argument assumes no forward
  references mutate an earlier prefix. The implementation must verify this holds
  for `def`/`apply`, `BindLine`, `Point`, and any panel/`step` machinery — a
  test that an editing an early statement never changes a *reused* prefix's
  frames.
- **AST canonical hashing.** Need a stable, span-independent hash of `Ast.stmt`
  (spans and provenance strings must not participate, or cosmetic edits bust the
  cache). Define exactly which AST fields are semantic.
- **Instance table depth.** Snapshot must copy inner `instance` hashtables, not
  just alias them, or a later `apply` mutates a cached prefix's instance state.

## Success criteria

- Appending one fold to an N-step program recomputes exactly one step
  (assert via a step-count / kernel-call counter, not wall-clock).
- Editing statement `k` reuses frames `1..k-1` byte-identically and recomputes
  `k..n`.
- `Session.eval` on an unchanged program returns the cached result with zero
  `step` calls.
- Full golden suite passes: `Session.eval` on a fresh session equals
  `eval_folded` for every fixture.
- Playground append-latency drops measurably on a multi-step model.
