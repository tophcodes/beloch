#!/usr/bin/env bun
// Regenerates the standalone brand files in packages/www/public/brand/ for
// places where the site's inline lockup cannot go: an <img> on GitHub, a
// slide, a badge. They are committed build artifacts, same pattern as
// public/og-image.png: the site build does not run this script, so run it
// manually after brand/mark.svg, the wordmark, the mono font or the ink
// colour changes.
//
//   mark-light.svg,   mark-dark.svg    brand/mark.svg with currentColor
//                                       replaced by a literal ink colour
//   lockup-light.svg, lockup-dark.svg  the mark beside the word "beloch",
//                                       laid out as src/components/
//                                       Wordmark.astro lays it out at the
//                                       width where the header shows the full
//                                       cut, with the word as outline paths
//
// An SVG loaded through <img> resolves neither currentColor nor a web font,
// so every colour here is literal and the word carries no <text>. The
// backgrounds are transparent: "light" is the ink for a light page, "dark"
// the ink for a dark one.
//
// Nothing is copied by hand. The mark is read from brand/mark.svg. The ink is
// --bel-ui-text, parsed out of src/styles/tokens.css (its light-dark() pair).
// The glyphs are outlined from public/fonts/jetbrains-mono-600.woff2, the
// SemiBold cut the site's --bel-font-mono serves at weight 600, through
// fontkitten (a dependency of astro, resolved via node_modules hoisting),
// which reads WOFF2 directly. The font is under the SIL Open Font License
// 1.1 (public/fonts/OFL.txt), which permits converting glyphs to outlines in
// an artwork like this one.
//
// Regenerate with:
//   bun packages/www/scripts/generate-brand.ts
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { create, type Font } from "fontkitten";

const wwwRoot = join(fileURLToPath(import.meta.url), "..", "..");
const brandDir = join(wwwRoot, "public", "brand");
const markPath = join(brandDir, "mark.svg");
const fontPath = join(wwwRoot, "public", "fonts", "jetbrains-mono-600.woff2");
const tokensPath = join(wwwRoot, "src", "styles", "tokens.css");

// Wordmark.astro at 50rem and wider, in CSS px: .mark-full's size, the gap
// (--bel-space-2), the font size (--bel-text-xl) and the word it prints.
const MARK_PX = 28;
const GAP_PX = 16;
const FONT_PX = 18;
const WORD = "beloch";

function round(n: number): string {
  return String(Math.round(n * 100) / 100);
}

