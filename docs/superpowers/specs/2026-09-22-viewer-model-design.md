# The runtime: a composable owner for document and interaction state

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

1. A small core, the **runtime**, holds the state and derives the render
   command. Optional modules compose onto it. A consumer loads the runtime,
   the modules it needs, and plugs in its own renderer.
2. The runtime core is free of the DOM and free of side effects. A planned VS
   Code preview is a consumer, so nothing in the core may reach for the DOM,
   CodeMirror or SVG.
3. **Evaluation is a module beside the core.** The tour and the card
   evaluate nothing; they are handed a finished FOLD document. Only the
   playground and a VS Code preview evaluate, and they do it by different
   means.
4. **Picking among coincident lines is a module too.** The core knows one
   selection; resolving several entities that share a pixel into a choice is
   the playground's affordance, and the card and the tour never open it.
5. The editor owns the source text and reports changes. Everything derived
   from the text belongs to the runtime.
6. First slice: the core, the three modules the playground needs, the DOM
   renderer, and the playground migrated onto them.

## The core and its document slot

The runtime holds a **document slot**: a `FoldScene`, its statement list, its
inspect data, or nothing. The slot is set by an event, and who raises that
event is the composition's business. The evaluation module raises it after a
run; the card raises it once from the FOLD JSON embedded in its markup; the
tour raises it per section from a build-time evaluated program.

That single decision keeps the core small enough to compose. Without it the
tour would have to carry a worker it never uses, and the card would have to
pretend to evaluate what was already evaluated at build time.

Beside the slot the core holds:

**Interaction state.** Current step, the settled selection, the hovered
entity. This is the group all three consumers share and the reason the package
exists. What the core carries is one settled selection; how a reader arrived
at it belongs to whoever offered the choice.

The playground's "pinned" does not appear here. It means the tooltip has
stopped following the cursor and gained a close button, which is the view's
business. What the core needs from it is whether a selection is settled, and
a settled selection outranks the pointer: once the reader has picked a line,
moving the cursor away does not take the answer with it.

**Presentation options are arguments, not state.** View (`cp` / `folded`),
hidden mode, paper scheme and line style go to `renderCommand` as parameters.
The only reader of any of them is a renderer, and the `<Beloch>` card draws
the crease pattern and the folded form of one document side by side, so a
single state has to answer two drawing requests that differ here. Holding the
view in the core would leave the card unable to express itself with one
runtime. Step, selection and hover are the same in both drawings, which is
where the line falls.

**The render command.** The core derives it from the state above and the
caller's options, as plain data: which of three drawings to make (the crease pattern of a
document with no timeline, the flat sheet scored up to a statement, or one
folded frame), the hidden mode, the marks still dangling, and the highlight
set. It carries no scene and no theme: the document is in the state the
renderer already reads, and colours belong to the renderer. Deriving it in the
core lets a headless test assert what a view would draw without a view
existing. `svgForStep` in `Playground.astro` is this function today, buried in
the component.

The core does **not** hold the viewport. Pan offset, zoom scale, drag tracking
and pointer capture stay with the view, because two consumers showing the same
document at different zoom is correct behaviour.

## Modules

A module contributes a state slice, a pure reducer over its own events, and a
declaration of the effects it needs. The core imports no module. A module
reads core state and never another module's slice.

Effects stay out of the reducer, which is the pattern
`src/lib/playground-run-state.ts` already follows: it decides the run button
and the status line as a pure function of a state record, and the caller owns
the worker, both timers and the DOM writes. That file becomes the run-UI
decision inside the evaluation module and keeps its tests. The scheduler is
injected, so a headless test drives debounce and timeouts without waiting.

Four modules in this slice, each its own package under `packages/runtime/`:

**`@beloch/runtime` (core).** State, events, reducers, render-command
derivation. No DOM, no effects, no evaluation.

**`@beloch/runtime-eval`.** Source to document. Owns the phase machine
(`cold` / `loading` / `ready`), the in-flight run, load progress, the debounce,
and the dispatched-versus-pending source. Its **backend is swappable**: the
web consumers pass the wasm worker under `public/beloch/`, a VS Code preview
passes a subprocess running the native `beloch fold`. One interface, two
backends. This is the concrete payoff of making evaluation a module rather
than a core concern.

**`@beloch/runtime-pick`.** Coincident lines. It holds the candidate list and
the open flag, decides from a hit report whether a pick settles directly or
opens a choice, and dispatches the settled selection into the core. The hit
test itself stays with the view, which is the only side that knows what was
drawn where (see `pick-visibility.ts` and `lineEntitiesAtPoint`); the module
receives its verdict as data. A consumer that never has two entities on one
pixel omits this and picks by dispatching a selection.

**`@beloch/runtime-editor`.** Selection and spans, both directions: it turns
the runtime's selection into the spans an editor should mark (step line,
reference marks) and turns a cursor position into a selection. It reads
`document.inspect` and stays free of the DOM; the host passes a small adapter,
CodeMirror here, `TextDocument` in VS Code.

**`@beloch/runtime-render-dom`** is the renderer plug rather than a module: it
takes a render command and puts SVG in an element, wrapping
`@beloch/render-svg` and keeping the DOM work the playground carries today
(hit-line enhancement, ghosting, the crossfade). Any DOM host can use it, and
a host with a different surface writes its own plug instead.

## What each consumer composes

| Consumer | Core | eval | pick | editor | renderer |
|---|---|---|---|---|---|
| Playground | yes | wasm worker | yes | CodeMirror | render-dom |
| `<Beloch>` card | yes | no | no | no | render-dom |
| Model tour | yes | no | no | no | render-dom |
| VS Code preview | yes | subprocess | yes | `TextDocument` | its own |

