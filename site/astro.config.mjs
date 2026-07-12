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

// https://astro.build/config
export default defineConfig({
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
			components: {
				SiteTitle: './src/starlight/SiteTitle.astro',
				Header: './src/starlight/Header.astro',
				Sidebar: './src/starlight/Sidebar.astro',
				TwoColumnContent: './src/starlight/TwoColumnContent.astro',
			},
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
