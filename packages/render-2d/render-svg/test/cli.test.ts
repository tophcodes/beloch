import { test, expect } from "bun:test";

const CLI = new URL("../bin/fold2svg.ts", import.meta.url).pathname;
const FIX = new URL("./fixtures/fold-quarter.fold", import.meta.url).pathname;
const CUBE_ROOT = new URL("./fixtures/cube-root.fold", import.meta.url).pathname;

test("CLI: fold → SVG on stdout", async () => {
  const p = Bun.spawn(["bun", CLI, FIX]);
  const out = await new Response(p.stdout).text();
  expect(await p.exited).toBe(0);
  expect(out).toStartWith("<svg");
});

test("CLI: --view folded → folded view PNG file", async () => {
  const out = `${process.env.TMPDIR ?? "/tmp"}/beloch-cli-test.png`;
  const p = Bun.spawn(["bun", CLI, FIX, out, "--view", "folded"]);
  expect(await p.exited).toBe(0);
  const bytes = new Uint8Array(await Bun.file(out).arrayBuffer());
  // PNG magic
  expect([...bytes.slice(0, 4)]).toEqual([0x89, 0x50, 0x4e, 0x47]);
});

test("CLI: --view folded --flip renders a different SVG than unflipped", async () => {
  const top = Bun.spawn(["bun", CLI, FIX, "--view", "folded"]);
  const bottom = Bun.spawn(["bun", CLI, FIX, "--view", "folded", "--flip"]);
  const topOut = await new Response(top.stdout).text();
  const bottomOut = await new Response(bottom.stdout).text();
  expect(await top.exited).toBe(0);
  expect(await bottom.exited).toBe(0);
  expect(topOut).not.toBe(bottomOut);
});

test("CLI: unknown --view value exits 1 with a plain error", async () => {
  const p = Bun.spawn(["bun", CLI, FIX, "--view", "top"], { stderr: "pipe" });
  const err = await new Response(p.stderr).text();
  expect(await p.exited).toBe(1);
  expect(err).toContain("unknown --view value 'top' — expected cp or folded");
});

test("CLI: stdin input", async () => {
  const p = Bun.spawn(["bun", CLI, "-"], { stdin: Bun.file(FIX) });
  const out = await new Response(p.stdout).text();
  expect(await p.exited).toBe(0);
  expect(out).toStartWith("<svg");
});

test("CLI: --legend adds the legend panel", async () => {
  const p = Bun.spawn(["bun", CLI, FIX]);
  const without = await new Response(p.stdout).text();
  expect(await p.exited).toBe(0);
  const q = Bun.spawn(["bun", CLI, FIX, "--legend"]);
  const withLegend = await new Response(q.stdout).text();
  expect(await q.exited).toBe(0);
  expect(without).not.toContain('class="legend-panel"');
  expect(withLegend).toContain('class="legend-panel"');
});

test("CLI: unmatched --step exits 1 with the available named steps", async () => {
  const p = Bun.spawn(
    ["bun", CLI, CUBE_ROOT, "--view", "folded", "--step", "no-such-step"],
    { stderr: "pipe" },
  );
  const err = await new Response(p.stderr).text();
  expect(await p.exited).toBe(1);
  expect(err).toBe(
    "beloch-render: step 'no-such-step' not found — 5 step(s) available. " +
      "named steps are vertical_middle (2), thirds (3), beloch_fold (4)\n",
  );
});
