import { test, expect } from "bun:test";

const CLI = new URL("../bin/fold2svg.ts", import.meta.url).pathname;
const FIX = new URL("../../../tests/golden/syntax/fold-quarter.fold", import.meta.url).pathname;

test("CLI: fold → SVG on stdout", async () => {
  const p = Bun.spawn(["bun", CLI, FIX]);
  const out = await new Response(p.stdout).text();
  expect(await p.exited).toBe(0);
  expect(out).toStartWith("<svg");
});

test("CLI: --folded → folded view PNG file", async () => {
  const out = `${process.env.TMPDIR ?? "/tmp"}/beloch-cli-test.png`;
  const p = Bun.spawn(["bun", CLI, FIX, out, "--folded"]);
  expect(await p.exited).toBe(0);
  const bytes = new Uint8Array(await Bun.file(out).arrayBuffer());
  // PNG magic
  expect([...bytes.slice(0, 4)]).toEqual([0x89, 0x50, 0x4e, 0x47]);
});

test("CLI: stdin input", async () => {
  const p = Bun.spawn(["bun", CLI, "-"], { stdin: Bun.file(FIX) });
  const out = await new Response(p.stdout).text();
  expect(await p.exited).toBe(0);
  expect(out).toStartWith("<svg");
});
