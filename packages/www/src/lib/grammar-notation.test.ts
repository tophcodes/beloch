import { test, expect } from "bun:test";
import { parseDocument } from "./grammar-notation.ts";
import {
	renderCollected,
	renderExternal,
	renderFragment,
	renderPlanned,
	renderRule,
} from "./grammar-notation.ts";

const source = [
	"# Fixture",
	"",
	"```grammar",
	'program := "paper" "square" stmt*',
	"stmt    := write_stmt",
	"```",
	"",
	"```grammar",
	"write_stmt := axis",
	'            | "moving" flap_operand [ "mountain" ]   ; a placed fold',
	"axis       := CREASE_NAME | flap_operand",
	"```",
	"",
	"```grammar-external",
	"flap_operand   ; SPECIFICATION.md Appendix A",
	"```",
	"",
	"```grammar-planned",
	"align   ; two-fold constructions are not evaluated yet",
	"```",
	"",
].join("\n");

const doc = parseDocument(source, "fixture.md");
const rules = doc.fragments.flatMap((f) => f.rules);
const byName = new Map(rules.map((r) => [r.name, r]));

test("every rule of every fragment is collected, in order of definition", () => {
	expect(rules.map((r) => r.name)).toEqual(["program", "stmt", "write_stmt", "axis"]);
	expect(doc.fragments.map((f) => f.line)).toEqual([4, 9]);
	expect(byName.get("write_stmt")?.line).toBe(9);
	expect(byName.get("write_stmt")?.id).toBe("rule-write_stmt");
});

test("a line is lexed into spans of the documented classes", () => {
	expect(byName.get("program")?.lines).toEqual([
		[
			{ class: "gr-rule", text: "program" },
			{ class: "gr-plain", text: " " },
			{ class: "gr-operator", text: ":=" },
			{ class: "gr-plain", text: " " },
			{ class: "gr-keyword", text: '"paper"' },
			{ class: "gr-plain", text: " " },
			{ class: "gr-keyword", text: '"square"' },
			{ class: "gr-plain", text: " " },
			{ class: "gr-nonterminal", text: "stmt", ref: "rule-stmt" },
			{ class: "gr-operator", text: "*" },
		],
	]);
});

test("an indented line continues the rule, with its breaks and indentation", () => {
	const rule = byName.get("write_stmt");
	expect(rule?.lines.length).toBe(2);
	// the `|` of the continuation sits under the `=` of the head line, so the
	// indentation is one character past the start of `:=`
	const indent = rule?.lines[1][0] as { class: string; text: string };
	expect(indent.class).toBe("gr-plain");
	expect(indent.text).toBe(" ".repeat("write_stmt :".length));
	expect(rule?.lines[1].at(-1)).toEqual({ class: "gr-comment", text: "; a placed fold" });
});

test("upper case is a token, a quoted word is a keyword, other quoted text a symbol", () => {
	expect(byName.get("axis")?.tokens).toEqual(["CREASE_NAME"]);
	expect(byName.get("write_stmt")?.keywords).toEqual(["moving", "mountain"]);
	expect(byName.get("program")?.keywords).toEqual(["paper", "square"]);
	const symbols = parseDocument(
		['```grammar', 'sel := "#[" CREASE_NAME "]"', "```"].join("\n"),
		"fixture.md",
	);
	expect(symbols.fragments[0].rules[0].symbols).toEqual(["#[", "]"]);
	expect(symbols.fragments[0].rules[0].keywords).toEqual([]);
});

test("uses are the nonterminals of the right-hand side; usedBy is derived", () => {
	expect(byName.get("write_stmt")?.uses).toEqual(["axis", "flap_operand"]);
	expect(byName.get("stmt")?.usedBy).toEqual(["program"]);
	expect(byName.get("axis")?.usedBy).toEqual(["write_stmt"]);
	expect(byName.get("program")?.usedBy).toEqual([]);
});

test("external and planned entries carry their line and their note", () => {
	expect(doc.external).toEqual([
		{
			name: "flap_operand",
			id: "rule-flap_operand",
			line: 15,
			note: "SPECIFICATION.md Appendix A",
		},
	]);
	expect(doc.planned).toEqual([
		{ keyword: "align", line: 19, note: "two-fold constructions are not evaluated yet" },
	]);
});

