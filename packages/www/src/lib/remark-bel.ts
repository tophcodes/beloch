// Highlight ```beloch / ```bel fenced code blocks with the shared tree-sitter
// highlighter, turning them into raw HTML so Expressive Code leaves them alone,
// then render the outcome the build-side capture tool recorded for it (design
// doc "Rendering the outcome", Acceptance 10 and 11). Inline code that the
// highlighter covers completely gets the same colors; any other inline code,
// a path or an identifier, is left to the page.
//
// docs/reference/BELOCH.md's example blocks carry pandoc's attribute form of the info
// string, `{.bel .frag prelude=triangle}` (design doc "Marking the blocks"),
// because pandoc's markdown reader takes only a single bare word or a bracketed
// attribute list. remark-parse splits an info string at its first space, so a
// block written `{.bel .frag prelude=triangle}` arrives here as
// `node.lang === "{.bel"` and `node.meta === ".frag prelude=triangle}"`;
// parseFenceTag rejoins the two before reading the class list. A bare `bel` or
// `beloch` (one word, no braces) is unchanged: a whole program, no classes.
//
// A block carrying the `prelude` class sets up names for other blocks and is
// never shown: it is spliced out of the tree instead of rendered (Acceptance
// 11). It still consumes a block index, since `packages/core/tools/blocks.ml`
// counts every tagged block, including preludes, in document order, and this
// plugin's counter has to land on the same index for every later block.
import { visit } from "unist-util-visit";
import { readFileSync, realpathSync } from "node:fs";
import { join, relative } from "node:path";
import { highlightBel, highlightBelInline } from "./highlight-bel.ts";

const BARE_LANGS = new Set(["beloch", "bel"]);

interface AssertEntry {
  text: string;
  verified: boolean;
  message?: string;
}

interface BlockEntry {
  index: number;
  status: "ok" | "error";
  expected: boolean;
  message?: string;
  diagnostic?: string;
  asserts: AssertEntry[];
}

function repoRoot(): string {
  return process.env.BELOCH_REPO_ROOT ?? process.cwd();
}

// The document a processed file corresponds to, relative to the repo root:
// the same key packages/core/tools/blocks.ml writes into blocks.json. The
// reference documents are reached through symlinks under
// src/content/docs/ (e.g. language.md -> ../../../../../docs/reference/BELOCH.md).
// Resolving the path before comparing keeps a symlinked page keyed off the
// docs/reference/ path blocks.ml wrote entries under, instead of its own content
// path. `null` when the file carries no path at all (e.g. a `VFile` built
// straight from a string), left to the caller.
function docPathOf(file: any): string | null {
  const raw = file?.path ?? file?.history?.[0];
  if (!raw) return null;
  let real: string;
  try {
    real = realpathSync(raw);
  } catch {
    real = raw;
  }
  return relative(repoRoot(), real);
}

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// [lang, meta] rejoined into the original info string, e.g. "{.bel .frag
// prelude=triangle}", or `null` for anything that is not a `.bel` block: a
// bare `bel`/`beloch` fence stays a whole program with no classes; the
// attribute form is read for its class list, `prelude` in particular.
function parseFenceTag(
  lang: string | null | undefined,
  meta: string | null | undefined,
): { isPrelude: boolean } | null {
  if (!lang) return null;
  if (BARE_LANGS.has(lang)) return { isPrelude: false };
  if (!lang.startsWith("{")) return null;
  const info = meta ? `${lang} ${meta}` : lang;
  if (!info.endsWith("}")) return null;
  const inner = info.slice(1, -1);
  const tokens = inner.split(" ").filter((t) => t !== "");
  if (tokens[0] !== ".bel") return null;
  const classes = tokens.slice(1).filter((t) => t.startsWith("."));
  return { isPrelude: classes.includes(".prelude") };
}

// `_build/reference/blocks.json`[doc] once no `.exe` has run yet: `astro dev` still
// has to work, so every block just falls through to the no-entry rendering.
function loadEntries(path: string, doc: string): BlockEntry[] {
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    return parsed[doc] ?? [];
  } catch {
    return [];
  }
}

