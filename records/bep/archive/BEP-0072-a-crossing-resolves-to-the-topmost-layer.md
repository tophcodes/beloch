---
id: BEP-0072
title: "A crossing resolves to the topmost layer at its table point"
status: abandoned
---

# BEP-0072: A crossing resolves to the topmost layer at its table point

Built in v0.7-dev, removed in v0.19-dev.

## Proposal

`cross` used to intersect the operands' current table lines and resolve the
table point to the material point on the *topmost layer covering that spot*:
"the one your hand would touch".

## Why abandoned

Wrong twice over. Physically: paper is opaque;
the topmost face can carry **neither** crease, so no layer shows the
crossing your hand touches (`fold-top-two.bel`'s bottom-edge cross resolved to
a point on the *top* edge of the sheet). Semantically: it made a point
*construction* depend on the fold state, while creases are permanent scars
whose paper-space crossing never moves. The bundle case was also ill-posed:
segments scored through several layers are coincident on the table only at
birth, so "the" table line of a crease stops existing after the next fold.

Crossings are computed in paper space, on the material marks; table space
survives only as transient geometry inside axiom evaluation, never as a
value. Rule of thumb since: **if a construct's result can name a layer,
something is wrong: layers are for folding, values are material.**
