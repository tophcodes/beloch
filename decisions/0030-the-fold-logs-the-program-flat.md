---
id: "0030"
title: "A program has two axes, and the FOLD logs every executed statement on them"
date: 2026-09-25
status: accepted
---

# 0030: A program has two axes, and the FOLD logs every executed statement on them

Supersedes ADR 0026, which logged the top-level statements only.

## Context

ADR 0026 split a position in a program into two axes. The model counts
states, and a state changes with every write. The language counts statements,
and a binding moves the program without moving paper. In the opening of the
bird base, the first number is the folded state and the second counts the
statements since that state began:

```beloch
fold (map .a onto .c) as --bd             ; 1.0
reverse (map .b onto .c) as --h           ; 2.0
reverse (map .d onto .c) as --v           ; 3.0
.o = --h * --v                            ; 3.1  new point, same paper
--mid = (through .c .o)                   ; 3.2  new line, same paper
.sr = --ab * --h                          ; 3.3  new point, same paper
reverse (map .sr onto --mid through .c)   ; 4.0
```

A stepper walks the first axis and shows a new drawing at every stop. An
editor walks the second and can say at `3.1` that `.o` appears, which the
first axis has no stop for.

`beloch:statements` records both, one entry per top-level statement. An
`apply` is one top-level statement that runs a whole `def` body, so a
program that applies a `def` twice has two entries, and the statements of
the body have none.

Two uses need the body in full. ADR 0029 lets an annotation attach to a
statement, and the statement a diagram needs to talk about is often inside a
`def`: the petal fold is written once and applied four times. A repetition in
a diagram ("repeat steps 5 to 8 on the other side") is the second `apply` of
the same `def`, and a renderer can only draw it if it can see which entries
one `apply` produced.

## Decision

**A position in a program is a pair,** the state it stands in and how far
the program has moved since that state began, written `2.3` for a reader.
The FOLD stores no position. One pass over the entries gives both
coordinates, since each entry carries its kind. A consumer that keeps a
position keeps the pair, because a decimal number cannot tell the tenth
statement after a state, `3.10`, from the first, `3.1`.

**The first axis counts writes.** Every `fold`, `reverse`, `flip`, `flatten`
and `mark`. A score changes the paper as a fold does, and the axis stops at
both. The difference that an effective write moves the state and a score
leaves it standing up to refinement (ADR 0025) stays inside the axis, where a
renderer needs it: a fold crossfades between two placements, a mark draws on
the placement already there.

**The second axis counts executed statements,** all of them, in the order
they run. A statement inside a `def` body counts once for every `apply` that
runs it, and never at the `def`, which runs nothing.

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

The reason for putting the structure into the document is the one ADR 0026
gave: every renderer gets it, and none has to parse the program or re-run a
body to learn what happened.

## Alternatives considered

- **The log as a tree,** an `apply` entry holding its body's entries. Every
  consumer would have to recurse to step through a program, and the frames,
  which are a flat sequence, would have to be joined to a tree. The parent
  index carries the same information in the flat form.
- **An `apply` as a single entry,** as ADR 0026 had it. The body would have
  no entries for an annotation to target, and a repetition would be
  invisible.
- **Entries for the folds inside a body and none for its bindings.** A
  stepper would still stop at every fold, but a point that a body binds would
  have no entry, so an editor could not say where it appears and an
  annotation could not target the line that binds it.
- **Reading the structure from the syntax tree,** rejected in ADR 0026 for
  the same reason it is rejected here: a consumer without a parser would be
  left without it.

## Consequences

- One source span can now occur in several entries, one per `apply` that ran
  its statement. Consumers join on the entry index, which `spec/FOLD.md`
  already asks of `beloch:edges`.
- A renderer finds a repetition by grouping the `apply` entries by the `def`
  they name. The diagram library draws the second one as a repeat of the
  first, and no annotation is needed for it.
- An annotation in a `def` body is emitted once per execution, targeting the
  entries of that execution (ADR 0029).
- `beloch:named_points[].statement` and `beloch:named_lines[].statement` stay
  the entry that binds the name. For a name bound in a body, that is the
  entry of the execution that bound it.
- A FOLD written before this change carries no `apply` entries and no body
  bindings. A reader treats an entry without a parent as top-level, and an
  entry without a kind as a write, as ADR 0026 already required.
- The evaluator, `spec/FOLD.md`, the scene parser and the runtime core change
  together. The stepper walks the writes as before and sees no difference.
