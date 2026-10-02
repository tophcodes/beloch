---
title: Model
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

**Review status.** Section 1 read and accepted. Section 2 rewritten on
review (2026-09-17): the state is a triple, $\lambda$ is a signed function
on ordered pairs, refinement has its lemma. Section 3 read and accepted for
now (2026-09-18); the primary source Justin 1997 is still missing. Section 4
rewritten on review (2026-09-18): every value is a set of paper points, the
line sort is gone in favor of the material of a table line and the line of
a straight bundle, and the former open point on a line value across states
is closed by that. Section 5 is a draft; it still writes states as pairs
$(f, \lambda)$ and takes lines rather than bundles as arguments.

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
The language design for sheets as values names the circle as a shape. A disc is no polygon and has no decomposition into finitely
many convex polygons, so [#def-sheet] and [#def-flat-state] exclude it as
written. The generalization is a sheet bounded by finitely many algebraic
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

::: {.definition #def-flat-state name="flat folded state" uses="def-sheet def-refinement def-noncrossing" defines="term-table term-face term-layer"}
Let $P$ be a sheet and let $T = \mathbb{R}^2$ be the [table](#term-table), a
plane with a chosen side called *up*. A flat folded state of $P$ is a triple
$(\mathcal{F}, f, \lambda)$, read up to the refinement equivalence of
[#def-refinement], where

1. $\mathcal{F}$ is a finite set of convex polygons, the faces, with pairwise
   disjoint interiors and $\bigcup \mathcal{F} = P$: the faces cover the sheet
   and overlap at most along their boundaries;
2. for every face $A$ there is a plane isometry $\phi_A$, a map
   $\mathbb{R}^2 \to \mathbb{R}^2$ that preserves distances (every such map is
   a composition of translations, rotations and reflections), such that
   $\phi_A(p) = \phi_B(p)$ for all $p \in A \cap B$, and $f : P \to T$ is the
   map with $f(p) = \phi_A(p)$ for $p \in A$. The agreement on shared
   boundaries makes $f$ well defined, and since the faces are finitely many
   closed sets, $f$ is continuous;
3. with $\Omega = \{(A, B) \in \mathcal{F} \times \mathcal{F} : A \neq B,\
   \operatorname{int} f(A) \cap \operatorname{int} f(B) \neq \emptyset\}$
   the set of ordered pairs of overlapping faces, $\lambda : \Omega \to
   \{+1, -1\}$ is a function with $\lambda(B, A) = -\lambda(A, B)$, and
   $\lambda(A, B) = +1$ reads as "$A$ lies above $B$": throughout their
   overlap, $A$ is on the up side of $B$;

and $\lambda$ satisfies the non-crossing conditions of [#def-noncrossing].
:::

Reading the notation: $\bigcup \mathcal{F}$ is the union of all faces;
$\operatorname{int} X$ is the interior of $X$, the set without its boundary,
and for convex polygons "the interiors meet" is the same as "the intersection
has positive area"; $\lambda : \Omega \to \{+1, -1\}$ names the function, its
domain and its set of values, in that order.

One value per pair of faces is enough because the overlap of two convex faces
is a single convex region that contains no crease of either face, and the
order of two uncreased regions is constant on their overlap [@demaine2007,
§11.4.4.3; @akitaya2016, §2, consistency]. The sign is Demaine's: $+1$
means above [@demaine2007, §11.4.4]; Akitaya et al. and Hull and Zakharevich
use the opposite sign [@akitaya2016, §2; @hullzakharevich2023, §2.1].

::: {.term #term-table name="table"}
The plane $T = \mathbb{R}^2$ a state is folded onto, the image of $f$, with a
chosen side called *up*. "Table frame" names its coordinate system; a point
of the sheet has one paper coordinate and, per state, one table coordinate.
:::

::: {.term #term-face name="face"}
A convex polygon $A$ of the decomposition $\mathcal{F}$, on which $f$ is the
single isometry $\phi_A$.
:::

::: {.term #term-layer name="layer, above, below"}
In a region of the table where several faces overlap, the faces are the
layers, and $\lambda$ says for each pair which is above: $\lambda(A, B) = +1$
puts $A$ above $B$.
:::

::: {.figure #fig-flat-state-layers caption="The preliminary base as a flat folded state, cut along `--s` across the diagonal, from `.e` to `.f`. Left, the folded state with the line, and arrows that show the side the section is seen from. Middle, the crease pattern with the paper the line crosses, each piece named by the face of the pattern it lies in and each folded hinge by the two pieces it joins, with `.e`, `.m` and `.f` where they are on the paper and a small circle wherever another layer lands on one of them. Right, the section with the stack pulled apart, the top layer first: each piece is a horizontal strip in its color, each folded hinge a turn from one strip into the next, each point a dashed line across the stack, and a dot on the layer it belongs to. The path is closed, since the line runs round the point of the base. Between `.m` and `.f` the layers are 1, 6, 5, 9, the quarters of `.a`, `.b`, `.b` and `.c`; between `.e` and `.m` they are 3, 8, 7, 10. The top and the bottom strip run flat across the diagonal at `.m`, from 3 into 1 and from 10 into 9, and the quarters of `.b` and `.d` are folded in half along it." views="side" along="--s" highlight="--s .e .m .f"}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b mountain) (--bd & .d)
.m = free on --bd from .b at 1/4
--s = (perp --bd through .m)
mark (--s) (on #[.a]) as --sm
.e = --sm * --h
.f = --sm * --v
:::

A segment of positive length shared by the boundaries of two faces $A$ and
$B$ is a [hinge](#term-hinge). Its angle is $0$ when $\phi_A = \phi_B$, so that
on the table the two faces continue each other without a bend; it is
$\pm\pi$ when $\phi_B = \phi_A \circ \rho_e$, where $\rho_e$ is the
reflection of the paper across the line through the segment $e$, so that on
the table the two faces lie on top of each other, joined along the edge. A
hinge of angle $0$ is a flat crease; a hinge of angle $\pm\pi$ is a folded
crease. That these are the only two cases is [#lem-hinge-cases].

::: {.lemma #lem-hinge-cases name="a hinge is flat or folded" uses="def-flat-state" defines="term-hinge"}
Let $A$ and $B$ be faces sharing a boundary segment $e$ of positive length.
Then either $\phi_A = \phi_B$, or $\phi_B = \phi_A \circ \rho_e$ with $\rho_e$
the reflection across the line through $e$.

*Proof.* The isometry $\psi = \phi_A^{-1} \circ \phi_B$ fixes every point of
$e$, since $\phi_A$ and $\phi_B$ agree there. An isometry that fixes two
distinct points $u$, $v$ fixes every point of the line through them, because
a point of that line is determined by its distances to $u$ and $v$. A point
$q$ off the line is sent to a point with the same distances to $u$ and $v$ as
$q$, and there are exactly two such points, $q$ and its mirror image across
the line. Hence $\psi$ is the identity or $\rho_e$, which is the claim.
:::

::: {.term #term-hinge name="hinge"}
A boundary segment of positive length shared by two faces, with an angle of
$0$ (flat crease) or $\pm\pi$ (folded crease).
:::

A state relates its faces in two ways, and each relation is a graph with the
faces as nodes. In the first, two faces are joined when they share a hinge;
it lives on the paper and says how the sheet hangs together. In the second,
two faces are joined when they overlap on the table, which is a pair
$(A, B) \in \Omega$ of [#def-flat-state], and $\lambda$ gives the edge its
direction, from the face above to the face below. The first is fixed by where
the creases run; the second is what the folding did with them.

::: {.figure #fig-face-graphs caption="The face graphs of the preliminary base folded by one collapse, the state of [#fig-flat-state-layers] before the line `--s` is marked. Left, adjacency on the paper: each face is a node inside its own polygon, numbered from 1, and each hinge a path from one face through the middle of the hinge into the other, red where the hinge is a mountain, blue where it is a valley and dashed where it is flat. The two flat hinges lie on the diagonal through `.a` and `.c`, which stays flat. Right, superposition, the top layer first: a face stands one row below the lowest face above it, and a line joins two faces only when no third face lies between them, since every other pair follows from those. The base lies in two stacks that do not overlap, 1, 4, 3, 7 and 2, 6, 5, 8, so twelve of the 28 pairs of faces overlap, and $\Omega$ holds each of them in both orders. A shaded node is a face that lies face down." views="faces"}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b mountain) (--bd & .d)
:::

::: {.example #ex-half-square name="a square folded in half" uses="def-flat-state lem-hinge-cases"}
Let $P$ be the unit square with corners `.a` $= (0, 0)$, `.b` $= (1, 0)$,
`.c` $= (1, 1)$, `.d` $= (0, 1)$; let $A$ be its left half, $B$ its right
half, and $h$ the segment they share on the line $x = \tfrac12$. Unfolded,
$\phi_A = \phi_B = \mathrm{id}$ and the hinge is flat. Fold the right half
onto the left, in Beloch `fold (map .b onto .a)`: $A$ stays, so
$\phi_A = \mathrm{id}$, and $B$ is mirrored across the hinge, so
$\phi_B(x, y) = (1 - x, y)$, which is $\rho_h$; the corner `.b` lands on
`.a`. Now turn the folded square on the table by a rotation $R$: $\phi_A = R$
and $\phi_B = R \circ \rho_h$. The relation $\phi_B = \phi_A \circ \rho_h$
says nothing about where $A$ lies. It says how $B$ lies relative to $A$:
displaced by the flip across the hinge, wherever $A$ went. Read $\circ$ from
the right: mirror $B$ across $h$ in the paper, which puts it on $A$'s paper
position, then move it the way $A$ is moved.
:::

::: {.figure #fig-half-square caption="The square of [#ex-half-square]: on the paper `.b` is the right corner, on the table it lies on `.a`, and the crease `--h` is the hinge between the two faces." views="cp folded" highlight=".b --h" program="shown"}
paper square
fold (map .b onto .a) as --h
:::

::: {.remark #rem-fold-and-hinge name="folds and hinges are one reflection seen twice" uses="def-flat-state lem-hinge-cases"}
The hinge relation composes the reflection on the paper side of $\phi_A$.
The fold operation of §5 composes on the table side: a fold along a table
line $\ell$ replaces $\phi_F$ by $\rho_\ell \circ \phi_F$ on every moving face
$F$, so a state reached by folding has $\phi_F = \rho_n \circ \dots \circ
\rho_1$, the reflections that moved $F$, in order. The two views agree
because reflecting across the table image of $h$ is the paper reflection
carried over by $\phi_A$: $\rho_{f(h)} = \phi_A \circ \rho_h \circ
\phi_A^{-1}$, hence $\rho_{f(h)} \circ \phi_A = \phi_A \circ \rho_h$. A
folded hinge between $A$ and $B$ is therefore the same as "$B$ is $A$
reflected across the table line $f(h)$". A state still records no history:
$\phi_F$ is the net motion, and the relation holds for every hinge whether or
not the state was reached by folding.
:::

::: {.definition #def-refinement name="refinement equivalence" uses="def-flat-state" defines="term-refinement"}
A split of a state $(\mathcal{F}, f, \lambda)$ replaces one face $A$ by two
convex faces $A_1$, $A_2$ with $A_1 \cup A_2 = A$ and disjoint interiors, sets
$\phi_{A_1} = \phi_{A_2} = \phi_A$, and sets $\lambda(A_i, B) = \lambda(A, B)$
for every face $B$ with $(A_i, B) \in \Omega$; $f$ is unchanged. A refinement
of a state is the result of finitely many splits. Two states are the same
state when they have a common refinement.
:::

::: {.lemma #lem-refinement-overlay name="refinements have a common refinement" uses="def-refinement"}
Two refinements of one state have a common refinement. Consequently "having a
common refinement" is an equivalence relation on states, and "the same
state" in [#def-refinement] is well defined.

*Proof.* Let $\mathcal{F}_1$ and $\mathcal{F}_2$ be the face sets of two
refinements of $(\mathcal{F}, f, \lambda)$. The overlay
$\{A_1 \cap A_2 : A_1 \in \mathcal{F}_1, A_2 \in \mathcal{F}_2\}$, with the
pieces of empty interior dropped, consists of convex polygons with disjoint
interiors covering $P$, since the intersection of two convex polygons is a
convex polygon. Each piece $A_1 \cap A_2$ arises from $A_1$ by cutting along
the lines through the edges of $A_2$, one at a time, and each cut is a split.
The overlay therefore refines $\mathcal{F}_1$, and by the same argument
$\mathcal{F}_2$. The isometries and the values of $\lambda$ on the overlay
are inherited from $\mathcal{F}$ through either side and agree, because both
sides copied them from the same faces of $\mathcal{F}$. Reflexivity and
symmetry of the relation are immediate; for transitivity, if $S_1$, $S_2$
share a refinement $R_{12}$ and $S_2$, $S_3$ share $R_{23}$, then $R_{12}$ and
$R_{23}$ are refinements of $S_2$, their common refinement refines $S_1$ and
$S_3$, and splits compose.
:::

::: {.term #term-refinement name="refinement"}
Splitting faces along flat hinges, finitely often; states with a common
refinement are the same state.
:::

::: {.definition #def-flap name="flap" uses="def-flat-state def-refinement" defines="term-flap"}
A *flap* of a state is a maximal set of faces in which any two are joined by
a chain of hinges of angle $0$. Flaps partition the faces, and they are the
pieces of paper that lie flat as one: neighboring faces of angle $0$ share
their isometry, so on the union of a flap's faces $f$ is one isometry. A
split of [#def-refinement] adds a hinge of angle $0$ inside a face, so flaps
are invariant under refinement, which is why the language addresses flaps
and never faces.
:::

::: {.figure #fig-flap caption="The fold leaves two flaps; the marked crease `--s` runs through the highlighted one and splits it into two faces, which stay one flap because the hinge between them has angle $0$." views="cp" highlight="#[.c] --s"}
paper square
.m = free on --cd from .c at 1/4
fold (map .a onto .b)
mark (through .b .m) (on #[.c]) as --s
:::

::: {.term #term-flap name="flap"}
A maximal set of faces joined by hinges of angle $0$; a piece of paper that
lies flat as one, and the unit a program addresses.
:::

Three things follow from [#def-refinement]. Which convex decomposition a
state carries does not matter: two decompositions of the same folding have a
common refinement, so they are the same state. A `mark` (§5) splits a face
along a flat hinge and nothing else, so it leaves the state unchanged. And
when two programs are said to reach the same folded state, this is the
equality meant: the two routes cut the sheet differently, and they agree up
to refinement.

::: {.remark #rem-linear-extension name="linear extensions" uses="def-flat-state"}
The relation "$A$ above $B$", that is $\lambda(A, B) = +1$, is a partial
order: it relates overlapping faces only. A total order
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

## 3. Non-crossing conditions

Intuition: $\lambda$ says which of two overlapping faces is on top. Not every
such assignment describes a sheet of paper. A face cannot pass through
another face, it cannot pass through a fold, and two folds cannot thread
through each other. This section states the conditions that rule those out,
one at a time, and then defines a non-crossing layer ordering as one that
satisfies them all. They are the non-crossing conditions of Akitaya et al. [@akitaya2016, §2],
as Hull and Zakharevich restate them [@hullzakharevich2023, §2.1], stated
here for faces instead of points, plus two conditions that a decomposition into faces has to satisfy to
be one sheet.

Three of the six properties in the literature need no condition here.
Existence says that $\lambda$ is defined exactly on overlapping pairs, and
antisymmetry says that reversing a pair reverses the value; both are part of
[#def-flat-state]. Tortilla-tortilla says that two uncreased regions which
fully overlap are ordered as wholes; [#def-flat-state] takes one value per
pair of faces, and the paragraph after it says why that is legitimate.

::: {.condition #cond-order name="order condition" uses="def-flat-state"}
For faces $A$, $B$, $C$ whose images share a region of positive area: if $A$
is above $B$ and $B$ is above $C$, then $A$ is above $C$.
:::

The next two conditions speak about folded hinges. Let $h$ be a folded hinge
between faces $A$ and $B$. Since $\phi_B = \phi_A \circ \rho_h$, the fold lays
$B$ onto $A$: near $f(h)$ the images $f(A)$ and $f(B)$ cover the same region
of the table, one on the other, joined along $f(h)$ and separate everywhere
else. The pair is a [taco](#term-taco): closed along the fold, open away from
it.

::: {.term #term-taco name="taco"}
Two faces joined by a folded hinge, seen near the hinge: closed along the
hinge, open away from it.
:::

::: {.term #term-tortilla name="tortilla"}
A face whose image covers a neighborhood of a point of a folded hinge's
image without that hinge being its own edge.
:::

::: {.condition #cond-taco-tortilla name="taco-tortilla condition" uses="def-flat-state cond-order" defines="term-taco term-tortilla"}
Let $A$ and $B$ be joined by a folded hinge $h$, and let $C$ be a face whose
image contains a neighborhood of an interior point of $f(h)$, so that $C$
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
For every hinge between faces $A$ and $B$, the isometries $\phi_A$ and
$\phi_B$ agree on the shared segment, and by [#lem-hinge-cases] $\phi_B$ is
then $\phi_A$ either unchanged or composed with the reflection across the
segment's line. Equivalently every
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
$f$ and $\lambda$ alone: nothing about a state's physical realizability is
left outside the definition.

The last statement of this section connects the ordering on faces to the
ordering on points that the literature defines. It stands here rather than
in §2 because its proof needs the conditions above.

::: {.lemma #lem-face-points name="face and point orderings agree" uses="def-flat-state def-noncrossing"}
Let $(\mathcal{F}, f, \lambda)$ be a flat folded state in the sense of
[#def-flat-state], and let $\lambda'$ be the layer ordering on points that
Demaine [@demaine2007, §11.4] and Akitaya et al. [@akitaya2016, §2] define.
Setting $\lambda'(p, q) = \lambda(A_p, A_q)$ for points $p, q$ interior to
faces $A_p, A_q$ with $f(p) = f(q)$ yields a global layer ordering in
Demaine's sense, and $-\lambda(A_p, A_q)$ one in Akitaya's, whose sign is
opposite; every such ordering arises this way from exactly one $\lambda$ up
to refinement.

*Proof.* Pending. The forward direction needs the non-crossing conditions of
[#def-noncrossing]; the backward direction uses that the crease pattern of a
flat folding is a straight-line graph, so its regions refine to convex faces,
and that faces are uncreased regions, so $\lambda'$ is constant on pairs of
faces by the consistency property.
:::

Sources: the six properties on points and their names [@akitaya2016, §2],
with Figure 1 of Hull and Zakharevich showing the two crossing patterns
[@hullzakharevich2023, §2.1]; Justin's three conditions in Hull's
statement [@hull2020, sec. 6.5, p. 123].

## 4. Values and reads

Intuition: a program names things on the paper, points, straight pieces of
paper, and pieces that lie flat as one, and asks questions about them: where
is this point now, which fold carries this onto that, which piece of paper
holds this point. Values are the answers, and a read is the act of asking. A
read looks at the current state and computes a value; it changes nothing. If
the state has no answer, the read fails, and the program stops there.

Every value is a set of paper points, and a state says where those points
lie on the table. A fold therefore moves every value with the paper, and no value
has to be told about it. Values come in three sorts: point, bundle and flap.

::: {.definition #def-point name="point value" uses="def-sheet def-flat-state" defines="term-point"}
A value of sort *point* is a paper point $p \in P$. In a state
$(\mathcal{F}, f, \lambda)$ its position on the table is $f(p)$. A point
keeps its paper coordinate through every later state; only $f(p)$ changes.
:::

::: {.figure #fig-point caption="`.p` keeps the paper coordinate it was named with, and the fold moves only where it sits on the table." views="cp folded" highlight=".p"}
paper square
.p = free on --ab from .a at 1/4
fold (map .a onto .c)
:::

::: {.term #term-point name="point"}
A paper point, named once and carried in paper coordinates; its table
position depends on the state.
:::

::: {.definition #def-segment name="segment" uses="def-sheet def-flat-state def-flap" defines="term-segment"}
A *segment* of a state is a closed straight piece of the sheet of positive
length, $\{p + t(q - p) : 0 \le t \le 1\}$ for paper points $p \neq q$, on
which $f$ is an isometry, so that its table image is a straight segment of
the same length. Equivalently the piece lies within one flap ([#def-flap]):
faces are closed, so a piece along a hinge lies in the faces on both sides,
and $f$ is an isometry on it either way. A straight piece that crosses a
folded hinge is not a segment, since its image is bent. Segments are not
values; they are what bundles are made of.
:::

::: {.figure #fig-segment caption="`--s` meets each of the two flaps in a segment, and the crease `--h` is a segment along the hinge where the flaps join." views="cp folded" highlight="--s --h"}
paper square
--s = (map .a onto .b)
fold (map .a onto .d) as --h
:::

::: {.term #term-segment name="segment"}
A straight piece of the sheet on which $f$ is an isometry, so within one
flap; carried in paper coordinates.
:::

::: {.definition #def-bundle name="bundle" uses="def-flat-state def-segment def-flap" defines="term-bundle term-piece"}
A value of sort *bundle* is a finite union of segments, a subset
$b \subseteq P$. Two bundles are equal when they are equal as sets: a bundle
does not remember the segments it was assembled from, so a refinement, which
splits segments along flat hinges, leaves every bundle as it is. The
*pieces* of a bundle in a state are its maximal segments, the connected
straight stretches within one flap each. Its table image is $f(b)$, one
straight segment per piece. A fold across a bundle leaves the bundle as it
is and splits a piece in two: the stretch across the new folded hinge is no
longer a segment, so each side is a piece of its own. Pieces are read off
the state; nothing subdivides a value.
:::

::: {.term #term-bundle name="bundle"}
A finite union of segments, a set of paper points; the material of a line,
or a crease.
:::

::: {.term #term-piece name="piece"}
A maximal segment of a bundle in a state; one straight stretch within one
flap.
:::

::: {.definition #def-material name="material of a table line" uses="def-flat-state def-bundle def-flap" defines="term-material"}
Let $\ell$ be a line in the table frame. The *material* of $\ell$ in a state
is the union of all segments whose table image lies on $\ell$: the paper
that $f$ sends onto $\ell$, isolated points aside. It is a bundle with one
piece per flap that $\ell$ crosses, because $f$ is an isometry on each flap
and the flaps are finitely many. A table line is what a construction
computes; the value a program holds is its material.
:::

::: {.figure #fig-line caption="The material of the table line `--l` is one piece per flap it crosses: on the paper the two lie on either side of the crease, on the table they land on the same stretch of `--l`." views="cp folded" highlight="--l"}
paper square
--l = (through .a .c)
fold (map .a onto .c)
:::

::: {.term #term-material name="material"}
The paper a table line crosses in a state: a bundle with one piece per flap.
:::

::: {.definition #def-line name="line of a bundle" uses="def-flat-state def-bundle def-material" defines="term-line term-straight"}
A bundle $b$ is *straight* in a state when it is non-empty and its table
image $f(b)$ lies on one table line. The *line of* $b$ is that line, a read
of the state defined exactly when $b$ is straight. Straightness belongs to
the state, not to the bundle: a bundle straight in one state is bent by a
fold across it and straight again when that fold is undone. The material of
the line of a straight bundle contains $b$ and may be larger, where other
flaps cross the same line.

A line is needed at two places only: as the axis of a write (§5), and as an
argument of an alignment ([#def-alignment]). Both take a bundle and use its
line, so a line off the paper never arises, and a bundle that is not
straight cannot serve. Nothing in the language holds a table line across
states: `--l = (map .a onto .b)`, then a fold, then `mark (--l)` scores the
pieces of `--l` where they lie after the fold, bent or not.
:::

::: {.term #term-line name="line"}
The table line a straight bundle lies on; a read defined exactly when the
bundle is straight.
:::

::: {.term #term-straight name="straight"}
A bundle whose table image lies on one table line in the current state.
:::

::: {.definition #def-crease name="crease" uses="def-bundle def-line def-material" defines="term-crease"}
A *crease* is a bundle that a write of §5 scored, under a name or not. Its
hinges in a state are the hinges of the state that lie in it. A write scores
the material of a line, so a crease is straight when scored; a later fold
across it bends it, and it stays the same bundle.
:::

::: {.figure #fig-bundle caption="The crease `--m` is straight when marked; the fold that follows bends it: on the table its two pieces meet at a right angle, and `--m` is the same bundle of paper." views="cp folded" highlight="--m"}
paper square
mark (map --ab onto --cd) as --m
fold (map .a onto .c)
:::

::: {.term #term-crease name="crease"}
A bundle that a write scored; its hinges in a state are those of the state
that lie in it.
:::

::: {.definition #def-read name="read" uses="def-flat-state def-point def-bundle def-flap" defines="term-read"}
Write $S$ for the set of flat folded states of the sheet. A read of sort $V$,
with $V$ one of point, bundle and flap, is a partial function
$r : S \times A \rightharpoonup V$, where $A$ is a tuple of values of these
sorts, the arguments. A read has no effect on the state. Where it is
undefined the program fails with a reason.
:::

::: {.term #term-read name="read"}
A partial function from the current state and some values to a value; it
never changes the state.
:::

The reads of the language fall into three families; the line of a bundle
([#def-line]) is a fourth read that the others use.

::: {.definition #def-alignment name="alignment" uses="def-flat-state def-point def-line" defines="term-alignment"}
An *alignment* is an incidence on the table between two objects, each the
table position of a point, the line of a bundle, or the image of one of
these under the reflection across the line sought: a point onto a point, a
point onto a line, a line onto a line, the line through a point, the line
perpendicular to a line.
:::

::: {.term #term-alignment name="alignment"}
An incidence on the table that the line sought has to satisfy, with one side
of it reflected across that line.
:::

::: {.definition #def-selection name="selection" uses="def-read def-alignment def-bundle def-material def-line def-crease def-mark def-flap" defines="term-selection term-folding-side"}
Let $\ell$ be a table line, $\rho_\ell$ the reflection across it, and
$H^+_\ell$, $H^-_\ell$ its two open half-planes. An alignment `x onto y` of
a construction is an incidence ([#def-alignment]): $\rho_\ell(x)$ lies on
$y$, equivalently $\rho_\ell(y)$ passes through $x$, so `x onto y` and
`y onto x` are one alignment. Its objects are points, as their table
positions, and lines. A line is the bundle the program holds under its name
([#def-bundle]), and every read of its paper below takes that bundle, as a
finite set of table segments: a crease's scored segments
([#def-crease]), a mark's extent in the flaps it was marked on
([#def-mark]), and for a construction, a name bound to one and a paper
edge, all the paper on their line ([#def-material]). The line of the bundle
([#def-line]) is the object of the incidence.

A point $t$ *names the side* of $\ell$ that holds it, and names none when
$t \in \ell$. A set of segments $T$ names the side that holds
$T \setminus \ell$, and names none when $T \setminus \ell$ is empty or meets
both sides. A line names the side its bundle names: none when $\ell$
crosses the bundle or contains it. A mark that ends short of $\ell$ names
the side it lies on, though $\ell$ crosses its line on the paper.

A fold along $\ell$ with *folding side* $H$, one of $H^\pm_\ell$, *carries
out* an alignment `x onto y` when one of three holds: $x$ lies in $H$ and
lands on $y$; $y$ lies in $H$ and lands on $x$; or $x$ is a point on $\ell$
and on the line $y$. For a point that lands on a point this means lying
in $H$; for a point $p$ that lands on a line, lying in $H$ with
$\rho_\ell(p)$ in the material of the line's table line ([#def-material]),
which the line's bundle need not reach; for a line that lands on a line,
having part of its bundle in $H$; for a line that lands on a point $q$,
having its bundle at $\rho_\ell(q)$ in $H$. Whoever moves lands on the
paper of the other object, and a line that moves lands only with its
bundle: a mark carries out an alignment only where marked paper lands. The fold carries out a
construction when it carries out each of its `onto` alignments. The
*landing* of an object is the image under $\rho_\ell$ of its part in
$\overline{H}$, where $\overline{H}$ adds $\ell$ to $H$: a point in $H$, and
the bundle of a line in $\overline{H}$. The part of a line on the other
side stays where it is.

A *selection* $\sigma$ is the read that keeps one line of the candidates
$C$ of a construction ([#def-construction]), from the items a program
states: a line $g$ as `heading`, a point or a line $\tau$ as `toward`,
optionally with one object $x$ of the alignments as its subject, and a flap
$m$ as `moving`, which names the side of its first anchor point off $\ell$,
or of the bundle of a line. It runs four stages.

1. *Direction.* With `heading`, only the $\ell \in C$ whose angle with $g$ is
   least remain; a tie leaves all of them to the later stages.
2. *Folding side.* With `toward`, the folding side of $\ell$ is the side
   opposite the one $\tau$ names, undefined where $\tau$ names none; with
   `moving` too, $m$ has to name that side, or the folding side is
   undefined. With `moving` alone, it is the side $m$ names. With neither,
   it is *open*.
3. *Moved material.* Only the $\ell$ remain whose folding side is defined and
   whose fold with it carries out the construction, or whose folding side
   is open and for which a fold with either side does. A remaining line with an open folding side
   takes the side that alone carries the construction out, or, where both
   do, the side of the first object of the first alignment as the program
   writes it; that default belongs to the write ([#def-fold]). Where that
   object names no side either, the write has no default and needs
   `toward` or `moving`.
4. *Landing.* With a subject $x$, only the $\ell$ remain whose fold gives
   $x$ a landing, however many remain; the others would have nothing of $x$
   to measure. With `toward`, among several remaining lines only those
   remain whose landing lies nearest $\tau$, measured by the distance
   between sets, $d(A, B) = \min_{a \in A, b \in B} |a - b|$: the landing
   of $x$ with a subject, the union of the landings of all objects without.

$\sigma$ is defined when exactly one line remains; its value is that line,
and its folding side is the side a fold along it moves. A construction that
determines one line by its alignments has $|C| = 1$ and takes no `heading`;
`toward` and `moving` still pass it through stages 2 and 3.
:::

::: {.term #term-selection name="selection"}
The read that keeps one line out of the candidates of a construction: by
direction with `heading`, by the side that folds over with `toward` or
`moving`, by whether that fold carries out every alignment, and by where it
lands the objects of the alignments.
:::

::: {.term #term-folding-side name="folding side"}
The side of a candidate line that a fold along it moves: the one opposite
`toward`, the one `moving` names, or with neither the side that carries
the construction out.
:::

::: {.definition #def-construction name="construction" uses="def-read def-alignment def-selection def-line def-material" defines="term-construction term-candidate"}
A *construction* is a read of sort bundle, written as a finite set of
alignments on one sought line: finitely many solutions, and no alignment
redundant [@alperin2006, §2, Definition 8]. A construction determines no
line on its own. Its *candidates* $c(s, a)$ in a state $s$ with arguments
$a$ are the table lines satisfying every alignment, less those whose
material in $s$ is empty, since a line off the paper is no fold; there are
finitely many and there is usually more than one. A line is reached only
through a selection, and the value of the construction is
$$ r(s, a) = \text{the material of } \ell \quad \text{when } \sigma(s, a, c(s, a)) = \{\ell\}, $$
undefined otherwise, where $\sigma$ is the selection ([#def-selection]) the
program stated. The seven Huzita-Justin axioms are all the constructions on
one sought line [@alperin2006, §2].
:::

::: {.term #term-construction name="construction"}
A read of sort bundle: a finite set of alignments on one sought line, whose
candidates a selection narrows to the one whose material is the value.
:::

::: {.term #term-candidate name="candidate"}
A table line that satisfies every alignment of a construction in a state and
crosses paper; a line off the paper is none.
:::

::: {.figure #fig-candidates caption="`map .d onto --ef through .a` has two candidates, the two tangents from `.a` to the parabola with focus `.d` and directrix `--ef`. Both cross the paper, so no line is reached until the program selects one; with `toward .c` the steep one remains, the start of the largest equilateral triangle in the square [@ida2020, §2.2.3, Fig. 2.17]." views="candidates" at="choose"}
paper square
mark (map .a onto .b) as --ef
@label choose
fold (map .d onto --ef through .a) as --s
:::

::: {.figure #fig-toward-boundary caption="`map .d onto --ef through .p`, with `.p` a quarter of the way along `--bd` from `.d`: `.d` lands at the center under one candidate and on the top edge under the other. `toward` keeps the candidate whose landing lies nearer, so the points as near to both landings, dotted, cut the paper in two, and each panel shades the part where a `toward` point selects its candidate. `.c` lies above the line; a point on it selects nothing." views="candidates" at="choose"}
paper square
mark (map .a onto .b) as --ef
mark (through .b .d) as --bd
.p = free on --bd from .d at 1/4
@label choose
fold (map .d onto --ef through .p) (.d toward .c) as --s
:::

::: {.figure #fig-toward-stages caption="The program of [#fig-toward-boundary], one row per stage of [#def-selection]; the fold names no heading, so stage 1 is skipped. Both candidates cross the paper and both keep the side of `.c`, so the side that folds over carries `.d`, and each fold carries `.d` onto `--ef`. The landing stage decides: `.d` lands on the top edge under one candidate and at the center under the other, and the top edge lies nearer `.c`." views="stages" at="choose"}
paper square
mark (map .a onto .b) as --ef
mark (through .b .d) as --bd
.p = free on --bd from .d at 1/4
@label choose
fold (map .d onto --ef through .p) (.d toward .c) as --s
:::

::: {.lemma #lem-selection-defined name="a selection is a partial function" uses="def-selection def-construction"}
For every state, arguments and items, each stage of [#def-selection] is
determined, and $\sigma$ is a partial function of the state, the arguments
and the items. The line it keeps does not depend on the order in which the
construction lists its alignments; the default folding side of stage 3,
and with it whether a write without side items can take a side, does.

*Proof.* The candidates are finitely many ([#def-construction]), so every
stage filters a finite set. Stage 1 compares angles between lines, a
function of the lines alone. In stage 2, a point either lies on $\ell$ or
in exactly one of $H^\pm_\ell$, since the open half-planes and $\ell$
partition the plane, so the side a point names is determined or undefined.
The bundle of a line is a finite union of segments ([#def-bundle]);
$T \setminus \ell$ is empty, or lies in one half-plane, or meets both, and
these three cases are exclusive, so the side a line names is determined or
undefined, never two. The side `moving` names is that of one point, its
first anchor point off $\ell$, or of a line. Stage 3 tests, for finitely
many points and segments, membership in a half-plane and incidence of a
reflected point with a segment. In stage 4, whether the landing of $x$ is
empty is again a test of half-planes, and a landing is a finite union of
points and segments, each compact, and so is $\tau$; the distance between
two non-empty compact sets is attained, so the minimum over the finitely
many remaining lines exists. A line with an empty landing is not compared.
Stages 1 to 4 read the alignments as a set of incidences and the landings
as a union, and none reads their order; only the default folding side
reads the first object. $\sigma$ keeps one line or none, so it is a
partial function.
:::

In the kernel the comparisons are exact: squared distances between points
and segments, and squared cosines between lines, are rational functions of
the coordinates, so they stay in the field the coordinates lie in.

::: {.lemma #lem-selection-carries-out name="a remaining line carries out its alignments" uses="def-selection def-alignment"}
Let $\ell$ remain after stage 3 of [#def-selection] with folding side $H$.
Reflecting the paper in $H$ across $\ell$ and leaving the rest in place
makes every `onto` alignment of the construction hold as an incidence of
the table positions. Conversely, an alignment whose two objects both lie
outside $\overline{H}$ holds after the fold exactly when it held before.

*Proof.* $\ell$ is a candidate, so it satisfies each alignment
`x onto y` ([#def-alignment]): $\rho_\ell(x)$ lies on $y$, and since
$\rho_\ell$ is an involution, $\rho_\ell(y)$ passes through $x$. Stage 3
gives one of three cases for each alignment. If $x$ lies in $H$, what
lands of it lies on $y$: a point $x$ lands at $\rho_\ell(x)$ on $y$, on the
paper of its table line where $y$ is a line, and the
bundle of a line $x$ in $\overline{H}$ lands on the image of the line of
$x$, which is the line of $y$. If $y$ lies in $H$, the same holds with the
roles exchanged; where $y$ is a line and $x$ a point, stage 3 asks for
the bundle of $y$ at $\rho_\ell(x)$ in $H$, and that point lands on $x$. If
$x$ is a point on $\ell$ and on the line $y$, it stays and lies on $y$. A
point outside $\overline{H}$ is not reflected, so an alignment between two
such objects holds after the fold exactly when it did before.
:::

The lemma speaks about the half-plane $H$ on the table. Which layers on
$H$ a `fold` moves is its scope ([#def-fold]): every layer on $H$, or
where the write names a depth, the flap it names, what lies outward of it
and what is hinged to those off the axis. An object that lies in $H$ under a layer the scope
leaves behind stays behind with that layer.

::: {.lemma #lem-crossing-landing name="where a crossing line lands" uses="def-selection"}
Let a construction fold a line $m$ onto a line $n$, crossing at $X$, and
let the bundle of $m$ be one segment whose interior contains $X$, with
the parts $M_1$ and $M_2$ on either side of $X$. The candidates are the two
bisectors $b_1 \perp b_2$ through $X$, where both cross the paper, as they
do on the flat sheet when $X$ lies inside it, and `(m toward τ)` measures the
landing of $m$: under each bisector, the part that folds over lands on one
of the two rays of $n$ from $X$, as a segment from $X$ of the length of
that part. Let $v$ be the unit direction of $n$ such that the landing under
$b_1$ lies on $X + \mathbb{R}_{\ge 0}\, v$, let $\tau$ be a point on neither
bisector, $s$ the coordinate along $v$ of its foot on $n$, counted from
$X$, and $h$ its distance from $n$.

1. If the landing under $b_2$ lies on the opposite ray, $\tau$ is as near
   to one landing as to the other exactly when $s = 0$: $\tau$ lies on the
   perpendicular to $n$ through $X$.
2. If it lies on the same ray, with lengths $l_1 \le l_2$ of the two
   landings, $\tau$ is as near to one as to the other exactly when
   $l_1 = l_2$ or $s \le l_1$.

*Proof.* Every point of $m$ apart from $X$ lies on one side of each
bisector, so each bisector has paper of $m$ on both sides; stage 3
keeps both with any folding side, and $m$ has a landing under both. For
perpendicular lines through $X$, $\rho_{b_1} \circ \rho_{b_2} = R_X$, the
half-turn about $X$, so $\rho_{b_2} = \rho_{b_1} \circ R_X$. If
$\rho_{b_1}$ sends the ray of $M_1$ to the ray of $n$ in direction $v$, it
sends the ray of $M_2$ to $-v$, and $\rho_{b_2}$ sends $M_1$ to $-v$ and
$M_2$ to $v$. Each part is a segment from $X$, and a reflection keeps its
length.

The squared distance from $\tau$ to $X + [0, l]\,v$ is
$h^2 + \max(0, s - l)^2$ for $s \ge 0$ and $h^2 + s^2$ for $s < 0$, and to
$X - [0, l]\,v$ it is $h^2 + \max(0, -s - l)^2$ for $s \le 0$ and
$h^2 + s^2$ for $s > 0$. In case 1, with $s > 0$ the landing along $v$ is
at squared distance $h^2 + \max(0, s - l_1)^2 < h^2 + s^2$, the distance
to the one along $-v$, and $s < 0$ is the mirror case; the two agree at
$s = 0$. In case 2, for $s \le l_1$ both squared distances are
$h^2 + \min(0, s)^2$, equal; for $s > l_1$ the longer landing is strictly
nearer unless $l_1 = l_2$.
:::

For `--v` folded onto `--h` in the square, the figures of issue #58, both
parts of `--v` have length $\tfrac12$: with `(--v toward τ)` case 2 is a
tie at every point, and case 1 ties on `--v` itself. A bare `toward`
measures the landing of `--h` as well, which lands on the rays of `--v` by
the same argument with the roles of the two lines exchanged, and adds ties
of its own.

::: {.open #open-several-sought-lines name="constructions that seek more than one line" uses="def-construction def-alignment"}
[#def-construction] puts its alignments on one sought line, which is where
the seven Huzita-Justin axioms live. The same alignments distributed over two
lines sought at once give the 489 two-fold axioms [@alperin2006, §3, §4],
which `packages/multifold` (ADR 0020) enumerates. A candidate is then a pair
of lines, a selection keeps one pair, and a write takes two axes and moves
them together, so the definitions of candidate, selection and write all widen
by the same step. Which of them the language will carry, and whether a
two-fold write is one write or a pair, is not decided.
:::

::: {.definition #def-selector name="selector" uses="def-read def-flap def-point def-bundle def-meet"}
A *selector* is a read of sort flap or point that resolves a description by
incidence in paper coordinates: the flap whose faces contain every listed
point; the point where bundles meet ([#def-meet]); the point on a bundle of a
single piece at a given fraction of that piece's length from a named
endpoint. Each is defined exactly when the description picks out one thing.
:::

::: {.definition #def-meet name="meet" uses="def-read def-sheet def-bundle" defines="term-meet"}
Let $b_1, \dots, b_n$ be bundles, $n \ge 2$, where a side of the sheet
between two corners counts as the bundle of its points. Their *meet* is the
read of sort point
$$ m(s, b_1, \dots, b_n) = p \quad \text{when } b_1 \cap \dots \cap b_n = \{p\}, $$
undefined otherwise. The intersection is taken in the paper frame, so the
value does not depend on the state $s$: a fold changes where $p$ lies on the
table and never whether the bundles meet. A point of $b_1 \cap b_2$ lies on
both bundles in the same paper, so a layer that carries it carries both. A
bundle may lie on any number of paper lines, as a crease scored through
several layers does; only the number of common points counts. The meet is
undefined in three cases: the intersection is empty, it holds two or more
points, or it contains a segment, where the bundles share a stretch of paper.
:::

::: {.figure #fig-meet caption="`--h` and `--v` each lie on two paper lines after the reverse folds, a scar and its mirror image, and have one point in common, the center `.o`." views="cp folded" highlight="--h --v .o"}
paper square
fold (map .a onto .c) as --bd
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
.o = --h * --v
:::

::: {.term #term-meet name="meet"}
The one paper point that two or more bundles have in common; a read defined
exactly when their intersection is a single point.
:::

::: {.definition #def-filter name="filter" uses="def-read def-bundle def-line def-flap"}
The *filters* are the reads of sort bundle that form the Boolean algebra of
subsets of the pieces of a bundle $b$ generated by incidence predicates: for
a point $p$, a straight bundle $m$ or a flap $\phi$, the predicate "the
piece contains $p$", "the piece's table image meets the line of $m$", "the
piece lies in $\phi$". A filter keeps the pieces satisfying a predicate, its
complement drops them, and the union joins two bundles. Chaining filters is
intersection.
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

::: {.definition #def-effective name="effective write" uses="def-write def-score def-refinement" defines="term-effective"}
A write is *effective* in a state when its value is a different state in the
sense of [#def-refinement]. A score is exactly a write that is not effective:
by [#def-score] its value is the state it was given. A read is effective
nowhere, since it yields no state at all.
:::

::: {.term #term-effective name="effective"}
A write whose value is a different state; a score is not one, and a read is
no write.
:::

::: {.open #open-writes-on-the-quotient name="whether a write acts on the states read up to refinement" uses="def-effective def-refinement def-write"}
A write is stated here on a state, so *effective* is a property of a write at
a state. The stronger reading is that every write descends to the states read
up to refinement ([#def-refinement]): applied to two refinements of one
state, a write yields two states with a common refinement, so it induces a
map there, and a score induces the identity while an effective write does
not. The text argues the intuition for scoring below, that a write may score
every face its axis crosses because scoring changes nothing, and
`spec/KERNEL.md` records that the representation does not quotient. The
statement is not proved here, and nothing in the model rests on it.
:::

Every write below scores its axis first, so that each face lies on one side
of the axis before any face moves. Because scoring changes nothing, a write
may score every face the axis crosses, moving or not; the hinges that end up
between two stationary faces stay flat and vanish again under refinement.

::: {.definition #def-mark name="mark" uses="def-write def-score def-line def-flap def-bundle"}
The write `mark` takes a line $\ell$, a flap $\phi$ or none, and an extent:
the whole of $\ell$, a segment of $\ell$ between two points, or a point of
$\ell$. Its value is the state itself, up to refinement. Its effect is a
crease value. With $\phi$ it is the bundle of the material of $\ell$ in the
faces of $\phi$, clipped to the extent, and it is defined when that bundle
is non-empty and the extent lies in the image of $\phi$; an extent that
crosses a folded hinge of $\phi$ leaves the flap and is outside the domain.
Without $\phi$ it scores every layer under the extent: one piece per flap
whose image the extent meets, the material of $\ell$ in the faces of that
flap where its image lies under the extent. It is defined when there is at
least one piece.
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

The lemma is why an unfold needs no construction of its own: reflecting a
block back across a folded hinge returns that hinge to angle $0$, and the
crease is then a flat hinge that refinement forgets. What survives is the
crease value, which a later write can fold along again. The language offers
the write as `unfold` ([#def-unfold]).

::: {.definition #def-fold name="fold" uses="def-write def-reflection def-flap def-score def-line" defines="term-anchor term-depth"}
The write `fold` takes a table line $\ell$, a side $H$ of it, a *depth*
flap $\delta$ with material in $H$ or none, and a placement $\pi$. Score
$\ell$ and call the faces lying in $H$ the candidates. The moving set $M$
is the least set of candidates that contains the faces of $\delta$ in $H$,
or every candidate where there is no depth, and is closed under

- hinges off the axis: a candidate joined to a face of $M$ by a hinge,
  folded or flat, whose image does not lie on $\ell$ is in $M$, since the
  paper cannot tear there; with the flat hinges a flap moves as a whole
  ([#def-flap]); and,
- outward closure: a candidate that lies above a face of $M$ is in $M$ for
  *top*, and one that lies below a face of $M$ is in $M$ for *bottom*. For
  *under $T$* a candidate outside $T$ that lies above a face of $M$ and
  below every face of $T$ it overlaps is in $M$, and for *over $T$* one that
  lies below a face of $M$ and above every face of $T$ it overlaps. The
  faces of $T$ and the layers beyond them stay.

The value of the write is the reflection of the single block $(M, \pi)$. It
is defined when for *over $T$* and *under $T$* the set $T$ is the faces of a
stationary flap, and when the reflection is a state. The crease the write
scores is the bundle of the hinges of the result that lie on $\ell$ between
a face of $M$ and a stationary face.
:::

::: {.term #term-anchor name="anchor"}
The point or flap a fold names its side by: the side of the axis its image
lies on folds over. It names that side and nothing else.
:::

::: {.term #term-depth name="depth"}
The deepest flap a fold reaches where the program names one; the moving set
grows outward from it, up to the target of a placed fold. Without one, every
layer on the moving side moves.
:::

The language derives $H$ from the anchor: the point of a `moving` item, or
the object a construction moves, and the side its image lies on. A point on
the axis names no side, and a flap that straddles the axis without a point
names none either; both are outside the domain. `mountain` is the placement
*bottom* and the default is *top*; `up to` names $\delta$; `over` and
`under` name $T$. Without $\delta$ the moving set is every layer on $H$, as
a finger pressing a crease through the stack takes it. With $\delta$ it is
the flap $\delta$, the layers outward of it, and every layer joined to
those by a hinge off the axis, folded or flat: leaving such a layer behind
would tear the paper, so the closure takes it along. For a fold placed
`over` or `under` a flap, the layers outward of $\delta$ end at that flap:
the fold takes every layer between $\delta$ and the target, hinged to
$\delta$ or not, as a folder lifts the flap with what lies on it and slides
it in beside the target. The target and the layers beyond it stay. A line
with all of the paper on one side of it is outside the domain the language
gives `fold`: without $\delta$ every layer would move and no hinge would
change. `unfold` ([#def-unfold]) turns some of the layers over such a line.

::: {.figure #fig-fold-default caption="`--f` folds the corner through both layers: without `up to` the moving set is every layer on the side of `.b`. The crease reads valley on the face-up layer and mountain on the face-down one." views="cp folded" highlight="--f .b"}
paper square
fold (map .b onto .a)
.p = free on --bc from .b at 1/4
.q = free on --ab from .b at 1/4
fold (through .p .q) (moving .b) as --f
:::

::: {.figure #fig-fold-depth caption="The same fold given the top layer as its depth: the moving set grows outward from the flap carrying `.b`, and the layer beneath it stays. The crease reads mountain because that layer lies face down." views="cp folded" highlight="--f"}
paper square
fold (map .b onto .a)
.p = free on --bc from .b at 1/4
.q = free on --ab from .b at 1/4
fold (through .p .q) (moving .b) (up to .b) as --f
:::

::: {.figure #fig-fold-op caption="The terms of `--f` in [#fig-fold-depth] on the state it reads: the axis dashed and the moving set filled, the corner of the top layer alone. The layer beneath it is a candidate and stays, since the moving set grows outward from the depth. On the right the state after the fold." views="op" at="f"}
paper square
fold (map .b onto .a)
.p = free on --bc from .b at 1/4
.q = free on --ab from .b at 1/4
@label f
fold (through .p .q) (moving .b) (up to .b) as --f
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

::: {.figure #fig-fold-tuck caption="A pocket tuck: after the sheet is folded in half, the corner `.b` of the top layer is placed beneath `.p`, into the gap between the two layers. The crease `--t` reads valley because the layer it goes beneath lies face down." views="cp folded" highlight="--t .b"}
paper square
fold (map .a onto .d)
.m = free on --bc from .b at 1/2
.n = free on --ab from .b at 1/2
.p = free on --ab from .a at 1/4
fold (through .m .n) (moving .b) (up to .b) (under .p) as --t
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
the closure under hinges off the axis.
:::

::: {.definition #def-unfold name="unfold" uses="def-write def-fold def-reflection def-flap lem-toggle"}
The write `unfold` takes a table line $\ell$, a side $H$ of it, a placement
$\pi$ that is *top* or *bottom*, a depth flap $\delta$ or none, and a
staying flap $\sigma$ or none, at least one of the two given, each with
material in $H$. Score $\ell$ and call the faces lying in $H$ the
candidates. With $\delta$, the moving set $M$ is the moving set
[#def-fold] gives for $\ell$, $H$, $\delta$ and $\pi$. With $\sigma$ alone,
let $S$ be the least set of candidates that contains the faces of $\sigma$
in $H$ and is closed under the hinges off the axis and under inward closure:
a candidate that lies below a face of $S$ is in $S$ for *top*, one that lies
above a face of $S$ for *bottom*. Then $M$ is every candidate outside $S$.

The value of the write is the reflection of the single block $(M, \pi)$. It
is defined when $M$ contains no face of $\sigma$, when every hinge on $\ell$
between a face of $M$ and a stationary face is folded and at least one
exists, and when the reflection is a state.
:::

::: {.corollary #cor-unfold-opens name="an unfold opens and folds nothing" uses="def-unfold lem-toggle cond-hinge-closure"}
In the value of an unfold, every hinge on $\ell$ between a face of $M$ and a
stationary face has angle $0$, and every other hinge keeps its angle.

*Proof.* By [#lem-toggle] a hinge on $\ell$ between a moving and a
stationary face changes between $0$ and $\pm\pi$, and the domain asks each
of them to be folded, so each becomes flat. A hinge between two moving or
two stationary faces keeps its angle by the same lemma. A hinge off $\ell$
between a moving and a stationary face fails hinge closure
([#cond-hinge-closure]), so the reflection is no state there. $\square$
:::

The language takes the side $H$ from the point of the `moving` item, else
from the flap `up to` names, else from the point of the `toward` item; `up
to` names $\delta$, else `moving` does, and `toward` names $\sigma$.
`(moving … down)` gives the placement *bottom*, and `(moving … up)`, the
default, *top*: the direction of the moving set and the side of the stack it
lands on are one choice. The axis is a
crease the program has scored, since the hinges an unfold opens lie on the
paper already. A hinge on $\ell$ that is flat, or a face of $M$ the axis
cuts, which scoring joins to a stationary face by a flat hinge on $\ell$,
puts the write outside its domain: turning that layer over folds the hinge,
and `fold` writes that.

::: {.figure #fig-unfold caption="After two folds in the same direction every layer lies beside `--q`. `unfold` turns the layer of `.b` back over it, with the two layers above, which would be swept through otherwise: the hinge on `--q` between those layers and the bottom layer opens, and the hinge on `--q` among the moving layers stays folded." views="cp folded" highlight="--q .b"}
paper square
fold (map .b onto .a) as --d
.m = --d * --ab
fold (map .m onto .a) as --q
unfold (--q) (moving .b)
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

::: {.figure #fig-flip caption="With the sheet turned face down, the crease `--g` scored by a fold placed on top reads mountain: the folder turned the paper over and made a valley on its back." views="cp folded" highlight="--g"}
paper square
flip
fold (map .a onto .c) as --g
:::

::: {.definition #def-reverse name="reverse fold" uses="def-write def-reflection def-fold def-flap def-letter def-flat-state" defines="term-tip term-opening term-block term-spine term-body"}
The write `reverse` takes a table line $\ell$, a side $H$, an anchor flap
$\alpha$ with material in $H$, a kind, *inside* or *outside*, and a finite
set of letters, each a letter on hinges of the state. Score $\ell$ and call
the faces in $H$ the candidates. The *tip* $T$ is the least set of
candidates that contains the faces of $\alpha$ in $H$ and is closed under
hinges of any angle between candidates. An *opening* is a place between two
faces of $T$ that are consecutive in $\lambda$ restricted to $T$, such that
every hinge between a face below it and a face above it is folded and lies
on one table line $s$ that meets $H$. The opening cuts $T$ into the *blocks*
$T_1$ below it and $T_2$ above it. The *body* $B_i$ of a block is the set of
stationary faces joined to a face of $T_i$ by a hinge on $\ell$. An opening
is admissible when both bodies are non-empty and separated: every face of
$B_1$ lies below every face of $B_2$ it overlaps. Its state is the
reflection of the two blocks $(T_1, \text{over } B_1)$ and
$(T_2, \text{under } B_2)$ for *inside*, and $(T_1, \text{bottom})$ and
$(T_2, \text{top})$ for *outside*; it meets a letter when every hinge of $T$
the letter names has that letter in it. The value of the write is the one
state the admissible openings that meet every letter give, two states that
order every overlapping pair alike counting as one ([#def-flat-state]). It
is undefined when there is none or more than one.
:::

::: {.term #term-tip name="tip"}
The material a reverse fold or a flatten moves: beyond the axis or outside
the stayer's wedge, and joined to the anchor.
:::

::: {.term #term-opening name="opening"}
The place between two layers of the tip where a reverse fold opens it: every
hinge that crosses it is folded and lies on the spine.
:::

::: {.term #term-block name="block"}
The layers of the tip on one side of the opening, reflected as a whole.
:::

::: {.term #term-spine name="spine"}
The table line the hinges across the opening lie on. The reverse fold turns
those hinges the other way.
:::

::: {.term #term-body name="body"}
The stationary faces a block of the tip is hinged to along the axis.
:::

The two blocks move in one reflection and never one after the other: once
one block has moved, a hinge across the opening joins a reflected face to an
unreflected one along no common segment, and hinge closure fails. Inside,
each block lands next to its own body in the gap between the two bodies;
outside, the lower block goes under everything and the upper block on top.

A tip of one flap folded once has one opening, between its two layers. A
tip of several layers can have several: the square of [#fig-reverse-open]
opens between its two inner layers or below its outermost one, and the
write is undefined until a letter keeps one of them. A letter names a hinge
of the spine by its crease and a point on it, as a letter of a flatten names
a ray.

A reverse fold is the fan ([#def-flatten]) at the point where $\ell$ meets
$s$, a point of the projective table that lies off the paper or at infinity
where $\ell$ does not cross $s$ on the paper. Its rays are $s$ on the side
of the body, whose hinges stay; $s$ on the side of the tip, whose hinges
across the opening turn and whose other hinges stay; and $\ell$ on either
side of $s$, which adds a crease through every layer of the tip. *Inside*
and *outside* are the placements the write hands to the fan.

::: {.figure #fig-reverse caption="The preliminary base by two inside reverse folds [@ida2020, §7.4.3]: the diagonal fold makes a triangle whose spine is `--bd`, and each acute corner is reversed to the right-angle corner in turn." views="cp folded" highlight="--h --v --bd"}
paper square
fold (map .a onto .c) as --bd
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
:::

::: {.figure #fig-reverse-op caption="The terms of `--h` in [#fig-reverse] on the triangle it reads: the axis dashed, the spine on `--bd`, the two blocks of the tip hatched in two directions below the axis, where they lie on one another, and their bodies above it, each block and its body in one color. On the right the state after the reverse fold." views="op" at="h"}
paper square
fold (map .a onto .c) as --bd
@label h
reverse (map .b onto .c) as --h
reverse (map .d onto .c) as --v
:::

::: {.figure #fig-reverse-open caption="A square folded in half twice in the same direction, its lower half inside-reversed along the middle, cut along the top edge. The tip opens between its two inner layers, and the letter on the inner hinge of `--e` through `.q` keeps that opening: both hinges on the spine turn, 5|8 and 6|7, nested inside 2|3 and 1|4, and the lower half's layers read 8, 7, 6, 5 between 3 and 2. On the other edge the hinge 7|8 keeps its letter." views="side" along="--top"}
paper square
fold (map .b onto .a) as --d
fold (map --d onto --da) as --e
.q = free on --cd from .c at 1/4
reverse (map .a onto .d) (--e & .q valley) as --r
.p = free on --cd from .d at 1/4
--top = (through .d .p)
:::

::: {.figure #fig-reverse-open-outer caption="The same square with a mountain on the inner hinge: the tip opens below its outermost layer. Only the outer hinge 5|6 turns, the inner one, 7|8, keeps its letter, and the three inner layers of the lower half go in as one block, 8, 7, 6 between 2 and 5." views="side" along="--top"}
paper square
fold (map .b onto .a) as --d
fold (map --d onto --da) as --e
.q = free on --cd from .c at 1/4
reverse (map .a onto .d) (--e & .q mountain) as --r
.p = free on --cd from .d at 1/4
--top = (through .d .p)
:::

::: {.corollary #cor-reverse-letters name="letters of a reverse fold" uses="def-reverse def-letter cor-fold-letters def-reflection"}
Every hinge across the opening reverses its letter, and every other hinge of
the tip keeps its letter. Where a hinge across the opening crosses $\ell$,
the hinges the write scores there read the letter it had before for an
*inside* reverse and the opposite letter for an *outside* reverse.

*Proof.* Both blocks are reflected, so in each the face-up faces become face
down and the face-down ones face up. Inside a block the reflection also
reverses the order of the layers, so a hinge with both faces in one block
keeps its letter by [#cor-fold-letters]. A hinge across the opening joins a
face $A$ of $T_1$ to a face $C$ of $T_2$; the blocks keep their relative
order, since $B_1$ lies below $B_2$ and each block is placed at its own
body, so $A$ stays below $C$ while both change side: the letter reverses.
Where the hinge crosses $\ell$, $A$ and $C$ are hinged on $\ell$ to faces
$A'$ of $B_1$ and $C'$ of $B_2$, flat before the fold, so $A'$ and $C'$ are
joined by the part of the hinge on the body's side, with its letter. Let
$A'$ be face up; that hinge is then a valley. Inside, $A$ lands above
$A'$ and $C$ below the face-down $C'$: by [#cor-fold-letters] both new
hinges are valleys. Outside, $A$ lands below everything and $C$ above: both
mountains. For a face-down $A'$ exchange the letters. $\square$
:::

::: {.definition #def-flatten name="flatten" uses="def-write def-flap def-score def-reflection def-letter def-noncrossing def-selection" defines="term-fan term-sector term-stayer term-emergent"}
The write `flatten` takes a point $O$ of the projective table: a table
point, or a point at infinity, one for each direction (ADR 0041). It takes
an *anchor*: a flap $\Phi$ whose image meets the rays, a finite set of
*rays*: segments of creases on lines through $O$, from $O$ where $O$ lies on
the image of $\Phi$ and from the edge of that image where it does not, to
the other edge, no two of one crease in one direction, a set of
constraints, and a selection $\sigma$. Rays of different creases in one
direction lie in different layers and count as one direction below. At a
point at infinity the lines of the rays are parallel and the wedges
between them are strips. Let $\rho_1, \ldots, \rho_k$ be the reflections of
the table across the lines of the rays' directions, in counter-clockwise
order around $O$, or in order across the strips at a point at infinity.
The closure condition below applies only where $\Phi$ surrounds $O$ on the
paper: the paper point of $\Phi$ under $O$ lies inside the sheet and on no
folded hinge. A fan whose vertex lies on the edge, on a folded edge, off
the paper or at infinity has no condition at its vertex and no emergent
ray; only the closure of its paper paths below applies (ADR 0044).

- If $k$ is even, the composition $\rho_1 \circ \cdots \circ \rho_k$ must be
  the identity; this is Kawasaki's condition that the alternating sum of the
  angles between consecutive rays vanishes [@hull2020, §5.3].
- If $k$ is odd, the composition is a reflection across a line through
  $f(O)$, since an odd number of reflections through a point reverses
  orientation and fixes the point. Each of the two rays of that line that
  lies strictly inside a gap between consecutive given rays is an *emergent*
  ray; adding it makes the composition close. Each choice is a candidate
  fan.

Call the $n$ directions of a candidate fan $r_1, \ldots, r_n$ and the
regions of the table between consecutive ones the *wedges*
$W_0, \ldots, W_{n-1}$, with $W_i$ between $r_i$ and $r_{i+1}$. The
*stayer* is one wedge $W_0$, named by the program or by its convention.
The program names it by points $p_1, \ldots, p_j$ of $\Phi$: $W_0$ is the
wedge whose closure holds $f(p_1), \ldots, f(p_j)$, and the candidate fan has
candidate states only when exactly one wedge does and it holds a piece of
$\Phi$. The layers of the points play no further part; the tip decides which
layers move. Let
$R$ be the image of $\Phi$ and let $C$ be the faces whose image meets $R$
in positive area, the layers under the fan. Score every face of $C$ along
the rays' half-lines from $O$, so that each piece lies in one wedge, and
call the pieces outside $W_0$ the *candidates*. The *tip* $T$ is the least
set of candidates that contains the candidates of $\Phi$ and is closed
under hinges of any angle between candidates. The value keeps the scoring
on the faces with a piece in $T$ and leaves the other faces whole.

A hinge on a ray with a piece of $T$ on one side *changes* when it goes
from flat to folded or from folded to flat, and *keeps* otherwise. A flat
hinge of a ray's crease on that ray changes. A folded hinge of a ray's
crease, and a hinge of another crease on a ray, changes or keeps; each
choice is a candidate fan. The *motion* $m_p$ of a piece $p$ is the
composition of the reflections across the changing hinges that a path on
the paper crosses from a piece outside $T$ to $p$, in order
[@hull2020, Def. 6.5], and the identity outside $T$. A choice is a
candidate only when every such path gives $p$ the same motion, which is
Kawasaki's condition at every paper point the paths enclose
[@hull2020, Thm. 6.6], and when some piece of $T$ moves. The map $f'$ is
$m_p \circ f$ on every piece $p$. A *candidate state* is a pair
$(f', \lambda')$ with $\lambda'$ such that it satisfies [#def-noncrossing]
and the constraints:

- a letter for a ray: of the hinges of the ray's crease on that ray that do
  not open, the one whose face on the clockwise side lies lowest has that
  letter;
- one sector over another: the two pieces are so ordered;
- the stayer, which only fixes where the result lies on the table.

A ray may run along hinges of $T$ that are already folded, as the spine of
a reverse fold does ([#def-reverse]). Such a hinge *stays* when it keeps
its angle and its letter, *turns* when it keeps its angle and takes the
other letter, and *opens* when it changes, as the spine of a squash does.

The value of the write is the one candidate state $\sigma$ selects from the
set of all candidate states of all candidate fans; it is undefined when
that set is empty, when its states differ in their stayer, or when
$\sigma$ leaves more than one. The crease the write
scores is the bundle of the hinges on the given rays when $k$ is even and
the bundle of the hinges on the emergent ray when $k$ is odd.
:::

::: {.term #term-fan name="fan, ray"}
The segments from one vertex along which a flatten folds at once.
:::

::: {.term #term-sector name="sector"}
A piece of the tip between the hinges on the rays of a fan. It moves by the
creases on its paper path from the stayer (ADR 0044).
:::

::: {.term #term-stayer name="stayer"}
The wedge of a flatten whose pieces keep their place; it fixes where the
result lies on the table.
:::

::: {.term #term-emergent name="emergent ray"}
The ray a flatten with an odd number of given rays has to add for the vertex
to fold flat.
:::

The construction is the folding map of flat-folding theory, restricted to
the hinges the fan changes [@hull2020, Def. 6.5]. On a single sheet a path
from the stayer to a piece crosses the rays between the stayer's wedge and
the piece's wedge, so every piece of a wedge moves by the composition of the
reflections across those rays, the single-vertex fan of
[@hull2020, chapter 5]. On folded paper two pieces of one wedge can move
differently: the squash of one flap of the preliminary base turns a piece of
the top layer about the vertex and reflects the piece of the second layer
beside it across the axis. Kawasaki's theorem says that the closure
condition is exactly flat-foldability of a vertex the paper surrounds, and
Maekawa's theorem, that the letters around it differ in number by two,
holds in every candidate state because a candidate state is a flat folded
state [@hull2020, §5.2, §5.3]. A layer under the fan moves with its sector
when it hangs on $\Phi$ through the candidates, a flap of several layers
hinged together beyond the fan included, and a separate flap stays where it
lies: on a book fold, a fan near the corner whose rays end on the raw edges
folds the corner of $\Phi$ alone, and a fan whose ray reaches the spine
moves both layers. On a single sheet every piece is joined to $\Phi$, so
the tip is every piece outside the stayer's wedge. Where a face of $T$ is
hinged to a face in the stayer's wedge off the rays, the paths disagree and
the write is undefined, as for every reflection.

::: {.figure #fig-flatten caption="The preliminary base by one collapse at the center: six rays fold, the diagonal through `.a` and `.c` stays flat, and the ordering constraint puts the a-quarter in front of the b-taco." views="cp folded" highlight=".a .c"}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
.q = free on --ab from .a at 1/4
.r = free on --ab from .b at 1/4
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b) (--bd & .d) (.q over .r) (toward .q)
:::

::: {.figure #fig-flatten-op caption="The terms of the collapse in [#fig-flatten]: the vertex at the center, the six rays, and the stayer, the quarter between the rays on `--h` and `--v` that holds the diagonal to `.c`. Every other sector moves by the reflections across the rays between it and the stayer; on the right the state after the collapse." views="op" at="collapse"}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
mark (map --da onto --bc) as --v
.q = free on --ab from .a at 1/4
.r = free on --ab from .b at 1/4
@label collapse
flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b) (--bd & .d) (.q over .r) (toward .q)
:::

::: {.figure #fig-flatten-states caption="The candidate states of a four-ray vertex, the midline on both sides and the half-diagonals to `.c` and `.b`, each as its crease pattern, mountains red and valleys blue. The sectors are 45°, 135°, 135° and 45°, so opposite sectors sum to 180° and the vertex folds flat. Every state has three rays of one letter and one of the other. The three with three mountains are removed; the three with one mountain each remain, and without `toward` the program fails as ambiguous ([#open-flatten-selection])." views="candidates" at="vertex"}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
@label vertex
flatten (--h & --bc) (--ac & .c) (--h & --da) (--bd & .b)
:::

::: {.figure #fig-flatten-toward caption="The same vertex with `toward .c`: of the three states with one mountain, two put less of the material toward `.c` on top than the third, which remains." views="candidates" at="vertex"}
paper square
mark (through .a .c) as --ac
mark (through .b .d) as --bd
mark (map --ab onto --cd) as --h
@label vertex
flatten (--h & --bc) (--ac & .c) (--h & --da) (--bd & .b) (toward .c)
:::

::: {.open #open-flatten-selection name="what selects among the candidates of a flatten" uses="def-flatten def-selection"}
[#def-flatten] leaves $\sigma$ to the program, as [#def-construction] does
for the candidates of a construction. The language's `toward` is three rules in
sequence: the candidate whose moved material lies toward the named point,
among those the ones with the fewest mountains on the given rays, among
those the one whose material toward the point lies on top. The first is a
selection in the sense of [#def-selection]; the other two are conventions that
pick a folder's habit out of several states that are all flat folded. Whether
they belong in the model as named selections, or the language should ask for
a constraint instead when several states remain, is not decided.
:::

## 6. Programs

To be written: a program as a finite sequence of states.

::: {.open #open-several-sheets name="several sheets and bodies" uses="def-sheet def-flat-state def-noncrossing cond-connected"}
The language design for sheets as values lets a program
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
