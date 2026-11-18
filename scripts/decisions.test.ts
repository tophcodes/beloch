import { test, expect } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dir, "..", "records");
const records = ["adr", "bep"].flatMap((kind) =>
	readdirSync(join(root, kind))
		.filter((f) => /^(ADR|BEP)-\d{4}-.*\.md$/.test(f))
		.map((f) => join(root, kind, f)),
);

test("a record's issue names owner and repository", () => {
	const malformed = records.filter((path) => {
		const frontmatter = readFileSync(path, "utf8").split(/^---$/m)[1] ?? "";
		const issue = frontmatter.match(/^issue:(.*)$/m);
		return issue !== null && !/^ *"?[\w.-]+\/[\w.-]+#\d+"? *$/.test(issue[1]);
	});
	expect(malformed).toEqual([]);
});
