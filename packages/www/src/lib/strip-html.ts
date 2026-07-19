// Recover raw text from an Astro slot's rendered HTML.
//
// `Astro.slots.render("default")` returns HTML: wrapper tags plus
// entity-encoded text. Beloch source uses characters Astro escapes — notably
// `&` (the keep/filter operator), which Astro emits as the NUMERIC entity
// `&#x26;`, not the named `&amp;`. So decoding must cover numeric entities
// (hex and decimal), not just a hand-picked set of named ones, or the raw
// `&#x26;` reaches `beloch fold` and the build dies on an "unexpected
// character" lex error.

const NAMED: Record<string, string> = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
};

// Single pass: each entity is decoded exactly once and the output is never
// re-scanned, so a decoded `&` can't be mistaken for the start of another
// entity (no double-decode).
function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z][a-zA-Z0-9]*);/g, (m, e: string) => {
    if (e[0] === "#") {
      const code =
        e[1] === "x" || e[1] === "X"
          ? parseInt(e.slice(2), 16)
          : parseInt(e.slice(1), 10);
      return Number.isNaN(code) ? m : String.fromCodePoint(code);
    }
    return e in NAMED ? NAMED[e]! : m;
  });
}

export function stripHtml(s: string): string {
  // Strip real tags first (they contain literal `<`/`>`), THEN decode entities
  // back to the literal characters they stand for.
  return decodeEntities(s.replace(/<[^>]*>/g, "")).trim();
}
