---
id: BEP-0076
title: "A flatten anchors on several flaps"
date: 2026-11-18
status: accepted
issue: tophcodes/beloch#320
reference:
  - reference/model#def-flatten
  - reference/beloch-writes#flatten-and-flip
  - reference/beloch-grammar
amends: [BEP-0037]
superseded-by: null
---

# BEP-0076: A flatten anchors on several flaps

## Summary

The `on` item of `flatten` names the flap a fan folds, its anchor. A petal
fold on a squashed flap lifts two layers that are separate flaps, so one
flap cannot name what the fold moves. `on` takes several flaps, and the
anchor is all of them.

## Example

The traditional frog squashes the four flaps of the preliminary base, then
petal-folds each squashed flap (issue 189). After the squash the front
flap is a kite with the paper center `.o` at its top and the corners `.c`
and `.d` at its bottom. Its upper half holds the two layers the squash
turned over; its lower half holds the two layers that kept their place,
one on each side of the center line. The point `.y` lies on the layer of
`.d`, the point `.z` on the layer of `.c`. Folded hinges join each of the
two to the layer above it and to a layer below it, and no hinge joins the
two to each other.

The petal fold lifts the lower half of the kite. One `on` item names one of
its two layers:

```beloch
.p1 = --s4 * --cd
.p2 = --t4 * --cd
mark (perp --mid through .p1) as --pp
flatten (fan (--pp & .p1) (map .p1 onto --mid through .d) as .e1)
        (fan (--pp & .p2) (map .p2 onto --mid through .c) as .e2)
        (on #[.y]) (staying .o) as --pf1
```

The statement fails with `the fans do not fold flat together`: the layer of
`.d` moves, the layer of `.c` stays, and the fan at `.e2` has nothing to
fold. `(on #[.y .z])` fails, since no flap holds both points, and a second
`on` item fails with `only one on item per flatten`. Under this record the
statement names both:

```beloch
flatten (fan (--pp & .p1) (map .p1 onto --mid through .d) as .e1)
        (fan (--pp & .p2) (map .p2 onto --mid through .c) as .e2)
        (on #[.y] #[.z]) (staying .o) as --pf1
```

## Rule

In [[reference/model#def-flatten]]: the anchor $\Phi$ is one flap or the
union of several. The rest of the definition reads $\Phi$ as it stands: the
staying points lie on $\Phi$, so on one of its flaps, and the tip is the
least set of candidates that holds the candidates of every flap of $\Phi$
and is closed under hinges.

In [[reference/beloch-writes#flatten-and-flip]] and
[[reference/beloch-grammar]]: the `on` item of `flatten` takes one or more
flap operands, `(on #[.y] #[.z])`, and stands at most once. Each flap
operand names one flap, as a single one does.

## Alternatives considered

- **`up to` for a fan**, as [[BEP-0037]] proposed: the flaps from the
  anchor down to the one it names. It reads the stack by depth. The two
  layers of the petal lie side by side, one on each half of the kite, so no
  depth separates them from the layers that stay.
- **A tip that follows earlier hinges across regions.** The fan would move
  every layer that a folded hinge joins to the anchor, in any region. The
  layer of `.c` is joined to the layer of `.d` only through the upper half
  of the kite, whose turned-over layers move in part, so the tip would grow
  past what the petal lifts, and every program with a fan would change its
  states.
- **Several `on` items.** It reads as several anchors with one item each.
  One item with several flaps keeps the rule that a statement has one
  anchor.

## Open questions

- Whether `mark` takes several flaps in its `on` item, so that the
  horizontal crease of the petal scores the two layers alone (issue 320).
- Whether `fold` and `reverse` take several flaps in `on`. No model has
  asked for it.

## Consequences

- The four petal folds of the frog base are one statement each.
- [[BEP-0037]] named the item that widens a fan to separate flaps as open;
  this record settles it for `flatten` as several flaps in `on`.
- A single flap in `on` folds as before.
