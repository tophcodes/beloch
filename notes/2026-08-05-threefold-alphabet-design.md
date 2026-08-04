# Three-fold alignment alphabet: the design space (Phase 2 decision memo)

**Status: decision prep, not a decision.** This memo lays out the possible
three-fold alignment alphabets, what each choice commits us to, and what it
costs — so that the alphabet decision (the spec's explicitly flagged
nested-reflection obligation, `docs/superpowers/specs/2026-08-03-multifold-axioms-research-design.md`,
Phase 2 / open question in `notes/2026-08-04-multifold-phase1-reproduction.md`)
can be made by a human who has read Alperin–Lang §4. Nothing here changes
code; the k=2 pipeline (`packages/multifold/lib/`) is the untouched baseline.

Every claim about the paper cites `[alperin2006, l. N]` = line N of
`refs/alperin2006.txt`. Every judgment call is marked **[judgment]**.

---

## 0. Notation (defined before use)

- **Folds.** Three simultaneous fold lines F1, F2, F3, each represented as a
  line (X, Y) with point set Xx + Yy + 1 = 0 [alperin2006, Def. 2,
  l. 177-178]. Six unknowns total → a valid 3FA is a minimal alignment set
  contributing **exactly 6 equations** (the k=2 argument [alperin2006,
  l. 308-311, 527-529] verbatim, with 4 → 6). Since every alignment kind
  contributes 1 or 2 equations, combos have **3 to 6 alignments** (k=2:
  "two, three, or four" [alperin2006, l. 527-529]).
- **Suffixes.** The paper's a/b suffix names which fold does the folding
  [alperin2006, l. 484-489]. At k=3 suffixes range over {a, b, c} ≙
  {F1, F2, F3}, and the suffix symmetry group is **S3** (all six relabelings
  of the three folds), not S2. I write F_i(·) for reflection across fold i,
  and use index notation AL5_{i→j} etc. in the body; a concrete symbol
  syntax is proposed in §2.1.
- **ρ_{ij} := F_i ∘ F_j**, the composition of two fold reflections — a
  rotation about F_i ∩ F_j by twice the angle between the folds (a
  translation if parallel). The k=2 mismatch note established that AL1, AL7,
  AL8, AL9 constrain *only* ρ = F_a∘F_b
  (`notes/2026-08-04-multifold-203-mismatch.md`, §R4). New at k=3: the three
  compositions are not independent — **ρ_{13} = ρ_{12} ∘ ρ_{23}**.
- **Word length.** Any alignment can be rewritten (Def. 12 style) as
  u(A) ↔ v(B) with u, v words in {F_1, F_2, F_3} and A, B given objects,
  fold lines, or virtual points. Its *total word length* is |u| + |v| after
  reduction. Two facts used throughout:
  - **Involution** F_i(F_i(·)) = id [alperin2006, l. 208-217].
  - **Incidence transport**: P ∈ ℓ ⟺ F_i(P) ∈ F_i(ℓ) (reflections
    preserve incidence — this is what makes F(P) ↔ L ≡ F(L) ↔ P
    [alperin2006, l. 279-283]).
  - Def-12 moves (applying some F_i to both sides [alperin2006,
    l. 476-478]) change each side's length by ±1, so the **parity of the
    total length is a Def-12 invariant**, and the minimal total length of an
    alignment's orbit is well-defined. "Nested" below always means: *every*
    Def-12-equivalent form has a word of length ≥ 2 on some given object,
    or a folded fold line aligned against a folded object.
- **Virtual points.** P_{ℓ,m} := the intersection point of lines ℓ and m,
  when at least one of them is a fold line (otherwise it is an ordinary
  derived given). A-L's AL10 uses exactly one shape of these — see §2.3.

---

## 1. What the k=2 alphabet actually is — a precise reconstruction

Before extending the alphabet we need to know what rule generated it. A-L
state their method in one sentence: "We consider the possible alignments
between points, lines, fold lines, and their folded images"
[alperin2006, l. 449-452], plus three explicit exclusions:

- **Parallelism** is not an alignment — verifying it needs infinite paper
  [alperin2006, l. 228-233].
- **Single-alignment-determines-a-fold** shapes (F(P1) ↔ P2 ≙ O2,
  F(L1) ↔ L2 ≙ O3) are omitted because any combination containing one is
  separable [alperin2006, l. 481-483].
