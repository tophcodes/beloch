// CM6 boxes over the spans that bind a value, for the Playground's debug mode.
//
// Pointing at the program to see what a statement built is a debugging move
// with its own audience, and it has no business happening while the reader is
// typing: the mode turns the editor read-only, so a click is a choice and never
// a caret. What each box stands for is the host's business (see
// `debugTargets` in `@beloch/runtime-editor`); this module draws them, reports
// the clicks, and holds the mode.
import { Decoration, EditorView, WidgetType } from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { EditorState, Prec, StateEffect, StateField } from "@codemirror/state";
import type { Extension } from "@codemirror/state";

// One box: a range of the document, the id the host knows it by, and whether
// what it binds is in the selection.
export interface DebugBox {
  from: number;
  to: number;
  id: number;
  on: boolean;
}

// The values the sheet brings, which no statement binds: the paper's corners
// and its edges. They have nowhere in the source to be boxed, so they stand
// under the line that declares the paper, written as the program would write
// them — the editor's own type, the editor's own colours, one row per kind.
export interface DebugChip {
  id: number;
  text: string;
  on: boolean;
  // The class the colouring gives this kind of name, so the row reads as code
  // rather than as a control of its own.
  cls?: string;
}

export interface DebugChips {
  line: number;
  rows: DebugChip[][];
  // A word on what this block is, written where a comment would stand.
  note?: string;
}

export const setDebugMode = StateEffect.define<boolean>();
export const setDebugBoxes = StateEffect.define<DebugBox[]>();
export const setDebugChips = StateEffect.define<DebugChips | null>();

const sameChips = (a: DebugChip[][], b: DebugChip[][]): boolean =>
  a.length === b.length &&
  a.every((row, i) => {
    const other = b[i]!;
    return (
      row.length === other.length &&
      row.every((c, j) => {
        const o = other[j]!;
        return c.id === o.id && c.text === o.text && c.on === o.on && c.cls === o.cls;
      })
    );
  });

class ChipsWidget extends WidgetType {
  constructor(readonly rows: DebugChip[][], readonly note: string | undefined) {
    super();
  }
  override eq(other: ChipsWidget) {
    return this.note === other.note && sameChips(this.rows, other.rows);
  }
  override toDOM() {
    const block = document.createElement("div");
    block.className = "cm-debug-chips";
    let first = true;
    for (const chips of this.rows) {
      if (chips.length === 0) continue;
      const row = document.createElement("div");
      row.className = "cm-debug-chip-row";
      for (const chip of chips) {
        const el = document.createElement("span");
        el.className =
          "cm-debug-box cm-debug-chip" + (chip.on ? " is-on" : "") +
          (chip.cls ? ` ${chip.cls}` : "");
        el.dataset.debug = String(chip.id);
        el.textContent = chip.text;
        row.appendChild(el);
      }
      if (first && this.note !== undefined) {
        const note = document.createElement("span");
        note.className = "cm-debug-note bel-comment";
        note.textContent = this.note;
        row.appendChild(note);
      }
      first = false;
      block.appendChild(row);
    }
    return block;
  }
  override ignoreEvent() {
    // The chips answer the pointer themselves, like the boxes.
    return false;
  }
}

interface DebugValue {
  on: boolean;
  boxes: DebugBox[];
  chips: DebugChips | null;
  deco: DecorationSet;
}

function decorationsFor(
  boxes: DebugBox[],
  chips: DebugChips | null,
  on: boolean,
  doc: EditorState["doc"],
): DecorationSet {
  if (!on) return Decoration.none;
  const ranges = boxes
    .filter((b) => b.from >= 0 && b.to > b.from && b.to <= doc.length)
    .map((b) =>
      Decoration.mark({
        class: "cm-debug-box" + (b.on ? " is-on" : ""),
        attributes: { "data-debug": String(b.id) },
      }).range(b.from, b.to),
    );
  const hasChips = chips !== null && chips.rows.some((row) => row.length > 0);
  if (chips && hasChips && chips.line >= 1 && chips.line <= doc.lines) {
    ranges.push(
      Decoration.widget({
        widget: new ChipsWidget(chips.rows, chips.note),
        block: true,
        side: 1,
      }).range(doc.line(chips.line).to),
    );
  }
  return Decoration.set(ranges, true);
}

const debugField = StateField.define<DebugValue>({
  create: () => ({ on: false, boxes: [], chips: null, deco: Decoration.none }),
  update(value, tr) {
    let { on, boxes, chips } = value;
    for (const e of tr.effects) {
      if (e.is(setDebugMode)) on = e.value;
      if (e.is(setDebugBoxes)) boxes = e.value;
      if (e.is(setDebugChips)) chips = e.value;
    }
    if (on === value.on && boxes === value.boxes && chips === value.chips && !tr.docChanged) {
      return value;
    }
    return { on, boxes, chips, deco: decorationsFor(boxes, chips, on, tr.state.doc) };
  },
  provide: (f) => [
    // Lowest precedence, which is what puts the box OUTSIDE the syntax
    // colouring rather than inside each token: of two marks over one range,
    // the one later in the decoration order wraps the other, and a box cut
    // into one span per token draws its border once per word.
    Prec.lowest(EditorView.decorations.from(f, (v) => v.deco)),
    // The mode is what makes the editor read-only, so leaving it gives the
    // text back without the host having to remember it did that.
    EditorState.readOnly.from(f, (v) => v.on),
  ],
});

/** Whether debug mode is on. */
export const debugIsOn = (state: EditorState): boolean => state.field(debugField).on;

// A box in the program or a chip under the paper line: both carry the id the
// host knows the value by, and a click on either is the same move.
const targetId = (target: EventTarget | null): number | null => {
  const el =
    target instanceof Element
      ? target.closest<HTMLElement>(".cm-debug-box, .cm-debug-chip")
      : null;
  const id = el?.dataset.debug;
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
        const id = targetId(event.target);
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

/** Show the chips under `line`, or clear them with null. */
export function setDebugChipsOn(view: EditorView, chips: DebugChips | null) {
  view.dispatch({ effects: setDebugChips.of(chips) });
}