const tokens = readFileSync(tokensPath, "utf8");
const inkMatch = tokens.match(/--bel-ui-text:\s*light-dark\(\s*(#[0-9A-Fa-f]{3,8})\s*,\s*(#[0-9A-Fa-f]{3,8})\s*\)/);
if (!inkMatch) throw new Error(`--bel-ui-text: no light-dark(#…, #…) pair in ${tokensPath}`);
const INK = { light: inkMatch[1], dark: inkMatch[2] };

const markSvg = readFileSync(markPath, "utf8");
if (!markSvg.includes("currentColor")) throw new Error(`${markPath}: no currentColor to replace`);
const markParts = markSvg.match(/^\s*<svg\b([^>]*)>([\s\S]*)<\/svg>\s*$/);
if (!markParts) throw new Error(`${markPath}: not a single <svg> element`);
const markViewBox = markParts[1].match(/viewBox="([^"]+)"/)?.[1].split(/[\s,]+/).map(Number);
if (!markViewBox || markViewBox.length !== 4 || markViewBox[0] !== 0 || markViewBox[1] !== 0 || markViewBox[2] !== markViewBox[3]) {
  throw new Error(`${markPath}: expected a square viewBox at the origin`);
}
// The root's presentation attributes (fill, stroke, caps) move onto the group
// that places the mark inside the lockup.
const markGroupAttrs = markParts[1]
  .replace(/\s*xmlns(:\w+)?="[^"]*"/g, "")
  .replace(/\s*viewBox="[^"]*"/, "")
  .trim();
const markInner = markParts[2].trim();

// The mark's ink extent in its own units: every path point widened by half
// that path's stroke width, which a round cap reaches and a butt cap stays
// inside.
function markInkBox(): { x0: number; y0: number; x1: number; y1: number } {
  const box = { x0: Infinity, y0: Infinity, x1: -Infinity, y1: -Infinity };
  for (const path of markInner.matchAll(/<path\b([^>]*)\/?>/g)) {
    const d = path[1].match(/\sd="([^"]+)"/)?.[1];
    const width = Number(path[1].match(/stroke-width="([^"]+)"/)?.[1] ?? 1);
    if (!d) continue;
    if (/[^ML\d\s.,-]/.test(d)) throw new Error(`${markPath}: only absolute M/L paths are handled: ${d}`);
    const nums = d.match(/-?\d*\.?\d+/g)!.map(Number);
    for (let i = 0; i + 1 < nums.length; i += 2) {
      box.x0 = Math.min(box.x0, nums[i] - width / 2);
      box.x1 = Math.max(box.x1, nums[i] + width / 2);
      box.y0 = Math.min(box.y0, nums[i + 1] - width / 2);
      box.y1 = Math.max(box.y1, nums[i + 1] + width / 2);
    }
  }
  return box;
}

// The word as one path in lockup px. Wordmark.astro centres the text's line
// box on the mark (align-items: center), and a line box puts the baseline
// half of (ascent - descent) below its middle whatever the line height is.
// This font's hhea and OS/2 typo metrics agree, so either rule a browser
// follows lands on the same baseline.
function wordPath(font: Font, x: number): { d: string; x0: number; y0: number; x1: number; y1: number } {
  const scale = FONT_PX / font.unitsPerEm;
  const baseline = MARK_PX / 2 + ((font.ascent + font.descent) / 2) * scale;
  const box = { x0: Infinity, y0: Infinity, x1: -Infinity, y1: -Infinity };
  let d = "";
  for (const glyph of font.glyphsForString(WORD)) {
    const path = glyph.path.scale(scale, -scale).translate(x, baseline);
    const b = path.bbox;
    box.x0 = Math.min(box.x0, b.minX);
    box.x1 = Math.max(box.x1, b.maxX);
    box.y0 = Math.min(box.y0, b.minY);
    box.y1 = Math.max(box.y1, b.maxY);
    d += path.toSVG();
    x += glyph.advanceWidth * scale;
  }
  return { d: d.replace(/-?\d*\.\d+(?:e-?\d+)?/g, (n) => round(Number(n))), ...box };
}

const font = create(readFileSync(fontPath)) as Font;
const markScale = MARK_PX / markViewBox[2];
const mark = markInkBox();
const word = wordPath(font, MARK_PX + GAP_PX);

const x0 = Math.floor(Math.min(mark.x0 * markScale, word.x0) * 100) / 100;
const y0 = Math.floor(Math.min(mark.y0 * markScale, word.y0) * 100) / 100;
const x1 = Math.ceil(Math.max(mark.x1 * markScale, word.x1) * 100) / 100;
const y1 = Math.ceil(Math.max(mark.y1 * markScale, word.y1) * 100) / 100;
const w = round(x1 - x0);
const h = round(y1 - y0);

for (const [theme, ink] of Object.entries(INK)) {
  const markOut = join(brandDir, `mark-${theme}.svg`);
  writeFileSync(markOut, markSvg.replaceAll("currentColor", ink));

  const lockupOut = join(brandDir, `lockup-${theme}.svg`);
  const groupAttrs = markGroupAttrs.replaceAll("currentColor", ink);
  writeFileSync(
    lockupOut,
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="${round(x0)} ${round(y0)} ${w} ${h}" role="img" aria-label="Beloch">
  <g transform="scale(${markScale})" ${groupAttrs}>
    ${markInner.replace(/\n\s*/g, "\n    ")}
  </g>
  <path fill="${ink}" d="${word.d}"/>
</svg>
`,
  );
  console.log(`Wrote ${markOut}\nWrote ${lockupOut} (${w}x${h})`);
}
