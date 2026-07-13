// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import remarkBel from './src/lib/remark-bel.ts';

// Anchor repo root to this file's location (site/astro.config.mjs → one level up).
// Used by highlight-bel.ts to resolve the grammar wasm + web-tree-sitter runtime
// under site/. (The old BELOCH_BIN coupling — a native-binary path for build-time
// .bel evaluation — is deliberately not carried forward: highlight-bel.ts and
// remark-bel.ts only do tree-sitter syntax highlighting, no evaluation, so the
// build has no dependency on a native binary. Real rendering happens client-side
// in a later step.)
const repoRoot = join(fileURLToPath(import.meta.url), '..', '..');
process.env.BELOCH_REPO_ROOT = repoRoot;

// The render pipeline (render/scene, render/render-svg) is browser-safe TS
// with no build step of its own (main: src/index.ts, no dist/). It isn't a
// published package, so instead of a `file:` dependency (raw TS sitting in
// node_modules usually isn't transpiled by the consumer's bundler), we alias
// the package names straight to their source entrypoints and let Vite
// transpile them like any other project source. render-svg's only Node-native
// dependency (@resvg/resvg-js, for PNG rasterization) is a dynamic `import()`
// confined to bin/fold2svg.ts — not reachable from src/index.ts — so it never
// enters the client bundle.
const sceneRoot = join(repoRoot, 'render', 'scene', 'src', 'index.ts');
const renderSvgRoot = join(repoRoot, 'render', 'render-svg', 'src', 'index.ts');

// https://astro.build/config
export default defineConfig({
	vite: {
		resolve: {
			alias: {
				'@beloch/scene': sceneRoot,
				'@beloch/render-svg': renderSvgRoot,
			},
		},
		// render/ lives outside site/ (Vite's default project root), so the dev
		// server needs explicit permission to read source files from there.
		server: {
			fs: { allow: [repoRoot] },
		},
	},
	markdown: {
		// Highlight ```beloch fences with the tree-sitter highlighter before
		// Expressive Code sees them.
		remarkPlugins: [remarkBel],
	},
	integrations: [
		starlight({
			title: "Beloch",
			description: "A declarative language for origami, built on the Huzita–Justin axioms.",
			social: [{ icon: "github", label: "GitHub", href: "https://github.com/tophcodes/beloch" }],
			sidebar: [
				{
					label: "Einstieg",
					items: [{ label: "Einführung", link: "/" }],
				},
				{
					label: "Anleitung",
					items: [{ autogenerate: { directory: "guide" } }],
				},
				{
					label: "Referenz",
					items: [{ autogenerate: { directory: "reference" } }],
				},
				{
					label: "Beispiele",
					items: [{ label: "Beispiele", link: "/beispiele/" }],
				},
				{
					label: "Playground",
					items: [{ label: "Playground", link: "/playground/" }],
				},
			],
			customCss: ['./src/styles/theme.css'],
		}),
	],
});
