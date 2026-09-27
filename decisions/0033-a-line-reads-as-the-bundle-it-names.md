---
id: "0033"
title: "A line reads as the bundle it names; a mark's bundle is its extent"
date: 2026-09-27
status: proposed
---

# 0033: A line reads as the bundle it names; a mark's bundle is its extent

## Context

The selection reads the material of a line (ADR 0031): a `toward` or
`moving` line names the side its material lies on, a moved line carries out
an alignment where its material lands, and the landing stage measures that
material. Three statements of what this material is were in force at once.

- `def-mark` gives a mark's value as a bundle: the material of its line in
  the flap it was marked on, clipped to its extent.
- `def-selection` gives every line in an alignment, a `toward` or a `moving`
  "its material" in the sense of `def-material`: all the paper on its table
  line, in every flap.
- The kernel reads a crease as its own segments, a mark bound by
  `mark … as --x` as all the paper on its table line, and a mark in a meet as
  its own extent.

Issue #62 showed where the second and third reading fail:

```beloch
paper square
mark (through .a .c) as --ac
.o = free on --ac from .a at 1/2
mark (through .a .c) (between .a .o) as --half
fold (map .c onto .o) (toward --half)
```

The fold line crosses the diagonal at three quarters of its length. The
chord of `--half` crosses it and names no side; the stretch from `.a` to `.o`
lies on the side of `.a`, and a folder reading the program folds the corner
`.c` onto the centre.

Two costs weighed against reading the extent. The kernel splits faces only
along whole chords, so the extent of a partial mark is held beside the faces;
and a read that consults it looked like a second representation of paper,
with rules of its own for layers and for later folds.

## Decision

**The material of a line is the bundle the program holds under its name.**
Every read that asks for the paper of a line takes that bundle: the side a
`toward` or `moving` line names, whether a moved line carries out an
alignment, its landing, the meet and the filters. The table line of the
bundle (`def-line`) serves where a line is asked for: the objects of an
alignment and the axis of a write.

**A mark's bundle is its extent**, in the flap it was marked on, as
`def-mark` states. A crease's bundle is its scored segments. A construction,
a name bound to one by `=`, and a paper edge hold all the paper on their
line, since that is their value (`def-construction`). One rule covers all of
them, and a mark is a bundle in the sense of ADR 0014: a fold across it
splits it into pieces that move with their flaps, a fold that bends it
leaves it without a line, and an operation that wants one segment wants one
piece of it.

**A mark that moves carries out an alignment only with marked paper.** Where
a construction folds a mark over onto a point, the paper that lands on the
point has to belong to the mark. A candidate whose landing falls on the
unmarked continuation of the mark's line does not remain. A point folded onto
the line of a mark needs the line only, as ADR 0031 has it for every line.

**How a state stores a bundle is outside this record.** The pieces of a
bundle are read off the state by `def-bundle`, from the set of paper points
the bundle is. Hinges and a record beside the faces are two ways of holding
that set, and neither adds a rule for layers or for later folds: paper
coordinates name one point of one layer, and a later fold moves the point
with its face.

## Alternatives considered

- **The chord of the mark's line.** The extent becomes a drawing, and the
  program of #62 has to name its side with `toward .a`. The material of a
  mark then changes with every later fold, since it takes whatever paper of
  any flap comes to lie on the mark's table line, which is the reading of a
  crease as its line that ADR 0014 retired. `def-mark` and the meet would
  have to change with it.
- **A reading per operation**, the extent for the meet and the chord for the
  selection. Two answers to one question, and a program cannot tell from the
  name which one a statement uses.
- **A mark subdivides the faces it crosses**, split along the whole chord in
  each face and carrying its crease identity only within the extent. The
  reads come out as under this decision, and the crease pattern and the FOLD
  output would have to hide the hinges outside the extent. That is a choice
  of representation and stays open until a need for it shows.

## Consequences

- `def-selection` in `spec/MODEL.md` gives the objects of an alignment and
  the `toward` and `moving` lines their bundles in place of the material of
  their table lines. For creases this states what the kernel already does;
  for marks it changes the kernel, and the program of #62 folds `.c` onto the
  centre. The paragraph in `spec/KERNEL.md` that points at #62 goes.
- A program that moves a partial mark can lose the candidate it had. The
  pinch below runs from the middle of the bottom edge to the centre. Of the
  two candidates, `moving` keeps the one that folds the pinch over, and it
  lands the point of the pinch's line at height $\sqrt{3}/2$ on `.d`:

  ```beloch
  paper square
  mark (through .a .c) as --ac
  .o = free on --ac from .a at 1/2
  .m = free on --ab from .a at 1/2
  mark (through .m .o) (between .m .o) as --pinch
  fold (map .d onto --pinch through .a) (moving --pinch) as --f
  ```

  The fold becomes an error. It succeeds with a mark that reaches the landing
  point, or with `(moving .d)`, which folds the corner onto the line of the
  pinch.
- The error names the point of the mark's line that has to land, with a hint
  to extend the mark to it (ADR 0028). A program learns from it how far a
  pinch has to reach. Folders pinch only where a later fold needs a
  reference, to keep the interior of the sheet free of creases
  [@hull2020, pp. 15–16].
- A mark takes no paper from other flaps. After a fold stacks paper along
  the mark's table line, `toward` and `moving` with the mark read the marked
  layer only.
- A mark at a point (`open-point-mark`) stays open. Whatever sort it gets,
  its material is its point.
