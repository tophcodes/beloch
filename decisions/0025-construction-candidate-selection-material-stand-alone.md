---
id: "0025"
title: "Construction, candidate, selection and material stand on their own"
date: 2026-09-23
status: accepted
---

# 0025 — Construction, candidate, selection and material stand on their own

## Context

`spec/MODEL.md` defines four things inside the body of one definition. Read
`def-motion`: an *alignment* is an incidence on the table between two objects,
one of them reflected across the line sought; a *construction* is a finite set
of alignments that determines the line, with finitely many solutions and no
alignment redundant; its value in a state is the finite set of *candidate*
table lines; a *selection* narrows the candidates to one. The definition then
composes all four and names the composition a *motion*: the read that yields
the material of the chosen line.

The glossary carries one entry for the five, `term-motion`. A reader who wants
to know what an alignment is reads a definition about something else.

Three forces made this worth settling.

**Multifold.** The same alignments distributed over two fold lines give the
489 two-fold axioms [@alperin2006, §3, §4], and `packages/multifold` (ADR 0020)
enumerates them. A solution of a two-fold set is a pair of lines. A composition
named for the material of *the* line hides the place where one line becomes a
tuple, which is the place the work will happen.

**The word is spent.** `motion` names a read that moves nothing. The writes
that do move paper (`fold`, `flip`, `reverse`, `flatten`) have no name as a
group, and the group is what a reader of a program counts: those writes change
the state, and `mark` leaves it unchanged up to refinement (`term-score`).

**The glossary says what a term is called and not what kind of thing it is.**
Nothing in an entry separates a condition from a function. `alignment` is a
relation and `selection` is a read, and the two read alike on the page.

## Decision

**The four stand as definitions of their own**, each with a glossary entry:
alignment, construction, candidate, selection. `material` stays as it is, the
one crossing from table space to paper space, carrying one piece per flap.

**The composition keeps a name, and the name is `construction`.** ADR 0022
already puts the word on the read rather than on the set of alignments alone,
and the grammar wants the same word. So the read of sort bundle stays, and
alignment, candidate and selection are lifted out of its body into definitions
of their own.

ADR 0022 phrases it as "the read that yields a fold line", which this record
sharpens: a construction yields *candidates*, finitely many and usually more
than one, and a line is reached only through a selection. The phrase also
presumes a single sought line, which holds for the seven Huzita-Justin axioms
and stops holding one step further out, where the same alignments over two
sought lines give the 489 two-fold axioms. `def-construction` therefore states
its alignments on one sought line and says so, and what widens under multifold
is recorded beside it as an open question rather than promised in the
definition.

**The writes that leave the refinement class are `effective`.** A write is
effective in a state when its value is a different state in the sense of
`def-refinement`; a score is exactly a write that is not. The property is
stated on a state rather than on the quotient, because the quotient reading
needs a statement the model does not prove: that a write applied to two
refinements of one state yields two states with a common refinement. That
statement is recorded as an open question beside the definition.

`motion` keeps its meaning and is not reused. The word is already load-bearing
twice in `spec/MODEL.md`, both times for movement the model does not model:
"the model checks the end state and never the motion", and "immaterial for the
state up to a motion of the table". A third meaning would have made the first
of those read as if the model skipped checking its own writes.

**The grammar follows the model.** The nonterminal `<motion>` becomes
`<construction>`, which is what is written there, and the core's `MMotion`
constructor is renamed with it.

**Every term the text italicises as a definition carries a glossary entry**,
and each entry carries what kind of object it is, as an RDF class rather than
a string: `structure`, `value`, `read`, `write`, `relation`, each a subclass of
`bm:Term`. Where a signature exists the entry states it, with partiality
marked, so `material` reads as total from a state and a table line to a bundle
and `line` as partial from a state and a bundle to a table line.

## Alternatives considered

- **`axis` or `chord` for the read.** Both are already in use informally, and
  both presuppose a single line. Under multifold the entry would describe a
  tuple while its name says otherwise.
- **Reusing `motion` for the writes.** Rejected on the evidence above: the
  word carries the continuous folding motion and the rigid motion of the table,
  and both readings are correct where they stand.
- **Naming the write group by listing it**, as fold, flip, reverse and
  flatten. The list goes stale the first time a write is added; the property
  does not.
- **Rationalising `material` away.** It is the only place where the table and
  the paper meet, and it carries the decomposition into one piece per flap. A
  bundle is already a subset of the sheet, so a material of a bundle would be
  the identity: nothing is missing there, under multifold either.
- **The kind as a property, `bm:kind "read"`.** A string comparison where a
  type query is available, and no room for a subclass to say more later.

## Consequences

- The model, the language reference and the core rename together.
  `spec/SPECIFICATION.md` carries `<motion>` as a syntax category in about ten
  places, so the rename is a documentation change before it is a code change.
- A glossary entry can now disagree with the definition that owns it: a
  signature naming a sort the model does not define, or a kind that contradicts
  the body. The record gains its `checks` when the entries carry their kind.
- The model gains an open question, `open-writes-on-the-quotient`. Nothing in
  the text rests on it, and `effective` is usable without it.
- Multifold extends construction and candidate and leaves alignment, selection
  and material untouched. Splitting them is what buys that.
- The generated glossary grows. Where it lives is a separate question, filed
  as an issue rather than decided here.
