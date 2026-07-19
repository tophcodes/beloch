// Highlight ```beloch / ```bel fenced code blocks with the shared tree-sitter
// highlighter, turning them into raw HTML so Expressive Code leaves them alone.
import { visit } from "unist-util-visit";
import { highlightBel } from "./highlight-bel.ts";

const LANGS = new Set(["beloch", "bel"]);

export default function remarkBel() {
  return async (tree: any) => {
    const targets: any[] = [];
    visit(tree, "code", (node: any) => {
      if (node.lang && LANGS.has(node.lang)) targets.push(node);
    });
    await Promise.all(
      targets.map(async (node) => {
        const html = await highlightBel(String(node.value ?? ""));
        node.type = "html";
        node.value = `<pre class="bel-block"><code>${html}</code></pre>`;
        delete node.lang;
        delete node.meta;
      })
    );
  };
}
