---
id: "0050"
title: "A 3D state is flat blocks turned on hinges; a simulation only fills what the program leaves free"
date: 2026-10-02
status: accepted
issue: tophcodes/beloch#195
---

# 0050: A 3D state is flat blocks turned on hinges; a simulation only fills what the program leaves free

## Context

ADR 0015 keeps the evaluator to flat folded states and names 3D as a goal:
3D rigid motions in place of 2D isometries, 3D points, and coordinates per
face and vertex. It does not say what a program writes to leave the plane, or
what the kernel computes when it does.

The models of ADR 0049 end in 3D: the crane spreads its wings, the penguin
stands, the waterbomb and the frog are inflated. Their 3D steps fall into
four kinds:

1. A step that starts and ends flat and passes through 3D in the hands: a
   sink, a reverse fold, a collapse. Beloch computes states, not motions, and
   folds these today. Several of them cannot be performed as a rigid motion
   at all [tachi2009rigidsim, Fig. 9].
2. A flat block turned about one line to an angle short of flat: a wing
   lowered to 90°.
3. Several creases at one vertex moving together. Their angles are coupled:
   the rotations about the creases around a vertex compose to the identity
   [tachi2009rigidsim, eq. 1; watanabe2009rigid].
4. Bent paper. Paper bends without stretching, so a bent region is a
   developable surface, swept by straight lines, and a chain of planar strips
   along those lines with small angles between them approximates it
   [demaine2007, p. 191, §20.2].

Kind 4 reduces to kind 2: a bend is a family of hinges. What sets kind 4
apart is who chooses the lines and the angles. A fold takes its line from an
axiom. Nobody chooses where an inflated waterbomb bends; the stiffness of
the paper and the forces on it do, and neither appears in the program.

ADR 0008 decides every comparison the kernel makes exactly, with no
tolerance, and ADR 0012 lets a float appear in the output only.

## Decision

**A 3D state is a set of flat blocks joined at hinges.** Each block is a flat
folded state as the kernel computes it today. A hinge is a line on the
paper, shared by two blocks, with a fold angle. A hinge stores the cosine and
the sine of its angle, which are real algebraic numbers in the sense of
ADR 0012 for any angle that is a rational number of degrees, so 90° and 60°
are exact.

**A hinge fold turns a block to an angle.** It selects the layers that move
the way a fold selects them today and turns them about the axis by an angle
the program states, between 0° and 180°. Illustratively,
`fold (--wing) (by 90)`; the syntax is settled with the implementation.

**A bend is a family of hinge folds.** Where the program names the lines and
the angles, constructed like any other lines, the bend is exact and
determined by the program. Where it leaves them open, the bend is an open
degree of freedom.

**Every comparison stays exact.** Collisions between blocks, a point lying on
a line, and the angles at a vertex are decided over the algebraic numbers.
Where several hinges meet at one vertex, their angles must satisfy the
vertex condition; a program whose angles violate it is an error.

**Any statement may follow a hinge fold.** A flat fold is a hinge fold by
180°, and a flat folded state is a 3D state whose angles are all 0° or 180°.
The flat kernel becomes this special case of the 3D one. Which layers a
statement selects in a state that is not flat is settled with the
implementation, in the issue named above.

**A program may leave degrees of freedom open.** How far an inflated model
bulges is one. An open degree of freedom is not an error. A simulation may
pick a shape for it numerically, for display and export, and its result never
returns to the kernel, as ADR 0012 holds for floats. A later statement that
relies on a position the open degree of freedom moves needs that position
fixed by an invariant the program states, such as a point that stays on a
line. The simulation keeps the invariant, the kernel reads the invariant and
never the simulated coordinates, and a later statement may name only what an
invariant names. A program with no later statement needs no invariant.

**ADR 0015 stays in force until a hinge fold evaluates.** The pull request
that lands the first hinge fold moves ADR 0015 to `archive/`.

## Alternatives considered

**The kernel simulates bends and later statements read the result.** Bends
would need no lines in the program. Every comparison on a simulated point
would need a tolerance, which ADR 0008 rules out, and the meaning of a
program would depend on a model of paper stiffness that the program does
not state.

**Bends are out of scope.** Every model that is inflated or curved would end
before its last step. A bend reduces to hinges, so including it costs the
language one statement form and no new kernel concept.

**3D statements end a program.** The flat kernel would stay as it is, with
the 3D part as a stage after it. The restriction protects nothing the
invariants do not: they already fix what a later statement may rely on, and
ADR 0015 changes the types of the flat kernel either way.

**Solve coupled vertices numerically.** Kind 3 is a system of polynomial
equations in the cosines and sines of the angles. When the program fixes
enough angles, its solutions are algebraic and the existence of a real
solution is decidable [bpr2006, ch. 13]. The kernel solves polynomials in one
variable today; several variables need elimination first, which is costly.
This decision keeps kind 3 exact and leaves its solver to a later issue.

## Consequences

- The kernel moves to 3D rigid motions and per-face vertex coordinates, as
  ADR 0015 lists, and the flat folds become the case of angles 0° and 180°.
- FOLD output carries 3D vertex coordinates and `edges_foldAngle` in the
  frames after the first hinge fold.
- The renderer needs a 3D view; the 2D renderer keeps drawing the flat
  states.
- A simulation backend is optional. Without one, an open degree of freedom
  stays open in the state, and output that needs one shape picks one.
- Moving a wing or flapping the flapping bird is a family of states over a
  parameter. Beloch describes single states; an animation sweeps the
  parameter outside the kernel.
