import { test, expect } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const dir = join(import.meta.dir, "..", "docs", "decision");
const records = readdirSync(dir).filter((f) => /^\d{4}-.*\.md$/.test(f));

test("a record's issue names owner and repository", () => {
	const malformed = records.filter((file) => {
		const frontmatter = readFileSync(join(dir, file), "utf8").split(/^---$/m)[1] ?? "";
		const issue = frontmatter.match(/^issue:(.*)$/m);
		return issue !== null && !/^ *"?[\w.-]+\/[\w.-]+#\d+"? *$/.test(issue[1]);
	});
	expect(malformed).toEqual([]);
});
