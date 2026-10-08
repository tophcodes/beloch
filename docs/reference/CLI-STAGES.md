---
title: The stages view
description: How `beloch render --view stages` draws the selection of one construction, one stage per row, and what each mark in it means.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

`beloch render FILE --view stages` draws how the selection of one
construction ([[reference/model#def-selection|def-selection]]) went: which
candidates the construction produced, which stage removed each of them,
and the one that remains, or why none or several remain. Like the rest of
`CLI.md`, this page describes the reference implementation and binds no
other.

The view reads the trace that `beloch fold --trace` writes (`FOLD.md`, "The
trace") and repeats no part of the selection. Every candidate, side,
landing and distance it draws is one the trace carries.

## Invocation

```sh
beloch render FILE.bel|FILE.fold [OUT] --view stages [--stage N] [--checks]
```

Without further flags the view draws the construction of the statement a
traced run failed at, and otherwise the last statement that chose from
candidates, as the candidates view does.

| Flag | Effect |
|---|---|
| `--stage N` | Draws stage `N` alone, with the program block and the legend. |
| `--checks` | Adds the rows that say what each stage checks, for a figure that explains the selection. |

The output is SVG or PNG, as for every view.

## Two readers

The view has one grammar for two readers. The author of a program is the
reference case: which stage decided my candidates, and what do I write when
none did. A figure in the specification adds, with `--checks`, what each
stage checks. The flag changes which text rows appear and nothing in the
drawing.

## Layout

The figure is one column, read from top to bottom.

- **Program.** The statement the view draws, in bold, after the statements
  that define the names it reads, directly or through other names, in
  program order. Statements in between are left out.
- **One row per stage**, 0 to 4, in order. A row holds the paper on the
  left and on the right the title, the statement with the part the stage
  reads underlined, and the text rows. A long statement wraps between its
  items.
- **A stage the construction does not use** keeps its place as a short gray
  row: its title and one line, "Skipped, as the fold names no heading."
  A stage the construction uses keeps its full row even when it removes
  nothing.
- **One square per candidate.** When the marks of several candidates would
  cover each other, the stage draws one full-size square per candidate,
  stacked in the left column. The text stays on the right.
- **The closing block** follows the last stage, in the right column:
  Outcome, and Next when the construction ends with several candidates or
  none.
- **The legend** closes the figure. It shows only the marks the figure
  uses, drawn as they appear, in three groups: the states of a candidate,
  the paper and what the stages read, and the marks of the stages.

A rule between two stages separates their rows, and a heavier rule
separates the last stage from the closing block. The drawing area reaches
as far beyond the paper as its content does: a parabola, a landing past
the edge.

Every stage title names what the stage does:

| Stage | Title |
|---|---|
| 0 | generate candidates |
| 1 | compare with the heading |
| 2 | name the folding side |
| 3 | check what the fold moves |
| 4 | measure the landing |

## Candidates

A candidate is numbered from 1 in the order the trace lists the candidates
of stage 0, and keeps its number in every row. A line that creases no face
is no candidate: stage 0 does not draw or number it.

The number is the candidate's identity. It stands in a circle at one end of
the line, outside the paper, and in front of every text row about the
candidate. Color repeats the number: blue, orange and purple from the
highlight colors, in that order. Green and red are left out, since they
read as pass and fail. Only candidates are colored; what a stage reads or
constructs is slate.

| State | Line | Number |
|---|---|---|
| in the selection | solid, medium weight | outlined |
| eliminated by this stage | hairline | crossed out |
| eliminated by an earlier stage | not drawn | not drawn |
| kept, in the last stage | as the fold it makes: valley, mountain or mark | filled |

## Marks

The paper, its creases and its marks are drawn as in the crease-pattern
view, and every mark keeps the meaning it has there. A dotted line is a
line drawn on the paper and not folded.

| Role | Mark |
|---|---|
| what a stage reads | a thin solid slate line, always labeled |
| an edge a stage reads | a slate rail set inside the paper, parallel to the edge, labeled |
| a construction | thin slate: the circle of axiom 6, the parabolas of axiom 7 |
| the `toward` or `moving` target | a filled black diamond, labeled |
| the side that folds over | hatching in the candidate's color, its number inside; each candidate has its own hatch angle |
| a point that moves | a filled dot, an arrow, and an outlined ring where it lands, labeled with a prime: `.d` becomes `.d′` |
| a piece of line that moves | a filled bar, an arrow, and an outlined bar where it lands, labeled `--ef′` |
| a motion the paper cannot make | a thin arrow from a cross where the missing paper would be, and a label naming it |
| where a point can land (stage 0) | a thin line from the point to the landing, with a right-angle mark where the candidate crosses it |
| an angle | an arc in the candidate's color, with its value |
| a distance | a line from a dot on the nearest landed point to the target, its value in a tag with the candidate's number |

A source is filled and its image is the same shape outlined, so a thing and
the place it lands read as a pair. Every mark that belongs to a candidate
carries its number: arrows, images, distances, hatched sides. A label never
covers a line; it sits in a tag or at the end of a leader.

Every distinction above holds in black on white, where the numbers, the
hatch angles and the line weights carry what color carries on screen.

## Stage by stage

### 0 · generate candidates

Stage 0 constructs the candidates and removes none. The paper shows the
construction of the axiom:

- **Axiom 5**, a line onto a line: the two lines and, per candidate, the two
  equal angles it makes with them.
- **Axiom 6**, a point onto a line through a point: the circle about the
  point on the crease through the point that moves, the target line drawn
  past the paper, and per candidate the landing and the line from the point
  to it.
- **Axiom 7**, two points onto two lines: both parabolas. The candidates are
  their common tangents.

Its rows are Constructs, with `--checks`, and Yields, which names each
candidate by what it is: "① halves the angle at the top right".

### 1 · compare with the heading

The heading line as input, and the angle of each candidate to it, as an
arc with its value where the two meet. The candidates at the smallest
angle pass; a tie passes on.

### 2 · name the folding side

The target of `toward` or `moving`, and per candidate the hatched side that
folds over. A candidate the item names no side of is eliminated here, with
the reason: "--ab crosses it, so it names no side".

### 3 · check what the fold moves

Per candidate and alignment, the motion that carries the alignment out.
Whoever moves lands on the paper of the other object:

- a point onto a line: the point, its arrow and its image on the line;
- a line onto a point: a short piece of the line around the place that
  lands on the point, and its image through the point;
- a line onto a line: the piece of the line that folds over, and its image
  on the other line.

With neither `toward` nor `moving`, the Result row names the side that
folds and why: "the side of .d folds over, as the statement reads".

### 4 · measure the landing

The images of what the stage measures, the target, and per candidate the
distance from the nearest landed point. `(toward …)` measures the objects
of the alignments; `(x toward …)` measures `x` alone.

## Text rows

| Row | Stages | Appears | Says |
|---|---|---|---|
| Constructs | 0 | with `--checks` | how the axiom produces its candidates |
| Yields | 0 | always | each candidate, by what it is |
| Checks | 1 to 4 | with `--checks` | the stage's criterion in one sentence; a default names its reason |
| Result | 1 to 4 | always | per candidate its verdict, then what the stage measured |
| Outcome | closing block | always | the kept candidate, or that several or none remain |
| Next | closing block | when several or none remain | per candidate the item that keeps it |

A Result line starts with the candidate's number, drawn in the state it has
in the square, then the verdict: `passes` or `eliminated`, and in the
Outcome `holds`. The verdict is bold; the line of an eliminated candidate
is gray. A value shows as many decimals as it takes to tell two different
values apart, at least two. Values that print alike are a tie in the exact
comparison, and the line says so.

Next shows the suggestions the trace carries, one per remaining candidate:
"① to keep it, add (toward .d)". The view computes none of them.
