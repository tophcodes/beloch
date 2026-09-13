// The grammar notation of spec/BELOCH.md: a lexer over one line at a time, the
// document checks, and the HTML renderers.
//
// A rule starts at column 0 and runs to the next line that starts at column 0
// or to the end of the fragment; an indented line continues the current rule,
// whether or not it opens with `|`. A blank line and a `;` comment at column 0
// end the current rule and belong to no rule.
//
// This module imports nothing from remark, so scripts/grammar-register.ts can
// use it and the register is the same parse the page renders.
//
// Astro caches rendered content entries in node_modules/.astro; after changing
// this file, delete that directory (and .astro/) or the old output is served.

/** A run of one class. `class` is used verbatim as a CSS class and as a typst
    `raw` language. */
export interface Span {
	class: string;
	text: string;
	/** `rule-<name>`, on a nonterminal. */
	ref?: string;
}

export interface Rule {
	name: string;
	id: string;
	/** 1-based line of the rule head in the document. */
	line: number;
	uses: string[];
	usedBy: string[];
	/** Quoted strings matching `^[a-z]+$`, unquoted. */
	keywords: string[];
	/** Every other quoted string, unquoted. */
	symbols: string[];
	tokens: string[];
	lines: Span[][];
}

export interface Fragment {
	/** 1-based line of the fragment's first source line. */
	line: number;
	rules: Rule[];
}

export interface External {
	name: string;
	id: string;
	line: number;
	note: string;
}

export interface Planned {
	keyword: string;
	line: number;
	note: string;
}

export interface GrammarDocument {
	path: string;
	fragments: Fragment[];
	external: External[];
	planned: Planned[];
}

export interface ParseOptions {
	/** "ignore" for a document read for its keywords alone, which may refer to
	    names it does not state. */
	references?: "check" | "ignore";
}

export class GrammarError extends Error {}

// An opener is a run of three or more backticks followed by an info string:
// anything with no backtick in it, possibly empty. The language is the info
// string's first word; anything after is a meta part (a title, flags for a
// highlighter), set off from the language by a space or tab, and not part of
// the language. A fence ends at the first later line that is a run of
// backticks at least as wide as the opener and nothing else, so a narrower
// fence quoted inside it is content, not a nested block.
const OPEN = /^(`{3,})([^`]*)$/;
const CLOSE = /^(`+)\s*$/;
const HEAD = /^([A-Za-z_][A-Za-z0-9_]*)\s*:=/;
const ENTRY = /^\s*([A-Za-z_][A-Za-z0-9_]*)[ \t]*(?:;[ \t]*(.*?))?[ \t]*$/;
const IDENT = /^[A-Za-z_][A-Za-z0-9_]*/;
const TOKEN = /^[A-Z][A-Z0-9_]*$/;
const WORD = /^[a-z]+$/;
const OPERATORS = [":=", "|", "[", "]", "(", ")", "*", "+", "?"];

interface Block {
	lang: string;
	/** 1-based line of the first line inside the fence. */
	line: number;
	lines: string[];
}

function fail(path: string, line: number, message: string): never {
	throw new GrammarError(`${path}:${line}: ${message}`);
}

function blocks(source: string, path: string): Block[] {
	const all = source.split("\n");
	const out: Block[] = [];
	for (let i = 0; i < all.length; i++) {
		const open = OPEN.exec(all[i]);
		if (!open) continue;
		const width = open[1].length;
		const lang = open[2].trim().split(/[ \t]+/, 1)[0] ?? "";
		let j = i + 1;
		while (j < all.length) {
			const close = CLOSE.exec(all[j]);
			if (close && close[1].length >= width) break;
			j++;
		}
		if (j >= all.length) fail(path, i + 1, "unclosed fence; add a closing line of three backticks");
		out.push({ lang, line: i + 2, lines: all.slice(i + 1, j) });
		i = j;
	}
	return out;
}

function shown(text: string): string {
	return text.replace(/\s+$/, "");
}

function lexLine(text: string, head: boolean, rule: string, path: string, line: number): Span[] {
	const spans: Span[] = [];
	let i = 0;
	while (i < text.length) {
		const c = text[i];
		if (c === ";") {
			spans.push({ class: "gr-comment", text: shown(text.slice(i)) });
			break;
		}
		if (c === " " || c === "\t") {
			let j = i;
			while (j < text.length && (text[j] === " " || text[j] === "\t")) j++;
			if (j < text.length) spans.push({ class: "gr-plain", text: text.slice(i, j) });
			i = j;
			continue;
		}
		if (c === '"') {
			const end = text.indexOf('"', i + 1);
			if (end < 0) fail(path, line, `unexpected character "\\"" in rule ${rule}`);
			spans.push({ class: "gr-keyword", text: text.slice(i, end + 1) });
			i = end + 1;
			continue;
		}
		const op = OPERATORS.find((o) => text.startsWith(o, i));
		if (op) {
			spans.push({ class: "gr-operator", text: op });
			i += op.length;
			continue;
		}
		const id = IDENT.exec(text.slice(i));
		if (!id) fail(path, line, `unexpected character "${c}" in rule ${rule}`);
		const name = id[0];
		if (head && i === 0) spans.push({ class: "gr-rule", text: name });
		else if (TOKEN.test(name)) spans.push({ class: "gr-token", text: name });
		else spans.push({ class: "gr-nonterminal", text: name, ref: `rule-${name}` });
		i += name.length;
	}
	return spans;
}

