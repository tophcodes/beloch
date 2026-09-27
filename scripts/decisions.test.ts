import { test, expect } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const dir = join(import.meta.dir, "..", "decisions");
const records = readdirSync(dir).filter((f) => /^\d{4}-.*\.md$/.test(f));

// The first record that has to name its issue; earlier ones predate the field.
const FIRST_WITH_ISSUE = 34;

test("every record from 0034 on names its issue with owner and repository", () => {
	const missing = records.filter((file) => {
		if (Number(file.slice(0, 4)) < FIRST_WITH_ISSUE) return false;
		const frontmatter = readFileSync(join(dir, file), "utf8").split(/^---$/m)[1] ?? "";
		return !/^issue: *"?[\w.-]+\/[\w.-]+#\d+"? *$/m.test(frontmatter);
	});
	expect(missing).toEqual([]);
});
