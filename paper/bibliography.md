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

### Della Dora, Dicrescenzo & Duval — "About a New Method for Computing in Algebraic Number Fields" (EUROCAL '85, LNCS 204)
The founding "D5" paper — a two-page extended abstract (pp. 289–290; that *is*
the complete published text). States Lazard's remark: for squarefree `P` and any
`A`, `A` is zero modulo `gcd(P,A)` and invertible modulo `P/gcd(P,A)` — so one
can compute in `ℚ[X]/P(X)` without factorization or primitive-element
computation, letting representations split lazily during computation. Grounds
the kernel's squarefree-generator `Field` invariant (zero-test via gcd,
generator splitting on inversion). `refs/ddd1985.md` is a transcription of the
scan (no text layer).

### Duval — "Algebraic Numbers: An Example of Dynamic Evaluation" (*J. Symbolic Computation* 18, 1994)
Tutorial companion to ddd1985 (received 1989, from an ISSAC '89 invited talk):
names the technique *dynamic evaluation* ("automatic case discussion"), works
the algebraic-number case in detail (§2–3), and discusses implementation (§5).
The readable exposition of what the D5 abstract compresses into two pages.
OCR'd text in `refs/duval1994.txt` (scanned original; math notation mangled,
prose searchable).

### Messer — "Problem 1054" (*Crux Mathematicorum* 12(10), 1986)
The canonical paper-folding construction of ∛2. A square is divided into three
equal vertical strips by lines `PQ` (x=1/3) and `RS` (x=2/3); folding corner `C`
onto edge `AB` while `S` (the top of `RS`) lands on `PQ` is a single axiom-7 fold,
and the corner divides `AB` in ratio `AC/CB = ∛2`. Shipped as
`examples/syntax/cube-root.bel`, kernel-verified `(AC/CB)³ = 2` exactly. Note: neither
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
  Origamizer, etc. Together with [lam2009]'s taxonomy it fixes the niche Beloch
  claims: a standalone language whose primitives are the axioms, whose geometry
  is exact, and whose folded state and layer order are derived from the
  actions, with the folded state exact. Fisher 1994 already had the first three
  in a single system; what he lacked was exact geometry, the emergent-crease
  solve, and an interchange format. Eos and Caruana & Pace have axiom
  semantics without a standalone language; the simulators have a folded
  state without a language.)

## Multifold research track (Phase 0)

### Alperin & Lang — "One-, Two-, and Multi-Fold Origami Axioms" (Origami⁴, 2009)
**The foundation of the multifold research track.** Defines alignments as the
primitive (5 one-fold alignments A1–A5; 10 two-fold types AL1–AL10, a/b
variants → 17 symbols), proves HJA completeness by hand table, then
computer-enumerates non-separable two-fold axioms: 2–4 alignments summing to
exactly 4 equations, deduped under permutation/folding equivalence, Jacobian
non-degeneracy check in Mathematica. **489 with AL10, 203 without** — the
numbers Phase 1 must reproduce, both. Section 8: N-fold axioms defined, one
3-fold construction (general quintic via Lill), Theorem: degree n solvable
with n−2 folds; minimality conjectured, **no enumeration for k≥3**.
Version-of-record check done (see `notes/2026-09-10-origami4-version-of-record.md`):
the typeset chapter is a copyedit of the Dec-2006 preprint. The 489-symbol
listing matches our fixture symbol for symbol, the five symbols our pipeline
produces that the listing lacks (`AL2ab8`, `AL2a7a8`, `AL2a7b8`, `AL2a7a9`,
`AL2a7b9`) are absent in the book too, and the sign misprint in
the folded-line formula, eq. (2), is printed identically in both. The
discrepancy is therefore ours to explain against the version of record, and a
candidate erratum for the paper.
Alignments use single reflections only (no nested F_a(F_b(P))) — a modeling
choice our 3-fold alphabet must make explicitly and defend.

