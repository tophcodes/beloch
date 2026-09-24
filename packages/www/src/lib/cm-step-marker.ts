// CM6 line markers for the Playground: the line of the statement the drawing
// stands at, marked with a background, and a failed run shown in the code
// under the line it names.
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
import { Decoration, EditorView, GutterMarker, WidgetType, gutterLineClass } from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { RangeSet, StateEffect, StateField } from "@codemirror/state";
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

// A failed run, shown in the code (ADR 0028): its line marked, the span it
// names underlined, a caret row with the message and a hint row inserted under
// that line, and every line after it dimmed. Its own effect and field, so the
// step marker and this one never clear each other.
export interface ErrorMark {
  line: number;
  // 1-based, the end one past the last character; null marks the line only.
  span: { fromLine: number; fromCol: number; toLine: number; toCol: number } | null;
  message: string;
  hint: string | null;
}

export const setError = StateEffect.define<ErrorMark | null>();

// Held as document offsets; `to` is clipped to the first line, since the caret
// row can only stand under one. Any edit drops the marks: they describe the
// text the run saw, and the next run says what holds for the new one.
interface ErrorValue {
  at: { from: number; to: number } | null;
  message: string;
  hint: string | null;
  deco: DecorationSet;
}

const noError: ErrorValue = { at: null, message: "", hint: null, deco: Decoration.none };

function offsetsOf(state: EditorState, mark: ErrorMark): { from: number; to: number } | null {
  const { doc } = state;
  if (mark.span) {
    const s = mark.span;
    if (s.fromLine < 1 || s.fromLine > doc.lines) return null;
    const line = doc.line(s.fromLine);
    const from = Math.min(line.from + s.fromCol - 1, line.to);
    const end = s.toLine === s.fromLine ? line.from + s.toCol - 1 : line.to;
    return { from, to: Math.max(from, Math.min(end, line.to)) };
  }
  if (mark.line < 1 || mark.line > doc.lines) return null;
  const { from } = doc.line(mark.line);
  return { from, to: from };
}

// The caret row counts columns in characters, so a tab before the span
// shifts it. Programs are written with spaces; tabs would need the editor's
// tab size here.
class ErrorDetail extends WidgetType {
  constructor(
    readonly indent: number,
    readonly width: number,
    readonly message: string,
    readonly hint: string | null,
  ) {
    super();
  }
  eq(other: ErrorDetail) {
    return other.indent === this.indent && other.width === this.width &&
      other.message === this.message && other.hint === this.hint;
  }
  toDOM() {
    const box = document.createElement("div");
    box.className = "cm-error-detail";
    // The alert region beside the drawing announces the same words.
    box.setAttribute("aria-hidden", "true");
    const pad = " ".repeat(this.indent);
    const caret = document.createElement("div");
    caret.className = "cm-error-caret";
    caret.textContent = this.width > 0
      ? `${pad}^${"~".repeat(this.width - 1)} ${this.message}`
      : this.message;
    box.appendChild(caret);
    if (this.hint !== null) {
      const hint = document.createElement("div");
      hint.className = "cm-error-hint";
      hint.textContent = this.width > 0 ? `${pad}${this.hint}` : this.hint;
      box.appendChild(hint);
    }
    return box;
  }
  ignoreEvent() {
    return false;
  }
}

function errorDecorations(state: EditorState, v: Omit<ErrorValue, "deco">): DecorationSet {
  if (!v.at) return Decoration.none;
  const line = state.doc.lineAt(v.at.from);
  const width = v.at.to - v.at.from;
  const ranges = [
    Decoration.line({ attributes: { class: "cm-error-line" } }).range(line.from),
  ];
  if (width > 0) ranges.push(Decoration.mark({ class: "cm-error-word" }).range(v.at.from, v.at.to));
  ranges.push(
    Decoration.widget({
      widget: new ErrorDetail(width > 0 ? v.at.from - line.from : 0, width, v.message, v.hint),
      block: true,
      side: 1,
    }).range(line.to),
  );
  for (let n = line.number + 1; n <= state.doc.lines; n++) {
    ranges.push(Decoration.line({ attributes: { class: "cm-after-error" } }).range(state.doc.line(n).from));
  }
  return Decoration.set(ranges, true);
}

const errorField = StateField.define<ErrorValue>({
  create: () => noError,
  update(value, tr) {
    let next: Omit<ErrorValue, "deco"> | null = null;
    for (const e of tr.effects) {
      if (!e.is(setError)) continue;
      next = e.value === null
        ? noError
        : { at: offsetsOf(tr.state, e.value), message: e.value.message, hint: e.value.hint };
    }
    if (next === null) {
      return tr.docChanged && value.at ? noError : value;
    }
    return { ...next, deco: errorDecorations(tr.state, next) };
  },
  provide: (f) => EditorView.decorations.from(f, (v) => v.deco),
});

class ErrorGutterMark extends GutterMarker {
  elementClass = "cm-error-gutter";
}
const errorGutterMark = new ErrorGutterMark();

// The failed line's number carries a cross, in every gutter that draws it.
const errorGutter = gutterLineClass.compute([errorField], (state) => {
  const { at } = state.field(errorField);
  if (!at) return RangeSet.empty;
  return RangeSet.of([errorGutterMark.range(state.doc.lineAt(at.from).from)]);
});

/** The marker extensions. */
export function stepMarkerExtensions(): Extension[] {
  return [stepLineField, errorField, errorGutter];
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

/** Show (or, with `null`, clear) a failed run in the code, and scroll its
 * line into view. Never touches the selection/cursor. */
export function setErrorOn(view: EditorView, mark: ErrorMark | null) {
  view.dispatch({ effects: setError.of(mark) });
  const { at } = view.state.field(errorField);
  if (at) view.dispatch({ effects: EditorView.scrollIntoView(at.from, { y: "center" }) });
}
