#!/usr/bin/env bun
// Regenerates packages/www/public/og-image.png, the social-preview image for
// the landing page and the Starlight docs (og:image / twitter:card). It is a
// committed build artifact, same pattern as public/beloch/beloch-eval.js and
// public/grammar/tree-sitter-beloch.wasm: the site build does not run this
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
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const repoRoot = join(fileURLToPath(import.meta.url), "..", "..", "..", "..");
const sourceBel = join(repoRoot, "examples", "bases", "bird-base.bel");
const fold2svgBin = join(repoRoot, "packages", "render-2d", "render-svg", "bin", "fold2svg.ts");
const outPath = join(repoRoot, "packages", "www", "public", "og-image.png");

// theme.css dark theme: --beloch-panel and --beloch-ink.
const PANEL_BG = "#171B24";
const INK = "#E7EAF2";

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
const foldedSvg = run("bun", [fold2svgBin, "-", "--view", "folded"], fold);

// Crop to the fold's own geometry rather than the full render canvas (which
// is mostly blank paper around a folded base far smaller than the sheet) by
// reading every coordinate resvg would draw and padding around their bounds.
const coords: [number, number][] = [];
for (const m of foldedSvg.matchAll(/points="([^"]+)"/g)) {
  for (const pair of m[1]!.trim().split(/\s+/)) {
    const [x, y] = pair.split(",").map(Number);
    coords.push([x!, y!]);
  }
}
for (const m of foldedSvg.matchAll(/<(?:line|circle)\b[^>]*>/g)) {
  const tag = m[0];
  const attr = (name: string) => Number(tag.match(new RegExp(`${name}="([-\\d.]+)"`))?.[1]);
  if (tag.startsWith("<line")) {
    coords.push([attr("x1"), attr("y1")], [attr("x2"), attr("y2")]);
  } else {
    coords.push([attr("cx"), attr("cy")]);
  }
}
const xs = coords.map(([x]) => x);
const ys = coords.map(([, y]) => y);
// Padding accounts for corner/crease-name labels, which sit just outside the
// shape's own coordinates.
const PAD = 100;
const cropX0 = Math.min(...xs) - PAD;
const cropY0 = Math.min(...ys) - PAD;
const cropWidth = Math.max(...xs) - cropX0 + PAD;
const cropHeight = Math.max(...ys) - cropY0 + PAD;

// Drop the fold's own full-canvas background rect (it covers the whole
// 572x572 render, not just the cropped region) and draw a card-sized one in
// its place, in the same pre-transform coordinate space as the crop.
const innerMarkup = foldedSvg
  .replace(/^<svg[^>]*>/, "")
  .replace(/<\/svg>\s*$/, "")
  .replace(/<rect width="\d+(?:\.\d+)?" height="\d+(?:\.\d+)?" fill="white"\/>/, "");
const cardBg =
  `<rect x="${cropX0}" y="${cropY0}" width="${cropWidth}" height="${cropHeight}" fill="white"/>`;

// Fit the cropped fold into a card on the right, vertically centered,
// leaving the left side for the wordmark.
const cardHeight = HEIGHT - 150;
const cardWidth = cardHeight * (cropWidth / cropHeight);
const scale = cardHeight / cropHeight;
const cardX = WIDTH - cardWidth - 96;
const cardY = (HEIGHT - cardHeight) / 2;

const composed = `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
  <rect width="${WIDTH}" height="${HEIGHT}" fill="${PANEL_BG}"/>
  <text x="96" y="${HEIGHT / 2 - 10}" font-family="IBM Plex Mono, monospace" font-size="72" font-weight="600" fill="${INK}">Beloch</text>
  <text x="96" y="${HEIGHT / 2 + 34}" font-family="IBM Plex Sans, sans-serif" font-size="22" fill="${INK}" opacity="0.7">A declarative language for origami</text>
  <g transform="translate(${cardX - cropX0 * scale}, ${cardY - cropY0 * scale}) scale(${scale})">
    ${cardBg}
    ${innerMarkup}
  </g>
</svg>`;

const { Resvg } = await import("@resvg/resvg-js");
const png = new Resvg(composed, { fitTo: { mode: "width", value: WIDTH } }).render().asPng();
writeFileSync(outPath, png);
console.log(`Wrote ${outPath} (${(png.length / 1024).toFixed(1)} KiB, ${WIDTH}x${HEIGHT})`);
