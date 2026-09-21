---
id: "0020"
title: "Multifold research package lives in a separate repository"
status: accepted
---

# 0020 — Multifold research package lives in a separate repository

## Context

The multifold axiom research track needs an enumeration library, a symbolic
solver driver and fixtures. None of it belongs to the language: the evaluator
never calls into it, and the track answers questions about the axiom space
rather than about `.bel` programs.

It first lived here as `packages/multifold/`. Unpublished research is easier to
hold back before it is written up than after, so the package and its notes now
live in a separate, non-public repository instead.

## Decision

The multifold enumeration, its notes and its fixtures live outside this
repository. This repository carries the language, the evaluator and the site.

- The core evaluator never depends on the research package. The dependency edge
  points one way, and only the research side may cross it.
- The research package consumes `beloch` as a library, the same way any other
  consumer would. It gets no privileged access and no carve-outs in the core.
- Nothing in the core changes to accommodate the research track. A change the
  track needs is either useful to the language on its own terms, or it happens
  on the research side.

## Consequences

- `flake.nix` builds the core, the web bundle and the renderer. The research
  package brings its own build.
- `msolve` stays in the development shell, because the research package is
  developed from this checkout.
- Work that starts as a research question and turns out to be a language
  feature moves here deliberately, through an ADR, rather than by growing a
  dependency.
