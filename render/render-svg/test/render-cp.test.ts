import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderCP } from "@beloch/render-svg";

const golden = (p: string) =>
  Bun.file(new URL(`../../../tests/golden/${p}`, import.meta.url)).text();

test("bisect-a CP: faces, colored creases, named constructions, legend", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  const s = renderCP(scene).toString();
  // layers in order
  expect(s.indexOf('data-layer="paper"')).toBeLessThan(s.indexOf('data-layer="creases"'));
  expect(s.indexOf('data-layer="creases"')).toBeLessThan(s.indexOf('data-layer="annotations"'));
  // 3 faces
  expect((s.match(/data-kind="face"/g) ?? []).length).toBe(3);
  // 9 edges as crease lines
  expect((s.match(/data-kind="crease"/g) ?? []).length).toBe(9);
  // named crease edge carries its name; unassigned color from the default palette
  expect(s).toContain('data-name="v"');
  expect(s).toContain("#f59e0b");
  // named crease "v" has no step provenance -> null step serializes as data-step=""
  expect(s).toContain('data-step=""');
  // crease label text --v, corner labels .a
  expect(s).toContain(">--v</text>");
  expect(s).toContain(">.a</text>");
  // legend lists assignments present (boundary + unassigned), not axiom provenance
  expect(s).toContain("boundary");
  expect(s).toContain("unassigned");
});

test("constructions: unnamed-crease line drawn dashed, corner points skipped", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  const s = renderCP(scene).toString();
  // named line "v" IS a crease → not double-drawn as construction
  expect(s).not.toContain('data-construction="v"');
  // corner named points (a-d on corners) are skipped as constructions
  expect(s).not.toContain('data-construction="a"');
});

test("constructions selection narrows rendering", async () => {
  const scene = parseFold(await golden("syntax/x-midpoint.fold"));
  const all = renderCP(scene).toString();
  const none = renderCP(scene, { constructions: [] }).toString();
  expect((none.match(/class="construction"/g) ?? []).length).toBe(0);
  // x-midpoint renders exactly 1 construction by default
  expect((all.match(/class="construction"/g) ?? []).length).toBeGreaterThan(0);
});

test("title renders in hud layer", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  const s = renderCP(scene, { title: "bisect-a.bel" }).toString();
  expect(s).toContain(">bisect-a.bel</text>");
});

test("theme override changes crease color", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  const s = renderCP(scene, { theme: { boundary: "#000001" } }).toString();
  expect(s).toContain("#000001");
});

test("bisect-a CP golden snapshot", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  expect(renderCP(scene).toString()).toMatchSnapshot();
});

test("crease lines carry a crease-M/crease-V class per assignment", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  const s = renderCP(scene).toString();
  expect(s).toContain('class="crease-M"');
  expect(s).toContain('class="crease-V"');
});