- **F_a(L) ↔ F_b(L)** (same L) is not counted: same equations as
  AL2a + AL2b [alperin2006, l. 490-492]. Similarly at k=1, a line incident
  to the fold line is excluded — the fold must not already exist
  [alperin2006, l. 284-285] — and F_b(P_{LFa,L1}) ↔ P1 is dropped as
  decomposable into two listed alignments [alperin2006, l. 525-526].

Taking Fig. 4 [alperin2006, l. 501-521] at face value, the closure rule
that reproduces it exactly is:

> **(K2)** Alignments are incidences/coincidences where each side is a given
> point/line folded **at most once**, or a **bare** fold line, or (AL10) a
> virtual point P_{fold, given-line} folded once — with a **single
> exception**, AL1, where a folded fold line appears, aligned only *with
> itself*.

This is narrower than the sentence l. 449-452 suggests, in ways that matter
for k=3. Three findings from checking the boundary (each verifiable by hand
from the involution + incidence-transport lemmas):

### 1.1 Depth-2 images of *givens* against *given* targets are already in Fig. 4

This is the "no room anyway" half, and it is real. For given targets,
nesting is Def-12-redundant at k=2:

- F_a(F_b(P2)) ↔ P1 — apply F_a to both sides: F_b(P2) ↔ F_a(P1) = **AL8**
  [alperin2006, l. 515].
- F_a(F_b(L2)) ↔ L1 — same move: **AL9** [l. 517].
- F_a(F_b(P)) ↔ L — incidence transport: F_b(P) ↔ F_a(L) = **AL7** [l. 513].

So AL7/AL8/AL9 *are* the depth-2 alignments, written in split (1,1) form.
A-L never say this, but it means their alphabet's semantic span is "total
word length ≤ 2 over given objects" — and excluding nested *notation* costs
nothing there.

### 1.2 …but depth-2 against a *fold-line* target is silently missing

The same move fails when the target is a fold line and the outer letter
matches it:

