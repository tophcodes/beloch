#!/usr/bin/env bun
// The API register: what packages/core's interfaces say about themselves.
//
// Scans packages/core/lib/*.mli and writes one entry per documented item
// (types, their constructors and record fields, and values). An entry carries
// the signature as written, the doc comment as markdown, the `@see <url>`
// targets that say which model statement the item realizes, and the odoc page
// the item is documented on (scripts/build-api-docs.sh publishes that HTML
// under /api/).
//
// The register is what `::: {.include api="Fold_state.t"}` blocks in spec/ are
// replaced by, on both renderers (packages/www/src/lib/remark-model-blocks.ts,
// scripts/model-blocks.lua), and what gives the model page its "Realized by"
// lines.
//
//   bun scripts/api-register.ts [--out <path>]

import { readdirSync, readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join, dirname, basename } from "node:path";

export interface Realization {
	/** The `@see` target as written. */
	url: string;
	/** Its fragment: the id of the model statement. */
	id: string;
	/** The prose after the target. */
	text: string;
}

export interface ApiItem {
	/** `Fold_state.make`, `Fold_state.violation.Taco_taco`. */
	path: string;
	kind: "type" | "value" | "constructor" | "field";
	name: string;
	/** The item this one belongs to, for constructors and fields. */
	parent: string | null;
	/** The declaration as written, doc comments removed. */
	signature: string;
	/** The doc comment as markdown, `@see` lines removed. */
	doc: string;
	realizes: Realization[];
	/** Path of the odoc page and anchor, as the docs site serves it. */
	html: string;
}

export interface ApiRegister {
	items: ApiItem[];
}

/** Where scripts/build-api-docs.sh puts the odoc HTML. */
const HTML_ROOT = "/api/beloch/Beloch";

interface Comment {
	start: number;
	end: number;
	text: string;
}

// Doc comments only; `(* … *)` is skipped but still consumed, so a `(**` inside
// one is never mistaken for the start of a doc comment.
function scanComments(source: string): Comment[] {
	const out: Comment[] = [];
	for (let i = 0; i < source.length; i++) {
		if (!source.startsWith("(*", i)) continue;
		const doc = source.startsWith("(**", i) && !source.startsWith("(**)", i);
		let depth = 1;
		let j = i + 2;
		while (j < source.length && depth > 0) {
			if (source.startsWith("(*", j)) {
				depth++;
				j += 2;
			} else if (source.startsWith("*)", j)) {
				depth--;
				j += 2;
			} else j++;
		}
		if (doc) out.push({ start: i, end: j, text: source.slice(i + 3, j - 2) });
		i = j - 1;
	}
	return out;
}

/** The source with every comment blanked out, offsets and lines preserved. */
function blankComments(source: string): string {
	const chars = [...source];
	for (let i = 0; i < source.length; i++) {
		if (!source.startsWith("(*", i)) continue;
		let depth = 1;
		let j = i + 2;
		while (j < source.length && depth > 0) {
			if (source.startsWith("(*", j)) {
				depth++;
				j += 2;
			} else if (source.startsWith("*)", j)) {
				depth--;
				j += 2;
			} else j++;
		}
		for (let k = i; k < j; k++) if (chars[k] !== "\n") chars[k] = " ";
		i = j - 1;
	}
	return chars.join("");
}

const DECL = /^(type|val|exception|external|module)\s/;

interface Decl {
	keyword: string;
	name: string;
	start: number;
	end: number;
}

function scanDecls(code: string): Decl[] {
	const decls: Decl[] = [];
	let offset = 0;
	for (const line of code.split("\n")) {
		const m = DECL.exec(line);
		if (m) {
			const rest = line.slice(m[0].length).trim();
			const name = /^[A-Za-z_'][A-Za-z0-9_']*/.exec(rest)?.[0] ?? "";
			if (name) decls.push({ keyword: m[1], name, start: offset, end: code.length });
		}
		offset += line.length + 1;
	}
	for (let i = 0; i + 1 < decls.length; i++) decls[i].end = decls[i + 1].start;
	return decls;
}

/** A gap that stays inside one line break: an adjacent doc comment, not a floating one. */
function adjacent(gap: string): boolean {
	return gap.trim() === "" && (gap.match(/\n/g) ?? []).length <= 1;
}

