import { test, expect } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const dir = join(import.meta.dir, "..", "docs", "decisions");
const files = [
	...readdirSync(dir).map((f) => join(dir, f)),
	...readdirSync(join(dir, "archive")).map((f) => join(dir, "archive", f)),
].filter((f) => f.endsWith(".md") && !f.endsWith("README.md"));

function frontmatter(file: string): string {
	return readFileSync(file, "utf8").split(/^---$/m)[1] ?? "";
}

test("a record's file is its date and slug, and the date is the one in the record", () => {
	const wrong = files.filter((file) => {
		const name = /^(\d{8})-([a-z0-9-]+)\.md$/.exec(file.slice(file.lastIndexOf("/") + 1));
		if (!name) return true;
		const date = /^date:\s*(\d{4})-(\d{2})-(\d{2})/m.exec(frontmatter(file));
		return !date || date[1]! + date[2]! + date[3]! !== name[1];
	});
	expect(wrong).toEqual([]);
});

test("no two records share a slug, since the slug is the id a link names", () => {
	const slugs = files.map((f) => f.slice(f.lastIndexOf("/") + 1).replace(/^\d{8}-/, "").replace(/\.md$/, ""));
	expect(slugs.filter((s, i) => slugs.indexOf(s) !== i)).toEqual([]);
});

test("a record's issue names owner and repository", () => {
	const malformed = files.filter((file) => {
		const issue = frontmatter(file).match(/^issue:(.*)$/m);
		return issue !== null && !/^ *"?[\w.-]+\/[\w.-]+#\d+"? *$/.test(issue[1]);
	});
	expect(malformed).toEqual([]);
});
