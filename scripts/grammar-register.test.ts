import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
	buildGrammarRegister,
	crossCheck,
	lexerKeywords,
	DOCUMENTS,
	LEXER,
} from "./grammar-register.ts";

const root = join(import.meta.dir, "..");
const register = buildGrammarRegister(DOCUMENTS);
const lexerSource = readFileSync(join(root, LEXER), "utf8");

const beloch = register.documents.find((d) => d.path === "spec/BELOCH.md");
if (!beloch) throw new Error("spec/BELOCH.md missing from the register");

test("spec/BELOCH.md yields 18 rules and 7 external names", () => {
	expect(beloch.fragments.flatMap((f) => f.rules).length).toBe(18);
	expect(beloch.external.length).toBe(7);
	expect(beloch.external.map((e) => e.name)).toEqual([
		"point_operand",
		"line_operand",
		"prose_axiom",
		"bind_stmt",
		"def_stmt",
		"apply_stmt",
		"export_stmt",
	]);
	expect(beloch.planned).toEqual([]);
});

test("a rule's lines are the rendering contract both renderers consume", () => {
	const program = beloch.fragments.flatMap((f) => f.rules).find((r) => r.name === "program");
	expect(program?.id).toBe("rule-program");
	expect(program?.keywords).toEqual(["paper", "square"]);
	expect(program?.symbols).toEqual([]);
	expect(program?.uses).toEqual(["stmt"]);
	expect(program?.usedBy).toEqual([]);
	expect(program?.lines).toEqual([
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

test("spec/SPECIFICATION.md is in the register, read for its keywords", () => {
	const spec = register.documents.find((d) => d.path === "spec/SPECIFICATION.md");
	expect(spec?.fragments.flatMap((f) => f.rules).length).toBeGreaterThan(20);
	expect(spec?.external).toEqual([]);
});

test("the lexer's keyword table is read from its sedlex branches", () => {
	const lexed = lexerKeywords(lexerSource);
	expect(lexed.has("paper")).toBe(true);
	expect(lexed.has("between")).toBe(true);
	expect(lexed.has("#[")).toBe(false);
	expect(lexed.has("--[")).toBe(false);
});

test("the documented keywords and the lexer agree, with no keyword declared planned", () => {
	expect(register.documents.every((d) => d.planned.length === 0)).toBe(true);
	expect(crossCheck(register, lexerSource, LEXER)).toEqual([]);
});

test("a documented keyword the lexer lacks fails, naming where it is stated", () => {
	const unlexed = lexerSource.replace(/^[ \t]*\|[ \t]*"align"[ \t]*->.*$/m, "");
	const failures = crossCheck(register, unlexed, LEXER);
	expect(failures).toEqual([
		expect.stringMatching(
			/^keyword "align" is stated in spec\/BELOCH\.md:\d+ and packages\/core\/lib\/lexer\.ml does not lex it$/,
		),
	]);
});

test("a lexed keyword no documented rule states fails, naming the keyword", () => {
	const failures = crossCheck(register, `${lexerSource}\n  | "rotate" -> ROTATE\n`, LEXER);
	expect(failures).toEqual([
		'keyword "rotate" is lexed by packages/core/lib/lexer.ml and no documented rule states it',
	]);
});

test("a planned keyword the lexer already has fails, naming its entry", () => {
	const stale = {
		documents: register.documents.map((d) =>
			d.path === "spec/BELOCH.md"
				? { ...d, planned: [...d.planned, { keyword: "map", line: 275, note: "" }] }
				: d,
		),
	};
	const failures = crossCheck(stale, lexerSource, LEXER);
	expect(failures).toEqual([
		'keyword "map" is declared planned in spec/BELOCH.md:275 and packages/core/lib/lexer.ml ' +
			"lexes it; remove the entry",
	]);
});
