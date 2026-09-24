import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState } from "@codemirror/state";
import { EditorView } from "codemirror";
import { stepMarkerExtensions, setStepLineOn, setErrorOn } from "./cm-step-marker";

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

test("a step marks its own line and nothing under it", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\n--mid = (through .a .c)\nfold Y\n");
  setStepLineOn(view, 2);
  expect(view.dom.querySelectorAll(".cm-step-line").length).toBe(1);
});

test("a line outside the document marks nothing", () => {
  const view = mountEditor("paper square\nfold X\n");
  setStepLineOn(view, 99);
  expect(view.dom.querySelector(".cm-step-line")).toBeNull();
});

test("moving to a different line clears the previous marker", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 2);
  setStepLineOn(view, 3);
  expect(view.dom.querySelectorAll(".cm-step-line").length).toBe(1);
});

test("the step line and the error line stand at once", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 2);
  setErrorOn(view, { line: 3, span: null, message: "boom", hint: null });
  expect(view.dom.querySelector(".cm-step-line")).not.toBeNull();
  expect(view.dom.querySelector(".cm-error-line")).not.toBeNull();
});

// Marking the line never moves the program: where the reader put it is theirs.
// Asserted on the dispatches rather than on scrollTop, because CodeMirror only
// renders the visible viewport and a headless editor has no layout to scroll.
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

test("marking a line dispatches once and scrolls nothing", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  expect(countDispatches(view, () => setStepLineOn(view, 3))).toBe(1);
  expect(view.dom.querySelector(".cm-step-line")).not.toBeNull();
});

test("clearing dispatches once either way", () => {
  const view = mountEditor("paper square\nfold X\n");
  expect(countDispatches(view, () => setStepLineOn(view, null))).toBe(1);
});

// A failed run, shown in the code: the offending word underlined, a caret row
// with the message and a hint row under its line, and the rest dimmed.
const failed = {
  line: 2,
  span: { fromLine: 2, fromCol: 6, toLine: 2, toCol: 10 },
  message: "unknown line --dx",
  hint: "in scope: --ab --bc",
};

test("the span a failed run names is underlined, and only it", () => {
  const view = mountEditor("paper square\nfold --dx\nfold Y\n");
  setErrorOn(view, failed);
  const words = view.dom.querySelectorAll(".cm-error-word");
  expect(words.length).toBe(1);
  expect(words[0]!.textContent).toBe("--dx");
});

test("the caret row stands under the word with the message, the hint under it", () => {
  const view = mountEditor("paper square\nfold --dx\nfold Y\n");
  setErrorOn(view, failed);
  const caret = view.dom.querySelector(".cm-error-caret")!;
  expect(caret.textContent).toBe("     ^~~~ unknown line --dx");
  expect(view.dom.querySelector(".cm-error-hint")!.textContent).toBe("     in scope: --ab --bc");
});

test("no hint, no hint row", () => {
  const view = mountEditor("paper square\nfold --dx\n");
  setErrorOn(view, { ...failed, hint: null });
  expect(view.dom.querySelector(".cm-error-caret")).not.toBeNull();
  expect(view.dom.querySelector(".cm-error-hint")).toBeNull();
});

test("the lines after the failed one are dimmed, the ones before are not", () => {
  const view = mountEditor("paper square\nfold --dx\nfold Y\nfold Z\n");
  setErrorOn(view, failed);
  expect(view.dom.querySelectorAll(".cm-after-error").length).toBe(3);
  expect(view.dom.querySelector(".cm-line.cm-after-error")?.textContent).toBe("fold Y");
});

test("an error without a span marks its line and writes the message under it", () => {
  const view = mountEditor("paper square\nfold X\n");
  setErrorOn(view, { line: 2, span: null, message: "boom", hint: null });
  expect(view.dom.querySelector(".cm-error-line")).not.toBeNull();
  expect(view.dom.querySelector(".cm-error-word")).toBeNull();
  expect(view.dom.querySelector(".cm-error-caret")!.textContent).toBe("boom");
});

test("clearing takes every mark away", () => {
  const view = mountEditor("paper square\nfold --dx\nfold Y\n");
  setErrorOn(view, failed);
  setErrorOn(view, null);
  for (const cls of ["cm-error-line", "cm-error-word", "cm-error-caret", "cm-after-error"]) {
    expect(view.dom.querySelector(`.${cls}`)).toBeNull();
  }
});

test("an edit above the error carries the marks along", () => {
  const view = mountEditor("paper square\nfold --dx\n");
  setErrorOn(view, { ...failed, hint: null });
  view.dispatch({ changes: { from: 0, insert: "; note\n" } });
  expect(view.dom.querySelector(".cm-error-word")!.textContent).toBe("--dx");
  expect(view.dom.querySelector(".cm-line.cm-error-line")!.textContent).toBe("fold --dx");
});
