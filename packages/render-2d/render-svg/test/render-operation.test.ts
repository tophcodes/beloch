import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderCandidates, renderOperation } from "@beloch/render-svg";

// Written with `beloch fold --trace`: the preliminary base by two inside
// reverse folds, the same base by one flatten with `toward`, and a pocket tuck.
const fixture = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

const count = (s: string, re: RegExp) => (s.match(re) ?? []).length;

test("the writes of a traced file are parsed apart from its constructions", async () => {
  const scene = parseFold(await fixture("trace-reverse.fold"));
  expect(scene.writeTrace.map((e) => e.terms.write)).toEqual(["fold", "reverse", "reverse"]);
  expect(scene.trace.every((e) => typeof e.axiom === "string")).toBe(true);
  const rev = scene.writeTrace[1]!;
  expect(rev.frameIndex).toBe(1);
  expect(rev.candidates[0]!.frame).not.toBeNull();
});

test("a fold's operation view draws its moving set and axis, then the state after", async () => {
  const scene = parseFold(await fixture("trace-reverse.fold"));
  const s = renderOperation(scene, { statement: 0 }).toString();
  expect(count(s, /data-kind="moving"/g)).toBe(1);
  expect(count(s, /data-kind="axis"/g)).toBeGreaterThanOrEqual(1);
  expect(s).toContain("fold · top");
  expect(s).toContain("after");
});

test("a reverse fold's operation view draws the spine, halves and bodies", async () => {
  const scene = parseFold(await fixture("trace-reverse.fold"));
  const s = renderOperation(scene, { statement: 1 }).toString();
  expect(count(s, /data-kind="spine"/g)).toBe(1);
  expect(count(s, /data-kind="half-outline"/g)).toBeGreaterThanOrEqual(2);
  expect(count(s, /data-kind="body-outline"/g)).toBeGreaterThanOrEqual(2);
  expect(s).toContain("reverse · inside");
});

test("a tuck draws the region it is placed against", async () => {
  const scene = parseFold(await fixture("trace-tuck.fold"));
  const s = renderOperation(scene).toString();
  expect(s).toContain("fold · under");
  expect(count(s, /data-kind="target"/g)).toBeGreaterThanOrEqual(1);
});

test("a flatten's operation view draws the vertex, the rays and the stayer", async () => {
  const scene = parseFold(await fixture("trace-flatten.fold"));
  const s = renderOperation(scene).toString();
  expect(count(s, /data-kind="vertex"/g)).toBe(1);
  expect(count(s, /data-kind="ray"/g)).toBe(6);
  expect(count(s, /data-kind="stayer"/g)).toBe(1);
});

test("the candidates of a flatten are its states, in rows of four", async () => {
  const scene = parseFold(await fixture("trace-flatten.fold"));
  const doc = renderCandidates(scene);
  const n = scene.writeTrace[0]!.candidates.length;
  const s = doc.toString();
  expect(count(s, /data-status="selected"/g)).toBe(1);
  expect(count(s, /data-status="removed: mountains"/g)).toBeGreaterThanOrEqual(1);
  expect(doc.width).toBe(4 * 572);
  expect(doc.height).toBe(Math.ceil(n / 4) * 572);
});

test("the candidates of a fold's statement are its construction's lines", async () => {
  const scene = parseFold(await fixture("trace-reverse.fold"));
  const s = renderCandidates(scene, { statement: 0 }).toString();
  expect(count(s, /data-kind="candidate"/g)).toBe(1);
});

test("a statement that runs no write says so", async () => {
  const scene = parseFold(await fixture("trace-tuck.fold"));
  expect(() => renderOperation(scene, { statement: 1 })).toThrow("runs no fold, reverse or flatten");
});
