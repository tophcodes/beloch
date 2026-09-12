// Post-processing after rehype-citation, for a Wikipedia-like reference
// apparatus:
//
// 1. Backlinks: each bibliography entry (`#bib-<key>`) gets `↑ a b c …`,
//    one letter per citing location (`#citation--<key>--<n>`).
// 2. Notes: the footnote section rehype-citation builds for a note-style
//    CSL is titled "Notes", made visible, and moved in front of the
//    "References" heading, so the page reads text → notes → references.
//    Pages without a bibliography keep their plain GFM footnotes.
//
// Astro caches rendered content entries in node_modules/.astro; after changing
// this file, delete that directory (and .astro/) or the old output is served.
import type { Root, Element, ElementContent } from 'hast';
import { visit } from 'unist-util-visit';

const CITATION_ID = /^citation--(.+)--(\d+)$/;

export default function rehypeCitePost() {
	return (tree: Root) => {
		addBacklinks(tree);
		placeNotes(tree);
	};
}

function addBacklinks(tree: Root) {
	const sites = new Map<string, string[]>();
	visit(tree, 'element', (node: Element) => {
		const id = node.properties?.id;
		if (typeof id !== 'string') return;
		const m = CITATION_ID.exec(id);
		if (!m) return;
		// a citation with several keys, `[@a; @b]`, gets the id `citation--a--b--n`
		for (const key of m[1].split('--')) {
			const list = sites.get(key) ?? [];
			list.push(id);
			sites.set(key, list);
		}
	});
	if (sites.size === 0) return;

	visit(tree, 'element', (node: Element) => {
		const id = node.properties?.id;
		if (typeof id !== 'string' || !id.startsWith('bib-')) return;
		const ids = sites.get(id.slice('bib-'.length));
		if (!ids) return;
		const links: ElementContent[] = [];
		ids.forEach((target, i) => {
			if (i > 0) links.push({ type: 'text', value: ' ' });
			links.push({
				type: 'element',
				tagName: 'a',
				properties: { href: `#${target}`, className: ['cite-backlink'] },
				children: [{ type: 'text', value: label(i) }],
			});
		});
		node.children.push(
			{ type: 'text', value: ' ' },
			{
				type: 'element',
				tagName: 'span',
				properties: { className: ['cite-backlinks'], title: 'cited at' },
				children: [{ type: 'text', value: '↑ ' }, ...links],
			},
		);
	});
}

function placeNotes(tree: Root) {
	type Slot = { node: Element; parent: Root | Element; index: number };
	let notes: Slot | undefined;
	let refs: Slot | undefined;
	let hasRefs = false; // only pages with a bibliography get the Notes treatment
	visit(tree, 'element', (node: Element, index, parent) => {
		if (index === undefined || !parent) return;
		const cls = node.properties?.className;
		if (node.properties?.id === 'refs') {
			hasRefs = true;
		} else if (node.tagName === 'section' && Array.isArray(cls) && cls.includes('footnotes')) {
			notes = { node, parent, index };
		} else if (node.tagName === 'h2' && text(node).trim() === 'References') {
			// matched by text: Astro assigns heading ids after user plugins run
			refs = { node, parent, index };
		}
	});
	if (!notes || !hasRefs) return;

	const heading = notes.node.children.find((n) =>
		n.type === 'element' && n.tagName === 'h2' && n.properties?.id === 'footnote-label') as Element | undefined;
	if (heading) {
		heading.properties = { id: 'notes' };
		heading.children = [{ type: 'text', value: 'Notes' }];
	}

	if (refs && refs.parent === notes.parent && refs.index < notes.index) {
		const siblings = notes.parent.children;
		siblings.splice(notes.index, 1);
		siblings.splice(refs.index, 0, notes.node);
	}
}

function text(node: ElementContent): string {
	if (node.type === 'text') return node.value;
	if (node.type === 'element') return node.children.map(text).join('');
	return '';
}

// a, b, …, z, aa, ab, … as Wikipedia does
function label(i: number): string {
	let s = '';
	let n = i;
	do {
		s = String.fromCharCode(97 + (n % 26)) + s;
		n = Math.floor(n / 26) - 1;
	} while (n >= 0);
	return s;
}