- **F_aF_b(P) ↔ LFb** (i.e. ρ(P) lies on fold b's line). Transport with F_b
  gives F_bF_aF_b(P) ∈ LFb (longer); with F_a gives F_b(P) ∈ F_a(LFb) — a
  folded point against a folded *fold line*. No Def-12 form has ≤ 1
  reflection per side over the Fig.-4 object grammar. (The outer-letter-
  matches-target case *is* reducible: F_aF_b(P) ∈ LFa ⟺ F_b(P) ∈ LFa =
  AL5b, by F_a-invariance of LFa.) The line version F_aF_b(L) ↔ LFb behaves
  identically.
- **F_a(LFb) ↔ F_b(LFa)**. Writing the folds' angle as θ, AL1 is
  (F_aF_b)² = id ⟺ θ = π/2 (its component equations factor into
  perpendicular ∪ coincident, cf. the mismatch note §R2); this one is
  (up to the degenerate branch) **θ = π/3** — the next member of the same
  ρⁿ = id family. Finite-paper-verifiable (align two visible crease
  images), one equation, nondegenerate. Absent.
- Depth ≥ 3 on givens: ρ²(P) ↔ P′, or reflection across the derived mirror
  F_a(LFb) (word F_aF_bF_a) — by the parity/length invariant these can
  never reduce to total length ≤ 2, so they are structurally outside. The
  family {ρⁿ = id}, {ρⁿ(P) ↔ P′} is **infinite**: an alphabet closed under
  Def-12 with *no* depth cutoff does not exist as a finite object.
- In the virtual-point family: P_{LFa,L1} ↔ LFb (folds a, b and L1
  concurrent — 1 equation, unreflected virtual point on the *other* fold)
  is likewise absent from Fig. 4, though the reflected version onto a given
  line (AL10) is present.

**Conclusion of the check the prompt asked for.** Is F_a(F_b(P)) ↔ X
expressible/nonredundant at k=2? *Split answer:* for X a given point/line —
expressible, redundant (≡ AL8/AL7); for X = LFb (the inner fold's own
line) — inexpressible and silently absent. Did A-L exclude nesting silently
or structurally? *Both, at different depths:* their derivation grammar
(l. 449-452, one-step images of the object list) structurally never
generates nesting, and at depth 2 over givens this loses nothing (§1.1);
but the grammar also silently drops the irreducible leftovers of §1.2, and
the exclusion is **load-bearing for finiteness** (the ρⁿ slope). The paper
never acknowledges either fact.

**Consequence for k=3.** "No nesting" at k=3 is simultaneously
(i) a *faithful extension of their method* — the same one-step object
grammar, with the same silences — and (ii) a *genuine restriction we must
state*, because at k=3 (unlike k=2 §1.1) even given-target depth-2
alignments become irreducible: F_1F_2(P) ↔ F_3(P′) has minimal total length
3, and no Def-12 move brings both sides to depth ≤ 1 (parity + reduced-word
argument as in §0). Physically these are exactly "align the doubly-folded
flap's material with the third flap's image" — realizable in a 3-fold
model, where a region behind two creases moves by ρ_{ij}. The choice is no
longer free of casualties; it must be made and defended explicitly. That is
the decision this memo prepares. **[judgment**: the physical reading of
word-length ≤ k as "what k simultaneous flat creases can do to a paper
region" is my gloss, not A-L's; they explicitly ignore physical
realizability anyway (folds binding at intersections, l. 456-462).**]**

---

## 2. The k=3 design space

Three orthogonal-ish axes: (A) the single-reflection core, (B) nested
kinds, (C) virtual-point kinds. Each option below is a concrete alphabet
with an equation-count table (needed for the §3 size estimates).

### 2.1 Option A — the faithful single-reflection alphabet (45 symbols)

Apply rule (K2) with three folds. The ten kinds survive unchanged — only
their suffix multiplicities grow — plus exactly one genuinely new kind that
(K2) *permits* but k=2 could not instantiate.

| kind | shape | eqs | k=3 variants | S3 behaviour |
|---|---|---|---|---|
| AL1_{ij} | F_i(LFj) ↔ LFj ⟺ ρ_{ij}² = id | 1 | 3 (unordered {i,j}: involution makes F_i(LFj)↔LFj and F_j(LFi)↔LFi the same constraint, θ=π/2) | orbit of 3; each variant fixed by the transposition (ij) |
| AL2_i | F_i(L) ↔ L | 1 | 3 | orbit of 3; fixed by the (jk) transposition |
| AL3_i | LFi ↔ P | 1 | 3 | same |
| AL4_{i→j} | F_i(L) ↔ LFj | 2 | 6 (ordered, i≠j) | free orbit of 6 (no symmetry) |
| AL5_{i→j} | F_i(P) ↔ LFj | 1 | 6 | free orbit |
| AL6_i | F_i(P) ↔ L | 1 | 3 | fixed by (jk) |
| AL7_{i→j} | F_i(P) ↔ F_j(L) | 1 | 6 | free orbit |
| AL8_{ij} | F_i(P1) ↔ F_j(P2) | 2 | 3 (unordered: swapping folds = relabeling P1,P2, free under Def. 11 [alperin2006, l. 474-475]) | fixed by (ij) |
| AL9_{ij} | F_i(L1) ↔ F_j(L2) | 2 | 3 (unordered, same argument) | fixed by (ij) |
| AL10_{i→j} | F_j(P_{LFi,L1}) ↔ L2 | 1 | 6 (i = fold making the intersection, j ≠ i reflects; j = i is trivial — the point lies on its own mirror) | free orbit |
| **N1_{i;jk}** | **F_i(LFj) ↔ LFk**, i,j,k distinct | 2 | 3 (i chosen; {j,k} unordered by involution) | fixed by (jk) |

Totals: 30 one-equation + 15 two-equation = **45 symbols**. The general-k
count for the first ten kinds is k(11k−5)/2 (= 17 at k=2 ✓, 42 at k=3);
N1 adds k·C(k−1,2) more (0 at k=2 — which is why Fig. 4 couldn't contain
it — 3 at k=3).

**Why N1 belongs in the faithful core [judgment, but a strong one].** N1 is
"fold i lays crease j exactly onto crease k" — depth 1 on both sides, and
its Def-12 orbit stays depth-1. It generalizes AL1 exactly the way AL4
generalizes AL2: AL2/AL1 fold a line/fold-line onto *itself* (1 eq), AL4/N1
fold it onto *another* line (2 eqs). At k=2 both members of the AL2/AL4
pair exist; the AL4-analogue of AL1 needs a third line and so *could not*
appear in Fig. 4 — its absence there is vacuous, not an exclusion. Rule
(K2)'s "folded fold lines only in AL1" reading would drop it; I read that
clause as an artifact of k=2's poverty, not a principle. Physically it is
one of the most natural three-fold alignments there is. If the human
disagrees, option A0 = A minus N1 (42 symbols) is also costed in §3.

**Notation proposal [judgment].** Keep the paper's letters, folds a/b/c.
Symmetric kinds take an unordered suffix pair (AL1ab, AL8bc, N1a·bc);
nonsymmetric kinds take an *ordered* two-letter suffix, reflector first
(AL5ab = F_a(P) ↔ LFb; AL10ab = intersection on fold a, reflected by
fold b). Note this breaks the k=2 convention where "AL5a" left the target
implicit — at k=3 every non-symmetric suffix must name two folds. Combo
canonicalization = per-alignment canonical form, sort, then lex-min over
the 6 S3 relabelings (straight generalization of `Combo.canonical`'s
a↔b lex-min).

Carried-over exclusions, restated for k=3: no O1-O7-shaped alignments
(single alignment pinning a fold from givens) in the alphabet [alperin2006,
l. 481-483]; F_i(L) ↔ F_j(L) with the same L not counted (≡ AL2_i + AL2_j)
[l. 490-492]; parallelism excluded [l. 228-233]; all given objects distinct
per occurrence [l. 318-320], with the repeated-given caveat of §2.3.

### 2.2 Option B — admitting nested reflections

"With nesting" is not one option: without a cutoff the alphabet is infinite
(§1.2's ρⁿ slope). Two concrete cutoffs, chosen so that each has a
defensible rationale:

**B1 — minimal nesting: only the kinds the third fold *forces*
(A/C + 36 symbols).** Add exactly the depth-2 kinds that are irreducible
*because of the third fold* — those with no k=2 precedent either way. All
have i, j, k distinct; 6 variants each (ρ_{ij} ordered, k determined):

| kind | shape | eqs | reading |
|---|---|---|---|
| N4 | ρ_{ij}(P) ↔ LFk | 1 | doubly-folded point lands on the third crease |
| N5 | ρ_{ij}(L) ↔ LFk | 2 | doubly-folded line lands on the third crease |
| N8 | ρ_{ij}(P) ↔ F_k(P′) | 2 | doubly-folded point meets the third flap's point image |
| N9 | ρ_{ij}(L) ↔ F_k(L′) | 2 | line version |
| N10 | ρ_{ij}(P) ↔ F_k(L) | 1 | mixed |
| N11 | ρ_{ij}(L) ↔ F_k(P′) | 1 | mixed (not Def-12-equal to N10: different object types) |

The B1 rationale: it is the exact k=3 analogue of what §1.1 showed A-L's
alphabet *already contains* at k=2 (AL7/8/9 = depth-2-vs-given in
disguise), extended to the targets that k=3 newly makes irreducible.
Boundary discipline: reducible index patterns stay out (outer letter =
target's fold reduces to AL5/AL4-shapes; outer letter matching a folded
target's fold strips to AL8/AL7/AL9 — e.g. F_1F_2(P) ↔ F_1(P′) ⟺
F_2(P) ↔ P′, an O2 shape, separable). Kinds with a k=2 precedent of
*exclusion* stay excluded (next paragraph).

**B2 — the full per-side-depth-≤2 closure (~157 symbols, boundary
unstable).** B1 plus the kinds A-L demonstrably had available at k=2 and
left out (N2: ρ_{ij}(P) ↔ LFj, 6 variants, 1 eq; N3: line version, 6, 2 eq;
N6: the θ=π/3 kind F_i(LFj) ↔ F_j(LFi), 3, 1 eq — **[judgment]** counted
as 1 equation by analogy with AL1's degenerate-branch factoring, needs
actual derivation), plus fold-line chains (N7: F_i(LFj) ↔ F_j(LFk), 6
variants, 2 eq), plus the depth-2-vs-depth-2 family
(ρ_{ij}(X) ↔ ρ_{kl}(X′) with different outer letters: 12 point-point + 12
line-line + 24 point-line = 48 symbols; this includes ρ²(P) ↔ P′ in the
disguise ρ_{12}(P) ↔ ρ_{21}(P′)). Two warnings, both load-bearing:

1. **The closure leaks.** Example: F_2F_3(P) ↔ F_1(LF2) is per-side
   depth-(2,1) — surface-admissible — but its Def-12 orbit's canonical
   form is a *3-letter* word against a bare fold line. Whether it is "in"
   B2 depends on grammar details invisible at the surface. Hand-enumeration
   of B2 is unreliable; any nested option needs a mechanical Def-12
   canonicalizer over words *before* alphabet enumeration, i.e. real
   implementation work upstream of the candidate generator. The 157 is an
   estimate of one particular cutoff, ±a handful of borderline kinds.
2. **No non-arbitrary stopping point.** B2 excludes depth-3 words
   (F_1F_2F_3(P), realizable by a region behind all three creases), which
   partially reduce into B1's span against given targets
   (F_iF_jF_k(P) ↔ P′ ⟺ F_jF_k(P) ↔ F_i(P′) = N8) but not against fold
   targets. Every cutoff needs its own defense; the only principled-looking
   one I see is "words realizable as layer maps of k simultaneous creases"
   (distinct-letter words, length ≤ k) — attractive, matches A-L's span at
   k=2 for givens, but it is a research question of its own, and A-L
   explicitly disclaim physical realizability as a criterion
   [alperin2006, l. 456-462]. **[judgment]**

**On faithfulness:** A-L's k=2 choice, read semantically (§1), excluded
N2/N3/N6-type alignments while including their given-target cousins. B1
respects that precedent; B2 overrides it. If we pick any B, the paper we
write must say "A-L's alphabet, extended by the following closure rule" and
own the rule — there is no reading of [alperin2006] under which B2 is
*their* method.

### 2.3 Option C — extended virtual points (A + 7 symbols)

**AL10's precise k=2 definition** (the check requested): the virtual point
is P_{LFa,L1}, "the intersection of the first fold line FLa with the
existing line L1" [alperin2006, l. 493-496] — fold line ∩ *given* line,
never fold ∩ fold — reflected by the *other* fold onto a second given
line: F_{LFb}(P_{LFa,L1}) ↔ L2. It comes in a and b varieties [l. 493-494].
Two boundary remarks in the paper pin down the family's intended scope:

- **L1 = L2** "forces the intersection of the two fold lines with each
  other to lie on the given line" [l. 496-498] — i.e. the *fold ∩ fold*
  virtual point on a given line is reachable at k=2 only as a
  repeated-given special case of AL10, not as an alphabet citizen.
- The point-target version decomposes and is excluded [l. 525-526].

At k=3 the fold∩fold point stops being a curiosity: **F1 ∩ F2 is a point
that F3 can act on**, which k=2 could never do (each fold fixes the
intersection it participates in). The natural new kinds:

| kind | shape | eqs | variants | note |
|---|---|---|---|---|
| V1 | F_k(P_{Fi,Fj}) ↔ L | 1 | 3 ({i,j} unordered, k the third fold; k ∈ {i,j} is trivial — point on own mirror) | genuinely k=3-new |
| V2 | P_{Fi,Fj} ↔ LFk | 1 | 1 (fully symmetric: three folds concurrent) | k=3-new |
| V3 | P_{Fi,Fj} ↔ L | 1 | 3 | = A-L's L1=L2 reading of AL10, first-class |

Excluded, for k=2 consistency **[judgment]**: P_{Fi,L} ↔ LFj (three-line
concurrency with a given line — this shape was *available* at k=2 and
absent from Fig. 4, §1.2), reflected-virtual-point-onto-fold-line kinds,
virtual points of folded lines, and iterated virtual points. Note the
asymmetry with the N1 argument: V1/V2/V3 could not exist at k=2 (absence
vacuous → fair game), P_{Fi,L} ↔ LFj could and didn't (precedent of
exclusion). Also note a cross-option dependency: with V2 in the alphabet,
the B2 kind "F_i(LFj) ↔ F_k(LFj)" decomposes as AL1_{ik} + V2-on-LFj
(rotation fixing a line ⟺ half-turn about a point of it) — mirroring the
paper's own AL10 decomposition move [l. 525-526]; without V2 it would be
irreducible. Alphabet options are not independent.

**The decisive fact for option C: the paper's own three-fold construction
needs it.** A-L's §8 quintic [alperin2006, l. 936-954] is the only k=3
axiom in the literature. Its alignment content: AL6 on fold a, AL6 on fold
b, then fold c "perpendicular to Fa (AL1) so that the fold intersection
lies on CD (AL10) and is perpendicular to Fb (AL1) so that the fold
intersection lies on BC (AL10)" [l. 950-953] — in k=3 terms:
{AL6_a, AL6_b, AL1_{ac}, AL1_{bc}, V3_{ac}, V3_{bc}}: six alignments,
1+1+1+1+1+1 = 6 equations ✓ (the general-n bookkeeping 2(n−2) is theirs,
[l. 962-970, Thm. 1]). The "AL10" steps are fold∩fold-on-a-given-line, i.e.
V3 — usable at k=2 only via the repeated-line trick, which our machinery
**cannot express**: `Symeq.param_stream` deliberately draws every given
fresh (`packages/multifold/lib/symeq.mli`, the documented limitation citing
[alperin2006, §6.2.3]). So under strict option A, *the one published 3FA is
not in the enumeration's language.* Either V3 becomes first-class, or
Symeq grows repeated-given support — a formalization decision in its own
right (first-class V3 keeps the genericity story clean; repeated givens
change what "generic parameters" means mid-enumeration). This is the
strongest single argument in this memo, and it makes "A alone" very hard
to defend: the §8 combo is simultaneously the only available *validation
target* for the k=3 pipeline (the one axiom whose existence and complexity
the paper vouches for).

Mirroring A-L's own with/without-AL10 twin counts (489/203 [l. 541-542]),
whatever we choose should be enumerated both with and without the V-kinds —
cheap, and gives the paper comparable numbers.

---

## 3. Equivalence and validity at k=3

### 3.1 Definitions 10-12, lifted

- **Def. 11 (permutation)** [alperin2006, l. 474-475]: unchanged for given
  objects; fold relabeling grows from S2 to **S3**: canonicalization minimizes over
  6 relabeled images instead of 2. The k=2 finding that A-L's equivalence-as-applied does
  *not* include the σ-move (renaming a fold as its own mirror image —
  proven by AL2a5a8 and AL2a3b8 both appearing in the 489;
  `notes/2026-08-04-multifold-203-mismatch.md`, Def-12 follow-up §1)
  carries over: keep σ out, at all three folds, for comparability.
- **Def. 12 (folding)** [l. 476-478]: now three generators F_1, F_2, F_3
  applicable to both sides of any alignment. Involution and incidence
  transport are unchanged. New at k=3: transport can move an alignment
  *between* §2's option classes (§2.2's leak), so per-alignment orbit
  canonicalization must run before combo canonicalization. For options
  A/C this is trivial (orbits within the alphabet are singletons up to the
  baked-in identities); for any B it is the canonicalizer flagged above.
