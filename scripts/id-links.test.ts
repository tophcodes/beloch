import { test, expect } from "bun:test";
import { join } from "node:path";
import {
	buildIndex,
	checkDocuments,
	findLinks,
	indexDocument,
	parseTarget,
	resolve,
	slug,
	type Index,
} from "./id-links.ts";

const root = join(import.meta.dir, "..");

const model = indexDocument(
	[
		"---",
		"title: Model",
		"---",
		"",
		"## 1. Paper",
		"",
		'::: {.definition #def-sheet name="sheet" uses="paper"}',
		"A sheet is a polygon.",
		":::",
		"",
		"```beloch",
		"## not a heading",
		"```",
		"",
		"## The `fold` verb",
		"## 1. Paper",
	].join("\n"),
	"docs/reference/MODEL.md",
	"/model/",
);

const adr = indexDocument(
	["---", 'id: "0032"', 'title: "The specification binds"', "---", "", "# 0032: The specification binds", "", "## Context"].join("\n"),
	"docs/decision/0032-the-specification-binds-every-implementation.md",
	null,
);

const index: Index = { site: "https://belochlang.org", repository: "https://github.com/tophcodes/beloch/blob/main", documents: { [model.id]: model, [adr.id]: adr } };

test("a document's id is its kind and case-folded stem; a decision's is its number", () => {
	expect(model.id).toBe("reference/model");
	expect(adr.id).toBe("decision/0032");
});

test("headings get the site's slugs, blocks their ids, and a fence hides its lines", () => {
	expect(model.anchors).toEqual({
		"1-paper": "1. Paper",
		"def-sheet": "sheet",
		"the-fold-verb": "The fold verb",
		"1-paper-1": "1. Paper",
	});
});

test("the title comes from the front matter, else from the first heading", () => {
	expect(model.title).toBe("Model");
	expect(adr.title).toBe("The specification binds");
	expect(indexDocument("# Dead ends\n\ntext", "docs/notes/antipatterns.md", null).title).toBe("Dead ends");
});

test("slug drops punctuation and numbers repeats", () => {
	const seen = new Map<string, number>();
	expect(slug("A mark's extent (§4)", seen)).toBe("a-marks-extent-4");
	expect(slug("A mark's extent (§4)", seen)).toBe("a-marks-extent-4-1");
});

test("findLinks reads targets and texts outside code, with line numbers", () => {
	const links = findLinks(
		[
			"See [[decision/0032]] and [[reference/model#def-sheet|the sheet]].",
			"Code keeps `[[decision/0001]]` and ``[[x]] with `backtick` ``.",
			"```",
			"[[decision/0002]]",
			"```",
			"[[notes/2026-06-28]]",
			"| a | [[reference/model#def-sheet\\|in a cell]] |",
		].join("\n"),
	);
	expect(links).toEqual([
		{ raw: "[[decision/0032]]", target: "decision/0032", text: null, line: 1 },
		{ raw: "[[reference/model#def-sheet|the sheet]]", target: "reference/model#def-sheet", text: "the sheet", line: 1 },
		{ raw: "[[notes/2026-06-28]]", target: "notes/2026-06-28", text: null, line: 6 },
		{ raw: "[[reference/model#def-sheet\\|in a cell]]", target: "reference/model#def-sheet", text: "in a cell", line: 7 },
	]);
});

test("parseTarget folds case and splits the anchor", () => {
	expect(parseTarget("Reference/MODEL#def-sheet")).toEqual({ id: "reference/model", anchor: "def-sheet" });
	expect(parseTarget("hull2020")).toBeNull();
	expect(parseTarget("decision/0032 and more")).toBeNull();
});

test("resolve gives the site page, the anchor and the default text", () => {
	expect(resolve(index, { target: "reference/model", text: null })).toMatchObject({ url: "/model/", text: "Model" });
	expect(resolve(index, { target: "reference/model#def-sheet", text: null })).toMatchObject({
		url: "/model/#def-sheet",
		text: "sheet",
	});
	expect(resolve(index, { target: "reference/model#1-paper", text: "the paper" })).toMatchObject({
		url: "/model/#1-paper",
		text: "the paper",
	});
});

test("a decision resolves to its file in the repository, named by number", () => {
	expect(resolve(index, { target: "decision/0032", text: null })).toMatchObject({
		url: "https://github.com/tophcodes/beloch/blob/main/docs/decision/0032-the-specification-binds-every-implementation.md",
		text: "ADR 0032",
	});
});

test("an unknown document, anchor or form is an error naming what is missing", () => {
	expect(resolve(index, { target: "decision/9999", text: null })).toEqual({
		error: "[[decision/9999]] names no document; there is no decision/9999 under docs/",
	});
	expect(resolve(index, { target: "reference/model#def-nothing", text: null })).toEqual({
		error: "[[reference/model#def-nothing]] names no anchor; docs/reference/MODEL.md has no #def-nothing",
	});
	expect(resolve(index, { target: "hull2020", text: null })).toEqual({
		error: "[[hull2020]] is no id; a link names kind/stem, with #anchor after it",
	});
});

test("the repository's index serves the reference pages and lists every decision", () => {
	const idx = buildIndex(root);
	expect(idx.documents["reference/model"]?.site).toBe("/model/");
	expect(idx.documents["reference/beloch-writes"]?.site).toBe("/language/writes/");
	expect(idx.documents["reference/fold"]?.site).toBe("/output/");
	expect(idx.documents["guide/first-folds"]?.site).toBe("/guide/first-folds/");
	expect(idx.documents["decision/0032"]?.site).toBeNull();
	expect(idx.documents["decision/0021"]?.path).toContain("archive/");
});

test("every id link under docs/ resolves", () => {
	expect(checkDocuments(root)).toEqual([]);
});
