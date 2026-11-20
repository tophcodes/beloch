import { test, expect } from "bun:test";
import { join } from "node:path";

const script = join(import.meta.dir, "guard-reviewed-interfaces.sh");
const list = "packages/core/reviewed.sha256";

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
	expect(decide(edit(`/repo/${list}`))).toBe("ask");
});

test("an edit of any other file passes without a decision", () => {
	expect(decide(edit("/repo/.claude/settings.json"))).toBeNull();
	expect(decide(edit("/repo/scripts/guard-reviewed-interfaces.sh"))).toBeNull();
	expect(decide({ tool_name: "Write", tool_input: { file_path: "/repo/packages/core/lib/fan.mli" } })).toBeNull();
});

test("a shell command that writes the hash list asks the user", () => {
	for (const command of [
		`sha256sum packages/core/lib/fan.mli >> ${list}`,
		`sha256sum packages/core/lib/fan.mli >${list}`,
		`echo x > ./${list}`,
		`sha256sum packages/core/lib/fan.mli | tee -a ${list}`,
		`sed -i 's/x/y/' ${list}`,
		`perl -pi -e 's/x/y/' ${list}`,
		`cp /tmp/list ${list}`,
		`mv /tmp/list ${list}`,
		`mv ${list} /tmp/list`,
		`truncate -s 0 ${list}`,
		`dune build && rm ${list}`,
	]) {
		expect([command, decide(bash(command))]).toEqual([command, "ask"]);
	}
});

test("a shell command that only reads the hash list passes without a decision", () => {
	for (const command of [
		`cat ${list}`,
		`git show main:${list}`,
		`rg fan ${list}`,
		`less ${list}`,
		`sha256sum ${list}`,
		`cp ${list} /tmp/list`,
		`sed -n 1p ${list}`,
		`cat ${list} > /tmp/list`,
		`cat ${list} 2>/dev/null | wc -l`,
		`rm /tmp/x; cat ${list}`,
	]) {
		expect([command, decide(bash(command))]).toEqual([command, null]);
	}
});

test("a shell command that names no hash list passes without a decision", () => {
	expect(decide(bash("dune build"))).toBeNull();
	expect(decide(bash("sed -i 's/x/y/' .claude/settings.json"))).toBeNull();
});
