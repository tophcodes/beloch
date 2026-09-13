import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import remarkGrammar from "./remark-grammar.ts";

const fixtures = join(import.meta.dir, "fixtures");

async function render(path: string) {
	return String(
		await unified()
			.use(remarkParse)
			.use(remarkGrammar)
			.use(remarkRehype, { allowDangerousHtml: true })
			.use(rehypeStringify, { allowDangerousHtml: true })
			.process({ path, value: readFileSync(path, "utf8") }),
	);
}

const html = await render(join(fixtures, "grammar-blocks.md"));

test("a fragment renders as grammar-block pres with the notation's classes", () => {
	expect(html).toContain('<div class="grammar-fragment">');
	expect(html).toContain('<pre class="grammar-block"><code>');
	expect(html).toContain('<span class="gr-keyword">"moving"</span>');
	expect(html).toContain('<span class="gr-token">CREASE_NAME</span>');
	expect(html).toContain('<span class="gr-operator">:=</span>');
	expect(html).toContain('<span class="gr-comment">; a placed fold</span>');
	// indentation and the line break of the continuation, as written: the
	// alternatives of fold_item line up under its `:=`
	const cont = /\n( +)<span class="gr-operator">\|<\/span>/.exec(html);
	expect(cont?.[1]).toBe(" ".repeat("fold_item    :".length));
});

test("the defining occurrence carries the id and the collected copy does not", () => {
	expect(html).toContain('<span class="gr-rule" id="rule-fold_item">fold_item</span>');
	expect(html.split('id="rule-fold_item"').length - 1).toBe(1);
	expect(html).toContain('<a class="gr-rule" href="#rule-fold_item">fold_item</a>');
});

test("a nonterminal is a link; an external name points at its entry", () => {
	expect(html).toContain('<a class="gr-nonterminal" href="#rule-axis">axis</a>');
	expect(html).toContain(
		'<a class="gr-nonterminal gr-external" href="#rule-flap_operand">flap_operand</a>',
	);
	expect(html).toContain('<span class="gr-rule" id="rule-flap_operand">flap_operand</span>');
});

test("backlinks are in document order; a rule nothing refers to has none", () => {
	expect(html).toContain(
		'<p class="gr-links">Used by: <a href="#rule-fold_item">fold_item</a>, ' +
			'<a href="#rule-reverse_item">reverse_item</a></p>',
	);
	const program = html.slice(html.indexOf('id="rule-program"'));
	expect(program.slice(0, program.indexOf("</pre>"))).not.toContain("gr-links");
});

test("the collected marker expands to every rule in order of definition", () => {
	const collected = html.slice(html.indexOf("collected."));
	const order = [...collected.matchAll(/<a class="gr-rule" href="#rule-([a-z_]+)">/g)].map(
		(m) => m[1],
	);
	expect(order).toEqual([
		"program",
		"stmt",
		"write_stmt",
		"item",
		"fold_item",
		"axis",
		"reverse_item",
	]);
});

test("the declaration blocks render with their heads", () => {
	expect(html).toContain('<p class="gr-block-head">Defined elsewhere</p>');
	expect(html).toContain('<p class="gr-block-head">Not lexed yet</p>');
	expect(html).toContain('<span class="gr-keyword">align</span>');
});

test("a build error names the document", async () => {
	const path = join(fixtures, "grammar-error-unknown.md");
	expect(render(path)).rejects.toThrow(`${path}:4: rule fold_item refers to point_operand`);
});
