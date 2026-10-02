# Knot: five drafts

Exploration of direction B of the logo brief (`docs/brand/logo-brief.md`,
§7 B). A single flat-foldable vertex, drawn in the line language of the
renderer. For each draft, this note gives the angles, the mountain-valley
assignment, the Maekawa and Kawasaki arithmetic, and the point where it
breaks.

## What is here

| File | Vertex | Where the geometry comes from |
| --- | --- | --- |
| `knot-01-emergent.svg` | $(1/3,\ 2/3)$ | computed by the evaluator, `logo.bel` |
| `knot-02-fan.svg` | $(0.36,\ 0.60)$ | constructed by hand |
| `knot-03-fish.svg` | $(1-\tfrac{\sqrt2}{2},\ 1-\tfrac{\sqrt2}{2})$ | computed by the evaluator, `logo-fish.bel` |
| `knot-04-bare.svg` | as 03, without the sheet's edge | constructed by hand |
| `knot-05-pane.svg` | $(0.44,\ 0.40)$ | constructed by hand, evidence for the breaking point |

Each draft comes with a `-16` version (see "The 16-pixel versions"). All
files: `viewBox="0 0 64 64"`, `stroke="currentColor"`, one `rect`, two
`path`, one `circle`, under 600 bytes.

## The test that applies to all of them

A single interior vertex with sector angles $\alpha_0 \dots \alpha_{2n-1}$
is flat-foldable exactly when the alternating sum of the angles is zero
(Kawasaki, [hull2020, §5.3]). At a flat vertex the number of mountain folds
minus the number of valley folds is $\pm 2$ (Maekawa, [hull2020, §5.2]).
Added to these is the Big-Little-Big Lemma ([hull2020, Lemma 5.25]): when a
strictly smallest sector borders two larger ones, its two creases must
carry different assignments.

For a vertex of degree 4 with a unique smallest sector, these three
conditions together are sufficient. Kawasaki forces $\alpha_1 + \alpha_3 =
\alpha_2 + \alpha_4 = 180°$; of the eight assignments that satisfy Maekawa,
the four the lemma admits survive ([hull2020, Theorem 5.26] and the
discussion before it). Every draft here has four pairwise distinct sectors,
and so a unique smallest one.

The angles below are in degrees, measured as a direction from the vertex,
counter-clockwise, with $0°$ pointing right. The sheet's coordinates are the
unit square with $y$ pointing up; in the SVG the sheet sits at margin 6 with
side length 52.

## `knot-01-emergent`

Vertex $O = (1/3,\ 2/3)$.

| Ray | Direction | End point | Assignment |
| --- | --- | --- | --- |
| 1 | $180° - \arctan 4 = 104.0362°$ | $(1/4,\ 1)$ | valley |
| 2 | $180° + \arctan 2 = 243.4349°$ | $(0,\ 0)$ | valley |
| 3 | $315°$ | $(1,\ 0)$ | valley |
| 4 | $360° - \arctan \tfrac{1}{13} = 355.6013°$ | $(1,\ 8/13)$ | **mountain** |

Sectors, in this order:

$$\alpha_1 = 139.3987 \quad \alpha_2 = 71.5651 \quad \alpha_3 = 40.6013 \quad \alpha_4 = 108.4349$$

**Kawasaki.** $139.3987 - 71.5651 + 40.6013 - 108.4349 = 0$.
Equivalently: $\alpha_1 + \alpha_3 = 180.0000$ and $\alpha_2 + \alpha_4 =
180.0000$. Sum of all four: $360.0000$.

**Maekawa.** $M - V = 1 - 3 = -2$.

**Big-Little-Big.** Smallest sector $\alpha_3 = 40.6013$, enclosed by ray 3
(valley) and ray 4 (mountain). The two differ.

Ray 4 is the crease `flatten` solves for itself. No Huzita axiom constructs
it from the named points; it exists because the vertex has to close flat,
and the evaluator gives it the only mountain. That is the line no other tool
in the field writes this way.

