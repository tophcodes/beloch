// Typed cross-references for spec/MODEL.md. Pandoc fenced divs
//
//   ::: {.definition #def-flat-state name="flat folded state" defines="term-table"}
//   body
//   :::
//
// become numbered statement sections with RDFa, a generated links line that
// carries both the written relations (`defines`, `uses`) and the derived ones
// (`used-by`, `defined-by`, `realized-by`), and a generated Terms glossary.
// `.term` blocks are moved out of the text into that glossary.
//
// `::: {.include api="Fold_state.violation"}` is replaced by what
// packages/core's interface says about that item: its signature, its doc
// comment, and one entry per constructor. Both directions of the realization
// relation come from the API register that scripts/api-register.ts writes; a
// statement's "Realized by" line names the kernel items whose `@see` tags point
// at it. Without the register, an `.include` block renders a placeholder and no
// statement gets a "Realized by" line.
//
// Statement classes: definition, lemma, corollary, remark, open. Numbers are
// `<section>.<n>`, counted per `##` heading and shared by all statement
// classes, so ids are what the source refers to and numbers only ever appear
// in the output. `[#some-id]` in prose becomes a link whose text is the
// computed label.
//
// A block's fences must stand on their own lines with a blank line on either
// side; a paragraph that straddles a fence is an error rather than silently
// dropped content. Blocks do not nest.
//
// scripts/model-blocks.lua is the pandoc side of the same syntax, for the PDF.
//
// Astro caches rendered content entries in node_modules/.astro; after changing
// this file, delete that directory (and .astro/) or the old output is served.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { visit } from "unist-util-visit";

const LABELS: Record<string, string> = {
	definition: "Definition",
	lemma: "Lemma",
	corollary: "Corollary",
	remark: "Remark",
	open: "Open",
};

// RDFa Lite prefix binding. It sits on every generated section instead of on a
// page-level wrapper: a remark plugin cannot reach the element Starlight wraps
// the content in, and every CURIE this plugin emits is inside a section it
// generates, so the bindings cover them all.
// The vocabulary lives under the docs site; the statements themselves are
// resources on the page (`/model/#def-…`), so the two fragment spaces stay apart.
const PREFIX = "bm: https://beloch.toph.so/ns/model#";

