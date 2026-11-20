---
id: BEP-0082
title: "An over item orders the faces of its two points"
date: 2026-11-20
status: proposed
issue: tophcodes/beloch#350
reference:
  - reference/beloch-writes#flatten-and-flip
  - reference/model#def-flatten
  - reference/kernel#fan
amends: []
superseded-by: null
---

# BEP-0082: An over item orders the faces of its two points

## Summary

`(.p over .q)` in a `flatten` keeps the states in which the face that
holds `.p` lies above the face that holds `.q`. The two faces must
overlap; a pair that lies apart holds in no state. No other face is
compared. Before this record the item ordered whole pieces: every face of
the piece and sector of `.p` had to lie above every face of the piece and
sector of `.q` that it overlaps. A flap that a fan folds between two
layers of one piece then satisfies no `over` item in either direction.

## Example

The swivel fold of one flap of the folded preliminary base is the squash
fan with one flank a mountain [lang2011secrets, §2.2]. Its letters leave
two states. In both, one face of the staying part lies above the moving
flap; the states differ in whether the flap lies above or below two other
faces of the staying part.

```beloch
.g = free on --bc from .b at 1/4
mark (through .f .b) as --fb
mark (through .a .g) as --ag
.p = free on --fb from .f at 1/10
.w = free on --ag from .a at 9/10
flatten (--h & --da) (--s & --da mountain) (--t & --da valley)
        (--ac & .a valley) (staying .q) (.p over .w)
```

`.p` lies in the flap and `.w` in one of the two faces below or above it.
`(.p over .w)` keeps the state in which the flap lies above that face, and
`(.w over .p)` keeps the other. Under the piece rule both items fail with
`` contradictory `over` ``, because the face of the staying part above
the flap belongs to the same piece as the face of `.w`, while the hint of
the ambiguous statement names an `over` item as what would decide it.

## Rule

In [[reference/beloch-writes#flatten-and-flip]]: `(.p over .q)` puts the
face that holds `.p` above the face that holds `.q`, and the two must
overlap. A point on a crease shared by two faces names neither and is an
error, as before. An item that no state satisfies, a pair of faces that
overlap in no state among them, is `` contradictory `over` ``.
[[reference/model#def-flatten]] states the item as a condition on the
candidate states, and [[reference/kernel#fan]] where the solver applies
it. The order of the other layers follows from the letters and the
non-crossing conditions alone. Where a fan with `(up to <flap>)` keeps the
order of the layers of its stack, an `over` item exempts its pair, as
before.

## Alternatives considered

- **Keep the piece rule and narrow the hint.** The hint would name an
  `over` item only where one separates the states. A flap folded between
  two layers of one piece then has no item that decides it, and the swivel
  fold of a folded flap stays ambiguous.
- **Order the faces of the two pieces that overlap the named faces.** The
  face of the staying part above the flap overlaps the flap as well, so
  the item fails in the swivel fold as it does under the piece rule.
- **A pair that lies apart holds trivially.** An item that compares
  nothing then passes silently, and a misplaced point leaves the statement
  as ambiguous as it was with no hint of why.

## Open questions

- The hint of an ambiguous flatten names an `over` item without naming
  two points that would decide it ([[BEP-0078]] lists suggestions of
  `over` items as not built).

## Consequences

- No program in `examples/` or in the test cases used an `over` item in a
  `flatten`; the kernel's unit tests on a flat sheet name one face per
  sector, where the two rules agree.
- The swivel fold of a folded flap folds to one state with an `over` item.
