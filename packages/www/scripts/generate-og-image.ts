#!/usr/bin/env bun
// Regenerates packages/www/public/og-image.png, the social-preview image for
// the landing page and the Starlight docs (og:image / twitter:card). It is a
// committed build artifact, same pattern as public/beloch/beloch-eval.js and
// src/grammar/tree-sitter-beloch.wasm: the site build does not run this
// script, so run it manually after the source program or the wordmark
// changes.
//
// The image is the project's own bird-base fold, the same base the landing
// hero shows, rendered fresh through the project's headless render path
// (`beloch fold` -> `beloch-render` -> resvg, packages/render-2d/render-svg/
// bin/fold2svg.ts) and framed on the dark panel background from
// packages/www/src/styles/theme.css with the "Beloch" wordmark in the site's
// own header font. No color here is invented: the fold keeps
// packages/render-2d/render-svg/src/theme.ts's DEFAULT_THEME colors, and the
// panel/ink values are copied from theme.css's dark theme.
//
// Regenerate with:
//   bun packages/www/scripts/generate-og-image.ts
//
// Requires the `beloch` binary on PATH (`nix develop`, same requirement
// src/lib/eval-bel.ts has for the rest of the site build), @resvg/resvg-js
// (a dependency of packages/render-2d/render-svg, resolved here via
// node_modules hoisting), and a monospace font resvg's font database can
// resolve "IBM Plex Mono, monospace" against, the same font stack the
// site's CSS already asks browsers for.
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const repoRoot = join(fileURLToPath(import.meta.url), "..", "..", "..", "..");
const markPath = join(repoRoot, "packages", "www", "public", "brand", "mark.svg");
const sourceBel = join(repoRoot, "examples", "bases", "bird-base.bel");
const fold2svgBin = join(repoRoot, "packages", "render-2d", "render-svg", "bin", "fold2svg.ts");
const outPath = join(repoRoot, "packages", "www", "public", "og-image.png");

// theme.css dark theme: --bel-ui-surface and --bel-ui-text.
const PANEL_BG = "#1C1A17";
const INK = "#EDE9E1";

const WIDTH = 1200;
const HEIGHT = 630;

function run(cmd: string, args: string[], input?: string): string {
  try {
    return execFileSync(cmd, args, { encoding: "utf8", input });
  } catch (err) {
    const e = err as { code?: string; stderr?: Buffer | string; message?: string };
    if (e.code === "ENOENT") {
      throw new Error(`${cmd}: binary not found on PATH — run \`nix develop\`.`);
    }
    throw new Error(`${cmd} failed:\n${e.stderr?.toString() ?? e.message ?? String(err)}`);
  }
}

const fold = run("beloch", ["fold", sourceBel]);
// The crease pattern, not the folded state: flat-folded from above, the bird
// base is a quadrilateral and shows nothing. Labels are stripped from the
// markup rather than asked off, because --labels "" leaves the corner names in.
const cpSvg = run("bun", [fold2svgBin, "-", "--view", "cp", "--labels", ""], fold)
  .replace(/<text\b[^>]*>[\s\S]*?<\/text>/g, "");

// The CP render is a square canvas the pattern already fills, so it needs no
// cropping: drop its white backdrop and place the whole square as the card.
const CANVAS = 572;
const innerMarkup = cpSvg
  .replace(/^<svg[^>]*>/, "")
  .replace(/<\/svg>\s*$/, "")
  .replace(/<rect width="\d+(?:\.\d+)?" height="\d+(?:\.\d+)?" fill="white"\/>/, "");

const cardHeight = HEIGHT - 150;
const scale = cardHeight / CANVAS;
const cardX = WIDTH - cardHeight - 96;
const cardY = (HEIGHT - cardHeight) / 2;
const cardBg = `<rect width="${CANVAS}" height="${CANVAS}" fill="white"/>`;

// The mark, from brand/mark.svg, which fold2logo.ts renders out of
// brand/mark.bel. currentColor has no meaning inside a standalone SVG, so the
// ink value is substituted in.
const MARK_SIZE = 128;
const MARK_Y = 168;
const markInner = readFileSync(markPath, "utf8")
  .replace(/^<svg[^>]*>/, "")
  .replace(/<\/svg>\s*$/, "")
  .replaceAll("currentColor", INK)
  .trim();

const composed = `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
  <rect width="${WIDTH}" height="${HEIGHT}" fill="${PANEL_BG}"/>
  <g transform="translate(96, ${MARK_Y}) scale(${MARK_SIZE / 64})" fill="none" stroke="${INK}" stroke-linecap="round">
    ${markInner}
  </g>
  <text x="96" y="${MARK_Y + MARK_SIZE + 84}" font-family="IBM Plex Mono, monospace" font-size="72" font-weight="600" fill="${INK}">Beloch</text>
  <text x="96" y="${MARK_Y + MARK_SIZE + 128}" font-family="IBM Plex Sans, sans-serif" font-size="22" fill="${INK}" opacity="0.7">A declarative language for origami</text>
  <g transform="translate(${cardX}, ${cardY}) scale(${scale})">
    ${cardBg}
    ${innerMarkup}
  </g>
</svg>`;

const { Resvg } = await import("@resvg/resvg-js");
const png = new Resvg(composed, { fitTo: { mode: "width", value: WIDTH } }).render().asPng();
writeFileSync(outPath, png);
console.log(`Wrote ${outPath} (${(png.length / 1024).toFixed(1)} KiB, ${WIDTH}x${HEIGHT})`);
