#!/usr/bin/env bun
// prose-mask OUTDIR FILE…
//
// Writes OUTDIR/FILE.txt for every source FILE: a copy in which only the
// prose of its comments is left. Every other character becomes a space and
// every newline stays, so a word of a comment keeps the line and column it
// has in FILE. scripts/prose.sh runs Vale over the copies, the way it runs
// it over the copies prose_mask (packages/core/tools) writes for OCaml.
//
// The comment syntax follows the extension: // and /* */ in .ts, .astro and
// .typ, with <!-- --> as well in .astro; /* */ in .css; -- and --[[ ]] in
// .lua; # in .sh. A string literal ('…', "…", `…`, and [[…]] in Lua) hides a
// comment marker inside it. A regular expression literal does not: a // or
// /* inside one opens a comment the file never meant, and the code after it
// is read as prose until the line, or the next */, ends it. Text between the
// tags of an .astro file counts as code, and an apostrophe in it opens a
// string that the next apostrophe closes.
//
// Inside a comment the mask also covers what is not prose: the delimiters,
// the * that opens a continuation line of a block comment, `code spans`,
// URLs, tags such as <rect>, and every token shaped like code: one with a
// slash, an underscore, a dot, a digit or a camel hump inside, two or more
// capitals, a leading @, #, $ or -, or a single letter other than a and I,
// with the apostrophe suffix it carries.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, extname, join } from "node:path";

interface Syntax {
	line: string[];
	block: [string, string][];
	strings: string[];
	// A '…' or "…" string may run over several lines (shell), or ends with
	// the line (the others). A `…` string always may.
	multiline: boolean;
	longString?: [string, string];
}

const C: Syntax = { line: ["//"], block: [["/*", "*/"]], strings: ["'", '"', "`"], multiline: false };
const SYNTAX: Record<string, Syntax> = {
	".ts": C,
	".typ": C,
	".astro": { ...C, block: [["/*", "*/"], ["<!--", "-->"]] },
	".css": { line: [], block: [["/*", "*/"]], strings: ["'", '"'], multiline: false },
	".lua": { line: ["--"], block: [["--[[", "]]"]], strings: ["'", '"'], multiline: false, longString: ["[[", "]]"] },
	".sh": { line: ["#"], block: [], strings: ["'", '"'], multiline: true },
};

// The spans [start, stop) of every comment in `src`, delimiters included.
function commentSpans(src: string, syn: Syntax): [number, number][] {
	const spans: [number, number][] = [];
	const n = src.length;
	let i = 0;
	while (i < n) {
		const c = src[i]!;
		if (c === "\\") {
			i += 2;
			continue;
		}
		const block = syn.block.find(([open]) => src.startsWith(open, i));
		if (block) {
			const end = src.indexOf(block[1], i + block[0].length);
			const stop = end < 0 ? n : end + block[1].length;
			spans.push([i, stop]);
			i = stop;
			continue;
		}
		// A # opens a shell comment at the start of a line or after a space;
		// ${#x} and a # inside a word do not.
		const line = syn.line.find((open) => src.startsWith(open, i) && (open !== "#" || i === 0 || /\s/.test(src[i - 1]!)));
		if (line) {
			let end = src.indexOf("\n", i);
			if (end < 0) end = n;
			spans.push([i, end]);
			i = end;
			continue;
		}
		if (syn.longString && src.startsWith(syn.longString[0], i)) {
			const end = src.indexOf(syn.longString[1], i + syn.longString[0].length);
			i = end < 0 ? n : end + syn.longString[1].length;
			continue;
		}
		if (syn.strings.includes(c)) {
			const multiline = c === "`" || syn.multiline;
			const escapes = !(c === "'" && syn.multiline);
			let j = i + 1;
			while (j < n && src[j] !== c) {
				if (src[j] === "\n" && !multiline) break;
				if (src[j] === "\\" && escapes) j++;
				j++;
			}
			i = j + 1;
			continue;
		}
		i++;
	}
	return spans;
}

const NOT_PROSE = [
	/^[ \t]*\*(?!\/)/gm, // the * that opens a continuation line
	/`[^`\n]*`/g, // a code span
	/https?:\/\/[^\s)>]+/g, // a URL
	/<\/?[A-Za-z][^\s<>]*>/g, // a tag
	// A token shaped like code. The run of token characters is taken whole, so
	// a mask never cuts a token in two.
	/(?<![\w`'’])(?:[@#$][\w./:-]+|--?[\w-]+|(?:[\w./:-]*(?:[a-z][A-Z]|[_/]|\w\.\w|\d)[\w./:-]*|[A-Z][A-Z0-9]+|[B-HJ-Zb-hj-z])(?:['’]\w+)?)(?![\w`])/g,
];

// Marks the characters of the comment [start, stop) that are prose.
function keepProse(src: string, keep: boolean[], [start, stop]: [number, number], syn: Syntax): void {
	const text = src.slice(start, stop);
	const mask = (a: number, b: number) => keep.fill(false, start + a, start + b);
	keep.fill(true, start, stop);
	const openers = [...syn.block.map(([open]) => open), ...syn.line];
	const open = openers.find((o) => text.startsWith(o)) ?? "";
	mask(0, text.startsWith("/**") ? 3 : open.length);
	for (const [, close] of syn.block) if (text.endsWith(close)) mask(text.length - close.length, text.length);
	for (const re of NOT_PROSE) for (const m of text.matchAll(re)) mask(m.index, m.index + m[0].length);
}

// src with every character outside keep blanked. A newline stays, and a
// masked character of any width becomes one space.
function render(src: string, keep: boolean[]): string {
	let out = "";
	let i = 0;
	for (const ch of src) {
		out += keep[i] || ch === "\n" ? ch : " ";
		i += ch.length;
	}
	return out;
}

function maskFile(outdir: string, path: string): void {
	const syn = SYNTAX[extname(path)];
	if (!syn) throw new Error(`prose-mask: no comment syntax for ${path}`);
	const src = readFileSync(path, "utf8");
	const keep: boolean[] = new Array(src.length).fill(false);
	for (const span of commentSpans(src, syn)) keepProse(src, keep, span, syn);
	const target = join(outdir, `${path}.txt`);
	mkdirSync(dirname(target), { recursive: true });
	writeFileSync(target, render(src, keep));
}

const [outdir, ...files] = process.argv.slice(2);
if (!outdir || files.length === 0) {
	console.error("usage: prose-mask OUTDIR FILE...");
	process.exit(2);
}
for (const file of files) maskFile(outdir, file);