### König & Nedrenco — "Septic equations are solvable by 2-fold origami" (arXiv:1504.07090, 2015)
Two-fold origami reaches degree 7: explicit septics with Galois groups A₇ and
PSL₃(F₂) solved via 2FAs. Upper end of what's known for k=2 — calibrates the
"which degrees need how many folds" table.

### Lucero — "Geometric solution of a quintic equation by two-fold origami" (arXiv:1801.07460, 2018)
Explicit quintic solution using a single two-fold operation. NB: earlier scan
misattributed this arXiv id to Nishimura — it is Lucero.

### Lucero — "Construction of a regular hendecagon by two-fold origami" (arXiv:1807.09557, 2018)
The 11-gon (smallest regular polygon beyond HJA reach) via 2-fold. Concrete
minimal-fold-count data point for the Phase 3 table.

### Chow & Fan, "The Power of Multifolds" (Origami⁴ 2009, arXiv:0808.1517)
Sits directly after [alperin2006] in the same volume; our Phase-0 scan missed
it. Defines the "$n$-parameter multifold" and shows one-parameter multifolds
reach the full algebraic closure $\bar{\mathbb{Q}}$. This is a second
multifold formalism beside Alperin-Lang's simultaneous-crease alignments, and
the k=3 alphabet decision must engage with how the two relate. Their result
settles reachability inside their framework and leaves the enumeration of
axiom systems untouched, so the classification question stays open. The
related-work section needs the comparison, and any "which degree needs how
many folds" claim must name its formalism.

## Origami⁴ (4OSME, 2009): computational origami and neighbours

Photographed chapters from the Origami⁴ proceedings (A K Peters, 2009, ed.
Robert J. Lang), OCR'd into `refs/<citekey>.txt`; the ingest is documented in
`refs/origami4-scans/INGEST-REPORT.md`. Four further chapters are PDFs. The
assessment of what they change for Beloch is
[`notes/2026-09-10-origami4-prior-art.md`](../notes/2026-09-10-origami4-prior-art.md).

### Ida, Takahashi, Marin, Kasem & Ghourabi, "Computational Origami System Eos" (pp. 285–293)
**The closest system prior art beside Caruana & Pace.** Eos is a Mathematica
package (`OrigamiBasics`) plus a web front end (`webOrigami`). Table 1 (p. 287)
maps Huzita's axioms to function calls: `Fold[P,Q]` brings `P` onto `Q`,
`Fold[PQ,EF]` superposes two lines, `Fold[P,EF,Through→Q]` is axiom 6 in
Beloch's numbering, `Fold[P,EF,Q,GH]` the simultaneous two-point fold. When a
fold has several solutions Eos shows the cases and the user re-issues the call
with a case number (§3, heptagon construction, p. 288): the analogue of
Beloch's `toward`. Five "artistic folds" (`MountainFold`, `ValleyFold`,
`InsideReverseFold`, `OutsideReverseFold`, `SquashFold`) fold the crane (§4,
p. 290–291). §5 proves construction correctness automatically: premises and
conclusion become polynomial systems, decided by Gröbner bases or, with
inequalities, cylindrical algebraic decomposition. What this chapter does not
say: how Eos represents the folded state and layers, and what arithmetic it
computes in. The 2004 AISC paper (Ida, Tepeneu, Buchberger, Robu) is the
source for that and is not yet in `refs/`. Honest comparison for the paper:
Eos has proof, Beloch has a standalone language, an exact folded-state
kernel and a file format.

### Fastag, "eGami: Virtual Paperfolding and Diagramming Software" (pp. 273–283)
Direct-manipulation simulator for flat origami with automatic diagram
generation. Two things matter for Beloch. Table 1 (p. 276) is a complete
catalogue of folding maneuvers as diagrammers name them (fold: valley,
mountain, valley-under, mountain-under, crease; reverse; squash; petal; rabbit
ear; sink; pleat; fan fold; crimp; unfold), the checklist for the spec's
Appendix B. §3.3 (p. 281) states that tools are operation-driven, and that one
"could theoretically reproduce the entire folding sequence simply from the
starting paper configuration and the history of operations, although this is
not how it is implemented in practice". Beloch makes that operation history
the source artefact. §3.2 (p. 280) lists the paper constraints (Maekawa,
Kawasaki, no stretch, flat faces, no self-intersection) and §3.4 reports that
validity testing is factorial in practice.

