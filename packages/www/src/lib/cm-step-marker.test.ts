import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState } from "@codemirror/state";
import { EditorView, basicSetup } from "codemirror";
import { stepMarkerExtensions, setStepLineOn } from "./cm-step-marker";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

function mountEditor(doc: string): EditorView {
  const state = EditorState.create({ doc, extensions: stepMarkerExtensions });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  return new EditorView({ state, parent });
}

test("setStepLineOn adds a gutter dot marker on the target line", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 2);
  const dot = view.dom.querySelector(".cm-step-gutter .cm-step-dot");
  expect(dot).not.toBeNull();
});

test("setStepLineOn(null) clears the marker", () => {
  const view = mountEditor("paper square\nfold X\n");
  setStepLineOn(view, 2);
  setStepLineOn(view, null);
  expect(view.dom.querySelector(".cm-step-gutter .cm-step-dot")).toBeNull();
});

test("setStepLineOn adds a line-background decoration on the target line", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 3);
  expect(view.dom.querySelector(".cm-step-line")).not.toBeNull();
});

test("moving to a different line clears the previous marker", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 2);
  setStepLineOn(view, 3);
  const dots = view.dom.querySelectorAll(".cm-step-gutter .cm-step-dot");
  expect(dots.length).toBe(1);
  const lines = view.dom.querySelectorAll(".cm-step-line");
  expect(lines.length).toBe(1);
});

test("gutter is registered before (left of) the default line-number gutter", () => {
  const state = EditorState.create({
    doc: "a\nb\nc\n",
    extensions: [...stepMarkerExtensions, basicSetup],
  });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  const view = new EditorView({ state, parent });
  const classes = Array.from(view.dom.querySelectorAll(".cm-gutters > *")).map((el) => el.className);
  const stepIdx = classes.findIndex((c) => c.includes("cm-step-gutter"));
  const lineNumIdx = classes.findIndex((c) => c.includes("cm-lineNumbers"));
  expect(stepIdx).toBeGreaterThanOrEqual(0);
  expect(lineNumIdx).toBeGreaterThan(stepIdx);
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
