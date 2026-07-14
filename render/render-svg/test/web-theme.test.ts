import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderCP, WEB_THEME } from "@beloch/render-svg";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

test("renderCP with WEB_THEME emits CSS-var paper + ink fills", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const svg = renderCP(scene, { theme: WEB_THEME }).toString();
  expect(svg).toContain('fill="var(--bel-paper-cp, #f8fafc)"');
  expect(svg).toContain('fill="var(--bel-ink, #0f172a)"');
  expect(svg).toContain('stroke="var(--bel-boundary, #1f2937)"');
});

test("renderCP without a theme keeps the concrete hex (headless-safe)", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const svg = renderCP(scene).toString();
  expect(svg).toContain('fill="#f8fafc"');
  expect(svg).not.toContain("var(--bel-");
});
