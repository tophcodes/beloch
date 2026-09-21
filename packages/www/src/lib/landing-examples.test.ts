import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { test, expect } from "bun:test";
import { evalBelToFold } from "./eval-bel";
import { HERO_SRC } from "./landing-examples";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = process.env.BELOCH_REPO_ROOT ?? join(here, "..", "..", "..", "..");

// The landing page's hero is the only Beloch program this page ships, so a
// program that stops parsing fails in front of every visitor.
test("landing hero evaluates", () => {
  const fold = evalBelToFold(HERO_SRC) as { vertices_coords?: unknown[] };
  expect(Array.isArray(fold.vertices_coords)).toBe(true);
  expect(fold.vertices_coords!.length).toBeGreaterThan(0);
});

// Provenance fields carry the source file's path and line numbers, which
// differ between landing-hero.bel and bird-base.bel even when every
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

// landing-hero.bel is a display copy of examples/bases/bird-base.bel with the
// source-attribution header and the `; assert` fixture lines cut, so the hero
// shows Beloch code from the first line instead of a comment block. Comparing
// evaluated FOLD output (not source text) is what lets the two files differ
// in comments while still guaranteeing the display copy's statements stay
// identical in effect to the corpus's.
test("landing hero matches the bird-base corpus semantically", () => {
  const corpusSrc = readFileSync(
    join(repoRoot, "examples", "bases", "bird-base.bel"),
    "utf-8",
  );
  expect(stripProvenance(evalBelToFold(HERO_SRC))).toEqual(
    stripProvenance(evalBelToFold(corpusSrc)),
  );
});
