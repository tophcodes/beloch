---
id: BEP-0029
title: "Annotations pass through to the FOLD, and each output kind is a TypeScript library over it"
date: 2026-09-25
status: accepted
---

# BEP-0029: Annotations pass through to the FOLD, and each output kind is a TypeScript library over it

The architecture part of this decision is [[ADR-0065]].

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

The fused `step` construct ([[notes/antipatterns]]) shows the risk on the
language side: display grouping and scoping were one construct and came apart
under pressure. Whatever marks a step for a diagram must group and do nothing
else.

## Decision

**Annotations are written in the `.bel` source.** An annotation attaches to a
statement or to a contiguous range of statements. Its syntax belongs to
[[reference/beloch]]; `#[ … ]` is the flap selector and is not available.

**An annotation never changes the geometry.** The front end separates
annotations from the program, and the geometric evaluation ([[ADR-0007]], phase 2)
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

## Alternatives considered

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

## Consequences

- [[reference/beloch]] already calls the intent item `(mountain)`, `(valley)` an
  annotation. Intent reaches the FOLD as `edges_assignment` and constrains a
  `flatten`, so it is part of the geometry and stays an item of its statement.
  The word in that table changes, so that "annotation" means one thing.
- A typo in a viewer annotation passes the kernel. The owning library is the
  only place that can catch it, and each library should report the keys it
  does not know.

### Open

- **Focus**, a neutral annotation that says which part of the model a step is
  about. It needs a value that names a point, a line or a flap, which means
  the annotation would resolve names against the program without writing.
  It is the next entry for the vocabulary once the first three are in use.
- **Values.** The first vocabulary needs text, numbers and label references.
  Beloch has no text literal yet, and [[reference/beloch]] adds one with the
  syntax.
