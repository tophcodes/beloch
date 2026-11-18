---
id: ADR-0064
title: "A defined term stands on its own with a glossary entry of its kind"
date: 2026-11-18
status: accepted
---

# ADR-0064: A defined term stands on its own with a glossary entry of its kind

This record holds the architecture part of [[BEP-0025]], which decided both kinds.

## Context

The glossary carries one entry for the five, `term-motion`. A reader who wants
to know what an alignment is reads a definition about something else.

**The glossary says what a term is called and not what kind of thing it is.**
Nothing in an entry separates a condition from a function. `alignment` is a
relation and `selection` is a read, and the two read alike on the page.

## Decision

**The four stand as definitions of their own**, each with a glossary entry:
alignment, construction, candidate, selection. `material` stays as it is, the
one crossing from table space to paper space, carrying one piece per flap.

**Every term the text italicizes as a definition carries a glossary entry**,
and each entry carries what kind of object it is, as an RDF class rather than
a string: `structure`, `value`, `read`, `write`, `relation`, each a subclass of
`bm:Term`. Where a signature exists the entry states it, with partiality
marked, so `material` reads as total from a state and a table line to a bundle
and `line` as partial from a state and a bundle to a table line.

## Alternatives considered

- **The kind as a property, `bm:kind "read"`.** A string comparison where a
  type query is available, and no room for a subclass to say more later.

## Consequences

- A glossary entry can now disagree with the definition that owns it: a
  signature naming a sort the model does not define, or a kind that contradicts
  the body. The record gains its `checks` when the entries carry their kind.
- Multifold extends construction and candidate and leaves alignment, selection
  and material untouched. Splitting them is what buys that.
- The generated glossary grows. Where it lives is a separate question, filed
  as an issue rather than decided here.
