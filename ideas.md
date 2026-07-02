# Ideas & deferred possibilities

Concepts that came up during design but were set aside — not rejected, just not
needed yet. Check here before reinventing. Unlike `antipatterns.md`, nothing here
has been tried and found wanting; these are just parked.

---

## Step interface / pub-priv

Caller-side `export { .foo } from apply $step(args)` already handles namespace
control sufficiently for single-author use. Author-side interface declaration —
a `pub { .foo --bar }` block at the end of a step, or a `priv` modifier per
binding — would let library authors lock down implementation details.

Revisit when shared `.bel` libraries / distribution is on the table.

## Geometric destructuring

`export { .p1 } from --line` — pulling the defining points back out of a line
after the fact. Redundant as long as you name the points at construction time.
Could be useful if access patterns in real programs show that points frequently
need to be recovered from a line that was kept but whose inputs weren't exported.

## Looping primitives

`apply $step(args)` with dynamic scoping makes steps re-applicable. Useful
patterns would need `repeat n { ... }` or `foreach .p in [...] { ... }`.
Requires its own design — conditions, iteration over paper elements, etc.
