#!/usr/bin/env bun
// The grammar register: the documented grammar of spec/, parsed.
//
// Scans spec/BELOCH.md, the rendered document, and spec/SPECIFICATION.md,
// whose Appendix A block carries the `grammar` tag and is read for its
// keywords alone: no ids, no links, no collection, and its rules satisfy no
// external declaration of BELOCH.md. Parsing both means the documented side of
// the keyword cross-check is the whole documented grammar while the appendix
// migrates into BELOCH.md, and the union shrinks to BELOCH.md by itself when
// the appendix is empty.
//
// The parse is the one packages/www/src/lib/remark-grammar.ts renders from, so
// the PDF (scripts/grammar-blocks.lua) and the page carry the same rules in the
// same order.
//
//   bun scripts/grammar-register.ts [--out <path>]

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import {
	parseDocument,
	type GrammarDocument,
	type ParseOptions,
} from "../packages/www/src/lib/grammar-notation.ts";

export interface DocumentSpec {
	/** Repo-relative. */
	path: string;
	references: "check" | "ignore";
}

export interface GrammarRegister {
	documents: GrammarDocument[];
}

export const DOCUMENTS: DocumentSpec[] = [
	{ path: "spec/BELOCH.md", references: "check" },
	{ path: "spec/SPECIFICATION.md", references: "ignore" },
];

/** The keyword table the cross-check reads. */
export const LEXER = "packages/core/lib/lexer.ml";

const ROOT = join(import.meta.dir, "..");

export function buildGrammarRegister(paths: (string | DocumentSpec)[]): GrammarRegister {
	return {
		documents: paths.map((entry) => {
			const spec: DocumentSpec =
				typeof entry === "string" ? { path: entry, references: "check" } : entry;
			const options: ParseOptions = { references: spec.references };
			return parseDocument(readFileSync(join(ROOT, spec.path), "utf8"), spec.path, options);
		}),
	};
}

// A sedlex branch of the keyword table: `  | "paper" -> PAPER`. The `[a-z]+`
// filter drops "#[", "--[" and ".[" on this side, the way the word-keyword
// filter drops them on the documented side.
const LEXED = /^[ \t]*\|[ \t]*"([a-z]+)"[ \t]*->/gm;

export function lexerKeywords(source: string): Set<string> {
	return new Set([...source.matchAll(LEXED)].map((m) => m[1]));
}

/** Every word keyword of the register, with the first rule that states it. */
export function documentedKeywords(
	register: GrammarRegister,
): Map<string, { path: string; line: number }> {
	const out = new Map<string, { path: string; line: number }>();
	for (const doc of register.documents) {
		for (const fragment of doc.fragments) {
			for (const rule of fragment.rules) {
				for (const keyword of rule.keywords) {
					if (!out.has(keyword)) out.set(keyword, { path: doc.path, line: rule.line });
				}
			}
		}
	}
	return out;
}

/** A set comparison over keyword spellings. Empty means the two sides agree. */
export function crossCheck(
	register: GrammarRegister,
	lexerSource: string,
	lexerPath: string,
): string[] {
	const documented = documentedKeywords(register);
	const lexed = lexerKeywords(lexerSource);
	const planned = new Map<string, { path: string; line: number }>();
	for (const doc of register.documents) {
		for (const entry of doc.planned) {
			if (!planned.has(entry.keyword)) {
				planned.set(entry.keyword, { path: doc.path, line: entry.line });
			}
		}
	}

	const failures: string[] = [];
	for (const [keyword, site] of documented) {
		if (lexed.has(keyword) || planned.has(keyword)) continue;
		failures.push(
			`keyword "${keyword}" is stated in ${site.path}:${site.line} and ${lexerPath} ` +
				"does not lex it",
		);
	}
	for (const keyword of lexed) {
		if (documented.has(keyword)) continue;
		failures.push(
			`keyword "${keyword}" is lexed by ${lexerPath} and no documented rule states it`,
		);
	}
	for (const [keyword, site] of planned) {
		if (!lexed.has(keyword)) continue;
		failures.push(
			`keyword "${keyword}" is declared planned in ${site.path}:${site.line} and ${lexerPath} ` +
				"lexes it; remove the entry",
		);
	}
	return failures;
}

if (import.meta.main) {
	const flag = process.argv.indexOf("--out");
	const out = flag >= 0 ? process.argv[flag + 1] : join(ROOT, "_build", "grammar.json");
	const register = buildGrammarRegister(DOCUMENTS);
	mkdirSync(dirname(out), { recursive: true });
	writeFileSync(out, `${JSON.stringify(register, null, 2)}\n`);
	const rules = register.documents.reduce(
		(n, doc) => n + doc.fragments.reduce((m, f) => m + f.rules.length, 0),
		0,
	);
	console.log(`${out} (${rules} rules)`);
}
