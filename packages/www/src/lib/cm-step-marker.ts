// CM6 line markers for the Playground: the source the currently-shown step
// stands for, marked with a bar down its left edge and a background over its
// lines, and a second highlight on the line a failed run reported.
// Read-only/display-only by design: it never moves the text cursor/selection,
// so it can't interfere with editing.
//
// The bars stand in the lane the line padding keeps free at the left edge of
// every line, rather than in a gutter column of their own: the column cost
// width the program is read in, and the lane is already there.
//
// A step stands for more than its own line. Only a fold or a mark makes a
// step, so everything between one of them and the next (a point, a named
// line, a comment) is in force at the step that precedes it, and the drawing
// shows what it built. Marking the block rather than the line is what keeps
// the editor and the drawing saying the same thing.
//
// The two markers are independent: a diagnostic leaves the last valid drawing
// and its step marker standing (B3.5), so both lines can be lit at once.
import { Decoration, EditorView, WidgetType } from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { StateEffect, StateField } from "@codemirror/state";
import type { EditorState, Extension } from "@codemirror/state";

// The source a step stands for: every line from `line` through `to` carries
// the mark.
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

// Every block the program divides into, so the source says how many steps
// there are and which one is on screen. The current block's own mark is the
// step line above; a bar stands on every block, the current one solid.
export interface StepBlockSpan { step: number; fromLine: number; toLine: number }

export const setStepBlocks = StateEffect.define<StepBlockSpan[]>();

// One block's bar on one line. Absolutely positioned inside the line, so it
// sits in the padding lane and takes no room in the text.
//
// The ends of a block are marked: the bar pulls in at the first and the last
// line of its block, so two blocks that meet read as two bars rather than as
// one unbroken column.
interface BarState {
  step: number;
  current: boolean;
  hovered: boolean;
  head: boolean;
  tail: boolean;
}

class StepBarWidget extends WidgetType {
  constructor(private readonly state: BarState) {
    super();
  }
  override eq(other: StepBarWidget) {
    const a = this.state, b = other.state;
    return (
      a.step === b.step && a.current === b.current &&
      a.hovered === b.hovered && a.head === b.head && a.tail === b.tail
    );
  }
  override toDOM() {
    const { step, current, hovered, head, tail } = this.state;
    const bar = document.createElement("span");
    bar.className =
      "cm-step-bar" +
      (current ? " is-current" : "") +
      (hovered ? " is-hover" : "") +
      (head ? " is-head" : "") +
      (tail ? " is-tail" : "");
    bar.dataset.step = String(step);
    bar.title = step === 0 ? "Starting paper" : `Step ${step}`;
    return bar;
  }
  override ignoreEvent() {
    // The bar answers the pointer itself: a click on it is a jump, never a
    // place for the cursor.
    return false;
  }
}

// The block the pointer is over. A block is one target, so pointing anywhere
// in it lights its whole bar rather than the one line under the cursor.
export const setHoveredStep = StateEffect.define<number | null>();

const hoveredStepField = StateField.define<number | null>({
  create: () => null,
  update(value, tr) {
    let step = value;
    for (const e of tr.effects) if (e.is(setHoveredStep)) step = e.value;
    return step;
  },
});

function barsFor(
  state: EditorState,
  blocks: StepBlockSpan[],
  current: StepBlock | null,
  hovered: number | null,
): DecorationSet {
  const ranges = [];
  for (const b of blocks) {
    const first = Math.max(1, b.fromLine);
    const last = Math.min(b.toLine, state.doc.lines);
    for (let n = first; n <= last; n++) {
      const inCurrent =
        current !== null && n >= current.line && n <= Math.max(current.to, current.line);
      ranges.push(
        Decoration.widget({
          widget: new StepBarWidget({
            step: b.step,
            current: inCurrent,
            hovered: hovered === b.step,
            head: n === first,
            tail: n === last,
          }),
          side: -1,
        }).range(state.doc.line(n).from),
      );
    }
  }
  return Decoration.set(ranges, true);
}

interface StepBlocksValue { blocks: StepBlockSpan[]; deco: DecorationSet }

const stepBlocksField = StateField.define<StepBlocksValue>({
  create: () => ({ blocks: [], deco: Decoration.none }),
  update(value, tr) {
    let blocks = value.blocks;
    for (const e of tr.effects) if (e.is(setStepBlocks)) blocks = e.value;
    // Which block is on screen and which one the pointer is over are answered
    // elsewhere, so the bars are rebuilt when either moves.
    const moved = tr.effects.some((e) => e.is(setStepLine) || e.is(setHoveredStep));
    if (blocks === value.blocks && !tr.docChanged && !moved) return value;
    return {
      blocks,
      deco: barsFor(
        tr.state,
        blocks,
        tr.state.field(stepLineField).block,
        tr.state.field(hoveredStepField),
      ),
    };
  },
  provide: (f) => EditorView.decorations.from(f, (v) => v.deco),
});

/** The block whose bar was clicked, or nothing. */
const barStep = (target: EventTarget | null): number | null => {
  const bar = target instanceof Element ? target.closest<HTMLElement>(".cm-step-bar") : null;
  const step = bar?.dataset.step;
  return step === undefined ? null : Number(step);
};

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
 * block's bar; without it the bars are shown and inert. */
export function stepMarkerExtensions(
  opts: { onPickStep?: (step: number) => void } = {},
): Extension[] {
  const onPick = opts.onPickStep;
  return [
    stepLineField,
    hoveredStepField,
    stepBlocksField,
    errorLineField,
    EditorView.domEventHandlers({
      mousedown(event) {
        if (onPick === undefined) return false;
        const step = barStep(event.target);
        if (step === null) return false;
        onPick(step);
        return true;
      },
    }),
  ];
}

/** Show the blocks the program divides into, or clear them with an empty
 * list. */
export function setStepBlocksOn(view: EditorView, blocks: StepBlockSpan[]) {
  view.dispatch({ effects: setStepBlocks.of(blocks) });
}

/** Light the bar of the block the pointer is over, or none with `null`. */
export function setHoveredStepOn(view: EditorView, step: number | null) {
  if (view.state.field(hoveredStepField) === step) return;
  view.dispatch({ effects: setHoveredStep.of(step) });
}

/** Show (or, with `line: null`, clear) the step marker: the bar and the
 * background over `line` through `opts.through`, with the first line scrolled
 * into view. Never touches the selection/cursor. */
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
