---
id: "0029"
title: "Annotations pass through to the FOLD, and each output kind is a TypeScript library over it"
date: 2026-09-25
status: accepted
---

# 0029: Annotations pass through to the FOLD, and each output kind is a TypeScript library over it

## Context

One program should serve many readers. The YR-style folding diagram is the
criterion of success the examples set (`examples/syntax/README.md`), and the
same program should also become a text instruction a screen reader can
speak.

These outputs need information the geometry does not contain. Which folds a
diagram shows as one step, the sentence that tells the folder what to do, a
name a later page can point back to, and hints that only one medium
understands, such as where a YR diagram turns the model over. The author
knows these things, and today the program has no place to say them.

ADR 0002 planned a small, versioned JSON schema for step-by-step diagrams,
beside the FOLD. Since then the FOLD has grown what that schema would have
carried. It holds one frame per state (`spec/FOLD.md`), and ADR 0026 put every
statement into `beloch:statements` with its kind, its source span and the
frame it stands on. A consumer can walk the program and the states without
parsing the source.

The media differ more than one schema can absorb. A printed YR page holds a
grid of panels with arrows and fold lines. A screen reader gets sentences and
no picture. A shared instruction schema would either take the smallest common
part of these or grow a branch per medium, and in both cases the real layout
work would still happen in each consumer.

The fused `step` construct (`notes/antipatterns.md`) shows the risk on the
language side: display grouping and scoping were one construct and came apart
under pressure. Whatever marks a step for a diagram must group and do nothing
else.

## Decision

**Annotations are written in the `.bel` source.** An annotation attaches to a
statement or to a contiguous range of statements. Its syntax belongs to
`spec/BELOCH.md`; `#[ … ]` is the flap selector and is not available.

**An annotation never changes the geometry.** The front end separates
annotations from the program, and the geometric evaluation (ADR 0007, phase 2)
runs on the program without them. The emitter writes them into the FOLD
unchanged. A program with its annotations removed evaluates to the same FOLD
minus the annotation field. A test holds the kernel to this: it replaces every
annotation in a program with spaces, which keeps every source span and line,
and compares the two FOLD documents with the annotation field removed.

**Two kinds of annotation.**

- **Neutral annotations** have a fixed vocabulary that the kernel checks. An
  unknown key without a namespace is an error, and so is a reference to a
  label the program does not define. The first vocabulary has three entries:
  a *label* on a statement or a range, so that other annotations and the
  output libraries can refer to it; a *step group*, saying that the statements
  in a range are one step for the reader; and a *sentence*, the instruction
  text for a statement or a step.
- **Viewer annotations** carry a namespace by convention, such as `yr.*` for
  the diagram library. The kernel checks their shape
  (namespace, key, a literal value, a target that resolves) and does not know
  their keys. The library that owns the namespace reads them and decides what
  an unknown key means for it.

A step group groups and scopes nothing. Names bound inside it stay visible
after it, and a `def` body is still the only scope.

**The FOLD is the only data layer.** FOLD stays the output format, with
Beloch's fields under the `beloch:` prefix. There are no page files beside the
program and no second file format. The frames, `beloch:statements` and the
annotations together are everything an output reads. The annotations live in
one top-level field, one entry per annotation, each naming its target as a
range of indices into `beloch:statements`. A range fits the step group, which
spans statements and frames, and a single statement is a range of length one.
The field-level contract goes into `spec/FOLD.md`.

**Each output kind is a TypeScript library at the edge (ADR 0001).** A library
offers two sets of primitives:

- primitives that *select*: statements, labels, annotations and frames, read
  from the evaluated FOLD. They can build on the runtime core of ADR 0024,
  which already holds the document and the step over the writes;
- primitives that *draw* for its medium: for YR a panel, an arrow, a fold line
  in YR notation and the layer that moves.

An output is a function that receives the evaluated program, calls these
primitives and writes the result: a PDF, a set of SVG files, a text for a screen
reader. Each library ships a default function, so `beloch render --as=yr` works
without any code of the author's. An author who wants a different layout
writes a function of their own against the same primitives.

**This record supersedes ADR 0002**, which moves to `archive/`. Its FOLD
decision holds and is restated above; its instruction JSON is dropped in
favour of the libraries; its editor boundary, LSP, stands in ADR 0007 as
`beloch lsp`.

## Alternatives considered

- **The instruction JSON of ADR 0002.** A second contract to specify and
  version, whose content the FOLD now carries, and which every medium would
  still have to lay out itself. Rejected for the reasons in the context.
- **Page files or a sidecar format beside the program.** They drift: a
  renamed point or a moved fold leaves a sidecar pointing at a statement that
  no longer exists, and nothing evaluates both files together to notice.
  With the annotations in the source, the kernel checks them on every run.
- **Annotations as structured comments.** A comment is invisible to the
  parser, so a label could not be checked, a reference could not be resolved,
  and the annotation would have no span to report an error at.
- **Annotations that may influence evaluation**, for example choosing among
  construction candidates. Choosing belongs to the items of a statement. With
  the rule above, an edit that touches only annotations cannot change the
  fold, and a diff shows which kind of edit it is.
- **One open vocabulary without namespaces.** The kernel could check nothing,
  and two viewers could read the same key differently.
- **A `step` statement in the language.** It is the construct the antipattern
  split apart. As an annotation, the step group cannot acquire a scope.
- **Layout as configuration data instead of code.** Deciding which folds
  share a panel and where a row of panels breaks is a computation. ADR 0009 puts
  computation in a host language and keeps `.bel` declarative, and the
  TypeScript edge is that host.

## Consequences

- The front end, the emitter, `spec/BELOCH.md` (syntax) and `spec/FOLD.md`
  (the annotation field) change together; the geometric evaluation does not
  change.
- The invariance test becomes part of `check`. A kernel change that lets an
  annotation reach the geometry fails it.
- `spec/BELOCH.md` already calls the intent item `(mountain)`, `(valley)` an
  annotation. Intent reaches the FOLD as `edges_assignment` and constrains a
  `flatten`, so it is part of the geometry and stays an item of its statement.
  The word in that table changes, so that "annotation" means one thing.
- A typo in a viewer annotation passes the kernel. The owning library is the
  only place that can catch it, and each library should report the keys it
  does not know.
- An output that the default function does not serve costs its author code.
  There is no layout that can be adjusted without programming.
- The libraries evaluate nothing. They take an evaluated FOLD, so they run in
  the browser and in the CLI alike, and `beloch render`
  reads a FOLD file as ADR 0007 describes.
- ADR 0001 still says the process boundary crosses via "FOLD-extended /
  custom JSON". The custom JSON is gone with this record; the boundary is the
  FOLD.

### Open

- **Focus**, a neutral annotation that says which part of the model a step is
  about. It needs a value that names a point, a line or a flap, which means
  the annotation would resolve names against the program without writing.
  It is the next entry for the vocabulary once the first three are in use.
- **Values.** The first vocabulary needs text, numbers and label references.
  Beloch has no text literal yet, and `spec/BELOCH.md` adds one with the
  syntax.
- **How the CLI finds an author's own function** in place of a library's
  default. This belongs to the CLI once the first library exists.
