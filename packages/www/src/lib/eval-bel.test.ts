import { test, expect } from "bun:test";
import { evalBelToFold } from "./eval-bel";

test("evaluates a simple program to a FOLD object", () => {
  const fold = evalBelToFold("paper square\nmark --d1 = through .a .c\n") as {
    vertices_coords?: unknown;
  };
  expect(typeof fold).toBe("object");
  expect(Array.isArray(fold.vertices_coords)).toBe(true);
});

test("throws with a diagnostic on a broken program", () => {
  // `through .a .a` — no line through a single point (a known anti-example).
  expect(() => evalBelToFold("paper square\nmark through .a .a\n")).toThrow();
});
