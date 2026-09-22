// CM6 line markers for the Playground: a small gutter dot (breakpoint-style)
// plus a line-background highlight on whichever source line produced the
// currently-shown fold step, and a second highlight on the line a failed run
// reported. Read-only/display-only by design: it never moves the text
// cursor/selection, so it can't interfere with editing.
//
// The two markers are independent: a diagnostic leaves the last valid drawing
// and its step marker standing (B3.5), so both lines can be lit at once.
import {
  Decoration, EditorView, gutter, GutterMarker,
} from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { StateEffect, StateField } from "@codemirror/state";
import type { EditorState } from "@codemirror/state";

export const setStepLine = StateEffect.define<number | null>();

interface StepLineValue { line: number | null; deco: DecorationSet }

function decorationsFor(state: EditorState, line: number | null): DecorationSet {
  if (line == null || line < 1 || line > state.doc.lines) return Decoration.none;
  const { from } = state.doc.line(line);
  return Decoration.set([
    Decoration.line({ attributes: { class: "cm-step-line" } }).range(from),
  ]);
}

const stepLineField = StateField.define<StepLineValue>({
  create: () => ({ line: null, deco: Decoration.none }),
  update(value, tr) {
    let line = value.line;
    for (const e of tr.effects) if (e.is(setStepLine)) line = e.value;
    if (line === value.line && !tr.docChanged) return value;
    return { line, deco: decorationsFor(tr.state, line) };
  },
  provide: (f) => EditorView.decorations.from(f, (v) => v.deco),
});

class StepDotMarker extends GutterMarker {
  toDOM() {
    const dot = document.createElement("span");
    dot.className = "cm-step-dot";
    return dot;
  }
}
const stepDotMarker = new StepDotMarker();

const stepGutterExtension = gutter({
  class: "cm-step-gutter",
  lineMarker(view, line) {
    const { line: current } = view.state.field(stepLineField);
    if (current == null) return null;
    return view.state.doc.lineAt(line.from).number === current ? stepDotMarker : null;
  },
  lineMarkerChange: (update) =>
    update.startState.field(stepLineField).line !== update.state.field(stepLineField).line,
});

// The line a failed run named. Same mechanism as the step line, its own
// effect and field so neither clears the other.
export const setErrorLine = StateEffect.define<number | null>();

const errorLineField = StateField.define<StepLineValue>({
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

export const stepMarkerExtensions = [stepLineField, errorLineField, stepGutterExtension];

/** Show (or, with `line: null`, clear) the step-line gutter dot + highlight,
 * and scroll it into view. Never touches the selection/cursor. */
// `reveal` (default true) also brings the line into view. Stepping through a
// program wants that; marking the line a clicked crease was built on does
// not, because the reader is looking at the drawing and did not ask the
// editor to move.
export function setStepLineOn(
  view: EditorView,
  line: number | null,
  opts: { reveal?: boolean } = {},
) {
  view.dispatch({ effects: setStepLine.of(line) });
  if (opts.reveal !== false && line != null && line >= 1 && line <= view.state.doc.lines) {
    const pos = view.state.doc.line(line).from;
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
