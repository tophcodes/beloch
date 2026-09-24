import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState, RangeSetBuilder } from "@codemirror/state";
import { Decoration, ViewPlugin } from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { insertNewlineAndIndent } from "@codemirror/commands";
import { EditorView } from "codemirror";
import {
  debugExtensions,
  debugIsOn,
  setDebugBoxesOn,
  setDebugModeOn,
  type DebugBox,
} from "./cm-debug-boxes";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

const DOC = "paper square\n--vert = (map .a onto .b)\n.mid = --ac * --bd\n";

function mountEditor(onPick?: (id: number) => void): EditorView {
  const state = EditorState.create({
    doc: DOC,
    extensions: onPick ? debugExtensions({ onPick }) : debugExtensions(),
  });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  return new EditorView({ state, parent });
}

// `--vert` on line 2 and `.mid` on line 3, as the host computes them from the
// spans the document carries.
const boxes: DebugBox[] = [
  { from: 13, to: 19, id: 0, on: false },
  { from: 39, to: 43, id: 1, on: false },
];

test("no box is drawn until the mode is on", () => {
  const view = mountEditor();
  setDebugBoxesOn(view, boxes);
  expect(view.dom.querySelector(".cm-debug-box")).toBeNull();
  setDebugModeOn(view, true);
  expect(view.dom.querySelectorAll(".cm-debug-box").length).toBe(2);
});

test("a box says what it stands for and whether it is selected", () => {
  const view = mountEditor();
  setDebugModeOn(view, true);
  setDebugBoxesOn(view, [boxes[0]!, { ...boxes[1]!, on: true }]);
  const drawn = Array.from(view.dom.querySelectorAll(".cm-debug-box"));
  expect(drawn.map((b) => b.getAttribute("data-debug"))).toEqual(["0", "1"]);
  expect(drawn.map((b) => b.classList.contains("is-on"))).toEqual([false, true]);
});

test("clicking a box reports it", () => {
  const picked: number[] = [];
  const view = mountEditor((id) => picked.push(id));
  setDebugModeOn(view, true);
  setDebugBoxesOn(view, boxes);
  const box = view.dom.querySelectorAll(".cm-debug-box")[1]!;
  box.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
  expect(picked).toEqual([1]);
});

test("the editor refuses an edit while the mode is on", () => {
  const view = mountEditor();
  setDebugModeOn(view, true);
  // A command is how a keystroke reaches the document, and every one of them
  // declines on a read-only state.
  expect(insertNewlineAndIndent(view)).toBe(false);
  expect(view.state.doc.toString()).toBe(DOC);
  setDebugModeOn(view, false);
  expect(debugIsOn(view.state)).toBe(false);
  expect(insertNewlineAndIndent(view)).toBe(true);
});

test("leaving the mode takes the boxes away and keeps them for the next time", () => {
  const view = mountEditor();
  setDebugModeOn(view, true);
  setDebugBoxesOn(view, boxes);
  setDebugModeOn(view, false);
  expect(view.dom.querySelector(".cm-debug-box")).toBeNull();
  setDebugModeOn(view, true);
  expect(view.dom.querySelectorAll(".cm-debug-box").length).toBe(2);
});

// The colouring is a view plugin that marks every token, and of two marks over
// one range the later one wraps the other. A box that lost that race is cut
// into one span per token and draws its border once per word, which is what
// the reader sees. Asserted on the DOM, since nothing else shows it.
const tokens = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;
    constructor() { this.decorations = this.build(); }
    update() { this.decorations = this.build(); }
    build() {
      const b = new RangeSetBuilder<Decoration>();
      b.add(0, 5, Decoration.mark({ class: "tok-a" }));
      b.add(6, 13, Decoration.mark({ class: "tok-b" }));
      return b.finish();
    }
  },
  { decorations: (v) => v.decorations },
);

test("a box wraps the colouring rather than each token", () => {
  const state = EditorState.create({
    doc: "paper square\n",
    extensions: [...debugExtensions(), tokens],
  });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  const view = new EditorView({ state, parent });
  setDebugModeOn(view, true);
  setDebugBoxesOn(view, [{ from: 0, to: 12, id: 0, on: false }]);
  expect(view.dom.querySelectorAll(".cm-debug-box").length).toBe(1);
  expect(view.dom.querySelector(".cm-debug-box")!.querySelectorAll(".tok-a, .tok-b").length).toBe(2);
});
