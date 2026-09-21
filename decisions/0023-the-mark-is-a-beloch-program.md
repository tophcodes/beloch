---
id: "0023"
title: "The mark is a Beloch program"
status: accepted
---

# 0023 — The mark is a Beloch program

## Context

The project needed a mark for the favicon, the social preview, slides and the
eventual paper. The favicon it had was a four-pointed star with diagonal rays,
which reads as a compass rose or an AI sparkle and says nothing about paper.

Two directions were explored in full. One drew the digit seven, since the cubic
Beloch fold is axiom 7 in the Huzita-Justin numbering this project uses. The
other drew a single flat-foldable vertex in the crease notation every diagram
here already uses.

The seven direction turned up an obstacle worth recording: **a valid crease
pattern cannot form the digit.** Two straight creases crossing inside the sheet
make a degree-4 vertex with sectors α, 180°−α, α, 180°−α, and Kawasaki's
theorem then forces α = 90°. The result is a square with an X in it, at every
size. Any seven would have to draw its crossbar as a reference line rather than
a crease, so the mark would show a construction the language cannot express.

## Decision

The mark is **one flat-foldable vertex, produced by a Beloch program**, not
drawn. The program is `packages/www/public/brand/mark.bel`.

Three marked lines meet at (1/3, 2/3). Three of the rays there are given;
`flatten` solves for the fourth, which no Huzita axiom constructs from the named
points. It exists only because the vertex has to fold flat, and it is the mark's
single mountain fold.

This is why the vertex, and not a base from the corpus: the mark shows the one
operation that separates Beloch from a library of axioms. A kite or a bird base
would show a crease pattern any origami tool can draw.

The geometry is the evaluator's output, so it is correct by construction rather
than by inspection: sectors 139.40° / 71.57° / 40.60° / 108.43°, Kawasaki sums
to zero, Maekawa gives M − V = −2. A vertex that violated either would be
rejected before it could be rendered.

## Consequences

- The mark ships in two fassungen. Above roughly 48 px it carries the renderer's
  crease notation, mountains and valleys distinguished by dash pattern. Below
  that the patterns collapse into dotted noise, so a simplified fassung draws
  every crease alike. The favicon is the simplified one.
- Colour stays out of the mark. Mountain and valley carry meaning in this
  project, and a mark that used red or blue would spend colours that belong to
  content. The mark takes the ink colour of whatever it sits on.
- The favicon cannot use `currentColor`: a favicon renders with no CSS context
  and would fall back to black on a dark tab. It carries an embedded
  `prefers-color-scheme` rule instead.
- Regenerating the mark needs the evaluator plus `fold2logo.ts`, which strips
  faces, legend and labels and drops the scaffolding creases the program marked
  but never folded. That tool is exploration code today; if the mark is ever
  rebuilt in CI, it has to move somewhere maintained.
- A sheet boundary is drawn, so the mark may occupy at most 87 % of a circular
  crop or an avatar cuts the corners off.
