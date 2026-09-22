import { test, expect } from "bun:test";
import { parseFold, type FoldScene, type SourceRef } from "@beloch/scene";
import { entitiesAtLine, lineOfSpan, parseSpan, refSpansFor, sourceLineOf } from "../src/index";
import type { EntityRef } from "@beloch/runtime";

// paper square / --diag / fold as --bd / .m / --slant / fold as --ac
// `--bd` is crease 0, built on line 3 and named again on line 4; `--ac` is
// crease 1, built on line 6.
const scene: FoldScene = parseFold(
  await Bun.file(
    new URL("../../render-dom/test/fixtures/constructions.fold", import.meta.url),
  ).text(),
);

const crease = (id: string): EntityRef => ({ kind: "crease", creaseId: id });
const edge = (name: string): EntityRef => ({ kind: "edge", name });

// A scene carrying references to a paper boundary, which the fixture program
// never names.
const withRefs = (references: SourceRef[]): FoldScene => ({ ...scene, references });

test("a span on one line reads its line and column range", () => {
  expect(parseSpan("prog.bel:4:14-18")).toEqual({ fromLine: 4, fromCol: 14, toLine: 4, toCol: 18 });
});

test("a span across two lines reads both of them", () => {
  expect(parseSpan("prog.bel:4:14-6:3")).toEqual({ fromLine: 4, fromCol: 14, toLine: 6, toCol: 3 });
});

test("a path with colons in it does not confuse the span", () => {
  expect(parseSpan("C:/tmp/prog.bel:4:14-18")?.fromLine).toBe(4);
});

test("something that is not a span reads as nothing", () => {
  expect(parseSpan("prog.bel")).toBeNull();
  expect(lineOfSpan(null)).toBeNull();
});

test("a selected crease is marked where the program names it", () => {
  expect(refSpansFor(scene, [crease("0")]).map(lineOfSpan)).toEqual([4]);
});

test("a crease the program never names again is marked nowhere", () => {
  expect(refSpansFor(scene, [crease("1")])).toEqual([]);
});

test("selecting nothing marks nothing", () => {
  expect(refSpansFor(scene, [])).toEqual([]);
});

test("a selected paper boundary is marked where the program names the edge", () => {
  const s = withRefs([{ span: "prog.bel:5:3-7", creaseId: null, edge: "ab" }]);
  expect(refSpansFor(s, [edge("ab")])).toEqual(["prog.bel:5:3-7"]);
  expect(refSpansFor(s, [edge("bc")])).toEqual([]);
});

test("several selected entities are marked together", () => {
  const s = withRefs([
    { span: "prog.bel:4:14-18", creaseId: 0, edge: null },
    { span: "prog.bel:5:3-7", creaseId: null, edge: "ab" },
  ]);
  expect(refSpansFor(s, [crease("0"), edge("ab")])).toEqual(["prog.bel:4:14-18", "prog.bel:5:3-7"]);
});

test("a face and a vertex are named nowhere in the source", () => {
  expect(refSpansFor(scene, [{ kind: "face", index: "0" }])).toEqual([]);
  expect(refSpansFor(scene, [{ kind: "vertex", index: 2, name: "m" }])).toEqual([]);
});

test("the line a crease was built on is where the step mark goes", () => {
  expect(sourceLineOf(scene, crease("0"))).toBe(3);
  expect(sourceLineOf(scene, crease("1"))).toBe(6);
});

test("a paper boundary was built by no statement", () => {
  expect(sourceLineOf(scene, edge("ab"))).toBeNull();
});

test("a crease the document does not carry has no line", () => {
  expect(sourceLineOf(scene, crease("99"))).toBeNull();
});

test("the cursor on a statement's line selects what that line built", () => {
  expect(entitiesAtLine(scene, 3)).toEqual([crease("0")]);
  expect(entitiesAtLine(scene, 6)).toEqual([crease("1")]);
});

test("the cursor on a line that built nothing selects nothing", () => {
  expect(entitiesAtLine(scene, 1)).toEqual([]);
  expect(entitiesAtLine(scene, 4)).toEqual([]);
});

test("a document without inspect data answers both directions with nothing", () => {
  const bare: FoldScene = { ...scene, inspect: null };
  expect(entitiesAtLine(bare, 3)).toEqual([]);
  expect(sourceLineOf(bare, crease("0"))).toBeNull();
});
