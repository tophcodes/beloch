---
title: The output
description: What `beloch fold` writes. A FOLD file with one frame per state of the program, extended with Beloch's own fields under the `beloch:` prefix.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

`beloch fold FILE.bel` writes one JSON document in the FOLD format
[@foldformat], extended with fields under the `beloch:` prefix as FOLD's
custom-property rule allows. FOLD is the exchange format the origami tools
read (ADR 0002); the extension carries what the model and the language know
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
  has not folded. `U` never occurs, since a state always knows a crease's
  disposition.
- `edges_foldAngle`: $0$ or $\pm 180$, the hinge angles of the state.
- `faceOrders`: the layer relation $\lambda$ as FOLD encodes it, one triple
  per pair of overlapping faces with the sign taken relative to the second
  face's normal. Pairs that do not overlap are absent, as in the model.
- `frame_classes`, `frame_parent`, `frame_inherit`: FOLD's frame bookkeeping;
  every folded frame is a child of frame 0 without inheritance.

Exact coordinates are rounded to decimal only at serialisation; the values the
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
- `beloch:named_points[].statement` and `beloch:named_lines[].statement`: the
  statement that binds the name, as an index into `beloch:statements`. The
  `step` beside it counts frames and cannot separate two names bound between
  the same pair of folds. It is null for a name no statement bound, which the
  four paper corners are. A FOLD written before every statement was logged
  reports the next state-changing statement instead, which is what the field
  meant then.
- `beloch:vertices_names`, `beloch:named_points`, `beloch:named_lines` with
  `beloch:named_lines_frame`: the names a program gave to points and lines,
  mapped to vertices and to lines. See
  [issue #82](https://github.com/tophcodes/beloch/issues/82) for the frame the
  lines are currently reported in.
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

## What this document will grow into

A worked file for the preliminary base, frame by frame, with the fields
called out; and the diagram output, the YR-style folding sequence, once it
exists.
