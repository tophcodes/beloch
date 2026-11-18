---
id: "0061"
title: "A verb chooses its result by conditions, and a squash has two valleys at its flanks"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#269
---

# 0061: A verb chooses its result by conditions, and a squash has two valleys at its flanks

## Context

A squash opens a flap of two layers at its folded edge, the *spine*, and
presses it flat so that the spine lands on a target ([[decision/0038]]). On
the preliminary base the squash of the front flap folds four creases at the
base's closed corner: the spine `--h & --da` opens, `--s` and `--t` fold
one on each layer of the flap along the axis, and the center line `--ac`
folds in the layer under the flap. `--s` and `--t` lie on the two sides of
the opened spine; this record calls them the *flanks*. Written as a fan:

```beloch
flatten (--h & --da) (--s & --da) (--t & --da) (--ac & .a) (on #[.f]) (staying .q)
```

The four creases fold flat in 8 states. The stage of `flatten` that keeps
the states with the fewest mountains leaves 3 of them. All 3 put every
piece at the same place on the table and differ in the layer order:

| state | `--s` | `--t` | `--ac` under the flap |
|---|---|---|---|
| 1 | valley | valley | mountain |
| 2 | mountain | valley | valley |
| 3 | mountain | valley | valley |

States 2 and 3 differ from each other only in the side of two faces
against two others.

Lang names the difference. A squash has two valleys on each side of two
mountains, all four meeting at one point, and "most of the time, the two
valley folds are side-by-side and the squash fold is symmetric about the
valley fold. However, a squash fold can be made asymmetrically and it
sometimes happens that the two valley folds are not side-by-side … This
asymmetric version of a squash fold occurs often enough that it is given
its own name: a swivel fold" [lang2011secrets, §2.2, pp. 27-28]. State 1
is the squash. States 2 and 3 are swivel folds on the same crease lines.

The kernel, the program that evaluates Beloch, stored the layers as one
list of all faces, and its check that two folded creases do not cross
compared faces by their heights in that list. It rejected states 2 and 3,
and `squash` had one result. With a side stored for each pair of
overlapping faces ([[decision/0060]]), the check compares only faces that
overlap, states 2 and 3 are legal, and `squash` on the base reports 3
states.

## Decision

**An operation's result is the set of legal states. An item of the
program is a condition on that set, never a ranking. One state left is
the result, several are an error. A verb is a fan plus the conditions
that define the verb.**

**For `squash`, the two flanks are valleys.** The condition is part of
what `squash` means, and the write passes it to the fan as a letter on
each piece of the axis, the way a letter item of `flatten` reaches the
search ([[decision/0044]]). On the preliminary base it keeps state 1
alone.

## Alternatives considered

- **Keep the list-based check as a filter in the stacking search.** It
  rejects legal states, and it makes the result depend on a list of all
  faces that the paper does not have.
- **Rank the states**, for example with the tip on top. A ranking gives
  some answer on every input and hides the other states from the program.

## Consequences

- The swivel states stay reachable: the explicit fan with `--s` a
  mountain, `--t` a valley and `--ac` a valley leaves states 2 and 3, and
  the program needs one more condition to choose between them.
- The explicit fan selects the squash by conditions with both letters,
  `(--s & --da valley)` and `(--t & --da valley)`. The letter on `--s`
  alone leaves 3 states, of which the fewest-mountains stage picks
  state 1; the letter on `--t` alone leaves 4, and the statement is
  ambiguous.
- The stages of `flatten` that rank states stay as they are: the fewest
  mountains, the dipole with `toward`, and the outline preference of
  [[decision/0056]]. Issue 99 removes the first two.
- [[decision/0038]] says that the squash moves the tip of the flap, which
  opens at the spine while each layer of the tip folds along its piece of
  the axis. This record adds the letter of those pieces: both fold as
  valleys.
