import { test, expect } from "bun:test";
import { heroSequence } from "./hero-steps";

const SRC = `paper square

; a comment stands on no step
fold (map .a onto .c) as --bd
--m = (through .b .d)
reverse (map .b onto .c)
  as --h
`;

test("one step per write, a read on the step of the write after it", () => {
  const { steps } = heroSequence(SRC);
  expect(steps.map((s) => s.lines)).toEqual([
    ["fold (map .a onto .c) as --bd"],
    ["--m = (through .b .d)", "reverse (map .b onto .c) as --h"],
  ]);
});

test("a step dims the creases scored before it and none of its own", () => {
  const { steps, final } = heroSequence(SRC);
  expect(steps[0]!.figure).not.toContain('opacity="0.3"');
  expect(steps[1]!.figure).toContain('opacity="0.3"');
  expect(final).not.toContain('opacity="0.3"');
});
