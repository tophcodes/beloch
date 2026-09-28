---
id: "0031"
title: "toward names the side that stays; heading names the direction of the crease"
date: 2026-09-27
status: accepted
---

# 0031: toward names the side that stays; heading names the direction of the crease

## Context

A construction yields candidates, finitely many and usually more than one,
and a selection keeps one (ADR 0025). `toward` is the selection the language
offers, and it has to mean one thing for every construction that can leave
more than one candidate: a point moved onto a line, two points moved onto
two lines, and a line moved onto a line. Issue #58 drew the candidate rules
on the same programs: the landing of the moved point, the line nearest the
point, the side of the moved line. They pick different candidates for the
same `toward` point, and each needs a special case for one of the three
kinds.

Two observations settled the direction. A line has no target point, so a
rule phrased as "where the moved thing lands" needs a separate reading when a
line moves. And a `toward` point on paper that moves names nothing a folder
would mean: pointing at a flap says where the flap starts, and a folder
points at where it goes.

## Decision

**An alignment is an incidence.** `x onto y` states that after the fold the
image of `x` lies on `y`, which is the same as the image of `y` passing
through `x`. It names no object as the one that moves; the program says
which side moves with `toward` and `moving`.

**`toward` names the side that stays.** For each candidate, the side of its
line that holds the `toward` point stays and the other side folds over.
`toward` takes a point or a line. A line names the side it lies on; a line
that the candidate crosses on the paper names no side for that candidate,
and a point on the candidate names none either. A candidate for which
`toward` names no side does not remain. **`moving` names the side that folds
over**: the side of its anchor point, or of the first point of a `#[…]`
selector off the line, or of the material of a line.

**A fold keeps only the candidates it can perform.** A candidate remains
when the fold along it, with the side that folds over, carries out every
alignment: in each, one of the two objects lies on the side that folds over
and lands on the paper of the other, or a point lies on the candidate and on
its target line already. A point that folds onto a line lands on the part of
the line that lies on the paper, and a line that carries a point needs paper
of that line at the one place that lands on it. A landing on a line's
extension beyond the edge cannot be made by eye, so a program that wants one
constructs the target line first. The part of a line on the other side stays
where it is. With neither `toward` nor `moving`, a candidate remains when either side
carries the construction out; the side that alone does so folds over, and
where both do, the side of the first object of the first alignment folds
over. That default belongs to the write and gives the alignment no
direction.

**Among several remaining candidates, `toward` keeps the one that lands the
objects of its alignments nearest the `toward` point or line**, measured as
the distance between the two sets. `(toward .u)` measures the landing of
every object: the points that fold over and the parts of the lines that
fold over, where they land. The rest of the flap goes unmeasured.
`(x toward .u)` measures only the part of `x`, one of the objects, and
keeps only the candidates that fold `x` over. Equal distances leave the construction ambiguous, and the hint names
the second form. `moving` names no target and has no such stage: several
candidates remaining after `moving` leave the fold ambiguous.

**An ambiguous selection suggests what to write.** For each remaining
candidate the kernel runs the selection again with one added item, and the
trace carries the first item after which exactly that candidate remains.
Without `toward` the items are `(toward x)` over the named points in scope,
then the named lines, in program order; after a tie of a bare `toward` they
are `(x toward …)` over the objects of the alignments as the program writes
them. A suggestion is checked for its own statement only.

**`heading` names the direction of the crease.** `heading --l` keeps the
candidate whose line makes the smallest angle with `--l`. The position of
`--l` plays no part. Equal angles pass the tied candidates on to `toward`;
without `toward` they leave the construction ambiguous.

**`toward` and `moving` agree or the fold fails.** Both name a side; a
candidate for which they name the same side as staying and moving does not
remain, and where that removes every candidate the fold is an error. When
they agree, `moving` still names the flap that moves, and it is redundant
only where it names the flap the fold would take without it.

**`toward` names the side on every write.** On a fold along an existing
crease, on `reverse` and on a placed fold, `toward` without `moving` names
the side that stays. Where the write has no anchor, the material on the
other side is the flap, the tip or the block that moves.

**Each word sits at the level it speaks about.** Alignments and `heading`
determine the line and stay inside the construction. `toward`, `moving` and
the placement determine the fold and are items of the write, as `toward`
already is in `flatten`. The canonical form parenthesises each part of a
construction:

```beloch
(align (.p onto --l) (through .q) (heading --m))
fold (align (.d onto --ef) (through .p)) (toward .c) (moving .d)
fold (map .d onto --ef through .p) (.d toward .c)
```

A binding takes items as a write does. `toward` there names the side that
would stay and `moving` the side that would fold over, so both select as
they do in a fold: `--k = (map --v onto --h) (--v toward .b)`. `mark` takes
them the same way. Where no paper moves, `moving` names a side and no flap.
A construction inside an expression takes no selection; it is bound first.

