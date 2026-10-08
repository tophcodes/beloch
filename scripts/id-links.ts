// The id links between documents (ADR 0054). A link `[[kind/stem]]`,
// `[[kind/stem#anchor]]` or `[[kind/stem|text]]` names a document under
// docs/ by the directory it lives in and its file stem, case-folded; a
// decision's stem is its number. In a table cell the pipe before the text is
// escaped, `[[kind/stem\|text]]`, so the table keeps its columns. The index
// built here maps every document to the page the site serves it on, or to
// its file on GitHub when the site does not serve it, and lists the anchors
// it exposes: its headings, with the slug the site gives them, and the ids
// of its fenced blocks (`::: {.definition #id …}`).
//
// `bun scripts/id-links.ts` writes the index to _build/id-links.json for
// scripts/id-links.lua, which resolves the links in the PDFs;
// packages/www/src/lib/remark-id-links.ts builds the index in process.
// `bun scripts/id-links.ts --check` reports every link under docs/ that
// names no document or no anchor, with file and line, and exits 1 on the
// first.

import { lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { dirname, join, relative, sep } from "node:path";

export const SITE = "https://belochlang.org";
export const REPOSITORY = "https://github.com/tophcodes/beloch/blob/main";

export type Document = {
	id: string;
	path: string;
	title: string;
	/** The page's path on the site, such as `/language/writes/`; null when the site does not serve the document. */
	site: string | null;
	/** Label per anchor: the heading's text, or the block's name or caption. */
	anchors: Record<string, string>;
};

export type Index = {
	/** The site's origin and the repository's blob URL, so a reader of the file needs no second source for them. */
	site: string;
	repository: string;
	documents: Record<string, Document>;
};

export const LINK_PATTERN = /\[\[([^\]|\\]+)(?:\\?\|([^\]]*))?\]\]/g;

export type Link = { raw: string; target: string; text: string | null; line: number };

export type Resolved = { url: string; text: string; document: Document; anchor: string | null };

const DOCS = "docs";
const CONTENT = join("packages", "www", "src", "content", "docs");

// Files the check does not read: SPECIFICATION.md is being dissolved (ADR
// 0032) and carries citation keys in double brackets.
const UNCHECKED = new Set([join(DOCS, "reference", "SPECIFICATION.md")]);

function walk(dir: string): string[] {
	const out: string[] = [];
	for (const entry of readdirSync(dir, { withFileTypes: true })) {
		const path = join(dir, entry.name);
		if (entry.isDirectory()) out.push(...walk(path));
		else if (entry.name.endsWith(".md")) out.push(path);
	}
	return out.sort();
}

// The slug Astro gives a heading (github-slugger): lower case, punctuation
// dropped, whitespace to hyphens, a repeated slug numbered from -1.
export function slug(text: string, seen: Map<string, number>): string {
	const base = text
		.toLowerCase()
		.replace(/[^\p{L}\p{N}\s_-]/gu, "")
		.replace(/\s/g, "-");
	const n = seen.get(base) ?? 0;
	seen.set(base, n + 1);
	return n === 0 ? base : `${base}-${n}`;
}

// A heading's text without its inline markup: code spans, links, emphasis.
function plain(text: string): string {
	return text
		.replace(/`([^`]*)`/g, "$1")
		.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
		.replace(/[*_]/g, "")
		.trim();
}

function frontmatterTitle(lines: string[]): string | null {
	if (lines[0] !== "---") return null;
	for (let i = 1; i < lines.length && lines[i] !== "---"; i++) {
		const m = /^title:\s*(.*)$/.exec(lines[i]!);
		if (m) return m[1]!.replace(/^["'](.*)["']$/, "$1").trim();
	}
	return null;
}

export function idOf(path: string): string {
	const rel = relative(DOCS, path).split(sep);
	const kind = rel[0]!;
	const stem = rel[rel.length - 1]!.replace(/\.md$/, "");
	if (kind === "decision") {
		const m = /^(\d{4})/.exec(stem);
		if (m) return `${kind}/${m[1]}`;
	}
	return `${kind}/${stem.toLowerCase()}`;
}

// The page of the site each document is: the content directory links the
// documents, and a link's path under it is the page's path.
function sitePaths(root: string): Map<string, string> {
	const out = new Map<string, string>();
	const dir = join(root, CONTENT);
	for (const path of walk(dir)) {
		if (!lstatSync(path).isSymbolicLink()) continue;
		let real: string;
		try {
			real = realpathSync(path);
		} catch {
			continue;
		}
		const page = relative(dir, path).replace(/\.md$/, "").split(sep).join("/");
		out.set(relative(root, real), `/${page}/`);
	}
	return out;
}

export function indexDocument(source: string, path: string, site: string | null): Document {
	const lines = source.split("\n");
	const anchors: Record<string, string> = {};
	const seen = new Map<string, number>();
	let title = frontmatterTitle(lines);
	let fence: string | null = null;
	let inFrontmatter = lines[0] === "---";
	for (let i = inFrontmatter ? 1 : 0; i < lines.length; i++) {
		const line = lines[i]!;
		if (inFrontmatter) {
			if (line === "---") inFrontmatter = false;
			continue;
		}
		const f = /^(`{3,}|~{3,})/.exec(line);
		if (f) {
			if (fence === null) fence = f[1]!;
			else if (line.startsWith(fence)) fence = null;
			continue;
		}
		if (fence !== null) continue;
		const h = /^#{1,6}\s+(.*?)\s*#*\s*$/.exec(line);
		if (h) {
			const text = plain(h[1]!);
			anchors[slug(text, seen)] = text;
			if (title === null) title = text;
			continue;
		}
		const b = /^:::\s*\{([^}]*)\}/.exec(line);
		if (b) {
			const attrs = b[1]!;
			const id = /#([A-Za-z0-9_.-]+)/.exec(attrs)?.[1];
			if (!id) continue;
			const label = /\b(?:name|caption)="([^"]*)"/.exec(attrs)?.[1];
			anchors[id] = label ? plain(label) : id;
		}
	}
	const id = idOf(path);
	return { id, path, title: title ?? id, site, anchors };
}

