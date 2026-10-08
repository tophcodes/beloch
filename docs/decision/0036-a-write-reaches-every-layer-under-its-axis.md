---
id: "0036"
title: "A write reaches every layer under its axis; moving names a side"
date: 2026-09-29
status: accepted
issue: tophcodes/beloch#52
---

# 0036: A write reaches every layer under its axis; moving names a side

## Context

On a flat sheet every write reaches the one layer there is. On folded paper
a write has to say which of the layers under its axis it scores or moves,
and the three writes answer that differently today.

- `mark` scores one flap: the one its `on` item names, else the flap that
  carries a point of its line (`def-mark`).
- `fold` moves the outward closure of one flap: the flap its anchor names and
  every layer above it (`def-fold`). `up to` names a deeper flap to start
  from. By [[decision/0031]] `moving` names the side that folds over and the flap that
  moves, so the item that picks a side also narrows the fold to one flap.
- `flatten` moves every layer under its fan (`def-flatten`).

A folder presses a crease through the whole stack under the finger, and ADR
0011 names folding through all layers of a folded stack as a thing the
language describes. Folding one layer alone is the case that needs care: the
layer has to be lifted clear of the others.

The book fold of #105 shows the cost. Its corner bisector runs from the
corner to the spine:

```beloch
paper square
fold (map --ab onto --cd) (moving .a) as --m
.f = --m * --bc
mark (map --da onto --cd) (toward .f) (on #[.a]) as --x
```

On paper that crease cannot be made on the upper layer alone: the triangle of
the upper layer beside the line hangs on the lower layer at the spine, so
creasing it moves the lower layer too. A crease on both layers takes a second
statement per line, `mark (--x) (on #[.d]) into --x`. Folding the corner along
the bisector through both layers takes two helper points on the left edge,
one per layer, for `(moving .h) (up to .g)`, and a second fold through the
stack takes two more.

## Decision

**A write reaches every layer under its axis.**

- `mark` without `on` scores every layer its line crosses. Its bundle is the
  extent on each of those layers, one piece per layer ([[decision/0033]], [[decision/0014]]).
- `fold` moves every layer on the side that folds over. The moving set is
  every face under the axis on that side, closed under hinges of angle 0 so
  that a flap moves whole.
- `flatten` without an anchor moves every layer under its fan, as
  `def-flatten` states.

**`moving` names the side that folds over.** It picks the side by its point,
by the first point of a `#[…]` off the line, or by the material of a line, as
[[decision/0031]] has it, and it narrows nothing. The part of [[decision/0031]] that has
`moving` name the flap that moves is replaced by this record.

**`up to` narrows a fold to the layers from the flap it names outward.** The
moving set grows from that flap as `def-fold` states for its depth. A fold of
the top flap alone names that flap: `fold (…) (moving .a) (up to .a)`.

The placement items `mountain`, `over` and `under` keep their meaning: they
say where the moving set lands in the stack, and nothing about which layers
belong to it.

## Alternatives considered

- **Keep the current reading, where `moving` names the side and the flap.**
  Most folds pick their side with `moving`, and each of them would go on
  moving one flap and what lies on it. The default of all layers would reach
  only the folds that pick their side with `toward` or through their
  construction, and folding the book's corner through both layers would still
  take the two helper points shown above.
- **`moving` names the tip, as `reverse` reads its anchor.** Everything hinged
  to the anchor's flap beyond the axis would move, and separate flaps below
  it would stay. A folder pressing a crease takes the layers under the
  finger, and a reader of the program would have to know the hinges of the
  state to tell which layers the fold takes.
- **All layers for `mark`, one flap for `fold`.** The two writes would read
  one axis two ways, and a `fold` along a `mark` would move less paper than
  the mark scored.

## Consequences

- `def-fold` in [[reference/model]] changes: without `up to` the depth is the
  deepest layer under the axis on the moving side, and the anchor condition
  goes, since the anchor names a side only. `def-mark` takes every layer its
  line crosses when no flap is given. [[reference/beloch]] states `moving` as a
  side, and its example `fold (map .c onto .b) (up to .d)` keeps its
  meaning.
- A program that folds one flap of a folded stack with `moving` alone now
  folds the whole stack. Such programs in `examples/` and the test cases gain
  `(up to …)` naming the flap they fold; the kernel change finds them as
  failing cases.
- A mark that the finger cannot make, on one layer of a flap hinged to
  others along its line, stays writable with `on`. What `on` means for such
  a mark is open (#52).
- `flatten` with an anchor is open (#52): whether it moves the tip, as
  `reverse` does, or keeps every layer under the fan.
- `reverse` keeps its tip: the anchor's flap and what is hinged to it beyond
  the axis. A reverse fold turns one flap inside or outside the others, and
  the layers it leaves are what makes it a reverse fold.
