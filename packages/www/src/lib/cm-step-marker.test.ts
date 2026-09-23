import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState } from "@codemirror/state";
import { EditorView } from "codemirror";
import { stepMarkerExtensions, setStepLineOn } from "./cm-step-marker";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

function mountEditor(doc: string): EditorView {
  const state = EditorState.create({ doc, extensions: stepMarkerExtensions() });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  return new EditorView({ state, parent });
}

test("setStepLineOn adds a line-background decoration on the target line", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 3);
  expect(view.dom.querySelector(".cm-step-line")).not.toBeNull();
});

test("a step marks every line it stands for", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\n--mid = (through .a .c)\nfold Y\n");
  // The first fold stands for its own line and the two declarations under it.
  setStepLineOn(view, 2, { through: 4 });
  expect(view.dom.querySelectorAll(".cm-step-line").length).toBe(3);
});

test("the source above the first statement is a block of its own", () => {
  const view = mountEditor("paper square\n--diag = (through .a .c)\nfold X\n");
  setStepLineOn(view, 1, { through: 2 });
  expect(view.dom.querySelectorAll(".cm-step-line").length).toBe(2);
});

test("a block that ends above where it starts stands for nothing", () => {
  // A program whose first statement is also its first line: step 0 owns no
  // source at all.
  const view = mountEditor("fold X\nfold Y\n");
  setStepLineOn(view, 1, { through: 0 });
  expect(view.dom.querySelector(".cm-step-line")).toBeNull();
});

test("a block reaching past the end of the document stops at the last line", () => {
  // No trailing newline, so the document is exactly three lines.
  const view = mountEditor("paper square\nfold X\n.m = free");
  setStepLineOn(view, 2, { through: 99 });
  expect(view.dom.querySelectorAll(".cm-step-line").length).toBe(2);
});

test("moving to a different line clears the previous marker", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 2);
  setStepLineOn(view, 3);
  expect(view.dom.querySelectorAll(".cm-step-line").length).toBe(1);
});

// Marking a line and revealing it are different jobs: stepping through a
// program wants the line brought into view, clicking a crease in the
// drawing wants the editor left where the reader put it. Asserted on the
// dispatches rather than on scrollTop, because CodeMirror only renders the
// visible viewport and a headless editor has no layout to scroll.
function countDispatches(view: EditorView, run: () => void): number {
  const real = view.dispatch.bind(view);
  let n = 0;
  (view as unknown as { dispatch: typeof real }).dispatch = (...args: Parameters<typeof real>) => {
    n++;
    return real(...args);
  };
  run();
  (view as unknown as { dispatch: typeof real }).dispatch = real;
  return n;
}

test("reveal:false marks the line and dispatches no scroll", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  expect(countDispatches(view, () => setStepLineOn(view, 3, { reveal: false }))).toBe(1);
  expect(view.dom.querySelector(".cm-step-line")).not.toBeNull();
});

test("the default still reveals the line, as stepping needs", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  expect(countDispatches(view, () => setStepLineOn(view, 3))).toBe(2);
});

test("clearing dispatches once either way", () => {
  const view = mountEditor("paper square\nfold X\n");
  expect(countDispatches(view, () => setStepLineOn(view, null))).toBe(1);
});