// The three states a reader must be able to see (design doc "Rendering the
// outcome"): no entry renders nothing extra here (the caller keeps the
// highlighted program alone); `status: "error"` with `expected: true` is a
// plain diagnostic (a negative example behaving as documented); `expected:
// false` on either status is a failure, an unexpected error or an `expect
// error` that never raised, and both are marked the same way.
function outcomeHtml(entry: BlockEntry | undefined): string {
  if (!entry) return "";
  if (entry.status === "error") {
    const cls = entry.expected ? "bel-outcome-expected" : "bel-outcome-unexpected";
    return `<pre class="bel-outcome bel-outcome-error ${cls}">${esc(entry.diagnostic ?? entry.message ?? "")}</pre>`;
  }
  if (entry.expected) {
    return `<pre class="bel-outcome bel-outcome-error bel-outcome-unexpected">${esc(entry.message ?? "")}</pre>`;
  }
  if (entry.asserts.length === 0) return "";
  const failed = entry.asserts.filter((a) => !a.verified).length;
  const n = entry.asserts.length;
  const noun = n === 1 ? "assertion" : "assertions";
  const summary = failed === 0 ? `${n} ${noun} passed` : `${failed} of ${n} ${noun} failed`;
  const lines = entry.asserts
    .map((a) => {
      const explanation = !a.verified && a.message ? ` <span class="bel-assert-message">${esc(a.message)}</span>` : "";
      return `<div class="bel-assert ${a.verified ? "bel-assert-verified" : "bel-assert-failed"}"><code>${esc(a.text)}</code>${explanation}</div>`;
    })
    .join("");
  // Closed while every assertion holds; a failure opens it, so a broken page
  // shows what broke without a click.
  return `<details class="bel-outcome bel-outcome-ok"${failed === 0 ? "" : " open"}><summary>${summary}</summary>${lines}</details>`;
}

// `; assert …` and `; expect …` lines, as packages/core's
// Bel_assert.is_assertion_line reads them.
const ASSERT_LINE = /^[ \t]*;[ \t]*(?:assert|expect)(?:[ \t]|$)/;

// The program without its assertion lines and the blank lines they leave at
// the end. A block drops them only when an outcome renders under it, so a page
// built without blocks.json still shows what the block asserts.
function withoutAssertions(src: string): string {
  const lines = src.split("\n").filter((l) => !ASSERT_LINE.test(l));
  while (lines.length > 0 && lines[lines.length - 1]!.trim() === "") lines.pop();
  return lines.join("\n");
}

export default function remarkBel(options: { blocks?: string; doc?: string } = {}) {
  return async (tree: any, file: any) => {
    const blocksPath = options.blocks ?? join(repoRoot(), "_build", "reference", "blocks.json");
    const doc = options.doc ?? docPathOf(file) ?? "";
    const entries = loadEntries(blocksPath, doc);

    let index = 0;
    const targets: { node: any; blockIndex: number }[] = [];
    const removals = new Map<any, number[]>();

    visit(tree, "code", (node: any, i: number | undefined, parent: any) => {
      const tag = parseFenceTag(node.lang, node.meta);
      if (!tag) return;
      const blockIndex = index++;
      if (tag.isPrelude) {
        if (parent && i !== undefined) {
          const at = removals.get(parent) ?? [];
          at.push(i);
          removals.set(parent, at);
        }
        return;
      }
      targets.push({ node, blockIndex });
    });

    const inline: any[] = [];
    visit(tree, "inlineCode", (node: any) => {
      inline.push(node);
    });
    await Promise.all(
      inline.map(async (node) => {
        const html = await highlightBelInline(String(node.value ?? ""));
        if (html === null) return;
        node.type = "html";
        node.value = `<code class="bel-inline">${html}</code>`;
      })
    );

    await Promise.all(
      targets.map(async ({ node, blockIndex }) => {
        const entry = entries.find((e) => e.index === blockIndex);
        const src = String(node.value ?? "");
        const outcome = outcomeHtml(entry);
        const html = await highlightBel(outcome ? withoutAssertions(src) : src);
        node.type = "html";
        node.value = `<pre class="bel-block"><code>${html}</code></pre>${outcome}`;
        delete node.lang;
        delete node.meta;
      })
    );

    // Splice prelude nodes out last, highest child index first per parent, so
    // an earlier removal never shifts a later one's index.
    for (const [parent, at] of removals) {
      for (const i of [...at].sort((a, b) => b - a)) parent.children.splice(i, 1);
    }
  };
}
