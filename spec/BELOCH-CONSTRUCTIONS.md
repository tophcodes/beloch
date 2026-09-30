---
title: Constructions
description: The reads of sort line that a write's axis comes from, the seven axioms as names of alignment sets, and how a statement selects one of several candidate lines.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

A construction is the read of sort line that a write's axis comes from: a
set of *alignments* that together determine one fold line, or several. An
alignment is an incidence between two objects, each a point, a line, or the
folded image of one: a point onto a point, a point onto a line, a line onto
a line, the fold line through a point, the fold line perpendicular to a
line. Alperin and Lang show that the seven Huzita-Justin axioms are exactly
the minimal sets of such alignments that determine one fold line with
finitely many solutions [@alperin2006, §3], and that the same alignments,
distributed over two fold lines, give the 489 two-fold axioms [@alperin2006,
§4]. The construction with its alignments is the canonical form; an axiom
number is the name of one such set.

```{.bel .prelude name=axioms}
paper square
mark (through .a .b) as --l
mark (through .b .c) as --m
mark (through .a .c) as --ac
.p = free on --ac from .a at 1/2
.q = free on --ab from .a at 1/2
```

```{.bel .construction prelude=axioms}
(align (.a onto .c))                            ; axiom 2
(align (through .a) (through .b))               ; axiom 1
(align (perp --l) (through .p))                 ; axiom 3
(align (.p onto --l) (through .q)) (toward .a)  ; axiom 6, and the side that stays
(align (.p onto --l) (perp --m))                ; axiom 4
(align (--l onto --m)) (toward .c)              ; axiom 5, and the side that stays
(align (.a onto --m) (.c onto --l))             ; axiom 7

; assert .p = (1/2, 1/2)
; assert .q = (1/2, 0)
```

The prose forms of the seven axioms are sugar for these, the
`prose_axiom` alternatives: `(through .a .b)`, `(map .a onto .c)`, `(perp
--l through .p)`, `(map .p onto --l perp --m)`, `(map --l onto --m)`,
`(map .p onto --l through .q)`, `(map .p onto --l and .q onto --m)`. A
prose form means what its `align` spelling means. The axiom number names
one alignment set, recognised by the kinds of its alignments; it appears in
error messages, in provenance (`"axiom": "axiom6"` in `beloch:edges`) and
here, and it is no type of its own. A set that is none of the seven is an
error naming its alignments.

A construction holds what determines the line: its alignments and its
`heading`. What determines the fold, `toward`, `moving` and the placement,
are items of the statement that reads the construction (ADR 0031). A
binding takes the side items as a write does, `--k = (map --v onto --h)
(toward .b)`, so a bound line is selected the way a fold along it would
be. A construction inside an expression takes no selection; it is bound
first. A `toward` written inside a construction is an error, with the hint
`write it as an item of the write: (toward .p)`.

A construction over several fold lines names them and lets each alignment
say which line folds: `(align --a --b (--a .p onto --l) (--b .q onto --m)
(--a .r onto --b .s))` is the two-fold axiom Alperin and Lang call
`AL6ab8`. Its name is composed from the kinds of its alignments, as every
two-fold name is [@alperin2006, §4]; `packages/multifold` computes the
same names. No two-fold construction is evaluated by the kernel yet; the
syntax is fixed here so that it needs no second form when one is.

