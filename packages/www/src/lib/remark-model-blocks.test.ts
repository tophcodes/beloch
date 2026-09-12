import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkMath from "remark-math";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import remarkModelBlocks from "./remark-model-blocks.ts";

const fixture = readFileSync(join(import.meta.dir, "fixtures", "model-blocks.md"), "utf8");

const html = String(
  await unified()
    .use(remarkParse)
    .use(remarkModelBlocks)
    .use(remarkMath)
    .use(remarkRehype, { allowDangerousHtml: true })
    .use(rehypeStringify, { allowDangerousHtml: true })
    .process(fixture),
);

// the links line of one statement section, by id
function links(id: string): string {
  const section = html.slice(html.indexOf(`id="${id}"`));
  const line = /<p class="stmt-links">(.*?)<\/p>/s.exec(section);
  return line ? line[1] : "";
}

test("statements are numbered per section, shared across classes", () => {
  expect(html).toContain('<span class="stmt-label" property="bm:label">Definition 1.1</span>');
  expect(html).toContain('<span class="stmt-label" property="bm:label">Definition 1.2</span>');
  expect(html).toContain('<span class="stmt-label" property="bm:label">Lemma 2.1</span>');
  expect(html).toContain('<span class="stmt-label" property="bm:label">Open 2.2</span>');
});

test("statement sections carry RDFa and keep their id", () => {
  expect(html).toContain(
    '<section class="stmt stmt-definition" id="def-flat-state" typeof="bm:Definition"' +
      ' resource="#def-flat-state" prefix="bm: https://beloch.dev/model#">',
  );
  expect(html).toContain('<span class="stmt-name" property="bm:name">flat folded state</span>');
  expect(html).toContain(
    '<section class="term" id="term-table" typeof="bm:Term" resource="#term-table"' +
      ' prefix="bm: https://beloch.dev/model#">',
  );
});

test("back references are derived from the forward ones", () => {
  // Definition 1.1 is used by the lemma only; Definition 1.2 by the lemma and
  // the open point.
  expect(links("def-sheet")).toContain(
    'Used by: <a rel="bm:usedBy" href="#lem-face-points">Lemma 2.1</a>',
  );
  expect(links("def-flat-state")).toContain(
    'Used by: <a rel="bm:usedBy" href="#lem-face-points">Lemma 2.1</a>, ' +
      '<a rel="bm:usedBy" href="#open-rank">Open 2.2</a>',
  );
  expect(links("lem-face-points")).toContain(
    'Uses: <a rel="bm:uses" href="#def-sheet">Definition 1.1</a>, ' +
      '<a rel="bm:uses" href="#def-flat-state">Definition 1.2</a>',
  );
});

test("defines and realized-by render on the links line", () => {
  expect(links("def-sheet")).toContain('Defines: <a rel="bm:defines" href="#term-face">face</a>');
  expect(links("def-sheet")).toContain('Realized by: <code property="bm:realizedBy">Paper.make</code>');
  // a term's own defined-by is the same relation written from the other end
  expect(links("def-flat-state")).toContain(
    'Defines: <a rel="bm:defines" href="#term-table">table</a>, ' +
      '<a rel="bm:defines" href="#term-hinge">hinge</a>',
  );
});

test("the Terms section is generated, alphabetical, with Defined in links", () => {
  const glossary = html.slice(html.indexOf('id="term-face"'));
  const order = [...glossary.matchAll(/<span class="term-name" property="bm:name">([^<]+)</g)].map(
    (m) => m[1],
  );
  expect(order).toEqual(["face", "hinge", "table"]);
  expect(glossary).toContain(
    'Defined in <a rel="bm:definedBy" href="#def-flat-state">Definition 1.2</a>',
  );
  expect(glossary).toContain(
    'Defined in <a rel="bm:definedBy" href="#def-sheet">Definition 1.1</a>',
  );
  // the glossary sits under the Terms heading, ahead of References
  expect(html.indexOf("Terms</h2>")).toBeLessThan(html.indexOf('id="term-face"'));
  expect(html.indexOf('id="term-table"')).toBeLessThan(html.indexOf("References</h2>"));
});

test("terms are moved out of the running text", () => {
  // the only occurrence of each term section is the glossary one
  expect(html.split('id="term-table"').length - 1).toBe(1);
});

test("[#id] in prose becomes a link carrying the computed label", () => {
  expect(html).toContain('<a href="#def-flat-state">Definition 1.2</a>');
  expect(html).toContain('<a href="#term-table">table</a>');
});

test("math and citations inside a block body survive", () => {
  const section = html.slice(html.indexOf('id="def-flat-state"'));
  expect(section).toContain('class="language-math math-inline"');
  expect(html).toContain("[@hull2020, chapter 6]");
});