/** `{1 Heading}` comments introduce a section; they document no item. */
function isHeading(text: string): boolean {
	return /^\s*\{[0-9]\s/.test(text);
}

const SEE = /^\s*@see\s+<([^>]*)>\s*(.*)$/;

export function convertDoc(raw: string): { doc: string; realizes: Realization[] } {
	const body: string[] = [];
	const realizes: Realization[] = [];
	let see: Realization | null = null;
	let seeIndent = 0;
	for (const line of raw.split("\n")) {
		const m = SEE.exec(line);
		if (m) {
			see = { url: m[1], id: m[1].split("#")[1] ?? "", text: m[2].trim() };
			seeIndent = indentOf(line);
			realizes.push(see);
			continue;
		}
		// A tag's text continues on the lines indented under it.
		if (see && line.trim() !== "" && indentOf(line) > seeIndent) {
			see.text = `${see.text} ${line.trim()}`.trim();
			continue;
		}
		see = null;
		body.push(line);
	}
	return { doc: markup(dedent(body.join("\n"))).trim(), realizes };
}

function indentOf(line: string): number {
	return (/^\s*/.exec(line) as RegExpExecArray)[0].length;
}

/** Drop the common indentation the comment's continuation lines carry. */
function dedent(raw: string): string {
	const lines = raw.replace(/\s+$/, "").split("\n");
	const widths = lines
		.slice(1)
		.filter((l) => l.trim() !== "")
		.map((l) => (/^\s*/.exec(l) as RegExpExecArray)[0].length);
	const indent = widths.length ? Math.min(...widths) : 0;
	return [lines[0].replace(/^\s+/, ""), ...lines.slice(1).map((l) => l.slice(indent))].join("\n");
}

/** odoc markup, for the shapes packages/core uses. */
function markup(text: string): string {
	return text
		.replace(/\{!(?:[a-z]+:)?([^}]+)\}/g, (_, target: string) => "`" + target.trim() + "`")
		.replace(/\{b\s+([^}]*)\}/g, "**$1**")
		.replace(/\{i\s+([^}]*)\}/g, "*$1*")
		.replace(/\[([^\]]*)\]/g, (_, code: string) => "`" + code + "`");
}

export function parseMli(source: string, module: string): ApiItem[] {
	const code = blankComments(source);
	const comments = scanComments(source);
	const decls = scanDecls(code);
	const items: ApiItem[] = [];
	const claimed = new Set<Comment>();

	// Members go first: a constructor's or field's comment is the one nearest
	// under it, and the declaration's own comment is whatever is left over.
	const members = new Map<Decl, Member[]>();
	for (const decl of decls) {
		if (decl.keyword === "type") members.set(decl, scanMembers(code, decl, comments, claimed));
	}

	// Pass 1: the doc comment that sits directly under a declaration.
	const own = new Map<Decl, Comment>();
	for (const decl of decls) {
		const lastCode = lastNonSpace(code, decl.start, decl.end);
		const trailing = comments.find(
			(c) => c.start > lastCode && c.start < decl.end && !claimed.has(c),
		);
		if (trailing && adjacent(source.slice(lastCode + 1, trailing.start)) && !isHeading(trailing.text)) {
			own.set(decl, trailing);
			claimed.add(trailing);
		}
	}
	// Pass 2: the comment that sits directly above one, where there is no other.
	for (const decl of decls) {
		if (own.has(decl)) continue;
		const before = [...comments].reverse().find((c) => c.end <= decl.start);
		if (!before || claimed.has(before) || isHeading(before.text)) continue;
		if (!adjacent(source.slice(before.end, decl.start))) continue;
		own.set(decl, before);
		claimed.add(before);
	}

	for (const decl of decls) {
		if (decl.keyword !== "type" && decl.keyword !== "val") continue;
		const kind = decl.keyword === "type" ? "type" : "value";
		const path = `${module}.${decl.name}`;
		const anchor = kind === "type" ? `type-${decl.name}` : `val-${decl.name}`;
		const members_ = members.get(decl) ?? [];
		const doc = own.get(decl);
		if (!doc && members_.length === 0) continue;
		const converted = doc ? convertDoc(doc.text) : { doc: "", realizes: [] };
		items.push({
			path,
			kind,
			name: decl.name,
			parent: null,
			signature: signatureOf(code, decl),
			doc: converted.doc,
			realizes: converted.realizes,
			html: `${HTML_ROOT}/${module}/index.html#${anchor}`,
		});
		for (const member of members_) {
			const converted = convertDoc(member.comment.text);
			items.push({
				path: `${path}.${member.name}`,
				kind: member.kind,
				name: member.name,
				parent: path,
				signature: member.signature,
				doc: converted.doc,
				realizes: converted.realizes,
				html: `${HTML_ROOT}/${module}/index.html#type-${decl.name}.${member.name}`,
			});
		}
	}
	return items;
}