### Lam, "Computer Origami Simulation and the Production of Origami Instructions" (pp. 237–249)
Survey and usability study. §4.2 (p. 241) sorts origami software into design
tools (Tess, ReferenceFinder, TreeMaker, ORIPA), **origami-oriented
languages** (Oridraw and Doodle: text compiled to PostScript
diagrams, with the user still placing lines and polygons by hand; and
Fisher 1994, which Lam files here but is a folding-sequence interpreter,
see [fisher1994] below), and
direct-manipulation simulators (Miyazaki, eGami, Foldinator, Nimoy). This
kills any "first origami language" claim; Beloch's claim is the combination
of axiom semantics, exact arithmetic and a derived folded state in a
standalone language. §5.4 (p. 244) lists the disadvantages of direct
manipulation: the user cannot manipulate what is hidden and cannot
distinguish multiple layers. That is the usability argument for explicit
layer selection (`up to`, `#[…]`) in a textual language. The bibliography
(pp. 246–249) is the map of pre-2009 origami software.

### Lang & Demaine, "Facet Ordering and Crease Assignment in Uniaxial Bases" (pp. 189–205)
Completes TreeMaker's tree theory with an algorithm for stacking order and
M/V assignment. §3.1 restates the four Justin layer-ordering conditions (Fig.
5), §3.3 builds an ordering graph (OG) over facets and its reduced acyclic
form (ROG), §3.4 derives mountain/valley from a two-colouring of facets plus
the order: white-up above colour-up is a mountain. §4 names "the primacy of
the ordering relationship, rather than the crease assignment, as the
fundamental mathematical description". This is the published form of ADR
0011's "M/V is derived from the layer order"; cite it there and in the paper.
The Justin conditions are the correctness criterion Beloch's folded-state
validity checks should be measured against. Justin's own 1991 and 1997 papers
are not in `refs/`.

### Konjevod, "Integer Programming Models for Flat Origami" (preprint of the Origami⁴ chapter)
Flat foldability on a square-triangle grid as an integer linear program:
crease variables, orientation and location constraints, layer variables
$\lambda(v,w,k)$ and an above-relation $\alpha(u,v)$, with the three
non-crossing types W, X, Y (§2.4). The 2×2 iso-area chessboard takes hours to
solve (§3). Useful as the counterexample that motivates Beloch's
constructive route: actions determine the order, so no global search over
layer assignments is needed.

### Shimanuki, Kato & Watanabe, "Construction of 3D Virtual Origami Models from Sketches" (pp. 217–228)
Sketch to crease pattern to folded model. §2.3 uses Miyazaki's data
structure: faces grouped by plane, each group holding an ordered face list.
That is the coplanar-cluster view of ADR 0017. §4 orders faces by simulated
annealing over cross sections because the global order is intractable; Beloch
avoids the search by deriving order from actions.

### Mitani, "Recognition, Modeling, and Rendering Method for Origami Using 2D Bar Codes" (pp. 251–258)
Captures a physical folding sequence from photos of QR-coded paper (brute
force over candidate folds per step, §2) and renders folded models with a
per-face offset by stack position and slid vertices so layers read (§3). The
rendering half is the reference for "thickness is a display-only offset"
(ADR 0011 consequences). Miyazaki's structure again.

### Hull, "Configuration Spaces for Flat Vertex Folds" (preprint of the Origami⁴ chapter)
For a flat vertex of degree $2n$ the number $C(v)$ of valid M/V assignments
is computable in linear time and bounded by $2^n \le C(v) \le 2\binom{2n}{n-1}$
(§1); the chapter describes the configuration space of angle vectors and
where $C(v)$ jumps. Test oracle for `flatten`'s solution-space enumeration
at a single vertex.

