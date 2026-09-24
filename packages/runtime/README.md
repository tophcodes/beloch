# runtime

Bun workspace for the state the web client shows: a document in, a drawing
order and a set of editor marks out. It holds what a reader of a Beloch
program is looking at, so that every view of that program agrees.

The core is free of the DOM and free of side effects. A consumer loads it,
adds the modules it needs, and plugs in its own renderer.

## Packages

- **`core/`** (`@beloch/runtime`): the state, the events that change it, and
  `renderCommand`, which says what to draw. Imports types from `@beloch/scene`
  and nothing at runtime.
- **`editor/`** (`@beloch/runtime-editor`): source and entities, both
  directions. It carries no DOM and no editor library.
- **`render-dom/`** (`@beloch/runtime-render-dom`): the renderer plug for a
  DOM host. It executes a render command with `@beloch/render-svg` and puts the
  result in an element.

## What the core holds

A **document slot**: one `FoldScene`, or nothing. Who fills it is the
composition's business. An evaluation module fills it after a run, a card
fills it from the FOLD embedded in its markup, a scroll-driven tour fills it
per section from a program evaluated at build time. Nothing in the core
evaluates, so a consumer that never evaluates carries no evaluator.

The **step**, from 0 to `writes.length`. 0 is the sheet before any statement
ran; n means every write has been applied. The stepper stops where the paper
changed, which a fold and a mark both do and a binding statement does not
(ADR 0026). Frames are the renderer's business, reached through
`writes[i].frameIndex`.

The **selection** and the **hover**. A selection names entities by their
identity: a crease is its bundle (ADR-0014), a paper boundary is its edge
name. A settled selection outranks the pointer, so moving the cursor away
does not take the reader's answer with it.

It holds no viewport. Pan, zoom and animation progress are the view's, because
two consumers may show one document at different zoom and mid-animation.

## Drawing

`renderCommand(state, { view, hidden })` returns what to draw, as plain data
in one of three shapes:

- `cp-only`: a program with no fold and no mark statement has no timeline.
  Its one drawing is the crease pattern.
- `flat`: the sheet, scored up to `upToStatement`, carrying the marks still
  dangling there. `-1` is the sheet before anything was scored.
- `folded`: one frame of the folded state, under a hidden mode. Frame 0 is
  the unfolded sheet.

The view and the hidden mode are arguments rather than state, because the only
reader of either is a renderer and one document may be drawn twice at once:
the `<Beloch>` card shows the crease pattern and the folded form side by side,
from one step and one selection.

A command also says whether its highlight is settled or under the pointer,
because a renderer may show a settled entity more than the drawing holds.

Beside that it names the **construction lines** the program has bound by this
step. A line that never becomes a crease is geometry the program built and the
paper does not carry, so a drawing that leaves it out loses it. The core dates
the list by the step and stops there: whether a name is already in the picture
as a crease is something only the drawing knows.

A command carries no scene, no theme and no geometry. The scene is in the
state the renderer already reads, colours are the renderer's, and the motion
of a flap between two frames comes from the scene's `facesMatrix`. So a
command is a small comparable value, which is what a headless test asserts
against and what a renderer diffs to decide how to animate.

## Events

`dispatch` takes an intention, never an assignment: `document/set`,
`step/to`, `selection/set`, `hover/set`. An intention the core cannot honour
is clamped or ignored rather than rejected, so a caller may hand over a step
remembered from a shorter program.

An event that changes nothing returns the state object it was given, and a
dispatch that changed nothing notifies no one. A renderer can therefore ask
`prev === next` and a pointer resting on one crease does not restart a
running animation.

## Types

String-literal unions, no `enum`. These values cross into FOLD JSON, into DOM
attributes and into `@beloch/render-svg` as the strings they are, and TypeScript
erases a union entirely where an enum would leave an object in the bundle.
Exhaustiveness is checked the same way, by a `switch` the compiler completes.

## The renderer plug

`createDomRenderer(host).draw(scene, command, { theme, fade })` puts the
drawing in `host`. It owns four pieces of DOM work:

- The markup, through `@beloch/render-svg`. `commandToSvg` alone is the pure
  half, for a caller that wants the string without an element to put it in.
- A fat transparent twin after every crease line and point dot, since a
  two-pixel line is too fine a target to hover or click.
- The highlight: every segment of a bundle at once, a paper boundary matched
  by its geometry, and the classes cleared again when the next command names
  something else.
- The construction overlay, for the lines the command dates to this step that
  the picture does not already carry as a crease. A folded frame answers that
  from its own edges; a flat sheet holds every crease of the final state, so
  there the statement each crease was scored at decides.
- A dashed ghost per segment of a settled entity that the folded drawing has
  no line for. Those coordinates come from `beloch:inspect`, which describes
  the final fold, so they are drawn at that frame and nowhere else.

It holds what it last drew. A command asking for the same picture re-lights
rather than rebuilds, so a pointer resting on a crease leaves a running fade
alone. The theme counts as part of the picture and is compared by
identity, so a host that builds a fresh theme object per call redraws on every
event: keep one object per style.

The viewport stays with the host. Pan, zoom and the element carrying the
transform are untouched by a swap, and the host decides whether a swap fades.

The markup it writes carries `bel-hit`, `bel-hl`, `bel-hl-ghost` and
`bel-fade-host` / `bel-fade-ghost`; what those look like is the host's
stylesheet, including whether the fade is a fade at all.

## Tests

`bun test` in this directory. The render-dom suite draws through
`@beloch/render-svg`, whose own workspace has to be installed for that import
to resolve: `bun install` in `packages/render-2d`.