test('a "\\" keyword and a ? operator parse, so Appendix A can be tagged', () => {
	const doc = parseDocument(
		[
			"```grammar",
			'line_operand := line_operand "\\" constraint',
			'export_stmt  := "export" ( "{" CREASE_NAME+ "}" )? INSTANCE_NAME',
			"```",
		].join("\n"),
		"fixture.md",
		{ references: "ignore" },
	);
	const rules = doc.fragments[0].rules;
	expect(rules[0].symbols).toEqual(["\\"]);
	expect(rules[1].lines[0].some((s) => s.class === "gr-operator" && s.text === "?")).toBe(true);
});

test("a blank line and a column-0 comment end the rule and carry no spans", () => {
	const doc = parseDocument(
		[
			"```grammar",
			"a := b",
			"",
			"; a note about the group below",
			"b := CREASE_NAME",
			"```",
		].join("\n"),
		"fixture.md",
	);
	expect(doc.fragments[0].rules.map((r) => r.name)).toEqual(["a", "b"]);
	expect(doc.fragments[0].rules[0].lines.length).toBe(1);
});

test("references are not checked when the document is read for its keywords", () => {
	expect(() =>
		parseDocument(["```grammar", "body_stmt := stmt minus", "```"].join("\n"), "fixture.md", {
			references: "ignore",
		}),
	).not.toThrow();
});

import { readFileSync } from "node:fs";
import { join } from "node:path";

const fixtures = join(import.meta.dir, "fixtures");

function parseFixture(name: string) {
	const path = join(fixtures, name);
	return () => parseDocument(readFileSync(path, "utf8"), path);
}

function at(name: string, line: number): string {
	return `${join(fixtures, name)}:${line}: `;
}

test("a reference to an unknown name names the rule and the way out", () => {
	expect(parseFixture("grammar-error-unknown.md")).toThrow(
		`${at("grammar-error-unknown.md", 4)}rule fold_item refers to point_operand, which no rule ` +
			"in this document defines; state it here or list it in the grammar-external block",
	);
});

test("a rule defined twice names the first definition", () => {
	expect(parseFixture("grammar-error-duplicate.md")).toThrow(
		`${at("grammar-error-duplicate.md", 5)}rule axis is already defined at line 4`,
	);
});

test("a rule both defined and declared external names both sites", () => {
	expect(parseFixture("grammar-error-both.md")).toThrow(
		`${at("grammar-error-both.md", 9)}rule axis is defined at line 5 and declared external; ` +
			"remove the external entry",
	);
});

test("an external name nothing refers to is an error at its entry", () => {
	expect(parseFixture("grammar-error-unused-external.md")).toThrow(
		`${at("grammar-error-unused-external.md", 8)}point_operand is declared external and no rule ` +
			"refers to it; remove the entry",
	);
});

test("an unclosed fence ends in a named error, not a swallowed remainder", () => {
	expect(() => parseDocument("```grammar\na := CREASE_NAME\n", "fixture.md")).toThrow(
		"fixture.md:1: unclosed fence; add a closing line of three backticks",
	);
});

test("a `grammar` sample quoted inside a wider fence is not a fragment of its own", () => {
	const nested = parseFixture("grammar-nested-fence.md")();
	expect(nested.fragments.map((f) => ({ line: f.line, rules: f.rules.map((r) => r.name) }))).toEqual(
		[{ line: 13, rules: ["real"] }],
	);
	expect(renderCollected(nested)).not.toContain("rule-fake");
});

test("a `grammar2` info string is not a grammar block", () => {
	const doc = parseDocument(
		[
			"```grammar",
			"real := CREASE_NAME",
			"```",
			"",
			"```grammar2",
			"fake := CREASE_NAME",
			"```",
		].join("\n"),
		"fixture.md",
	);
	expect(doc.fragments.map((f) => f.rules.map((r) => r.name))).toEqual([["real"]]);
});

test("an info string glued to the language, like `c99` or `json5`, still opens and closes a fence, and a closed `grammar2` block does not swallow a later `grammar` block", () => {
	const doc = parseDocument(
		[
			"```grammar",
			"real := CREASE_NAME",
			"```",
			"",
			"```grammar2",
			"fake := CREASE_NAME",
			"```",
			"",
			"```c99",
			"int main() {}",
			"```",
			"",
			"```json5",
			"{ x: 1 }",
			"```",
			"",
			"```grammar",
			"real2 := CREASE_NAME",
			"```",
		].join("\n"),
		"fixture.md",
	);
	expect(doc.fragments.map((f) => f.rules.map((r) => r.name))).toEqual([["real"], ["real2"]]);
});

