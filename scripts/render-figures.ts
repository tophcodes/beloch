#!/usr/bin/env bun
// The figures of the reference documents, drawn by Beloch's own pipeline.
//
// Scans spec/*.md for `::: {.figure #fig-point caption="…" views="cp folded"
// highlight=".p"}` blocks, whose body is a Beloch program, evaluates each one
// with the `beloch` binary and renders the requested views through
// packages/render-2d, the same functions the docs site's <Beloch> card uses.
//
// Output goes to _build/spec/figures: `<id>-cp.svg`, `<id>-folded.svg`, and
// index.json (one entry per figure, with the files it produced and the reason
// if it produced none). Both renderers of the documents read the SVG files and
// fall back to a placeholder, so a figure that fails here never fails a build:
// packages/www/src/lib/remark-model-blocks.ts on the site,
// scripts/model-blocks.lua for the PDF.
//
// The SVGs carry the literal colors of DEFAULT_THEME, because typst places the
// same file into the PDF and resolves no var(); the site's live cards keep
// their CSS-variable theme.
//
// Runs inside the flake devshell, which puts `beloch` on PATH and installs the
// packages/render-2d workspace the imports below resolve through:
//   nix develop -c bun scripts/render-figures.ts [--out <dir>]

import { readdirSync, readFileSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { parseFold } from "../packages/render-2d/scene/src/index.ts";
import { renderCP, renderFolded } from "../packages/render-2d/render-svg/src/index.ts";
import { evalBelToFold } from "../packages/www/src/lib/eval-bel.ts";

const VIEWS = ["cp", "folded"] as const;
type View = (typeof VIEWS)[number];

export interface FigureEntry {
	/** The document the block is written in, relative to the repo root. */
	source: string;
	views: View[];
	highlight: string[];
	/** Paths of the rendered SVGs, relative to the index, by view. */
	files: Partial<Record<View, string>>;
	/** Why nothing was rendered, or null. */
	error: string | null;
}

// The third reader of the fenced-div syntax, next to remark-model-blocks.ts and
// model-blocks.lua. It only has to find `.figure` blocks and keep their body
// verbatim, so it stays a scanner rather than a markdown parse.
const OPEN_FENCE = /^:{3,}\s*\{(.*)\}\s*$/;
const CLOSE_FENCE = /^:{3,}\s*$/;
const ATTR = /([.#])([^\s"'{}]+)|([A-Za-z_][\w-]*)="([^"]*)"/g;

export interface FigureBlock {
	id: string;
	views: View[];
	highlight: string[];
	program: string;
}

export function scanFigures(source: string): FigureBlock[] {
	const lines = source.split("\n");
	const out: FigureBlock[] = [];
	for (let i = 0; i < lines.length; i++) {
		const open = OPEN_FENCE.exec(lines[i]!);
		if (!open) continue;
		let j = i + 1;
		while (j < lines.length && !CLOSE_FENCE.test(lines[j]!)) j++;
		if (j >= lines.length) break; // unterminated fence: leave the source alone
		const classes: string[] = [];
		const attrs: Record<string, string> = {};
		let id = "";
		let m: RegExpExecArray | null;
		ATTR.lastIndex = 0;
		while ((m = ATTR.exec(open[1]!))) {
			if (m[1] === ".") classes.push(m[2]!);
			else if (m[1] === "#") id = m[2]!;
			else attrs[m[3]!] = m[4]!;
		}
		if (classes.includes("figure") && id) {
			out.push({
				id,
				views: words(attrs.views).filter((v): v is View => VIEWS.includes(v as View)),
				highlight: highlightNames(attrs.highlight),
				program: lines.slice(i + 1, j).join("\n").trim(),
			});
		}
		i = j;
	}
	return out;
}

function words(value: string | undefined): string[] {
	return value ? value.trim().split(/\s+/).filter(Boolean) : [];
}

// `.p --l #[.p .q]`. A flap selector stays one entry although it has a space
// inside its brackets.
export function highlightNames(value: string | undefined): string[] {
	return [...(value ?? "").matchAll(/#\[[^\]]*\]|\S+/g)].map((m) => m[0]);
}

function render(block: FigureBlock, outDir: string, source: string): FigureEntry {
	const views = block.views.length ? block.views : [...VIEWS];
	const entry: FigureEntry = {
		source,
		views,
		highlight: block.highlight,
		files: {},
		error: null,
	};
	let scene: ReturnType<typeof parseFold>;
	try {
		scene = parseFold(evalBelToFold(block.program) as object);
	} catch (err) {
		entry.error = (err as Error).message;
		return entry;
	}
	for (const view of views) {
		const file = `${block.id}-${view}.svg`;
		try {
			const opts = { highlight: block.highlight };
			const doc = view === "cp" ? renderCP(scene, opts) : renderFolded(scene, opts);
			writeFileSync(join(outDir, file), doc.toString());
			entry.files[view] = file;
		} catch (err) {
			entry.error = (err as Error).message;
		}
	}
	return entry;
}

function main() {
	const root = join(import.meta.dir, "..");
	const flag = process.argv.indexOf("--out");
	const outDir = flag >= 0 ? process.argv[flag + 1]! : join(root, "_build", "spec", "figures");
	const specDir = join(root, "spec");

	rmSync(outDir, { recursive: true, force: true });
	mkdirSync(outDir, { recursive: true });

	const figures: Record<string, FigureEntry> = {};
	let failed = 0;
	for (const name of readdirSync(specDir).sort()) {
		if (!name.endsWith(".md")) continue;
		const source = `spec/${name}`;
		for (const block of scanFigures(readFileSync(join(specDir, name), "utf8"))) {
			const entry = render(block, outDir, source);
			if (entry.error) failed++;
			figures[block.id] = entry;
		}
	}
	writeFileSync(join(outDir, "index.json"), `${JSON.stringify({ figures }, null, "\t")}\n`);
	const drawn = Object.keys(figures).length - failed;
	console.log(`${outDir}: ${drawn} figure(s)${failed ? `, ${failed} failed` : ""}`);
	for (const [id, entry] of Object.entries(figures)) {
		if (entry.error) console.error(`${id}: ${entry.error.split("\n")[0]}`);
	}
}

if (import.meta.main) main();
