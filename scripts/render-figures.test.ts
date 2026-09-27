// The figure pipeline's reading of a `.figure` block: which entities a
// `highlight` may name, and what happens when it names one the program never
// defines. Needs the `beloch` binary, so it runs inside the flake devshell:
//   nix develop -c bun test scripts
import { test, expect } from "bun:test";
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { documentFiles, renderDocuments, renderFigure, scanFigures, highlightNames } from "./render-figures.ts";

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

const TRIANGLE = [
	"paper square",
	"mark (map .a onto .b) as --ef",
	"@label choose",
	"fold (map .d onto --ef through .a) as --s",
].join("\n");

test("a candidates figure draws the choices of a program that stops at them", () => {
	const entry = renderFigure(
		{ id: "fig-choice", views: ["candidates"], highlight: [], at: "choose", program: TRIANGLE },
		outDir,
		"spec/TEST.md",
	);
	expect(entry.error).toBeNull();
	expect(entry.files.candidates).toBe("fig-choice-candidates.svg");
	const svg = readFileSync(join(outDir, "fig-choice-candidates.svg"), "utf8");
	expect((svg.match(/data-status="open"/g) ?? []).length).toBe(2);
});

test("an op figure draws the write of the labelled statement", () => {
	const entry = renderFigure(
		{
			id: "fig-rev", views: ["op"], highlight: [], at: "rev",
			program: "paper square\nfold (map .a onto .c) as --bd\n@label rev\nreverse (map .b onto .c) as --h\n",
		},
		outDir,
		"spec/TEST.md",
	);
	expect(entry.error).toBeNull();
	const svg = readFileSync(join(outDir, "fig-rev-op.svg"), "utf8");
	expect(svg).toContain('data-kind="spine"');
	expect(svg).toContain("reverse · inside");
});

test("a figure that shows an unlabelled statement is an error", () => {
	const entry = renderFigure(
		{ id: "fig-noat", views: ["candidates"], highlight: [], at: "nope", program: TRIANGLE },
		outDir,
		"spec/TEST.md",
	);
	expect(entry.error).toContain("nope");
});

test("scanFigures reads the at attribute", () => {
	const [block] = scanFigures(
		'::: {.figure #fig-x caption="x" views="candidates" at="choose"}\npaper square\n:::\n',
	);
	expect(block?.at).toBe("choose");
	expect(block?.views).toEqual(["candidates"]);
});

test("scanFigures reads the after attribute", () => {
	const [block] = scanFigures('::: {.figure #fig-y caption="y" after="fig-x"}\nfold (map .a onto .c)\n:::\n');
	expect(block?.after).toBe("fig-x");
});

// A document of figures under a scratch root, for renderDocuments.
function scratchDocs(files: Record<string, string>): string {
	const root = mkdtempSync(join(tmpdir(), "beloch-docs-"));
	for (const [path, text] of Object.entries(files)) {
		mkdirSync(join(root, dirname(path)), { recursive: true });
		writeFileSync(join(root, path), text);
	}
	return root;
}

test("a figure with after evaluates the earlier figure's program before its own", () => {
	const root = scratchDocs({
		"doc.md": [
			'::: {.figure #fig-first caption="a"}',
			"paper square\nfold (map .a onto .c) as --bd",
			":::",
			"",
			'::: {.figure #fig-second caption="b" highlight="--h" after="fig-first"}',
			"reverse (map .b onto .c) as --h",
			":::",
			"",
		].join("\n"),
	});
	const figures = renderDocuments(root, ["doc.md"], mkdtempSync(join(tmpdir(), "beloch-figures-")));
	expect(figures["fig-second"]?.error).toBeNull();
	expect(figures["fig-second"]?.files.folded).toBe("fig-second-folded.svg");
});

test("an after naming no earlier figure of the document is an error", () => {
	const root = scratchDocs({
		"one.md": '::: {.figure #fig-one caption="a"}\npaper square\n:::\n',
		"two.md": '::: {.figure #fig-two caption="b" after="fig-one"}\nfold (map .a onto .c)\n:::\n',
	});
	const figures = renderDocuments(root, ["one.md", "two.md"], mkdtempSync(join(tmpdir(), "beloch-figures-")));
	expect(figures["fig-two"]?.error).toContain("fig-one");
});

test("a figure id used twice is an error", () => {
	const root = scratchDocs({
		"one.md": '::: {.figure #fig-same caption="a"}\npaper square\n:::\n',
		"two.md": '::: {.figure #fig-same caption="b"}\npaper square\n:::\n',
	});
	const figures = renderDocuments(root, ["one.md", "two.md"], mkdtempSync(join(tmpdir(), "beloch-figures-")));
	expect(figures["fig-same"]?.error).toContain("two.md");
});

test("every figure of the documents renders", () => {
	const root = join(import.meta.dir, "..");
	const figures = renderDocuments(root, documentFiles(root), mkdtempSync(join(tmpdir(), "beloch-figures-")));
	const failed = Object.entries(figures).filter(([, e]) => e.error).map(([id, e]) => `${id}: ${e.error}`);
	expect(failed).toEqual([]);
	expect(Object.values(figures).some((e) => e.source.startsWith("packages/www/src/content/docs/guide/"))).toBe(true);
}, 120_000);