- **Def. 13** [l. 958-961] already defines N-fold axioms; Def. 9's
  "finite region of the Euclidean plane" [l. 453-455] and the minimality
  requirement carry over with 4 → 6.

### 3.2 Separability: the split shapes (R1 at k=3)

Def. 10 [l. 467-468] in the *sequential* reading that Phase 1 established
(R1; forced by the Abe example [l. 470-473]): a combo is separable iff some
proper subset of folds can be pinned first, from givens alone, after which
the rest is a valid lower-fold axiom that may use the pinned folds as
ordinary given lines. The DOF ledger (each fold = 2 DOF) fixes the possible
split shapes exactly:

- **2 + 4** — one fold pinned first (2 eqs from givens alone), remainder a
  2FA on the other two. Since the only kinds mentioning a single fold are
  AL2/AL3/AL6 (1 eq each; O2/O3 shapes are excluded from the alphabet),
  the syntactic test is the direct R1 lift: *some suffix carries ≥ 2
  single-fold alignments*.
- **4 + 2** — two folds pinned first by a genuine 2FA (4 eqs among
  alignments whose suffixes ⊆ {i,j}), remainder a 1FA for the third fold
  (which may reference F_i, F_j as given lines — every alphabet alignment
  becomes a one-fold alignment once its other folds are known lines, the
  k=2 argument verbatim, mismatch note §R1).
