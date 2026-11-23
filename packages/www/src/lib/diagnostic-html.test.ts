import { test, expect } from "bun:test";
import { diagnosticHtml } from "./diagnostic-html";

const DIAGNOSTIC = `error: undefined crease --diagonal
 --> fold.bel:3:30
  |
3 | fold (map .b onto .d) (up to --diagonal)
  |                              ^^^^^^^^^^ undefined crease --diagonal
  = help: in scope: --ab --bc --cd --da --diag`;

test("every line keeps its text, and each part takes its color", async () => {
  const lines = await diagnosticHtml(DIAGNOSTIC);
  const text = lines.map((l) => l.replace(/<[^>]+>/g, "").replace(/&gt;/g, ">"));
  expect(text).toEqual(DIAGNOSTIC.split("\n"));
  expect(lines[0]).toStartWith('<span class="dg-error">error</span>:');
  expect(lines[3]).toContain('<span class="bel-line" data-bel-name="diagonal">--diagonal</span>');
  expect(lines[4]).toContain('<span class="dg-error">^^^^^^^^^^ undefined crease --diagonal</span>');
  expect(lines[5]).toContain('<span class="dg-help">help</span>');
});
