---
id: ADR-0074
title: "A consumer reconstructs which creases exist at a statement"
date: 2026-09-22
status: abandoned
---

# ADR-0074: A consumer reconstructs which creases exist at a statement

## Proposal

The Playground has to know which creases exist at statement k. The kernel
never wrote that down, so two consumers set out to reconstruct it.

Instance 1, shipped and broken: `creaseStepOf` in the renderer matched a
crease edge to the same-named entry in `beloch:named_lines` and read its
`step`. That field is a frame counter. In `cube-root.bel` all nine named
lines bind before the single fold, so all nine report step 0; the filter
could not separate them and drew the same crease set at every stop. The
defect survived until someone counted crease lines across the nine stops of
the fish base.

Instance 2, designed and rejected before implementation: join on the source
line, `beloch:edges[i].span` against `beloch:statements[j].source_line`. It
would have worked on every program in this repository. Two statements on one
line is a legal program that evaluates, and then both report the same line,
so the key identifies nothing.

## Why abandoned

Fix: the emitter names the statement itself, as an index into
`beloch:statements` (`beloch:edges[i].statement`; see [[reference/fold]]). The
name lookup was deleted rather than repaired.

Rules of thumb since: a join key has to be unique under the grammar, and the
corpus failing to violate it proves nothing. And when a consumer recomputes
an identity the emitter already holds, the repair belongs in the emitter.
