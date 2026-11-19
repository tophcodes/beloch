import { test, expect } from "bun:test";
import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

const script = join(import.meta.dir, "check-reviewed-interfaces.sh");
const list = "packages/core/reviewed.sha256";

const sha = (text: string) => createHash("sha256").update(text).digest("hex");

// Runs the script over a fresh directory that holds `files`, each a path
// mapped to its text.
function check(files: Record<string, string>) {
	const root = mkdtempSync(join(tmpdir(), "reviewed-"));
	try {
		for (const [path, text] of Object.entries(files)) {
			mkdirSync(dirname(join(root, path)), { recursive: true });
			writeFileSync(join(root, path), text);
		}
		const run = Bun.spawnSync(["bash", script, root]);
		return {
			ok: run.exitCode === 0,
			out: run.stdout.toString() + run.stderr.toString(),
		};
	} finally {
		rmSync(root, { recursive: true, force: true });
	}
}

const mli = "type t = A | B\n";

test("a list without entries passes", () => {
	const { ok, out } = check({ [list]: "# reviewed interfaces\n" });
	expect(out).toBe("");
	expect(ok).toBe(true);
});

test("an interface that matches its hash passes", () => {
	const { ok, out } = check({
		[list]: `${sha(mli)}  packages/core/lib/fan.mli\n`,
		"packages/core/lib/fan.mli": mli,
	});
	expect(out).toBe("");
	expect(ok).toBe(true);
});

test("a changed interface fails and is named", () => {
	const { ok, out } = check({
		[list]: `${sha(mli)}  packages/core/lib/fan.mli\n`,
		"packages/core/lib/fan.mli": "type t = A | B | C\n",
	});
	expect(ok).toBe(false);
	expect(out).toContain("packages/core/lib/fan.mli");
});

test("a listed interface that is gone fails and is named", () => {
	const { ok, out } = check({
		[list]: `${sha(mli)}  packages/core/lib/fan.mli\n`,
	});
	expect(ok).toBe(false);
	expect(out).toContain("packages/core/lib/fan.mli");
});

test("a missing list fails", () => {
	const { ok } = check({ "packages/core/lib/fan.mli": mli });
	expect(ok).toBe(false);
});
