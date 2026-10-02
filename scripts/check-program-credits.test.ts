import { test, expect } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

const script = join(import.meta.dir, "check-program-credits.sh");

const bib = "@book{ida2020,\n  title = {T},\n}\n";

// Runs the script over a fresh git repository that holds `files`, each a
// path mapped to its text.
function check(files: Record<string, string>) {
	const root = mkdtempSync(join(tmpdir(), "credits-"));
	try {
		for (const [path, text] of Object.entries(files)) {
			mkdirSync(dirname(join(root, path)), { recursive: true });
			writeFileSync(join(root, path), text);
		}
		Bun.spawnSync(["git", "init", "-q"], { cwd: root });
		Bun.spawnSync(["git", "add", "."], { cwd: root });
		const run = Bun.spawnSync(["bash", script, root]);
		return { ok: run.exitCode === 0, out: run.stdout.toString() };
	} finally {
		rmSync(root, { recursive: true, force: true });
	}
}

const example = '@author "A"\n@design traditional\n@source "[ida2020, Fig. 1]"\npaper square\n';

test("a program with its credits passes", () => {
	const { ok, out } = check({
		"bibliography/references.bib": bib,
		"examples/crane.bel": example,
		"packages/core/tests/cases/t.bel": '; a test\n@author "A"\npaper square\n',
	});
	expect(out).toBe("");
	expect(ok).toBe(true);
});

test("a .bel file without the author annotation fails, each one listed", () => {
	const { ok, out } = check({
		"bibliography/references.bib": bib,
		"a.bel": "paper square\n",
		"b/c.bel": '; @author "in a comment"\npaper square\n',
	});
	expect(ok).toBe(false);
	expect(out).toContain("a.bel: no @author");
	expect(out).toContain("b/c.bel: no @author");
});

test("an example needs the design and a source", () => {
	const { ok, out } = check({
		"bibliography/references.bib": bib,
		"examples/a.bel": '@author "A"\npaper square\n',
	});
	expect(ok).toBe(false);
	expect(out).toContain("examples/a.bel: no @design");
	expect(out).toContain("examples/a.bel: no @source");
});

test("every cite key in a source's brackets is in the bibliography", () => {
	const { ok, out } = check({
		"bibliography/references.bib": bib,
		"examples/b.bel": '@author "A"\n@design traditional\n@source "[ida2020; nobody1999, p. 3]"\npaper square\n',
	});
	expect(ok).toBe(false);
	expect(out).toContain("examples/b.bel: @source cites nobody1999, which is not in bibliography/references.bib");
	expect(out).not.toContain("cites ida2020");
});

test("a program below examples/ is no example", () => {
	const { ok } = check({ "examples/syntax/a.bel": '@author "A"\npaper square\n' });
	expect(ok).toBe(true);
});