function classify(rule: Rule) {
	for (const spans of rule.lines) {
		for (const span of spans) {
			if (span.class === "gr-nonterminal") {
				if (!rule.uses.includes(span.text)) rule.uses.push(span.text);
			} else if (span.class === "gr-token") {
				if (!rule.tokens.includes(span.text)) rule.tokens.push(span.text);
			} else if (span.class === "gr-keyword") {
				const body = span.text.slice(1, -1);
				const list = WORD.test(body) ? rule.keywords : rule.symbols;
				if (!list.includes(body)) list.push(body);
			}
		}
	}
}

function parseFragment(block: Block, path: string): Fragment {
	const rules: Rule[] = [];
	let current: Rule | null = null;
	block.lines.forEach((text, k) => {
		const line = block.line + k;
		if (/^\s*$/.test(text) || text.startsWith(";")) {
			current = null;
			return;
		}
		if (/^\s/.test(text)) {
			if (!current) {
				fail(
					path,
					line,
					`expected \`name :=\` or an indented continuation, got "${shown(text)}"`,
				);
			}
			current.lines.push(lexLine(text, false, current.name, path, line));
			return;
		}
		const head = HEAD.exec(text);
		if (!head) {
			fail(path, line, `expected \`name :=\` or an indented continuation, got "${shown(text)}"`);
		}
		current = {
			name: head[1],
			id: `rule-${head[1]}`,
			line,
			uses: [],
			usedBy: [],
			keywords: [],
			symbols: [],
			tokens: [],
			lines: [],
		};
		current.lines.push(lexLine(text, true, current.name, path, line));
		rules.push(current);
	});
	for (const rule of rules) classify(rule);
	return { line: block.line, rules };
}

function parseEntries(block: Block, path: string): { name: string; line: number; note: string }[] {
	const out: { name: string; line: number; note: string }[] = [];
	block.lines.forEach((text, k) => {
		const line = block.line + k;
		if (/^\s*$/.test(text)) return;
		const entry = ENTRY.exec(text);
		if (!entry) {
			fail(path, line, `expected \`name\` or \`name ; note\`, got "${shown(text)}"`);
		}
		out.push({ name: entry[1], line, note: entry[2] ?? "" });
	});
	return out;
}

function check(doc: GrammarDocument, references: "check" | "ignore") {
	const rules = new Map<string, Rule>();
	for (const fragment of doc.fragments) {
		for (const rule of fragment.rules) {
			const first = rules.get(rule.name);
			if (first) {
				fail(doc.path, rule.line, `rule ${rule.name} is already defined at line ${first.line}`);
			}
			rules.set(rule.name, rule);
		}
	}
	for (const entry of doc.external) {
		const rule = rules.get(entry.name);
		if (rule) {
			fail(
				doc.path,
				entry.line,
				`rule ${entry.name} is defined at line ${rule.line} and declared external; ` +
					"remove the external entry",
			);
		}
	}
	const external = new Set(doc.external.map((e) => e.name));
	const referred = new Set<string>();
	for (const fragment of doc.fragments) {
		for (const rule of fragment.rules) {
			rule.lines.forEach((spans, offset) => {
				for (const span of spans) {
					if (span.class !== "gr-nonterminal") continue;
					referred.add(span.text);
					const target = rules.get(span.text);
					if (target) {
						if (!target.usedBy.includes(rule.name)) target.usedBy.push(rule.name);
						continue;
					}
					if (external.has(span.text) || references === "ignore") continue;
					fail(
						doc.path,
						rule.line + offset,
						`rule ${rule.name} refers to ${span.text}, which no rule in this document ` +
							"defines; state it here or list it in the grammar-external block",
					);
				}
			});
		}
	}
	if (references === "ignore") return;
	for (const entry of doc.external) {
		if (referred.has(entry.name)) continue;
		fail(
			doc.path,
			entry.line,
			`${entry.name} is declared external and no rule refers to it; remove the entry`,
		);
	}
}

