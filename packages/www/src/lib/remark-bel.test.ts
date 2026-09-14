import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import remarkBel from "./remark-bel.ts";

const fixtures = join(import.meta.dir, "fixtures");
const doc = join(fixtures, "remark-bel.md");
const blocksWithEntries = join(fixtures, "remark-bel-blocks.json");

// The fixture is processed as a plain string, not a real file on disk, so it
// carries no `file.path` for remark-bel.ts's file-path doc detection to key
// off; passing `doc` explicitly is the same override a caller with a real
// document uses to pin it (see remark-bel.ts's `options.doc`).
async function render(blocks: string): Promise<string> {
  return String(
    await unified()
      .use(remarkParse)
      .use(remarkBel, { blocks, doc: "spec/BELOCH.md" })
      .use(remarkRehype, { allowDangerousHtml: true })
      .use(rehypeStringify, { allowDangerousHtml: true })
      .process(readFileSync(doc, "utf8")),
  );
}

// Isolates the single `<pre class="bel-outcome ...">...</pre>` (or `<div
// class="bel-outcome ...">`) element that contains `marker`, so an assertion
// about one block's rendering does not accidentally hold or break over
// another block's markup elsewhere in the document.
function outcomeBlockContaining(html: string, marker: string): string {
  const re = /<(pre|div) class="bel-outcome[^>]*>[\s\S]*?<\/\1>/g;
  const found = [...html.matchAll(re)].find((m) => m[0].includes(marker));
  if (!found) throw new Error(`no bel-outcome block found containing ${JSON.stringify(marker)}`);
  return found[0];
}

// Same idea, but for one `<div class="bel-assert ...">` row nested inside a
// `.bel-outcome-ok` block, which the non-nesting regex above cannot isolate.
function assertRowContaining(html: string, marker: string): string {
  const re = /<div class="bel-assert[^>]*>[\s\S]*?<\/div>/g;
  const found = [...html.matchAll(re)].find((m) => m[0].includes(marker));
  if (!found) throw new Error(`no bel-assert row found containing ${JSON.stringify(marker)}`);
  return found[0];
}

// Acceptance 10: a verified assert, an expected error with its diagnostic,
// and a block with no entry, which renders as the program alone.
const html = await render(blocksWithEntries);

test("a verified assert renders marked as verified", () => {
  expect(html).toContain('<div class="bel-assert bel-assert-verified">');
  expect(html).toContain("assert faces = 1");
});

test("a failed assert renders its explanation", () => {
  const row = assertRowContaining(html, "assert faces = 2");
  expect(row).toContain('<div class="bel-assert bel-assert-failed">');
  expect(row).toContain("faces was 1, not 2");
});

test("an expected error renders its diagnostic, not marked as a failure", () => {
  const block = outcomeBlockContaining(html, "a placed fold derives its direction; drop mountain");
  expect(block).toContain("bel-outcome-expected");
  expect(block).not.toContain("bel-outcome-unexpected");
});

test("an unexpected error renders its diagnostic, marked as a failure", () => {
  const block = outcomeBlockContaining(html, "something genuinely broke");
  expect(block).toContain("bel-outcome-unexpected");
});

test("an expect-error that never fired renders as a failure, inverted", () => {
  const block = outcomeBlockContaining(html, "something that never happens");
  expect(block).toContain("bel-outcome-unexpected");
  expect(block).toContain("eval succeeded");
});

test("a block with no blocks.json entry renders as the program alone", () => {
  // the program itself is still highlighted and present
  expect(html).toContain("bd");
  // four outcome blocks render (indices 1, 2, 4, 5 above); index 3, the
  // `.bel .frag` block with no matching entry, adds none
  expect(html.match(/class="bel-outcome/g)?.length).toBe(4);
});

// Acceptance 11 (site half): a `.bel .prelude` block appears nowhere in the
// output, not even as an excerpt inside a rendered diagnostic.
test("a prelude block is never rendered", () => {
  expect(html).not.toContain("sentinel-prelude-marker");
});

// A missing blocks.json (the build script has not run yet) is not fatal:
// every block falls through to the no-entry rendering, and the plugin does
// not throw.
test("a missing blocks.json is not fatal", async () => {
  const withoutBuild = await render(join(fixtures, "remark-bel-blocks-missing.json"));
  expect(withoutBuild).not.toContain("bel-outcome");
  expect(withoutBuild).not.toContain("sentinel-prelude-marker");
});

// Fix for a bug where the plugin always fell back to spec/BELOCH.md's
// entries regardless of which document was being processed: a document with
// no entry in blocks.json must render nothing, even when blocks.json holds
// entries (for a different document) at the same indices.
test("a document with no blocks.json entry renders no outcomes at all", async () => {
  const rendered = String(
    await unified()
      .use(remarkParse)
      .use(remarkBel, { blocks: blocksWithEntries, doc: "spec/OTHER.md" })
      .use(remarkRehype, { allowDangerousHtml: true })
      .use(rehypeStringify, { allowDangerousHtml: true })
      .process(readFileSync(doc, "utf8")),
  );
  expect(rendered).not.toContain("bel-outcome");
});
