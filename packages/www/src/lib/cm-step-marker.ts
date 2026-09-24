// CM6 line markers for the Playground: the line of the statement the drawing
// stands at, marked with a background, and a second highlight on the line a
// failed run reported.
// Read-only/display-only by design: it never moves the text cursor/selection,
// so it can't interfere with editing.
//
// The stepper is a display of the fold sequence, and what it can say about the
// program is which line folded. Marking everything under that line until the
// next statement answered a different question, so a reader saw several
// statements at once and never one on its own. Which value a statement binds
// is the editor's debug mode, not the stepper's.
//
// The two markers are independent: a diagnostic leaves the last valid drawing
// and its step marker standing (B3.5), so both lines can be lit at once.
import { Decoration, EditorView } from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { StateEffect, StateField } from "@codemirror/state";
import type { EditorState, Extension } from "@codemirror/state";

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

/** The marker extensions. */
export function stepMarkerExtensions(): Extension[] {
  return [stepLineField, errorLineField];
}

/** Show (or, with `line: null`, clear) the step marker on `line`. Never
 * touches the selection/cursor, and never scrolls. */
// Marking the line does not bring it into view. Where the reader put the
// program is theirs: a step taken while reading line 40 of a long program has
// no business pulling the text back to line 3, and the drawing they are
// watching would go with it.
export function setStepLineOn(view: EditorView, line: number | null) {
  view.dispatch({ effects: setStepLine.of(line) });
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
