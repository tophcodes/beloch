import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { test, expect } from "bun:test";
import { evalBelToFold } from "./eval-bel";
import { HERO_SRC, PLAYGROUND_SRC } from "./landing-examples";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = process.env.BELOCH_REPO_ROOT ?? join(here, "..", "..", "..", "..");

// These two programs are what a first-time visitor sees, so one that stops
// parsing fails in front of every one of them.
test.each([
  ["landing hero", HERO_SRC],
  ["playground start", PLAYGROUND_SRC],
])("%s evaluates", (_name, src) => {
  const fold = evalBelToFold(src) as { vertices_coords?: unknown[] };
  expect(Array.isArray(fold.vertices_coords)).toBe(true);
  expect(fold.vertices_coords!.length).toBeGreaterThan(0);
});

// Constraint 1 of the viewer brief: at 1280 by 800 the source and the drawing
// are both there in full, with no click and no scrolling, and constraint 2
// keeps the drawing at least as wide as the editor. Section 8.5 extends the
// first to the hero. Both therefore cap how long a line of the starting
// program may be: past the cap it runs out of its column, and the visitor's
// first sight of the language is a sentence cut in half. The two numbers are
// the character counts the two editor columns hold at that width, at the
// monospace size --bel-code-size fixes.
test.each([
  ["landing hero", HERO_SRC, 48],
  ["playground start", PLAYGROUND_SRC, 50],
])("%s fits its editor column", (_name, src, cap) => {
  const longest = Math.max(...src.split("\n").map((l) => l.length));
  expect(longest).toBeLessThanOrEqual(cap);
});

// Provenance fields carry the source file's path and line numbers, which
// differ between a display copy and its corpus file even when every
// statement means the same thing, since the header comment and the asserts
// shift line numbers and each source is written to its own temp file before
// evaluation. Stripped recursively so the comparison below is over geometry
// and structure only.
function stripProvenance(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(stripProvenance);
  }
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .filter(([key]) => key !== "span" && key !== "source_line" && key !== "beloch:source_line")
        .map(([key, v]) => [key, stripProvenance(v)]),
    );
  }
  return value;
}

// Each display copy is its corpus file with the source-attribution header and
// the `; assert` fixture lines cut, so a card shows Beloch code from its first
// line instead of a comment block. Comparing evaluated FOLD output (not source
// text) is what lets the two files differ in comments while still guaranteeing
// the display copy's statements stay identical in effect to the corpus's.
test.each([
  ["landing hero", HERO_SRC, "fish-base.bel"],
  ["playground start", PLAYGROUND_SRC, "bird-base.bel"],
])("%s matches its corpus file semantically", (_name, src, corpus) => {
  const corpusSrc = readFileSync(join(repoRoot, "examples", "bases", corpus), "utf-8");
  expect(stripProvenance(evalBelToFold(src))).toEqual(
    stripProvenance(evalBelToFold(corpusSrc)),
  );
});