**Where it breaks.** The 40.6° sector is the narrowest in the whole set.
Below 24 pixels, rays 3 and 4 run together into a wedge, and the vertex
reads as a triangle with a line attached instead of as four creases. At 16
pixels only the overall figure carries.

## `knot-02-fan`

Vertex $O = (0.36,\ 0.60)$.

| Ray | Direction | End point | Assignment |
| --- | --- | --- | --- |
| 1 | $100°$ | $(0.2895,\ 1)$ | valley |
| 2 | $175°$ | $(0,\ 0.6315)$ | **mountain** |
| 3 | $225°$ | $(0,\ 0.2400)$ | valley |
| 4 | $330°$ | $(1,\ 0.2305)$ | valley |

Sectors: $75 \quad 50 \quad 105 \quad 130$.

**Kawasaki.** $75 - 50 + 105 - 130 = 0$, so $75 + 105 = 180$ and
$50 + 130 = 180$. Sum $360$.

**Maekawa.** $M - V = 1 - 3 = -2$.

**Big-Little-Big.** Smallest sector $50$, between ray 2 (mountain) and
ray 3 (valley).

**Where it breaks.** The angles are chosen, not derived. Beloch does not
construct $100°$ and $175°$ from the corners of a square, so this draft
loses the evidence that direction B is meant to bring. It is the best
picture in the set and the weakest claim.

## `knot-03-fish`

Vertex $O = (1 - \tfrac{\sqrt2}{2},\ 1 - \tfrac{\sqrt2}{2}) \approx
(0.292893,\ 0.292893)$. It is the first interior vertex of the fish base,
standing alone.

| Ray | Direction | End point | Assignment |
| --- | --- | --- | --- |
| 1 | $112.5°$ | $(0,\ 1)$, corner `.d` | valley |
| 2 | $180°$ | $(0,\ 1-\tfrac{\sqrt2}{2})$ | **mountain** |
| 3 | $225°$ | $(0,\ 0)$, corner `.a` | valley |
| 4 | $337.5°$ | $(1,\ 0)$, corner `.b` | valley |

Sectors: $67.5 \quad 45 \quad 112.5 \quad 135$.

**Kawasaki.** $67.5 - 45 + 112.5 - 135 = 0$, so $67.5 + 112.5 = 180$
and $45 + 135 = 180$. Sum $360$.

**Maekawa.** $M - V = 1 - 3 = -2$.

**Big-Little-Big.** Smallest sector $45$, between ray 2 (mountain) and
ray 3 (valley).

**Where it breaks.** Three of the four rays point down and to the left, and
two of them are short. The vertex therefore sits in a corner of the sheet
and the right half of the sheet stays empty, which at 16 pixels reads as a
square with a diagonal. Rays 3 and 4 end exactly in the corners `.a` and
`.b`, where they visually run into the edge.

## `knot-04-bare`

The same geometry as `knot-03-fish`, without a drawn sheet edge. The rays
end where the sheet would be, so the silhouette carries the square on
without showing it. Arithmetic as above.

**Where it breaks.** Without the edge the paper is missing, and with it the
only statement that separates the vertex from a sign for "branching". At 16
pixels the figure is recognizable and unmistakable, but it stands in the tab
without an area and vanishes next to favicons that have one. The direction
needs a wordmark beside it.

## `knot-05-pane`

Vertex $O = (0.44,\ 0.40)$, close to the middle of the sheet.

| Ray | Direction | End point | Assignment |
| --- | --- | --- | --- |
| 1 | $25°$ | $(1,\ 0.6611)$ | valley |
| 2 | $90°$ | $(0.44,\ 1)$ | **mountain** |
| 3 | $195°$ | $(0,\ 0.2821)$ | valley |
| 4 | $310°$ | $(0.7756,\ 0)$ | valley |

Sectors: $65 \quad 105 \quad 115 \quad 75$.

**Kawasaki.** $65 - 105 + 115 - 75 = 0$, so $65 + 115 = 180$ and
$105 + 75 = 180$. Sum $360$.

