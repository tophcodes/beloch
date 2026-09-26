---
id: "0031"
title: "toward names the side that stays; along names the direction of the crease"
date: 2026-09-27
status: accepted
---

# 0031: toward names the side that stays; along names the direction of the crease

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

**`toward` names the side that stays.** For each candidate, the side of its
line that holds the `toward` point stays and the other side folds over.
`toward` takes a point or a line. A line names the side it lies on; a line
that the candidate crosses on the paper names no side for that candidate.

**A fold keeps only the candidates it can perform.** The moved material of a
construction is every object one of its `onto` alignments moves: a point, or
the material of a line. A candidate remains when all of that material lies on
the side that folds over. Whether that side comes from `toward` (the side
opposite the point) or from `moving` (the side of the anchor), the condition
is the same. A candidate whose material lies on both sides of its line never
remains.

**Among several remaining candidates, `toward` keeps the one that lands the
moved material nearest the `toward` point or line.** Equal distances leave
the construction ambiguous. `moving` names no target and has no such stage:
several candidates remaining after `moving` leave the fold ambiguous.

**`along` names the direction of the crease.** `along --l` keeps the
candidate whose line makes the smallest angle with `--l`. The position of
`--l` plays no part. Equal angles leave the construction ambiguous.

**`toward` and `moving` agree or the fold fails.** Both name a side; when they
name the same side as staying and moving, the fold is an error. When they
agree, `moving` still names the flap that moves, and it is redundant only
where it names the flap the fold would take without it.

**Each word sits at the level it speaks about.** Alignments and `along`
determine the line and stay inside the construction. `toward`, `moving` and
the placement determine the fold and are items of the write, as `toward`
already is in `flatten`. The canonical form parenthesises each part of a
construction:

```beloch
(align (.p onto --l) (through .q) (along --m))
fold (align (.d onto --ef) (through .p)) (toward .c) (moving .d)
fold (map .d onto --ef through .p) (toward .c)
```

A binding takes items as a write does, and `toward` there names the side
that would stay: `--k = (map --v onto --h) (toward .b)`. A construction
inside an expression takes no selection; it is bound first.

**This record supersedes ADR 0022** and carries forward what it decided
apart from the selection. A construction is its set of alignments, together
with its named fold lines and its `along`. The prose forms of the seven
axioms desugar to that set, and a prose form means what its `align` spelling
means. An axiom number names one alignment set, recognised by the kinds of
its alignments, and appears in error messages, provenance and documentation;
it is no type of its own. A set that is none of the seven is an error naming
its alignments. `toward` leaves the construction.

## Alternatives considered

- **The line nearest the point**, as `def-selection` stated it. It answers
  where the crease lies, where every other use of `toward` asks where the
  paper goes, and it disagrees with the landing rule on the first programs
  #58 drew. Its question is served by `along`, which asks it without a
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
  role. With `along` in the construction and `toward` in the write, the
  nesting already separates the roles. Beloch's sigils name sorts of values,
  and alignments and selections are parts of statements.
- **`moving` with a landing stage.** `moving` names where the flap starts and
  gives no target to measure against.

## Consequences

- `def-selection` in `spec/MODEL.md` states the two selections and the
  condition every fold puts on its candidates. `spec/BELOCH.md` moves
  `toward` out of the construction, adds `along`, parenthesises the parts of
  `align`, and gives bindings items. The prose form of axiom 5 loses its
  `toward`.
- One rule over the moved material covers axioms 5, 6 and 7. Axiom 7
  measures both moved points. A line moved onto a line it meets at an oblique
  angle can select another candidate than before, and tests on such programs
  change. A line crossing the other one on the paper stays ambiguous, now as
  a consequence of the rule.
- `fig-toward-boundary` keeps its selection: both candidates remain for
  `.c`, and the landing stage keeps the one that lands `.d` on the top edge.
- A redundant `moving` wants a warning. The language has errors with hints
  (ADR 0028) and no warnings; the channel is a decision of its own (#59).
- Comments and notes that cite ADR 0022 for the alignment set and the prose
  forms cite this record instead.
- `flatten` keeps its selection stages (`open-flatten-selection`). Whether
  its first stage is the landing stage of this record is open.