The card and the tour need the core and a renderer. They set the document
once and dispatch step, view and highlight. That is the shape the composition
has to make possible, and it is how the core's size gets judged.

## Selection has to be reconciled first

The two existing consumers disagree about what a selection is.

The card keeps a `Set<string>` of `data-bel-name` values: several named
entities lit at once, no notion of a pinned one. The playground keeps one
`EntityRef | null` plus a candidate list for coincident lines, and identifies
a crease by `creaseId` rather than by name.

ADR-0014 settles the identity question: a crease is a bundle of segments, and
the bundle is what a selection names. So the core carries
`selection: EntityRef[]` with `hover: EntityRef | null` beside it, and each
consumer constrains what it dispatches. The card's multi-selection and the
playground's single pin are two policies over one state shape. The candidate
list leaves the core with the chooser, into `@beloch/runtime-pick`, because it
is a step on the way to a selection rather than a selection. Names stay what
the program calls an entity, resolved through the inspect data, never used as
the identity.

## Acceptance test

Headless tests in `bun test`, no browser.

**The core alone, no modules.** Given a FOLD document and nothing else, it
produces a render command, accepts step and selection events, and clamps the
step to the document. This is the card-and-tour path, and it is the test that
proves the core composes rather than merely exists.

**The core with the two modules**, driven through the sequences whose
invariants the playground maintains by hand today:

- hover, then pin, then hover elsewhere: the pin survives, hover is suppressed
- pin, then step forward: the pin survives the redraw and lights whatever the
  new step draws, or nothing, without clearing
- one state answers a crease-pattern and a folded request at once, with the
  same step and the same highlight in both (the card's side-by-side)
- a source change invalidates the document, the step and the pin together
- a failed run keeps the last good document and adds the diagnostic

**The pick module against hit reports.** One entity settles directly. Two or
more open the choice with every candidate, and choosing one closes it and
settles that selection. A hit report with nothing in it leaves the selection
alone, which is the drawing's honest answer where a buried segment is not
drawn.

**The eval module against a fake backend.** Phase transitions, debounce
collapsing two keystrokes into one run, a stalled load, and a run whose source
matches the previous one. The injected scheduler makes this instant.

Two guards beside them: the existing 201 tests in `packages/www` keep passing,
and `astro check` gains no errors.

Not in the acceptance test: pixel comparison of the SVG. A golden-file
conformance test across consumers was considered and set aside, because it
freezes the drawing and needs a DOM environment per consumer, while the
property under test is the state logic.

## First slice

In scope:

- `@beloch/runtime`, `@beloch/runtime-eval`, `@beloch/runtime-pick`,
  `@beloch/runtime-editor`, `@beloch/runtime-render-dom`.
- `playground-run-state.ts` moved into the eval module with its tests.
- `Playground.astro` migrated onto the composition, its inline script reduced
  to wiring and viewport handling.
- The headless suites above.

Out of scope, deliberately:

- Migrating the `<Beloch>` card and building the model tour. The core is
  tested for their path, and they move on their own schedule.
- The VS Code subprocess backend. The interface admits it; nothing is written
  until a preview panel exists.
- Behaviour changes. The migration is observable only as the same playground.
  Anything the reader could notice belongs in a separate change.

## Migration order

The playground works at the end of every step below, and each step is its own
commit. The order exists to keep that true: nothing here is a rewrite with a
broken interval in the middle.

1. **`@beloch/runtime` core.** State, events, reducers, render-command
   derivation. Gate: the core-alone test.
2. **`@beloch/runtime-render-dom`.** Render command to SVG in an element.
   Gate: a drawing the playground produces today, reproduced from a render
   command under happy-dom.
3. **The playground adopts core and renderer** for the document, the
   presentation options and the drawing. Its interaction state stays where it
   is for now. Gate: the 201 existing tests, plus the click list by hand.
4. **Interaction state moves in**: step, hover, pin, selection. Gate: the six
   sequences. This is the step that carries the invariants, so it moves alone.
5. **`@beloch/runtime-pick`** takes the chooser and the candidate list.
   Gate: the pick suite.
6. **`@beloch/runtime-editor`** takes the spans in both directions.
   Gate: the editor suite.
7. **`@beloch/runtime-eval`** takes the worker, the phases and the debounce;
   `playground-run-state.ts` moves in with its tests. Gate: the fake-backend
   suite. It goes last because it owns the only behaviour the reader watches
   while it happens, the runtime download and the run button.

Where the risk sits: step 4 holds the invariants that are currently kept by
hand at each call site, and step 7 holds everything the reader sees. Steps 1,
2, 5 and 6 are additive and reversible on their own.

## The name collision, resolved

"Runtime" named two things: this core, and the wasm evaluation runtime the
first run downloads. The second one gives up the word. In code it becomes the
**evaluator**: `EvaluatorPhase`, `EVALUATOR_SIZE`, and the eval module's
backend interface. The reader-facing status line keeps saying "loading runtime
(2.3 MB)", because the reader never meets a module name and changing that
string would be a visible change this slice does not make.

## What outlives this document

One ADR, on the decision and not on the mechanics: the web client holds its
state in a composable runtime, the core carries a document slot rather than an
evaluator, views are renderers plugged in by the consumer, and the editor owns
the text. It records what was rejected (state in each component, a framework
store, evaluation in the core, the coincidence chooser in the core, the
card's name-based selection as the identity) and the constraint that a non-DOM
consumer with a different evaluation backend is planned. Numbered 0024 unless something lands first.

The interfaces themselves stay in the packages' own types and doc comments,
where they cannot drift from the code.
