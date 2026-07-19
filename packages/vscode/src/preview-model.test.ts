import { test, expect } from "bun:test";
import { stepAtLine, parseSpanLine, hiddenStepDataValues } from "./preview-model";

const edges = [
  { span: "t:3:1-3:20", step: "a" },
  { span: "t:5:1-5:12", step: "b" },
];

test("line inside step a maps to a", () => {
  expect(stepAtLine(edges, 3)).toBe("a");
});
test("line inside step b maps to b", () => {
  expect(stepAtLine(edges, 5)).toBe("b");
});
test("line before any step is null", () => {
  expect(stepAtLine(edges, 1)).toBeNull();
});
test("line after last step's start stays on the nearest preceding step", () => {
  expect(stepAtLine(edges, 6)).toBe("b");
});

const realEdges = [
  { span: "examples/foo.bel:3:1", step: "a" },
  { span: "examples/foo.bel:7:1", step: "b" },
];
test("real single-position span (beloch fold's actual format) maps correctly", () => {
  expect(stepAtLine(realEdges, 5)).toBe("a");
  expect(stepAtLine(realEdges, 7)).toBe("b");
});
test("parseSpanLine handles the single-position format", () => {
  expect(parseSpanLine("examples/foo.bel:32:1")).toEqual({ startLine: 32, endLine: 32 });
});

const orderedSteps = [null, "a", "b", "c"];
test("hiddenStepDataValues hides every step after the current one", () => {
  expect(hiddenStepDataValues(orderedSteps, "a")).toEqual(["b", "c"]);
});
test("hiddenStepDataValues at baseline hides all named steps", () => {
  expect(hiddenStepDataValues(orderedSteps, null)).toEqual(["a", "b", "c"]);
});
test("hiddenStepDataValues at the last step hides nothing", () => {
  expect(hiddenStepDataValues(orderedSteps, "c")).toEqual([]);
});
test("hiddenStepDataValues for an unknown step fails open (hides nothing)", () => {
  expect(hiddenStepDataValues(orderedSteps, "nope")).toEqual([]);
});