### Azuma, "On the Fish Base Crease Pattern and Its Flat Foldable Property" (pp. 417–426)
Generalised fish base on a kite: the two vertices of the pattern are isogonal
conjugates of the triangle, hence foci of an inellipse, and Apollonius'
tangent-angle relation gives Kawasaki's condition at both (§2.3, Prop. 1–2).
A parametric example family for Beloch once a kite paper shape exists:
`flatten` at each vertex should verify flat foldability exactly.

### Kawasaki & Kawasaki, "Orizuru Deformation Theory for Unbounded Quadrilaterals" (pp. 427–438)
A bird base is foldable from a quadrilateral iff it has an inscribed circle
(Justin), and the centre of the base can be any point on a conic fixed by the
quadrilateral (Theorem 1, p. 436); the chapter extends this to unbounded
quadrilaterals. The bird-base-from-a-quadrilateral construction is the
target example for multi-vertex `flatten`.

### Veenstra, "Fujimoto, Number Theory, and a New Folding Technique" (pp. 405–415)
The Fujimoto approximation for folding $1/n$ as a recursion
$l_{k+1} = \tfrac{1}{2}(l_k + c_k)$ with $c_k \in \{0,1\}$ from the parity of
$n\,l_k$ (Eq. 1, p. 407); the number of distinct crease lines is the order of
2 mod $n$ (Theorem 1). The concrete demand for a loop primitive; with exact
rationals Beloch shows each pinch mark as an exact dyadic fraction.

### Watanabe & Kawaguchi, "The Method for Judging Rigid Foldability" (pp. 165–174)
Rigid foldability of a crease pattern via a vector diagram (closed loop, zero
oriented area) and its matrix form $A\varepsilon = 0$,
$\varepsilon^{T} C \varepsilon = 0$ solved with a generalised inverse.
Relevant only once 3D folding motion is in scope (ADR 0015).

### Tachi, "Simulation of Rigid Origami" (preprint of the Origami⁴ chapter)
Rigid-origami simulation with crease angles as configuration and motion
projected onto the constraint space given by the single-vertex closure
$\chi_1 \cdots \chi_n = I$. The reference implementation to compare with when
the 3D standing state lands (ADR 0015).

### Halloran, "Concepts and Modeling of a Tessellated Molecule Surface" (pp. 305–314)
Tessellated waterbomb surfaces and their rigid neighbourhoods. Photographed by
mistake; out of scope for now.

## Eos internals (Ida et al., Tsukuba, 2007–2008)

The papers that answer what [ida2009eos] leaves open: how Eos represents the
folded state and layers, and what arithmetic it runs on.

### Ida, Takahashi, Marin & Ghourabi, "Modeling Origami for Computational Construction and Beyond" (ICCSA 2007, LNCS 4706)
**Eos's folded-state model, and the closest published analogue of Beloch's
`Fold_state`.** An abstract origami is $(\Pi, \succ, A)$: a set of convex
faces with orientation (Def. 1–2), an overlay relation $\succ$ defined only
between overlapping faces, and an adjacency mapping (Def. 4–5). A fold is the
seven-step algorithm (F-1)–(F-7), p. 655–656: pick the fold method (a Huzita
axiom), get the line, take the origamist's set $F$ of faces of concern,
propagate to the affected set $G$ through adjacency and "overlapping and
above" (Def. 6, (G-1)–(G-4)), divide faces by the line, rotate the moved
half, recompute $\succ$ and $A$. Def. 7 defines $\succ$ inductively per fold
in three cases (both stayed, both moved with the order reversed, one of
each ordered by valley/mountain), which is exactly the parent-inheritance
rule Beloch's layer order uses. §4.1 shows $\succ$ is neither total nor
transitive and argues why a "touches if pressed" relation is too expensive to
compute. §4.2 defines a *layer* as an equivalence class of adjacent
same-orientation faces (coplanar clusters, cf. ADR 0017), the layer graph
and its transitive reduction, and layer stacks for rendering; the crane has 8
stacks of heights 31 and 23 (§6). §5: unfold is not undo, divided faces
persist. §7 names relating the model to Alperin & Lang as open work.

