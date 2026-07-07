# Bundle algebra & selection (design)

## Status

Proposed (2026-07-07). Companion to the `@flatten` design (whose surface
selectors adopt this). One open symbol choice (`@` vs `&`) is coupled to a
separate action-model revision — see *Open questions*.

## Motivation

Selection today is scattered: `--l at <sel>` (segment), `#(…)` (region), plus
the mooted `in` / `crossing`. They are in fact **all incidence** — `--l at --d`
*is* "crossing", `--l at #(R)` *is* "in region" (§4.8). So there is nothing new
to *add*; there is a lot to *unify*. This document makes bundles a first-class,
typed algebra and derives every selector as one operation on it.

## Types — the bracket encodes cardinality

A type's notation is fixed by whether the type is inherently **singular** or a
**bundle**. This is not a per-expression choice.

| type | form | why |
|---|---|---|
| **point** | `.( … )` | a point is always one — round, singular |
| **crease-bundle** | `--[ … ]` | a crease is *always* a bundle: it splits into segments at the first fold, so "one crease" is a fiction |
| **flap-bundle** | `#[ … ]` | a flap set |

No `.[…]` (points are never a set — multiple point constraints are *chained*,
below), no `--( … )`, no `#( … )`. The round-vs-square question dissolves: you
never choose, the type chooses.

`SIGIL[ constraints ]` denotes **the bundle of that type determined by the
constraints** (incident to every listed constraint):

```
--[.a .b]     the crease(-bundle) through a and b
#[.a .b]      the flap(-bundle) containing a and b
.(--x --y)    the point where --x and --y cross
```

(Note: `--[.a .b]` *constructs* new geometry; `#[.a .b]` *selects* an existing
region. Same shape, because both read as "the X these determine". Whether the
construct/select distinction needs surfacing is an open detail below.)

## Operations

All operate on a bundle and yield a bundle (never a forced singleton).

| op | reads | meaning |
|---|---|---|
| `[ a  b … ]` | union | `a ∪ b ∪ …` (same-typed bundles) |
| `bundle @ x` | ∋ ("has member") | `{ e ∈ bundle : e incident to x }` |
| `bundle \ x` | ∌ ("lacks member") | `{ e ∈ bundle : e not incident to x }` |

- **Chaining** conjoins: `--l @ .p @ .q` = incident to *both*. `--l @ .p \ .a`
  = through p but not through a.
- **`\` is the negated filter** — the natural "pick the opposite ray": with
  `--ba` split at the vertex, `--ba \ .a` is the segment *away* from a (the
  o→rm ray) without naming its far point.
- **Singleton coercion at the slot** (ADR 0016). `@`/`\` produce a sub-bundle
  (0..n); a slot that wants exactly one element demands cardinality 1 and errors
  otherwise ("`--l @ …` matched `k` segments; add a constraint"). Today's `at`
  conflates filter + singleton-projection; splitting them is more composable and
  is exactly the "bundles are values, singletons are slot results" rule.

## Every selector falls out

| today | new | note |
|---|---|---|
| `--l at .p` | `--l @ .p` | segment through p |
| `--l at --d` | `--l @ --d` | segment at the crossing (was "crossing") |
| `--l at #(R)` | `--l @ #r` | segment in a region (was "in") |
| `--l at (.p and --d)` | `--l @ .p @ --d` | conjunction = chain; `and`-form retires |
| `#(.a .b)` | `#[.a .b]` | region = flap-bundle, coerced to one at the slot |
| — | `--ba \ .a` | new: the opposite ray, by exclusion |

`at`, `in`, `crossing`, the `and`-selector, and the `#(…)`/`--(…)` round forms
all collapse into `--[]`/`#[]` + `@` / `\` / `[…]`.

## Migration

Syntax churn (pre-1.0, acceptable): `--(.a .b) → --[.a .b]`,
`#(.a .b) → #[.a .b]`, `--l at <sel> → --l @ <sel>`. `.(…)` is unchanged.
`@flatten`'s surface adopts this directly: `(#[.m] stays)`, and its hinge/return
selectors become `@`/`\` expressions.

## Open questions

1. **Filter symbol `@` vs `&`.** `@` currently prefixes actions (`@fold`,
   `@flatten`). Infix `--l @ .p` is grammatically separable but overloads `@`.
   `&` ("--l with .p") avoids it. **This resolves cleanly if the separate
   action-model revision drops the `@` action prefix** (fold/unfold as verbs) —
   then `@` is free for the filter. So the choice is *coupled* to that pass;
   pick `&` if action-model stays as-is, `@` if it frees the sigil.
2. **Construct vs select under `SIGIL[…]`.** `--[.a .b]` builds a line;
   `#[.a .b]` picks a region. Does the shared notation need a marker for "new
   geometry" vs "existing region", or is "the X these determine" enough?
3. **Face vs flap under `#[]`.** ADR 0017 keeps them at different granularities
   (fine face vs coplanar cluster), context-typed. Does `#[]` carry that
   granularity implicitly (as `#()` does now), or do we need `face[]` / `flap[]`?
4. **Which bundles bind** (ADR 0016). A crease-bundle has a stable identity →
   bindable. Ad-hoc filter results are values, not necessarily bound. Confirm
   the binding surface.
5. **More set ops?** Union/filter/diff cover the current need; intersection and
   others stay out until a use appears (YAGNI).

## References

- ADR 0014 (a crease is a bundle of segments — why crease is always `--[]`),
  0016 (typed operands: bundles are values, singletons are slot results — the
  coercion rule), 0017 (face vs flap granularity — the `#[]` open question).
- `spec/SPECIFICATION.md` §4.8 (`at`'s existing polymorphism this generalises).
- `docs/superpowers/specs/2026-07-07-flatten-primitive-design.md` (the consumer).
