#!/usr/bin/env bun
// fold2svg-compatible CLI: FOLD -> labelled SVG/PNG diagram, on top of
// @beloch/scene + @beloch/render-svg. Flag parsing ported from
// tools/fold2svg.mjs:162-184 (minus the rabbit-ear load-check — the OCaml
// emitter's own tests own FOLD validity).
// Usage:
//   bun bin/fold2svg.ts input.fold [out.svg|out.png] [--title "..."]
//   bun bin/fold2svg.ts f.fold --view top|bottom [--hidden dashed|hide]
//   beloch fold f.bel | bun bin/fold2svg.ts - out.png --title f.bel
import { parseFold } from "@beloch/scene";
import { renderCP, renderFolded } from "@beloch/render-svg";

const args = process.argv.slice(2);
const flagVal = (name: string): string | undefined => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

const title = flagVal("--title") || "";
const viewFlag = args.includes("--folded") ? "top" : flagVal("--view"); // top|bottom
const hidden = (flagVal("--hidden") || "hide") as "dashed" | "hide";
const constructionsFlag = flagVal("--constructions"); // undefined = show all
const step = flagVal("--step");
const FLAGS = new Set(["--title", "--view", "--hidden", "--constructions", "--step"]);
const positional = args.filter((a, i) => !a.startsWith("--") && !FLAGS.has(args[i - 1]!));
const [inPath, outPath] = positional;

// undefined = show all (fold2svg.mjs:360); "" splits to [] = show none.
const constructions = constructionsFlag !== undefined
  ? constructionsFlag.split(",").map((s) => s.trim()).filter(Boolean)
  : undefined;

const raw = !inPath || inPath === "-" ? await Bun.stdin.text() : await Bun.file(inPath).text();
const scene = parseFold(raw);
const opts = { title, constructions };
const doc = viewFlag
  ? renderFolded(scene, { ...opts, view: viewFlag as "top" | "bottom", hidden, step })
  : renderCP(scene, opts);
const svg = doc.toString();

if (outPath?.endsWith(".png")) {
  const { Resvg } = await import("@resvg/resvg-js");
  const png = new Resvg(svg, { background: "white", fitTo: { mode: "width", value: doc.width } })
    .render().asPng();
  await Bun.write(outPath, png);
} else if (outPath) {
  await Bun.write(outPath, svg);
} else {
  process.stdout.write(svg);
}
