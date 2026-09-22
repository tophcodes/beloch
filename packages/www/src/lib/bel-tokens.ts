/**
 * Turning tree-sitter captures into Beloch token ranges.
 *
 * Two surfaces highlight .bel source and they have to agree: highlight-bel.ts
 * builds HTML at build time for the <Beloch> cards and the markdown fences,
 * cm-bel-highlight.ts builds CodeMirror decorations in the browser for the
 * playground editor. They run different runtimes and produce different output,
 * so the one thing they share is this: which capture wins where, and what the
 * class is called. A token the editor colours differently from the card next
 * to it is the failure this file exists to prevent.
 */

/** A capture as both tree-sitter runtimes report it, narrowed to what we read. */
export interface Capture {
  name: string;
  node: { startIndex: number; endIndex: number };
}

export interface Token {
  from: number;
  to: number;
  /** Capture name; the CSS class is `bel-` + this. */
  name: string;
}

/**
 * Captures in source order, with overlaps dropped.
 *
 * The grammar is flat, so tokens rarely nest; where two captures do cover the
 * same text the earlier one keeps it and the later is skipped, which is what
 * makes the output a plain sequence both surfaces can render without a stack.
 */
export function belTokens(captures: readonly Capture[]): Token[] {
  const sorted = [...captures].sort((a, b) => a.node.startIndex - b.node.startIndex);
  const out: Token[] = [];
  let pos = 0;
  for (const c of sorted) {
    const from = c.node.startIndex;
    const to = c.node.endIndex;
    if (from < pos) continue;
    out.push({ from, to, name: c.name });
    pos = to;
  }
  return out;
}

/**
 * The entity name a token carries, for the two-way highlight between code and
 * drawing, or null for a token that names nothing. A bracketed selection
 * (`.[…]`, `--[…]`) is a construction rather than a name, so it carries none.
 */
export function belEntityName(captureName: string, text: string): string | null {
  if (captureName === "point") return /^\.([A-Za-z_]\w*)$/.exec(text)?.[1] ?? null;
  if (captureName === "line") return /^--([A-Za-z_]\w*)$/.exec(text)?.[1] ?? null;
  return null;
}
