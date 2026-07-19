/**
 * Beloch syntax highlighting via the ad-hoc tree-sitter grammar.
 *
 * Single source of truth for highlighting .bel source: used at build time by the
 * <Beloch> card and the markdown `bel` code-fence plugin. The same grammar wasm
 * also drives the live playground editor (see playground island).
 *
 * Captures (see packages/grammar/queries/highlights.scm) → CSS classes:
 *   comment→bel-comment keyword→bel-keyword point→bel-point line→bel-line
 *   instance→bel-instance number→bel-number operator→bel-operator
 *   punct→bel-punct
 */
import { Parser, Language, Query } from "web-tree-sitter";
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

let _lang: Language | null = null;
let _query: Query | null = null;
let _parser: Parser | null = null;

async function ensure(): Promise<{ parser: Parser; query: Query }> {
  if (_parser && _query) return { parser: _parser, query: _query };
  // Locate web-tree-sitter's own runtime wasm for Node.
  await Parser.init({
    locateFile: (name: string) => join(wtsDir, name),
  });
  _lang = await Language.load(join(grammarDir, "tree-sitter-beloch.wasm"));
  _query = new Query(
    _lang,
    readFileSync(join(grammarDir, "highlights.scm"), "utf8")
  );
  _parser = new Parser();
  _parser.setLanguage(_lang);
  return { parser: _parser, query: _query };
}

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

/** Highlight Beloch source to an HTML string of <span class="bel-*"> tokens. */
export async function highlightBel(source: string): Promise<string> {
  const { parser, query } = await ensure();
  const tree = parser.parse(source);
  if (!tree) return esc(source);
  const caps = query.captures(tree.rootNode);
  // Flat grammar → non-overlapping tokens; sort by start just in case.
  caps.sort((a, b) => a.node.startIndex - b.node.startIndex);
  let out = "";
  let pos = 0;
  for (const c of caps) {
    const { startIndex: s, endIndex: e } = c.node;
    if (s < pos) continue; // skip any overlap
    if (s > pos) out += esc(source.slice(pos, s));
    const tokenText = source.slice(s, e);
    let belName = "";
    if (c.name === "point") {
      const m = /^\.([A-Za-z_]\w*)$/.exec(tokenText); // .center — not .[
      if (m) belName = m[1]!;
    } else if (c.name === "line") {
      const m = /^--([A-Za-z_]\w*)$/.exec(tokenText); // --d1 — not --[
      if (m) belName = m[1]!;
    }
    const dataAttr = belName ? ` data-bel-name="${belName}"` : "";
    out += `<span class="bel-${c.name}"${dataAttr}>${esc(tokenText)}</span>`;
    pos = e;
  }
  if (pos < source.length) out += esc(source.slice(pos));
  tree.delete();
  return out;
}
