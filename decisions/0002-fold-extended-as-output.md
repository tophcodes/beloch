---
id: "0002"
title: "FOLD-extended as the geometric output, custom JSON for diagrams"
status: accepted
---

# 0002 — FOLD-extended as the geometric output, custom JSON for diagrams

## Context

Beloch evaluates a `.bel` source into an artifact describing a folded-paper
state. We need an output format. FOLD (the Demaine/Ku/Lang interchange format)
already exists, is JSON-based, well-specified, and has consumers in several
languages. It absorbed the field's "standard representation" energy in the
mid-2010s, which means any new source language's natural IR target is FOLD.

FOLD describes crease patterns and folded states. It does **not** describe
step-by-step folding instruction sequences (the YR-diagram use case), which are
a different kind of artifact.

## Decision

- **Geometric output: FOLD, extended.** Standard FOLD for crease pattern and
  folded state; Beloch-specific information in namespaced extension fields
  (`beloch:*`) so stock FOLD tools ignore them cleanly — exactly what FOLD's
  extension mechanism is for. Extensions carry things like source mapping back
  to the `.bel` file, layer-ordering explanations, and per-crease axiom
  provenance.
- **Instruction output: a small, versioned custom JSON schema** for YR-style
  step-by-step diagrams. This is the one new format we genuinely have to invent;
  keep it as small and as versioned as possible.
- **Editor boundary: LSP** (not a hand-rolled format) — see future ADR when the
  LSP work starts.

## Alternatives considered

- **Invent one Beloch-native format for everything.** Rejected — FOLD exists,
  is good, and reusing it gives us an ecosystem of consumers for free.
- **Use FOLD for the instruction sequence too.** Rejected — FOLD models states
  and patterns, not ordered instructions; forcing it would distort both.

## Consequences

- The evaluator's job ends at emitting FOLD-extended + instruction JSON.
  Renderers (SVG, Three.js, print, YR diagrams) are downstream consumers in any
  language — the research contribution has a clean interface.
- We owe a written, versioned spec for the `beloch:*` extension fields and for
  the instruction schema. These live in `../spec/`.
