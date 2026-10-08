import { test, expect } from "bun:test";
import { join } from "node:path";

const script = join(import.meta.dir, "check-pull-request.sh");

function check(labels: string[], body: string | null) {
	const payload = JSON.stringify({ pull_request: { labels: labels.map((name) => ({ name })), body } });
	const run = Bun.spawnSync(["bash", script], { stdin: new TextEncoder().encode(payload) });
	return { ok: run.exitCode === 0, out: run.stdout.toString() };
}

test("a kind label and Closes or Refs pass", () => {
	expect(check(["kind:build"], "Closes #89. Adds the check.").ok).toBe(true);
	expect(check(["kind:design"], "Adds decisions/action-is-the-sixth-core-module.\n\nRefs #59").ok).toBe(true);
});

test("For and Fixes do not count as a reference", () => {
	for (const body of ["For #59. Adds decisions/action-is-the-sixth-core-module.", "Fixes #81."]) {
		const { ok, out } = check(["kind:build"], body);
		expect(ok).toBe(false);
		expect(out).toContain("names no issue");
	}
});

test("a placeholder without a number does not count", () => {
	expect(check(["kind:build"], "Closes #n").ok).toBe(false);
});

test("no-issue waives the reference but not the kind label", () => {
	expect(check(["kind:build", "no-issue"], "Bumps a dependency.").ok).toBe(true);
	const { ok, out } = check(["no-issue"], "Bumps a dependency.");
	expect(ok).toBe(false);
	expect(out).toContain("0 kind: labels");
	expect(out).not.toContain("names no issue");
});

test("two kind labels fail", () => {
	const { ok, out } = check(["kind:build", "kind:docs"], "Closes #90");
	expect(ok).toBe(false);
	expect(out).toContain("2 kind: labels");
});

test("an empty body fails", () => {
	expect(check(["kind:build"], null).ok).toBe(false);
});
