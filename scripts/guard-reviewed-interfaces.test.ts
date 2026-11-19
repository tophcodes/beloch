import { test, expect } from "bun:test";
import { join } from "node:path";

const script = join(import.meta.dir, "guard-reviewed-interfaces.sh");

// Runs the hook with the payload Claude Code sends before a tool call and
// returns the permission decision it prints, or null when it prints none.
function decide(payload: object): string | null {
	const run = Bun.spawnSync(["bash", script], {
		stdin: new TextEncoder().encode(JSON.stringify(payload)),
	});
	expect(run.exitCode).toBe(0);
	const out = run.stdout.toString().trim();
	if (out === "") return null;
	return JSON.parse(out).hookSpecificOutput.permissionDecision;
}

const edit = (file_path: string) => ({ tool_name: "Edit", tool_input: { file_path } });
const bash = (command: string) => ({ tool_name: "Bash", tool_input: { command } });

test("an edit of the hash list asks the user", () => {
	expect(decide(edit("/repo/packages/core/reviewed.sha256"))).toBe("ask");
});

test("an edit of the agent settings, the hook or the check asks the user", () => {
	expect(decide(edit("/repo/.claude/settings.json"))).toBe("ask");
	expect(decide(edit("/repo/scripts/guard-reviewed-interfaces.sh"))).toBe("ask");
	expect(decide(edit("/repo/scripts/check-reviewed-interfaces.sh"))).toBe("ask");
});

test("a write of any other file passes without a decision", () => {
	expect(decide({ tool_name: "Write", tool_input: { file_path: "/repo/packages/core/lib/fan.mli" } })).toBeNull();
});

test("a shell command that names a guarded file asks the user", () => {
	expect(decide(bash("sha256sum packages/core/lib/fan.mli >> packages/core/reviewed.sha256"))).toBe("ask");
	expect(decide(bash("sed -i 's/x/y/' .claude/settings.json"))).toBe("ask");
});

test("a shell command that names no guarded file passes without a decision", () => {
	expect(decide(bash("dune build"))).toBeNull();
});
