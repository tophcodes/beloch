---
title: Command-line interface
description: The `beloch` command of the reference implementation. Folding a program to FOLD, tracing its selections, watching a file, and rendering.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

`beloch` is the command of the reference implementation. It evaluates a
program with the OCaml kernel (`KERNEL.md`) and writes the file `FOLD.md`
specifies. Like `KERNEL.md`, this document describes one implementation and
binds no other.

Inside the devshell (`nix develop`) the command is on the `PATH`. Without an
argument it prints its usage and exits with 2.

## `beloch fold`

```sh
beloch fold FILE.bel
```

Evaluates `FILE.bel` and writes the FOLD document to standard output. A
program that fails writes nothing to standard output, prints a diagnostic to
standard error, with the source line, the span and a hint where the
evaluator has one, and exits with 1.

```sh
beloch fold --trace FILE.bel
```

Writes the same document with the trace added: every candidate a selection
chose from and what removed the others (`FOLD.md`, "The trace"). A program
that fails still writes the file up to the failing statement, then prints the
diagnostic and exits with 1, so the candidates of an ambiguous statement can
be read.

```sh
beloch fold --watch FILE.bel
```

Folds the file, then folds it again each time it is saved and prints each
result. A fold after an edit recomputes only the statements from the first
changed one on; a line on standard error says how many that were. An error
prints its diagnostic and the watch goes on. The command runs until it is
interrupted.

## `beloch render`

```sh
beloch render FILE.bel|FILE.fold [OUT] [flags]
```

Draws a program or a FOLD file as SVG or PNG. A `.bel` file is folded first,
as by `beloch fold`. The drawing is done by a second program,
`beloch-render`, from `packages/render-2d`; the devshell puts it on the
`PATH`, and without it the command stops with a message saying so.

Without `OUT` the drawing goes to standard output; otherwise the extension of
`OUT` picks the format.

