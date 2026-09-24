---
id: "0027"
title: "The meet is the intersection of its operands as point sets"
date: 2026-09-24
status: accepted
---

# 0027: The meet is the intersection of its operands as point sets

## Context

The meet, `--x * --y` and its n-ary form `.[--x --y …]`, names the point
where creases cross. Until v0.19 it intersected the operands' table lines and
resolved the table point to the topmost layer covering it. That rule is
recorded as a dead end in `notes/antipatterns.md` (Q2-B) for two reasons.
Paper is opaque, so the topmost layer may carry neither crease, and the rule
named points that no layer of the paper shows. And a point construction came
to depend on the folded state, while a crease is a scar whose crossings in the
paper never move.

v0.19 moved the meet into paper space and kept what that bought: the meet
point lies on the marks of both operands, and it is computed in paper
coordinates, independent of the fold. It reached that by computing through
lines. Each operand had to lie on a single paper line, the two lines were
intersected, and the crossing was checked against the marks. A crease scored
through several layers lies on several paper lines, a scar and its mirror
images, and the meet refused it with the advice to narrow it to one segment.

The single-line requirement is a property of that computation and protects
nothing on its own. On the preliminary base `--h` and `--v` each lie on two
paper lines, and the two creases have exactly one point in common, the centre
of the paper. The program still had to write `--bd * (--h & --bc)` to reach
it, naming a segment the reader does not care about, and the bird base
located its four side corners with `free on … at 1/2` instead of as the
crossings they are.

The model already has the vocabulary for a better rule. A bundle is a finite
union of segments, a set of paper points (`def-bundle`), and the selector
definition speaks of the point where two bundles meet as "their intersection
when it is a single point".

## Decision

**The meet of bundles is their intersection as sets of paper points, and it
is defined exactly when that intersection is one point.** A paper edge counts
as the bundle of its points, the side of the sheet between two corners, and
so does a selection of an edge and a boundary crease that cut no face. How
many paper lines an operand lies on plays no part.

The meet fails in three ways, each with its own message:

- the operands have **no common point**: they are parallel, or the lines they
  lie on cross beyond their marks or off the paper;
- they have **two or more** common points: the message lists them in paper
  coordinates and suggests narrowing an operand with `&`;
- they **share a stretch** of paper: their intersection contains a segment.

With more than two operands, `.[l+]` yields the one paper point common to all
of them and fails in the same three ways.

The protection v0.19 bought survives unchanged. A point in the intersection
of two bundles lies on both creases in the same piece of paper, so some layer
shows the crossing. The intersection is taken in the paper frame and reads
nothing of the folded state; only name resolution, the `&` filter, does.

Every meet the single-line rule accepted keeps its point. Two operands that
each lie on one line, whose lines cross at a point on both marks, have exactly
that point in common. Narrowing with `&` stays valid for the same reason and
becomes optional wherever the unnarrowed operands already share one point.

## Alternatives considered

- **Keep the single-line rule and improve its message.** It refuses programs
  whose meaning is unambiguous and makes the author name a segment that
  carries no information for the reader.
- **Pick one of several crossings automatically**, the nearest to something
  or the one on the topmost layer. Any such choice reads the folded state or
  an order the program never stated, which is the Q2-B defect back again.
  Ambiguity stays an error, and the message offers the points so the author
  can narrow.
- **Intersect the supporting lines of all pieces and keep the crossings on
  the marks.** For operands on one line each this is the old rule. For
  several lines it computes the same set as the point-set intersection by a
  longer route, and it has no natural reading of two operands sharing a
  stretch.

## Consequences

- Programs write `--h * --v` and `--ab * --h` on folded bases where they
  wrote a filter before. The examples locate every point that a crossing
  determines as a meet.
- The meet compares every piece of one operand with every piece of the next,
  quadratic in the number of pieces. Bundles in practice hold a handful.
- Error messages carry paper coordinates, so an ambiguous meet tells
  the author which crossings to choose between.
- A mark at a single point (`open-point-mark`) stays an open question; this
  record does not decide what a meet against it means.
