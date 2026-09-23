// CM6 line markers for the Playground: a small gutter dot (breakpoint-style)
// plus a line-background highlight over the source the currently-shown step
// stands for, and a second highlight on the line a failed run reported.
// Read-only/display-only by design: it never moves the text cursor/selection,
// so it can't interfere with editing.
//
// A step stands for more than its own line. Only a fold or a mark makes a
// step, so everything between one of them and the next (a point, a named
// line, a comment) is in force at the step that precedes it, and the drawing
// shows what it built. Marking the block rather than the line is what keeps
// the editor and the drawing saying the same thing.
//
// The two markers are independent: a diagnostic leaves the last valid drawing
// and its step marker standing (B3.5), so both lines can be lit at once.
import {
  Decoration, EditorView, gutter, GutterMarker,
} from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { StateEffect, StateField } from "@codemirror/state";
import type { EditorState, Extension } from "@codemirror/state";

// The source a step stands for: its first line carries the gutter dot, and
// every line through `to` carries the background.
export interface StepBlock { line: number; to: number }

export const setStepLine = StateEffect.define<StepBlock | null>();

interface StepLineValue { block: StepBlock | null; deco: DecorationSet }

function decorationsFor(state: EditorState, block: StepBlock | null): DecorationSet {
  if (block == null || block.line < 1 || block.line > state.doc.lines) return Decoration.none;
  const last = Math.min(Math.max(block.to, block.line), state.doc.lines);
  const deco = Decoration.line({ attributes: { class: "cm-step-line" } });
  const ranges = [];
  for (let n = block.line; n <= last; n++) ranges.push(deco.range(state.doc.line(n).from));
  return Decoration.set(ranges);
}

const sameBlock = (a: StepBlock | null, b: StepBlock | null): boolean =>
  a === b || (a !== null && b !== null && a.line === b.line && a.to === b.to);

const stepLineField = StateField.define<StepLineValue>({
  create: () => ({ block: null, deco: Decoration.none }),
  update(value, tr) {
    let block = value.block;
    for (const e of tr.effects) if (e.is(setStepLine)) block = e.value;
    if (sameBlock(block, value.block) && !tr.docChanged) return value;
    return { block, deco: decorationsFor(tr.state, block) };
  },
  provide: (f) => EditorView.decorations.from(f, (v) => v.deco),
});

// Where a step can be reached from the source: the block it stands for, and
// the step it is. The gutter draws one bar per block, so the column says how
// the program divides into steps and which of them is on screen, rather than
// pointing at one line of each.
export interface StepSlot { step: number; fromLine: number; toLine: number }

export const setStepSlots = StateEffect.define<StepSlot[]>();

const stepSlotsField = StateField.define<StepSlot[]>({
  create: () => [],
  update(value, tr) {
    let slots = value;
    for (const e of tr.effects) if (e.is(setStepSlots)) slots = e.value;
    return slots;
  },
});

// The block the pointer is over, which lights its bar and is what a host
// answers by lighting what that block built.
const setHoveredStep = StateEffect.define<number | null>();

const hoveredStepField = StateField.define<number | null>({
  create: () => null,
  update(value, tr) {
    let step = value;
    for (const e of tr.effects) if (e.is(setHoveredStep)) step = e.value;
    return step;
  },
});

// One line's piece of a block's bar. The ends are marked so the bar reads as
// one shape over its lines rather than a column of segments.
class StepBarMarker extends GutterMarker {
  constructor(
    private readonly step: number,
    private readonly state: "current" | "hover" | "rest",
    private readonly head: boolean,
    private readonly tail: boolean,
  ) {
    super();
  }
  override eq(other: StepBarMarker) {
    return (
      other.step === this.step &&
      other.state === this.state &&
      other.head === this.head &&
      other.tail === this.tail
    );
  }
  toDOM() {
    const bar = document.createElement("span");
    bar.className =
      `cm-step-bar${this.state === "rest" ? "" : ` is-${this.state}`}` +
      `${this.head ? " is-head" : ""}${this.tail ? " is-tail" : ""}`;
    bar.title = this.step === 0 ? "Starting paper" : `Step ${this.step}`;
    return bar;
  }
}

// A line a marked block covers that no step owns: the line a clicked crease
// was built on. It keeps the dot, which points rather than spans.
class StepDotMarker extends GutterMarker {
  override eq() {
    return true;
  }
  toDOM() {
    const dot = document.createElement("span");
    dot.className = "cm-step-dot";
    return dot;
  }
}
const stepDotMarker = new StepDotMarker();

/** The step whose block covers this line, if one does. */
export const slotAtLine = (state: EditorState, line: number): StepSlot | undefined =>
  state.field(stepSlotsField).find((s) => line >= s.fromLine && line <= s.toLine);

const markerFor = (state: EditorState, lineNumber: number): GutterMarker | null => {
  const { block } = state.field(stepLineField);
  const slot = slotAtLine(state, lineNumber);
  if (slot) {
    const current = block != null && block.line === slot.fromLine;
    const hovered = state.field(hoveredStepField) === slot.step;
    return new StepBarMarker(
      slot.step,
      current ? "current" : hovered ? "hover" : "rest",
      lineNumber === slot.fromLine,
      lineNumber === slot.toLine,
    );
  }
  return block != null && block.line === lineNumber ? stepDotMarker : null;
};

