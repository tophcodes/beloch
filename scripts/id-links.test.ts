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

const record = indexDocument(
	["---", 'title: "The specification binds"', "date: 2026-09-27", "---", "", "# The specification binds", "", "## Context"].join("\n"),
	"docs/decisions/20260927-the-specification-binds-every-implementation.md",
	null,
);

const index: Index = {
	site: "https://belochlang.org",
	repository: "https://github.com/tophcodes/beloch/blob/main",
	documents: { [model.id]: model, [record.id]: record },
};

test("a document's id is its kind and case-folded stem; a decision's stem is its slug after the date", () => {
	expect(model.id).toBe("reference/model");
	expect(record.id).toBe("decisions/the-specification-binds-every-implementation");
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
	expect(record.title).toBe("The specification binds");
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
			"See [[decisions/the-specification-binds-every-implementation]] and [[reference/model#def-sheet|the sheet]].",
			"Code keeps `[[decisions/ocaml-core-typescript-edge]]` and ``[[x]] with `backtick` ``.",
			"```",
			"[[decisions/fold-extended-as-output]]",
			"```",
			"[[notes/2026-06-28]]",
			"| a | [[reference/model#def-sheet\\|in a cell]] |",
		].join("\n"),
	);
	expect(links).toEqual([
		{
			raw: "[[decisions/the-specification-binds-every-implementation]]",
			target: "decisions/the-specification-binds-every-implementation",
			text: null,
			line: 1,
		},
		{ raw: "[[reference/model#def-sheet|the sheet]]", target: "reference/model#def-sheet", text: "the sheet", line: 1 },
		{ raw: "[[notes/2026-06-28]]", target: "notes/2026-06-28", text: null, line: 6 },
		{ raw: "[[reference/model#def-sheet\\|in a cell]]", target: "reference/model#def-sheet", text: "in a cell", line: 7 },
	]);
});

test("parseTarget folds case and splits the anchor", () => {
	expect(parseTarget("Reference/MODEL#def-sheet")).toEqual({ id: "reference/model", anchor: "def-sheet" });
	expect(parseTarget("hull2020")).toBeNull();
	expect(parseTarget("decisions/name-beloch and more")).toBeNull();
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

test("a decision resolves to its file in the repository, with its title as the text", () => {
	expect(resolve(index, { target: "decisions/the-specification-binds-every-implementation", text: null })).toMatchObject({
		url: "https://github.com/tophcodes/beloch/blob/main/docs/decisions/20260927-the-specification-binds-every-implementation.md",
		text: "The specification binds",
	});
});

test("an unknown document, anchor or form is an error naming what is missing", () => {
	expect(resolve(index, { target: "decisions/nothing-of-the-kind", text: null })).toEqual({
		error: "[[decisions/nothing-of-the-kind]] names no document; there is no decisions/nothing-of-the-kind under docs/",
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
	expect(idx.documents["decisions/the-specification-binds-every-implementation"]?.site).toBeNull();
	expect(idx.documents["decisions/reference-documents-replace-specification"]?.path).toContain("archive/");
});

test("every id link under docs/ resolves", () => {
	expect(checkDocuments(root)).toEqual([]);
});