**Maekawa.** $M - V = 1 - 3 = -2$.

**Big-Little-Big.** Smallest sector $65$, between ray 1 (valley) and
ray 2 (mountain).

**Where it breaks.** It is the breaking point the brief names, supplied as
evidence. The arithmetic is right at every step, and still the picture
fails: a centred vertex with four sectors between 65° and 115° divides the
square into four panes, and at 16 and 24 pixels the figure reads as a
window frame or a layout icon. Comparing it with `knot-01` to `knot-03`
shows how far the vertex has to move from the centre: from an offset of
about a third of the sheet's width and a smallest sector under 55°, the
reading tips back to folding. Not recommended for further work.

## The `.bel` route

It carries, for two of the five drafts.

```
nix develop --command dune exec beloch -- fold \
  docs/brand/logo-explorations/knot/logo.bel > /tmp/logo.fold

cd packages/render-2d/render-svg && bun bin/fold2svg.ts /tmp/logo.fold /tmp/logo-cp.svg
```

`logo.bel` produces the vertex of `knot-01-emergent`, `logo-fish.bel` that
of `knot-03-fish`. Both programs run through, and the FOLD they produce
carries exactly the angles and the mountain-valley assignment given above.
The evaluator is thus the checking authority for these two drafts: Kawasaki
and Maekawa are part of its pipeline, and a vertex that violates them is
refused (`spec/KERNEL.md`, section Fan, check 11 and the Maekawa
enumeration in step 2 of the pipeline).

Two limits, so that the evidence claims no more than it holds.

**The delivered SVG file is not the renderer's output.** The renderer sets
face polygons, a legend and labels, and ends up at about 6 KB on a 572
grid. The brief asks for under 2 KB, at most six paths and a square
viewBox. The delivered files are therefore set from the evaluator's
coordinates, not from its SVG. The geometry is checked; the file is drawn.

**The draft shows only the folded rays.** At the vertex of `logo.bel`, the
full crease pattern holds three more rays with the assignment `F`, remnants
of the construction lines that fix the vertex in the first place. They are
left out of the sign. The reduced crease pattern stands on its own: a
square with a single interior vertex of degree 4 that is locally
flat-foldable folds flat as a whole.

**For `knot-02-fan` and `knot-05-pane` the route does not carry.** Their
angles are chosen from the drawing and cannot be constructed from the
corners of a square. They are computed by hand; the arithmetic is above.

## The line language, and where it departs

`packages/render-2d/render-svg/src/theme.ts` sets the Yoshizawa-Randlett
style: edge solid, width 3; mountain dash-dot `8 2 1 2`, width 2; valley
dashed `6 4`, width 2; everything in one colour on `ink`. The drafts take
over the system and depart from it deliberately in three points, because
the renderer draws on a sheet 460 units wide and the sign on one 52 units
wide.

- **Stroke widths.** Edge 4, crease 3 instead of 3 and 2. On a sheet of 52
  units the renderer's ratio would come to 0.34 and 0.23 units, at 16
  pixels about a twentieth of a pixel.
- **Dash patterns.** Mountain `6 2.5 1 2.5`, valley `4.5 3`. The ratio of
  dash to gap stays; the period is computed for the ray lengths of the
  sign. With the renderer's values the shortest ray would hold less than
  one period.
- **Line caps.** The creases end butt instead of round. At stroke width 3
  and gap 2.5 a round cap eats the gap, and mountain and valley look alike.

The dot at the vertex follows the renderer in substance (a filled circle on
`ink`), with radius 3 instead of 3 on a sheet of 460 units.

## The 16-pixel versions

Each `-16` file is the same geometry without dash patterns, with creases at
width 4 and a larger vertex dot. The mountain-valley distinction is lost.
At 16 pixels a dash pattern does not carry, and neither do two stroke widths
0.1 pixel apart; the version shows the crease pattern without assignment,
which is an admissible subject.