::: {.open #open-multifold-syntax name="naming fold lines inside a construction"}
The two-fold form above writes the folding line in front of the object it
folds, `(--a .p onto --l)`, and a doubly folded alignment as `(--a .r onto
--b .s)`. Whether the fold lines of a construction are declared in the
`align` head, as above, or are the names the binding form gives, and how an
alignment on a virtual point (Alperin and Lang's `AL10`) is written, is not
decided and waits for the first two-fold construction the kernel can solve.
:::

## Selection

Axioms 5, 6 and 7 leave finitely many candidate lines, usually more than
one, and the statement that reads the construction keeps one of them
([def-selection](/model/#def-selection)). A candidate creases a face of
the current state; a line off the paper, or one grazing an edge or a
corner, creases nothing and is no candidate. An `onto` alignment is an
incidence: after the fold, one of its two objects lies on the other, and
either may be the one that moves, so `(--l onto .p)` means `(.p onto
--l)`. The stages run in order, numbered as in the model, and each error
below names the stage that left no line or several.

1. `(heading --l)` keeps the candidates whose line makes the smallest
   angle with `--l`. The position of `--l` plays no part, and a tie passes
   on to `toward`.
2. `(toward …)` names the side of each candidate that stays: the side that
   holds the point, or the side the line lies on. A point on the
   candidate, or a line the candidate crosses on the paper, names no side
   of it. `(moving …)` names the side that folds over: the side of its
   first anchor point off the candidate, or the side of a line's material.
   With both items, `moving` has to name the side opposite `toward`.
3. A candidate remains when the fold with that side carries out every
   alignment: one of its objects lies on the side that folds over and lands
   on the paper of the other, or a point lies on the candidate and on its
   target line already. A point that folds onto a line lands on the part of
   the line that lies on the paper, and a line that folds onto a point has
   paper at the place that lands on it. A landing on a line's extension
   beyond the edge cannot be made by eye; a program that wants one
   constructs the target line first. A candidate for which stage 2 names no side does not remain.
   With neither item, a candidate remains when either side carries the
   construction out.
4. Among several remaining candidates, `toward` keeps the one that lands
   the objects of its alignments nearest it: the points and the parts of
   lines that fold over, where they land, or with `(x toward …)` only the
   part of `x`.
   The rest of the flap goes unmeasured. Distances are between sets and
   compared exactly.

The side that stage 2 names is the side the fold moves. With no side item,
the side that alone carries the construction out folds over, and where both
do, the side of the first object as the program writes it: `fold (map .a
onto .b)` folds `.a` onto `.b`, and `fold (map .a onto .b) (toward .a)`
folds `.b` onto `.a`. Where that object names no side either, a line lying
across the candidate or a point on it, the write needs `toward` or
`moving`. `toward` names the side that stays on every write: on a
construction of one line, on a fold along an existing crease, `fold (--v)
(toward .b)`, on `reverse (--h) (toward .d)`, whose tip lies opposite `.d`,
and on a placed fold, whose block is the material opposite the `toward`
where the write has no anchor.

```{.bel .frag}
fold (map .a onto .b) (toward .a)

; assert .b = (0, 0)
```

`(x toward .u)` names what goes toward `.u`. `x` is one of the objects of
the construction's alignments, compared by place, and the candidates that
do not fold `x` over drop out at stage 4, where `x` is measured, also when
no other candidate is left to compare.

Errors, with the stage that raises them:

- no candidate crosses the paper: "map .p onto --d through .q: no crease
  lands on the paper, so there is no fold to make";
- no candidate carries out the construction: with `toward`, "no fold of map
  .p onto --d through .q keeps .x on the side that stays and carries out
  its alignments"; with `moving` alone, "no fold of … moves .c and carries
  out its alignments"; with neither, "no fold of … carries out all its
  alignments at once";
- `toward` and `moving` naming the same side: "toward .x and moving .c name
  the same side of the fold line", hint "drop one of them";
- a `toward` on a line that determines one: "toward .x names no side of the
  fold line";
- `(x toward …)` with an `x` that is no object of the construction: "x is
  none of the objects of …";
- two candidates landing equally near `toward`: "toward .x lies as near to
  where one fold of … lands the objects of its alignments as to where
  another does", with `(x toward …)` naming `x` in place of the objects,
  hint "name what goes toward .x, e.g. (.p toward .x)";
- several candidates remaining without `toward`: "map .p onto --d through .q
  is ambiguous: 2 folds carry it out, all landing on the paper", hint "add
  (toward .x) or a heading";
- `heading` on a construction that determines one line, a parallel axiom 5
  among them: "this construction determines one line", hint "drop heading";
- `toward` or `moving` on a `mark` along an existing line, which selects
  nothing and moves nothing.

When several candidates remain, the trace (`FOLD.md`, "The trace") carries
one suggestion per remaining candidate: an item that, added to the
statement, keeps that candidate alone. Without `toward`, the selection runs
again with `(toward x)` for each named point in scope and then each named
line, in program order, and the suggestion is the first `x` after which
exactly that candidate remains. After a tie at stage 4 of a bare `toward`,
it tries `(x toward …)` over the objects of the alignments in the order the
program writes them. A candidate no such item keeps alone has no
suggestion, and a selection that ends with no candidate has none. A
suggestion is checked for its own statement only; a later statement that
fails with it reports that failure where it happens.

## Axiom 5, a line onto a line

`(map --l1 onto --l2)` folds `--l1` onto `--l2` along an angle bisector
[@justin1986, §8.1, operation ⑤], [@hull2020, §1.5]. Two lines that cross
have two bisectors, perpendicular to each other. Two parallel lines have
one midline, and two identical lines are an error, "lines are identical".
A line's material is the segments of a crease, or the chord of the paper
under a line bound by `=`. The kite base folds an edge onto the long
diagonal; one bisector crosses the paper and the other touches it only at
`.a`, so only the first is a candidate.

```{.bel .frag}
mark (through .a .c) as --ac
fold (map --da onto --ac)

; assert steps = 1
```

Where the two lines cross inside the material of `--l1`, each bisector has
material of both lines on both sides. `(--l1 toward .x)` measures the part
of `--l1` on the side away from `.x`: the two folds land it on the two rays
of `--l2` from the crossing, and the nearer landing is kept. Two landings
on the same ray, as long as each other, are equally near every point, and
so are two landings on opposite rays for a point on the perpendicular to
`--l2` through the crossing
([lem-crossing-landing](/model/#lem-crossing-landing)). A bare `toward`
measures the part of `--l2` that folds over too, and ties more often.
`moving` then separates the candidates by the flap it names. A fold with no
side item whose `--l1` lies across the fold line is an error, "--l1
straddles the fold line", hint "add `moving` to pick the swinging flap".

```{.bel .frag}
mark (through .a .c) as --ac
mark (through .b .d) as --bd
fold (map --ac onto --bd) (toward .b) (moving .c)

; assert .c = .b
```

The bisector of two rational lines is irrational in general, slope
$\sqrt2 - 1$ for $y = 0$ and $y = x$; equality, parallelism and the paper
tests stay exact (`SPECIFICATION.md` §6).

## Axiom 6, a point onto a line through a point

`(map .p onto --d through .q)` folds `.p` onto `--d` with a crease through
`.q` [@justin1986, §8.1, operation ⑥]. `.q` lies on the crease, so it is as
far from `.p` as from the landing on `--d`, which lies on the circle about
`.q` through `.p`: up to two landings, and a crease for each, the
perpendicular bisector of `.p` and its landing. Square roots suffice; cube
roots first appear with axiom 7.

The bird base's kite crease is the case the paper settles: on the
preliminary base, `map .sr onto --mid through .c` has two candidates, and
the outward one meets the folded base only at `.c`
(`examples/bases/bird-base.bel`). The largest equilateral triangle in the
square needs `toward`, since both candidates cross the paper
([fig-candidates](/model/#fig-candidates)).

Errors of its own: `.p` and `.q` the same point, "…: .p and .q are the
same point, so no fold exists"; the circle missing `--d`, "cannot fold .p
onto --d through .q: out of reach". When `.p` lies on `--d` already, the
identity landing is dropped and the mirror landing gives the crease.

## Axiom 7, two points onto two lines

`(map .p onto --d and .q onto --e)` folds `.p` onto `--d` and `.q` onto
`--e` with one crease [@justin1986, §8.1, operation ⑦]. Each alignment
traces a parabola with focus the point and directrix the line, and the
crease is a common tangent of the two, a root of a cubic: up to three
candidates [@hull2020, §2.3–2.4]. This is the operation that doubles the
cube and trisects an angle, beyond ruler and compass. The crease is
irrational in general, its coordinates in a field $\mathbb{Q}(\alpha)$ with
$\alpha$ algebraic of degree 3, and they are compared exactly.

A candidate with `.p` and `.q` on opposite sides still carries out both
alignments when the side of `.p` folds over and has paper of `--e` at the
place that lands on `.q`: `.p` lands on `--d`, and `--e` lands on `.q`.
`(.p toward .x)` measures where `.p` lands.

```{.bel .frag}
mark (through .a .c) as --diag
mark (through .b .d) as --anti
fold (map .a onto --anti and .d onto --diag) (.a toward .b)

; assert .a = (1, 0)
; assert .d = (1, 1)
```

Errors of its own: `.q` on `--e` already, "…: .q already lies on --e",
with a hint to use axiom 6 and axiom 4 instead; `--d` parallel to `--e`,
"…: --d and --e are parallel, so the cubic degenerates and no fold exists";
no common tangent, "cannot fold .p onto --d and .q onto --e: out of reach
(no common tangent)".

## References
