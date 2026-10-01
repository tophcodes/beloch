---
id: "0037"
title: "A fan moves its tip; a single crease moves every layer under it"
date: 2026-09-29
status: accepted
issue: tophcodes/beloch#52
---

# 0037: A fan moves its tip; a single crease moves every layer under it

## Context

ADR 0036 has every write reach every layer under its axis, `flatten`
included: a flatten without an anchor moves every layer under its fan. It
left open whether a flatten with an anchor moves the tip, as `reverse` does.

A fan is several creases through one point folded in one motion: `flatten`,
the squash fold (#17), `reverse`, and later the petal fold (#16). Two cases
separate the two rules.

- The squash of one flap of the preliminary base. Four layers lie under the
  fan on the side of the flap. The rule of all layers opens the flap behind
  as well and gives two squashes, front and back, in one statement. The
  kernel accepts that state, so the rule does not fail; it folds something
  other than the folder meant.
- A four-ray vertex near the corner of a book fold, whose rays end on the raw
  edges and none on the spine
  (`packages/core/tests/cases/collapse/flatten-through-two-layers.bel`). The
  rule of all layers folds both corners as one stack, the corner of the lower
  layer wrapping around the upper one from behind. The tip of the upper
  corner is that corner alone, and the lower corner stays in view.

A single crease through a stack is what a folder makes with one hand pressing
the whole stack, and ADR 0036 keeps it that way. A fan through several
separate flaps would take a hand per flap and per crease. Smith's notation
draws the same line: "where two or more layers are treated as one, then only
valley and mountain folds are involved" [smith1975oil, p. 17]. Where a
diagram does move several flaps with one fan, it says so. Vigo's rooster
outside-reverse-folds its neck with the note "(two points)" [vigo2006rooster,
step 6]; the model is folded in half the step before, so the two points lie
on the two sides of its spine and, as far as the diagram shows, hang
together there, which puts both in one tip. Fisher leaves the moving faces of a multiple fold
undecided [fisher1994, §5.3], and names the waterbomb base on one layer of a
folded rectangle and through both as two things his syntax cannot tell
apart. Under this rule the stayer tells them apart. When the spine lies along
the edge of the staying sector, the pieces beside it stay, no hinge joins the
moving pieces of the two layers, and the tip is the top layer alone. When the
stayer lies away from the spine, the spine's pieces move with the fan and
join both layers into one tip. A square folded in half cannot show the first
case: the spine runs past a waterbomb base on any sub-square and joins the
layers there (#150, #151).

## Decision

**A fan moves its tip.** The anchor of a fan is the flap that carries its
point: the flap $\Phi$ of `def-flatten`, the anchor flap of `def-reverse`.
Score the layers under the fan along its rays, and call the pieces that lie
outside the wedge of the stayer the candidates. The tip is the least set of
candidates that contains the anchor's pieces and is closed under hinges of
any angle between candidates. The tip moves; every other layer stays.

- On a single flat sheet every piece is joined to the anchor, so the tip is
  every layer under the fan and a flatten on one sheet keeps its result.
- A flap of several layers hinged together beyond the fan moves whole: the
  neck of a bird, the body of an animal folded in half, a book fold whose
  fan reaches the spine.
- Separate flaps under the fan stay.

**A single crease moves every layer under it**, as ADR 0036 states for
`mark` and `fold`. The line between the two rules is the number of creases
through one point, which is also what separates a fold from a fan in the
language.

This replaces the sentence of ADR 0036 that has a flatten without an anchor
move every layer under its fan; a flatten always has an anchor.

**Open: an item that widens a fan to separate flaps.** No real case needs it
yet. The candidate is `up to`, which for `fold` names the deepest flap the
fold reaches; for a fan it would add the flaps from the anchor down to the
one it names. It is decided when a model needs it.

## Alternatives considered

- **Every layer for every write**, as ADR 0036 left `flatten`. The squash of
  one flap of the preliminary base becomes two squashes, and a program that
  means one flap has no way to say so short of a narrowing item on every
  squash.
- **Narrow a fan with `up to`, as a fold is narrowed.** On the book and on
  the front flap of the preliminary base, `up to` and the tip select the same
  layers. They differ where the moving flap wraps around others, as the tip
  of a reverse fold wraps its body: `up to` takes a flap and everything
  outward of it, and cannot leave out a flap that lies between the halves.
- **The tip only where the program names an anchor**, every layer otherwise.
  Every squash and every flatten on folded paper would need the anchor
  written out, to state the case a folder makes almost always.

## Consequences

- `def-flatten` in `spec/MODEL.md` moves the tip of $\Phi$ in place of every
  face of $C$, and `rem-all-layers` is settled by this record. `def-reverse`
  already moves its tip and keeps its definition.
- `flatten-through-two-layers.bel` changes its result: the upper corner
  folds alone. Its current state, both corners as one stack, has no
  statement until the widening item is decided.
- The squash of #17 and the petal of #16 are fans and move their tip.
