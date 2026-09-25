import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderCandidates, renderCP } from "@beloch/render-svg";

// The largest equilateral triangle in the square [ida2020, Fig. 2.17]: fold .d
// onto --ef through .a has two solutions. Written with `beloch fold --trace`.
const fixture = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

const count = (s: string, re: RegExp) => (s.match(re) ?? []).length;

test("an ambiguous construction draws one panel per candidate, both open", async () => {
  const scene = parseFold(await fixture("trace-triangle-ambiguous.fold"));
  expect(scene.error?.message).toContain("two folds");
  const s = renderCandidates(scene).toString();
  expect(count(s, /data-kind="candidate"/g)).toBe(2);
  expect(count(s, /data-status="open"/g)).toBe(2);
  expect(s).toContain("1 · open");
  expect(s).toContain("2 · open");
});

test("the parabola behind the candidates is drawn on every panel", async () => {
  const scene = parseFold(await fixture("trace-triangle-ambiguous.fold"));
  const s = renderCandidates(scene).toString();
  expect(count(s, /data-kind="conic"/g)).toBeGreaterThanOrEqual(2);
});

test("with toward, one candidate is selected and the other removed", async () => {
  const scene = parseFold(await fixture("trace-triangle-toward.fold"));
  const s = renderCandidates(scene, { statement: 1 }).toString();
  expect(s).toContain('data-status="selected"');
  expect(s).toContain('data-status="removed by toward"');
  expect(count(s, /data-kind="toward"/g)).toBe(2);
});

test("the candidates of a fold are drawn on the state before it", async () => {
  const scene = parseFold(await fixture("trace-triangle-toward.fold"));
  const entry = scene.trace.find((e) => e.statement === 1)!;
  expect(entry.frameIndex).toBe(0);
  expect(scene.statements[1]!.frameIndex).toBe(1);
});

test("a file without a trace says how to get one", async () => {
  const scene = parseFold(await fixture("bisect-a.fold"));
  expect(() => renderCandidates(scene)).toThrow("beloch fold --trace");
  expect(() => renderCP(scene)).not.toThrow();
});
