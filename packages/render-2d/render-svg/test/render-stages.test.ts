import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";
import { renderStages } from "@beloch/render-svg";

// The programs of the mockups on issue #63, each written with
// `beloch fold --trace` next to its .bel source.
const fixture = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

async function stages(name: string, opts: { stage?: number; checks?: boolean } = {}) {
  const scene = parseFold(await fixture(`stages-${name}.fold`));
  const source = await fixture(`stages-${name}.bel`);
  return renderStages(scene, { source, ...opts }).toString();
}

const count = (s: string, re: RegExp) => (s.match(re) ?? []).length;
const rows = (s: string) => [...s.matchAll(/data-stage="(\w+)" data-status="(\w+)"/g)].map((m) => `${m[1]}:${m[2]}`);
// the part of the document that draws one stage, or the closing block
const part = (s: string, key: string) => {
  const at = s.indexOf(key);
  if (at < 0) return "";
  const next = s.slice(at + 1).search(/data-stage=|data-kind="closing"|data-kind="legend"/);
  return s.slice(at, next < 0 ? undefined : at + 1 + next);
};
const stage = (s: string, name: string) => part(s, `data-stage="${name}"`);
// the words of the text rows, tags removed
const words = (s: string) =>
  [...s.matchAll(/<text[^>]*data-row="[^"]*"[^>]*>(.*?)<\/text>/g)]
    .map((m) => m[1]!.replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").trim()).join(" ");
const numbers = (s: string, status: string, kind = "number") =>
  [...s.matchAll(new RegExp(`data-kind="${kind}" data-index="(\\d+)" data-status="${status}"`, "g"))].map((m) => Number(m[1]));
const legend = (s: string) => [...s.matchAll(/data-legend="([\w-]+)"/g)].map((m) => m[1]);

test("every stage keeps its place: drawn where it is used, a short gray row where not", async () => {
  expect(rows(await stages("ax5-heading"))).toEqual(
    ["paper:drawn", "heading:drawn", "side:drawn", "moved:drawn", "landing:drawn"]);
  const e = await stages("ax5-ambiguous");
  expect(rows(e)).toEqual(["paper:drawn", "heading:skipped", "side:skipped", "moved:drawn", "landing:skipped"]);
  expect(stage(e, "heading")).toContain("Skipped, as the fold names no heading.");
  expect(stage(e, "side")).toContain("Skipped, as the fold names neither toward nor moving.");
  expect(stage(e, "landing")).toContain("Skipped, as the fold names no toward.");
  expect(stage(await stages("ax6-off-paper"), "landing")).toContain("Skipped, as only one candidate is left.");
});

test("stage titles name what the stage does", async () => {
  const s = await stages("ax5-heading");
  for (const t of ["Stage 0 · generate candidates", "Stage 1 · compare with the heading",
    "Stage 2 · name the folding side", "Stage 3 · check what the fold moves", "Stage 4 · measure the landing"]) {
    expect(s).toContain(t);
  }
});

test("the program lists the statements the drawn one reads, in order, and the statement last", async () => {
  const s = await stages("ax6-subject");
  const lines = [...s.matchAll(/data-kind="program"[^>]*>([^<]*)</g)].map((m) => m[1]);
  expect(lines).toEqual([
    "paper square", "mark (map .a onto .b) as --ef", "mark (through .b .d) as --bd",
    ".p = free on --bd from .d at 1/4", "fold (map .d onto --ef through .p) (.d toward .c) as --s",
  ]);
});

test("each stage underlines the part of the statement it reads", async () => {
  const s = await stages("ax5-heading");
  const reads = (name: string) =>
    [...stage(s, name).matchAll(/data-kind="reads">([^<]*)</g)].map((m) => m[1]);
  expect(reads("paper")).toEqual(["--v onto --h"]);
  expect(reads("heading")).toEqual(["heading --ab"]);
  expect(reads("side")).toEqual(["--v toward .u"]);
  expect(reads("moved")).toEqual(["--v onto --h"]);
  expect(reads("landing")).toEqual(["--v toward .u"]);
});

test("a line that creases no face is neither drawn nor numbered", async () => {
  const s = await stages("ax5-kite");
  expect(numbers(stage(s, "paper"), "(?:on|kept)")).toEqual([1]);
  expect(count(stage(s, "paper"), /data-kind="candidate"/g)).toBe(1);
});

test("a candidate's number keeps its state: outlined, crossed out where removed, filled where kept", async () => {
  const s = await stages("ax5-toward-edge");
  expect(numbers(stage(s, "paper"), "on")).toEqual([1, 2]);
  expect(numbers(stage(s, "side"), "out")).toEqual([2]);
  // removed at stage 2, candidate 2 is not drawn after it
  expect(numbers(stage(s, "moved"), "(?:on|out|kept)")).toEqual([1]);
  // the last stage drawn shows the line kept as the fold it makes
  expect(numbers(stage(s, "moved"), "kept")).toEqual([1]);
  expect(stage(s, "moved")).toMatch(/data-kind="candidate"[^>]*data-status="kept"/);
  expect(stage(s, "moved")).toContain('stroke-dasharray="7 4"');
});

test("stage 0 draws the construction of each axiom", async () => {
  const ax5 = stage(await stages("ax5-ambiguous"), "paper");
  expect(count(ax5, /data-kind="angle"/g)).toBe(2);
  expect(words(ax5)).toContain("halves the angle on the right");
  expect(words(ax5)).toContain("halves the angle at the top");
  const ax6 = stage(await stages("ax6-moving"), "paper");
  expect(count(ax6, /data-kind="construction"/g)).toBeGreaterThanOrEqual(2);
  expect(count(ax6, /data-kind="landing-line"/g)).toBe(2);
  expect(count(ax6, /data-kind="landing"/g)).toBe(2);
  expect(words(ax6)).toContain("one crease for each landing of .d");
  const ax7 = stage(await stages("ax7-heading"), "paper");
  expect(ax7).toContain("parabola: .a, --bd");
  expect(ax7).toContain("parabola: .u, --v");
  expect(words(ax7)).toContain("the three common tangents");
});

test("stage 1 gives each candidate its angle to the heading, and a tie passes on", async () => {
  const h = stage(await stages("ax7-heading"), "heading");
  expect(h).toContain("heading --ac");
  expect(words(h)).toContain("passes: 60° to --ac");
  expect(words(h)).toContain("eliminated: 90° to --ac");
  expect(words(h)).toContain("passes: 60° to --ac, a tie passes on");
  expect(numbers(h, "out")).toEqual([2]);
});

test("stage 2 hatches the side that folds over and marks the toward or moving item", async () => {
  const g = stage(await stages("ax5-heading"), "side");
  expect(count(g, /data-kind="folds-over"/g)).toBeGreaterThanOrEqual(2);
  expect(g).toContain('data-kind="target"');
  expect(g).toContain("toward .u");
  expect(words(g)).toContain("passes: .u lies on one side");
  const b = stage(await stages("ax6-moving"), "side");
  expect(b).toContain("moving .a");
  const f = stage(await stages("ax5-toward-edge"), "side");
  // an edge the stage reads is a rail inside the paper
  expect(f).toContain('data-kind="edge-reads"');
  expect(words(f)).toContain("eliminated: --ab crosses it, so it names no side");
});

test("stage 3 draws what each fold moves and where it lands, and what the paper cannot do", async () => {
  const b = stage(await stages("ax6-moving"), "moved");
  expect(count(b, /data-kind="moves"/g)).toBeGreaterThanOrEqual(2);
  expect(count(b, /data-kind="lands"/g)).toBeGreaterThanOrEqual(2);
  expect(b).toContain(".d′");
  expect(b).toContain("--ef′");
  expect(words(b)).toContain("passes: --ef folds over, and its paper at the dot lands on .d");
  expect(words(b)).toContain("passes: .d lands on --ef");
  const c = stage(await stages("ax6-off-paper"), "moved");
  expect(c).toContain('data-kind="missing"');
  expect(c).toContain("--ef has no paper here");
  expect(words(c)).toContain("eliminated: .d stays, and the paper of --ef that would land on it lies beyond the edge");
  // with neither toward nor moving, the result names the side and why
  const e = stage(await stages("ax5-ambiguous"), "moved");
  expect(words(e)).toContain("as the statement reads");
});

test("marks of several candidates that would cover each other get a square each", async () => {
  const g = stage(await stages("ax5-heading"), "moved");
  expect(count(g, /<svg /g)).toBe(2);
});

test("stage 4 measures the landing and names each distance", async () => {
  const g = stage(await stages("ax5-heading"), "landing");
  expect(count(g, /data-kind="distance"/g)).toBe(2);
  expect(words(g)).toContain("passes: --v lands 0.50 from .u");
  expect(words(g)).toContain("eliminated: --v lands 0.58 from .u");
  const h = stage(await stages("ax7-heading"), "landing");
  expect(words(h)).toContain("lands 0.09 from .w");
});

test("the closing block names the outcome, and what to write when several remain", async () => {
  const kept = part(await stages("ax5-heading"), 'data-kind="closing"');
  expect(words(kept)).toContain("holds");
  expect(numbers(kept, "kept", "row-number")).toEqual([1]);
  const amb = part(await stages("ax5-ambiguous"), 'data-kind="closing"');
  expect(words(amb)).toContain("both hold: ambiguous");
  expect(words(amb)).toContain("to keep it, add (toward --ab)");
  expect(words(amb)).toContain("to keep it, add (toward --bc)");
  const b = part(await stages("ax6-moving"), 'data-kind="closing"');
  expect(words(b)).toContain("to keep it, add (toward .d)");
});

test("--checks adds what each stage checks, and changes nothing in the drawing", async () => {
  const plain = await stages("ax5-heading");
  const checked = await stages("ax5-heading", { checks: true });
  expect(plain).not.toContain(">Checks<");
  expect(plain).not.toContain(">Constructs<");
  expect(count(checked, />Checks</g)).toBe(4);
  expect(checked).toContain(">Constructs<");
  expect(words(stage(checked, "landing"))).toContain("(--v toward .u) measures only --v");
  const drawing = (s: string) => [...s.matchAll(/<svg [^>]*>/g)].length;
  expect(drawing(checked)).toBe(drawing(plain));
});

test("--stage draws one stage with the program and the legend", async () => {
  const s = await stages("ax5-heading", { stage: 2 });
  expect(rows(s)).toEqual(["side:drawn"]);
  expect(s).toContain('data-kind="program"');
  expect(s).toContain('data-kind="legend"');
  expect(s).not.toContain('data-kind="closing"');
});

test("the legend shows only the marks the figure uses", async () => {
  const e = legend(await stages("ax5-ambiguous"));
  expect(e).toContain("candidate");
  expect(e).toContain("moves-line");
  expect(e).not.toContain("distance");
  expect(e).not.toContain("target");
  const c = legend(await stages("ax6-off-paper"));
  expect(c).toContain("missing");
  expect(c).toContain("removed");
  expect(c).toContain("kept");
});

test("a value shows as many decimals as tell it apart, at least two", async () => {
  const h = words(stage(await stages("ax7-heading"), "landing"));
  expect(h).toMatch(/lands 0\.\d{2} from \.w/);
});
