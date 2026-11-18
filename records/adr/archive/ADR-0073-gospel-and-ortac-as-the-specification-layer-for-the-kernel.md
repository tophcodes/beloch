---
id: ADR-0073
title: "Gospel and Ortac as the specification layer for the kernel"
date: 2026-09-13
status: abandoned
---

# ADR-0073: Gospel and Ortac as the specification layer for the kernel

## Proposal

Gospel writes a formal contract into the `.mli` as `(*@ requires / ensures *)`
annotations; Ortac compiles that contract into runtime assertions and, via the
`qcheck-stm` plugin, into a generated model-based test harness. The attraction
was placement: [[reference/kernel]] already pulls its content out of
`fold_state.mli` through odoc, so the contract would live where the interface
lives.

## Why abandoned

It does not reach the kernel. `Fold_state.make` exists in order to decide the
non-crossing conditions, so its postcondition reads "returns `Ok` exactly when
connectivity, hinge closure, taco-tortilla and taco-taco hold". Ortac
translates only the executable fragment of Gospel and accepts quantifiers in a
few fixed patterns, while taco-taco quantifies over pairs of hinges under a
geometric overlap predicate. The formula is then either untranslatable, or it
calls the function that implements the check and the postcondition becomes a
tautology. `qcheck-stm` also needs a Gospel `model` of the abstract type, an
`init_sut` and a generator per argument type, and random `faces`/`hinges`
arrays are rejected by `make` in nearly every draw, so the generated harness
would exercise the error path only.

Second reason, specific to the reference documents: the annotation in
`fold_state.mli` already carries `@see <…/model/#cond-taco-taco> realizes the
taco-taco condition`, naming the statement in `MODEL.md` that the constructor
answers to. A Gospel formula cannot cite that id, states less than the
statement it would duplicate, and introduces a fourth notation beside the
model's mathematics, the kernel document's prose and the `violation`
constructors.

What remains is a plain testing gap with no Gospel in it: the algebra and the
axioms have postconditions independent of their implementations and cheap to
state, and the repository has no property-based tests at all. Tracked as
[#85](https://github.com/tophcodes/beloch/issues/85).

Rule of thumb: a runtime-assertion tool pays where the checker is independent
of the implementation. Where the function *is* the checker, it can only restate
the code.
