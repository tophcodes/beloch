import { test, expect } from "bun:test";
import { evalBelToFold } from "./eval-bel";
import { EXAMPLES } from "./landing-examples";

// The playground loads these into its editor on click, so a program that stops
// parsing fails in front of a visitor and nowhere else.
for (const { label, code } of EXAMPLES) {
  test(`landing example "${label}" evaluates`, () => {
    const fold = evalBelToFold(code) as { vertices_coords?: unknown[] };
    expect(Array.isArray(fold.vertices_coords)).toBe(true);
    expect(fold.vertices_coords!.length).toBeGreaterThan(0);
  });
}
