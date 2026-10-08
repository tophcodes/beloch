import { test, expect } from "bun:test";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkGfm from "remark-gfm";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import remarkIdLinks from "./remark-id-links.ts";
import { indexDocument, type Index } from "../../../../scripts/id-links.ts";

const model = indexDocument(
	["---", "title: Model", "---", "", "## 1. Paper", "", '::: {.definition #def-sheet name="sheet"}', "text", ":::"].join("\n"),
	"docs/reference/MODEL.md",
	"/model/",
);
const adr = indexDocument(
	["---", 'title: "The specification binds"', "---", "", "# The specification binds"].join("\n"),
	"docs/decisions/20260927-the-specification-binds-every-implementation.md",
	null,
);
const index: Index = {
	site: "https://belochlang.org",
	repository: "https://github.com/tophcodes/beloch/blob/main",
	documents: { [model.id]: model, [adr.id]: adr },
};

async function render(source: string) {
	return String(
		await unified()
			.use(remarkParse)
			.use(remarkGfm)
			.use(remarkIdLinks, { index })
			.use(remarkRehype)
			.use(rehypeStringify)
			.process({ path: "docs/guide/first-folds.md", value: source }),
	);
}

test("a link to a page, an anchor and a decision renders with the default text", async () => {
	const html = await render("See [[reference/model]], [[reference/model#def-sheet]] and [[decisions/the-specification-binds-every-implementation]].");
	expect(html).toBe(
		'<p>See <a href="/model/">Model</a>, <a href="/model/#def-sheet">sheet</a> and ' +
			'<a href="https://github.com/tophcodes/beloch/blob/main/docs/decisions/20260927-the-specification-binds-every-implementation.md">The specification binds</a>.</p>',
	);
});

test("text after the pipe replaces the default, and code spans keep their brackets", async () => {
	const html = await render("Read [[reference/model#1-paper|the paper section]]; write `[[decisions/the-specification-binds-every-implementation]]` to link it.");
	expect(html).toBe(
		'<p>Read <a href="/model/#1-paper">the paper section</a>; write <code>[[decisions/the-specification-binds-every-implementation]]</code> to link it.</p>',
	);
});

test("the escaped pipe of a table cell reads as the pipe", async () => {
	const html = await render("| Sort | Defined |\n|---|---|\n| sheet | [[reference/model#def-sheet\\|in a cell]] |");
	expect(html).toContain('<a href="/model/#def-sheet">in a cell</a>');
});

test("a link that resolves to nothing fails the build, naming the file and the target", async () => {
	await expect(render("See [[decisions/nothing-of-the-kind]].")).rejects.toThrow(
		"docs/guide/first-folds.md: [[decisions/nothing-of-the-kind]] names no document; there is no decisions/nothing-of-the-kind under docs/",
	);
});
