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

## Degree compression via subfields (post-#33, only if needed)

If the #33 benchmarks show degree creep in long models (values carrying ambient
degree though they live in a proper subfield — e.g. √2·√5 = √10 at degree 4
instead of 2), add a demotion pass: compute the element's own minimal polynomial
(one resultant Res_x(gen(x), y − coords(x)) + gcd trick) and re-home it in the
smaller field. Full subfield enumeration (Szutkoski & van Hoeij, principal
subfields) is overkill for this; pull that reference in only if per-element
demotion proves insufficient.
