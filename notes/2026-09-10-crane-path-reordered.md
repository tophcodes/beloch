# 2026-09-10: Crane path reordered around the inside reverse fold

Decision (Toph): the crane milestone takes the Eos route. The critical path
is **Inside Reverse Fold → Bird Base → Crane**; squash and petal become a
second route to the same bird base, and the outside reverse fold leaves the
path entirely. Issues #29–#35 and milestones 1–7 carry the new positions.

## What changed the ladder

The ladder in the issues (Even Bases → Squash → Petal → Bird Base → Inside
Reverse → Outside Reverse → Crane) follows the diagrams every folder knows.
The Origami⁴ prior-art pass (`2026-09-10-origami4-prior-art.md`) turned up a
shorter route in print.

Eos folds the crane with three commands: `ValleyFold`, `MountainFold`,
`InsideReverseFold` [ida2020, §7.4.3, Fig. 7.19, p. 192–193]. Diagonal as a
valley fold; two inside reverse folds make the preliminary base; four inside
reverse folds on the preliminary base's lower corners make the bird base, which
replaces the petal fold; valley and mountain folds narrow the legs; three more
inside reverse folds make neck, tail and head. Steps 18 and 19 open the wings
with a face rotation of $\pi/2$, which is 3D and outside ADR 0015. Squash and
petal do not occur.

Ida also describes how Eos realizes the reverse fold: split the origami into
two sub-origamis, mountain-fold one and valley-fold the other, merge, and
calls this "substantially complicate[s] the modeling" [ida2020, §7.4.3,
p. 192]. Fisher's `multifold` had a `reverse` specifier for exactly this case,
an already-folded edge that flips its fold type during a multiple fold
[fisher1994, §3.3.2]. That is the shape Beloch's `flatten` already has: bare
elements are solver-assigned, `mountain`/`valley` are constraints, and the
stayer is named or implied.

Consequence: one new maneuver reaches the crane instead of three.

## Verified today

The preliminary base runs on the current evaluator as a single-vertex
`flatten` (`examples/bases/preliminary.bel`, added with this note; the
earlier `waterbomb.bel` was deleted in the staying redesign and nothing had
replaced it). Getting it right took three attempts, and the wrong two are
worth recording because face counts do not tell them apart:

- **Eight rays folded** (both diagonals and both medians) gives eight
  coincident triangles in one 45° wedge with all 28 face orders. That is the
  base folded in half along its spine, one wedge, not a square.
- **The four medians alone**, diagonals as flat marks, gives the square
  outline with all four quarters flat and both sides stacked in the same
  order, one flap wrapping the other. That is the quarter fold (halve twice),
  which becomes the base only after a squash.
- **Six rays**: the four medians plus the half-diagonals toward `.b` and
  `.d`, the diagonal through `.a` and `.c` marked but flat. Kawasaki holds
  (45 + 90 + 45 on each alternation), Maekawa gives four and two. The
  resulting stack, read out of `faceOrders` with the FOLD sign convention
  (the sign is relative to the *second* face's normal): the `a`-quarter is
  the flat front face spanning both sides, the `c`-quarter the flat back,
  the `b`-quarter a two-layer taco on one side and the `d`-quarter a taco on
  the other, each sandwiched between front and back. That is the book-page
  structure of the preliminary base: four two-layer flaps around the spine,
  two per side, none wrapping another.

Two consequences for the design pass. The classic crease pattern folds all
eight rays as precreases, but the folded base has two half-diagonals at 0°;
the Eos route creases exactly the six that fold (the initial diagonal plus
the medians from the reverse folds) and never marks the other diagonal. And
"same folded state" between two routes has to be checked on the outline and
the per-side stacking, never on face and order counts.

The run needed three things the spec already has: non-collinear leading
elements, an `over` clause between sector points to put the `a`-quarter in
front, and `{toward}` with a point off every crease through the centre. Every
named point (corners, edge midpoints) lies on such a crease, so both operands
are free points on an edge.

## The new ladder

Route A, critical path:

1. **Inside Reverse Fold** (#33). The one new maneuver. Its own design pass;
   see below for what it has to decide.
2. **Bird Base** (#32), route A: preliminary base plus four inside reverse
   folds.
3. **Crane** (#35), flat: bird base, leg narrowing by `fold`, three inside
   reverse folds. Wing opening stays out (ADR 0015).

Route B, second program for the same bird base, off the critical path:

- **Even Bases** (#29) → **Squash Fold** (#30) → **Petal Fold** (#31) →
  Bird Base route B. Two programs, one folded state, exact equality of the
  two `foldedForm` frames checkable in the kernel. That comparison is a paper
  example on its own.

Off both routes:

- **Outside Reverse Fold** (#34). The traditional crane never uses it. It
  shares the reverse-fold semantics with #33 and comes after it.

## Rejected

- **Traditional path first (squash, petal, then reverse).** Three maneuvers
  before a crane compiles, and two of them are not needed for it. Kept as
  route B because the diagrams use them and the two-route equality check is
  worth having.
- **Reverse-only, drop squash and petal.** Throws away the issues and the
  equality example for no gain; route B costs nothing until someone starts it.
- **Eos's split-and-merge realization of the reverse fold.** Ida's own verdict
  on it stands. Beloch has a solver-assigned multi-crease action already; the
  reverse fold should be a case of it.

## What the inside reverse fold design pass has to decide

Not decided here. Listed so the pass starts from the prior art instead of
from memory.

- **Semantics.** A crease across a folded flap whose vertex sits on the
  folded edge (the spine); beyond the new crease the spine's existing fold
  reverses M↔V; the moved material tucks between the flap's two layers. In
  Appendix B terms: boundary-vertex flatten across a folded edge, plus
  insert-between (Fisher's `tucking A under B`, Ida's `InsertFace → f`
  [ida2020, App. B.2]). The layer stack was designed insert-anywhere for this
  (action-model design, §3.1).
- **Operands.** Eos takes a face list and a `Ray` for the crease line
  [ida2020, Fig. 7.19]. Fisher takes edges plus a held face. Beloch has motion
  × disposition × extent; the open question is whether `fold <motion> …` with a
  scope that crosses a folded edge is enough, or whether the reverse needs its
  own verb or a `flatten` item. `notes/ideas.md` and Appendix B list named
  maneuvers as sugar over `unfold` plus layer selection; the Eos route makes
  the reverse fold the first sugar to land, before `unfold`.
- **Exactness.** The bird-base reverse folds carry $\sqrt{2}$ coordinates
  (Fig. 7.19 shows them). Nothing new for the kernel, but the first maneuver
  example that leaves the rationals.
- **Oracle.** Ida's Fig. 7.20–7.21 give the intermediate states for steps
  1–17; the face counts and the layer graphs (Figs. 7.23–7.24 for $O_{15}$)
  are checkable against Beloch's `faceOrders`.
