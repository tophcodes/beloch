# Origami⁴ prior art: what the 2009 proceedings change for Beloch

**Question:** Fourteen chapters of *Origami⁴* (4OSME proceedings, A K Peters
2009) arrived in `refs/` on 2026-09-09/10 (see
`refs/origami4-scans/INGEST-REPORT.md`). Which of them are prior art for the
language, and how should Beloch build on them?

**Verdict:** Two chapters move the related-work picture: Eos [ida2009eos] is
a second, stronger system precedent beside Caruana & Pace, and Lam's survey
[lam2009] shows that "origami-oriented languages" already existed in 2009, so
the novelty claim is the combination of three qualifiers, spelled out in §1. The
layer-ordering chapters give Beloch's derived M/V a citation and a
correctness criterion. The rest supplies examples, oracles and a maneuver
catalogue.

## 1. Language and system prior art

### Eos (Ida et al.)

Eos is a Mathematica package plus web front end. Its fold functions are the
axioms [ida2009eos, Table 1, p. 287]:

| Eos call | Beloch |
|---|---|
| `Fold[A, Along→PQ]` | `fold` along `through .p .q` |
| `Fold[P,Q]` | `map .p onto .q` |
| `Fold[PQ,EF]` | `map --pq onto --ef` |
| `Fold[A, AlongPerpendicular→{P,EF}]` | `perp` |
| `Fold[P,EF,Through→Q]` | axiom 6, `map .p onto --ef through .q` |
| `Fold[P,EF,Q,GH]` | axiom 7, `map .p onto --ef and .q onto --gh` |
| `Fold[P,EF,AlongPerpendicular→GH]` | axiom 4 form |

Multiple solutions are resolved by showing the cases and re-issuing the call
with a case index [§3, p. 288]. Beloch resolves by geometry (`toward`), which
is stable under parameter change; a case index is not. That is a defensible
design difference worth one paragraph in the paper.

Eos folds the crane with five artistic folds [§4, p. 290–291]:
`MountainFold`, `ValleyFold`, `InsideReverseFold`, `OutsideReverseFold`,
`SquashFold`. Beloch's Appendix B lists the same maneuvers as future work, so
the crane milestone has a known minimum vocabulary: valley, inside reverse,
squash.

