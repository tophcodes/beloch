---
id: BEP-0071
title: "One step construct for scope and diagram grouping"
date: 2026-07-02
status: abandoned
---

# BEP-0071: One step construct for scope and diagram grouping

## Proposal

The first approved step/macro spec made one `step` construct carry scoping
*and* diagram grouping, and gave `$name` three meanings at once: display
label (evaluated immediately, scope discarded), stored macro (deferred),
retained namespace (needed by post-hoc `export`). Nine commits on
`worktree-feat+step-macros` implement this design.

## Why abandoned

Per the review in #29: post-hoc `export { --pq } $thirds` either failed or
re-ran the body, physically double-folding the paper; a parameter list
silently switched the evaluation model; the spec's own flagship example was
undefined under its own scope rule; several examples didn't parse.

The revised spec of the same date replaced it with one construct per
meaning, `def` (never runs) / `apply` (only execution form, yields retained
instance) / `export` (reads, never runs) / `step` (panel marker, display
only), and one sigil per meaning: bare identifiers for defs, `$` only for
instances. Don't re-fuse the axes: display grouping and scoping always come
apart under pressure ("group without hiding" and "hide without grouping"
both exist).