### Ida, "Graph Rewriting in Computational Origami" (SYNASC 2008)
Refines the 2007 overlay into three relations (Def. 4.4–4.7): a transient
*over* relation carried through face division, *above* as its transitive
closure, and *superposes* as "above with nothing between". Fold becomes a
hypergraph rewrite with labels `A` (adjacency), `S` (superposition), `L`/`R`
(sides of the ray), and Algorithm Fold (§4.2) is the 2007 procedure made
explicit. The paper states that rotation "will invoke numerical computation
of the coordinates" (§7.4).

### Ida, Marin, Takahashi & Ghourabi, "Computational Origami Construction as Constraint Solving and Rewriting" (ENTCS 216, 2008)
Huzita's axioms as first-order formulas (A1)–(A6) and then as a 3-CTRS
(`foldTh`, `foldBr`, `foldBrLine`, `foldPerTh`, `foldThBr`, `foldBrBr`,
§3.3), with lines as `line(a,b,c)` under a coefficient normalisation. §3.2
fixes "the domain of interpretation to be the domain of algebraic numbers",
but the implementation splits: "the system solved the constraints
numerically, and at the same time it saved the constraints in symbolic
expression" (§5), and "the numerical solutions are used to simulate the
construction" (§7). **So Eos's folded state is floating point; exactness
lives only in the proof side.** That is the sharpest difference from
Beloch's exact kernel, where the folded state itself is exact. §6 lists Eos's
primitives (`HFold[A, Along→{P,Q}]`, `HFold[P,Q]`) and the wish list: typing
of geometric objects that degenerate, a friendlier interface.

### Ghourabi, Ida, Takahashi, Marin & Kasem, "Logical and Algebraic View of Huzita's Origami Axioms" (SAC 2007)
The translation $\mathcal{A}[\![\cdot]\!]\rho$ from the logical axioms to
polynomial systems (§3.2), with slack variables for disequalities. §4 shows
Abe's trisection with `Fold[E, KJ, I, EG, Case → 3]` (explicit case index for
axiom 6) and a constraint-specified alternative with two simultaneous axiom-3
folds; the numeric solutions are printed as floats (`Line[0.9096, 1, -2]`).
§5: correctness proofs by Gröbner basis (`1 − gξ` trick) via Theorema, CAD
when inequalities appear. Confirms the numeric/symbolic split.

### Ida, *An Introduction to Computational Origami* (Springer, 2020)
The consolidated version of the Eos line, and the one to cite for the model.
Three things it adds over the 2007–2008 papers.

