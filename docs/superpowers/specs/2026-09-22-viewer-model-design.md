# The viewer model: one owner for document and interaction state

Point-in-time design document. It is written to be executed from and then
deleted; the durable part becomes an ADR (see "What outlives this document").

## Problem

Three consumers render the same thing and each wires it by hand.

`packages/www/src/components/Playground.astro` holds 27 mutable closure
variables in one 2642-line inline script. `src/lib/beloch-figure.ts` holds its
own `scene`, `step` and `selected`, with its own bidirectional hover wiring.
`notes/2026-09-17-model-tour-renderer.md` sketches a third consumer, the
scroll-driven model tour, and lists as its state exactly what the other two
already carry: program, step, view and highlight.

The cost shows up three ways.

**Duplication.** The card and the playground answer "which crease did the
reader point at, and which statement made it" twice, differently. The tour
would answer it a third time.

**Every path re-does everything.** A step change has to rebuild the drawing,
re-apply the anchored highlight, re-clamp the step index, sync the nav
buttons, and put the editor marks back. Each of those is a separate call at
each call site, so a new interaction path starts by rediscovering which five
things it owes.

**The views drift.** Selection, hover and step live in three places that must
agree and have no mechanism forcing them to.

## Decision frame

Settled in conversation on 2026-09-22:

1. The model is a separate package with a DOM-free core.
2. It owns the document state, the interaction state, and the render command.
   Views become renderers without decisions of their own.
3. A future VS Code preview counts as a consumer, so the core may not reach
   for the DOM, CodeMirror or SVG. Renderer and editor attach as adapters.
4. The editor owns the source text and reports changes. Everything derived
   from the text belongs to the model.
5. First slice: the core plus the playground migration. The playground is the
   only consumer that exercises the whole state, so it is what proves the
   interface.

## What the model owns

The playground's 27 variables sort into five groups, and the sort is the
design.

**Document state, owned by the model.** The last evaluated source, the
`FoldScene` it produced, the statement list, the inspect data, the diagnostic
of a failed run. Derived from text the model does not own.

**Evaluation lifecycle, owned by the model.** Worker handle, phase
(`cold` / `loading` / `ready`), in-flight run, load progress, the debounce
timers, the dispatched-versus-pending source. `playground-run-state.ts`
already decides the run button and status line from this as a pure function;
it moves into the core unchanged and keeps its tests.

**Interaction state, owned by the model.** Current step, the pinned entity,
the coincidence chooser's open flag and its candidates, the hovered entity.
This is the group the three consumers share and the reason the package exists.

**Presentation options, owned by the model.** View (`cp` / `folded`), hidden
mode (`hide` / `dashed` / `depth`), paper scheme, line style. They are inputs
to the render command, so they belong with it.

**Viewport, owned by the view.** Pan offset, zoom scale, drag tracking,
pointer capture. A second consumer showing the same document at a different
zoom is correct behaviour, so this state stays local and the core never sees
it.

## The seams

Three interfaces, and the core depends on none of them concretely.

**The store.** `subscribe(listener)` plus one `dispatch(event)`. Events are
the reader's intentions (`hover`, `pick`, `pin`, `unpin`, `step`,
`setHidden`, `sourceChanged`, `runRequested`), never state assignments. A
listener receives the new state and the render command derived from it. The
model is the only writer, so "both views render the same state" is a property
of the code rather than a habit of the call sites.

**The renderer adapter.** Takes a render command (scene, step, view, options,
highlight set) and puts a drawing somewhere. The SVG adapter in
`packages/www` wraps `@beloch/render-svg` and keeps the DOM work that lives in
the playground today: hit-line enhancement, ghosting, the crossfade.

**The editor adapter.** Reports text changes and cursor position to the model,
receives the spans to mark (step line, reference marks, selection). CodeMirror
here, `TextDocument` in VS Code. Text flows one way into the model and marks
flow one way out, which is why no version reconciliation is needed.

## Selection has to be reconciled first

The two existing consumers disagree about what a selection is.

The card keeps a `Set<string>` of `data-bel-name` values: several named
entities lit at once, no notion of a pinned one. The playground keeps one
`EntityRef | null` plus a candidate list for coincident lines, and identifies
a crease by `creaseId` rather than by name.

ADR-0014 settles the identity question: a crease is a bundle of segments, and
the bundle is what a selection names. So the model carries
`selection: EntityRef[]` with `pinned: EntityRef | null` beside it, and each
consumer constrains what it dispatches. The card's multi-selection and the
playground's single pin are two policies over one state shape. Names stay what
the program calls an entity, resolved through the inspect data, never used as
the identity.

## Acceptance test

Headless tests on the core, in `bun test`, no browser.

A test drives the model with an interaction sequence and asserts the render
command and the editor marks it emits. The sequences that matter are the ones
whose invariants the playground currently maintains by hand:

- hover, then pin, then hover elsewhere: the pin survives, hover is suppressed
- pin, then step forward: the pin survives the redraw and lights whatever the
  new step draws, or nothing, without clearing
- pick on coincident lines: the chooser opens with every candidate, and a
  candidate pick closes it and pins that one
- toggle hidden mode: the render command changes, the selection does not
- a source change invalidates the scene, the step and the pin together
- a failed run keeps the last good drawing and adds the diagnostic

Two guards beside them: the existing 201 tests in `packages/www` keep passing,
and `astro check` gains no errors.

Not in the acceptance test: pixel comparison of the SVG. A golden-file
conformance test across consumers was considered and set aside, because it
freezes the drawing and needs a DOM environment per consumer, while the
property under test is the state logic.

## First slice

In scope:

- The package, core only, with the store, the state shape, the render command
  and the two adapter interfaces.
- `playground-run-state.ts` moved into it with its tests.
- The SVG renderer adapter and the CodeMirror editor adapter in
  `packages/www`.
- `Playground.astro` migrated onto it, its inline script reduced to wiring.
- The headless test suite above.

Out of scope, deliberately:

- The `<Beloch>` card and the model tour. They migrate once the interface has
  carried the playground.
- Any VS Code adapter. The constraint shapes the core now; the adapter waits
  for a preview panel to exist.
- Behaviour changes. The migration is observable only as the same playground.
  Anything the reader could notice belongs in a separate change.

## Naming hazard

"Runtime" is taken. `playground-run-state.ts` uses it for the wasm evaluation
runtime (`RuntimePhase`, `RUNTIME_SIZE`, "loading runtime"), and that
vocabulary reaches the user in the status line. A second meaning would make
every sentence about either one ambiguous.

Proposal: the package is `@beloch/viewer` at `packages/viewer/`, and the thing
it holds is the **viewer model**. It sits above `@beloch/scene` and
`@beloch/render-svg` and depends on the first only.

## What outlives this document

One ADR, on the decision and not on the mechanics: the web client holds its
state in one model package with a DOM-free core, views are renderers, the
editor owns the text. It records what was rejected (state in each component,
a framework store, the card's name-based selection as the identity) and the
constraint that a non-DOM consumer is planned. Numbered 0024 unless something
lands first.

The interface itself stays in the package's own types and doc comments, where
it cannot drift from the code.