- **2 + 2 + 2** — fully sequential; a refinement of both shapes above,
  no separate test needed.
- **3 + 3 is impossible**: 3 equations can neither pin one fold
  (overdetermined, 2 DOF — generically inconsistent, dies at the Jacobian
  step anyway) nor two folds (underdetermined, 4 DOF — the remaining 3
  equations stay coupled). Splits must respect the 2-DOF-per-fold ledger.
- "One-fold-then-2FA" and "2FA-then-one-fold" from the task statement are
  exactly the 2+4 and 4+2 shapes.

Uniform statement subsuming all of it — proposed as the k=3 separability
rule: **for every proper nonempty fold subset S, let E(S) = total equations
of alignments whose suffixes ⊆ S; the combo is separable iff E(S) = 2|S|
for some S, and invalid (overdetermined) if E(S) > 2|S|.** At k=2 with
S = {i} this is precisely R1 (the "≥ 2" versus "= 2" difference only
affects combos that are invalid anyway). Also require every fold to be
mentioned at all (else underdetermined). **[judgment**: the rule's "=" vs
"≥" bookkeeping and the claim that E(S) > 2|S| always dies at the Jacobian
step should be re-verified once the pipeline exists.**]**

### 3.3 Degeneracies (R2 at k=3)

The k=2 rule "reject AL1 × {AL4, AL5, AL8, AL9}" (mismatch note §R2)
transplants *pairwise*: AL1_{ij} forces F_i ⊥ F_j, under which AL4/AL5/AL8/
AL9 *on the pair {i,j}* rewrite to separable/duplicate/degenerate forms by
the same alignment-by-alignment derivations. AL5_{i→k} etc. (third fold
involved) are untouched. But the pairwise transplant is **not sufficient**;
genuinely new k=3 interactions exist and need their own worked derivations
in Phase 2:

