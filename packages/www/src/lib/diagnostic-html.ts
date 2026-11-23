/** A diagnostic of `beloch fold`, colored for a page, one HTML string per
 *  line. The kernel's layout stays as it prints it: the message, the place,
 *  the source lines under a gutter, the carets under the span and the help
 *  line. A source line takes the highlighting of the code around it; a line
 *  the highlighter cannot read on its own, the tail of a statement that
 *  started above it, stays plain. */
import { highlightBelInline } from "./highlight-bel";

const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const gutter = (s: string) => `<span class="dg-gutter">${esc(s)}</span>`;

async function line(text: string): Promise<string> {
  let m = /^error: (.*)$/.exec(text);
  if (m) return `<span class="dg-error">error</span>: ${esc(m[1]!)}`;
  m = /^(\s*= )help: (.*)$/.exec(text);
  if (m) return `${gutter(m[1]!)}<span class="dg-help">help</span>: ${esc(m[2]!)}`;
  m = /^(\s*--> )(.*)$/.exec(text);
  if (m) return gutter(m[1]! + m[2]!);
  m = /^(\s*\d+ \| )(.*)$/.exec(text);
  if (m) return gutter(m[1]!) + ((await highlightBelInline(m[2]!)) ?? esc(m[2]!));
  m = /^(\s*\|)( *)(\^+)(.*)$/.exec(text);
  if (m) return `${gutter(m[1]!)}${m[2]}<span class="dg-error">${m[3]}${esc(m[4]!)}</span>`;
  m = /^(\s*\|)(.*)$/.exec(text);
  if (m) return gutter(m[1]!) + esc(m[2]!);
  return esc(text);
}

export async function diagnosticHtml(text: string): Promise<string[]> {
  return Promise.all(text.split("\n").map(line));
}