interface Member {
	kind: "constructor" | "field";
	name: string;
	signature: string;
	comment: Comment;
}

const CONSTRUCTOR = /^\s*\|\s*([A-Z][A-Za-z0-9_']*)/;
const FIELD = /^\s*([a-z_][A-Za-z0-9_']*)\s*:/;

// Constructors of a variant type, fields of a record type: a member owns the
// comments that follow it up to the next member.
function scanMembers(
	code: string,
	decl: Decl,
	comments: Comment[],
	claimed: Set<Comment>,
): Member[] {
	const body = code.slice(decl.start, decl.end);
	const record = /=\s*\{/.test(body.split("\n")[0]) || /^\s*\{/.test(body.split("\n")[1] ?? "");
	// A record's fields and their comments live between the braces; what follows
	// the closing brace is the type's own doc comment.
	const limit = record ? recordEnd(code, decl) : decl.end;
	const starts: { kind: "constructor" | "field"; name: string; at: number; line: string }[] = [];
	let offset = decl.start;
	for (const line of code.slice(decl.start, limit).split("\n")) {
		const ctor = CONSTRUCTOR.exec(line);
		const field = record ? FIELD.exec(line) : null;
		if (ctor) starts.push({ kind: "constructor", name: ctor[1], at: offset, line });
		else if (field) starts.push({ kind: "field", name: field[1], at: offset, line });
		offset += line.length + 1;
	}
	const members: Member[] = [];
	for (let i = 0; i < starts.length; i++) {
		const from = starts[i].at;
		const to = i + 1 < starts.length ? starts[i + 1].at : limit;
		const comment = comments.find((c) => c.start >= from && c.start < to && !claimed.has(c));
		if (!comment) continue;
		claimed.add(comment);
		members.push({
			kind: starts[i].kind,
			name: starts[i].name,
			signature: starts[i].line.trim().replace(/[;,]\s*$/, ""),
			comment,
		});
	}
	return members;
}

/** Offset of the brace that closes the record body. */
function recordEnd(code: string, decl: Decl): number {
	const open = code.indexOf("{", decl.start);
	if (open < 0 || open >= decl.end) return decl.end;
	let depth = 0;
	for (let i = open; i < decl.end; i++) {
		if (code[i] === "{") depth++;
		else if (code[i] === "}" && --depth === 0) return i + 1;
	}
	return decl.end;
}

function lastNonSpace(code: string, from: number, to: number): number {
	for (let i = to - 1; i >= from; i--) if (!/\s/.test(code[i])) return i;
	return from;
}

/** The declaration with its comments gone and its blank lines closed up. */
function signatureOf(code: string, decl: Decl): string {
	return code
		.slice(decl.start, decl.end)
		.split("\n")
		.map((line) => line.replace(/\s+$/, ""))
		.filter((line) => line !== "")
		.join("\n")
		.trim();
}

export function buildRegister(libDir: string): ApiRegister {
	const items: ApiItem[] = [];
	for (const file of readdirSync(libDir).sort()) {
		if (!file.endsWith(".mli")) continue;
		const base = basename(file, ".mli");
		const module = base.charAt(0).toUpperCase() + base.slice(1);
		items.push(...parseMli(readFileSync(join(libDir, file), "utf8"), module));
	}
	return { items };
}

if (import.meta.main) {
	const root = join(import.meta.dir, "..");
	const flag = process.argv.indexOf("--out");
	const out = flag >= 0 ? process.argv[flag + 1] : join(root, "_build", "api-register.json");
	const register = buildRegister(join(root, "packages", "core", "lib"));
	mkdirSync(dirname(out), { recursive: true });
	writeFileSync(out, `${JSON.stringify(register, null, 2)}\n`);
	console.log(`${out} (${register.items.length} items)`);
}