- **{AL1_{12}, AL1_{13}, AL1_{23}} is inconsistent** — three pairwise
  perpendicular lines don't exist in the plane.
- **AL1_{ij} + AL1_{ik} forces F_j ∥ F_k**: then P_{Fj,Fk} is undefined
  (kills any V-kind on that pair, and AL10-with-repeated-given readings),
  ρ_{jk} degenerates to a translation (AL8_{jk}/AL9_{jk}/N-kinds on that
  pair change character — AL9_{jk} generically inconsistent as at k=2, the
  AL8_{jk} translation case needs derivation), and the paper's own §8
  construction *contains* exactly this pattern (AL1_{ac} + AL1_{bc} ⟹
  F_a ∥ F_b) — so "reject double-AL1" would reject the quintic axiom. The
  correct rule is finer than any k=2 precedent. **[judgment**: expect R2 at
  k=3 to be a small table of derived interactions, not one rejection
  clause; deriving it is a Phase-2 task of its own.**]**
- ρ_{13} = ρ_{12}∘ρ_{23} creates cross-pair dependencies among AL7/8/9/N
  alignments on *different* pairs that have no k=2 analogue at all; no
  syntactic rule is proposed here — the Jacobian/msolve stage must catch
  the rank collapses, and §4's R4 discussion applies.

