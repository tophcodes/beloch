/**
 * Beloch syntax colouring for the playground editor.
 *
 * The browser half of the pair described in highlight-bel.ts: the same grammar
 * wasm and the same highlights.scm, parsed with web-tree-sitter and handed to
 * CodeMirror as line decorations rather than as HTML. Token ranges come from
 * bel-tokens.ts, so a token here carries the class it carries in a <Beloch>
 * card, and theme.css colours both from the same --bel-syntax-* role.
 *
 * This is decorations, not a CodeMirror `Language`. A Language would need a
 * Lezer parser, and the grammar this project maintains is a tree-sitter one;
 * nothing else in CodeMirror (folding, indentation, completion) reads the tree
 * here, so the tree's only job is to say which range gets which class.
 *
 * The three files the parser needs are imported through the bundler, so the
 * build emits them with the rest of the site and there is no hand-kept copy to
 * drift: packages/grammar's `generate` writes src/grammar, and src/grammar is
 * what both halves read.
 */
import { Parser, Language, Query, type Tree } from "web-tree-sitter";
import { Decoration, EditorView, ViewPlugin } from "@codemirror/view";
import type { DecorationSet, ViewUpdate } from "@codemirror/view";
import { RangeSetBuilder } from "@codemirror/state";
import type { Extension } from "@codemirror/state";
import { belTokens } from "./bel-tokens";

import wtsWasmUrl from "web-tree-sitter/web-tree-sitter.wasm?url";
import grammarWasmUrl from "../grammar/tree-sitter-beloch.wasm?url";
import highlightsQuery from "../grammar/highlights.scm?raw";

let ready: Promise<{ parser: Parser; query: Query }> | null = null;

/**
 * Loads the parser, once per page. The playground awaits this before it mounts
 * the editor: the server already rendered the program with its colours, and
 * mounting an uncoloured editor over that would take them away and give them
 * back a moment later, on the one element the reader is looking at.
 */
export function initBelHighlight(): Promise<{ parser: Parser; query: Query }> {
  if (!ready) {
    ready = (async () => {
      await Parser.init({ locateFile: () => wtsWasmUrl });
      const lang = await Language.load(grammarWasmUrl);
      const parser = new Parser();
      parser.setLanguage(lang);
      return { parser, query: new Query(lang, highlightsQuery) };
    })();
  }
  return ready;
}

const marks = new Map<string, Decoration>();
function markFor(name: string): Decoration {
  let d = marks.get(name);
  if (!d) {
    d = Decoration.mark({ class: `bel-${name}` });
    marks.set(name, d);
  }
  return d;
}

/**
 * The extension. Pass the value `initBelHighlight()` resolved to, so the
 * editor is built with colouring already in place rather than gaining it on a
 * later transaction.
 *
 * Every build parses the whole document. Reusing the previous tree would mean
 * applying each change to it with `tree.edit()` first; handing over an
 * unedited tree makes tree-sitter keep the old ranges, and the colouring then
 * describes the text as it was before the keystroke. At the size a program in
 * this editor reaches, a full parse with its captures takes about 0.15 ms, so
 * the ceiling is a document long enough for that to show between two
 * keystrokes, and that is where keeping an edited tree would start to pay.
 */
export function belHighlighting({ parser, query }: { parser: Parser; query: Query }): Extension {
  return ViewPlugin.fromClass(
    class {
      decorations: DecorationSet;

      constructor(view: EditorView) {
        this.decorations = this.build(view);
      }

      update(update: ViewUpdate) {
        if (update.docChanged || update.viewportChanged) {
          this.decorations = this.build(update.view);
        }
      }

      private build(view: EditorView): DecorationSet {
        const text = view.state.doc.toString();
        let tree: Tree | null;
        try {
          tree = parser.parse(text);
        } catch {
          // A parse that throws leaves the previous colouring standing rather
          // than stripping the editor back to plain text mid-edit.
          return this.decorations ?? Decoration.none;
        }
        if (!tree) return this.decorations ?? Decoration.none;
        try {
          const builder = new RangeSetBuilder<Decoration>();
          for (const t of belTokens(query.captures(tree.rootNode))) {
            builder.add(t.from, t.to, markFor(t.name));
          }
          return builder.finish();
        } finally {
          // The tree lives in wasm memory, which the garbage collector does
          // not reach.
          tree.delete();
        }
      }
    },
    { decorations: (v) => v.decorations },
  );
}
