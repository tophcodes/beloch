---
id: "0026"
title: "A program has two axes, and the FOLD carries both"
date: 2026-09-23
status: accepted
---

# 0026 — A program has two axes, and the FOLD carries both

## Context

The timeline has one counter today. `beloch:statements` holds one entry per
state-changing statement in source order, which means a `fold` or a `mark`
(`spec/FOLD.md`). A construction statement such as `.m = --v * --ab` changes no
state and is not logged; a named point records the index of the next
state-changing statement, "the first stop at which the point can matter".

A reader of the playground meets the consequence. The source a step stands for
is its own line and everything under it until the next statement, so a step is
a block of several lines, and a declaration is never shown on its own. Several
things are visible at once and nothing says which of them the drawing just
gained.

Two different things are being counted, and one counter cannot hold both.

**The model counts states.** A flat folded state is read up to refinement
equivalence (`def-refinement`). A write that leaves that class gives a new
state; `mark` scores and stays inside it; a read changes nothing. The model has
no notion of a program, a name or an order of statements.

**The language counts statements.** `.o = free on --bd from .b at 1/2` binds a
read, `--mid = (through .c .o)` binds another, `mark` writes without moving
paper. All three advance the program. None of them moves the model's counter.

The naming environment appears nowhere in `spec/MODEL.md`, so the second axis
belongs to a layer the model does not have rather than being a distinction the
interface invented.

## Decision

**A position in a program is a pair.** The state it stands in, and how far the
program has moved since that state began. Written `2.3`: the third statement
standing on the second folded state.

**The first axis counts writes.** Every `fold`, `reverse`, `flip`, `flatten`
and `mark`. The axis asks whether the paper changed, and a score changes it:
the sheet carries a scar it did not carry before, which the drawing shows and
a reader steps to. That an effective write moves the state and a score leaves
it standing up to refinement (ADR 0025) still separates the two inside the
axis, and a renderer needs that separation: a fold crossfades between two
placements, a mark draws on the placement that is already there.

**The second axis counts statements**, all of them, including the writes the
first axis already counted. It answers where in the program a position stands,
which the first axis cannot: a binding moves it and moves no paper. The model
knows a bound read as no event at all, so this axis belongs to the language
alone.

**The FOLD carries both.** `beloch:statements` logs every top-level statement
in source order, each carrying the kind that says which axis it moves, its
source span and the frame it stands on. A named line carries `statement`, as a
named point already does.

The reason for putting it in the document rather than deriving it in the
client: every renderer gets the structure. The card in the documents, a
scroll-driven tour, an editor extension, a printed diagram. A consumer that
draws should not have to parse the program, which is the same reason ADR 0024
gives the runtime core a document slot rather than an evaluator.

## Alternatives considered

- **Reading the structure from the client's syntax tree.** The web client
  already loads the tree-sitter grammar to colour the editor, so the statement
  boundaries are there for free, and they are there while the program is being
  typed and even when it does not run. It was rejected because it makes the
  structure a property of one code editor. A consumer with no parser, which is
  every other renderer, would be left without it.
- **A single finer counter, one stop per statement.** It would make stepping
  walk through positions where the paper does not move, and the drawing would
  answer a step with the same picture. The two axes keep stepping on the
  states and let the source column show the rest.
- **Logging declarations only where they bind something drawable.** A point and
  a construction line are drawn, a `def` body is not. Splitting on that would
  put a rendering question into the document contract.

## Consequences

- The emitter, `spec/FOLD.md`, the scene parser and the runtime core change
  together. The kind on a statement is the new field a consumer must read to
  tell the axes apart.
- A FOLD written before this change carries fewer entries. The parser keeps
  reading it: a statement without a kind is a state-changing one, which is what
  the old list held.
- The stepper keeps walking the writes, which is where it stops today. What
  the second axis buys is the editor's debug mode: it can say what each
  statement binds and offer it as a target, which needs the map from
  statements to values that this record puts in the document.
- `beloch:named_points[].statement` changes meaning: it becomes the statement
  that binds the point rather than the next state-changing one. The old reading
  was a workaround for the missing entries.
