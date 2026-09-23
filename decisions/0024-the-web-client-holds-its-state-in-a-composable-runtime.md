---
id: "0024"
title: "The web client holds its state in a composable runtime"
date: 2026-09-22
status: accepted
checks:
  - desc: Der Core greift nicht auf den DOM zu
    run: '! rg -q "(document|window|navigator)\.|HTMLElement|SVGElement" packages/runtime/core/src'
  - desc: Der Core importiert kein Modul, das auf ihn komponiert
    run: '! rg -q "from \"@beloch/runtime-" packages/runtime/core/src'
---

# 0024 — The web client holds its state in a composable runtime

## Context

Three surfaces show the same thing: the playground, the `<Beloch>` card in the
documents, and a scroll-driven tour of the model. Each wired its own state by
hand, and all three answer the same questions. Which statement is the reader
at. Which crease did they point at, and which statement made it. What should be
drawn now.

The cost showed up three ways. The same answer was written twice and would have
been written a third time. Every interaction path had to redo everything a step
change implies, so a new path started by rediscovering which five things it
owed. And selection, hover and step lived in several places that had to agree
with nothing forcing them to.

A fourth consumer is planned and constrains the shape: a preview inside an
editor extension, which has no DOM, draws through a different surface, and
evaluates by running the native binary rather than a wasm worker.

## Decision

The web client's state lives in a **small core that consumers compose onto**,
with four commitments.

**The core carries a document slot.** It holds one evaluated document, or
nothing, and an event fills the slot. Who raises that event is the
composition's business: an evaluation module after a run, a card from the
document embedded in its markup, a tour from a program evaluated at build time.
A consumer that never evaluates carries no evaluator.

**How a state is drawn is an argument to the drawing request.** Which view,
which occlusion mode, which colours. The core derives a render command as plain
data, and a consumer showing two drawings of one document asks twice. The card
therefore draws the crease pattern and the folded form side by side from a
single state.

**A view is a renderer the consumer plugs in.** The core names no colours, no
geometry and no element. A DOM host takes the renderer this project ships; a
host with another surface writes its own and the core does not learn about it.

**The editor owns the source text.** Everything derived from that text belongs
to the runtime, and the editor reports changes rather than holding what they
mean.

Optional modules compose onto the core for what only some consumers need:
evaluation with a swappable backend, resolving several entities that share a
pixel into one choice, and the map between source positions and entities. The
core imports none of them.

## Alternatives considered

**State in each component, as it was.** Rejected because the three consumers
already disagreed about what a selection is, and a fourth would have to guess
which of the two answers to copy.

**A framework store.** Rejected because the consumers have no framework in
common: one is a hydration island in a static document, one is scroll-driven
markup, one would live in a webview. Each would pay for a runtime dependency
that the amount of state here does not justify.

**Evaluation inside the core.** Rejected because two of the four consumers
evaluate nothing, and the two that do use different means. With evaluation
beside the core, one interface serves a wasm worker in a browser and a
subprocess in an editor extension.

**The coincidence chooser inside the core.** Resolving several entities that
share a pixel into a choice is one consumer's affordance. The core holds the
settled answer, and whoever offered the choice dispatches it.

**The card's name-based selection as the identity.** The card lit entities by
the name the program gave them. ADR-0014 settles that a crease is its bundle of
segments, so the bundle is what a selection names, and a name is resolved
through the document's own inspect data.

## Consequences

- A consumer composes what it needs. The card and the tour take the core and a
  renderer; the playground adds evaluation, the chooser and the editor map.
- An event that changes nothing returns the state it was given, so a renderer
  answers "did anything move" by identity. A pointer resting on one crease
  sends an event per mouse move, and redrawing on each would restart a running
  animation.
- The viewport stays with the view. Pan, zoom and animation progress are the
  renderer's, because two consumers may show one document at different zoom and
  mid-animation, and both are right.
- A headless test asserts what a view would draw without a view existing, and
  the state logic is tested there.
- The word "runtime" named two things, this core and the wasm evaluation
  runtime the first run downloads. The second gives up the word and is the
  evaluator in code. What the reader is told while it loads keeps saying
  runtime.
- The price is paid by the simplest consumer: a surface that only ever draws
  one document now carries a state machine it could have inlined.
