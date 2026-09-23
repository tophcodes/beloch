import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState } from "@codemirror/state";
import { EditorView, basicSetup } from "codemirror";
import { stepMarkerExtensions, setStepLineOn, setStepSlotsOn, slotAtLine } from "./cm-step-marker";

beforeAll(() => { if (!GlobalRegistrator.isRegistered) GlobalRegistrator.register(); });

function mountEditor(doc: string, onPickStep?: (step: number) => void): EditorView {
  const state = EditorState.create({
    doc,
    extensions: onPickStep ? stepMarkerExtensions({ onPickStep }) : stepMarkerExtensions(),
  });
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

test("a step marks every line it stands for, with one dot on its first", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\n--mid = (through .a .c)\nfold Y\n");
  // The first fold stands for its own line and the two declarations under it.
  setStepLineOn(view, 2, { through: 4 });
  expect(view.dom.querySelectorAll(".cm-step-line").length).toBe(3);
  expect(view.dom.querySelectorAll(".cm-step-gutter .cm-step-dot").length).toBe(1);
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
  expect(view.dom.querySelector(".cm-step-gutter .cm-step-dot")).toBeNull();
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
  const dots = view.dom.querySelectorAll(".cm-step-gutter .cm-step-dot");
  expect(dots.length).toBe(1);
  const lines = view.dom.querySelectorAll(".cm-step-line");
  expect(lines.length).toBe(1);
});

test("gutter is registered before (left of) the default line-number gutter", () => {
  const state = EditorState.create({
    doc: "a\nb\nc\n",
    extensions: [...stepMarkerExtensions(), basicSetup],
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

// The gutter carries one bar per step, over the source that step stands for,
// so the column says how the program divides into steps.
const threeSteps = [
  { step: 0, fromLine: 1, toLine: 1 },
  { step: 1, fromLine: 2, toLine: 3 },
  { step: 2, fromLine: 4, toLine: 4 },
];

test("a step's bar covers every line of its block", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepSlotsOn(view, threeSteps);
  expect(view.dom.querySelectorAll(".cm-step-gutter .cm-step-bar").length).toBe(4);
  // One head and one tail per block, so three blocks end up with three of each.
  expect(view.dom.querySelectorAll(".cm-step-bar.is-head").length).toBe(3);
  expect(view.dom.querySelectorAll(".cm-step-bar.is-tail").length).toBe(3);
});

test("the step on screen is the one drawn solid", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepSlotsOn(view, threeSteps);
  setStepLineOn(view, 2, { through: 3 });
  // Both lines of the marked block, and nothing from the others.
  expect(view.dom.querySelectorAll(".cm-step-bar.is-current").length).toBe(2);
});

test("a bar answers for every line its block covers", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepSlotsOn(view, threeSteps);
  expect(slotAtLine(view.state, 3)?.step).toBe(1);
  expect(slotAtLine(view.state, 4)?.step).toBe(2);
  expect(slotAtLine(view.state, 9)).toBeUndefined();
});

test("clearing the bars leaves only the marked line's dot", () => {
  const view = mountEditor("paper square\nfold X\n");
  setStepSlotsOn(view, [{ step: 0, fromLine: 1, toLine: 1 }]);
  setStepLineOn(view, 2, { through: 2 });
  setStepSlotsOn(view, []);
  expect(view.dom.querySelector(".cm-step-gutter .cm-step-bar")).toBeNull();
  expect(view.dom.querySelectorAll(".cm-step-gutter .cm-step-dot").length).toBe(1);
});

test("a mousedown on a bar jumps to its step", () => {
  const picked: number[] = [];
  const view = mountEditor("paper square\nfold X\n", (step) => picked.push(step));
  setStepSlotsOn(view, [{ step: 0, fromLine: 1, toLine: 1 }]);
  const cell = view.dom.querySelector(".cm-step-gutter .cm-gutterElement");
  cell?.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
  expect(picked).toEqual([0]);
});

test("pointing at a bar reports its step, and leaving reports none", () => {
  const hovered: (number | null)[] = [];
  const state = EditorState.create({
    doc: "paper square\nfold X\n",
    extensions: stepMarkerExtensions({ onHoverStep: (step) => hovered.push(step) }),
  });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  const view = new EditorView({ state, parent });
  setStepSlotsOn(view, [{ step: 0, fromLine: 1, toLine: 1 }]);
  const gutterDom = view.dom.querySelector(".cm-step-gutter")!;
  gutterDom.querySelector(".cm-gutterElement")
    ?.dispatchEvent(new MouseEvent("mousemove", { bubbles: true }));
  gutterDom.dispatchEvent(new MouseEvent("mouseleave", { bubbles: false }));
  expect(hovered).toEqual([0, null]);
});
