import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import remarkGrammar from "./remark-grammar.ts";

const fixtures = join(import.meta.dir, "fixtures");

async function renderSource(path: string, source: string) {
	return String(
		await unified()
			.use(remarkParse)
			.use(remarkGrammar)
			.use(remarkRehype, { allowDangerousHtml: true })
			.use(rehypeStringify, { allowDangerousHtml: true })
			.process({ path, value: source }),
	);
}

async function render(path: string) {
	return renderSource(path, readFileSync(path, "utf8"));
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

test("no rule carries a gr-links element", () => {
	expect(html).not.toContain("gr-links");
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

test("a fence tagged grammar with a meta string still renders, meta ignored", async () => {
	const out = await render(join(fixtures, "grammar-meta-fence.md"));
	expect(out).toContain('<span class="gr-rule" id="rule-a">a</span>');
	expect(out).toContain('<span class="gr-rule" id="rule-b">b</span>');
	expect(out.indexOf('id="rule-a"')).toBeLessThan(out.indexOf('id="rule-b"'));
	expect(out).not.toContain("title=");
	expect(out).not.toContain("demo");
});

test("a grammar sample nested in a four-backtick block is not paired as a fence", async () => {
	const out = await render(join(fixtures, "grammar-nested-fence.md"));
	// The real fence renders its own rule, matched by line rather than by an
	// ordinal count the nested sample would otherwise have shifted.
	expect(out).toContain('<span class="gr-rule" id="rule-real">real</span>');
	expect(out).not.toContain('id="rule-fake"');
	expect(out).toContain("```grammar\nfake := CREASE_NAME\n```");
});

test("an unclosed fence ends in a named error, not a swallowed remainder", async () => {
	const path = join(fixtures, "grammar-unclosed.md");
	await expect(renderSource(path, "```grammar\na := CREASE_NAME\n")).rejects.toThrow(
		`${path}:1: unclosed fence`,
	);
});
