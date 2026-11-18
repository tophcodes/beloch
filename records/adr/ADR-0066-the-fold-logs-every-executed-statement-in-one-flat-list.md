---
id: ADR-0066
title: "The FOLD logs every executed statement in one flat list"
date: 2026-11-18
status: accepted
---

# ADR-0066: The FOLD logs every executed statement in one flat list

This record holds the architecture part of [[BEP-0030]], which decided both kinds.

## Context

`beloch:statements` records both, one entry per top-level statement. An
`apply` is one top-level statement that runs a whole `def` body, so a
program that applies a `def` twice has two entries, and the statements of
the body have none.

Two uses need the body in full. [[BEP-0029]] lets an annotation attach to a
statement, and the statement a diagram needs to talk about is often inside a
`def`: the petal fold is written once and applied four times. A repetition in
a diagram ("repeat steps 5 to 8 on the other side") is the second `apply` of
the same `def`, and a renderer can only draw it if it can see which entries
one `apply` produced.

## Decision

**`beloch:statements` is flat.** One entry per executed statement, in
execution order, whatever the nesting in the source. Each entry carries

- its kind: a write, a binding, or an `apply`;
- the source span where the statement is written, which for a body
  statement lies inside the `def`;
- the frame it stands on;
- the `apply` it runs under, as the index of that `apply`'s entry, or
  nothing at the top level.

An `apply` has an entry of its own, before the entries of its body, and it
names the `def` it runs. Nested applications chain through the parent index,
so the tree of calls is there for a consumer that wants it, and a consumer
that walks the program linearly never has to recurse.

```beloch
def petal(.p) {
  .t = …                  ; entries 1 and 4
  fold …                  ; entries 2 and 5
}
apply petal(.a)           ; entry 0
apply petal(.c)           ; entry 3
```

Entries 1 and 2 name entry 0 as their parent, entries 4 and 5 name entry 3.
Entries 0 and 3 both name `petal`, which is how a renderer sees that the
second application repeats the first.

The reason for putting the structure into the document is the one [[BEP-0026]]
gave: every renderer gets it, and none has to parse the program or re-run a
body to learn what happened.

## Alternatives considered

- **The log as a tree,** an `apply` entry holding its body's entries. Every
  consumer would have to recurse to step through a program, and the frames,
  which are a flat sequence, would have to be joined to a tree. The parent
  index carries the same information in the flat form.
- **An `apply` as a single entry,** as [[BEP-0026]] had it. The body would have
  no entries for an annotation to target, and a repetition would be
  invisible.
- **Entries for the folds inside a body and none for its bindings.** A
  stepper would still stop at every fold, but a point that a body binds would
  have no entry, so an editor could not say where it appears and an
  annotation could not target the line that binds it.
- **Reading the structure from the syntax tree,** rejected in [[BEP-0026]] for
  the same reason it is rejected here: a consumer without a parser would be
  left without it.

## Consequences

- One source span can now occur in several entries, one per `apply` that ran
  its statement. Consumers join on the entry index, which [[reference/fold]]
  already asks of `beloch:edges`.
- A renderer finds a repetition by grouping the `apply` entries by the `def`
  they name. The diagram library draws the second one as a repeat of the
  first, and no annotation is needed for it.
- An annotation in a `def` body is emitted once per execution, targeting the
  entries of that execution ([[BEP-0029]]).
- `beloch:named_points[].statement` and `beloch:named_lines[].statement` stay
  the entry that binds the name. For a name bound in a body, that is the
  entry of the execution that bound it.
- A FOLD written before this change carries no `apply` entries and no body
  bindings. A reader treats an entry without a parent as top-level, and an
  entry without a kind as a write, as [[BEP-0026]] already required.
- The evaluator, [[reference/fold]], the scene parser and the runtime core change
  together. The stepper walks the writes as before and sees no difference.
