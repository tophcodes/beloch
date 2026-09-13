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
statement, each a flat folded state ([def-flat-state](/model/#def-flat-state))
in table coordinates. A reader that wants only the result takes the last
frame; a reader that wants the diagram sequence takes them all.

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

- `beloch:edges`: per crease edge, the statement that scored it, its
  construction (which axiom or verb), the names of the points and lines it
  was built from, and the crease's name if it has one. This is the
  attribution the model calls provenance (ADR 0019).
- `beloch:source_line`, on each folded frame: the source line of the
  statement that produced the frame.
- `beloch:statements`: one entry per state-changing statement in source order,
  a sourcemap from the program to the frames.
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