**This record supersedes ADR 0022** and carries forward what it decided
apart from the selection. A construction is its set of alignments, together
with its named fold lines and its `heading`. The prose forms of the seven
axioms desugar to that set, and a prose form means what its `align` spelling
means. An axiom number names one alignment set, recognised by the kinds of
its alignments, and appears in error messages, provenance and documentation;
it is no type of its own. A set that is none of the seven is an error naming
its alignments. `(--l onto .p)` means `(.p onto --l)`. `toward`
leaves the construction.

## Alternatives considered

- **The first object of `onto` as the one that moves.** It reads intent
  into the word order and drops folds that carry out the incidence by moving
  the target: axiom 7 with its two points on opposite sides of the only
  candidate, where the fold lands one point on its line and the other line
  on its point. The word order keeps one role, the default side of a fold
  that names none.
- **`(toward .u)` measuring the first object only.** It ties the item at the
  end of a statement to the first object inside it and reads oddly;
  `(x toward .u)` names the object where the program needs one.
- **The line nearest the point**, as `def-selection` stated it. It answers
  where the crease lies, where every other use of `toward` asks where the
  paper goes, and it disagrees with the landing rule on the first programs
  #58 drew. Its question is served by `heading`, which asks it without a
  position.
- **The side of the moved line when a line moves, the landing point when
  points move.** Two rules for one word, and a separate case for a line that
  crosses the other one on the paper.
- **Distance of the landed material alone, for every axiom.** It needs no
  side, and it lets `toward` point at paper that moves.
- **`toward --l` selecting by angle.** The same word would say where the
  paper goes when given a point and how the crease runs when given a line.
- **A measure combining angle and position.** It needs a scale that trades
  degrees for lengths, and a reader of a program cannot predict it.
- **A `select` or `choose` item grouping the selections**, or a sigil per
  role. With `heading` in the construction and `toward` in the write, the
  nesting already separates the roles. Beloch's sigils name sorts of values,
  and alignments and selections are parts of statements.
- **The landing of the whole flap**, all paper that folds over. The flap
  lands on the side that stays, where the `toward` point lies, so two
  candidates whose flaps both cover the point tie at distance zero: with `.p`
  a quarter along `--bd` from `.d`, `fold (map .d onto --ef through .p)
  (toward .c)` keeps one candidate by the objects and none by the flap. A
  `mark` moves no paper and has no flap to measure, and in a folded state the
  flap needs a rule for which layers belong to it. The objects are what the
  program names, so a reader can find what is measured in the statement.
- **`moving` with a landing stage.** `moving` names where the flap starts and
  gives no target to measure against.
- **A point landing anywhere on the line of its target**, the extension
  beyond the paper included. The fold then has nothing on the paper to aim
  at, where a line that folds onto a point already needs paper at the place
  that lands. Constructing the target line first states the landing in the
  program.
- **Suggestions that search every item and every combination.** One item
  per object, in a fixed order, is what a reader can repeat by hand, and
  the first that keeps a candidate alone is the one the figure names.

## Consequences

- `def-selection` in `spec/MODEL.md` states the selection and the condition
  every fold puts on its candidates. `spec/BELOCH.md` moves `toward` out of
  the construction, adds `heading` and `(x toward …)`, parenthesises the parts
  of `align`, and gives bindings items. The prose form of axiom 5 loses its
  `toward`.
- One rule covers axioms 5, 6 and 7. A line moved onto a line it meets at an
  oblique angle can select another candidate than before, and tests on such
  programs change. A line that crosses the other one on the paper becomes
  selectable: with `(x toward …)` each fold carries the part of `x` on the
  side away from `toward`, and where the two folds land equally near is
  stated in `lem-crossing-landing`. A bare `toward` measures the part of the
  target line that folds over too, and ties more often there.
- Axiom 7 keeps a candidate with its two points on opposite sides: the fold
  lands one point on its line and the other line on its point. The figures
  in #58 that drop such a candidate show the reading this record rejects.
- `fig-toward-boundary` writes `(.d toward .c)`: both candidates remain for
  `.c`, and the landing stage keeps the one that lands `.d` on the top edge.
- A redundant `moving` wants a warning. The language has errors with hints
  (ADR 0028) and no warnings; the channel is a decision of its own (#59).
- A point that would land beside the paper of its line removes the
  candidate at the moved-material stage. On the square with the midlines
  `--v` and `--h`, `fold (map .a onto --v and .c onto --h)` has three
  candidates without that condition and none with it.
- The stages view of `beloch render` shows the suggestions in its closing
  block; the kernel computes them, and the view repeats none of the
  selection.
- Comments and notes that cite ADR 0022 for the alignment set and the prose
  forms cite this record instead.
- `flatten` keeps its selection stages (`open-flatten-selection`). Whether
  its first stage is the landing stage of this record is open.