interface GutterHooks {
  onPick: ((step: number) => void) | null;
  onHover: ((step: number | null) => void) | null;
}

const stepGutterExtension = ({ onPick, onHover }: GutterHooks) =>
  gutter({
    class: "cm-step-gutter",
    lineMarker: (view, line) => markerFor(view.state, view.state.doc.lineAt(line.from).number),
    lineMarkerChange: (update) =>
      !sameBlock(
        update.startState.field(stepLineField).block,
        update.state.field(stepLineField).block,
      ) ||
      update.startState.field(stepSlotsField) !== update.state.field(stepSlotsField) ||
      update.startState.field(hoveredStepField) !== update.state.field(hoveredStepField),
    domEventHandlers: {
      mousedown(view, line) {
        if (onPick === null) return false;
        const slot = slotAtLine(view.state, view.state.doc.lineAt(line.from).number);
        if (!slot) return false;
        onPick(slot.step);
        return true;
      },
      mousemove(view, line) {
        const slot = slotAtLine(view.state, view.state.doc.lineAt(line.from).number);
        const step = slot?.step ?? null;
        if (view.state.field(hoveredStepField) !== step) {
          view.dispatch({ effects: setHoveredStep.of(step) });
          onHover?.(step);
        }
        return false;
      },
      mouseleave(view) {
        if (view.state.field(hoveredStepField) !== null) {
          view.dispatch({ effects: setHoveredStep.of(null) });
          onHover?.(null);
        }
        return false;
      },
    },
  });

// The line a failed run named. Same mechanism as the step line, its own
// effect and field so neither clears the other.
export const setErrorLine = StateEffect.define<number | null>();

interface ErrorLineValue { line: number | null; deco: DecorationSet }

const errorLineField = StateField.define<ErrorLineValue>({
  create: () => ({ line: null, deco: Decoration.none }),
  update(value, tr) {
    let line = value.line;
    for (const e of tr.effects) if (e.is(setErrorLine)) line = e.value;
    if (line === value.line && !tr.docChanged) return value;
    return { line, deco: errorDecorationsFor(tr.state, line) };
  },
  provide: (f) => EditorView.decorations.from(f, (v) => v.deco),
});

function errorDecorationsFor(state: EditorState, line: number | null): DecorationSet {
  if (line == null || line < 1 || line > state.doc.lines) return Decoration.none;
  const { from } = state.doc.line(line);
  return Decoration.set([
    Decoration.line({ attributes: { class: "cm-error-line" } }).range(from),
  ]);
}

/** The marker extensions. `onPickStep` is called when the reader clicks a
 * step's bar in the gutter, `onHoverStep` when the pointer enters or leaves
 * one. Without them the bars are shown and inert. */
export function stepMarkerExtensions(
  opts: {
    onPickStep?: (step: number) => void;
    onHoverStep?: (step: number | null) => void;
  } = {},
): Extension[] {
  return [
    stepLineField,
    stepSlotsField,
    hoveredStepField,
    errorLineField,
    stepGutterExtension({
      onPick: opts.onPickStep ?? null,
      onHover: opts.onHoverStep ?? null,
    }),
  ];
}

/** Show the slots a reader can jump to, or clear them with an empty list. */
export function setStepSlotsOn(view: EditorView, slots: StepSlot[]) {
  view.dispatch({ effects: setStepSlots.of(slots) });
}

/** Show (or, with `line: null`, clear) the step marker: the gutter dot on
 * `line`, the background over `line` through `opts.through`, and the first
 * line scrolled into view. Never touches the selection/cursor. */
// `through` (default `line`) is the last line the step stands for. A block
// that ends above where it starts stands for nothing and clears the marker,
// which is what a program whose first statement is also its first line asks
// for.
//
// `reveal` (default true) also brings the line into view. Stepping through a
// program wants that; marking the line a clicked crease was built on does
// not, because the reader is looking at the drawing and did not ask the
// editor to move.
export function setStepLineOn(
  view: EditorView,
  line: number | null,
  opts: { through?: number; reveal?: boolean } = {},
) {
  const to = opts.through ?? line;
  const block = line == null || to == null || to < line ? null : { line, to };
  view.dispatch({ effects: setStepLine.of(block) });
  if (opts.reveal !== false && block !== null && block.line >= 1 && block.line <= view.state.doc.lines) {
    const pos = view.state.doc.line(block.line).from;
    view.dispatch({ effects: EditorView.scrollIntoView(pos, { y: "center" }) });
  }
}

/** Show (or, with `line: null`, clear) the highlight on the line a failed run
 * named, and scroll it into view. Never touches the selection/cursor. */
export function setErrorLineOn(view: EditorView, line: number | null) {
  view.dispatch({ effects: setErrorLine.of(line) });
  if (line != null && line >= 1 && line <= view.state.doc.lines) {
    const pos = view.state.doc.line(line).from;
    view.dispatch({ effects: EditorView.scrollIntoView(pos, { y: "center" }) });
  }
}
