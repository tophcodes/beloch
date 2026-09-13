---
title: The model
description: What a Beloch program talks about. States, values, and the operations on both.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

This document defines what a Beloch program talks about: the set of states,
the values a program can name, and the operations on both. `SPECIFICATION.md`
says how the language is written; this document says what it means. How the
kernel realizes it is the subject of `KERNEL.md`, which refers to the
statements here by their ids; this document does not refer back.

The document grows in steps. Each definition is stated with its intuition
first, then its formal content.
Statements are numbered within their section: a *Definition* introduces a
term, a *Lemma* is a consequence with a proof or a pointer to one, a
*Corollary* follows from a lemma without further argument, a *Remark* is
unproven commentary, a *Condition* is a named requirement that a later
definition collects, an *Open* point is a decision still to be made and is
part of the contract until closed. Each statement carries the terms it
defines, the statements it uses and the statements that use it. Every word used in a technical sense is listed under
[Terms](#terms) with a link to where it is defined; the first use in the text
links there too.

**Before reading.** The text uses set notation and plane geometry at
first-course level, and folding words (crease, flap, layer, mountain, valley)
the way folders use them. Everything it needs from flat-folding theory is
restated where it is used; the full account is Hull [@hull2020, chapter 6].

**Review status.** Sections 1 and 2 read and accepted. Section 3 read up to
the taco-taco condition. Section 4 is a draft.

## 1. Paper

Intuition: a sheet of paper is a flat shape whose points keep their identity
no matter how the sheet is folded. Everything Beloch names is a point of the
sheet, a line drawn on the sheet, or a set of such things.

::: {.definition #def-sheet name="sheet" defines="term-paper-frame"}
A sheet is a simple polygon $P \subset \mathbb{R}^2$: a closed boundary
without self-intersection and without holes. The plane of $P$ is the
[paper frame](#term-paper-frame). A paper point is an element of $P$.
:::

::: {.term #term-paper-frame name="paper frame"}
The plane the sheet $P$ lives in before any folding; coordinates in it never
change.
:::

The sheet may be non-convex. Convexity belongs to the faces of a state
([#def-flat-state]): a non-convex sheet is decomposed into convex faces joined
by flat hinges (angle $0$), and a convex sheet is a single face.

Holes are excluded because the tortilla conditions of [#def-noncrossing] are
stated for regions without holes [@hullzakharevich2023, §2.1] and because the
existence of a folding motion is proven for simple polygons only
[@demaine2007, sec. 11.6, Theorem 11.6.2].

Sources: paper as an orientable 2-manifold with boundary [@demaine2007,
§11.4.1]; faces as strictly convex polygons because face division and overlap
algorithms need it [@ida2020, p. 176].

## 2. Flat folded state

Intuition: a folded state records where every point of the sheet lies on the
[table](#term-table) and, wherever paper lies on paper, which layer is on top.
In particular a state does not remember how it was reached.[^history]

[^history]: An implementation may record the history for its own purposes.
    Nothing in this document depends on such a record, and no operation may
    read it.

::: {.definition #def-flat-state name="flat folded state" uses="def-sheet def-noncrossing" defines="term-table term-face term-hinge term-layer"}
A flat folded state of a sheet $P$ is a pair $(f, \lambda)$ where

- $F$ is a finite decomposition of $P$ into convex polygons, the faces, such
  that any two faces meet in a common edge, a common vertex, or not at all;
- $f : P \to \mathbb{R}^2$ is a map that is an isometry (a rotation,
  reflection, or translation, composed) on each face and continuous across
  face edges; the plane of the image is the [table frame](#term-table);
- $\lambda$ assigns to every pair of faces whose images overlap in a region of
  positive area one of *above* and *below*, subject to [#def-noncrossing].
:::

::: {.term #term-table name="table"}
The plane a state is folded onto, the image of $f$. "Table frame" names its
coordinate system; a point of the sheet has one paper coordinate and, per
state, one table coordinate.
:::

::: {.term #term-face name="face"}
A convex polygon of the decomposition $F$ on which $f$ is a single isometry.
:::

An edge shared by two faces is a [hinge](#term-hinge). Its angle is $0$ when the
two faces are placed by the same isometry, so that on the table they continue
each other without a bend; it is $\pm\pi$ when one face's isometry is the
other's composed with the reflection across the edge's image, so that on the
table the two faces lie on top of each other, joined along the edge. A hinge
of angle $0$ is a flat crease; a hinge of angle $\pm\pi$ is a folded crease.

::: {.term #term-hinge name="hinge"}
An edge shared by two faces, with an angle of $0$ (flat crease) or $\pm\pi$
(folded crease).
:::

::: {.term #term-layer name="layer, above, below"}
In a region of the table where several faces overlap, the faces are the
layers, and $\lambda$ says for each pair which is above.
:::

::: {.definition #def-refinement name="refinement equivalence" uses="def-flat-state" defines="term-refinement"}
Splitting a face along a segment into two faces joined by a hinge of angle $0$
does not change the state. Two states that differ only by such splits are the
same state.
:::

::: {.term #term-refinement name="refinement"}
Splitting faces along flat hinges; states equal up to refinement are the same
state.
:::

::: {.term #term-flap name="flap"}
A maximal set of faces joined by flat hinges; the unit that moves as one in a
fold. ADR 0017, to be defined in the section on operations.
:::

This makes the convex decomposition of [#def-sheet] immaterial, makes `mark`
a no-op on the state modulo refinement, and is what "the two routes reach the
same folded state" means when comparing programs.

::: {.remark #rem-linear-extension name="linear extensions" uses="def-flat-state"}
$\lambda$ is a partial order: it relates overlapping faces only. A total order
of all faces that agrees with $\lambda$ on every overlapping pair is a linear
extension of $\lambda$, and two linear extensions with the same restriction to
overlapping pairs describe the same state. A linear extension exists only
when the *above* relation is acyclic across regions, and flat-foldable states
violate this: in the square twist the four central faces lie
over-under-over-under around the twist, so "no linear layer ordering will be
able to avoid such obstructions", while the fold is flat-foldable
[@hull2020, sec. 6.5, p. 119]. A representation that stores one linear
extension therefore cannot hold every state of [#def-flat-state].
:::

::: {.lemma #lem-face-points name="face and point orderings agree" uses="def-flat-state def-noncrossing"}
Let $(f, \lambda)$ be a flat folded state in the sense of [#def-flat-state],
and let $\lambda'$ be the layer ordering on points that Demaine
[@demaine2007, §11.4] and Hull and Zakharevich [@hullzakharevich2023, §2.1]
define. Setting $\lambda'(p, q) = \lambda(F_p, F_q)$ for points $p, q$
interior to faces $F_p, F_q$ with $f(p) = f(q)$ yields a global layer ordering
in their sense, and every such ordering arises this way from exactly one
$\lambda$.

*Proof.* Pending. The forward direction needs the non-crossing conditions of
[#def-noncrossing]; the backward direction uses that faces are uncreased
regions, so $\lambda'$ is constant on pairs of faces by the
tortilla-tortilla property.
:::

## 3. Non-crossing conditions

Intuition: $\lambda$ says which of two overlapping faces is on top. Not every
such assignment describes a sheet of paper. A face cannot pass through
another face, it cannot pass through a fold, and two folds cannot thread
through each other. This section states the conditions that rule those out,
one at a time, and then defines a non-crossing layer ordering as one that
satisfies them all. They are the non-crossing conditions of Hull and
Zakharevich [@hullzakharevich2023, §2.1], restated for faces instead of
points, plus two conditions that a decomposition into faces has to satisfy to
be one sheet.

Two of the six properties in the literature need no condition here. Existence
says that $\lambda$ is defined exactly on overlapping pairs, and
tortilla-tortilla says that two uncreased regions which fully overlap are
ordered as wholes. Both hold by construction, because [#def-flat-state]
defines $\lambda$ on pairs of faces and a face is an uncreased region.

::: {.condition #cond-order name="order condition" uses="def-flat-state"}
For faces $A$, $B$, $C$ whose images share a region of positive area: if $A$
is above $B$ and $B$ is above $C$, then $A$ is above $C$. Antisymmetry needs
no separate statement, since $\lambda$ assigns one of *above* and *below* to
each unordered pair.
:::

The next two conditions speak about folded hinges. A folded hinge $h$ between
faces $A$ and $B$ folds the two onto each other, so that near $f(h)$ the
images of $A$ and $B$ coincide; the pair is a [taco](#term-taco), closed along
$f(h)$ and open on the other side.

::: {.term #term-taco name="taco"}
Two faces joined by a folded hinge, seen near the hinge: closed along the
hinge, open away from it.
:::

::: {.term #term-tortilla name="tortilla"}
A face whose image covers a neighbourhood of a point of a folded hinge's
image without that hinge being its own edge.
:::

::: {.condition #cond-taco-tortilla name="taco-tortilla condition" uses="def-flat-state cond-order" defines="term-taco term-tortilla"}
Let $A$ and $B$ be joined by a folded hinge $h$, and let $C$ be a face whose
image contains a neighbourhood of an interior point of $f(h)$, so that $C$
overlaps both $A$ and $B$ there. Then $C$ lies on the same side of both:
$\lambda(A, C) = \lambda(B, C)$. A face cannot lie between the two sides of a
fold.
:::

::: {.condition #cond-taco-taco name="taco-taco condition" uses="def-flat-state cond-order"}
Let $A$ and $B$ be joined by a folded hinge $h$, and $C$ and $D$ by a folded
hinge $k$, such that $f(h)$ and $f(k)$ overlap in a segment of positive length
and all four faces overlap near it. Then the two pairs do not interleave: in
the order of $A$, $B$, $C$, $D$ at that place, $C$ and $D$ are either both
above $A$ and $B$, both below them, or both between them, and likewise with
the pairs exchanged. Two folds along the same line are nested or separate.
:::

The last two conditions concern $f$ and the decomposition rather than
$\lambda$. They are consequences of [#def-flat-state] for a sheet that is one
piece, and they are stated on their own because a representation has to
check them.

::: {.condition #cond-hinge-closure name="hinge closure condition" uses="def-flat-state"}
For every hinge between faces $A$ and $B$, the isometries of $A$ and $B$ agree
on the shared edge, and the isometry of $B$ is the isometry of $A$ either
unchanged or composed with the reflection across the edge. Equivalently every
hinge has angle $0$ or $\pm\pi$, and $f$ is continuous.
:::

::: {.condition #cond-connected name="connectivity condition" uses="def-sheet def-flat-state"}
The faces, joined along their hinges, form one connected piece: every face is
reachable from every other through shared edges. This restates that the
decomposition covers a single sheet.
:::

These five conditions are what a layer ordering needs to describe paper. Each
of the first three names one way in which paper would pass through itself; the
last two say that $f$ folds one sheet. That they are also enough, so that
every ordering which satisfies them describes a sheet that can be folded, is
a theorem rather than a definition, stated as [#lem-noncrossing-adequate]
after the definition that collects them.

::: {.definition #def-noncrossing name="non-crossing layer ordering" uses="def-flat-state cond-order cond-taco-tortilla cond-taco-taco cond-hinge-closure cond-connected" defines="term-noncrossing"}
$\lambda$ is a non-crossing layer ordering for $f$ when it satisfies

- the [order condition](#cond-order),
- the [taco-tortilla condition](#cond-taco-tortilla), and
- the [taco-taco condition](#cond-taco-taco).

A pair $(f, \lambda)$ with a non-crossing $\lambda$ is a flat folded state when
in addition

- the [hinge closure condition](#cond-hinge-closure) and
- the [connectivity condition](#cond-connected)

hold.
:::

::: {.term #term-noncrossing name="non-crossing"}
The conditions on a layer ordering that keep the paper from passing through
itself.
:::

::: {.lemma #lem-noncrossing-adequate name="the conditions are necessary and sufficient" uses="def-noncrossing def-flat-state"}
Let $f$ be an isometric folding map of a sheet $P$ into the plane, with faces
as in [#def-flat-state]. A layer ordering $\lambda$ on the faces describes a
placement of $P$ in space that does not pass through itself if and only if
$\lambda$ is non-crossing in the sense of [#def-noncrossing].

*Proof.* Cited. Necessity: whenever two crease images coincide, the faces on
either side are two tacos, a taco and a tortilla, or two tortillas, and any
self-intersection caused by the ordering falls into one of these three cases
[@hull2020, sec. 6.5, p. 123]. Sufficiency: lift each face along the third
axis by its position in the ordering and join the faces along their hinges by
half-cylinders; the conditions are exactly what makes this map one-to-one
[@hull2020, sec. 6.5, Proposition 6.13, p. 124]. That such a placement is
reached by a continuous folding motion of unstretched paper is Demaine's
theorem [@demaine2007, sec. 11.6, Theorem 11.6.2], which Hull's argument
leaves open, since it deforms the paper elastically [@hull2020, p. 125]. The
sheet without holes is what both results assume; with holes an additional
condition on the boundary curves is needed [@hull2020, Proposition 6.14].
:::

Sufficiency is what allows the model to define a flat folded state through
$f$ and $\lambda$ alone: nothing about a state's physical realisability is
left outside the definition.

Sources: the six properties on points, with Figure 1 showing the two crossing
patterns [@hullzakharevich2023, §2.1]; Justin's three conditions in Hull's
statement [@hull2020, sec. 6.5, p. 123].

## 4. Values and reads

Intuition: a program names things on the paper, points, lines, and pieces of
paper, and asks questions about them: where is this point now, which line
folds this onto that, which piece of paper carries this point. Values are the
answers, and a read is the act of asking. A read looks at the current state
and computes a value; it changes nothing. If the state has no answer, the
read fails, and the program stops there.

::: {.definition #def-point name="point value" uses="def-sheet def-flat-state" defines="term-point"}
A value of sort *point* is a paper point $p \in P$. In a state $(f, \lambda)$
its position on the table is $f(p)$. A point keeps its paper coordinate
through every later state; only $f(p)$ changes.
:::

::: {.term #term-point name="point"}
A paper point, named once and carried in paper coordinates; its table
position depends on the state.
:::

::: {.definition #def-line name="line value" uses="def-flat-state" defines="term-line term-material"}
A value of sort *line* is a line $\ell$ in the table frame. Its *material* in
a state is the set of segments in which $\ell$ meets the images of the faces:
for every face $F$ with $f(F) \cap \ell$ of positive length, the paper segment
$f|_F^{-1}(f(F) \cap \ell) \subseteq F$. A line is a description of where a
crease would go; it has no material of its own until a write creases it.
:::

::: {.term #term-line name="line"}
A line in the table frame, computed by a read in some state; its material in
a state is where it crosses the paper.
:::

::: {.term #term-material name="material"}
The paper segments a line crosses in a state, one per face.
:::

::: {.definition #def-bundle name="bundle" uses="def-flat-state def-line" defines="term-bundle term-crease"}
A value of sort *bundle* is a finite set of paper segments, each lying in one
face or on one hinge. The material of a line is a bundle. A *crease* is the
bundle of hinges that one write scored; it keeps its identity through later
states, and once later folds have bent it its hinges no longer lie on one
table line.
:::

::: {.term #term-bundle name="bundle"}
A finite set of paper segments in faces or on hinges; the material of a line,
or a crease.
:::

::: {.term #term-crease name="crease"}
The bundle of hinges that one write scored, named or unnamed.
:::

::: {.definition #def-flap name="flap" uses="def-flat-state def-refinement" defines="term-flap"}
A *flap* of a state is a maximal set of faces in which any two are joined by
a chain of hinges of angle $0$. Flaps partition the faces; they are the
pieces of paper that lie flat as one, and they are invariant under refinement
([#def-refinement]), which is why the language addresses flaps and never
faces.
:::

::: {.definition #def-read name="read" uses="def-flat-state def-point def-line def-bundle def-flap" defines="term-read"}
A read of sort $V$ is a partial function $r : S \times A \rightharpoonup V$
from states and arguments (values of the sorts above) to values of sort $V$.
A read has no effect on the state. Where it is undefined the program fails
with a reason.
:::

::: {.term #term-read name="read"}
A partial function from the current state and some values to a value; it
never changes the state.
:::

The reads of the language fall into three families.

::: {.definition #def-motion name="motion" uses="def-read def-line" defines="term-motion"}
A *motion* is a read of sort line built from a Huzita-Justin construction: a
construction $c$ takes points and lines and yields a finite set $c(s, a)$ of
candidate lines, between zero and three of them. The motion is the read
$$ r(s, a) = \ell \quad \text{when } \sigma(s, a, c(s, a)) = \{\ell\}, $$
undefined otherwise, where $\sigma$ is the selection the program stated, the
identity when it stated none. Selections are: discard candidates whose
material in $s$ is empty; keep the candidate nearest a named point; keep the
candidate whose fold moves a named point to a named side.
:::

::: {.term #term-motion name="motion"}
A read that computes a line from a Huzita-Justin construction and a
selection among its candidates.
:::

::: {.definition #def-selector name="selector" uses="def-read def-flap def-point"}
A *selector* is a read of sort flap or point that resolves a description by
incidence: the flap whose faces contain every listed point; the point where
the materials of two bundles cross; the point on a bundle's material at a
given fraction of its length from a named end. Each is defined exactly when
the description picks out one thing.
:::

::: {.definition #def-filter name="filter" uses="def-read def-bundle"}
The *filters* are the reads of sort bundle that form the Boolean algebra of
subsets of a bundle $b$ generated by incidence predicates: for a point $p$, a
line $m$ or a flap $\phi$, the predicate "the segment contains $p$", "the
segment's table image meets $m$", "the segment lies in a face of $\phi$".
A filter keeps the segments satisfying a predicate, its complement drops
them, and the union joins two bundles. Chaining filters is intersection.
:::

::: {.open #open-line-after-fold name="a line value across later states"}
A line value is a table line. When a later write moves the paper, the value
stays where it is on the table while its material changes. Whether this is
the intended meaning, or a line should be re-anchored to the material it was
computed from, is not decided; it decides what `--l = map .a onto .b`
followed by a fold and then `mark --l` means.
:::

## Terms

Each entry gives the meaning in one line and points to the definition that
fixes it.

## References
