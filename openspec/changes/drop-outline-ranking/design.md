## Context

The outline ranking runs in four places: the fan of one vertex, the fans of
several vertices, the pool of a single valley collapse, and the squash. Each
filters the candidate states by whether their faces lie inside the convex
hull of the state before the write and falls back to all of them when none
does. With the ranking switched off, every program in `examples/` folds as
before, and the only test that changes is the rabbit ear without
conditions in the reference, whose error message changes.

## Decisions

- **Remove the ranking outright and let `staying` carry what it decided.**
  At the fish-base vertex the outline drops the four states that take the
  far halves of the lines; `(staying .c)` drops the same four, since none of
  them has a part that holds `.c`.
- **Every `flatten` names its stayer.** Fisher's multiple fold names "a
  single face which does not move during the multiple fold" every time
  [fisher1994, p. 16]. A `flatten` that names its stayer reads without a
  rule the reader has to know.

Rejected alternatives:

- A hard bound that removes every state past the outline: the petal fold
  and every fold that lays paper beside its old place would fail.
- An item that names the outline or its exception: it restates in a new
  word what `staying` already says.
- A default stayer, the part that holds the lowest face under the vertex
  and among those the one of largest area: it matches folding by hand and
  would let a rabbit ear leave out `(staying .d)`, but a symmetric collapse
  from the open sheet ties under it, and a reader has to know the rule. The
  kernel check that asks for `staying` says in a comment that such a default
  could be added later.
- Keeping the wedge between the first two rays as the default of ray items:
  it depends on the order of the items and does not exist for bare lines,
  whose rays lie on either half.

## Risks / Trade-offs

- [A `staying` point added to a program that relied on a default may name a
  different part than the default held still] → compare the FOLD output of
  every changed program before and after the change.
