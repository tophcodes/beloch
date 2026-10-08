// The id links of ADR 0054 on the site: `[[decision/0032]]`,
// `[[reference/model#def-sheet]]` and `[[guide/first-folds|the guide]]` in
// prose become links. The index of documents and anchors is built from the
// checkout once per process by scripts/id-links.ts, which also carries the
// check that every link resolves; a link that resolves to nothing fails the
// build here, naming the file and the target.
//
// remark-model-blocks parses the bodies of its blocks apart from the page,
// so it calls `linkIds` on them itself.

import { visit } from "unist-util-visit";
import {
	buildIndex,
	LINK_PATTERN,
	resolve,
	type Index,
} from "../../../../scripts/id-links.ts";

export type Options = {
	/** The index to resolve against; built from the repository when absent. */
	index?: Index;
};

function repoRoot(): string {
	return process.env.BELOCH_REPO_ROOT ?? process.cwd();
}

let cached: Index | undefined;

export function getIndex(options: Options = {}): Index {
	if (options.index) return options.index;
	cached ??= buildIndex(repoRoot());
	return cached;
}

/**
 * Turns every id link in the text nodes of `tree` into a link node. The
 * index is a value or a function that builds it, called on the first link
 * found, so a tree without links costs no index.
 */
export function linkIds(tree: any, index: Index | (() => Index), path = "document"): void {
	let idx: Index | undefined = typeof index === "function" ? undefined : index;
	visit(tree, "text", (node: any, i: number | undefined, parent: any) => {
		if (!parent || i === undefined || !node.value.includes("[[")) return;
		const parts: any[] = [];
		let last = 0;
		for (const m of node.value.matchAll(new RegExp(LINK_PATTERN.source, "g"))) {
			idx ??= (index as () => Index)();
			const r = resolve(idx, { target: m[1]!.trim(), text: m[2]?.trim() ?? null });
			if ("error" in r) throw new Error(`${path}: ${r.error}`);
			if (m.index! > last) parts.push({ type: "text", value: node.value.slice(last, m.index) });
			parts.push({ type: "link", url: r.url, children: [{ type: "text", value: r.text }] });
			last = m.index! + m[0].length;
		}
		if (parts.length === 0) return;
		if (last < node.value.length) parts.push({ type: "text", value: node.value.slice(last) });
		parent.children.splice(i, 1, ...parts);
		return i + parts.length;
	});
}

export default function remarkIdLinks(options: Options = {}) {
	return (tree: any, file: any) => {
		linkIds(tree, getIndex(options), file?.path);
	};
}
