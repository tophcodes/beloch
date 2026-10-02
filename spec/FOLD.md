---
title: Output format
description: What `beloch fold` writes. A FOLD file with one frame per state of the program, extended with Beloch's own fields under the `beloch:` prefix.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

`beloch fold FILE.bel` writes one JSON document in the FOLD format
[@foldformat], extended with fields under the `beloch:` prefix as FOLD's
custom-property rule allows. FOLD is the exchange format the origami tools
read (ADR 0029); the extension carries what the model and the language know
and FOLD has no field for. `SPECIFICATION.md` §7 is the field-level contract;
this document explains what the file represents.

The output refers to the model by statement ids and to the kernel by module.
Neither refers back.

## A file is the path, frame by frame

The model's meaning of a program is the sequence of states it passes through
(`BELOCH.md`, "A program is a path"). The file records that sequence: the
top-level dictionary is frame 0, the flat sheet with every crease drawn on it
in paper coordinates, and `file_frames` holds one `foldedForm` frame per
statement that moved the paper, each a flat folded state
([def-flat-state](/model/#def-flat-state)) in table coordinates. A reader that
wants only the result takes the last frame; a reader that wants the diagram
sequence takes them all.

A program with several sheets (the sheet-as-value design) keeps this shape: a
frame holds every sheet as its own connected component of the planar graph,
and a field `beloch:sheets` maps faces to sheet names. An assembled body is
one frame like any other, since the model treats it as one folded state.

This is where the history lives that the model's state does not carry. The
file is a record of the run, and no operation of the language reads it.

## Standard fields

Each frame uses the FOLD vocabulary for what FOLD can express:

- `vertices_coords`, `edges_vertices`, `faces_vertices`: the planar graph of
  the faces of the state, vertices deduplicated by coordinate. Frame 0 is in
  paper coordinates, every other frame in table coordinates.
- `edges_assignment`: `B` for the sheet boundary, `M` and `V` for folded
  creases with the letter derived from the state, `F` for a marked crease that
  has not folded, and `J` for a join edge: a flat edge that only divides a
  non-convex sheet into convex faces, whose two faces FOLD counts as one. `U`
  never occurs, since a state always knows a crease's disposition.
- `edges_faces`: per edge, the faces on its sides as indices into
  `faces_vertices`, ascending: one face for a boundary edge, two for every
  other edge, a `J` edge included. Faces joined across `J` edges are what FOLD
  counts as one face, so a reader that wants FOLD's faces merges them there,
  and `M`, `V` and `F` edges separate them.
- `edges_foldAngle`: $0$ or $\pm 180$ in degrees, with FOLD's sign: $+180$
  for `V`, $-180$ for `M`, $0$ for `F`, `J` and `B`, so the sign always
  matches `edges_assignment`. On a folded frame these are the hinge angles of
  that state. Frame 0 carries them too, read from the final state: there they
  are the target angle of each crease, which FOLD allows on a crease pattern.
  Without them a consumer that folds the pattern (Origami Simulator, for one)
  would take the angles from frame 0's geometry, which lies flat and gives $0$
  everywhere.
- `faceOrders`: the layer relation $\lambda$ as FOLD encodes it, one triple
  per pair of overlapping faces with the sign taken relative to the second
  face's normal. Pairs that do not overlap are absent, as in the model.
- `frame_classes`, `frame_parent`, `frame_inherit`: FOLD's frame bookkeeping;
  every folded frame is a child of frame 0 without inheritance.
- `file_author`: the text of the program's `@author` annotation
  (`BELOCH-ANNOTATIONS.md`), absent when the program has none.
- `frame_unit`: the unit the program's file declares (`BELOCH.md`,
  "Sheets"), or `"unit"` when it declares none. It stands in frame 0, and
  every coordinate of the file is in that unit.

Exact coordinates are rounded to decimal only at serialization; the values the
kernel computes stay exact (ADR 0008, 0012).

## Beloch's fields

What the language knows about a state and FOLD cannot say:

- `beloch:edges`: per crease edge, the statement that scored it as an index
  into `beloch:statements` (`statement`) together with its source span, its
  construction (which axiom or verb), the names of the points and lines it
  was built from, and the crease's name if it has one. Consumers join on the
  index; two statements may share a source line, so the span alone leaves
  the join ambiguous. This is the attribution the model calls provenance
  (ADR 0019).
- `beloch:source_line`, on each folded frame: the source line of the
  statement that produced the frame.
- `beloch:statements`: one entry per executed statement in the order the
  statements run, a sourcemap from the program to the frames (ADR 0030). Each
  entry carries the `kind` that says which axis it moves, its `source_line`
  and its `span`, the `frame_index` of the frame it reads against, and its
  `parent`. `fold` and `mark` are the writes: the paper moved, or it was
  scored and stands where it was. `bind` moves the program alone, which a
  point, a construction line, a bundle, a definition and an export all do.
  `apply` runs a definition and names it in `def`; the statements of its
  body follow it, each with the index of the `apply` entry as its `parent`,
  once per execution, and with the span where the body writes them.
  `parent` is null at the top level. A reader stepping through the fold
  sequence walks the writes; a reader of the program walks every entry. A
  FOLD written before `parent` existed carries neither `apply` entries nor
  the bindings of a body.
- `beloch:references`: one entry per resolved mention of a crease name in the
  source, each with the `span` it occupies and what it names: a `crease_id`,
  or `edge` for a paper boundary. The arguments of a `flatten`, the operands
  of a `map`, a filter: every place the program names a crease. The spans a
  crease's own entry in `beloch:edges` carries say where it was *defined*;
  these say where it is *used*, which no consumer can recover by re-reading
  the text, since one spelling names different creases inside a `def` body
  and after a `--x!` rebinding. Deduplicated by (target, span).
- `beloch:annotations`: one entry per annotation in the order the statements
  ran, an annotation in a `def` body once per execution (ADR 0029,
  `BELOCH-ANNOTATIONS.md`). Each carries its `key`, its `namespace` or null,
  its `span` and `source_line`, and its `target`: the first and the last
  index into `beloch:statements` it belongs to. The target is one entry,
  the statement after the annotation, except for `step`, whose target runs
  to the entry before the next `step` or to the last entry. An annotation
  after the last statement of the program or of a `def` body belongs to a
  state, and its target is null; `frame_index` names that state. The keys
  `author`, `design` and `source` belong to the program as a whole
  (ADR 0051), and their target is the string `"program"`; their
  `frame_index` is 0. `args` holds the
  arguments in order, each an object with its `span` and one of `text`,
  `number`, `word`, `point` (with `paper` and `table` coordinates), `line`
  (with the table line's `coeffs` and the `crease_id` when the argument
  names a crease) or `flap` (with its `faces`, indices into the faces of the
  frame `frame_index`, the frame the arguments were read against). A reader
  that removes this field and `file_author` has the FOLD of the same program
  without its annotations.
- `beloch:named_points[].statement` and `beloch:named_lines[].statement`: the
  statement that binds the name, as an index into `beloch:statements`. The
  `step` beside it counts frames and cannot separate two names bound between
  the same pair of folds. It is null for a name no statement bound, which the
  four paper corners are. A FOLD written before every statement was logged
  reports the next state-changing statement instead, which is what the field
  meant then.
- `beloch:vertices_names`, `beloch:named_points`, `beloch:named_lines` with
  `beloch:named_lines_frame`: the names a program gave to points and lines,
  mapped to vertices and to lines. A line bound with `=` is given by its
  coefficients on the table of the step its `step` names, step 0 being the
  flat sheet. A crease is given by its line on the table of the last frame,
  and a crease a later fold has bent has no entry; where a crease lies on the
  paper is its edges, named in `beloch:edges`. `beloch:named_lines_frame`
  reads `creasePattern` for both, which matches neither
  ([#81](https://github.com/tophcodes/beloch/issues/81)).
- `beloch:marks`: reference marks that subdivide no face (`mark … at`,
  `mark … between` ending mid-face), which are creases in the language and no
  edges in the graph.
- `beloch:free`: every free point (`free on … from … at …`) with its
  parameter, so a renderer can offer it as a slider.
- `beloch:faces_matrix`: each face's isometry as a matrix, the restriction of
  $f$ to that face, so a renderer can interpolate between frames without
  re-deriving it.
- `beloch:inspect`: an inventory of creases, segments and flaps of the final
  state keyed by crease id, for the playground's entity inspector.

Everything under `beloch:` is optional to a FOLD reader that does not know
Beloch; the standard fields alone describe each state completely.

## The trace

`beloch fold --trace FILE.bel` adds what the evaluator considered on the way
to each result: every candidate a selection chose from, and what removed the
others. Figures that explain an operation read it (issue #51), and so can an
editor that shows the candidates while a program is typed. Without `--trace`
none of this appears, and every other field is the same with and without it.

- `beloch:trace`: one entry per construction and per write the program
  evaluates, in the order they run. Every entry carries the `statement` it
  belongs to as an index into `beloch:statements` and the `frame_index` of
  the state it read: for a statement that moves paper the state before it,
  where the statement's own `frame_index` names the state after. A statement
  with a construction and a write, such as `fold (map .b onto .c)`, has two
  entries, the construction's first.
- A construction's entry covers a construction inside a `fold` or `mark` and
  one on the right-hand side of a binding alike. It carries the `axiom` tag
  as in `beloch:edges`, the `toward` point when the statement names one (a
  `toward` line leaves it null), and `candidates`: every line that satisfies
  the construction's alignments, each with its `line` (the table line's
  `coeffs` in that state) and `removed_by`, the stage of the selection
  ([def-selection](/model/#def-selection)) that removed it: `"paper"` for a
  line that creases no face, which the model does not count as a candidate
  at all ([def-construction](/model/#def-construction)); `"heading"` for one
  farther in direction from the `heading` line than another; `"toward"` for
  one whose side the `toward` names no fold of, or whose landing lies
  farther from the `toward` than another's; `"moving"` for one whose side
  the anchor of `moving` names no fold of; `"moved"` for one along which no
  fold carries out every alignment; and null for one no stage
  removed. `selected` is true on the line the construction yields. For
  axioms 6 and 7 the entry also carries `conics`: the parabolas whose
  tangents these lines are, each as a `focus` point and a `directrix` line,
  and each candidate that crosses paper carries its `landing`: the
  reflection across it of the point of the first alignment, where that
  point lands when it lies on the side that folds over. For axiom 6 the
  entry carries `circle`, with the `center`, the point the crease passes
  through, and `through`, the point that moves: its landings lie where the
  circle meets the target line.
- A construction's entry also records what each stage of the selection
  found, so that a figure can draw the stages without repeating them. The
  entry carries `alignments`, the `onto` alignments in the order the
  candidates' `attempts` index them, each with its `span` and its two
  `objects`: a `name`, and a `point` or the table `segments` of a line's
  material ([def-material](/model/#def-material)). `spans` holds the source
  spans of every alignment (`alignments`, `onto` or not) and of the
  `heading`, `toward` and `moving` items, each span covering the item
  inside its parentheses, or null where the program has no such item.
  `operands` lists the points and lines the construction is built from, the
  point of a `through` included, each an object as in `alignments` and
  placed in the state the construction read. `toward_name`, `moving_name` and `subject` spell the
  `toward` target, the `moving` operand and the `x` of `(x toward …)`.
  `moving_point` is where the anchor of `moving` lies on the table when it
  names a point, and null otherwise. `heading_name` and `heading_line` give
  the `heading` line and its `coeffs`, and `toward_segments` holds the
  material of a `toward` line, empty for a `toward` point. Each
  candidate carries `removed_at`, the stage that removed it: `"paper"`,
  `"heading"`, `"side"` (the side items name no side of it, or name the
  same side twice), `"moved"` (the fold with its side does not carry
  out every alignment) or `"landing"` (it does not fold the subject of
  `(x toward …)` over, or lands farther from the `toward` than another), and null for one no stage removed. A field of a
  stage the candidate did not reach, or the program does not use, is null
  or empty. `angle` is the angle in degrees between the candidate and the
  `heading` line. `side` is the side that folds over, as the sign in
  `terms`, and `side_from` says where it came from: `"toward"`,
  `"moving"`, `"alone"` for the only side whose fold carries out every
  alignment, and `"first"` for the side of the first object of the first
  alignment where both sides do. `attempts` lists the sides the
  moved-material stage tried, two without side items and one otherwise, each
  with its `side` and one value per alignment: `0` or `1` for the object
  that folds onto the other, `"already"` for a point that lies on the
  candidate and on its target line, and null where the fold does neither.
  Beside them each attempt lists `motions`, one per alignment: null where
  no object moves, and otherwise the `source` that moves and its `image`,
  both as segments: a point and where it lands; for a line that lands on a
  point, the place of the line that lands there and the point; for a line
  that lands on a line, the part of it on the side that folds over and
  that part reflected.
  `subject_folds` says whether that side folds the subject of
  `(x toward …)` over. `landed` is the landed material the landing stage
  measured, as segments, a point as a segment of length zero,
  `distance` its distance to the `toward`, and `nearest` the pair of
  points that distance lies between, the landed one first. Where several
  candidates remain, each carries `suggestion`: the item that keeps it
  alone, as the program would write it (`"(toward .d)"`,
  `"(--v toward .u)"`), chosen as `BELOCH-CONSTRUCTIONS.md` states beside the errors of
  the selection; null where none does, and on every candidate of a
  selection that decided.
- A write's entry carries `write`, one of `"fold"`, `"reverse"` and
  `"flatten"`, the `terms` of the write's definition in the state it read,
  and the `candidates` it chose from. A region of paper in the terms is a
  list of polygons, one per face, in table coordinates; a segment is a pair
  of points. Each candidate carries its `frame`, the candidate state as a
  `foldedForm` frame of the same shape as those in `file_frames`, or null
  where no state exists; `removed_by`, the rule that removed it or null; and
  `selected`, true on the state the write yields. Where several candidates
  keep `removed_by` null and none is `selected`, the write was ambiguous and
  the program failed.
- `fold` ([def-fold](/model/#def-fold)): the `terms` are the `axis` as a
  table line's `coeffs`, the `side` that moves as the sign, $1$ or $-1$, of
  $ax + by - c$ there, the `moving` set, and the `placement`: `"top"`,
  `"bottom"`, `"over"` or `"under"`, the last two with the `target` region
  the block is placed against. The moving set is the region as it lies
  before the fold. A fold chooses no state, so its `candidates` are empty and
  the state after it is the statement's own frame. A fold that would tear the
  paper still has its entry, and the file then ends before the fold.
  An `unfold` ([def-unfold](/model/#def-unfold)) reflects one block as a
  fold does, and its entry has the same shape, with `write` `"fold"`.
- `reverse` ([def-reverse](/model/#def-reverse)): the `terms` are the
  `axis`, the `side`, the `kind`, `"inside"` or `"outside"`, and the `tip`.
  The entry has one candidate per opening of the tip, from the bottom of the tip
  up, each with `spine`, a hinge across the opening, as a segment, its
  `halves`, the lower and the upper block, and its `bodies` as two regions
  each, the lower first, and `removed_by`: `"letter"` when a letter item
  gives a hinge of the spine's line another letter, `"bodies"` when a block
  has no body, `"interleaved"` when the bodies are not separated, and
  `"crossing"` when the reflection is no state. `bodies` is null on a
  candidate removed before it exists, and `frame` is null on every removed
  candidate.
- `flatten` ([def-flatten](/model/#def-flatten)): the `terms` are the
  vertex `point`. The entry has one candidate per candidate state, each with the
  `rays` of its fan that the program gave, its `emergent` ray or null, and
  its `stayer` as the ends of the two rays that bound the stayer sector,
  counter-clockwise; a ray is a segment from the vertex. The letters of a
  candidate are the assignments in its frame. `removed_by` names the stage
  of the selection
  ([open-flatten-selection](/model/#open-flatten-selection)) that removed
  it: `"opposite"` for an emergent ray on the far side of a given ray's
  line, which the selection falls back to only when no emergent ray on a new
  line closes the vertex, `"toward"` for a state whose moved material lies
  farther from the `toward` point than another's, `"mountains"` for one with
  more mountains on the given rays than another, and `"top"` for one that
  puts less of the material toward the point on top.
- `beloch:error`: present when the program fails, with the `message`, the
  `hint`, the `span` and the `statement` index of the statement that failed.

With `--trace`, a program that fails still writes a file: the frames up to
the state the failing statement read, its entry in `beloch:statements`, and
its trace entries. An ambiguous construction leaves several candidates with
`removed_by` null and none `selected`, and so does an ambiguous write; that
is the state a figure draws to show why the program has to choose. The exit
code is that of the failure.

## What this document will grow into

A worked file for the preliminary base, frame by frame, with the fields
called out; and the diagram output, the YR-style folding sequence, once it
exists.
