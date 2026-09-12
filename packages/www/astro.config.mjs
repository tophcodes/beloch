// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import remarkBel from './src/lib/remark-bel.ts';
import remarkModelBlocks from './src/lib/remark-model-blocks.ts';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
// The package's default export condition is the browser build, which cannot
// read a local .bib; the node entry is what a static build needs.
import rehypeCitation from 'rehype-citation/node/rehype-citation.mjs';
import rehypeCitePost from './src/lib/rehype-cite-post.ts';
import { headSyncScript } from "./src/lib/paper-schemes.ts";
import { notePopupScript } from "./src/lib/note-popups.ts";

// Anchor repo root to this file's location (packages/www/astro.config.mjs → two levels up).
// Used by highlight-bel.ts to resolve the grammar wasm + web-tree-sitter runtime
// under packages/www/. (The old BELOCH_BIN coupling — a native-binary path for build-time
// .bel evaluation — is deliberately not carried forward: highlight-bel.ts and
// remark-bel.ts only do tree-sitter syntax highlighting, no evaluation, so the
// build has no dependency on a native binary. Real rendering happens client-side
// in a later step.)
const repoRoot = join(fileURLToPath(import.meta.url), '..', '..', '..');
process.env.BELOCH_REPO_ROOT = repoRoot;

// The render pipeline (packages/render-2d/scene, packages/render-2d/render-svg) is browser-safe TS
// with no build step of its own (main: src/index.ts, no dist/). It isn't a
// published package, so instead of a `file:` dependency (raw TS sitting in
// node_modules usually isn't transpiled by the consumer's bundler), we alias
// the package names straight to their source entrypoints and let Vite
// transpile them like any other project source. render-svg's only Node-native
// dependency (@resvg/resvg-js, for PNG rasterization) is a dynamic `import()`
// confined to bin/fold2svg.ts — not reachable from src/index.ts — so it never
// enters the client bundle.
const sceneRoot = join(repoRoot, 'packages', 'render-2d', 'scene', 'src', 'index.ts');
const renderSvgRoot = join(repoRoot, 'packages', 'render-2d', 'render-svg', 'src', 'index.ts');

// https://astro.build/config
export default defineConfig({
	vite: {
		resolve: {
			alias: {
				'@beloch/scene': sceneRoot,
				'@beloch/render-svg': renderSvgRoot,
			},
		},
		// packages/render-2d/ lives outside packages/www/ (Vite's default project root), so the dev
		// server needs explicit permission to read source files from there.
		server: {
			fs: { allow: [repoRoot] },
		},
	},
	redirects: {
		// The docs playground page was replaced by the landing page at `/`
		// (the live playground is the landing hero now).
		'/playground/': '/',
	},
	markdown: {
		// Highlight ```beloch fences with the tree-sitter highlighter before
		// Expressive Code sees them.
		// remark-model-blocks turns the `::: {.definition #id …}` fenced divs of
		// spec/MODEL.md into numbered, cross-referenced sections; it runs before
		// remarkMath so the math inside a block body is still tokenized.
		remarkPlugins: [remarkBel, remarkModelBlocks, remarkMath],
		// `$...$` math and `[@key, §3]` citations, the same syntax pandoc reads
		// for scripts/render-model.sh; the bibliography is the paper's.
		rehypePlugins: [
			rehypeKatex,
			[rehypeCitation, {
				// `bibliography` is joined onto `path`; an absolute path here
				// would be appended to the cwd and fail to resolve.
				path: repoRoot,
				bibliography: join('paper', 'references.bib'),
				// note style: a footnote marker in the text, the locator in the note
				csl: join('paper', 'chicago-notes-bibliography.csl'),
				linkCitations: true,
			}],
			rehypeCitePost,
		],
		// SmartyPants (on by default) rewrites "--" to an en/em dash in prose.
		// Beloch source uses "--" as the crease-name sigil (e.g. `--d1`), and
		// <Beloch> slot children are markdown body text, not raw JS/JSX text —
		// so without this, evalBelToFold() sees mangled source for any inline
		// example that uses a crease name. Disabled site-wide rather than only
		// inside .bel snippets: no separate hook point exists to scope it.
		smartypants: false,
	},
	integrations: [
		starlight({
			title: "Beloch",
			description: "A declarative language for origami, built on the Huzita–Justin axioms.",
			social: [{ icon: "github", label: "GitHub", href: "https://github.com/tophcodes/beloch" }],
			sidebar: [
				{
					label: "Getting Started",
					items: [
						{ label: "Introduction", link: "/introduction/" },
					],
				},
				{
					label: "Tutorials",
					items: [
						{ label: "Paper & Values", link: "/tutorials/paper-and-values/" },
						{ label: "Naming Points & Lines", link: "/tutorials/naming/" },
						{ label: "Reflecting: map onto", link: "/tutorials/reflecting/" },
						{ label: "mark vs. fold", link: "/tutorials/mark-vs-fold/" },
						{ label: "Layers & Ordering", link: "/tutorials/layers/" },
					],
				},
				{
					label: "Reference",
					items: [
						{ label: "The model", link: "/model/" },
					],
				},
			],
			customCss: ['./src/styles/theme.css', 'katex/dist/katex.min.css'],
			head: [
				{
					tag: "script",
					content: headSyncScript(),
				},
				{
					tag: "script",
					attrs: { defer: true },
					content: notePopupScript(),
				},
			],
		}),
	],
});
