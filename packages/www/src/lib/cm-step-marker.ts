// CM6 extension pair for the Playground's step player: a small gutter dot
// (breakpoint-style) plus a line-background highlight on whichever source
// line produced the currently-shown fold step. Read-only/display-only by
// design — it never moves the text cursor/selection, so it can't interfere
// with editing (see docs/superpowers/specs/2026-07-19-playground-step-navigation-design.md).
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

export const stepMarkerExtensions = [stepLineField, stepGutterExtension];

/** Show (or, with `line: null`, clear) the step-line gutter dot + highlight,
 * and scroll it into view. Never touches the selection/cursor. */
export function setStepLineOn(view: EditorView, line: number | null) {
  view.dispatch({ effects: setStepLine.of(line) });
  if (line != null && line >= 1 && line <= view.state.doc.lines) {
    const pos = view.state.doc.line(line).from;
    view.dispatch({ effects: EditorView.scrollIntoView(pos, { y: "center" }) });
  }
}