| Flag | Effect |
|---|---|
| `--view cp` | The crease pattern, the flat sheet with every crease. The default. |
| `--view folded` | The folded state, seen from above and turned by the `@orient` in force at the state drawn. |
| `--view side --along --l` | The section of the folded state along the line `--l`: the stack pulled apart, the top layer first, each layer a strip and each folded hinge a turn, beside the crease pattern with the same pieces and hinges named. The line is read on the table of the state drawn: a line bound with `=` after the last fold. [The side view](#the-side-view) states how it is seen and named. |
| `--view faces` | The face graphs of the folded state: which faces share a hinge, drawn on the paper, and which overlap on the table, the top layer first. [The face graphs](#the-face-graphs) states how they are drawn. |
| `--view yr` | The YR-style folding diagram (ADR 0029), one panel per step group in one column. A panel draws the state its step starts from, turned by the orient annotation in force, with a fold line and an arrow for every fold of the step, a fold-and-unfold arrow for a mark, its number above and its instruction below; the last panel shows the final state. A fold that lays its paper on top draws a valley line and a valley arrow, one that lays it underneath a mountain line and a mountain arrow, and a fold of some of the layers on its moving side hooks its arrow's tail around them. An inside reverse fold draws a mountain line on the near layer, a valley line on the far layer where it shows and beyond the edge where the layers open, a push arrow at the folded edge and a valley arrow; an outside reverse fold draws a valley line on the near layer, a push arrow at the folded edge, and a valley arrow and a mountain arrow that wrap around the flap. An existing crease ends short of an edge it ends on and touches an edge it runs under. A `flip` gets a panel of its own: the state the writes before it leave, with the turn-over arrow, and the panel after it shows the other side. Where the turn the orient annotation sets differs from the previous panel's, a circle with arrows and the fraction of the turn stands between the two panels. Panels share one scale until the model is less than half the size it had on the first panel of that scale, measured as the greatest distance between two of its vertices; that panel starts a larger scale. A step that holds a `flip` is split there, `2a` and `2b`, without a hint. A step whose later fold folds paper an earlier fold of the same step moved is split the same way, with a hint on standard error. A fold that lays paper between layers that stay and is no reverse fold is refused. |
| `--step N` | With `--view folded`, `--view side` or `--view faces`, draws the state after `N` writes, `0` being the flat sheet; by default the last state. |
| `--far-side` | With `--view side`, sees the section from the other side of the line: the section is mirrored and the arrows on the cut turn round. |
| `--view stages` | How the selection of one construction went, one row per stage; [The stages view](/cli/stages/) states its rules. A `.bel` input is evaluated with its trace, and a program that fails is drawn up to its failure. |
| `--statement N` | The statement the stages view draws, as an index into `beloch:statements`; by default the one that failed, else the last that chose from candidates. |
| `--stage N` | With `--view stages`, draws stage `N` alone, with the program and the legend. |
| `--checks` | With `--view stages`, adds the rows that say what each stage checks. |
| `--flip` | The folded state seen from the other side. |
| `--labels a,b` | Draws the named points and lines, and only those. |
| `--legend` | Adds the legend of crease kinds to the crease pattern: mountain, valley, border, unassigned. The folded view draws no legend. |
| `--plain` | Writes out no names and draws no point dots and no background: the paper and its creases alone. |
| `--title TEXT` | A caption in the top-left corner. |
| `--hidden dashed\|hide` | Draws covered creases of the folded state dashed, or leaves them out (the default). |
| `--format svg\|png` | Overrides the format `OUT` implies. |
| `--width N` | Width of a PNG in pixels. |
| `--open` | Writes to a temporary file and opens it. |

`beloch render --help` prints the same list.

### The side view

The folded state beside the section carries the cut, with an arrow at each
end that points the way the section is seen. The eye stands on the table
beside the line, looks across it, and sees the stack with the top layer up;
the section runs from the eye's left to its right.

By default the section is seen from outside the paper. The outline of the
state reaches out to some distance on each side of the line, measured along
the line's normal; the eye stands on the side where that distance is
smaller. A line along an edge of the outline is seen from outside that edge,
where the distance is zero. Where both sides reach equally far, the eye
stands on the side from which the section runs left to right on the table,
or bottom to top on a vertical line. `--far-side` puts the eye on the other
side.

Every piece of paper the line crosses is named after the face of the crease
pattern it lies in, the pattern with every crease the program makes, by that
face's position in the pattern, counted from 1. A hinge is named by the two
pieces it joins, the smaller name first (`3|4`), in the section beside its
turn and in the crease pattern where it crosses the line. Every state of one
program reads the same crease pattern, so a piece has one name in every
drawing it appears in, and the sections before and after a write can be
compared piece by piece. A piece that a later crease splits is drawn as the
parts it will split into, each with its own name, divided by a short tick.
Two pieces joined by a flat hinge run on as one layer and are divided by the
same tick. Two pieces of one layer whose raw edges meet share no hinge, and a
small gap stands between them. The crease pattern beside the section draws
the creases of the state drawn and none that a later write scores.

### The face graphs

Two graphs side by side, each with a node for every face of the state as
FOLD counts faces: the faces a `J` edge joins, which only divide a non-convex
sheet into convex pieces, are one node. A face is numbered by its place in the
state's `faces_vertices`, counted from 1, and a node carries the smallest
number among its faces. A node is shaded when its faces lie face down.

On the left, adjacency, drawn on the paper: each node stands at the center of
its largest face, which lies inside the node whatever shape its faces make
together, and two nodes that share a hinge are joined by a path through the
middle of the hinge, red for a mountain, blue for a valley, and dashed gray
for a flat hinge. Where faces are too small to hold their nodes apart, as at
the points of a crane, a node moves off its face and keeps a thin line back to
it.

The graphs read `edges_faces`, so a FOLD file written before that field
existed stops with a message that asks to fold it again.

On the right, superposition: the pairs of nodes whose faces overlap on the
table, as `faceOrders` lists them. A line joins two nodes only when no third
node lies between them; every other overlapping pair follows from those
lines. Each node stands in a row below every node above it, the top layer in
the first row. The rows are found in two passes. First each node stands one
row below the lowest node above it. Then each node moves, between the row
below the lowest node above it and the row above the highest node below it,
to the end where more of its lines go, and to the lower end when as many go
up as down. A short column beside a long one thus ends in the row where the
long one ends, as the tail of the crane ends beside its neck. A line that
spans several rows bends in each row between, at a place in that row beside
the nodes, so no line runs through a node. Nodes that lie over one another in
a cycle share a row, and the lines between them carry arrows from the node
above to the node below.

## Other commands

`beloch --version` prints the version. `beloch check` and `beloch lsp` are
reserved for a type check without evaluation and a language server; both
exit with 1 and say they are not implemented.
