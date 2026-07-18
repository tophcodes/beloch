import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { PRESETS, renderCP } from "@beloch/render-svg";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

test("bisect-a CP: faces, colored creases, named constructions, legend", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderCP(scene, { legend: true }).toString();
  // layers in order
  expect(s.indexOf('data-layer="paper"')).toBeLessThan(s.indexOf('data-layer="creases"'));
  expect(s.indexOf('data-layer="creases"')).toBeLessThan(s.indexOf('data-layer="annotations"'));
  // 3 faces
  expect((s.match(/data-kind="face"/g) ?? []).length).toBe(3);
  // 9 edges as crease lines
  expect((s.match(/data-kind="crease"/g) ?? []).length).toBe(9);
  // named crease edge carries its name; `mark --v = ...` defaults to valley
  // (no `mountain` keyword — see lib/parser.mly mark_clauses), so it gets the
  // valley class, not an "unassigned" one (bisect-a.bel has no F/U edges at
  // all since the notation-cutover rewrite to mark/fold, commit 818ed9e).
  expect(s).toContain('data-name="v"');
  expect(s).toContain('class="crease-V"');
  // named crease "v" has no step provenance -> null step serializes as data-step=""
  expect(s).toContain('data-step=""');
  // crease label text --v, corner labels .a
  expect(s).toContain(">--v</text>");
  expect(s).toContain(">.a</text>");
  // legend lists assignments present (boundary + valley), not axiom provenance
  expect(s).toContain("boundary");
  expect(s).toContain("valley");
});

test("no --labels: no overlay at all, even for named creases/corners", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderCP(scene).toString();
  expect(s).not.toContain('class="construction"');
});

test("explicit --labels draws exactly what's named, even a crease-duplicate or a corner", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderCP(scene, { labels: ["--v", ".a"] }).toString();
  // "v" IS a crease and "a" IS a paper corner — explicit request still draws both
  expect(s).toContain('data-construction="v"');
  expect(s).toContain('data-construction="a"');
});

test("labels selection narrows rendering", async () => {
  const scene = parseFold(await golden("x-midpoint.fold"));
  const none = renderCP(scene).toString();
  const some = renderCP(scene, { labels: ["--d1"] }).toString();
  expect((none.match(/class="construction"/g) ?? []).length).toBe(0);
  expect((some.match(/class="construction"/g) ?? []).length).toBeGreaterThan(0);
});

test("title renders in hud layer", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderCP(scene, { title: "bisect-a.bel" }).toString();
  expect(s).toContain(">bisect-a.bel</text>");
});

test("theme override changes crease color", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderCP(scene, { theme: { boundary: "#000001" } }).toString();
  expect(s).toContain("#000001");
});

test("bisect-a CP golden snapshot", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  expect(renderCP(scene).toString()).toMatchSnapshot();
});

test("crease lines carry a crease-M/crease-V class per assignment", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const s = renderCP(scene).toString();
  expect(s).toContain('class="crease-M"');
  expect(s).toContain('class="crease-V"');
});

test("legend hidden by default", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderCP(scene).toString();
  expect(s).not.toContain('class="legend-panel"');
});

test("legend: true shows the legend panel", async () => {
  const scene = parseFold(await golden("bisect-a.fold"));
  const s = renderCP(scene, { legend: true }).toString();
  expect(s).toContain('class="legend-panel"');
});

test("legend lists exactly the assignment classes present, including F", async () => {
  const scene = parseFold(await golden("legend-full.fold"));
  const s = renderCP(scene, { legend: true }).toString();
  expect(s).toContain(">boundary</text>");
  expect(s).toContain(">mountain</text>");
  expect(s).toContain(">valley</text>");
  expect(s).toContain(">flat</text>");
  expect(s).not.toContain(">unassigned</text>");
});

test("legend omits flat when the FOLD carries no F edges", async () => {
  const scene = parseFold(await golden("fold-quarter.fold")); // B/M/V only
  const s = renderCP(scene, { legend: true }).toString();
  expect(s).toContain(">boundary</text>");
  expect(s).toContain(">mountain</text>");
  expect(s).toContain(">valley</text>");
  expect(s).not.toContain(">flat</text>");
});

test("legend swatch styling follows the active theme.lineStyle preset", async () => {
  const scene = parseFold(await golden("legend-full.fold"));
  const s = renderCP(scene, { legend: true, theme: { lineStyle: PRESETS.mono! } }).toString();
  // mono's F swatch: stroke=ink, dasharray "1 3", opacity 0.4
  expect(s).toContain('stroke-dasharray="1 3"');
});

test("CP stamps data-bel-name on named creases and named vertex dots", async () => {
  const scene = parseFold(await golden("x-midpoint.fold"));
  const s = renderCP(scene).toString();
  expect(s).toContain('data-bel-name="center"');            // the named crossing vertex
  expect(s).toMatch(/data-bel-name="d1"|data-bel-name="d2"/); // a named diagonal crease
});
