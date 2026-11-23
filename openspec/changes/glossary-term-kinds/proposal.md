## Why

The glossary says what a term is called and not what kind of thing it is.
`alignment` is a relation and `selection` is a read, and their entries read
alike, so a reader has to open the definition to learn which is which. The
four terms of selection have an entry each, but `candidate` is still defined
inside the definition of `construction`, so its entry sends the reader to the
definition of another term.

## What Changes

- Every glossary entry carries the kind of its term as an RDF class, one of
  `structure`, `value`, `read`, `write` and `relation`, each a subclass of
  `bm:Term`, and states the term's signature where it has one, with
  partiality marked.
- Alignment, construction, candidate and selection each stand as a
  definition of its own in `MODEL.md`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `architecture`: a glossary entry states the kind of its term, and the four
  terms of selection stand as definitions of their own.

## Impact

`docs/reference/MODEL.md`, whose `.term` blocks gain their kind and
signature and whose construction definition splits in two; the remark plugin
in `packages/www` that turns the blocks into the glossary and its RDFa.
