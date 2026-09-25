# 2026-09-25: The crane against Ida's crane program

`examples/crane.bel` continues `examples/bases/bird-base.bel` with Ida's steps
9 to 17 [ida2020, Fig. 7.19, p. 193]. Steps 18 and 19 rotate faces by $\pi/2$
to open the wings and stay out of scope (ADR 0015). The bird base itself was
checked in `2026-09-12-bird-base-oracle.md`; this note uses its similarity from
Ida's $4 \times 4$ table to Beloch's unit square,

$$(X, Y) \mapsto \left(\tfrac{X}{4},\; 1 - \tfrac{Y}{4}\right),$$

and its step numbering (Ida step $k$ is Beloch frame $k - 1$).

Verdict: **match on steps 9 to 16, a deliberate free choice on step 17.** Every
fold line of steps 9 to 16 is Ida's ray exactly, and the two leg tips land on
her positions exactly. The head uses two free points instead of her ray,
because her ray is a coordinate choice with no construction behind it (below).

## Per step

Coordinates are Beloch table coordinates. $L = (1 - \tfrac{\sqrt2}{4}, 1 - \tfrac{\sqrt2}{4})$
marks where the four side corners landed in the bird base: the table position
of `.sr`.

| Ida step | Ida command | Ida's ray | Beloch | verdict |
|---|---|---|---|---|
| 9 | `ValleyFold` | through $(\tfrac12, \tfrac{3-\sqrt2}{2})$ and $(\tfrac{3-\sqrt2}{2}, \tfrac12)$ | `fold (perp --mid through .sr) (moving .a)` | same line |
| 10 | `MountainFold` | as step 9 | `fold (perp --mid through .sr) (moving .c) (mountain)` | same line |
| 11 | `ValleyFold` | $(1,1)$ to $(\tfrac12, 0.66591)$ | `fold (map --rsl & .d onto --mid) (moving .e2)` | mirror image |
| 12 | `ValleyFold` | $(1,1)$ to $(0.66591, \tfrac12)$ | `fold (map --rsr & .b onto --mid) (moving .e1)` | mirror image |
| 13, 14 | `MountainFold` | as steps 11, 12 | the two mountain folds on `--rbr`, `--rbl` | mirror image |
| 15 | `InsideReverseFold` | $L$ to $(0.86562, \tfrac12)$ | `reverse (perp --n1 through .sr) (moving .b)` | same line, `.b` at $(0.45510, 0.18451)$ |
| 16 | `InsideReverseFold` | $(\tfrac12, 0.86562)$ to $L$ | `reverse (perp --n2 through .sr) (moving .d)` | same line, `.d` at $(0.18451, 0.45510)$ |
| 17 | `InsideReverseFold` | $(\tfrac34, 0)$ to $(\tfrac12, 1 - \tfrac{\sqrt2}{2})$ | `reverse (through .hp .ht) (moving .b)` | free choice, tip within $0.02$ |

The narrowing folds come in the order right, left where Ida folds left, right:
the same benign mirror as the bird base's corner order. Steps 15 and 16 act on
the same legs as Ida's: the tip positions above are her rays' reflections of
$(1, 1)$.

## Narrowing needs an anchor on the moving layer

Each leg of the bird base is a stack of layers, and its outer edge is a
different reverse-fold crease on each of them (`--rsr` in front, `--rbr`
behind, and likewise on the left). `map --rsr & .b onto --mid` names the right
line, but a fold without `moving` takes the default scope, and on this stack
that reached the back layers too: after the front fold `--rbr & .b` already
lay on `--mid` and the back fold failed with "lines are identical". Anchoring
each fold on a point of the layer it moves fixes the scope,

```
.e1 = (--rsr & .b) * --pf
fold (map --rsr & .b onto --mid) (moving .e1) as --n1
```

with `.e1` the meet of the front edge and the step 9 crease.

## Neck and tail: the perpendicular to the leg's own edge

The narrowing folds lie on the bisectors between the leg's outer edge and
`--mid`. `--mid` runs at $45^\circ$, the right outer edge `--rsr & .b` at
$67.5^\circ$ and the left one at $22.5^\circ$, so the narrowed edges `--n1` and
`--n2` run at $56.25^\circ$ and $33.75^\circ$. Ida's ray for step 15 runs
through $L$ at $146.25^\circ = 56.25^\circ + 90^\circ$, the one for step 16
through $L$ at $123.75^\circ = 33.75^\circ + 90^\circ$. Each reverse fold is therefore about the perpendicular
to its own leg's narrowed edge through $L$, and Beloch states it that way.
Reflecting the leg tip $(1, 1)$ in Ida's ray gives $(0.45510, 0.18451)$ for step
15, which is where the evaluator puts `.b`. The other pairing (a leg reversed
about the perpendicular to the other leg's edge) fails with "reversing the tip
would pierce layer …".

`perp --n1 through .sr` resolves although `--n1` has several pieces, because
its pieces are collinear on the table. `--n1 & .b` is ambiguous instead: two
stacked pieces pass through `.b`.

## The head

Ida's ray for step 17 runs from $(\tfrac34, 0)$, a table point outside the
folded model, at about $130.5^\circ$, which is no multiple of
$11.25^\circ$. It crosses the neck's centre line at $0.23463$ of the neck's
length from the tip, numerically $1 - 2\sin(\pi/8)$, and passes $0.0011$ from
the midpoint of the body edge `--rsl & .a`. No construction from the lines at
hand reproduces it, and in folding practice the head's position and angle are
the folder's choice. The program makes both explicit:

```
.hp = free on --bd & .b from .b at 1/4
.ht = free on --rsl & .a from .a at 1/2
reverse (through .hp .ht) (moving .b) as --head
```

`.hp` sets where the head bends, `.ht` its angle. With these values the head
tip lands at $(0.62196, 0.33818)$; reflecting `.b` in Ida's ray gives
$(0.61409, 0.32021)$.

An axis perpendicular to the neck (through `.hp` alone) folds the tip back onto
the neck, which is why the angle needs a second point.

## Cost

With the number-layer work of #38 and #39 the program evaluates natively in
about 2 s. The browser bundle is bound by `zarith_stubs_js`'s GCD and stays far
over the playground's 8 s budget (#40).

## Open questions

- A named crease that a later fold bends stops being a line for the assertion
  harness: `assert --n1 = --n3` reports "unknown line --n1" once the neck fold
  has bent `--n1`. The example therefore asserts only points.
- Whether $1 - 2\sin(\pi/8)$ is the construction behind Ida's head, or a
  coincidence of her coordinate choice, is not settled by anything in `refs/`.