**The language has a name: Orikoto** ("a small programming language for
origami", §3.8.1, p. 74; §2.2.1, p. 21), a subset of Wolfram Language. One
command `HO` covers all seven rules by argument sorts (Table B.1, p. 208),
with named arguments (App. B.2, pp. 209–210): `Handle → P` picks the moved
face by a point on it and Eos infers the rest (Beloch's flap-typed `moving`),
`FoldLine → k` selects the k-th solution by index (Beloch's `toward`),
`Direction → Mountain`, `Mark`/`MarkAt` name intersection points, and
**`InsertFace → f` places the moved faces below a named face**, a
between-layers insertion that Beloch's Appendix B lists as sector-block
interleaving. Orikoto joins Doodle and Oridraw in the "origami language"
column of the related-work table, embedded like Caruana & Pace.

**Fold = tentative crease ∘ flat fold** (§7.2.2, p. 173, Fig. 7.3): the
abstract fold relation is the composition of a crease step and a
mountain-or-valley flat-fold step, and unfold has the identity as its crease
step. That is the `mark`/`fold` split of spec §4.6, published first here.

**The folded-state model, final form** (§7.3, pp. 175–186): an abstract
origami $(\Pi, \frown, \sqsupset)$ with faces as strictly convex $n$-gons
with a side (up/down by vertex order), adjacency by shared edge (Def. 7.4,
with the face-division axiom 7.1), *overlap* via a point of one face
overlaying a point of the other (Def. 7.5), *over* defined inductively per
fold with the moved set $\Pi_M$ computed by closure from the faces of concern
(Eq. 7.1, Def. 7.6), *above* as its transitive closure (Def. 7.7), and
*superposition* as immediate above (Def. 7.8); over is shown non-transitive
(Example 7.10). §7.4.1 adds *face stratification*: Eos squeezes unrelated
faces into as few levels as possible and notes this can fail when layers
would become cyclic (Problem 7.11). §7.4.3 folds the crane in Orikoto
(Fig. 7.19): inside-reverse folds are realised by splitting into
sub-origamis, folding mountain and valley separately and merging, and the
last two steps rotate by $\pi/2$ into 3D, for which "we need to extend the
model of AO for 3D. We do not discuss this extension" (p. 192). Same
boundary as ADR 0015.

**Arithmetic, confirmed:** §7.1 (p. 169) separates "algebraic and numeric
computation on geometric objects" from "symbolic and combinatorial
computation on discrete objects"; §4.4.3 prints the three axiom-6 fold lines
as decimals and says "the above values are approximations" (p. 107); a
footnote in Ch. 6 switches to `Rationalize[...]` "to avoid numerical errors"
(p. 151). Also useful: §3.7 (pp. 72–74) states the constructible-number
results (Engeler, Martin, Alperin 2000, Cox 2004: 2-3 towers), §3.6 the
general fold `Og` and Martin's finiteness condition, and §3.9 (p. 86) the
Huzita/Justin history: both in the 1989 Padova proceedings, Justin's paper
also in L'Ouvert 1986, Justin's set has O7. **Numbering trap:** Ida's O6 is
the simultaneous two-point fold and his O7 is Hatori's, so his O4–O7 do not
match Beloch's classic Justin order.

## Precedents before 2000

### Fisher, *Origami On Computer* (Honours thesis, University of Sydney, 1994)
**The closest precedent in shape to Beloch's action model, and the one ADR
0011's landscape check missed.** A textual language for folding sequences
of flat models plus a program that executes it (10 343 lines of C on
SunOS/X11, §7.2). Design principles (§3.1): no coordinates, no absolute
directions, everything named by vertices. Simple folds (§3.3.1) are `fold a
to b`, `fold a-b to c-d`, `fold a to b-c through d`, `fold along line(a,b)
moving c`, `fold at 45 degrees to ...`, with `and return` for a crease and
`unfold e-f moving v`; Fisher lists eight fold types and notes "all except
for the last one of these are the same as the ones arrived at by Huzita".
The moving part is implicit in the syntax, and mountain/valley is relative
to the viewpoint with `turn over` flipping it (§3.3.1, §3.5), which is
Beloch's derived M/V plus `flip`. Designed but unimplemented (§3.3.2, §3.5,
§3.8): `multifold e-f, g-h, mountain i-j, unfold k-l, reverse m-n holding
face(...)` with `between e1 and e2` for the crease that "appears when the
fold is done" (the rabbit-ear emergent crease `flatten` solves), `tucking A
under B` to disambiguate layering (Beloch's `over`), `tuck`/`untuck`,
`define name fold(...)` macros with `include`, `uses "preliminary-base"`.
Data structures (§6.1): vertex, edge and face hash tables; layering as a
full boolean above-matrix because "cyclic layering relationships can occur
in origami ... so it would not be possible to simply give each face some
kind of layer number" (the 2018 bookmark antipattern, refuted in 1994); a
per-step difference list for replay (§6.2). Algorithms (§5.1): attached
faces propagate through shared edges and through overlap-plus-above (valley)
or overlap-plus-below (mountain), the same rule as Eos's affected set and
Beloch's fold scope; crease-pattern folding by BFS two-colouring and
reflection along the tree (§5.2); three layering inference rules with a
contradiction check (§5.2). Limits he names: floats, with "infinite
precision values" as future work (§7.1, §8); vertices must be named at
creation via `creating e on a-b` because fold-created vertices have no
other handle (§3.4); multifold and tuck algorithms "not discovered" (§5.3,
§5.4). Beloch answers the first with the exact kernel, the second by naming
points through constructions, the third with `flatten`. Cites Alice Gray's
O.I.L. (1975) as an earlier written origami language (§2).

### Miyazaki, Yasuda, Yokoi & Toriwaki, "An Origami Playing Simulator in the Virtual Space" (JVCA 7:1, 1996)
The direct-manipulation simulator everyone after it builds on. Operations:
bending, folding up (180°), tucking in (symmetric inside reverse), curving.
Fold line = intersection of the face with the plane equidistant from the
picked vertex's old and new positions. Data structure (§"Folding without
curved faces"): a face-cell binary tree recording division history, a
face-cell look-up table per *face group* (faces in one plane) holding the
*face stack* order, edge-cell trees, vertex lists. Moved-face search (a)–(e):
connectivity, overlap on the rotating side, and for tucks the faces between
the two outside faces. Face-stack renewal: bending makes a new group,
folding up reverses the moved group and piles it on, tucking interleaves.
This is the ancestor of ADR 0017's coplanar clusters and of Eos's layers.

### Justin, "Aspects mathématiques du pliage de papier" (L'Ouvert 47, 1987)
The 1986 Strasbourg lecture, in French; the Padova 1991 proceedings carry
the same title. §II.1 lists four folding operations a)–d) (line through two
points, bisector of two lines, point onto line through a point, two points
onto two lines) and says they solve the general cubic and quartic. §I.2 is
the rabbit ear: fold a triangle along two bisectors and the segment to the
incentre and "un quatrième pli se forme naturellement", the emergent crease.
**§IV.2 is the origin of the layer conditions:** a *c-réseau* (crease
network: domain, nodes, creases, every node of even degree), the folding
map $\varphi$ as a composition of reflections along any path, the coherence
condition $\prod \sigma_i = I$ around every circuit (reducing to
Kawasaki's alternating angle sum when the sheet has no holes), the
*f-réseau* (its image) and the *s-réseau* (superposition network, the
preimage refinement), and then: the s-faces carry a partial order that must
satisfy combinatorial non-crossing conditions, with the conjecture that for
a sheet without holes these conditions suffice. §IV.3 gives the single-vertex
M/V count by a parenthesisation of the creases (e.g.
$(c_1(c_2c_3)c_4)c_5c_6$, 8 choices), §VI the stamp-folding counts and the
dragon curve. Also §IV.1: the "perfect base" and the Loiseau point of a kite,
Kawasaki's orizuru theory in embryo. Cite this for Justin's conditions
alongside [langdemaine2009facet]; the 1991 and 1997 versions are still
missing.

## Eos internals, completed

### Ida, Ţepeneu, Buchberger & Robu, "Proving and Constraint Solving in Computational Origami" (AISC 2004, LNCS 3249)
The first Eos paper with proof. §2 defines an origami as $\langle\chi,
R\rangle$, faces plus "the combination of overlay and neighborhood
relations", and declines to elaborate. §3.1 gives Huzita's six axioms as
existential formulas; "our computational origami system returns the
solution both symbolically and numerically, depending on the input". §4
trisects with `FoldBrBr[G, AE, A, IH]` and re-issues with `3` to pick the
case; for O1–O4 the system "computes a solution using the well known
mathematical formulas of elementary geometry rather than proving the
existential formulas". §5 proves trisection by Gröbner bases in Theorema
with the Rabinovich trick. The 2007–2020 papers supersede it on the model;
cite it as the origin.

### Ida & Takahashi, "Origami Fold as Algebraic Graph Rewriting" (J. Symbolic Computation 45:4, 2010)
Journal version of the SAC 2009 paper and the source of [ida2020] Ch. 7.
Same abstract origami $(\Pi, \frown, \sqsupset)$, fold as hypergraph
rewriting; §1 states plainly that the Eos implementation "relies very much
on algorithms which resort to mixtures of algebraic, numeric and symbolic
computing". Nothing beyond [ida2008synasc] and [ida2020] for Beloch.