### 3.4 Algebra (R3, mechanical)

Six unknowns x_1,y_1,…,x_3,y_3 (plus Rabinowitsch variable); saturate all
three isotropic factors x_i² + y_i² alongside the chart denominators —
the k=2 lesson (mismatch note §R3) applied three-fold. Strict filter
unchanged: `Zero_dim { count >= 1; multiplicity_free }`; realness reported
per stream, never filtered (the addendum's argument is
parameter-count-independent and applies verbatim).

---

## 4. Size estimates (the spec's upper-bound milestone, k=3 arm)

Counting method: multisets over the alphabet whose equation counts sum
to 6, split by number of 2-equation symbols. Validated by reproducing the
recorded k=2 raw count exactly (2194, `notes/2026-08-04-multifold-phase1-reproduction.md`;
throwaway script under /tmp, not committed, per the Phase-1 convention).

| option | alphabet | 1-eq / 2-eq | raw multisets (Σ = 6 eqs) | by size 3/4/5/6 |
|---|---|---|---|---|
| k=2 check | 17 | 13 / 4 | **2,194** ✓ | 10 / 364 / 1,820 / — |
| A0 = A minus N1 | 42 | 30 / 12 | **2,150,834** | 364 / 36,270 / 491,040 / 1,623,160 |
| **A** (faithful single-reflection) | **45** | 30 / 15 | **2,293,440** | 680 / 55,800 / 613,800 / 1,623,160 |
| **C** = A + V1-V3 | **52** | 37 / 15 | **6,701,676** | 680 / 84,360 / 1,370,850 / 5,245,786 |
| **B1** = C + minimal nesting | **88** | 55 / 33 | **64,935,255** | 6,545 / 863,940 / 14,000,910 / 50,063,860 |
| B2 = full depth-2 closure (estimate) | ~157 | 88 / 69 | **956,174,009** | 57,155 / 9.46M / 184.4M / 762.2M |

Reading these against the spec's "~10⁴ or ~10⁸" question: the faithful
options land at **~2×10⁶ – 7×10⁶ raw**, nesting at **6.5×10⁷ – 10⁹**. For
scale, k=2 went 2,194 raw → 566 canonical non-separable → 489: S3
canonicalization (÷ ≤ 6) plus the syntactic R1/R2 rules will cut hard, but
even optimistically options A/C leave **10⁵-10⁶ msolve calls** on 7-variable
systems (vs. 566 four-variable systems at k=2) — likely days-to-weeks of
compute or real pruning work (e.g. solve only canonical representatives,
cheap syntactic prescreens, degree bounds). B1 leaves ~10⁷: **the spec's
Phase-2 explosion fallback (restrict to a defensible subclass) presumably
triggers for every nested option**, and is at least under discussion for C.
That is itself a decision-relevant fact: choosing B is choosing the
fallback subclass path. Note these totals are candidate counts, not final
axiom counts; nothing here predicts the k=3 analogue of 489.

