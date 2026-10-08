---
title: "unfold turns layers over a crease and opens the hinges on it"
date: 2026-10-02
status: accepted
issue: tophcodes/beloch#205
---

# unfold turns layers over a crease and opens the hinges on it

## Context

`fold` refuses a line that cuts no face. Two kinds of line pass that test.

- All of the paper lies on one side: the edge of the paper, a single corner,
  or a crease folded so that every layer lies beside it. The square folded in
  half lies beside its crease `--d`.
- The paper lies on both sides, and every face ends at the line. That happens
  once a hinge on the line lies flat: the spine a squash opens, or a crease
  opened again.

The kernel refuses both with one message, which says that the line lies along
the edge of the paper.

On a line of the first kind a folder turns some of the layers back over the
line. After two folds of the square in the same direction, the layers lie
beside `--q`, the crease of the second fold:

```beloch
paper square
fold (map .b onto .a) as --d
.m = --d * --ab
fold (map .m onto .a) as --q
```

Turning the layer of `.b` back over `--q` opens hinges on `--q` and closes
none. `lem-toggle` in [[reference/model]] says why: reflecting faces across a line
toggles every hinge on the line between a moving and a stationary face, and
where every layer lies on one side, each such hinge is folded. [[decisions/flap-is-coplanar-not-precrease-partition]] plans
the write as "`unfold` + layer selection".

`def-fold` already reflects such a set, given a depth, and the kernel's
refusal stands in front of it. Without a depth `def-fold` moves every layer on
the moving side, which is every layer, and toggles nothing. By [[decisions/a-write-reaches-every-layer-under-its-axis]]
`moving` names a side, and where all of the paper lies on one side, the side
names no layers.

## Decision

**`unfold` turns the layers it selects over a crease.** Its axis is a crease
the program has scored, named or narrowed with `&`. A construction and a line
bound with `=` are refused: the hinges an unfold opens are on the paper
already, and a construction would select its line with the items that select
the layers here. It scores no crease and takes no `as` or `into`.

**Its items are `moving`, `up to` and `toward`.**

- `(moving p up)` names the flap the moving layers grow from and takes every
  layer above it; `(moving p down)` takes every layer below it. `(moving p)`
  alone is `up`. Through `p` the item also names the side of the axis the
  layers leave.
- `(up to f)` names a deeper flap to grow from, as in `fold`.
- `(toward p)` names a layer that stays.

`fold` keeps its `moving` item without a direction and refuses `up` and
`down` there, with an error that says so. `unfold` refuses `(mountain)`, and
its error names `(moving … down)`. `over` and `under` are refused. The moving
layers land beside the stack on the far side of the axis, above or below
every layer there.

**The moving set is the one `def-fold` gives for a depth.** It holds the flap
`up to` names, else the flap `moving` names, every layer outward of it (above,
or below with `down`) and every layer joined to those by a hinge off the
axis. With `toward` alone, the same closure runs inward from the layer it
names, and that set stays: every other layer on its side of the axis moves.
With `toward` beside `moving` or `up to`, the write fails where the layer
`toward` names would move.

**What it does.** The moving set is reflected across the axis as one block,
on top of the stack there, or at the bottom with `down`: the layers turn as
one block about the axis, so the direction that selects them also places
them. By `lem-toggle`
every hinge on the axis between a moving and a staying layer opens.

**Errors.**

- A moving layer that would not cross the axis: one the axis cuts, or one
  joined to a staying layer by a flat hinge on the axis. Turning it over would
  fold that layer or that hinge, which `fold` does, and the message says so.
- No hinge on the axis between a moving and a staying layer, as when every
  layer moves.
- A hinge off the axis between a moving and a staying layer, which would tear
  the paper, and a state that crosses itself: the errors of every write.

**`fold` refuses a line only when all of the paper lies on one side of it**,
and its message names `unfold`. A fold along hinges with paper on both sides
reflects the layers on the moving side, and by `lem-toggle` the flat hinges
on the axis between moving and staying layers fold and the folded ones open.

**[[reference/model]] gets a definition of its own**, `def-unfold`, beside
`def-fold`. Its moving set with a depth is the one of `def-fold`; its moving
set named by the layer that stays, and its domain, are its own. The domain
asks that every hinge on the axis between the moving set and the stationary
faces be folded, and that one exist. A corollary of `lem-toggle` states that
every such hinge opens.

## Alternatives considered

- **Lift the refusal and let `fold` turn the layers**, as
  `fold (--q) (moving .b) (up to .b)`. `def-fold` describes it, and the
  kernel's moving set for `up to` is the same. Without `up to` the statement
  turns every layer over and changes nothing. A reader of a fold could not
  tell from its text whether it opens hinges or folds new ones.
- **The layer `moving` names and what hangs on it off the axis, without the
  layers outward of it.** On the two folds above, the layer of `.b` lies inside
  the outer hinge on `--q`. Turned out alone, it passes through that hinge,
  and the state crosses itself.
- **The direction chosen by which result is a state.** On the two folds above
  both directions give a state: the layers above `.b` turn with it and open
  one hinge, or the layer below turns with it and both hinges open. The result
  of a statement would depend on a check its text does not show.
- **`(mountain)` for the layers below.** On `fold`, `mountain` places a
  block that the side of the axis has already selected. On `unfold` it would
  select which layers turn, and one word would do two jobs on two verbs.
- **`over` and `under` for the direction.** `fold` uses them to place a block
  against a stationary flap; on `unfold` they would name the moving layers
  relative to the flap that moves.
- **`unfold` naming an earlier statement to undo.** Later writes may have
  moved the layers that statement folded, and the folder opens what lies in
  front of them, not a step of the history.

## Consequences

- [[reference/beloch-grammar]] adds the verb and its item; [[reference/beloch-writes]]
  states the write with a program; [[reference/model]] adds `def-unfold`.
- The trace records an unfold with the terms of a fold: axis, side, moving set
  and placement. The reflection is the one of `def-fold`.
- Opening a hinge merges two flaps into one: the flaps of [[decisions/flap-is-coplanar-not-precrease-partition]] are found
  again from the flat hinges at every lookup, so a merge needs nothing more.
- Step 8 of the traditional frog (#189) turns half of a squashed flap over
  the line where the spine of the squash lies flat. The paper lies on both
  sides there, so the step is a `fold`, which the narrowed refusal lets
  through. `unfold` refuses it and names `fold`.
- Step 14 of the flapping bird (#208) turns the half petal between the two
  wings down over the line of step 13. `unfold` turns it, and one of the
  wings turns with it in either direction: a flap between two others needs
  the moving set that #208 leaves open.
