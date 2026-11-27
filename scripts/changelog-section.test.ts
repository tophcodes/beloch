import { test, expect } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const script = join(import.meta.dir, "changelog-section.sh");

const changelog = `# Changelog

Intro.

## [Unreleased]

Pending work.

## [0.2.0] - 2026-02-01

**Breaking.** Something moved.

Second paragraph.

## [0.1.0] - 2026-01-01

First.

[0.2.0]: https://example.org/v0.2.0
[0.1.0]: https://example.org/v0.1.0
`;

function section(version: string) {
	const dir = mkdtempSync(join(tmpdir(), "changelog-"));
	const file = join(dir, "CHANGELOG.md");
	writeFileSync(file, changelog);
	const run = Bun.spawnSync(["bash", script, version, file]);
	return { ok: run.exitCode === 0, out: run.stdout.toString(), err: run.stderr.toString() };
}

test("prints the body of a version without its heading", () => {
	const { ok, out } = section("0.2.0");
	expect(ok).toBe(true);
	expect(out).toBe("**Breaking.** Something moved.\n\nSecond paragraph.\n");
});

test("accepts the tag name with its v", () => {
	expect(section("v0.2.0").out).toBe(section("0.2.0").out);
});

test("the last section stops before the link definitions", () => {
	expect(section("0.1.0").out).toBe("First.\n");
});

test("a version without a section fails", () => {
	const { ok, err } = section("0.3.0");
	expect(ok).toBe(false);
	expect(err).toContain("0.3.0");
});

test("a version is not matched as a prefix of another", () => {
	expect(section("0.2").ok).toBe(false);
});
