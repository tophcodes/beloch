---
id: BEP-0055
title: "A flatten folds several fans at once"
date: 2026-11-17
status: accepted
issue: tophcodes/beloch#16
---

# BEP-0055: A flatten folds several fans at once

## Context

A fan is several creases through one point of the folded state, folded in
one motion ([[BEP-0037]]). `flatten` folds one fan: its items name the
rays, and the rays meet at the vertex.

Some folds turn about several points in one motion. Lang describes the petal
fold as two squash folds made side by side, and the open sink as a fold
whose line "runs all the way around the point being sunk"
[lang2011secrets, ch. 2]. On the preliminary base the petal fold has two
vertices, one on each folded side edge of the front flap. At each of them
the half of the side edge toward the side corner opens, the crease that
brings the side corner onto the center line folds, and a crease to the other
vertex folds. That last crease ends in a vertex at both ends.

A `flatten` at one of the two vertices fails with `crease ends inside the
sheet`, since the crease between the vertices does not reach the raw edge.
Step 17 of the jumping frog has the same shape (tophcodes/beloch#231).

The same state is reachable today by two reverse folds and a valley fold.
That program states three steps where a folder makes one, and it has no
counterpart for the sink, whose vertices lie on a ring.

Two more things stand in the way of writing such a fold as one statement. A
ray of `flatten` is a line that already has a name, so the program marks
every crease of the fold and constructs every vertex before the statement
that folds them. And a line scored through several layers has one piece per
layer, which reads as if the program had to pick the pieces one by one.

## Decision

**`flatten` takes fans as items, and folds all of them in one motion.** A
fan item starts with the word `fan` and holds the rays of one vertex:

```beloch
flatten (fan (--h & .sr) (map .sr onto --mid through .a) as .r)
        (fan (--v & .sl) (map .sl onto --mid through .a) as .l)
        (on #[.a]) (staying .o) as --pf
```

The items `on`, `staying`, `toward` and `over` stand beside the fans and
apply to the whole statement. A `flatten` whose items are rays, without a
fan item, is one fan, as before.

**A fan names its vertex or binds it.** `(fan at .p ray+)` names a point the
program has bound; the statement fails when the rays do not meet at its
table position. `(fan ray+ as .p)` binds the point where the rays meet to a
new name, the way `as` after a write binds the crease the write gives. `as`
is optional. A fan never binds a name it reads.

**A ray is a line operand or a construction.** The statement scores the line
of a construction before it folds, as `fold` scores its axis. A program that
has the crease already names it.

**A ray reaches every layer of the tip under it.** The pieces of one crease
that lie on one table ray are one ray of the fan. `&` narrows a line to one
of its two halves at the vertex, or to one piece where the layers need
different letters. This states what the kernel does for one fan.

**A crease between two vertices is a ray of both fans.** A program that
names it writes it in both fans, and the statement fails when one fan
names it and the other does not. Where neither of two fans names it, the
statement scores the segment between their vertices as one crease on both,
and the output clause binds it; the statement then keeps the states whose
motions close. A fan does not derive its missing ray from its own rays, as
one fan with an odd number of rays does: at a vertex on a folded edge the
rays close around the paper point of the vertex, where the layers on both
sides of the edge meet, and the table shows them folded onto one side. In
the petal fold each fan gives two rays and the crease between the vertices
is the third.

**The statement names the region that stays.** `staying` is required: the
order of the rays picks no region when the rays belong to several
vertices. `toward` is not taken, and a statement has at least two fan
items; one vertex is written with ray items.

## Alternatives considered

- **The vertex on each ray**, `(--kr from .r)`, with `(--pf between .r .l)`
  for the crease between two vertices. The items stay flat, and the rays of
  one fan are spread over the statement.
- **One `flatten` per fan inside a block** that folds its statements at
  once. It adds a statement form, and it raises the question which other
  writes the block takes.
- **Rays as pairs of points**, `(.r to .a)`. A program that has named a
  crease then constructs a point on it to say which crease it means.
- **The fan as a sort of its own**, `^[.r --kr --pf]`, bound to a name and
  passed to `flatten`. A reader tells a fan from a construction by its
  bracket. It adds a fifth sort, and a fan bound before a later write names
  rays of a state that has passed. tophcodes/beloch#271 keeps the question
  of how a reader tells the kinds of item apart.
- **A walk through the vertices**, `(.p1 --s12 .p2 --s23 .p3)`. Each crease
  between two vertices is written once, and the rays of one vertex are
  spread over several items.
- **`(at .p …)` that binds `.p` when the name is new.** A misspelled name
  then makes a point where the program meant to check one.
- **A verb `petal`.** A fixed command per maneuver is how Eos writes its
  folds [ida2009eos, §4]; the petal fold as a definition over fans
  keeps it a program.

## Consequences

- `flatten_item` in [[reference/beloch-grammar]] gains the fan item, and a
  ray inside a fan may be a construction. `def-flatten` in
  [[reference/model]] takes a finite set of vertices; its sectors become
  the regions the rays of all fans cut the tip into.
- The kernel sorts the faces of the tip by region where it sorts them by
  wedge today. The motion of a face stays the product of the reflections
  across the changing hinges on a path from a face that stays
  [hull2020, Def. 6.5].
- A fan with more than one ray missing stays out of reach
  (tophcodes/beloch#265), and so does a statement of more than two fans
  that leaves a crease between two vertices unnamed: which pairs of
  vertices share a crease is open until the sink needs it.
- The petal fold and step 17 of the jumping frog are one statement each.
  The bird base by two petal folds must give the state of the bird base by
  reverse folds, which `packages/core/tests/cases/bases` checks.
- Each fan repeats a crease it shares with its neighbor. On a sink with
  many vertices an item that names the ring once may follow.
