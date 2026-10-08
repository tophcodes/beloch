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
	["---", 'id: "0032"', 'title: "The specification binds"', "---", "", "# 0032: The specification binds"].join("\n"),
	"docs/decision/0032-the-specification-binds-every-implementation.md",
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
	const html = await render("See [[reference/model]], [[reference/model#def-sheet]] and [[decision/0032]].");
	expect(html).toBe(
		'<p>See <a href="/model/">Model</a>, <a href="/model/#def-sheet">sheet</a> and ' +
			'<a href="https://github.com/tophcodes/beloch/blob/main/docs/decision/0032-the-specification-binds-every-implementation.md">ADR 0032</a>.</p>',
	);
});

test("text after the pipe replaces the default, and code spans keep their brackets", async () => {
	const html = await render("Read [[reference/model#1-paper|the paper section]]; write `[[decision/0032]]` to link it.");
	expect(html).toBe(
		'<p>Read <a href="/model/#1-paper">the paper section</a>; write <code>[[decision/0032]]</code> to link it.</p>',
	);
});

test("the escaped pipe of a table cell reads as the pipe", async () => {
	const html = await render("| Sort | Defined |\n|---|---|\n| sheet | [[reference/model#def-sheet\\|in a cell]] |");
	expect(html).toContain('<a href="/model/#def-sheet">in a cell</a>');
});

test("a link that resolves to nothing fails the build, naming the file and the target", async () => {
	await expect(render("See [[decision/9999]].")).rejects.toThrow(
		"docs/guide/first-folds.md: [[decision/9999]] names no document; there is no decision/9999 under docs/",
	);
});
