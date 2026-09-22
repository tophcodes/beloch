import { test, expect } from "bun:test";
import { belTokens, belEntityName, type Capture } from "./bel-tokens";

const cap = (name: string, startIndex: number, endIndex: number): Capture => ({
  name,
  node: { startIndex, endIndex },
});

test("captures come back in source order whatever order they arrived in", () => {
  const out = belTokens([cap("point", 10, 12), cap("keyword", 0, 4), cap("punct", 5, 6)]);
  expect(out.map((t) => t.from)).toEqual([0, 5, 10]);
  expect(out.map((t) => t.name)).toEqual(["keyword", "punct", "point"]);
});

// The build-time and the browser highlighter render the same token list on two
// different runtimes. If one of them kept an overlapping capture the other
// dropped, a token would carry one colour in the docs card and another in the
// editor beside it.
test("an overlapping capture is dropped, the earlier one keeps the text", () => {
  const out = belTokens([cap("construction", 0, 20), cap("point", 5, 7)]);
  expect(out).toEqual([{ from: 0, to: 20, name: "construction" }]);
});

test("a capture that starts exactly where the last one ended is kept", () => {
  const out = belTokens([cap("punct", 0, 1), cap("line", 1, 6)]);
  expect(out.map((t) => t.name)).toEqual(["punct", "line"]);
});

test("no captures is no tokens", () => {
  expect(belTokens([])).toEqual([]);
});

test("a point and a crease carry the entity name the drawing knows them by", () => {
  expect(belEntityName("point", ".center")).toBe("center");
  expect(belEntityName("line", "--d1")).toBe("d1");
});

// `.[…]` and `--[…]` select by incidence rather than naming anything, so there
// is no entity for the drawing to highlight in step with the code.
test("a bracketed selection names nothing", () => {
  expect(belEntityName("point", ".[--bc --lowerh]")).toBeNull();
  expect(belEntityName("line", "--[.a .b]")).toBeNull();
});

test("a token that is not a point or a crease names nothing", () => {
  expect(belEntityName("keyword", "mark")).toBeNull();
  expect(belEntityName("number", "1/2")).toBeNull();
});
