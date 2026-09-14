import { test, expect } from "bun:test";
import { highlightBel } from "./highlight-bel";

test("variable tokens get data-bel-name, non-variables don't", async () => {
  const html = await highlightBel(
    "paper square\nmark --d1 = through .a .c\n.center = --d1 * --d2\n",
  );
  expect(html).toContain('data-bel-name="d1"');
  expect(html).toContain('data-bel-name="center"');
  expect(html).toContain('data-bel-name="a"');
  // keyword 'through' must not be tagged
  expect(html).not.toMatch(/data-bel-name="through"/);
});

test("bracket operators are not tagged as variables", async () => {
  const html = await highlightBel("paper square\n.center = .[--d1 --d2]\n");
  // the '.[' meet-bracket must not produce data-bel-name="["
  expect(html).not.toContain('data-bel-name="["');
});

test("item heads get their capture classes, operand names keep data-bel-name", async () => {
  const html = await highlightBel(
    "fold (map .a onto .c) (moving .a) (mountain)\n",
  );
  expect(html).toContain('<span class="bel-construction">map</span>');
  expect(html).toContain('<span class="bel-anchor">moving</span>');
  expect(html).toContain('<span class="bel-intent">mountain</span>');
  expect(html).toContain('data-bel-name="a"');
});

test("verb keywords and item parentheses are highlighted", async () => {
  const html = await highlightBel("fold (map .a onto .c) as --f\n");
  expect(html).toContain('<span class="bel-keyword">fold</span>');
  expect(html).toContain('<span class="bel-punct">(</span>');
  expect(html).toContain('<span class="bel-punct">)</span>');
});

// A head word that no query reaches falls out of every span and renders
// unstyled. The program below covers the whole vocabulary, so anything left
// outside a span is a query that is missing or bound to the wrong parent.
// Every literal in highlights.scm must appear here at least once: a word only
// this program omits is a word this guard cannot protect.
test("no token in a program covering every head word renders unclassified", async () => {
  const src = [
    "paper square",
    "mark (align --f (.a onto .c) (through .b) (perp --l) toward .q) as --g!",
    "fold (map .a onto --cd and .c onto --da) (moving .a) (up to .c) (over .b) (mountain) into --h",
    "fold (map .a onto --cd through .o toward .q) (between .m .o) (at .x) (on #[.c])",
    "reverse (outside) (--d valley)",
    "flatten (--l mountain) (.q over .r) (staying .a) (toward .b)",
    "flip (--d mountain) (under .p) (valley) as --k",
    "mark (perp --l through .p)",
    "flatten (--l valley) (moving [.a .b])",
    "; a trailing comment",
  ].join("\n");
  const html = await highlightBel(src);
  const outsideSpans = html.replace(
    /<span class="bel-[a-z]+"(?: data-bel-name="[^"]*")?>[^<]*<\/span>/g,
    "",
  );
  expect(outsideSpans.replace(/\s+/g, "")).toBe("");
});
