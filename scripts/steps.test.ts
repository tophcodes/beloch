import { test, expect } from "bun:test";
import { join } from "node:path";

const steps = join(import.meta.dir, "steps.sh");

// Runs a script that sources steps.sh, the way scripts/check.sh does.
function run(body: string) {
	const script = `set -uo pipefail\nsource "${steps}"\n${body}`;
	const proc = Bun.spawnSync(["bash", "-c", script]);
	return { code: proc.exitCode, out: proc.stdout.toString() };
}

test("every step runs after a failed one, and the run fails", () => {
	const { code, out } = run(`
step one false
step two echo ran-two
finish check`);
	expect(out).toContain("ran-two");
	expect(out).toContain("FAILED   one");
	expect(out).toContain("passed   two");
	expect(out).toContain("check: 1 step(s) failed");
	expect(code).toBe(1);
});

test("a run whose steps all pass exits 0", () => {
	const { code, out } = run(`
step one true
step two true
finish check`);
	expect(out).toContain("check: every step passed");
	expect(code).toBe(0);
});

test("a step guarded by a failed one is reported as skipped", () => {
	const { code, out } = run(`
if step build false; then step tests true; else skip tests "build failed"; fi
finish check`);
	expect(out).toContain("skipped  tests (build failed)");
	expect(out).not.toContain("passed   tests");
	expect(code).toBe(1);
});
