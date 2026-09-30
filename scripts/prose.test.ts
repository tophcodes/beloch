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