test("a four-backtick block quoting an unclosed three-backtick fence parses without error", () => {
	const doc = parseDocument(
		[
			"````",
			"```grammar",
			"fake := CREASE_NAME",
			"````",
			"",
			"```grammar",
			"real := CREASE_NAME",
			"```",
		].join("\n"),
		"fixture.md",
	);
	expect(doc.fragments.map((f) => f.rules.map((r) => r.name))).toEqual([["real"]]);
});

test("content in the collected marker is an error", () => {
	expect(parseFixture("grammar-error-collected.md")).toThrow(
		`${at("grammar-error-collected.md", 8)}the grammar-collected block is generated; leave it empty`,
	);
});

test("a line that is neither a rule head nor a continuation quotes the line", () => {
	expect(parseFixture("grammar-error-line.md")).toThrow(
		`${at("grammar-error-line.md", 4)}expected \`name :=\` or an indented continuation, ` +
			'got "fold_item = axis"',
	);
});

test("a character with no class names the character and the rule", () => {
	expect(parseFixture("grammar-error-char.md")).toThrow(
		`${at("grammar-error-char.md", 4)}unexpected character "%" in rule fold_item`,
	);
});

test("a defining name carries its id; a nonterminal is a link", () => {
	const html = renderRule(byName.get("program") as never, doc);
	expect(html).toContain('<pre class="grammar-block"><code>');
	expect(html).toContain('<span class="gr-rule" id="rule-program">program</span>');
	expect(html).toContain('<span class="gr-keyword">"paper"</span>');
	expect(html).toContain('<a class="gr-nonterminal" href="#rule-stmt">stmt</a>');
	expect(html).toContain('<span class="gr-operator">*</span>');
});

test("a reference to an external name carries gr-external", () => {
	const html = renderRule(byName.get("axis") as never, doc);
	expect(html).toContain(
		'<a class="gr-nonterminal gr-external" href="#rule-flap_operand">flap_operand</a>',
	);
	expect(html).toContain('<span class="gr-token">CREASE_NAME</span>');
});

test("a rule other rules refer to carries a Used by line; one nothing refers to does not", () => {
	expect(renderRule(byName.get("axis") as never, doc)).toContain(
		'<p class="gr-links">Used by: <a href="#rule-write_stmt">write_stmt</a></p>',
	);
	expect(renderRule(byName.get("program") as never, doc)).not.toContain("gr-links");
});

test("the collected copy links the name back and carries no id and no links line", () => {
	const html = renderCollected(doc);
	expect(html).toContain('<a class="gr-rule" href="#rule-program">program</a>');
	expect(html).not.toContain('id="rule-program"');
	expect(html).not.toContain("gr-links");
	const order = [...html.matchAll(/<a class="gr-rule" href="#rule-([a-z_]+)">/g)].map((m) => m[1]);
	expect(order).toEqual(["program", "stmt", "write_stmt", "axis"]);
});

test("a fragment wraps its rules and keeps its line breaks", () => {
	const html = renderFragment(doc.fragments[1], doc);
	expect(html.startsWith('<div class="grammar-fragment">')).toBe(true);
	expect(html).toContain("\n            <span");
	expect(html).toContain('<span class="gr-comment">; a placed fold</span>');
});

test("the external and planned blocks carry their heads, ids and notes", () => {
	const html = renderExternal(doc);
	expect(html).toContain('<p class="gr-block-head">Defined elsewhere</p>');
	expect(html).toContain('<span class="gr-rule" id="rule-flap_operand">flap_operand</span>');
	expect(html).toContain('<span class="gr-comment">; SPECIFICATION.md Appendix A</span>');
	const planned = renderPlanned(doc);
	expect(planned).toContain('<p class="gr-block-head">Not lexed yet</p>');
	expect(planned).toContain('<span class="gr-keyword">align</span>');
	expect(planned).toContain(
		'<span class="gr-comment">; two-fold constructions are not evaluated yet</span>',
	);
});