const OPEN_FENCE = /^:{3,}\s*\{(.*)\}\s*$/;
const CLOSE_FENCE = /^:{3,}\s*$/;
const ATTR = /([.#])([^\s"'{}]+)|([A-Za-z_][\w-]*)="([^"]*)"/g;
const SUGAR = /\[#([A-Za-z0-9_-]+)\]/g;

// astro.config.mjs sets BELOCH_REPO_ROOT in its module body, which runs after
// this module is imported, so the variable is read per document rather than
// once. A bare `bun test` runs from the package directory and passes both paths
// as options instead.
function repoRoot(): string {
	return process.env.BELOCH_REPO_ROOT ?? process.cwd();
}

type Attrs = Record<string, string>;

interface Realization {
	id: string;
}

interface ApiItem {
	path: string;
	kind: string;
	parent: string | null;
	signature: string;
	doc: string;
	realizes: Realization[];
	html: string;
}

interface Register {
	byPath: Map<string, ApiItem>;
	children: Map<string, ApiItem[]>;
	realizedBy: Map<string, ApiItem[]>;
}

// One read per path per process: the plugin runs once per file, and every file
// of a build asks the same two questions.
const registers = new Map<string, Register | null>();
const labelMaps = new Map<string, Map<string, string>>();

function register(path: string): Register | null {
	if (registers.has(path)) return registers.get(path) as Register | null;
	let index: Register | null = null;
	try {
		const items: ApiItem[] = JSON.parse(readFileSync(path, "utf8")).items;
		index = { byPath: new Map(), children: new Map(), realizedBy: new Map() };
		for (const item of items) {
			if (!index.byPath.has(item.path)) index.byPath.set(item.path, item);
			if (item.parent) push(index.children, item.parent, item);
			for (const realization of item.realizes) push(index.realizedBy, realization.id, item);
		}
	} catch {
		index = null;
	}
	registers.set(path, index);
	return index;
}

function push(map: Map<string, ApiItem[]>, key: string, item: ApiItem) {
	const list = map.get(key);
	if (list) list.push(item);
	else map.set(key, [item]);
}

// The labels a link to a model statement carries. The plugin runs per file, so
// a document that is not the model has to number the model's statements itself,
// with the same counting rule.
function labelMap(path: string): Map<string, string> {
	const cached = labelMaps.get(path);
	if (cached) return cached;
	let labels = new Map<string, string>();
	try {
		const source = readFileSync(path, "utf8");
		const lines = source.split("\n");
		const sectionStarts: number[] = [];
		lines.forEach((line, i) => {
			if (/^## /.test(line)) sectionStarts.push(i + 1);
		});
		labels = number(scanBlocks(source), sectionStarts);
	} catch {
		labels = new Map();
	}
	labelMaps.set(path, labels);
	return labels;
}

// `<section>.<n>`, counted per `##` heading and shared by all statement classes.
function number(blocks: RawBlock[], sectionStarts: number[]): Map<string, string> {
	const labels = new Map<string, string>();
	const counters: number[] = [];
	for (const block of blocks) {
		const kind = block.classes.find((c) => c in LABELS);
		if (!kind) continue;
		const section = sectionStarts.filter((line) => line < block.openLine).length;
		counters[section] = (counters[section] ?? 0) + 1;
		const n = section > 0 ? `${section}.${counters[section]}` : `${counters[section]}`;
		labels.set(block.id, `${LABELS[kind]} ${n}`);
	}
	return labels;
}

interface RawBlock {
	classes: string[];
	id: string;
	attrs: Attrs;
	openLine: number;
	closeLine: number;
	body: string;
}

interface Statement {
	id: string;
	kind: string;
	label: string;
	name: string;
	defines: string[];
	uses: string[];
	usedBy: string[];
	body: any[];
}

interface Term {
	id: string;
	name: string;
	definedBy: string;
	body: any[];
}

export default function remarkModelBlocks(
	this: any,
	options: { register?: string; model?: string } = {},
) {
	const processor = this;
	return (tree: any, file: any) => {
		const registerPath = options.register ?? join(repoRoot(), "_build", "api-register.json");
		const modelPath = options.model ?? join(repoRoot(), "spec", "MODEL.md");
		const source = String(file.value ?? "");
		if (!source.includes(":::")) return;
		const raw = scanBlocks(source).filter(
			(b) =>
				b.classes.includes("term") ||
				b.classes.includes("include") ||
				b.classes.some((c) => c in LABELS),
		);
		if (raw.length === 0) return;

		const sectionStarts: number[] = [];
		visit(tree, "heading", (node: any) => {
			if (node.depth === 2 && node.position) sectionStarts.push(node.position.start.line);
		});
		sectionStarts.sort((a, b) => a - b);

		const api = register(registerPath);
		const labels = number(raw, sectionStarts);
		// A link to a model statement is labelled from this document when this is
		// the model, and from the model document otherwise.
		const labelOf = (id: string) => labels.get(id) ?? labelMap(modelPath).get(id) ?? id;

		const statements = new Map<string, Statement>();
		const terms = new Map<string, Term>();
		const order: { block: RawBlock; id: string; kind: "statement" | "term" | "include" }[] = [];

		for (const block of raw) {
			if (block.classes.includes("include")) {
				order.push({ block, id: "", kind: "include" });
				continue;
			}
			const body = processor.parse(block.body).children;
			if (block.classes.includes("term")) {
				terms.set(block.id, {
					id: block.id,
					name: block.attrs.name ?? block.id,
					definedBy: block.attrs["defined-by"] ?? "",
					body,
				});
				order.push({ block, id: block.id, kind: "term" });
				continue;
			}
			statements.set(block.id, {
				id: block.id,
				kind: block.classes.find((c) => c in LABELS) as string,
				label: labels.get(block.id) as string,
				name: block.attrs.name ?? "",
				defines: ids(block.attrs.defines),
				uses: ids(block.attrs.uses),
				usedBy: [],
				body,
			});
			order.push({ block, id: block.id, kind: "statement" });
		}

		link(statements, terms);

		const nodes = new Map<string, any>();
		for (const s of statements.values()) {
			nodes.set(s.id, statementNode(s, terms, statements, api?.realizedBy.get(s.id) ?? []));
		}
		for (const t of terms.values()) nodes.set(t.id, termNode(t, statements));

		// Splice back to front so earlier indices stay valid. Terms leave nothing
		// behind; they are re-emitted in the glossary.
		for (const entry of [...order].reverse()) {
			const replacement =
				entry.kind === "term"
					? []
					: entry.kind === "include"
						? [includeNode(processor, api, entry.block.attrs.api ?? "", labelOf)]
						: [nodes.get(entry.id)];
			replaceRange(tree, entry.block, replacement);
		}

		placeGlossary(
			tree,
			[...terms.values()]
				.sort((a, b) => a.name.localeCompare(b.name))
				.map((t) => nodes.get(t.id)),
		);

		expandSugar(tree, statements, terms);
	};
}

function scanBlocks(source: string): RawBlock[] {
	const lines = source.split("\n");
	const blocks: RawBlock[] = [];
	for (let i = 0; i < lines.length; i++) {
		const open = OPEN_FENCE.exec(lines[i]);
		if (!open) continue;
		let j = i + 1;
		while (j < lines.length && !CLOSE_FENCE.test(lines[j])) j++;
		if (j >= lines.length) break; // unterminated fence: leave the source alone
		const { classes, id, attrs } = parseAttrs(open[1]);
		blocks.push({
			classes,
			id,
			attrs,
			openLine: i + 1,
			closeLine: j + 1,
			body: lines.slice(i + 1, j).join("\n"),
		});
		i = j;
	}
	return blocks;
}

function parseAttrs(text: string): { classes: string[]; id: string; attrs: Attrs } {
	const classes: string[] = [];
	const attrs: Attrs = {};
	let id = "";
	let m: RegExpExecArray | null;
	ATTR.lastIndex = 0;
	while ((m = ATTR.exec(text))) {
		if (m[1] === ".") classes.push(m[2]);
		else if (m[1] === "#") id = m[2];
		else attrs[m[3]] = m[4];
	}
	return { classes, id, attrs };
}

function ids(value: string | undefined): string[] {
	return value ? value.trim().split(/\s+/).filter(Boolean) : [];
}

// Resolve the written relations and derive their reverses.
function link(statements: Map<string, Statement>, terms: Map<string, Term>) {
	for (const s of statements.values()) {
		// `defines="table"` is accepted as shorthand for `defines="term-table"`.
		s.defines = s.defines
			.map((entry) => (terms.has(entry) ? entry : `term-${entry}`))
			.filter((id) => terms.has(id));
		for (const id of s.defines) (terms.get(id) as Term).definedBy = s.id;
		for (const id of s.uses) statements.get(id)?.usedBy.push(s.id);
	}
	for (const t of terms.values()) {
		const owner = statements.get(t.definedBy);
		if (owner && !owner.defines.includes(t.id)) owner.defines.push(t.id);
	}
}

function statementNode(
	s: Statement,
	terms: Map<string, Term>,
	statements: Map<string, Statement>,
	realizedBy: ApiItem[],
): any {
	const head: any[] = [el("span", { className: ["stmt-label"], property: "bm:label" }, [text(s.label)])];
	if (s.name) {
		head.push(text(" "));
		head.push(el("span", { className: ["stmt-name"], property: "bm:name" }, [text(s.name)]));
	}

	const groups: any[][] = [];
	if (s.defines.length) {
		groups.push([
			text("Defines: "),
			...series(s.defines.map((id) => anchor("bm:defines", id, (terms.get(id) as Term).name))),
		]);
	}
	if (s.uses.length) {
		groups.push([
			text("Uses: "),
			...series(s.uses.map((id) => anchor("bm:uses", id, statements.get(id)?.label ?? id))),
		]);
	}
	if (s.usedBy.length) {
		groups.push([
			text("Used by: "),
			...series(s.usedBy.map((id) => anchor("bm:usedBy", id, statements.get(id)?.label ?? id))),
		]);
	}
	if (realizedBy.length) {
		groups.push([
			text("Realized by: "),
			...series(
				realizedBy.map((item) =>
					el("a", { rel: "bm:realizedBy", href: item.html }, [
						el("code", {}, [text(item.path)]),
					]),
				),
			),
		]);
	}

	const children = [para("stmt-head", head), ...s.body];
	if (groups.length) children.push(para("stmt-links", separated(groups)));

	return el(
		"section",
		{
			className: ["stmt", `stmt-${s.kind}`],
			id: s.id,
			typeof: `bm:${LABELS[s.kind]}`,
			resource: `#${s.id}`,
			prefix: PREFIX,
		},
		children,
	);
}

function termNode(t: Term, statements: Map<string, Statement>): any {
	const children = [
		para("term-head", [el("span", { className: ["term-name"], property: "bm:name" }, [text(t.name)])]),
		...t.body,
	];
	const owner = statements.get(t.definedBy);
	if (owner) {
		children.push(
			para("term-links", [text("Defined in "), anchor("bm:definedBy", owner.id, owner.label)]),
		);
	}
	return el(
		"section",
		{
			className: ["term"],
			id: t.id,
			typeof: "bm:Term",
			resource: `#${t.id}`,
			prefix: PREFIX,
		},
		children,
	);
}

// Drop the root children the block covers and put `replacement` in their place.
function replaceRange(tree: any, block: RawBlock, replacement: any[]) {
	let first = -1;
	let last = -1;
	tree.children.forEach((child: any, index: number) => {
		const p = child.position;
		if (!p || p.end.line < block.openLine || p.start.line > block.closeLine) return;
		if (p.start.line < block.openLine || p.end.line > block.closeLine) {
			throw new Error(
				`model block #${block.id} (line ${block.openLine}) shares a paragraph with the ` +
					`text around it; put a blank line before ::: and after the closing :::`,
			);
		}
		if (first < 0) first = index;
		last = index;
	});
	if (first < 0) return;
	tree.children.splice(first, last - first + 1, ...replacement);
}

// The glossary goes at the end of the `## Terms` section. Without such a
// heading one is created, before `## References` if the document has it.
function placeGlossary(tree: any, entries: any[]) {
	if (entries.length === 0) return;
	const kids = tree.children;
	const terms = headingIndex(kids, "Terms");
	if (terms >= 0) {
		kids.splice(sectionEnd(kids, terms), 0, ...entries);
		return;
	}
	const refs = headingIndex(kids, "References");
	const at = refs >= 0 ? refs : kids.length;
	kids.splice(at, 0, { type: "heading", depth: 2, children: [text("Terms")] }, ...entries);
}

function headingIndex(children: any[], title: string): number {
	return children.findIndex(
		(c: any) => c.type === "heading" && c.depth === 2 && plain(c) === title,
	);
}

function sectionEnd(children: any[], start: number): number {
	for (let i = start + 1; i < children.length; i++) {
		if (children[i].type === "heading" && children[i].depth <= 2) return i;
	}
	return children.length;
}

// `[#def-flat-state]` in prose renders as a link carrying the computed label.
function expandSugar(tree: any, statements: Map<string, Statement>, terms: Map<string, Term>) {
	visit(tree, "text", (node: any, index: number | undefined, parent: any) => {
		if (!parent || index === undefined || !node.value.includes("[#")) return;
		const parts: any[] = [];
		let last = 0;
		let m: RegExpExecArray | null;
		SUGAR.lastIndex = 0;
		while ((m = SUGAR.exec(node.value))) {
			const label = statements.get(m[1])?.label ?? terms.get(m[1])?.name;
			if (!label) continue;
			if (m.index > last) parts.push(text(node.value.slice(last, m.index)));
			parts.push(el("a", { href: `#${m[1]}` }, [text(label)]));
			last = m.index + m[0].length;
		}
		if (parts.length === 0) return;
		if (last < node.value.length) parts.push(text(node.value.slice(last)));
		parent.children.splice(index, 1, ...parts);
		return index + parts.length;
	});
}

// An `.include` block: the register's entry for the item, with the signature in
// a code block, the doc comment, and one entry per constructor or field.
function includeNode(
	processor: any,
	api: Register | null,
	path: string,
	labelOf: (id: string) => string,
): any {
	const item = api?.byPath.get(path);
	if (!item) {
		return para("api-missing", [
			text("No API register entry for "),
			el("code", {}, [text(path)]),
			text("; run scripts/api-register.ts."),
		]);
	}
	const children = [
		{ type: "code", lang: "ocaml", value: item.signature },
		...processor.parse(item.doc).children,
	];
	const realizes = realizesLine(item, labelOf);
	if (realizes) children.push(realizes);
	for (const member of api?.children.get(path) ?? []) {
		children.push(memberNode(processor, member, labelOf));
	}
	return el(
		"div",
		{ className: ["api-item"], about: item.html, typeof: "bm:CodeItem", prefix: PREFIX },
		children,
	);
}

function memberNode(processor: any, item: ApiItem, labelOf: (id: string) => string): any {
	const children = [
		para("api-member-head", [el("code", {}, [text(item.signature)])]),
		...processor.parse(item.doc).children,
	];
	const realizes = realizesLine(item, labelOf);
	if (realizes) children.push(realizes);
	return el(
		"div",
		{ className: ["api-member"], about: item.html, typeof: "bm:CodeItem" },
		children,
	);
}

function realizesLine(item: ApiItem, labelOf: (id: string) => string): any | null {
	if (item.realizes.length === 0) return null;
	return para("api-realizes", [
		text("Realizes: "),
		...series(
			item.realizes.map((r) =>
				el("a", { rel: "bm:realizes", href: `/model/#${r.id}` }, [text(labelOf(r.id))]),
			),
		),
	]);
}

function el(tagName: string, properties: Record<string, unknown>, children: any[]) {
	return { type: "modelElement", data: { hName: tagName, hProperties: properties }, children };
}

function para(className: string, children: any[]) {
	return { type: "paragraph", data: { hProperties: { className: [className] } }, children };
}

function anchor(rel: string, id: string, label: string) {
	return el("a", { rel, href: `#${id}` }, [text(label)]);
}

function text(value: string) {
	return { type: "text", value };
}

function series(links: any[]): any[] {
	return links.flatMap((node, i) => (i === 0 ? [node] : [text(", "), node]));
}

function separated(groups: any[][]): any[] {
	return groups.flatMap((group, i) => (i === 0 ? group : [text(" · "), ...group]));
}

function plain(node: any): string {
	if (node.type === "text") return node.value;
	return (node.children ?? []).map(plain).join("");
}
