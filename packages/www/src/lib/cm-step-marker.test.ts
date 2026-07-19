import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState } from "@codemirror/state";
import { EditorView, basicSetup } from "codemirror";
import { stepMarkerExtensions, setStepLineOn } from "./cm-step-marker";

beforeAll(() => { GlobalRegistrator.register(); });

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
