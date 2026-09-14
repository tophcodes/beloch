/**
 * The tree-sitter side of the reference corpus test (design doc "The three
 * runners"): every tagged block in spec/BELOCH.md, extracted by the same
 * rule as packages/core/tests/test_reference_corpus.ml, parses with the
 * shipped wasm and produces no ERROR node. Unlike the kernel runner this
 * stays parse-only: a block is parsed on its own, without its prelude
 * prepended, since well-formedness does not depend on the names a prelude
 * would bind.
 */
import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { Parser, Language } from "web-tree-sitter";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = process.env.BELOCH_REPO_ROOT ?? join(here, "..", "..", "..", "..");
const siteDir = join(repoRoot, "packages", "www");
const grammarDir = join(siteDir, "src", "grammar");
const wtsDir = join(siteDir, "node_modules", "web-tree-sitter");

let _parser: Parser | null = null;

async function parser(): Promise<Parser> {
  if (_parser) return _parser;
  await Parser.init({ locateFile: (name: string) => join(wtsDir, name) });
  const lang = await Language.load(join(grammarDir, "tree-sitter-beloch.wasm"));
  _parser = new Parser();
  _parser.setLanguage(lang);
  return _parser;
}

// ---- Block extraction, mirroring test_reference_corpus.ml's rule ----

type Tag = "whole" | "prelude" | "frag" | "construction";
interface Block {
  tag: Tag;
  body: string;
  fenceLine: number; // 1-based, the line the opening fence is on
}

// Attribute-list body, e.g. ".bel .frag prelude=triangle" (braces already
// stripped) -> its key=value attributes, ignoring the leading class tokens.
// A token that is neither a class nor a key=value pair is a malformed
// attribute, the way test_reference_corpus.ml's attrs_of reads it.
function attrsOf(tokens: string[]): Map<string, string> {
  const attrs = new Map<string, string>();
  for (const t of tokens) {
    if (t.startsWith(".")) continue;
    const i = t.indexOf("=");
    if (i < 0) throw new Error(`malformed attribute "${t}"`);
    attrs.set(t.slice(0, i), t.slice(i + 1));
  }
  return attrs;
}

function parseTag(info: string): Tag | null {
  const trimmed = info.trim();
  if (trimmed === "bel" || trimmed === "beloch") return "whole";
  if (trimmed.length >= 2 && trimmed.startsWith("{") && trimmed.endsWith("}")) {
    const inner = trimmed.slice(1, -1);
    const tokens = inner.split(" ").filter((t) => t !== "");
    if (tokens[0] !== ".bel") return null;
    const rest = tokens.slice(1);
    const classes = rest.filter((t) => t.startsWith("."));
    const attrs = attrsOf(rest);
    if (classes.length === 0) return "whole";
    if (classes.length === 1 && classes[0] === ".prelude") {
      if (!attrs.has("name")) throw new Error("{.bel .prelude} block with no name=");
      return "prelude";
    }
    if (classes.length === 1 && classes[0] === ".frag") return "frag";
    if (classes.length === 1 && classes[0] === ".construction") return "construction";
    throw new Error(`unrecognized .bel block classes: ${classes.join(" ")}`);
  }
  return null;
}

// Every fence in spec/*.md opens and closes with a bare ``` line (no longer
// backtick run, no indentation); an unterminated fence is a malformed
// document, not a block to silently drop.
function extractBlocks(src: string): Block[] {
  const lines = src.split("\n");
  const blocks: Block[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i]!;
    if (line.startsWith("```")) {
      const info = line.slice(3);
      const fenceLine = i + 1;
      let j = i + 1;
      while (j < lines.length && lines[j] !== "```") j++;
      if (j >= lines.length) throw new Error(`unterminated fence opened at line ${fenceLine}`);
      const body = lines.slice(i + 1, j).join("\n");
      const tag = parseTag(info);
      if (tag !== null) blocks.push({ tag, body, fenceLine });
      i = j + 1;
    } else {
      i++;
    }
  }
  return blocks;
}

// Block inventory of spec/BELOCH.md, by tag (matches test_reference_corpus.ml's
// expected_inventory). Ceiling: this catches the tree-sitter extractor
// drifting from the document, not from the OCaml and build-side copies of
// the same rule; update all three when a tagged block is added to
// BELOCH.md.
const expectedInventory: Record<Tag, number> = {
  whole: 0,
  prelude: 6,
  frag: 7,
  construction: 1,
};

test("BELOCH.md reference corpus: every tagged block parses with no ERROR node", async () => {
  const src = readFileSync(join(repoRoot, "spec", "BELOCH.md"), "utf8");
  const blocks = extractBlocks(src);

  const inventory: Record<Tag, number> = { whole: 0, prelude: 0, frag: 0, construction: 0 };
  for (const b of blocks) inventory[b.tag]++;
  expect(inventory).toEqual(expectedInventory);

  const p = await parser();
  for (const b of blocks) {
    const tree = p.parse(b.body);
    expect(tree).not.toBeNull();
    if (!tree) continue;
    try {
      if (tree.rootNode.hasError) {
        throw new Error(`line ${b.fenceLine} (${b.tag}) has an ERROR node: ${tree.rootNode.toString()}`);
      }
    } finally {
      tree.delete();
    }
  }
});

// The corpus test above pins permissiveness: a grammar with no rule that can
// fail parses every lexable program. These pin the structure the highlighting
// queries bind to (design doc "tree-sitter", Acceptance 9): one named node
// per item type, and a head the verb rejects parsing into its node all the
// same, so the diagnostic comes from the kernel.
const itemNodes: [string, string][] = [
  ["mark (align (.a onto .c))", "construction"],
  ["mark (align (.a onto .c))", "alignment"],
  ["mark (map .a onto .c)", "construction"],
  ["fold (--d)", "axis_item"],
  ["flatten (--l mountain)", "flatten_element"],
  ["fold (moving .a)", "anchor_item"],
  ["fold (up to .c)", "depth_item"],
  ["fold (over .b)", "placement_item"],
  ["reverse (outside)", "kind_item"],
  ["fold (mountain)", "intent_item"],
  ["mark (between .m .o)", "extent_item"],
  ["fold (on #[.c])", "layer_item"],
  ["flatten (.q over .r)", "order_item"],
  ["flatten (staying .a)", "stayer_item"],
  ["fold (toward .q)", "selection_item"],
  ["mark (--d) as --x", "output_clause"],
  ["mark (--d) into --x", "output_clause"],
  // a head its verb rejects: `(outside)` is the reverse fold's, and `mark`
  // has no use for it, yet it still parses into `kind_item`
  ["mark (outside)", "kind_item"],
];

test("every item type parses into its own named node", async () => {
  const p = await parser();
  for (const [program, node] of itemNodes) {
    const tree = p.parse(program);
    expect(tree).not.toBeNull();
    if (!tree) continue;
    try {
      const sexp = tree.rootNode.toString();
      expect([program, sexp.includes(`(${node}`), tree.rootNode.hasError]).toEqual([program, true, false]);
    } finally {
      tree.delete();
    }
  }
});
