// CM6 character-range marks for the Playground: every place the program
// names the crease bundle the reader has clicked in the drawing. The ranges
// come from `beloch:references`, which the evaluator emits at the point each
// name is resolved. Re-lexing the source could not produce them, because one
// spelling names different creases inside a `def` body and after a `--x!`
// rebinding.
//
// Display-only, like the step marker beside it: it never moves the cursor or
// the selection, and it never scrolls.
import { parseSpan } from "@beloch/runtime-editor";
import { Decoration, EditorView } from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { RangeSetBuilder, StateEffect, StateField } from "@codemirror/state";
import type { EditorState } from "@codemirror/state";

export const setRefSpans = StateEffect.define<string[]>();

// Document offsets for a span, or null when it falls outside the text the
// editor currently holds. That happens whenever the program has been edited
// since the run that produced the span.
export function spanToRange(
  state: EditorState,
  span: string,
): { from: number; to: number } | null {
  const p = parseSpan(span);
  if (!p) return null;
  if (p.fromLine < 1 || p.toLine < 1) return null;
  if (p.fromLine > state.doc.lines || p.toLine > state.doc.lines) return null;
  const a = state.doc.line(p.fromLine);
  const b = state.doc.line(p.toLine);
  const from = Math.min(a.from + p.fromCol - 1, a.to);
  const to = Math.min(b.from + p.toCol - 1, b.to);
  return to > from ? { from, to } : null;
}

const refMark = Decoration.mark({ class: "cm-bel-ref" });

function decorationsFor(state: EditorState, spans: string[]): DecorationSet {
  const ranges = spans
    .map((s) => spanToRange(state, s))
    .filter((r): r is { from: number; to: number } => r !== null)
    .sort((x, y) => x.from - y.from || x.to - y.to);
  const b = new RangeSetBuilder<Decoration>();
  // RangeSetBuilder takes non-overlapping ranges in order; two references
  // never overlap in the source, but a duplicate span would, so skip any
  // range starting before the previous one ended.
  let end = -1;
  for (const r of ranges) {
    if (r.from < end) continue;
    b.add(r.from, r.to, refMark);
    end = r.to;
  }
  return b.finish();
}

interface RefValue { spans: string[]; deco: DecorationSet }

const refField = StateField.define<RefValue>({
  create: () => ({ spans: [], deco: Decoration.none }),
  update(value, tr) {
    let spans: string[] | null = null;
    for (const e of tr.effects) if (e.is(setRefSpans)) spans = e.value;
    if (spans !== null) return { spans, deco: decorationsFor(tr.state, spans) };
    // An edit invalidates the spans: they describe the text as the last run
    // saw it. Recompute against the new document rather than mapping, so a
    // range that no longer fits drops out.
    if (tr.docChanged) return { spans: value.spans, deco: decorationsFor(tr.state, value.spans) };
    return value;
  },
  provide: (f) => EditorView.decorations.from(f, (v) => v.deco),
});

export const refMarkExtensions = [refField];

/** Mark every given span, or clear the marks with an empty list. */
export function setRefSpansOn(view: EditorView, spans: string[]) {
  view.dispatch({ effects: setRefSpans.of(spans) });
}
