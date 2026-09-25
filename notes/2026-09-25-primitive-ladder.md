# 2026-09-25: The ladder of folding primitives

A step of a folding sequence changes the crease pattern locally. Two
questions sort every named manoeuvre: at how many interior vertices the
crease pattern changes in that step, and whether an existing crease opens as
well as new ones forming. The answers give a ladder, and each rung needs a
capability the rung below does not have.

| Rung | What the step does | Named manoeuvres | Beloch |
|---|---|---|---|
| 1 | one line through all selected layers | valley, mountain, tuck (`over`/`under`) | `fold` |
| 2 | one line, and a folded hinge (the spine) turns the other way | inside and outside reverse | `reverse` |
| 3 | a fan of creases at one vertex, all new | rabbit ear, preliminary base in one step | `flatten` |
| 4 | a fan at one vertex that also opens an existing crease | squash | missing |
| 5 | fans at several vertices at once | petal, sink, fish or bird base in one step | missing |
| 6 | a state that is not flat | opening the crane's wings | out of scope (ADR 0015) |

Rung 4 is where the next work goes: `flatten` on material of several layers,
allowed to open a crease that is folded now. Rung 5 needs rung 4, since the
petal fold opens creases too.

Pleat and crimp stand on no rung of their own. A pleat is two rung-1 folds and
a crimp two rung-2 reverse folds, so each is at most a `def`.

## Where the named manoeuvres sit, by Fisher's own specifications

Fisher writes squash, petal and sink as `multifold` statements that list every
crease the step touches [fisher1994, p. 24]. The creases name their vertices,
so the rung can be read off:

- Squash: `multifold g-a, g-k, mountain g-j, unfold g-e`. Every crease runs
  from $g$; one vertex, and `unfold g-e` opens an existing crease. Rung 4.
- Petal: `multifold j-k, j-d, b-k, mountain a-j, a-k, unfold e-j, h-k`. Creases
  meet at $j$ and at $k$; two vertices, two creases opened. Rung 5.
- Sink: four `reverse` creases around $g$ plus a ring of new creases through
  $j$, $k$, $l$, $m$. Several vertices. Rung 5.

## Two meanings of "multifold"

The word names two different things in the sources this project reads.

- Fisher's `multifold` is a manoeuvre: several creases fold in one step
  [fisher1994, §3.3]. Rungs 2 to 5 are all multifolds in his sense.
- Alperin and Lang's multi-fold axioms are constructions: alignments
  distributed over two or more fold lines determine those lines together
  [alperin2006, §4]. The research package of ADR 0020 works on these, and
  evaluating them in Beloch is its goal; the syntax tree already holds a
  construction with named fold lines (ADR 0022).

A paper that uses the word has to say which one it means.

## What other systems reach

- Fisher designed `multifold` and left it unimplemented; his program performs
  rung-1 folds only [fisher1994, §7.2]. The creases of a multifold are all
  given by the user; none is derived.
- Eos has valley, mountain, inside and outside reverse and squash as built-in
  commands [ida2009eos, p. 287; ida2020, §7.4.3, fn. 7].
- eGami, an interactive simulator, offers inside, outside and asymmetric
  reverse, symmetric squash, symmetric petal, pleat and crimp as tools, with
  rabbit ear and sink under development at the time [fastag2009egami,
  p. 276]. The scanned text does not show whether a general vertex solver
  sits behind the tools.

Squash and petal were therefore reachable before Beloch, as fixed commands or
tools.

## The claim this supports

Among the languages and systems we know, Beloch is the first in which a
folding step is a general single-vertex fan whose missing crease is derived
from Kawasaki's condition, so that named manoeuvres are instances of it.

The same move happened at the construction level. The seven Huzita-Justin
axioms are instances of alignment sets (ADR 0022, [alperin2006, §3]); the
rung-3 manoeuvres are instances of a flat-foldable fan ([hull2020, ch. 5],
`spec/MODEL.md`, definition of `flatten`). Both levels replace a list of
named operations by the mathematical object the list enumerates.

On provenance: `flatten` was generalized in July 2026, and Fisher entered the
project with the Origami⁴ pass on 2026-09-10 (ADR 0011, correction). The two
designs converged independently; Fisher is the nearest precedent and gets
cited as such.
