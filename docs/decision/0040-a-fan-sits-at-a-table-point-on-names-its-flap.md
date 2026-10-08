---
id: "0040"
title: "A fan sits at a table point; on names the flap it folds"
date: 2026-09-29
status: accepted
issue: tophcodes/beloch#52
---

# 0040: A fan sits at a table point; on names the flap it folds

## Context

`def-flatten` takes a paper point interior to one flap $\Phi$ and computes
the rest on the table: it reflects across the images of the rays and scores
every layer under the fan along half-lines from the image of the point. By
[[decision/0037]] a fan moves the tip of its anchor, and the anchor is $\Phi$.

On folded paper one table point lies over a paper point in every layer under
it. A reverse fold through a thick flap, such as the neck of the crane,
crosses its spine in every layer at once, and each of those paper points
lies on a folded edge rather than inside a flap. The fan belongs to the
table point, and the flap the folder takes is one of several under it.

For `reverse` and `squash` the item names that flap: the construction of a
reverse fold moves its anchor, and the bare alignment of a squash names the
spine ([[decision/0038]]). The items of `flatten` name rays, sector orders and a
stayer, and none of them names a flap. On the book fold of #105 a fan at the
corner lies over the corner of the upper layer and the corner of the lower
one, and the two are not joined there. With the upper corner as anchor the
upper corner folds and the lower one stays; with the lower corner as anchor
the reverse.

A `mark` already names the one flap it scores with `on` ([[decision/0039]]).

## Decision

**A fan sits at a table point.** The fan point of `flatten`, `squash` and
`reverse` is a point of the table; under it lies a paper point in every
layer, interior to a flap or on a folded edge. Each layer of the tip is
scored along the rays from the table point.

**`on` names the flap a fan folds.** `flatten (…) (on #[.a])` takes the flap
that `#[.a]` names as its anchor and moves that flap's tip ([[decision/0037]]). The
flap may lie anywhere in the stack under the point: on top, at the bottom or
in between.

**Without `on`, the anchor is the topmost flap under the fan point.** It is
the flap the folder sees and takes. `reverse` and `squash` read their anchor
from their construction or spine, and `on` is not one of their items.

## Alternatives considered

- **An error when several flaps lie under the point**, offering the `on`
  items that keep one, as `flatten` does for its states (#99). A rabbit ear
  on the front flap of a stack is the common case, and it would need `on`
  every time.
- **The topmost flap, and `flip` for the one at the bottom.** A flap between
  others would have no statement.
- **`moving` names the anchor.** By [[decision/0036]] `moving` names a side and
  narrows nothing; naming the anchor would narrow the fan to one tip, the
  double role [[decision/0036]] removed from `fold`.
- **The flap the rays are marked on.** Rays marked on several layers, as the
  `into` records of #105 add them, name no single flap.

## Consequences

- `def-flatten` in [[reference/model]] takes a table point and an anchor flap in
  place of a paper point interior to $\Phi$. The paper point of a layer may
  lie on a folded edge.
- [[reference/beloch]] adds `on` to the items of `flatten`, with the meaning of
  `on` for `mark` unchanged: it names a flap by incidence.
- `on` reads the same in both writes: the flap the write is done on. A mark
  scores that flap alone ([[decision/0039]]); a fan moves its tip, since a flat state
  needs the layers hinged to it to follow.
- #113 takes the topmost flap as the default anchor and adds `on`.
