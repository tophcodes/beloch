---
id: "0049"
title: "The examples are popular models, each folding a published sequence"
date: 2026-10-02
status: accepted
issue: tophcodes/beloch#183
checks:
  - desc: Every program in examples/ names the sequence it folds in a source annotation whose cite keys are in references.bib (ADR 0051)
    run: 'bash scripts/check-program-credits.sh'
---

# 0049: The examples are popular models, each folding a published sequence

## Context

The programs in `examples/` are what a newcomer reads first, through the
README and the website. Until now they held one model, the flat crane after
[ida2020, Fig. 7.19], and seven bases and techniques. A base shows that one
operation works. It does not show that Beloch writes the models people fold.

Two groups of readers look at these programs. An origami folder wants to see
models they know, folded to the end. A reader of a paper on Beloch wants
programs long enough to measure, set beside the same model written in an
earlier origami language.

Beloch models flat-folded states only ([[decision/0015]]), so a model counts when it
is recognizable at its last flat state. Steps that open, inflate or shape the
paper in 3D stay out of the program.

## Decision

**`examples/` holds complete models.** A base or a single technique is a test
case and lives under `packages/core/tests/cases/`, where its assertions run.

**Each model is a popular traditional model.** The first set covers easy to
intermediate, each model with a technique the others lack: the cicada
(folds on single layers), the penguin (an outside reverse fold), the samurai
helmet (a tucked flap), the jumping frog (pleats), the flapping bird (petal
folds) and the traditional frog (the frog base), beside the crane. A model by
a named designer needs that designer's credit settled before it enters.

**Each program follows a published sequence and cites it.** A comment at the
head names the source by its key in `bibliography/references.bib`, and a
comment at each statement names the step it folds. A freely available diagram
counts as a source. The folding sequence of a traditional model belongs to no
one; a diagram belongs to the person who drew it, so a program states the
sequence in its own words and copies no figure.

**A model the kernel cannot fold yet still gets its program.** The step that
fails becomes a kernel issue. The README and the website show only models
that evaluate.

**The comparison with earlier languages lives on the website.** Where an
earlier language wrote the same model, such as Fisher's Origami Language for
the flapping bird [fisher1994, §4.2] or OIL for the frog base
[smith1975oil, §5.4], the website sets both programs side by side. Each
comparison reports the statement count, the number of points and lines the
program names, and the evaluation time.

## Alternatives considered

**Keep the bases in `examples/` as techniques.** They are short and each
shows one operation clearly. They also crowd out the models in the README,
and their assertions already make them test cases.

**Compose models from bases.** A model would start from an imported base,
as Fisher's `uses "preliminary-base"` does [fisher1994, §4.2]. That is a
language feature with scope questions of its own and needs its own decision;
the examples do not wait for it.

**Choose models from the research literature only.** Every sequence would be
citable to a paper. The papers print full sequences for few models: neither
Ida's cicada [ida2010jsc, Fig. 1] nor Mitani's [mitani2009barcodes, Fig. 6]
comes with its steps. Popular models with free diagrams reach the origami
folder and still yield the comparisons where a paper has one.

**Choose only models the kernel folds today.** The README would show no
failure. The selection would follow the kernel's gaps instead of finding them.

**Compare in the README.** The README is the first page a reader sees, and
side-by-side programs with measurements make it long. The website has room
for them.

## Consequences

- A new model may surface a kernel gap; its issue waits on the kernel issue
  it raises.
- Programs that cite web diagrams depend on pages that can move. The
  bibliography entry records the access date.
- The website needs a comparison page that evaluates programs and measures
  them.
- The landing page keeps its bases until the browser evaluates a model the
  size of the crane.