---

## 5. Recommendation and what the human must decide

**Recommendation [judgment, all of it]: adopt option C (45-symbol faithful
single-reflection core + N1 + the 7 fold∩fold virtual-point symbols) as the
Phase-2 primary alphabet; enumerate with and without the V-kinds; treat B1
as an explicitly-scoped extension enumeration, only if time allows, over
the restricted subclass the spec's fallback anticipates.** Reasons, in
order of weight:

1. The §8 quintic must be expressible (§2.3) — it is the only published
   3FA, our only external validation point, and it needs V3 (or
   repeated-given machinery) plus pairwise AL1. Option A fails this test.
2. C stays inside A-L's derivation grammar (§1's rule K2, with the N1 and
   V-absence-is-vacuous readings argued above), so the headline result
   remains "the k=3 analogue of Alperin-Lang's 489, by their method" —
   maximally comparable, minimally defensible-surface.
3. Every nested option needs (a) a mechanical Def-12 word canonicalizer,
   (b) a defended depth cutoff, (c) the fallback subclass — three research
   obligations before the first candidate is generated. That is a second
   project. Deliberately excluding nesting, *stated as a scoping decision
   with §1.2's honest accounting of what it drops* (including the
   physically natural N4/N8 alignments and the θ=π/n family), is the
   publishable-this-cycle path.

**Decisions the human must make after finishing §4** (none are mine to
make):

1. **The nesting decision** (the spec's flagged obligation). Accept
   "single-reflection only, stated as a restriction" (A/C), or require a
   nested tier (B1)? §1 gives the evidence: faithful-to-the-method AND
   genuinely restrictive are both true; the paper draft must say which
   claim we make. If B1: accept the canonicalizer + cutoff + subclass
   obligations now.
2. **N1 in or out** — is my "absence at k=2 is vacuous" argument (§2.1)
   convincing against the strict reading of (K2)? A0 vs A changes little
   in size (2.15M vs 2.29M) but changes the alphabet's character claim.
3. **V-kinds and the repeated-given question**: V3 first-class vs teaching
   `Symeq.param_stream` deliberate repeats (§2.3). Also whether V1/V2 ride
   along (my inclusion rests on the same vacuous-absence argument, plus
   the V2-enables-decomposition observation).
4. **Excluded-with-precedent kinds** (N2/N3/N6, P_{Fi,L}↔LFj): confirm
   that following A-L's silent k=2 exclusions is the right call, knowing
   they were silent (§1.2) — or decide the k=3 paper should *document*
   them as known omissions of the method (my preference: document,
   exclude).
5. **The R4-analogue stance — flagged as the no-oracle risk.** At k=2, R4
   was an empirical filter reproducing a printed list; three of its five
   exclusions (AL2ab8, AL2a7a9, AL2a7b9) now look like axioms *missing
   from the paper* (mismatch note, Def-12 follow-up). At k=3 there is no
   list: no R4 can exist. The analogous danger zone is real and larger —
   combos where no alignment anchors any fold's position to a given (all
   constraints through directions and the ρ_{ij}, which are themselves
   dependent via ρ_{13} = ρ_{12}ρ_{23}) will produce borderline cases with
   nothing to arbitrate them. Proposal: define validity *algebraically and
   definitionally* in the theorem statement (exactly 6 equations, minimal,
   non-separable per §3.2, R2-table clean, zero-dimensional,
   multiplicity-free at ≥ 2 independent parameter streams; realness
   reported, existential-realness stated as open per the Phase-1
   addendum), publish that count as primary, and report the
   "ρ-only-anchored" subclass separately with hand geometric spot-checks
   of a sample (the AL2ab8 Q-construction treatment). The human should
   sign off on this being the claim structure — it is weaker than "the"
   classification, and honest about why.
6. **Compute budget / fallback trigger** given §4's numbers: accept a
   10⁵-10⁶-call msolve campaign for C, or pre-commit to a subclass?

Also carried, unchanged, from Phase 1: the Origami⁴ book-version check
(Fernleihe pending) — it bears on the k=2 oracle and thus on how much
weight "comparability with the 489" should carry at all.
