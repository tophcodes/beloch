import { test, expect } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildGrammarRegister } from "./grammar-register.ts";

const root = join(import.meta.dir, "..");
const fixture = "packages/www/src/lib/fixtures/grammar-blocks.md";
const filter = join(root, "scripts", "grammar-blocks.lua");

const pandoc = Bun.which("pandoc");

function typst(): string {
	const dir = mkdtempSync(join(tmpdir(), "grammar-lua-"));
	const registerPath = join(dir, "grammar.json");
	writeFileSync(registerPath, JSON.stringify(buildGrammarRegister([fixture])));
	const run = Bun.spawnSync(
		[pandoc as string, join(root, fixture), "--from", "markdown", "--to", "typst",
		 "--lua-filter", filter],
		{ cwd: root, env: { ...process.env, BELOCH_GRAMMAR_REGISTER: registerPath } },
	);
	if (run.exitCode !== 0) throw new Error(run.stderr.toString());
	expect(run.stderr.toString()).toBe("");
	return run.stdout.toString();
}

test.skipIf(!pandoc)("the typst writer gets raw spans, links and labels", () => {
	const out = typst();
	expect(out).toContain('#raw(lang:"gr-keyword", "\\"moving\\"")');
	expect(out).toContain('#raw(lang:"gr-token", "CREASE_NAME")');
	expect(out).toContain('#raw(lang:"gr-comment", "; a placed fold")');
	expect(out).toContain("#link(<rule-axis>)");
	expect(out).toContain("<rule-fold_item>");
});

test.skipIf(!pandoc)("every label occurs once, so typst can resolve every link", () => {
	const out = typst();
	// `<rule-x>` is typst's label syntax, used both to attach a label
	// (`content<rule-x>`) and to build the label value a link targets
	// (`#link(<rule-x>)`). Only the attachment sites must be unique; a link
	// target is excluded here since a rule is linked from every place that
	// refers to it.
	const labels = [...out.matchAll(/(?<!#link\()<(rule-[a-z_]+)>/g)].map((m) => m[1]);
	expect(new Set(labels).size).toBe(labels.length);
	const linked = new Set([...out.matchAll(/#link\(<(rule-[a-z_]+)>\)/g)].map((m) => m[1]));
	for (const target of linked) expect(labels).toContain(target);
});

test.skipIf(!pandoc)("a missing register warns instead of rendering silently", () => {
	const dir = mkdtempSync(join(tmpdir(), "grammar-lua-"));
	const registerPath = join(dir, "does-not-exist.json");
	const run = Bun.spawnSync(
		[pandoc as string, join(root, fixture), "--from", "markdown", "--to", "typst",
		 "--lua-filter", filter],
		{ cwd: root, env: { ...process.env, BELOCH_GRAMMAR_REGISTER: registerPath } },
	);
	expect(run.stderr.toString()).toContain("run scripts/grammar-register.ts");
});

test.skipIf(!pandoc)("the collected copy carries the rules and no second label", () => {
	const out = typst();
	// Same distinction as above: the collected copy links back to fold_item's
	// definition rather than attaching a second label there.
	const defs = [...out.matchAll(/(?<!#link\()<rule-fold_item>/g)];
	expect(defs.length).toBe(1);
	expect(out).toContain("Used by:");
});
