import { test, expect } from "bun:test";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { indexDocument, type Index } from "./id-links.ts";

const root = join(import.meta.dir, "..");
const filter = join(root, "scripts", "id-links.lua");
const pandoc = Bun.which("pandoc");

const modelSource = [
	"---",
	"title: Model",
	"---",
	"",
	"## 1. Paper",
	"",
	"A sheet, see [[reference/model#def-sheet]] and [[decision/0032|the record]].",
	"",
	'::: {.definition #def-sheet name="sheet"}',
	"A sheet is a polygon. Compare [[reference/kernel#rank|rank]] and [[reference/kernel]].",
	":::",
	"",
	"| Sort | Defined |",
	"|------|---------|",
	"| sheet | [[reference/model#def-sheet\\|in a cell]] |",
].join("\n");

const model = indexDocument(modelSource, "docs/reference/MODEL.md", "/model/");
const kernel = indexDocument("---\ntitle: The OCaml kernel\n---\n\n## Rank\n", "docs/reference/KERNEL.md", "/kernel/");
const adr = indexDocument("# 0032: The specification binds\n", "docs/decision/0032-the-specification-binds.md", null);
const index: Index = {
	site: "https://belochlang.org",
	repository: "https://github.com/tophcodes/beloch/blob/main",
	documents: { [model.id]: model, [kernel.id]: kernel, [adr.id]: adr },
};

function html(source: string, extra: string[] = []): { out: string; err: string; code: number } {
	const dir = mkdtempSync(join(tmpdir(), "id-links-lua-"));
	mkdirSync(join(dir, "docs", "reference"), { recursive: true });
	const input = join(dir, "docs", "reference", "MODEL.md");
	writeFileSync(input, source);
	const indexPath = join(dir, "id-links.json");
	writeFileSync(indexPath, JSON.stringify(index));
	const run = Bun.spawnSync(
		[pandoc as string, input, "--from", "markdown+wikilinks_title_after_pipe", "--to", "html", "--wrap=none", "--lua-filter", filter, ...extra],
		{ cwd: dir, env: { ...process.env, BELOCH_ID_LINKS: indexPath } },
	);
	return { out: run.stdout.toString(), err: run.stderr.toString(), code: run.exitCode };
}

test.skipIf(!pandoc)("an anchor in the rendered document links internally, the rest to the site or the repository", () => {
	const r = html(modelSource);
	expect(r.err).toBe("");
	expect(r.out).toContain('<a href="#def-sheet">sheet</a>');
	expect(r.out).toContain('<a href="https://github.com/tophcodes/beloch/blob/main/docs/decision/0032-the-specification-binds.md">the record</a>');
	expect(r.out).toContain('<a href="https://belochlang.org/kernel/#rank">rank</a>');
	expect(r.out).toContain('<a href="https://belochlang.org/kernel/">The OCaml kernel</a>');
	expect(r.out).toContain('<td><a href="#def-sheet">in a cell</a></td>');
});

test.skipIf(!pandoc)("a target that resolves to nothing stops the render and names it", () => {
	const r = html("See [[decision/9999]].");
	expect(r.code).not.toBe(0);
	expect(r.err).toContain("[[decision/9999]] names no document; there is no decision/9999 under docs/");
});
