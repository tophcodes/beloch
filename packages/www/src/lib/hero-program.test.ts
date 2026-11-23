import { test, expect } from "bun:test";
import { heroProgram, nameTips } from "./hero-program";

const SRC = `@author "test"
paper square

fold (map .a onto .c) as --bd
mark (through .b .c) as --m
.o = --bd * --m
fold (map .c onto .o)
  as --h
`;

test("one fold per folding statement, a mark none, with every line it spans", async () => {
  const { folds, lines } = await heroProgram(SRC);
  expect(folds.map((f) => [f.from, f.to])).toEqual([[4, 4], [7, 8]]);
  expect(lines.length).toBe(SRC.split("\n").length);
});

test("a fold dims the creases scored before it and none of its own", async () => {
  const { folds } = await heroProgram(SRC);
  expect(folds[0]!.cp).not.toContain('opacity="0.3"');
  expect(folds[1]!.cp).toContain('opacity="0.3"');
});

test("a tip names where a name comes from and the line that made it", () => {
  const tips = nameTips(SRC);
  expect(tips[".a"]).toBe(".a  ·  corner of the sheet");
  expect(tips["--da"]).toBe("--da  ·  edge of the sheet");
  expect(tips["--bd"]).toBe("--bd  ·  crease, line 4  ·  fold (map .a onto .c) as --bd");
  expect(tips["--m"]).toBe("--m  ·  marked line, line 5  ·  mark (through .b .c) as --m");
  expect(tips[".o"]).toBe(".o  ·  point, line 6  ·  --bd * --m");
  expect(tips["--h"]).toBe("--h  ·  crease, line 7  ·  fold (map .c onto .o) as --h");
});
