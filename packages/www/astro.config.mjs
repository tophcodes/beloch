// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import remarkBel from './src/lib/remark-bel.ts';
import remarkModelBlocks from './src/lib/remark-model-blocks.ts';
import remarkGrammar from './src/lib/remark-grammar.ts';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
// The package's default export condition is the browser build, which cannot
// read a local .bib; the node entry is what a static build needs.
import rehypeCitation from 'rehype-citation/node/rehype-citation.mjs';
import rehypeCitePost from './src/lib/rehype-cite-post.ts';
import { headSyncScript } from "./src/lib/paper-schemes.ts";
import { notePopupScript } from "./src/lib/note-popups.ts";
import { sidebarCollapseScript } from "./src/lib/sidebar-collapse.ts";

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
// The runtime (packages/runtime) is the same kind of package: browser-safe TS
// with no build step, aliased to its entrypoints.
const runtimeRoot = join(repoRoot, 'packages', 'runtime', 'core', 'src', 'index.ts');
const runtimeRenderDomRoot = join(repoRoot, 'packages', 'runtime', 'render-dom', 'src', 'index.ts');
const runtimeEditorRoot = join(repoRoot, 'packages', 'runtime', 'editor', 'src', 'index.ts');
const runtimePickRoot = join(repoRoot, 'packages', 'runtime', 'pick', 'src', 'index.ts');
const runtimeEvalRoot = join(repoRoot, 'packages', 'runtime', 'eval', 'src', 'index.ts');

// https://astro.build/config
export default defineConfig({
	// The canonical domain (DEPLOY.md). Starlight only emits `og:url` and the
	// per-page canonical link when `site` is set, and an absolute `og:image`
	// needs a known origin to resolve against.
	site: 'https://beloch.toph.so',
	vite: {
		resolve: {
			alias: {
				'@beloch/scene': sceneRoot,
				'@beloch/render-svg': renderSvgRoot,
				'@beloch/runtime': runtimeRoot,
				'@beloch/runtime-render-dom': runtimeRenderDomRoot,
				'@beloch/runtime-editor': runtimeEditorRoot,
				'@beloch/runtime-pick': runtimePickRoot,
				'@beloch/runtime-eval': runtimeEvalRoot,
			},
		},
		// packages/render-2d/ lives outside packages/www/ (Vite's default project root), so the dev
		// server needs explicit permission to read source files from there.
		server: {
			fs: { allow: [repoRoot] },
		},
	},
	redirects: {
		// `introduction.mdx` and `tutorials/` were removed in favor of the four
		// reference documents under `/model/`, `/kernel/`, `/language/`,
		// `/output/`; both were still targets of the main navigation and are
		// indexed, so they 404 without a redirect. Each old path goes to the
		// reference doc covering the same ground: `paper-and-values`, `naming`
		// and `mark-vs-fold` are language syntax (paper declaration, bindings,
		// the `mark`/`fold` verbs), all in the language spec's "Write
		// statements" section; `reflecting` covers `map onto`, which the model
		// spec defines as an operation; `layers` covers fold-stack ordering,
		// which the kernel spec documents as rank. `/introduction/` followed
		// the same path as the first tutorial, so it goes there too.
		'/introduction/': '/language/',
		'/tutorials/paper-and-values/': '/language/',
		'/tutorials/naming/': '/language/',
		'/tutorials/mark-vs-fold/': '/language/',
		'/tutorials/reflecting/': '/model/',
		'/tutorials/layers/': '/kernel/',
	},
	markdown: {
		// Highlight ```beloch fences with the tree-sitter highlighter before
		// Expressive Code sees them.
		// remark-model-blocks turns the `::: {.definition #id …}` fenced divs of
		// spec/MODEL.md into numbered, cross-referenced sections; it runs before
		// remarkMath so the math inside a block body is still tokenized.
		// remark-grammar turns the ```grammar fragments of spec/BELOCH.md into
		// linked rules and generates the collected grammar under `## Grammar`.
		remarkPlugins: [remarkBel, remarkGrammar, remarkModelBlocks, remarkMath],
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
					label: "Reference",
					items: [
						{ label: "The model", link: "/model/" },
						{ label: "The kernel", link: "/kernel/" },
						{ label: "The language", link: "/language/" },
						{ label: "The output", link: "/output/" },
					],
				},
			],
			components: {
				Sidebar: './src/components/Sidebar.astro',
				// One header on every page. The mobile drawer picks up the text
				// links the compact header drops.
				Header: './src/components/DocsHeader.astro',
				MobileMenuFooter: './src/components/MobileMenuNav.astro',
				MobileMenuToggle: './src/components/MenuButton.astro',
				Footer: './src/components/DocsFooter.astro',
			},
			customCss: ['./src/styles/theme.css', 'katex/dist/katex.min.css'],
			head: [
				// Starlight sets og:title, og:description, og:type and
				// twitter:card itself (utils/head.ts); it never sets an image, so
				// the docs pages announce `summary_large_image` and deliver no
				// image, same gap as the landing page. Reuses the same
				// build-generated card (scripts/generate-og-image.ts) rather than
				// a second image, since these are reference documents of the same
				// project, not individually illustrated pages.
				{
					tag: "meta",
					attrs: { property: "og:image", content: "https://beloch.toph.so/og-image.png" },
				},
				{
					tag: "meta",
					attrs: { property: "og:image:width", content: "1200" },
				},
				{
					tag: "meta",
					attrs: { property: "og:image:height", content: "630" },
				},
				{
					tag: "meta",
					attrs: { name: "twitter:image", content: "https://beloch.toph.so/og-image.png" },
				},
				{
					tag: "script",
					content: headSyncScript(),
				},
				{
					tag: "script",
					content: sidebarCollapseScript(),
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
