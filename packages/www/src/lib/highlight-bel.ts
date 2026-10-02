/**
 * Beloch syntax highlighting via the ad-hoc tree-sitter grammar.
 *
 * The build-time half: used by the <Beloch> card and the markdown `bel`
 * code-fence plugin to emit HTML. This module reads the grammar off disk and
 * cannot run in a browser; the playground editor highlights through
 * cm-bel-highlight.ts, which loads the same grammar and the same query over
 * the network. Both take their token ranges from bel-tokens.ts, so the editor
 * and the card beside it cannot color one token differently.
 *
 * A capture named `x` becomes the CSS class `bel-x`, so the class list is
 * whatever packages/grammar/queries/highlights.scm captures: the token classes
 * of the flat grammar (comment, keyword, point, line, instance, number,
 * operator, `punct`) and one per item type under a write statement.
 */
import { Parser, Language, Query } from "web-tree-sitter";
import { belTokens, belEntityName } from "./bel-tokens";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

// Resolve against the site dir. import.meta.url is unreliable in Astro prerender
// bundles, so prefer BELOCH_REPO_ROOT (set in astro.config.mjs); fall back to the
// module path for `bun test` / standalone use.
const here = dirname(fileURLToPath(import.meta.url));
const siteDir = process.env.BELOCH_REPO_ROOT
  ? join(process.env.BELOCH_REPO_ROOT, "packages", "www")
  : join(here, "..", "..");
const grammarDir = join(siteDir, "src", "grammar");
const wtsDir = join(siteDir, "node_modules", "web-tree-sitter");

let ready: Promise<{ parser: Parser; query: Query }> | null = null;

// One load per process, shared by concurrent callers. Two overlapping
// Parser.init calls each instantiate a wasm module and the last one to finish
// becomes the global; a language loaded against the other then reads as
// "Incompatible language version 0" (#35).
function ensure(): Promise<{ parser: Parser; query: Query }> {
  if (!ready) {
    ready = (async () => {
      // Locate web-tree-sitter's own runtime wasm for Node.
      await Parser.init({
        locateFile: (name: string) => join(wtsDir, name),
      });
      const lang = await Language.load(join(grammarDir, "tree-sitter-beloch.wasm"));
      const query = new Query(
        lang,
        readFileSync(join(grammarDir, "highlights.scm"), "utf8")
      );
      const parser = new Parser();
      parser.setLanguage(lang);
      return { parser, query };
    })();
  }
  return ready;
}

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

/** Highlight Beloch source to an HTML string of <span class="bel-*"> tokens. */
export async function highlightBel(source: string): Promise<string> {
  return (await render(source)).html;
}

/**
 * Highlight an inline fragment, or `null` when it is not Beloch. A fragment
 * counts as Beloch when the highlighter covers every character outside
 * whitespace; a path such as `examples/crane.bel` leaves text over and stays
 * plain.
 */
export async function highlightBelInline(source: string): Promise<string | null> {
  const { html, covered } = await render(source);
  return covered ? html : null;
}

// The highlighted HTML, and whether every character outside whitespace fell
// inside a token.
async function render(source: string): Promise<{ html: string; covered: boolean }> {
  const { parser, query } = await ensure();
  const tree = parser.parse(source);
  if (!tree) return { html: esc(source), covered: false };
  let out = "";
  let pos = 0;
  let covered = true;
  const gap = (text: string) => {
    if (text.trim() !== "") covered = false;
    out += esc(text);
  };
  for (const t of belTokens(query.captures(tree.rootNode))) {
    if (t.from > pos) gap(source.slice(pos, t.from));
    const tokenText = source.slice(t.from, t.to);
    const belName = belEntityName(t.name, tokenText);
    const dataAttr = belName ? ` data-bel-name="${belName}"` : "";
    out += `<span class="bel-${t.name}"${dataAttr}>${esc(tokenText)}</span>`;
    pos = t.to;
  }
  if (pos < source.length) gap(source.slice(pos));
  tree.delete();
  return { html: out, covered };
}
