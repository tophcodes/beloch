---
title: The model
description: What a Beloch program talks about. States, values, and the operations on both, with the kernel as one model of it.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

This document defines what a Beloch program talks about: the set of states,
the values a program can name, and the operations on both. `SPECIFICATION.md`
says how the language is written; this document says what it means. The two
are kept consistent by hand, and the kernel (`packages/core`) is one model of
what is written here.

The document grows in steps. Each definition is stated with its intuition
first, then its formal content, then the place in the kernel that realizes it.
Open points are marked **Open** and are part of the contract until closed.
Statements are numbered within their section: a *Definition* introduces a
term, a *Lemma* is a consequence with a proof or a pointer to one, a
*Corollary* follows from a lemma without further argument, a *Remark* is
unproven commentary. Each statement carries the terms it defines, the
statements it uses, the statements that use it, and the kernel function that
realizes it. Every word used in a technical sense is listed under
[Terms](#terms) with a link to where it is defined; the first use in the text
links there too.

**Before reading.** The text uses set notation and plane geometry at
first-course level, and folding words (crease, flap, layer, mountain, valley)
the way folders use them. Everything it needs from flat-folding theory is
restated where it is used; the full account is Hull [@hull2020, chapter 6].

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
([#def-flat-state]), because the kernel's clipping and overlap tests work on
convex polygons; a non-convex sheet is decomposed into convex faces joined by
flat hinges (angle $0$). A convex sheet is a single face. `paper square` is
the only sheet the language offers today; the model does not depend on that.

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

[^history]: This holds for the model. The implementation does keep the
    history and exposes it: the FOLD output carries one frame per statement
    and, per edge, the statement that scored it (`file_frames`,
    `beloch:edges`, `beloch:source_line`; `SPECIFICATION.md` §7). Nothing in
    this document depends on that record, and no operation may read it.

::: {.definition #def-flat-state name="flat folded state" uses="def-sheet def-noncrossing" defines="term-table term-face term-hinge term-layer" realized-by="Fold_state.make"}
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

Kernel: `Fold_state.t` holds the face array in paper coordinates, one exact
2D isometry per face (`Isometry.t`), the hinge array with angles in
$\{0, \pm 1\}$ (units of $\pi$), and a rank. `Fold_state.make` is the only
constructor and rejects anything outside [#def-flat-state] and
[#def-noncrossing].

::: {.remark #rem-rank name="rank" uses="def-flat-state" realized-by="Fold_state.rank"}
The kernel does not store $\lambda$. It stores a rank, a total order of all
faces, and reads *above*/*below* for an overlapping pair off the rank. A rank
represents $\lambda$ exactly when it is a linear extension of it: it agrees
with $\lambda$ on every overlapping pair and is free on the rest. Two ranks
with the same restriction to overlapping pairs represent the same state.
:::

The rank is a representation, and a strictly weaker one: a $\lambda$ has a
linear extension only if it is acyclic across regions, and flat-foldable
states with cyclic layering exist. In the square twist the four central faces
lie over-under-over-under around the twist, so "no linear layer ordering will
be able to avoid such obstructions", while the fold is flat-foldable
[@hull2020, sec. 6.5, p. 119]. Such states are outside what the kernel can
hold today. This is a known ceiling of the implementation, the model itself
is stated on $\lambda$.

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

::: {.definition #def-noncrossing name="non-crossing conditions" realized-by="Fold_state.violation"}
To be written: the conditions on $\lambda$ that make $(f, \lambda)$ a physical
state (antisymmetry, transitivity, tortilla-tortilla, taco-tortilla,
taco-taco) and Beloch's structural conditions (hinge closure, connectivity),
each mapped to a constructor of `Fold_state.violation`.
:::

## Terms

Each entry gives the meaning in one line and points to the definition that
fixes it.

## References
