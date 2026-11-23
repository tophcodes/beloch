## Context

Every term a definition of `MODEL.md` introduces has a `.term` block, which
the site turns into a glossary entry with the RDFa type `bm:Term` and a link
to the definition that owns it. Alignment and selection have definitions of
their own; construction and candidate share one.

The rules come from ADR-0064. Its reason: one glossary entry for several
terms made a reader look up one term in the definition of another, and a
definition per term lets an extension change construction and candidate
while alignment, selection and material stay put. Nothing in
an entry separates a condition from a function, so the entry states the
kind.

## Goals / Non-Goals

**Goals:** the kind and the signature on every entry, and a definition of
its own for candidate.

**Non-Goals:** where the generated glossary lives on the site, a separate
question for an issue.

## Decisions

- **The kind is an RDF class, a subclass of `bm:Term`.** A type query finds
  every read, and a subclass can say more later.
  - Rejected: the kind as a property, `bm:kind "read"`; a string comparison
    where a type query is available, and no room for a subclass.
- **`material` stays one definition.** It is the one crossing from table
  space to paper space and carries one piece per flap.

## Risks / Trade-offs

- [An entry can disagree with the definition that owns it, by a signature
  that names a sort the model does not define or a kind that contradicts the
  body] → a check of the entries, still to be chosen; see the open question.

## Open Questions

- Which check holds an entry to the definition that owns it. Its answer adds
  a task and changes no requirement.
