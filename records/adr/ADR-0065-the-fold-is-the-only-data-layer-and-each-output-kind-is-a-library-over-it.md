---
id: ADR-0065
title: "The FOLD is the only data layer, and each output kind is a library over it"
date: 2026-11-18
status: accepted
---

# ADR-0065: The FOLD is the only data layer, and each output kind is a library over it

This record holds the architecture part of [[BEP-0029]], which decided both kinds.

## Context

[[ADR-0002]] planned a small, versioned JSON schema for step-by-step diagrams,
beside the FOLD. Since then the FOLD has grown what that schema would have
carried. It holds one frame per state ([[reference/fold]]), and [[BEP-0026]] put every
statement into `beloch:statements` with its kind, its source span and the
frame it stands on. A consumer can walk the program and the states without
parsing the source.

The media differ more than one schema can absorb. A printed YR page holds a
grid of panels with arrows and fold lines. A screen reader gets sentences and
no picture. A shared instruction schema would either take the smallest common
part of these or grow a branch per medium, and in both cases the real layout
work would still happen in each consumer.

## Decision

**The FOLD is the only data layer.** FOLD stays the output format, with
Beloch's fields under the `beloch:` prefix. No page files sit beside the
program, and no second file format exists. The frames, `beloch:statements` and the
annotations together are everything an output reads. The annotations live in
one top-level field, one entry per annotation, each naming its target as a
range of indices into `beloch:statements`. A range fits the step group, which
spans statements and frames, and a single statement is a range of length one.
The field-level contract goes into [[reference/fold]].

**Each output kind is a TypeScript library at the edge ([[ADR-0001]]).** A library
offers two sets of primitives:

- primitives that *select*: statements, labels, annotations and frames, read
  from the evaluated FOLD. They can build on the runtime core of [[ADR-0024]],
  which already holds the document and the step over the writes;
- primitives that *draw* for its medium: for YR a panel, an arrow, a fold line
  in YR notation and the layer that moves.

An output is a function that receives the evaluated program, calls these
primitives and writes the result: a PDF, a set of SVG files, a text for a screen
reader. Each library ships a default function, so `beloch render --as=yr` works
without any code of the author's. An author who wants a different layout
writes a function of their own against the same primitives.

**This record supersedes [[ADR-0002]]**, which moves to `archive/`. Its FOLD
decision holds and is restated above; its instruction JSON is dropped in
favor of the libraries; its editor boundary, LSP, stands in [[ADR-0007]] as
`beloch lsp`.

## Alternatives considered

- **The instruction JSON of [[ADR-0002]].** A second contract to specify and
  version, whose content the FOLD now carries, and which every medium would
  still have to lay out itself. Rejected for the reasons in the context.
- **Layout as configuration data instead of code.** Deciding which folds
  share a panel and where a row of panels breaks is a computation. [[ADR-0009]] puts
  computation in a host language and keeps `.bel` total, and the
  TypeScript edge is that host.

## Consequences

- The front end, the emitter, [[reference/beloch]] (syntax) and [[reference/fold]]
  (the annotation field) change together; the geometric evaluation does not
  change.
- The invariance test becomes part of `check`. A kernel change that lets an
  annotation reach the geometry fails it.
- An output that the default function does not serve costs its author code.
  No layout can be adjusted without programming.
- The libraries evaluate nothing. They take an evaluated FOLD, so they run in
  the browser and in the CLI alike, and `beloch render`
  reads a FOLD file as [[ADR-0007]] describes.
- [[ADR-0001]] still says the process boundary crosses via "FOLD-extended /
  custom JSON". The custom JSON is gone with this record; the boundary is the
  FOLD.

### Open

- **How the CLI finds an author's own function** in place of a library's
  default. This belongs to the CLI once the first library exists.
