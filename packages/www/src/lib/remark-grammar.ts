// Grammar fragments of spec/BELOCH.md. `grammar`, `grammar-external`,
// `grammar-planned` and `grammar-collected` fenced blocks become raw HTML:
// every rule gets an id, every nonterminal on a right-hand side gets a link to
// its rule, every rule other rules refer to gets a "Used by" line, and the
// empty `grammar-collected` marker expands to every rule of the page in order
// of definition.
//
// The parse comes from ./grammar-notation.ts rather than from
// _build/grammar.json: `astro dev` has to work before any script has run, and a
// reference to a name no rule of the page defines has to fail in every build.
// scripts/grammar-blocks.lua is the pandoc side of the same blocks, reading the
// register that scripts/grammar-register.ts writes from the same parser.
//
// The node is mutated in place, keeping `position`, so the range splicing in
// remark-model-blocks.ts still lines up. A raw `html` node is invisible to
// Expressive Code, so the emitted markup survives as written.
//
// Astro caches rendered content entries in node_modules/.astro; after changing
// this file, delete that directory (and .astro/) or the old output is served.
import { visit } from "unist-util-visit";
import {
	GrammarError,
	parseDocument,
	renderCollected,
	renderExternal,
	renderFragment,
	renderPlanned,
} from "./grammar-notation.ts";

const LANGS = new Set(["grammar", "grammar-external", "grammar-planned", "grammar-collected"]);

export default function remarkGrammar() {
	return (tree: any, file: any) => {
		const source = String(file.value ?? "");
		if (!source.includes("```grammar")) return;
		const path = file.path ?? file.basename ?? "<document>";
		const doc = parseDocument(source, path);
		const targets: any[] = [];
		visit(tree, "code", (node: any) => {
			if (node.lang && LANGS.has(node.lang)) targets.push(node);
		});
		for (const node of targets) {
			let html: string;
			if (node.lang === "grammar") {
				// A fragment is paired to its fence's code node by the line on
				// which the fence opens. An indented fence, or one quoted as a
				// sample inside a wider fence, is invisible to the raw scan in
				// grammar-notation.ts even though remark still parses it as a
				// code node; that mismatch fails with the error below instead
				// of shifting every later block's pairing.
				const line = node.position.start.line + 1;
				const fragment = doc.fragments.find((f) => f.line === line);
				if (!fragment) {
					throw new GrammarError(
						`${path}:${line}: no grammar fragment parses at this \`grammar\` fence`,
					);
				}
				html = renderFragment(fragment, doc);
			} else if (node.lang === "grammar-external") html = renderExternal(doc);
			else if (node.lang === "grammar-planned") html = renderPlanned(doc);
			else html = renderCollected(doc);
			node.type = "html";
			node.value = html;
			delete node.lang;
			delete node.meta;
		}
	};
}
