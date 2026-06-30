# Bibliography

Running list of sources, each with a one-paragraph note on what's in it and how
it relates to Beloch. The paper's related-work section writes itself from this.
Add a source the moment it's read or cited — don't batch.

## Core references

### Hull — *Origametry: Mathematical Methods in Paper Folding* (Cambridge, 2020)
Tom Hull (not Demaine — Demaine wrote the cover blurb, hence the common
mix-up). The math of origami. Part I = geometric constructions (the axioms,
angle trisection, regular heptagon, the field of origami numbers via Galois
theory) — maps directly onto Beloch's primitives and gives the vocabulary for
axiom-6 multiplicity (clearer once seen as a cubic). Later parts: flat-
foldability (Kawasaki, Maekawa), tessellations, rigid origami. **Tells you what
origami *is* mathematically.** Read order: structural skim first, then deep on
axiom-6 multiplicity.

### Demaine & O'Rourke — *Geometric Folding Algorithms: Linkages, Origami, Polyhedra* (Cambridge, 2007)
The computational/algorithmic counterpart. Bern–Hayes NP-hardness of
mountain-valley assignment, face-ordering, flat-foldability algorithms. **Tells
you what's *hard* about computing origami.** Closest to Beloch's implementation
pain — the layer/face-ordering problem. Read deeply on flat-foldability + layer
ordering.

### Caruana & Pace — "Embedded Languages for Origami-Based Geometry" (University of Malta, 2007)
**The closest academic precedent to Beloch.** A domain-specific *embedded*
language in Haskell, based on the seven axioms, compositional, with precondition
analysis and basic animation. Embedded (you write Haskell with their library),
not standalone; focused on geometric constructions, doesn't deeply engage layer
ordering / folded state / 3D. Beloch's defensible novelty is precisely:
standalone language + explicit layer model + FOLD-extended output, extending
this dropped thread. Must be cited and honestly compared. On ResearchGate /
Pace's Malta CS page.

### Hull & Zakharevich — "Flat origami is Turing complete" (arXiv:2309.07932, 2023)
Shows the *physical process* of flat-folding is Turing-complete (flat-
foldability / MV-assignment can encode arbitrary computation). A statement about
origami-the-object, **not** about any language describing it — making Beloch
Turing-complete is an unrelated ordinary language-design choice (and one to
resist in the core). Relevant for: related-work framing; the "compile-to-
computational-origami" spin-off idea; Figure 18 (Rule 110 cell) as a potential
reproducibility/parametricity example in a future paper.

### Basu, Pollack & Roy — *Algorithms in Real Algebraic Geometry* (Springer, 2006)
The canonical reference for real-algebraic computation: resultants and
subresultants (Ch. 4, 8), Sturm sequences and real-root counting (Ch. 2, 9),
real-root isolation via signed Sturm sequences and binary search (Ch. 10).
Grounds ADR 0012 (`lib/poly.ml`): the isolating-interval representation, the
numeric Sylvester resultant, and the interval-refinement comparisons. **The
number-theory foundation of Beloch's algebraic kernel.**

### Messer — "Problem 1054" (*Crux Mathematicorum* 12(10), 1986)
The canonical paper-folding construction of ∛2. A square is divided into three
equal vertical strips by lines `PQ` (x=1/3) and `RS` (x=2/3); folding corner `C`
onto edge `AB` while `S` (the top of `RS`) lands on `PQ` is a single axiom-7 fold,
and the corner divides `AB` in ratio `AC/CB = ∛2`. Shipped as
`examples/cube-root.bel`, kernel-verified `(AC/CB)³ = 2` exactly. Note: neither
Messer nor Hull §2.3 derives *why* the thirds — they are a given; the construction
is validated by the cube-root identity, not by re-deriving the subdivision. The
first axiom-7 example that actually folds (uses `@`), exercising the shared-field
kernel through the full folded-state pipeline.

## Formats / tools

### FOLD format (Demaine, Ku, Lang)
The JSON interchange format for origami; the natural IR target. Beloch emits
FOLD with `beloch:*` extension fields. See [decision 0002](decisions/0002-fold-extended-as-output.md).

### Rabbit Ear (Robby Kraft) — https://rabbitear.org
The closest existing work and the natural consumer/backend. A mature JavaScript
origami **library**: seven axioms as functions, FOLD manipulation, crease-pattern
math, SVG/WebGL rendering, folding simulation, face population. *Not* a standalone
declarative source language — you program against it in JS. Beloch positions as
the language layer above it; RE is the rendering/folding backend (it accepts
faces-less FOLD and computes faces itself). See
[decision 0009](decisions/0009-relationship-to-rabbit-ear.md). Must be cited and
positioned against honestly in the paper.

## To read / track

- Justin (1986) — first complete statement of the seven axioms ("Huzita-Justin"
  attribution; Hatori rediscovered #7 in 2002). Source for the axiom set.
- Lang, *Computational Origami* overview — https://langorigami.com/article/computational-origami/
  (survey of the field's tools: OrigamiDraw, Tessellatica, Grasshopper, TreeMaker,
  Origamizer, etc. — establishes that "axiomatic programming of origami as a
  standalone declarative language with its own file format" is the empty niche.)
