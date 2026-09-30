# Ideas & deferred possibilities

Concepts that came up during design but were set aside: not rejected, only not
needed yet. Check here before reinventing. Unlike `antipatterns.md`, nothing here
has been tried and found wanting; these are just parked.

---

## Def interface / pub-priv

Caller-side `export { .foo } $inst` plus `_`-temps already handle namespace
control sufficiently for single-author use. Author-side interface declaration
(a `pub { .foo --bar }` block at the end of a def, or a `priv` modifier per
binding) would let library authors lock down implementation details.

Revisit when shared `.bel` libraries / distribution is on the table.

## Verbs with an item signature

A `def` is called with `apply name(args)`, which drops the item syntax of
the writes: a petal written by a program would read
`apply petal(… (toward .o))` where a verb of the language reads
`petal (…) (toward .o)`. A `def` could instead declare its items, typed by
their head token as a write's items are, and be called like a write.

The grammar would not grow. A write is already `verb item*`, with items in
parentheses, in any order, classified by their first token; a user verb
parses the same way, and only the check of which items a verb takes moves
from the parser into the evaluator. The FOLD log keeps an `apply` entry for
each call (ADR 0030), so a renderer still sees the repetition.

It needs parameter types beyond point and line first (#143), and a bare
alignment such as `squash (--h onto --ac)` needs a read that finds the
vertex the write completes it with (ADR 0038). Revisit when a model needs
a manoeuvre the specification has no verb for, or when shared libraries
are on the table.

## Geometric destructuring

`export { .p1 } from --line`: pulling the defining points back out of a line
after the fact. Redundant as long as you name the points at construction time.
Could be useful if access patterns in real programs show that points frequently
need to be recovered from a line that was kept but whose inputs weren't exported.

## Looping primitives

`apply name(args)` makes defs re-applicable (closed scope: parameters +
earlier defs only). Useful patterns would need `repeat n { ... }` or
`foreach .p in [...] { ... }`. Requires its own design: conditions,
iteration over paper elements, etc.

## Nested defs & namespace chaining

Defs are top-level only; instances hold points/lines, not other instances.
If real programs want structured sub-results (`.[$bird $petal tip]`), that
needs nested defs plus chained qualified access. Deferred until a concrete
model demands it.

## Re-export cascades

The revised spec has no nested scopes, so lifting an export "one more
level" is meaningless. Becomes relevant only together with nested defs or
module/file namespacing.

## Degree compression via subfields (post-#33, only if needed)

If the #33 benchmarks show degree creep in long models (values carrying ambient
degree though they live in a proper subfield, e.g. √2·√5 = √10 at degree 4
instead of 2), add a demotion pass: compute the element's own minimal polynomial
(one resultant Res_x(gen(x), y − coords(x)) + GCD trick) and re-home it in the
smaller field. Full subfield enumeration (Szutkoski & van Hoeij, principal
subfields) is overkill for this; pull that reference in only if per-element
demotion proves insufficient.

## Approx mode? (--sacrifice-correctness discussion, 2026-07-03)

If #33 shows real models hitting the 3^k degree ceiling: do NOT add a raw
float kernel. Origami is dense in engineered coincidences (fold puts a point
exactly on a line; cross/validity ask "exactly zero?"); float+ε misclassifies
precisely those, yielding silently wrong topology instead of slowness. Instead:
(1) floating-point interval FILTER over the exact kernel (CGAL/LEDA recipe):
float-fast for generic sign queries, exact only when the interval straddles
(no guarantee sacrificed); (2) honest degree budget with a clear error naming the
offending fold, rather than a silent-wrong mode; (3) rendering stays float via
`to_float` as today. Revisit only with #33 benchmark data.

## Named reusable preludes

`paper square with { … }` lets a program bind its own names to the parts of a
sheet. A named, reusable
prelude (`prelude corners { .a = vertex 1 … }`, applied as `square with corners`)
would let several sheets share one spelling.

Left out because no program has yet written the same non-default prelude twice,
and a second declaration construct costs grammar, a namespace of its own and
its own error messages. Revisit when two sheets in one program spell out the
same non-default prelude.