The raster test showed a limit the brief does not anticipate: **the dashed
version carries only from about 48 pixels.** At 24 pixels in the slide
corner and at 38 pixels in black on white, the dashes fall apart into rows
of dots. The `-16` version is therefore the version for everything under 48
pixels and for 1-bit print, not only for the favicon.

The test used `@resvg/resvg-js` from `packages/render-2d/node_modules`, at
16, 32, 64, 128 and 256 pixels, each size looked at; also on `#101C2E` with
ink `#E7EAF2`, in a circular crop, in black on white at 38 pixels, and at
24 pixels next to 18 pt text. At 16 pixels all five drafts stood next to a
square, a circle, a star and a crosshair.

One measurement falls out that belongs in the derivation: **in a circular
crop the sign may take up at most 87 % of the circle's diameter.** The
corner of the sheet's frame lies $26\sqrt2 = 36.77$ units from the centre
of the 64 viewBox, the inscribed circle has radius 32, and
$32/36.77 = 0.87$. At full size the repository avatar cuts off the four
corners of the sheet.

## Acceptance criteria from §8 of the brief

Checked for `knot-01-emergent`, `knot-02-fan` and `knot-03-fish` with their
`-16` versions. What this exploration does not deliver is marked open.

Size and reduction

- [x] At 16 pixels, in greyscale, distinguishable from square, circle, star
      and crosshair. Rastered directly against each other.
- [x] At 16 pixels no dash pattern needed; the `-16` version is included.
- [x] At 32 pixels the fold is recognizable: the vertex and four rays of
      unequal length stand. Mountain and valley stand only from 48 pixels.
- [x] At 24 pixels height next to 18 pt text it does not disturb the text,
      in the `-16` version.
- [x] At 10 mm, 1-bit black on white, legible, in the `-16` version.

Colour

- [x] None of the forbidden colours and no red or blue hue. The files name
      only `currentColor`.
- [x] On `#101C2E`, `#171B24`, `#F7F9FB` and white the drawing is the same.
- [x] In pure black on white nothing is lost; the drawing is in one colour.

File

- [x] SVG under 2 KB (largest file 521 bytes), two `path`, no `filter`,
      `mask`, `linearGradient`, `radialGradient`, `image`, `text`.
- [x] Square viewBox `0 0 64 64`, nothing lies outside it. The brief names
      `0 0 128 128` as today's value; 64 is divisible by four and so puts
      the stroke edges on whole pixels at 16 pixels.
- [x] Nothing is lost in a circular crop, at 87 % size at most. At full size
      the corners of the sheet are cut off.
- [x] All coordinates are constructed. For `knot-01` and `knot-03` from the
      evaluator, for `knot-02` and `knot-05` from the angles noted above.

Content

- [x] No crane, no plane, no animal, no face, no digit.
- [x] No perspective, no shadow, no gradient.
- [x] Maekawa and Kawasaki hold at the interior vertex, recomputed for each
      draft separately.
- [x] Next to `examples/bases/fish-base-cp.svg` it looks made by the same
      hand. The departures in stroke width, pattern and line cap are named
      and justified above.

Wordmark and combination

- [ ] Open. This exploration delivers only the pictorial mark. The wordmark,
      the combination and the spacing as a multiple of the stroke width come
      with the elaboration of the chosen direction.

## Ranking

1. **`knot-01-emergent`.** The evaluator produces it, and its fourth crease
   is one no axiom constructs. For the first audience that is the evidence
   the brief expects from this direction. Legible at 16 pixels, good at 24.
2. **`knot-02-fan`.** The clearest picture at 16 and 24 pixels: a visible
   fork and a long diagonal. The angles are chosen, so the evidence is
   missing. A fallback for 1, in case its narrow sector gets in the way in
   use.
3. **`knot-03-fish`.** Also from the evaluator, with the shorter and more
   legible derivation, and it quotes the fish base the repository already
   shows. The picture is more crowded than 1 and 2.
4. **`knot-04-bare`.** The most reduced version, and the only one without an
   area in the tab. Only with a wordmark.
5. **`knot-05-pane`.** Not recommended. Included because it is the evidence
   for the breaking point the brief names.
