import { test, expect } from "bun:test";
import { join } from "node:path";

// scripts/fixtures/prose-sample.ml puts a hedging adverb and an em dash in
// code, in strings and in odoc markup, around a nested comment and a string
// that holds "*)". One comment on
// line 13 holds the only hit, after a multi-byte character in code.
test("prose reports the comments of an OCaml file at their source position", () => {
	const run = Bun.spawnSync(
		["bash", "scripts/prose.sh", "--output=JSON", "scripts/fixtures/prose-sample.ml"],
		{ cwd: join(import.meta.dir, "..") },
	);
	const report = JSON.parse(run.stdout.toString());
	const alerts = Object.entries(report).flatMap(([path, list]) =>
		(list as { Check: string; Line: number; Span: number[] }[]).map(
			(a) => `${path}:${a.Line}:${a.Span[0]} ${a.Check}`,
		),
	);
	expect(alerts).toEqual(["scripts/fixtures/prose-sample.ml:13:32 Prose.HedgingAdverb"]);
});

// scripts/fixtures/prose-sample.{ts,astro,lua,sh} put a British spelling in
// code, in strings, in a code span, in a URL, in a tag and in markup; only the
// comments are prose.
test("prose checks the spelling of the comments of the other sources", () => {
	const fixtures = ["ts", "astro", "lua", "sh"].map((ext) => `scripts/fixtures/prose-sample.${ext}`);
	const run = Bun.spawnSync(["bash", "scripts/prose.sh", "--output=JSON", ...fixtures], {
		cwd: join(import.meta.dir, ".."),
	});
	const report = JSON.parse(run.stdout.toString());
	const alerts = Object.entries(report).flatMap(([path, list]) =>
		(list as { Check: string; Line: number; Span: number[] }[]).map(
			(a) => `${path}:${a.Line}:${a.Span[0]} ${a.Check}`,
		),
	);
	expect(alerts.sort()).toEqual([
		"scripts/fixtures/prose-sample.astro:11:31 Beloch.Spelling",
		"scripts/fixtures/prose-sample.astro:5:8 Beloch.Spelling",
		"scripts/fixtures/prose-sample.astro:8:30 Beloch.Spelling",
		"scripts/fixtures/prose-sample.lua:3:14 Beloch.Spelling",
		"scripts/fixtures/prose-sample.lua:4:34 Beloch.Spelling",
		"scripts/fixtures/prose-sample.sh:4:13 Beloch.Spelling",
		"scripts/fixtures/prose-sample.sh:7:40 Beloch.Spelling",
		"scripts/fixtures/prose-sample.ts:11:69 Beloch.Spelling",
		"scripts/fixtures/prose-sample.ts:9:31 Beloch.Spelling",
	]);
});
