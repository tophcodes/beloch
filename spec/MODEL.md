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
the taco-taco condition. Sections 4 and 5 are drafts.

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

::: {.open #open-sheet-shapes name="sheet shapes beyond polygons" uses="def-sheet def-flat-state"}
The language design for sheets as values
(`docs/superpowers/specs/2026-09-13-paper-as-value-design.md`) names the
circle as a shape. A disc is no polygon and has no decomposition into finitely
many convex polygons, so [#def-sheet] and [#def-flat-state] exclude it as
written. The generalisation is a sheet bounded by finitely many algebraic
arcs and faces that are convex regions bounded by segments and arcs of the
sheet boundary; convexity survives cuts by lines, so the rest of the model
stands. Whether to widen the definitions now or when a circular sheet is
built is open; the kernel's polygon geometry is the cost either way.
:::

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
A maximal set of faces joined by hinges of angle $0$; a piece of paper that
lies flat as one, and the unit a program addresses.
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

::: {.figure #fig-point caption="`.p` keeps the paper coordinate it was named with, and the fold moves only where it sits on the table." views="cp folded" highlight=".p"}
paper square
.p = free on --ab from .a at 1/4
fold map .a onto .c
:::

::: {.term #term-point name="point"}
A paper point, named once and carried in paper coordinates; its table
position depends on the state.
:::

::: {.definition #def-segment name="segment" uses="def-sheet def-flat-state" defines="term-segment"}
A *segment* is a closed straight piece of the sheet of positive length,
$\{p + t(q - p) : 0 \le t \le 1\}$ for paper points $p \neq q$, that lies
within one face. Faces are closed, so a segment along a hinge lies in both
faces the hinge joins. In a state the table image of a segment is
$f(\text{segment})$, a straight segment of the same length, because $f$ is an
isometry on a face that contains it.
:::

::: {.figure #fig-segment caption="`--s` meets each of the two faces in a segment that lies within it, and the crease of `--h` is a segment along the hinge where those faces join." views="cp folded" highlight="--s --h"}
paper square
--s = map .a onto .b
fold --h = map .a onto .d
:::

::: {.term #term-segment name="segment"}
A straight piece of the sheet inside one face, carried in paper coordinates.
:::

::: {.definition #def-line name="line value" uses="def-flat-state def-segment" defines="term-line term-material"}
A value of sort *line* is a line $\ell$ in the table frame. Its *material* in
a state is the set of segments in which $\ell$ meets the images of the faces:
for every face $F$ with $f(F) \cap \ell$ of positive length, the paper segment
$f|_F^{-1}(f(F) \cap \ell) \subseteq F$. A line is a description of where a
crease would go; it has no material of its own until a write creases it.
:::

::: {.figure #fig-line caption="The material of the table line `--l` is one segment per face it crosses: on the paper the two lie on either side of the crease, on the table they land on the same stretch of `--l`." views="cp folded" highlight="--l"}
paper square
--l = through .a .c
fold map .a onto .c
:::

::: {.term #term-line name="line"}
A line in the table frame, computed by a read in some state; its material in
a state is where it crosses the paper.
:::

::: {.term #term-material name="material"}
The paper segments a line crosses in a state, one per face.
:::

::: {.definition #def-bundle name="bundle" uses="def-flat-state def-segment def-line" defines="term-bundle term-crease"}
A value of sort *bundle* is a finite set of segments. The material of a line
is a bundle. A *crease* is the
bundle of hinges that one write scored; it keeps its identity through later
states, and once later folds have bent it its hinges no longer lie on one
table line.
:::

::: {.figure #fig-bundle caption="The crease `--m` is one straight line on the paper; the fold that follows bends it, and on the table its two hinges meet at a right angle." views="cp folded" highlight="--m"}
paper square
mark --m = map --ab onto --cd
fold map .a onto .c
:::

::: {.term #term-bundle name="bundle"}
A finite set of segments; the material of a line, or a crease.
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

::: {.figure #fig-flap caption="The fold leaves two flaps; the marked crease `--s` runs through the highlighted one and splits it into two faces, which stay one flap because the hinge between them has angle $0$." views="cp" highlight="#[.c]"}
paper square
.m = free on --cd from .c at 1/4
fold map .a onto .b
mark --s = through .b .m
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
A *motion* is a read of sort line built from a construction. An *alignment*
is an incidence between two objects, each a point, a line, or the image of
one under the fold across the line sought: a point onto a point, a point
onto a line, a line onto a line, the line through a point, the line
perpendicular to a line. A *construction* $c$ is a finite set of alignments
that determines the line: finitely many solutions, and no alignment
redundant [@alperin2006, Definition 8]. Its value $c(s, a)$ is the finite
set of candidate lines that satisfy every alignment; the seven Huzita-Justin
axioms are the seven such sets, with between zero and three candidates each
[@alperin2006, §3]. The motion is the read
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

## 5. Operations

Intuition: a write takes the current state and a few values and yields the
next state, or fails. Every write of the language is built from one
construction: some faces are reflected across a table line, and the layer
ordering is rebuilt around them. Which faces move, the moving set, is what
separates folding one flap from folding through the stack; where the moved
faces come to lie, the placement, is what separates a valley fold from a
mountain fold from a tuck. `mark` reflects nothing, `flip` reflects
everything, `fold` reflects one block, `reverse` reflects two blocks in one
move, and `flatten` moves the sectors of a fan by different motions. This
section defines the construction once and then each write as an instance of
it, with its parameters and its domain.

::: {.definition #def-write name="write" uses="def-flat-state def-noncrossing def-read" defines="term-write"}
A write with parameter sorts $A$ is a partial function
$w : S \times A \rightharpoonup S$ from states and values to states. Where it
is undefined the program fails with a reason. Every value of a write is a
flat folded state with a non-crossing ordering ([#def-noncrossing]); a write
has no other effect. The domain of a write has two parts: conditions on its
arguments, stated with each write below, and the condition that the pair
$(f', \lambda')$ it constructs satisfies [#def-noncrossing]. The second part
is the same for every write and is not repeated.
:::

::: {.term #term-write name="write"}
A partial function from the current state and some values to the next state;
where it is undefined the program fails.
:::

::: {.definition #def-score name="scoring" uses="def-flat-state def-refinement def-bundle" defines="term-score"}
For a state $s$ and a bundle $b$, *scoring* $b$ in $s$ is the refinement
([#def-refinement]) that splits every face along each segment of $b$ it
contains, joining the parts by hinges of angle $0$. By [#def-refinement] the
result is $s$; the hinges it introduces are the crease of $b$
([#def-bundle]). Scoring a line $\ell$ means scoring its material
([#def-line]).
:::

::: {.term #term-score name="score"}
Split faces along a bundle without moving anything; the state is unchanged
up to refinement.
:::

Every write below scores its axis first, so that each face lies on one side
of the axis before any face moves. Because scoring changes nothing, a write
may score every face the axis crosses, moving or not; the hinges that end up
between two stationary faces stay flat and vanish again under refinement.

::: {.definition #def-mark name="mark" uses="def-write def-score def-line def-flap def-bundle"}
The write `mark` takes a line $\ell$, a flap $\phi$ and an extent: the whole
of $\ell$, a segment of $\ell$ between two points, or a point of $\ell$. Its
value is the state itself, up to refinement. Its effect is a crease value:
the bundle of the material of $\ell$ in the faces of $\phi$, clipped to the
extent. It is defined when that bundle is non-empty and the extent lies in
the image of $\phi$; an extent that crosses a folded hinge of $\phi$ leaves
the flap and is outside the domain.
:::

`mark` is the identity on states. The read/write law of the language
sequences it as a write because it introduces a piece of material that
later reads select and later folds fold along; the model records that
material as a value in paper coordinates, and the state itself has no
memory of it. The mountain or valley intent a program may write beside a
mark is an annotation for the crease pattern output and no part of the
state or the value.

::: {.open #open-point-mark name="a mark at a point" uses="def-mark def-segment def-bundle"}
A mark whose extent is a single point yields a segment of length zero, which
[#def-segment] excludes from bundles. The language admits such a mark as a
crease whose material is one point on $\ell$ and whose line is $\ell$, and a
meet against it uses the line. Whether a bundle may hold a point together
with the line it was marked on, or a point mark is a value of its own sort,
is not decided.
:::

::: {.definition #def-letter name="letter of a folded hinge" uses="def-flat-state" defines="term-letter term-face-up"}
Let $h$ be a folded hinge between faces $A$ and $B$. Exactly one of the two
isometries $f|_A$ and $f|_B$ preserves orientation, because they differ by a
reflection; the face whose isometry preserves orientation is *face up*, the
other *face down*. The *letter* of $h$ is *valley* when the face-up face is
below the other, *mountain* when it is above [@hullzakharevich2023, §2.1].
:::

::: {.term #term-letter name="letter, mountain, valley"}
Mountain or valley, derived for every folded hinge from which of its two
faces is face up and which is above.
:::

::: {.term #term-face-up name="face up, face down"}
A face is face up in a state when its isometry preserves orientation; the
front of the paper shows.
:::

The letter is the folder's mountain and valley seen from the front of the
paper, and it is a property of the state: no write takes a letter as an
instruction, and every letter in an output is read off the state.

::: {.definition #def-reflection name="reflection of blocks" uses="def-flat-state def-score def-line cond-hinge-closure def-noncrossing" defines="term-block term-placement term-moving-set"}
Let $s = (f, \lambda)$ be a state, $\ell$ a table line, $H$ one of the two
closed half-planes bounded by $\ell$, and $\rho$ the reflection of the table
across $\ell$. Score $\ell$, so that every face lies in $H$ or in the other
half-plane. A *block* is a pair $(M, \pi)$ of a set $M$ of faces lying in
$H$ and a *placement* $\pi$, which is one of *top*, *bottom*, *over $T$* and
*under $T$* for a set $T$ of faces belonging to no block. The *reflection*
of a family of blocks with pairwise disjoint face sets is the pair
$(f', \lambda')$ given as follows, where $\mathcal M$, the *moving set*, is
the union of the blocks' face sets and every other face is *stationary*:

- $f'|_F = \rho \circ f|_F$ for $F \in \mathcal M$, and $f'|_F = f|_F$ for
  stationary $F$;
- two faces of one block that overlap under $f'$ overlapped under $f$ and
  reverse their relation: $\lambda'(A, B) = \lambda(B, A)$. A rigid half
  turn reverses a stack;
- two stationary faces keep their relation;
- a face $F$ of a block $(M, \pi)$ and a stationary face $G$ that overlap
  under $f'$ are ordered by $\pi$: $F$ is above $G$ for *top* and below $G$
  for *bottom*. For *over $T$*, $F$ is above $G$ unless $G$ lies above every
  face of $T$ it overlaps, in which case $F$ is below $G$; for *under $T$*,
  $F$ is below $G$ unless $G$ lies below every face of $T$ it overlaps. Both
  placements require $T$ to cover the landing footprint: every point of
  $f'(F)$ lies in the image of some face of $T$;
- faces of two different blocks are ordered as their placements are ordered
  in the stack: a block placed *bottom* below every other block, a block
  placed *top* above every other, a block placed at $T$ below a block placed
  at $T'$ when every face of $T$ lies below every face of $T'$ it overlaps,
  and a block placed *under $T$* below a block placed *over $T$*. Two blocks
  whose placements are not so ordered are outside the domain.

The reflection is the candidate a write returns: it is the next state when
it satisfies [#def-noncrossing] and undefined otherwise.
:::

::: {.term #term-block name="block"}
A set of faces on one side of the axis together with the placement they
receive after reflection.
:::

::: {.term #term-placement name="placement"}
Where a reflected block comes to lie among the stationary faces: outside
above, outside below, or immediately above or below a set of stationary
faces.
:::

::: {.term #term-moving-set name="moving set, stationary"}
The faces a write reflects; every other face is stationary.
:::

Hinge closure ([#cond-hinge-closure]) is where the reflection fails when the
paper would tear: a hinge that joins a moving face to a stationary face off
the axis leaves $f'$ discontinuous there. On the axis the picture is exact:

::: {.lemma #lem-toggle name="hinges toggle on the axis" uses="def-reflection cond-hinge-closure"}
Let $(f', \lambda')$ be the reflection of blocks across $\ell$, and let $h$ be
a hinge between faces $A$ and $B$. If both faces move or both are
stationary, the angle of $h$ is unchanged. If $A$ moves, $B$ is stationary
and $f(h)$ lies on $\ell$, the angle of $h$ changes from $0$ to $\pm\pi$ or
from $\pm\pi$ to $0$.

*Proof.* Write $r$ for the reflection of the paper across the line of $h$.
If both move, $f'|_B = \rho \circ f|_B$ and $f'|_A = \rho \circ f|_A$, so
$f'|_B = f'|_A \circ r$ exactly when $f|_B = f|_A \circ r$; likewise when
both are stationary. If $A$ moves and $f(h) \subset \ell$, then $f|_A$
carries the line of $h$ onto $\ell$, so $\rho \circ f|_A = f|_A \circ r$.
For a flat hinge, $f|_B = f|_A$ and $f'|_A = f|_A \circ r = f|_B \circ r$:
angle $\pm\pi$. For a folded hinge, $f|_B = f|_A \circ r$ and
$f'|_A = f|_A \circ r = f|_B$: angle $0$. $\square$
:::

The lemma is why the model needs no unfold: reflecting a block back across
a folded hinge returns that hinge to angle $0$, and the crease is then a flat
hinge that refinement forgets. What survives is the crease value, which a
later write can fold along again. Whether the language offers such a write
is its decision.

::: {.definition #def-fold name="fold" uses="def-write def-reflection def-flap def-score def-line" defines="term-anchor term-depth"}
The write `fold` takes a table line $\ell$, a side $H$ of it, an *anchor*
flap $\alpha$ with material in $H$, a *depth* flap $\delta$ with material in
$H$, which is $\alpha$ when the program names none, and a placement $\pi$.
Score $\ell$ and call the faces lying in $H$ the candidates. The moving set
$M$ is the least set of candidates that contains the faces of $\delta$ in
$H$ and is closed under

- cohesion: a candidate joined to a face of $M$ by a hinge of angle $0$ is
  in $M$, so that a flap moves as a whole ([#def-flap]); and,
- when $\pi$ is *top* or *bottom*, outward closure: a candidate that lies
  above a face of $M$ is in $M$ for *top*, and one that lies below a face of
  $M$ is in $M$ for *bottom*.

The value of the write is the reflection of the single block $(M, \pi)$. It
is defined when the faces of $\alpha$ in $H$ belong to $M$, when for *over
$T$* and *under $T$* the set $T$ is the faces of a stationary flap, and when
the reflection is a state. The crease the write scores is the bundle of the
hinges of the result that lie on $\ell$ between a face of $M$ and a
stationary face.
:::

::: {.term #term-anchor name="anchor"}
The flap a fold is told to move; it fixes the side of the axis and must end
up in the moving set.
:::

::: {.term #term-depth name="depth"}
The deepest flap a fold reaches; the moving set grows outward from it.
:::

The language derives $H$ and $\alpha$ from a point: the flap carrying it and
the side its image lies on. A point on the axis names no side, and a flap
that straddles the axis without a point names none either; both are outside
the domain. `mountain` is the placement *bottom* and the default is *top*;
`up to` names $\delta$; `over` and `under` name $T$. When $\delta$ is
$\alpha$, the anchor condition holds by construction and the moving set is
the outward closure of one flap: the layers above it move with it, the
layers beneath it stay. When $\delta$ lies deeper, the moving set grows from
$\delta$ outward and the anchor condition fails exactly when a stationary
flap covers the anchor in the crease region; the fold would have to move
paper it was not told to move.

::: {.figure #fig-fold-default caption="`--f` folds the corner of the top layer only: the moving set is the outward closure of the flap carrying `.b`, and the layer beneath it stays. The crease reads mountain because that layer lies face down." views="cp folded" highlight="--f"}
paper square
fold map .b onto .a
.p = free on --bc from .b at 1/4
.q = free on --ab from .b at 1/4
fold --f = through .p .q moving .b
:::

::: {.figure #fig-fold-depth caption="The same fold with `up to .a` names the bottom layer as its depth; the moving set grows outward from there and both corners fold, valley on the face-up layer and mountain on the face-down one." views="cp folded" highlight="--f"}
paper square
fold map .b onto .a
.p = free on --bc from .b at 1/4
.q = free on --ab from .b at 1/4
fold --f = through .p .q moving .b up to .a
:::

::: {.corollary #cor-fold-letters name="letters of an outside fold" uses="def-fold def-letter def-reflection"}
For a fold placed *top*, every hinge it scores reads valley where the face
was face up before the fold and mountain where it was face down; for a fold
placed *bottom* the other way round.

*Proof.* Let $F \in M$ and let $G$ be the stationary face across the new
hinge; before the fold both had the same isometry. After it, $F$ is
reflected and $G$ is not, so exactly one is face up. For *top*, $F$ lies
above $G$. If $G$ is face up, the face-up face is below: valley. If $G$ is
face down, $F$ is face up and above: mountain. For *bottom*, exchange above
and below. $\square$
:::

A placed fold has no such rule. Its letter is read off the finished state
and depends on the layer the block is inserted against: tucking a corner
under a face-down layer reads valley, under a face-up layer mountain.

::: {.figure #fig-fold-tuck caption="A pocket tuck: after the sheet is folded in half, the corner `.b` of the top layer is folded `under .p`, into the gap between the two layers. The crease `--t` reads valley because the layer it tucks under lies face down." views="cp folded" highlight="--t"}
paper square
fold map .a onto .d
.m = free on --bc from .b at 1/2
.n = free on --ab from .b at 1/2
.p = free on --ab from .a at 1/4
fold --t = through .m .n moving .b under .p
:::

::: {.remark #rem-simple-fold name="simple folds" uses="def-fold lem-noncrossing-adequate"}
A fold placed *top* or *bottom* is a some-layers simple fold in Demaine's
sense: a rigid rotation of some layers under the crease segment through
$\pi$, avoiding self-intersection throughout [@demaine2007, §14.1]. Outward
closure is the condition that rotation imposes at the crease: a stationary
layer outside a moving one would be swept through. The model checks the end
state and never the motion; that a non-crossing end state of an
outward-closed block is reached by a rigid rotation is not claimed here. A
fold placed *over* or *under* is no simple fold, since the block passes
between layers that open for it. The model accepts it whenever the end state
is a state, which by [#lem-noncrossing-adequate] means whenever the end
state can be reached by some folding motion.
:::

::: {.lemma #lem-fold-closed name="an outward-closed fold crosses nothing" uses="def-fold def-reflection def-noncrossing cond-hinge-closure"}
Let $M$ be the moving set of a fold placed *top* or *bottom*. If the
reflection of $(M, \pi)$ satisfies the hinge closure condition, it satisfies
the order, taco-tortilla and taco-taco conditions as well.

*Proof.* Pending. The order condition holds because the relation on
stationary pairs is unchanged, the relation on moving pairs is reversed, and
every moving face lies outside every stationary face it overlaps. The two
taco conditions need the case analysis at a crease image: a new taco on
$\ell$ has its moving side outside its stationary side, and an old taco or
tortilla lies wholly in $M$ or wholly outside it by outward closure and
cohesion.
:::

::: {.definition #def-flip name="flip" uses="def-write def-flat-state def-noncrossing"}
The write `flip` takes no argument. For a state $(f, \lambda)$ and a fixed
reflection $\rho$ of the table its value is $(\rho \circ f, \lambda^{op})$,
where $\lambda^{op}$ exchanges above and below on every overlapping pair. It
is defined on every state.
:::

::: {.lemma #lem-flip name="flip preserves everything but the side" uses="def-flip def-letter def-noncrossing"}
The value of `flip` is a state. Every hinge keeps its angle and every folded
hinge keeps its letter; every face changes between face up and face down.

*Proof.* The order, taco-tortilla and taco-taco conditions are stated
symmetrically in above and below, so $\lambda^{op}$ satisfies them when
$\lambda$ does. For a hinge between $A$ and $B$ with $f|_B = f|_A \circ r$,
also $\rho \circ f|_B = \rho \circ f|_A \circ r$, so hinge closure and the
angles are unchanged; connectivity does not involve $f$. Composing with
$\rho$ reverses the orientation of every face, so the face-up face of a
folded hinge becomes the face-down one, and $\lambda^{op}$ puts it on the
other side: the letter is unchanged. $\square$
:::

Which reflection $\rho$ is used is immaterial for the state up to a motion of
the table, and it is visible to line values, which are table lines
([#open-line-after-fold]).

::: {.figure #fig-flip caption="After `flip` the sheet lies face down, so the crease `--g` scored by a fold placed on top reads mountain: the folder turned the paper over and made a valley on its back." views="cp folded" highlight="--g"}
paper square
flip
fold --g = map .a onto .c
:::

::: {.definition #def-reverse name="reverse fold" uses="def-write def-reflection def-fold def-flap def-letter" defines="term-tip term-spine term-body"}
The write `reverse` takes a table line $\ell$, a side $H$, an anchor flap
$\alpha$ with material in $H$, and a kind, *inside* or *outside*. Score
$\ell$ and call the faces in $H$ the candidates. The *tip* $T$ is the least
set of candidates that contains the faces of $\alpha$ in $H$ and is closed
under hinges of any angle between candidates. A *spine* is a folded hinge
between two faces of $T$ whose removal from the hinge graph of $T$ leaves
exactly two connected components, the *halves* $T_1$ and $T_2$. The *body*
$B_i$ of a half is the set of stationary faces joined to a face of $T_i$ by
a hinge on $\ell$. The spine is admissible when both bodies are non-empty
and separated: every face of $B_1$ lies below every face of $B_2$ it
overlaps, after renaming so that $B_1$ is the lower body. The value of the
write is the reflection of the two blocks
$(T_1, \text{over } B_1)$ and $(T_2, \text{under } B_2)$ for *inside*, and
$(T_1, \text{bottom})$ and $(T_2, \text{top})$ for *outside*. It is defined
when exactly one admissible spine yields a state.
:::

::: {.term #term-tip name="tip, half"}
The material beyond the axis of a reverse fold that is joined to the anchor;
the spine cuts it into two halves.
:::

::: {.term #term-spine name="spine"}
The folded hinge of the tip along which the two halves lie on each other and
which the reverse fold turns the other way.
:::

::: {.term #term-body name="body"}
The stationary faces a half of the tip is hinged to along the axis.
:::

The two halves move in one reflection and never one after the other: once
one half has moved, the spine joins a reflected face to an unreflected one
along no common segment, and hinge closure fails. Inside, each half lands
next to its own body in the gap between the two bodies; outside, the lower
half goes under everything and the upper half on top.

::: {.figure #fig-reverse caption="The preliminary base by two inside reverse folds [@ida2020, §7.4.3]: the diagonal fold makes a triangle whose spine is `--bd`, and each acute corner is reversed to the right-angle corner in turn." views="cp folded" highlight="--h --v"}
paper square
fold --bd = map .a onto .c
reverse --h = map .b onto .c
reverse --v = map .d onto .c
:::

::: {.corollary #cor-reverse-letters name="letters of a reverse fold" uses="def-reverse def-letter cor-fold-letters def-reflection"}
The spine beyond the axis reverses its letter. The hinges the write scores
on $\ell$ read, on both halves, the letter the spine had before for an
*inside* reverse and the opposite letter for an *outside* reverse.

*Proof.* The spine joins a face $A$ of $T_1$ to a face $B$ of $T_2$. Both
are reflected, so the face-up one becomes face down and the other face up;
the two blocks keep their relative order, since $B_1$ lies below $B_2$ and
each half is placed at its own body. The face-up face of the spine has
therefore changed and its side has not: the letter reverses. A face of
$T_i$ is face up exactly when its body is, because they are joined by a
flat hinge before the fold, and the bodies have opposite orientations
because the spine continues between them as a folded hinge. Let the lower
body be face up; the spine is then a valley. Inside, $T_1$ lands above the
face-up $B_1$ and $T_2$ below the face-down $B_2$: by [#cor-fold-letters]
both new hinges are valleys. Outside, $T_1$ lands below the face-up $B_1$
and $T_2$ above the face-down $B_2$: both mountains. For a face-down lower
body exchange the letters. $\square$
:::

::: {.definition #def-flatten name="flatten" uses="def-write def-flap def-score def-reflection def-letter def-noncrossing def-motion" defines="term-fan term-sector term-stayer term-emergent"}
The write `flatten` takes a paper point $O$ interior to a flap $\Phi$, a
finite set of *rays*: segments from $O$ to the boundary of $\Phi$ in
pairwise distinct directions, a set of constraints, and a selection
$\sigma$. Let $\rho_1, \ldots, \rho_k$ be the reflections of the table
across the lines of the rays' images, in counter-clockwise order around
$f(O)$.

- If $k$ is even, the composition $\rho_1 \circ \cdots \circ \rho_k$ must be
  the identity; this is Kawasaki's condition that the alternating sum of the
  angles between consecutive rays vanishes [@hull2020, §5.3].
- If $k$ is odd, the composition is a reflection across a line through
  $f(O)$, since an odd number of reflections through a point reverses
  orientation and fixes the point. Each of the two rays of that line that
  lies strictly inside a gap between consecutive given rays is an *emergent*
  ray; adding it makes the composition close. Each choice is a candidate
  fan.

Call the $n$ rays of a candidate fan $r_1, \ldots, r_n$ and the parts of
$\Phi$ between consecutive rays the *sectors* $S_0, \ldots, S_{n-1}$, with
$S_i$ between $r_i$ and $r_{i+1}$. The *stayer* is one sector $S_0$, named
by the program or by its convention. Set $m_0 = \mathrm{id}$ and
$m_i = m_{i-1} \circ \rho_i$; Kawasaki's condition is $m_n = m_0$, so the
motions close around $O$. Let $R$ be the image of $\Phi$ and let $C$ be the
faces whose image meets $R$ in positive area, the layers under the fan.
Score every face of $C$ along the rays' half-lines from $f(O)$, so that each
piece lies in one wedge between consecutive rays. The map $f'$ is $m_i \circ
f$ on every piece in the wedge of $S_i$ and $f$ elsewhere. A *candidate
state* is a pair $(f', \lambda')$ with $\lambda'$ such that it satisfies
[#def-noncrossing] and the constraints:

- a letter for a ray: the hinge between the two sectors of $\Phi$ on that ray
  has that letter;
- one sector over another: the two sectors of $\Phi$ are so ordered;
- the stayer, which only fixes $m_0$ and so the table position.

The value of the write is the one candidate state $\sigma$ selects from the
set of all candidate states of all candidate fans; it is undefined when
that set is empty or $\sigma$ leaves more than one. The crease the write
scores is the bundle of the hinges on the given rays when $k$ is even and
the bundle of the hinges on the emergent ray when $k$ is odd.
:::

::: {.term #term-fan name="fan, ray"}
The segments from one vertex along which a flatten folds at once.
:::

::: {.term #term-sector name="sector"}
The part of the flap between two consecutive rays of a fan.
:::

::: {.term #term-stayer name="stayer"}
The sector of a flatten that keeps its isometry; it fixes where the result
lies on the table.
:::

::: {.term #term-emergent name="emergent ray"}
The ray a flatten with an odd number of given rays has to add for the vertex
to fold flat.
:::

The construction is the single-vertex fan of flat-folding theory: the
isometry of each sector is the composition of the reflections across the
rays between it and the stayer [@hull2020, chapter 5]. Kawasaki's theorem
says that the closure condition is exactly flat-foldability of the vertex,
and Maekawa's theorem, that the letters around $O$ differ in number by two,
holds in every candidate state because a candidate state is a flat folded
state [@hull2020, §5.2, §5.3]. Everything stacked over the fan moves with
its sector; where a layer under the fan is hinged to stationary paper off
the rays, hinge closure fails and the write is undefined, as for every
reflection.

::: {.figure #fig-flatten caption="The preliminary base by one flatten at the centre: six rays fold, the diagonal through `.a` and `.c` stays flat, and `(.q over .r)` puts the a-quarter in front of the b-taco." views="cp folded" highlight="--h --v"}
paper square
mark --ac = through .a .c
mark --bd = through .b .d
mark --h = map --ab onto --cd
mark --v = map --da onto --bc
.q = free on --ab from .a at 1/4
.r = free on --ab from .b at 1/4
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b) (--bd & .d) (.q over .r) {toward .q}
:::

::: {.open #open-flatten-selection name="what selects among the candidates of a flatten" uses="def-flatten def-motion"}
[#def-flatten] leaves $\sigma$ to the program, as [#def-motion] does for the
candidates of a construction. The language's `toward` is three rules in
sequence: the candidate whose moved material lies toward the named point,
among those the ones with the fewest mountains on the given rays, among
those the one whose material toward the point lies on top. The first is a
selection in the sense of [#def-motion]; the other two are conventions that
pick a folder's habit out of several states that are all flat folded. Whether
they belong in the model as named selections, or the language should ask for
a constraint instead when several states remain, is not decided.
:::

::: {.remark #rem-all-layers name="the two rules for the layers under a crease" uses="def-fold def-flatten"}
`fold` moves the outward closure of one flap and leaves the layers beneath
it; `flatten` moves every layer under its fan. The two rules answer the same
question, which layers under a crease move with it, and they answer it
differently. A flatten that moves only the layers outward of a stayer, or a
fold through every layer, are both expressible with the constructions above
and neither is a write of the language; the model has no reason to prefer
one rule, and the difference is a language decision.
:::

## 6. Programs

To be written: a program as a finite sequence of states.

::: {.open #open-several-sheets name="several sheets and bodies" uses="def-sheet def-flat-state def-noncrossing cond-connected"}
The language design for sheets as values
(`docs/superpowers/specs/2026-09-13-paper-as-value-design.md`) lets a program
hold several sheets and assemble them into a body. In the model a multi-sheet
program state is a family of flat folded states, one per sheet, and an
assembled body is a flat folded state of the disjoint union of its sheets: one
$f$ into one table, one $\lambda$ over the faces of all members, the
non-crossing conditions unchanged, and [#cond-connected] required per member
instead of overall. A tab inside a pocket is then $\lambda$ placing the tab's
faces between the pocket's, with the taco-tortilla condition keeping it out of
the pocket's fold. This covers flat assembly; a body that is not flat waits
for the non-flat state. Taking a body apart again is trivial in the model and
absent from the language, which should be stated as a choice.
:::

## Terms

Each entry gives the meaning in one line and points to the definition that
fixes it.

## References
