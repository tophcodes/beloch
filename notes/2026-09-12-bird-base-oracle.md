# 2026-09-12: The bird base against Ida's crane figures

`examples/bases/bird-base.bel` (route A: preliminary base plus four inside
reverse folds) reproduces Ida's $O_8$ exactly, on every quantity her figures
publish: the outline, the vertex set including the $\sqrt2$ coordinates, the
crease rays, and the silhouette after each intermediate step. This is the
oracle check the crane-path note left open
(`2026-09-10-crane-path-reordered.md`, "Oracle").

Verdict: **match.** One benign difference: Ida folds the four side corners in
the order left, right, left, right and the program folds them right, left,
right, left, so the states after Ida's steps 5 to 7 and Beloch's frames 4 to 6
are mirror images across the base's centre line. The states after the fourth
reverse fold coincide.

## Ida's step numbering

Fig. 7.19 (p. 193) is one `Orikoto` program of 19 commands: `NewOrigami[4]`,
one `ValleyFold`, six `InsideReverseFold`, six `ValleyFold`/`MountainFold`,
three more `InsideReverseFold`, and two commands carrying a face rotation of
$\pi/2$. The graphics outputs are Fig. 7.20 for steps 1 to 9 (p. 194),
Fig. 7.21 for steps 10 to 17 (p. 195) and Fig. 7.22 for steps 18 and 19
(p. 196); the text pins the last two as the 3D wing openings
[ida2020, §7.4.3, p. 192]. Step $k$'s picture is $O_k$, confirmed by
"the graphics representation of $O_{15}$ is shown in Fig. 7.21(f)"
[ida2020, §7.4.3, p. 192], where (f) is captioned Step 15. Step 1 is therefore
the unfolded square and the bird base is $O_8$, Fig. 7.20(h).

Ida's sheet is the $4 \times 4$ square with $A = (0,0)$, $B = (4,0)$,
$C = (4,4)$, $D = (0,4)$. The first valley fold runs on the ray from $(4,4)$
to $(0,0)$ and carries $D$ onto $B$, which is why the bottom corner is
labelled $D$ from Fig. 7.20(b) on. The preliminary base $O_4$ is the square
$[2,4] \times [0,2]$ with its apex at $(4,0)$.

Beloch folds `.a` onto `.c`, so the two labelings differ by a reflection. The
similarity that carries Ida's table coordinates to Beloch's unit square is

$$(X, Y) \mapsto \left(\tfrac{X}{4},\; 1 - \tfrac{Y}{4}\right).$$

Apex $(4,0) \mapsto (1,1) = $ `.c`, paper centre $(2,2) \mapsto (1/2,1/2) = $
`.o`, side corners $(2,0) \mapsto (1/2,1)$ and $(4,2) \mapsto (1,1/2)$. Every
comparison below is under this map.

## Per step

`file_frames[0]` is the flat sheet, a viewing frame that the `steps` assertion
does not count, so Beloch frame $k$ is Ida step $k+1$.

| Ida step | Ida command (Fig. 7.19) | Ida's picture | Beloch | faces (Ida / Beloch) | verdict |
|---|---|---|---|---|---|
| 1 | `NewOrigami[4]` | 7.20(a), the square | `paper square`, frame 0 | 1 / 1 | match |
| 2 | `ValleyFold[Ray[{4,4},{0,0}]]` | 7.20(b), triangle $A$, $B$, $C$ | `fold --bd = map .a onto .c`, frame 1 | 2 / 2 | match |
| 3 | `InsideReverseFold[{2,3}, Ray[{4,2},{2,2}]]` | 7.20(c), quadrilateral $(0,0),(4,0),(4,2),(2,2)$ | `reverse --h = map .b onto .c`, frame 2 | not stated / 4 | outline matches |
| 4 | `InsideReverseFold[{4,6}, Ray[{2,2},{2,0}]]` | 7.20(d), preliminary base $[2,4] \times [0,2]$ | `reverse --v = map .d onto .c`, frame 3 | not stated / 6 | outline matches |
| 5 | `InsideReverseFold[{13,12}, …]`, ray $(2, 2\sqrt2 - 2) \to (4,0)$ | 7.20(e), silhouette still the square | `reverse map .sr …`, frame 4 | not stated / 8 | outline matches, mirrored corner |
| 6 | `InsideReverseFold[{24,7}, …]`, ray $(4,0) \to (6 - 2\sqrt2, 2)$ | 7.20(f), silhouette still the square | `reverse map .sl …`, frame 5 | not stated / 10 | outline matches, mirrored corner |
| 7 | `InsideReverseFold[{8,9}, …]`, ray of step 5 | 7.20(g), the corner $(2,0)$ is gone | `reverse map .br …`, frame 6 | not stated / 12 | mirror image |
| 8 | `InsideReverseFold[{5,16}, …]`, ray of step 6 | 7.20(h), the bird base kite | `reverse map .bl …`, frame 7 | not stated / 14 | match |

