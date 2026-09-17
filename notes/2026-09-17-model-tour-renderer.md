# Scroll-driven model tour: a renderer for the definitions (idea, 2026-09-17)

Idea, not yet a spec. While the reader scrolls through the definitions of the
model, a sticky pane on the right shows a small `.bel` program and the state it
evaluates to, and the pane tracks the definition currently in view. The program
grows with the text: `paper square` while §1 talks about the sheet $P$; one
fold while §2 introduces faces, hinges and $\lambda$; more when the non-crossing
conditions need two folds on one line. Each definition names what the pane
highlights, so the reader builds the mental picture from code, one term at a
time.

Pane layout as sketched: code on top, half-transparent and not selectable
(reference only; the reader is not meant to edit it here), rendered state
below, one or two lines of explanation under it.

## What the pane has to be able to do

- Highlight a term in the rendering: the whole sheet for $P$, one face for a
  face of $\mathcal{F}$, all faces together to show that they cover $P$, a
  hinge, an overlap region for a pair in the domain of $\lambda$.
- Switch between the crease pattern and the folded state with an animation
  in between, so the reader sees that both are views of the same $(f,
  \lambda)$.
- An onion mode for $\lambda$: pull the layers apart along the table normal,
  so the ordering becomes visible where the folded view only shows the top
  face.
- Advance with the scroll position: the definition in view decides the
  program, the step, the view and the highlight.

## What already exists

Most of the machinery is in the repository:

- The `<Beloch>` card in `packages/www` evaluates inline source at build time
  and embeds the FOLD object; its hydration island already toggles CP and
  folded view, steps through folds, and links code spans to creases in the
  SVG in both directions, with a palette for multi-selection.
- `@beloch/render-svg` renders folded frames with layer occlusion from
  `faceOrders`, so $\lambda$ is already in the renderer.
- The model page is generated from `spec/MODEL.md` by a plugin that turns
  the `{.definition #id ...}` blocks into numbered, cross-referenced
  sections. The attribute syntax is a natural place for a "what to show"
  annotation, should the tour live in the spec page.

Missing is the direction: the sticky pane, the scroll driver, the animated
transition, the onion mode, and the per-definition content that says which
program and which highlight explain a term.

## Animation: decided against an engine

The transition between crease pattern and folded state is the only real
animation, and it is small. Reflecting a flap across its hinge line is a
scale by $-1$ perpendicular to that line, and the orthographic projection of
a rotation by $\theta$ about the line is a scale by $\cos\theta$. So one fold
step animates as an SVG `transform` on the moving flap, interpolated from
$1$ to $-1$, with the layer order swapped when the factor crosses $0$. That
is a `requestAnimationFrame` loop or a Web Animations API call on the
existing SVG groups, no library. Highlights and the onion mode are CSS
transitions on the same groups.

Considered and set aside:

- Motion, anime.js: a tween timeline would help if several steps run as one
  choreographed sequence with pauses. Adopt only when that need appears.
- GSAP: same, and MorphSVG is licensed, which nothing here needs.
- Three.js or CSS 3D on HTML elements: only for a perspective view of the
  flap in mid-fold. The model is flat by construction; an orthographic flip
  says the same thing without a second rendering pipeline.
- Rabbit Ear (Kraft) and Origami Simulator (Ghassaei): references for how
  others animate folds, not dependencies; both would duplicate the existing
  render pipeline.
- Scroll driver: IntersectionObserver by hand, which the island already uses
  for lazy hydration. Scrollama adds little. CSS `animation-timeline: view()`
  would remove the JavaScript but is missing in Firefox.

## Effort, as a side project

Feasible. Sticky pane via a Starlight sidebar override, about a day. Scroll
driver, half a day. Fold animation with the layer swap, one to two days.
Onion mode, half a day. The lasting work is the content: choosing per
definition the program, step, view and highlight that explain the term, which
follows the model review and changes with it.

## Open: where it lives

Not decided, deliberately. Two candidates:

- Inside the page generated from `spec/MODEL.md`, with the annotations in the
  definition blocks. Keeps text and picture together; puts presentation
  attributes into the specification document.
- A separate page, possibly the Getting Started page itself, that quotes the
  definitions by id and leaves the spec untouched.

Decide when the model review is far enough that the content of the tour is
known.
