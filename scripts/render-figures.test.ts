// The figure pipeline's reading of a `.figure` block: which entities a
// `highlight` may name, and what happens when it names one the program never
// defines. Needs the `beloch` binary, so it runs inside the flake devshell:
//   nix develop -c bun test scripts
import { test, expect } from "bun:test";
import { mkdtempSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { renderFigure, scanFigures, highlightNames } from "./render-figures.ts";

const outDir = mkdtempSync(join(tmpdir(), "beloch-figures-"));

const SQUARE = "paper square\nmark (through .a .c) as --ac";

test("a highlight the program defines renders both views", () => {
  const entry = renderFigure(
    { id: "fig-ok", views: ["cp"], highlight: ["--ac", ".a"], program: SQUARE },
    outDir,
    "spec/TEST.md",
  );
  expect(entry.error).toBeNull();
  expect(entry.files.cp).toBe("fig-ok-cp.svg");
  expect(readdirSync(outDir)).toContain("fig-ok-cp.svg");
});

test("a highlight naming an entity the program does not define is an error", () => {
  const entry = renderFigure(
    { id: "fig-bad", views: ["cp"], highlight: ["--ac", "--nope"], program: SQUARE },
    outDir,
    "spec/TEST.md",
  );
  expect(entry.error).toContain("fig-bad");
  expect(entry.error).toContain("--nope");
  expect(entry.files.cp).toBeUndefined();
});

test("an unknown point inside a flap selector is named too", () => {
  const entry = renderFigure(
    { id: "fig-flapless", views: ["cp"], highlight: ["#[.zz]"], program: SQUARE },
    outDir,
    "spec/TEST.md",
  );
  expect(entry.error).toContain("fig-flapless");
  expect(entry.error).toContain(".zz");
});

test("a flap selector stays one entry although it has a space inside", () => {
  expect(highlightNames("--s #[.p .q] .a")).toEqual(["--s", "#[.p .q]", ".a"]);
});

test("scanFigures keeps the block body verbatim", () => {
  const blocks = scanFigures(
    `::: {.figure #fig-x caption="c" views="cp" highlight="--ac"}\n${SQUARE}\n:::\n`,
  );
  expect(blocks).toHaveLength(1);
  expect(blocks[0]!.program).toBe(SQUARE);
  expect(blocks[0]!.highlight).toEqual(["--ac"]);
});