Eos proves construction correctness automatically [§5, p. 291]: premises and
conclusion as polynomial systems, Gröbner bases for equalities, cylindrical
algebraic decomposition when inequalities appear. Beloch has kernel-verified
identities (Messer's $(AC/CB)^3 = 2$) and nothing like a proof pipeline.
State this plainly in the comparison.

**Folded state and arithmetic** (from the Eos internals papers, obtained
2026-09-10): Eos's folded state is the abstract origami
$(\Pi, \succ, A)$
[ida2007modeling]: convex faces, an overlay relation defined only on
overlapping pairs and inherited per fold by the three-case rule of its Def. 7
(both stayed, both moved with the order reversed, one of each ordered by
valley or mountain), and adjacency. Layers are classes of adjacent
same-orientation faces, the coplanar clusters of ADR 0017. The fold scope is
a user-given set of faces of concern propagated through adjacency and
"overlapping and above" (Def. 6), the counterpart of `moving` and `up to`.
This is structurally the same model as Beloch's layer order, published two
years before ADR 0011, and the paper must cite it as such. The difference is
arithmetic: Eos interprets the axioms over algebraic numbers on paper
[ida2008entcs, §3.2] but solves numerically for the simulation and keeps the
constraints symbolically for the proof [ida2008entcs, §5, §7; ghourabi2007,
§4]. Beloch's folded state is itself exact. Ida's 2020 book [ida2020]
consolidates this (Ch. 7) and adds two things: the abstract fold is the
composition of a tentative crease and a
flat fold (§7.2.2), which is the `mark`/`fold` split, and the command
reference (App. B.2) has `InsertFace → f` for placing moved faces below a
named face, the between-layers insertion Appendix B calls sector-block
interleaving. Still missing: the AISC 2004 paper (DOI
10.1007/978-3-540-30210-0_12).

### Fisher 1994: the precedent ADR 0011 missed

Fisher's honours thesis [fisher1994] is a standalone textual language for
folding sequences of flat models with an interpreter that maintains a folded
state: `fold a to b`, `fold a-b to c-d`, `fold a to b-c through d`, `fold
along line(a,b) moving c`, `and return` for a crease, `unfold`, `turn over`.
The moving part is implicit, mountain/valley is relative to the viewpoint,
the layer order is a full above-matrix because layering can be cyclic, and
the folding sequence is stored as a per-step difference list for replay. He
maps his fold types to Huzita's operations himself. Designed on paper and
left unimplemented: `multifold ... holding face(...)` with `between e1 and
e2` for the crease that appears on its own, `tucking A under B` to fix an
ambiguous layering, `define ... fold(...)` macros. What he did not have:
exact arithmetic (floats, "infinite precision" named as future work), a
solver for the emergent crease, an interchange format. ADR 0011's
"landscape check found the combination unoccupied" (2026-06-29) is wrong
for 1994; the paper must cite Fisher as the closest shape precedent and
state Beloch's delta against him.

### Origami-oriented languages before Beloch

The oldest is Smith's O.I.L. [smith1975oil], a written language for human
folders: point coincidences with the layer count on the arrow, folds made
between layers for reverses and sinks, points defined from the existing
model by fractions, offsets, intersections and rotations, and "the smallest
number of creases to flatten the model" assumed. Fisher's two objections,
renumbering every step and opaque symbols, are what persistent point names
answer.

Lam's taxonomy [lam2009, §4.2, p. 241] has a category "origami-oriented
languages": Oridraw (1999), Doodle (Gout 2001), and Fisher's 1994 system.
Oridraw and Doodle compile text to PostScript diagrams, and Lam's criticism is
that the user
still manages the positions of lines, vertices and polygons by hand. Eos's
language also has a name, Orikoto [ida2020, §3.8.1], a subset of Wolfram
Language with one `HO` command and named arguments (`Handle`, `FoldLine`,
`Direction`, `InsertFace`); it is embedded, like Caruana & Pace.

Consequence for the "empty niche" line: Beloch is a standalone language
whose primitives are the axioms, whose folded state and layer order are
derived from the actions, and whose geometry is exact. Fisher had the first
three qualities in 1994 as a prototype; Eos and Caruana & Pace have the
axioms without a standalone language; the simulators have the folded state
without a language. Beloch's delta is exact geometry, the emergent-crease
solve, FOLD output, and a finished implementation of what Fisher designed.

### Two quotes that carry the thesis

- eGami tools are operation-driven, and "one could theoretically reproduce
  the entire folding sequence simply from the starting paper configuration
  and the history of operations, although this is not how it is implemented
  in practice" [fastag2009egami, §3.3, p. 281]. Beloch makes that history the
  source artefact.
- The first disadvantage of direct manipulation: "the user can only
  manipulate what he/she can see", and "the user cannot distinguish multiple
  layers" [lam2009, §5.4, p. 244]. That is the usability case for explicit
  layer selection (`up to`, `#[…]`) in text.

## 2. Layer ordering

Lang & Demaine [langdemaine2009facet] describe the stacking order of a
folded form as a directed **ordering graph** on facets (edge $(F_i, F_j)$ iff
$F_i$ lies over $F_j$), reduce it to an acyclic ROG, and derive M/V from a
two-colouring of facets plus the order [§3.3–3.4]. Their closing remark names
"the primacy of the ordering relationship, rather than the crease assignment,
as the fundamental mathematical description" [§4]. This is ADR 0011's
"mountain/valley is derived" in print; cite it there.

The four **Justin conditions** on overlapping facets [§3.1, Fig. 5] are the
flat-foldability criterion beyond Kawasaki and Maekawa. Their origin is
[justin1987, §IV.2]: the s-faces of the superposition network carry a
partial order subject to non-crossing conditions, conjectured sufficient for
a sheet without holes. Beloch's `flatten`
checks Kawasaki, Maekawa and "layer-order validity"; the follow-up is to
state that validity check in terms of the Justin conditions (Konjevod's
crossing types W, X, Y [konjevod2009ip, §2.4] are the same conditions in
different clothing) and to test it against them. The 1987 L'Ouvert version is
in `refs/`; the 1991 Padova
version Lang & Demaine cite and the 1997 "Towards a mathematical theory of
origami" are not.

Konjevod also calibrates the alternative: a 2×2 iso-area chessboard as an
ILP takes hours [konjevod2009ip, §3]. Beloch's order comes from the action
sequence and never searches. The FOLD `faceOrders` array Beloch emits is
Lang & Demaine's ordering graph restricted to overlapping pairs.

## 3. Examples, oracles, vocabulary

- **Heptagon** [ida2009eos, §3]: the same construction in Eos and Beloch
  side by side, axiom 6 with case choice versus `toward`. Cheapest
  head-to-head example we have.
- **Generalised fish base** [azuma2009fishbase, §2.3]: on a kite, the two
  pattern vertices are isogonal conjugates, so Kawasaki holds at both by
  Apollonius' tangent-angle relation. Needs a kite paper shape; then
  `flatten` at each vertex verifies flat foldability exactly, for a whole
  parametric family.
- **Bird base from a tangential quadrilateral** [kawasaki2009orizuru,
  Theorem 1, p. 436]: foldable iff an inscribed circle exists, centre on a
  conic. Target for multi-vertex `flatten`.
- **Fujimoto fifths** [veenstra2009, Eq. 1, p. 407]:
  $l_{k+1} = \tfrac{1}{2}(l_k + c_k)$, $c_k$ from the parity of $n l_k$; the
  number of distinct creases is the order of 2 mod $n$. The concrete demand
  for a loop primitive. With exact rationals each pinch mark is a dyadic
  fraction, and the program can assert the crease count.
- **Single-vertex oracle** [hull2009configspace, §1]: $C(v)$, the number of
  valid M/V assignments at a flat vertex, is linear-time computable with
  $2^n \le C(v) \le 2\binom{2n}{n-1}$. Use it to check `flatten`'s
  enumeration count.
- **Maneuver catalogue** [fastag2009egami, Table 1, p. 276] union the five
  Eos folds: the checklist for Appendix B. eGami names valley-under and
  mountain-under as distinct tools; Beloch expresses those as scope
  (`up to`), which is a point for the design discussion.
- **3D later**: Watanabe & Kawaguchi's rigid-foldability test and Tachi's
  angle-projection simulator are the references when ADR 0015's standing
  state lands. Halloran is out of scope.

## 4. Alperin & Lang: version of record

Checked separately in
[`2026-09-10-origami4-version-of-record.md`](2026-09-10-origami4-version-of-record.md):
the typeset chapter is a copyedit of the Dec-2006 preprint, the 489-symbol
listing matches our fixture, the five strict-valid symbols our pipeline
produces are absent in the book too, and the eq. (2) misprint is printed
identically. The discrepancy is ours to explain against the version of record.

## Follow-ups

- Obtain for `refs/`: Justin 1991 (Padova) and 1997 (Otsu); Gout, Doodle
  (2001).
- ADR 0011's context paragraph claims the landscape was unoccupied; a
  follow-up note there should point at [fisher1994].
- Cite [langdemaine2009facet] and [ida2007modeling] in ADR 0011 and phrase
  `flatten`'s layer validity check as the Justin conditions.
- Examples backlog: heptagon, generalised fish base (needs `paper kite`),
  Fujimoto fifths (needs loops, or an unrolled n = 5).
- 9OSME: the call for papers lives at 9osme.org, a client-rendered app; read
  it in a browser.