The silhouette stays square through steps 5 and 6 because each of those folds
moves the front layer of a side corner while the back layer still covers the
corner. Steps 7 and 8 move the back layers and the outline collapses to the
kite, one corner at a time. Beloch's frames show the same three shapes in the
same order: `(1,1/2)` leaves the vertex list at frame 6 and `(1/2,1)` at
frame 7.

## The kite

The finished state has five distinct table vertices, and each one is Ida's
under the map above:

| Beloch | Ida | what it is |
|---|---|---|
| $(1,1)$ | $(4,0)$ | apex, all four paper corners |
| $(1/2, \frac{3-\sqrt2}{2})$ | $(2, 2\sqrt2 - 2)$ | side vertex, endpoint of one reverse ray |
| $(\frac{3-\sqrt2}{2}, 1/2)$ | $(6 - 2\sqrt2, 2)$ | side vertex, endpoint of the other |
| $(1/2,1/2)$ | $(2,2)$ | far vertex, the paper centre |
| $(1 - \frac{\sqrt2}{4}, 1 - \frac{\sqrt2}{4})$ | $(4 - \sqrt2, \sqrt2)$ | where the four reversed corners land |

The two side vertices are Ida's ray endpoints read straight off Fig. 7.19,
which is the strongest part of the check: the $\sqrt2$ coordinates in her
program are exactly the ones the evaluator derives, to the last symbol, with
no picture measurement in between.
The fifth point was verified by projecting it into Fig. 7.20(h) with the
figure's own oblique projection, recovered from the reference square's
corners; the three interior crease lines of that figure meet there.

The folded geometry that goes with it: the kite's four boundary edges are all
folded edges (valley), the axis from the far vertex to the apex carries the
two mountain halves of `--bd`, the two side vertices are joined to the landing
point by mountain creases that are collinear in the table, and eight raw paper
edges run along the axis from the landing point to the apex, two from each
reversed corner.

## Face counts

Ida states no face count for any step, and the figures are renderings rather
than labelled partitions, so only steps 1 and 2 are forced: one face, then the
two halves of the diagonal fold, which Fig. 7.19 confirms by handing step 3
the face list `{2, 3}`.

For steps 3 to 8 the face lists in Fig. 7.19 are the only quantitative handle,
and they do not yield a count. Every `InsideReverseFold` names exactly two
faces, which under "divide the faces in $C$ by ray $r$" [ida2020, §7.5, p. 194,
actions 3 and 4] would add two faces per command and give 4, 6, 8, 10, 12, 14,
the sequence Beloch produces. The face identifiers contradict a consecutive
reading of that model: step 5 names faces 12 and 13, which a consecutive
allocator has not reached by then, while step 6 names face 7 and step 8 names
face 5, both of which the same allocator would have consumed earlier. So Eos's
identifiers are not consecutive and no count can be read out of them. Recorded
as an open question below.

What can be said about the partition: Beloch's 14 faces are $3 + 3 + 4 + 4$
over the paper quarters, the `a` and `c` quarters split into a central kite
plus two corner triangles and the `b` and `d` quarters into four triangles
each. Nothing is creased that does not fold: `--ac`, the diagonal the classic
crease pattern precreases, stays uncreased on this route, and `--mid` is a
construction line rather than a crease, so the count is not inflated by marks.
Beloch's `reverse` creases both halves of a tip in one operation and the two
halves share one crease identifier, which is why the four corner folds add two
faces each rather than four.

## Layer order

Ida publishes layer graphs only for $O_{15}$ (Figs. 7.23 and 7.24, pp. 197 to
198), seven steps past the bird base, so there is no published layer oracle at
$O_8$. Fig. 7.20(h) shows the silhouette and the visible edges, which the
kite section above covers. The $\succ$-graph of $O_{15}$ is the superposition
relation and its node count is Eos's face count at that state; reading it off
is the natural check when the crane lands.

