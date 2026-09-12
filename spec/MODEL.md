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
unproven commentary. Every word used in a technical sense is listed under
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

> **Definition 1 (sheet).** A sheet is a simple polygon $P \subset \mathbb{R}^2$:
> a closed boundary without self-intersection and without holes. The plane of
> $P$ is the [paper frame](#paper-frame). A paper point is an element of $P$.

The sheet may be non-convex. Convexity belongs to the faces of a state
(Definition 2), because the kernel's clipping and overlap tests work on convex
polygons; a non-convex sheet is decomposed into convex faces joined by flat
hinges (angle $0$). A convex sheet is a single face. `paper square` is
the only sheet the language offers today; the model does not depend on that.

Holes are excluded because the tortilla conditions of Definition 3 are stated
for regions without holes [@hullzakharevich2023, §2.1] and because the
existence of a folding motion is proven for simple polygons only
[@demaine2007, sec. 11.6, Theorem 11.6.2].

Sources: paper as an orientable 2-manifold with boundary [@demaine2007,
§11.4.1]; faces as strictly convex polygons because face division and overlap
algorithms need it [@ida2020, p. 176].

## 2. Flat folded state

Intuition: a folded state records where every point of the sheet lies on the
[table](#table) and, wherever paper lies on paper, which layer is on top. Nothing else.
In particular a state does not remember how it was reached.

> **Definition 2 (flat folded state).** A flat folded state of a sheet $P$ is a
> pair $(f, \lambda)$ where
>
> - $F$ is a finite decomposition of $P$ into convex polygons, the faces, such
>   that any two faces meet in a common edge, a common vertex, or not at all;
> - $f : P \to \mathbb{R}^2$ is a map that is an isometry (a rotation,
>   reflection, or translation, composed) on each face and continuous across
>   face edges; the plane of the image is the [table frame](#table);
> - $\lambda$ assigns to every pair of faces whose images overlap in a region of
>   positive area one of *above* and *below*, subject to Definition 3.

An edge shared by two faces is a [hinge](#hinge). Its angle is $0$ when $f$ agrees on
both faces across it, and $\pm\pi$ when $f$ reflects one face onto the other
across the edge's image. A hinge of angle $0$ is a flat crease; a hinge of
angle $\pm\pi$ is a folded crease. Creases are not objects of their own; they
are hinges (ADR 0014).

> **Definition 2a (refinement equivalence).** Splitting a face along a segment
> into two faces joined by a hinge of angle $0$ does not change the state. Two
> states that differ only by such splits are the same state.

This makes the convex decomposition of Definition 1 immaterial, makes `mark`
a no-op on the state modulo refinement, and is what "the two routes reach the
same folded state" means when comparing programs.

Kernel: `Fold_state.t` holds the face array in paper coordinates, one exact
2D isometry per face (`Isometry.t`), the hinge array with angles in
$\{0, \pm 1\}$ (units of $\pi$), and a rank. `Fold_state.make` is the only
constructor and rejects anything outside Definitions 2 and 3.

**Open.** The kernel stores $\lambda$ as a rank, a total order of all faces,
and derives *above*/*below* for overlapping pairs from it. The model can treat
the rank as a representation (the partial order plus one chosen linear
extension) or as part of the state. Not yet decided.

**Open.** $\lambda$ is defined on faces here and on points in the literature
[@demaine2007, §11.4; @hullzakharevich2023, §2.1]. The two agree when faces are
uncreased regions, which Definition 2 guarantees. To be stated as a lemma once
Definition 3 is written.

## 3. Non-crossing conditions

To be written: the conditions on $\lambda$ that make $(f, \lambda)$ a physical
state (antisymmetry, transitivity, tortilla-tortilla, taco-tortilla,
taco-taco) and Beloch's structural conditions (hinge closure, connectivity),
each mapped to a constructor of `Fold_state.violation`.

## Terms

Each entry gives the meaning in one line and points to the definition that
fixes it.

### paper frame

The plane the sheet $P$ lives in before any folding; coordinates in it never
change. Definition 1.

### table

The plane a state is folded onto, the image of $f$. "Table frame" names its
coordinate system. A point of the sheet has one paper coordinate and, per
state, one table coordinate. Definition 2.

### face

A convex polygon of the decomposition $F$ on which $f$ is a single isometry.
Definition 2.

### hinge

An edge shared by two faces, with an angle of $0$ (flat crease) or $\pm\pi$
(folded crease). Definition 2.

### layer, above, below

In a region of the table where several faces overlap, the faces are the
layers, and $\lambda$ says for each pair which is above. Definition 2,
conditions in Definition 3.

### flap

A maximal set of faces joined by flat hinges; the unit that moves as one in a
fold. ADR 0017. To be defined in the section on operations.

### refinement

Splitting faces along flat hinges. States equal up to refinement are the same
state. Definition 2a.

## References