export function parseDocument(
	source: string,
	path: string,
	options: ParseOptions = {},
): GrammarDocument {
	const doc: GrammarDocument = { path, fragments: [], external: [], planned: [] };
	for (const block of blocks(source, path)) {
		if (block.lang === "grammar") {
			doc.fragments.push(parseFragment(block, path));
		} else if (block.lang === "grammar-external") {
			for (const entry of parseEntries(block, path)) {
				doc.external.push({
					name: entry.name,
					id: `rule-${entry.name}`,
					line: entry.line,
					note: entry.note,
				});
			}
		} else if (block.lang === "grammar-planned") {
			for (const entry of parseEntries(block, path)) {
				if (!WORD.test(entry.name)) {
					fail(
						path,
						entry.line,
						`${entry.name} is not a word keyword; the grammar-planned block holds keywords`,
					);
				}
				doc.planned.push({ keyword: entry.name, line: entry.line, note: entry.note });
			}
		} else if (block.lang === "grammar-collected") {
			const offset = block.lines.findIndex((l) => l.trim() !== "");
			if (offset >= 0) {
				fail(
					path,
					block.line + offset,
					"the grammar-collected block is generated; leave it empty",
				);
			}
		}
	}
	check(doc, options.references ?? "check");
	return doc;
}

// ── Rendering ──────────────────────────────────────────────────────────────
// One <pre class="grammar-block"> per rule, so that a rule other rules refer to
// can carry its own links line under it; the rules of a fragment sit in a
// .grammar-fragment wrapper that closes the gap between them.

function escape(text: string): string {
	return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function spanHtml(span: Span, doc: GrammarDocument): string {
	if (span.class === "gr-plain") return escape(span.text);
	if (span.class === "gr-nonterminal") {
		const external = doc.external.some((e) => e.name === span.text);
		const cls = external ? "gr-nonterminal gr-external" : "gr-nonterminal";
		return `<a class="${cls}" href="#${span.ref}">${escape(span.text)}</a>`;
	}
	return `<span class="${span.class}">${escape(span.text)}</span>`;
}

export function renderRule(
	rule: Rule,
	doc: GrammarDocument,
	options: { collected?: boolean } = {},
): string {
	const collected = options.collected === true;
	const body = rule.lines
		.map((spans, i) =>
			spans
				.map((span, j) => {
					if (i === 0 && j === 0 && span.class === "gr-rule") {
						return collected
							? `<a class="gr-rule" href="#${rule.id}">${escape(rule.name)}</a>`
							: `<span class="gr-rule" id="${rule.id}">${escape(rule.name)}</span>`;
					}
					return spanHtml(span, doc);
				})
				.join(""),
		)
		.join("\n");
	let html = `<pre class="grammar-block"><code>${body}</code></pre>`;
	if (!collected && rule.usedBy.length > 0) {
		const links = rule.usedBy
			.map((name) => `<a href="#rule-${name}">${escape(name)}</a>`)
			.join(", ");
		html += `\n<p class="gr-links">Used by: ${links}</p>`;
	}
	return html;
}

export function renderFragment(fragment: Fragment, doc: GrammarDocument): string {
	const rules = fragment.rules.map((rule) => renderRule(rule, doc)).join("\n");
	return `<div class="grammar-fragment">\n${rules}\n</div>`;
}

export function renderCollected(doc: GrammarDocument): string {
	const rules = doc.fragments
		.flatMap((fragment) => fragment.rules)
		.map((rule) => renderRule(rule, doc, { collected: true }))
		.join("\n");
	return `<div class="grammar-fragment">\n${rules}\n</div>`;
}

function entryBlock(head: string, rows: { name: string; id?: string; note: string }[]): string {
	if (rows.length === 0) return "";
	const width = Math.max(...rows.map((row) => row.name.length));
	const body = rows
		.map((row) => {
			const name = row.id
				? `<span class="gr-rule" id="${row.id}">${escape(row.name)}</span>`
				: `<span class="gr-keyword">${escape(row.name)}</span>`;
			if (!row.note) return name;
			const pad = " ".repeat(width - row.name.length + 3);
			return `${name}${pad}<span class="gr-comment">; ${escape(row.note)}</span>`;
		})
		.join("\n");
	return (
		`<p class="gr-block-head">${head}</p>\n` +
		`<pre class="grammar-block"><code>${body}</code></pre>`
	);
}

export function renderExternal(doc: GrammarDocument): string {
	return entryBlock(
		"Defined elsewhere",
		doc.external.map((e) => ({ name: e.name, id: e.id, note: e.note })),
	);
}

export function renderPlanned(doc: GrammarDocument): string {
	return entryBlock(
		"Not lexed yet",
		doc.planned.map((p) => ({ name: p.keyword, note: p.note })),
	);
}
