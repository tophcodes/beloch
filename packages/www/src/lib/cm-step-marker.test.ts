import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState } from "@codemirror/state";
import { EditorView } from "codemirror";
import {
  stepMarkerExtensions,
  setStepLineOn,
  setStepBlocksOn,
  setHoveredStepOn,
  stepOfLine,
} from "./cm-step-marker";

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

// Marking a block never moves the program: where the reader put it is theirs.
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

test("marking a block dispatches once and scrolls nothing", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  expect(countDispatches(view, () => setStepLineOn(view, 3))).toBe(1);
  expect(view.dom.querySelector(".cm-step-line")).not.toBeNull();
});

test("clearing dispatches once either way", () => {
  const view = mountEditor("paper square\nfold X\n");
  expect(countDispatches(view, () => setStepLineOn(view, null))).toBe(1);
});

// Every step the program has, marked in the lane the line padding keeps free
// at its left edge: the column says how the program divides into steps, and a
// bar is the target that jumps to one.
const threeBlocks = [
  { step: 0, fromLine: 1, toLine: 1 },
  { step: 1, fromLine: 2, toLine: 3 },
  { step: 2, fromLine: 4, toLine: 4 },
];

test("every block a program has carries a bar", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepBlocksOn(view, threeBlocks);
  expect(view.dom.querySelectorAll(".cm-step-bar").length).toBe(4);
});

test("the block on screen is the one drawn solid", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepBlocksOn(view, threeBlocks);
  setStepLineOn(view, 2, { through: 3 });
  const current = view.dom.querySelectorAll(".cm-step-bar.is-current");
  expect(current.length).toBe(2);
});

test("a bar says which step it stands for", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepBlocksOn(view, threeBlocks);
  const steps = Array.from(view.dom.querySelectorAll(".cm-step-bar")).map((b) =>
    b.getAttribute("data-step"),
  );
  expect(steps).toEqual(["0", "1", "1", "2"]);
});

test("clicking a bar jumps to its step", () => {
  const picked: number[] = [];
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n", (step) => picked.push(step));
  setStepBlocksOn(view, threeBlocks);
  const bar = view.dom.querySelectorAll(".cm-step-bar")[2]!;
  bar.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
  expect(picked).toEqual([1]);
});

test("clearing the blocks takes the bars with it", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepBlocksOn(view, threeBlocks);
  setStepBlocksOn(view, []);
  expect(view.dom.querySelector(".cm-step-bar")).toBeNull();
});

test("the ends of a block are marked, so two blocks read as two", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepBlocksOn(view, threeBlocks);
  const bars = Array.from(view.dom.querySelectorAll(".cm-step-bar"));
  // A block of one line is both its own head and its own tail.
  expect(bars.map((b) => b.classList.contains("is-head"))).toEqual([true, true, false, true]);
  expect(bars.map((b) => b.classList.contains("is-tail"))).toEqual([true, false, true, true]);
});

test("pointing at a block lights the whole block's bar", () => {
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n");
  setStepBlocksOn(view, threeBlocks);
  setHoveredStepOn(view, 1);
  const hovered = Array.from(view.dom.querySelectorAll(".cm-step-bar.is-hover"));
  expect(hovered.map((b) => b.getAttribute("data-step"))).toEqual(["1", "1"]);
  setHoveredStepOn(view, null);
  expect(view.dom.querySelector(".cm-step-bar.is-hover")).toBeNull();
});

test("clicking a line number jumps to the step its block stands for", () => {
  const picked: number[] = [];
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n", (step) => picked.push(step));
  setStepBlocksOn(view, threeBlocks);
  // The third line belongs to the block of step 1, which is what its number
  // answers for: pointing there already lights that bar.
  expect(stepOfLine(view.state, 3)).toBe(1);
  expect(stepOfLine(view.state, 4)).toBe(2);
  expect(stepOfLine(view.state, 99)).toBeNull();
});

test("a mousedown on a line number is answered", () => {
  const picked: number[] = [];
  const view = mountEditor("paper square\nfold X\n.m = free\nfold Y\n", (step) => picked.push(step));
  setStepBlocksOn(view, threeBlocks);
  const numbers = view.dom.querySelectorAll(".cm-lineNumbers .cm-gutterElement");
  expect(numbers.length).toBeGreaterThan(0);
  numbers[numbers.length - 1]!.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
  // Which line was clicked comes from the pointer's height against the line
  // boxes, and a headless editor has no layout, so the step it lands on is not
  // the assertion here; `stepOfLine` above is. What this holds is that the
  // number column reaches the handler at all, which the content element's own
  // handlers never do.
  expect(picked).toHaveLength(1);
});