export function buildIndex(root: string): Index {
	const pages = sitePaths(root);
	const documents: Record<string, Document> = {};
	for (const abs of walk(join(root, DOCS))) {
		const path = relative(root, abs);
		const doc = indexDocument(readFileSync(abs, "utf8"), path, pages.get(path) ?? null);
		const other = documents[doc.id];
		if (other) throw new Error(`two documents share the id ${doc.id}: ${other.path} and ${path}`);
		documents[doc.id] = doc;
	}
	return { site: SITE, repository: REPOSITORY, documents };
}

// A line with its code spans blanked: a run of n backticks opens a span that
// the next run of exactly n backticks closes, as CommonMark reads them.
export function maskCode(line: string): string {
	let out = "";
	let i = 0;
	while (i < line.length) {
		if (line[i] !== "`") {
			out += line[i];
			i++;
			continue;
		}
		let n = 0;
		while (line[i + n] === "`") n++;
		const open = "`".repeat(n);
		let j = i + n;
		let close = -1;
		while (j < line.length) {
			const k = line.indexOf(open, j);
			if (k < 0) break;
			let m = 0;
			while (line[k + m] === "`") m++;
			if (m === n) {
				close = k;
				break;
			}
			j = k + m;
		}
		if (close < 0) {
			out += open;
			i += n;
			continue;
		}
		out += " ".repeat(close + n - i);
		i = close + n;
	}
	return out;
}

// Every link in a document with its line, outside fenced and inline code.
export function findLinks(source: string): Link[] {
	const out: Link[] = [];
	let fence: string | null = null;
	source.split("\n").forEach((line, i) => {
		const f = /^(`{3,}|~{3,})/.exec(line);
		if (f) {
			if (fence === null) fence = f[1]!;
			else if (line.startsWith(fence)) fence = null;
			return;
		}
		if (fence !== null) return;
		const prose = maskCode(line);
		for (const m of prose.matchAll(LINK_PATTERN)) {
			out.push({ raw: m[0], target: m[1]!.trim(), text: m[2]?.trim() ?? null, line: i + 1 });
		}
	});
	return out;
}

export function parseTarget(target: string): { id: string; anchor: string | null } | null {
	const m = /^([a-z]+)\/([^#\s]+)(?:#(\S+))?$/i.exec(target);
	if (!m) return null;
	return { id: `${m[1]!.toLowerCase()}/${m[2]!.toLowerCase()}`, anchor: m[3] ?? null };
}

export function defaultText(document: Document, anchor: string | null): string {
	if (anchor !== null) return document.anchors[anchor] ?? anchor;
	const d = /^decision\/(\d{4})$/.exec(document.id);
	if (d) return `ADR ${d[1]}`;
	return document.title;
}

export function resolve(index: Index, link: Pick<Link, "target" | "text">): Resolved | { error: string } {
	const parsed = parseTarget(link.target);
	if (!parsed) return { error: `[[${link.target}]] is no id; a link names kind/stem, with #anchor after it` };
	const document = index.documents[parsed.id];
	if (!document) return { error: `[[${link.target}]] names no document; there is no ${parsed.id} under docs/` };
	if (parsed.anchor !== null && !(parsed.anchor in document.anchors)) {
		return { error: `[[${link.target}]] names no anchor; ${document.path} has no #${parsed.anchor}` };
	}
	const base = document.site ?? `${REPOSITORY}/${document.path}`;
	const url = parsed.anchor !== null ? `${base}#${parsed.anchor}` : base;
	return { url, text: link.text ?? defaultText(document, parsed.anchor), document, anchor: parsed.anchor };
}

export type Finding = { path: string; line: number; raw: string; error: string };

export function checkDocuments(root: string, index = buildIndex(root)): Finding[] {
	const findings: Finding[] = [];
	for (const abs of walk(join(root, DOCS))) {
		const path = relative(root, abs);
		if (UNCHECKED.has(path)) continue;
		for (const link of findLinks(readFileSync(abs, "utf8"))) {
			const r = resolve(index, link);
			if ("error" in r) findings.push({ path, line: link.line, raw: link.raw, error: r.error });
		}
	}
	return findings;
}

if (import.meta.main) {
	const root = join(import.meta.dir, "..");
	const args = process.argv.slice(2);
	const index = buildIndex(root);
	if (args.includes("--check")) {
		const findings = checkDocuments(root, index);
		for (const f of findings) console.error(`${f.path}:${f.line}: ${f.error}`);
		if (findings.length > 0) {
			console.error(`${findings.length} id link(s) resolve to nothing`);
			process.exit(1);
		}
		console.log(`every id link under docs/ resolves (${Object.keys(index.documents).length} documents)`);
	} else {
		const flag = args.indexOf("--out");
		const out = flag >= 0 ? args[flag + 1]! : join(root, "_build", "id-links.json");
		mkdirSync(dirname(out), { recursive: true });
		writeFileSync(out, `${JSON.stringify(index, null, "\t")}\n`);
		console.log(out);
	}
}
