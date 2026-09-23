// CM6 boxes over the spans that bind a value, for the Playground's debug mode.
//
// Pointing at the program to see what a statement built is a debugging move
// with its own audience, and it has no business happening while the reader is
// typing: the mode turns the editor read-only, so a click is a choice and never
// a caret. What each box stands for is the host's business (see
// `debugTargets` in `@beloch/runtime-editor`); this module draws them, reports
// the clicks, and holds the mode.
import { Decoration, EditorView } from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { EditorState, StateEffect, StateField } from "@codemirror/state";
import type { Extension } from "@codemirror/state";

// One box: a range of the document, the id the host knows it by, and whether
// what it binds is in the selection.
export interface DebugBox {
  from: number;
  to: number;
  id: number;
  on: boolean;
}

export const setDebugMode = StateEffect.define<boolean>();
export const setDebugBoxes = StateEffect.define<DebugBox[]>();

interface DebugValue { on: boolean; boxes: DebugBox[]; deco: DecorationSet }

function decorationsFor(boxes: DebugBox[], on: boolean, length: number): DecorationSet {
  if (!on) return Decoration.none;
  const ranges = boxes
    .filter((b) => b.from >= 0 && b.to > b.from && b.to <= length)
    .map((b) =>
      Decoration.mark({
        class: "cm-debug-box" + (b.on ? " is-on" : ""),
        attributes: { "data-debug": String(b.id) },
      }).range(b.from, b.to),
    );
  return Decoration.set(ranges, true);
}

const debugField = StateField.define<DebugValue>({
  create: () => ({ on: false, boxes: [], deco: Decoration.none }),
  update(value, tr) {
    let { on, boxes } = value;
    for (const e of tr.effects) {
      if (e.is(setDebugMode)) on = e.value;
      if (e.is(setDebugBoxes)) boxes = e.value;
    }
    if (on === value.on && boxes === value.boxes && !tr.docChanged) return value;
    return { on, boxes, deco: decorationsFor(boxes, on, tr.state.doc.length) };
  },
  provide: (f) => [
    EditorView.decorations.from(f, (v) => v.deco),
    // The mode is what makes the editor read-only, so leaving it gives the
    // text back without the host having to remember it did that.
    EditorState.readOnly.from(f, (v) => v.on),
  ],
});

/** Whether debug mode is on. */
export const debugIsOn = (state: EditorState): boolean => state.field(debugField).on;

const boxId = (target: EventTarget | null): number | null => {
  const box = target instanceof Element ? target.closest<HTMLElement>(".cm-debug-box") : null;
  const id = box?.dataset.debug;
  return id === undefined ? null : Number(id);
};

/** The debug-mode extensions. `onPick` is called with the id of the box the
 * reader clicked; without it the boxes are shown and inert. */
export function debugExtensions(opts: { onPick?: (id: number) => void } = {}): Extension[] {
  const onPick = opts.onPick;
  return [
    debugField,
    EditorView.domEventHandlers({
      mousedown(event, view) {
        if (onPick === undefined || !debugIsOn(view.state)) return false;
        const id = boxId(event.target);
        if (id === null) return false;
        onPick(id);
        return true;
      },
    }),
  ];
}

/** Turn the mode on or off. The boxes stay where they are, so turning it back
 * on shows them again without the host recomputing anything. */
export function setDebugModeOn(view: EditorView, on: boolean) {
  if (debugIsOn(view.state) === on) return;
  view.dispatch({ effects: setDebugMode.of(on) });
}

/** Show these boxes, replacing the ones before them. */
export function setDebugBoxesOn(view: EditorView, boxes: DebugBox[]) {
  view.dispatch({ effects: setDebugBoxes.of(boxes) });
}
