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

## What the core holds

A **document slot**: one `FoldScene`, or nothing. Who fills it is the
composition's business. An evaluation module fills it after a run, a card
fills it from the FOLD embedded in its markup, a scroll-driven tour fills it
per section from a program evaluated at build time. Nothing in the core
evaluates, so a consumer that never evaluates carries no evaluator.

The **step**, as a statement index from 0 to `statements.length`. 0 is the
sheet before any statement ran; n means every statement has been applied.
Frames are the renderer's business, reached through `statements[i].frameIndex`.

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
