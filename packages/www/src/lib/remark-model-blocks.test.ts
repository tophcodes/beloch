import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkMath from "remark-math";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import remarkModelBlocks from "./remark-model-blocks.ts";

const fixtures = join(import.meta.dir, "fixtures");
const model = join(fixtures, "model-blocks.md");
const register = join(fixtures, "api-register.json");
const figures = join(fixtures, "figures");

async function render(path: string, options: Record<string, string> = {}) {
  return String(
    await unified()
      .use(remarkParse)
      .use(remarkModelBlocks, options)
      .use(remarkMath)
      .use(remarkRehype, { allowDangerousHtml: true })
      .use(rehypeStringify, { allowDangerousHtml: true })
      .process(readFileSync(path, "utf8")),
  );
}

// The model document, rendered against the register: its statements carry the
// realizations the kernel's `@see` tags declare.
const html = await render(model, { register, model, figures });

// the links line of one statement section, by id
function links(id: string): string {
  const section = html.slice(html.indexOf(`id="${id}"`));
  const line = /<p class="stmt-links">(.*?)<\/p>/s.exec(section);
  return line ? line[1] : "";
}

function rels(id: string): string {
  const section = html.slice(html.indexOf(`id="${id}"`));
  const span = /<span class="stmt-rels" hidden(?:="")?>(.*?)<\/span>/s.exec(section);
  return span ? span[1] : "";
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
      ' resource="#def-flat-state" prefix="bm: https://beloch.toph.so/ns/model#">',
  );
  expect(html).toContain('<span class="stmt-name" property="bm:name">flat folded state</span>');
  expect(html).toContain(
    '<section class="term" id="term-table" typeof="bm:Term" resource="#term-table"' +
      ' prefix="bm: https://beloch.toph.so/ns/model#">',
  );
});

test("back references are derived from the forward ones, kept out of sight", () => {
  // Definition 1.1 is used by the lemma only; Definition 1.2 by the lemma and
  // the open point. Both directions live in a hidden span so that the RDFa
  // graph has them while the reader sees only the links in the text.
  expect(links("def-sheet")).not.toContain("Used by");
  expect(rels("def-sheet")).toContain(
    '<a rel="bm:usedBy" href="#lem-face-points">Lemma 2.1</a>',
  );
  expect(rels("def-flat-state")).toContain(
    '<a rel="bm:usedBy" href="#lem-face-points">Lemma 2.1</a>',
  );
  expect(rels("def-flat-state")).toContain('<a rel="bm:usedBy" href="#open-rank">Open 2.2</a>');
  expect(rels("lem-face-points")).toContain('<a rel="bm:uses" href="#def-sheet">Definition 1.1</a>');
  expect(links("lem-face-points")).not.toContain("Uses:");
});

test("defines and realized-by render on the links line", () => {
  expect(links("def-sheet")).toContain('Defines: <a rel="bm:defines" href="#term-face">face</a>');
  expect(links("def-sheet")).toContain(
    'Realized by: <a rel="bm:realizedBy" href="/api/beloch/Beloch/Sample/index.html' +
      '#type-violation.Taco_taco"><code>Sample.violation.Taco_taco</code></a>',
  );
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

test("figures are numbered on a counter of their own", () => {
  // Figure 1.1 sits between Definition 1.1 and Definition 1.2, and numbers
  // neither of them differently.
  expect(html).toContain('<span class="figure-label" property="bm:label">Figure 1.1</span>');
  expect(html).toContain('<span class="stmt-label" property="bm:label">Definition 1.2</span>');
});

test("a figure inlines the rendered view, the program and the caption", () => {
  const figure = html.slice(html.indexOf('id="fig-sheet"'), html.indexOf("Prose between"));
  expect(html).toContain(
    '<figure class="figure" id="fig-sheet" typeof="bm:Figure" resource="#fig-sheet"' +
      ' prefix="bm: https://beloch.toph.so/ns/model#">',
  );
  expect(figure).toContain('<div class="figure-view" data-view="cp">');
  expect(figure).toContain('<rect class="dummy-cp"');
  expect(figure).toContain(
    '<pre class="figure-source" property="bm:program">paper square\nmark --ac = through .a .c',
  );
  expect(figure).toContain("<figcaption>");
  expect(figure).toContain("A sheet, with the corner <em>.a</em> at the origin.");
});

test("a view with no rendered file becomes a placeholder, not a build failure", () => {
  const figure = html.slice(html.indexOf('id="fig-sheet"'), html.indexOf("Prose between"));
  expect(figure).toContain(
    '<p class="figure-missing">No rendered <code>folded</code> view for <code>fig-sheet</code>;' +
      " run scripts/render-figures.ts.</p>",
  );
});

test("[#id] in prose becomes a link carrying the computed label", () => {
  expect(html).toContain('<a href="#def-flat-state">Definition 1.2</a>');
  expect(html).toContain('<a href="#term-table">table</a>');
  expect(html).toContain('<a href="#fig-sheet">Figure 1.1</a>');
});

test("math and citations inside a block body survive", () => {
  const section = html.slice(html.indexOf('id="def-flat-state"'));
  expect(section).toContain('class="language-math math-inline"');
  expect(html).toContain("[@hull2020, chapter 6]");
});

test("a statement no kernel item points at has no Realized by line", () => {
  expect(links("lem-face-points")).not.toContain("Realized by");
});

test("without a register there are no Realized by lines", async () => {
  const bare = await render(model, { register: join(fixtures, "no-such-register.json"), model });
  expect(bare).not.toContain("Realized by");
});

test(".include renders the register entry with RDFa and a Realizes line", async () => {
  const included = await render(join(fixtures, "model-include.md"), { register, model });
  expect(included).toContain(
    '<div class="api-item" about="/api/beloch/Beloch/Sample/index.html#type-t"' +
      ' typeof="bm:CodeItem" prefix="bm: https://beloch.toph.so/ns/model#">',
  );
  expect(included).toContain("<code class=\"language-ocaml\">type t\n</code>");
  // the label comes from the model document's numbering, not from the register
  expect(included).toContain(
    '<p class="api-realizes">Realizes: <a rel="bm:realizes" href="/model/#def-flat-state">' +
      "Definition 1.2</a></p>",
  );
});

test(".include on a variant type lists its constructors", async () => {
  const included = await render(join(fixtures, "model-include.md"), { register, model });
  expect(included).toContain("Why a candidate is not a state.");
  expect(included).toContain(
    '<div class="api-member" about="/api/beloch/Beloch/Sample/index.html' +
      '#type-violation.Taco_taco" typeof="bm:CodeItem">',
  );
  expect(included).toContain('<code>| Taco_taco of int * int</code>');
  expect(included).toContain("hinges i and j interleave");
  expect(included).toContain('href="/model/#def-sheet">Definition 1.1</a>');
});

test("an item the register does not have renders a visible placeholder", async () => {
  const included = await render(join(fixtures, "model-include.md"), { register, model });
  expect(included).toContain(
    '<p class="api-missing">No API register entry for <code>Sample.missing</code>;' +
      " run scripts/api-register.ts.</p>",
  );
});
