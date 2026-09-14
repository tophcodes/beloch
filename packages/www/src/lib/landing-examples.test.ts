import { test, expect } from "bun:test";
import { evalBelToFold } from "./eval-bel";
import { HERO_SRC } from "./landing-examples";

// The landing page's hero is the only Beloch program this page ships, so a
// program that stops parsing fails in front of every visitor.
test("landing hero evaluates", () => {
  const fold = evalBelToFold(HERO_SRC) as { vertices_coords?: unknown[] };
  expect(Array.isArray(fold.vertices_coords)).toBe(true);
  expect(fold.vertices_coords!.length).toBeGreaterThan(0);
});