Beloch's stack at the bird base, read from `faceOrders` with the FOLD sign
convention (the sign is relative to the second face's normal) and cross-checked
against the kernel's rank array, bottom to top by paper quarter:

```
c(kite) c c  d d  b b b b  d d  a a  a(kite)
```

The two flat kites are the `a` and `c` quarters, front and back of the whole
outline. The `b` quarter sits as one contiguous run of four faces in the
middle, and the `d` quarter's four faces split into two pairs, one below the
`b` run and one above it. The pair `faceOrders` entry $[0, 1, +1]$ is the
bottom face against the top one: face 1 is face-down, so the $+1$ reads as
"face 0 lies on the side face 1's normal points to", which is below it in
space.

Layer census over the outline, which is the part the crane needs:

| region | layers |
|---|---|
| apex, all four corners | 14 |
| apex half, one side of the axis | 8 |
| far half, one side of the axis | 4 |
| far vertex | 6 |

## Mountain and valley

Ida gives no letters for the reverse folds. Eos names a direction only on the
plain folds, and the monograph describes `InsideReverseFold` as a split into
two sub-origamis with a mountain fold on one and a valley fold on the other
[ida2020, §7.4.3, p. 192]. Beloch derives the letters instead (ADR 0011), and
the sequence it derives has the same shape as that description:

| after | `--bd` | `--h` | `--v` | the four corner creases |
|---|---|---|---|---|
| `fold --bd` | V | | | |
| first `reverse` | M, V | V, V | | |
| second `reverse` | M, M | V, V | V, V | |
| each corner `reverse` | M, M | one more segment flips to M | likewise | V, V |
| bird base | M, M | M, V, M, V | M, V, M, V | V, V each |

The intermediate state after the first reverse fold is where the spine's two
halves disagree, one valley and one mountain, which is acceptance criterion 5
of `docs/superpowers/specs/2026-09-10-reverse-fold-and-layer-placement-design.md`
holding on a longer program than the one it was written for. Each corner
reverse fold flips exactly one segment of the preliminary base's own crease to
mountain, which is what leaves `--h` and `--v` reading M, V, M, V at the end.

This is also why the bird base carries fewer letter assertions than
`examples/bases/preliminary-reverse.bel`, which asserts `--h is valley` and
`--v is valley`. Those hold at the preliminary base and stop holding as soon
as the first corner is reversed, so the bird base can only assert `--bd`.

## Assertions added to `examples/bases/bird-base.bel`

Every one of these was read out of the evaluator's output first:

- `.c = (1, 1)`, `.a = .c`, `.b = .c`, `.d = .c`: all four paper corners at
  the kite apex.
- `.o = (1/2, 1/2)`: the paper centre is the kite's far vertex.
- `.sr = .sl`, `.sr = .br`, `.sr = .bl`: the four reversed side corners land
  on one point of the centre line.
- `--bd is mountain`: the spine reverses on both halves.

The two side vertices carry $\sqrt2$ coordinates and v1 of the assertion
format has no irrational literal
(`docs/superpowers/specs/2026-07-14-beloch-inline-assertions-design.md`,
non-goals), so the kite's width is pinned only through the point coincidences
above. Every named point in this program projects to one table position from
every face that contains it, so the harness's ambiguity error cannot fire on
them.

## What this hands the crane

- The apex carries all 14 layers. A reverse fold whose tip is taken at that
  end will offer the spine search many folded hinges, and the design's rule is
  that exactly one candidate may survive, otherwise the error asks the user to
  fold less. The neck, tail and head folds are Ida's steps 15 to 17 and they
  act there, so that is where `Several_spines` is most likely to bite first.
- The far half has four layers per side and the apex half eight, so a flap
  taken at the far end is the cheap one to reason about.
- Ida's steps 9 and 10 are a valley fold and a mountain fold on the same ray,
  the line joining the two side vertices of the kite. That line already exists
  in the bird base as the pair of collinear mountain creases through the
  landing point, so the crane's next six folds need no new construction beyond
  what `--mid` and the corner points already give. Steps 11 to 14 use the two
  rays from the apex again.
- Ida's steps 18 and 19 rotate faces by $\pi/2$ and stay out of scope
  (ADR 0015), so a flat crane ends at step 17.

## Open questions

- Eos's face identifiers in Fig. 7.19 cannot be reconciled with any simple
  allocation model (see the face-count section). Either Eos divides more faces
  per command than the argument list names, or its identifiers are not handed
  out consecutively. Nothing in the monograph settles it, and no source in
  `refs/` describes Eos's face bookkeeping at that level. If the crane slice
  needs Eos's counts, this needs a source that is not currently in `refs/`.
- `beloch:named_lines` reports a material crease's current line in the table
  frame while `beloch:named_lines_frame` declares `creasePattern`. For this
  program `--bd` therefore comes out as $y = x$, the line of the diagonal that
  is never creased, and `--h` and `--v` drop out of the map entirely once
  later folds bend them. The `is mountain` assertion is unaffected, because
  the harness resolves the crease by identifier and falls back to all of its
  hinges when the line filter matches none. Worth a look on its own.
