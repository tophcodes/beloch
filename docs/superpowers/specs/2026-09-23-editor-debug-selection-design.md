# What the editor says about the program

Point-in-time design document. It is written to be executed from and then
deleted; the durable part is already in ADR 0025 and ADR 0026, and what is
decided here about the interface belongs in `docs/brand/IMPLEMENTATION.md`
once it is built.

## The mistake this corrects

The playground marks the block a step stands for: the statement's line and
everything under it until the next statement. That came from a true sentence
about evaluation, that a step carries what the source under it built, and drew
a false conclusion about the interface.

The stepper is a display of the fold sequence. It belongs to the drawing. What
it can say about the program is which line folded, and nothing more. Marking
the block put the answer to a different question in its place, so a reader
always saw several statements at once and never one on its own.

Choosing a value in the program is a different job with a different audience.
It is a debugging move: point at the line that binds `--mid` and see `--mid` in
the drawing. It belongs to the editor, it needs no timeline, and it has no
business happening while the reader is typing.

## What gets built

**The stepper stops at every write.** A fold, a reverse, a flip, a flatten and
a mark: wherever the paper changed, whether it moved or was only scored. This
is where it stops today, and ADR 0026 states the axis that way.

**The step marker marks one line.** The line of the statement the drawing
stands at, as it did before the block. The block wash, the bar over every line
of a block and the per-block bars in the left lane all go.

**A debug mode, switched on in the editor.** While it is on:

- the editor is read-only, so a click is a choice and never a caret;
- every span that binds a value carries a box: a named point, a named line, a
  mark, and the crease a fold binds;
- clicking a box adds its value to the selection, clicking it again takes it
  out, and several can stand at once;
- the drawing lights every selected value, as it lights a settled selection
  today.

**The selection is the core's.** `selection: EntityRef[]` already holds a list
and already survives a step change; the playground has been constraining it to
one entity and calling that a pin. The constraint goes. The design document of
2026-09-22 said as much before either was built: the card's multi-selection and
the playground's single pin are two policies over one state shape.

Two sources fill it now. The drawing, by pointing at a crease, which settles
one entity as it does today. The program, in debug mode, by clicking the spans
that bind. Neither knows about the other, because both dispatch the same event.

## What the FOLD has to carry

ADR 0026 is the enabler, for a reason that has moved. The second axis is no
longer a second counter for the timeline. It is the map from statements to the
values they bind, which is what the editor needs to put a box anywhere.

- `beloch:statements` logs every top-level statement in source order, each with
  its kind and its source span.
- A named line carries `statement`, as a named point already does. Without it a
  construction line cannot be found in the source at all: it carries only the
  frame it was bound against, and a program with a `mark` in it leaves two
  blocks reading against one frame.
- A named point's `statement` becomes the statement that binds it rather than
  the next state-changing one.

## Acceptance test

Headless, in `bun test`, against a FOLD fixture with a point binding, a line
binding, a mark and two folds.

- The line a step marks is the statement's own line, at every step, including a
  step whose statement is a mark.
- Every binding span the fixture has is offered as a target, and a span that
  binds nothing is not.
- Clicking a target adds one entity to the selection; clicking the same target
  again removes it; the order of the list follows the order of the clicks.
- A step change leaves the selection standing, and the render command still
  lights it.
- Leaving debug mode leaves the selection standing and takes the boxes away.
- The editor refuses an edit while debug mode is on.

Not in the acceptance test: where the toggle sits and what it looks like. That
is the design brief's business.

## Open

- **What a box surrounds.** The whole line, or the span that binds. Spans are
  more precise and need the span data above; lines are cheaper and wrong for a
  statement that binds twice.
- **How the mode is reached.** A control in the toolbar, a key, or both.

## What this retracts

Three commits on `design-phase-2` built the block marking and its bars:
`feat(www): mark the step's block in the code and name its statement`,
`feat(www): stand every step's block in the editor's left lane`, and
`feat(www): mark where a block ends and light it as one target`. The statement
text beside the stepper survives all of this. The block marking and the bars do
not, and the lane the line padding opened is where the debug mode's boxes will
sit instead.
