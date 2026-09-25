#!/usr/bin/env bun
// fold2svg-compatible CLI: FOLD -> labelled SVG/PNG diagram, on top of
// @beloch/scene + @beloch/render-svg. Flag parsing ported from
// tools/fold2svg.mjs:162-184 (minus the rabbit-ear load-check — the OCaml
// emitter's own tests own FOLD validity).
// Usage:
//   bun bin/fold2svg.ts input.fold [out.svg|out.png] [--title "..."]
//   bun bin/fold2svg.ts f.fold --view folded [--flip] [--hidden dashed|hide]
//   beloch fold --trace f.bel | bun bin/fold2svg.ts - --view candidates [--statement N]
//   beloch fold f.bel | bun bin/fold2svg.ts - out.png --title f.bel
import { parseFold, SceneError, StepNotFoundError } from "@beloch/scene";
import { renderCandidates, renderCP, renderFolded } from "@beloch/render-svg";

const args = process.argv.slice(2);
const flagVal = (name: string): string | undefined => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

const title = flagVal("--title") || "";
const viewFlag = flagVal("--view"); // undefined | "cp" | "folded" | "candidates"
if (viewFlag !== undefined && viewFlag !== "cp" && viewFlag !== "folded" && viewFlag !== "candidates") {
  // process.stderr.write, not console.error — Bun's console.error unconditionally
  // ANSI-colors its argument even when stderr is piped (non-TTY), which would break
  // the plain-text stderr assertions below.
  process.stderr.write(
    `beloch-render: unknown --view value '${viewFlag}' — expected cp, folded or candidates\n`,
  );
  process.exit(1);
}
const flip = args.includes("--flip");
const hidden = (flagVal("--hidden") || "hide") as "dashed" | "hide";
const labelsFlag = flagVal("--labels"); // undefined = show none
const legend = args.includes("--legend");
const step = flagVal("--step");
const formatFlag = flagVal("--format"); // "svg"|"png", overrides outPath extension
const widthFlag = flagVal("--width"); // PNG output width in px; default = doc width
const FLAGS = new Set([
  "--title", "--view", "--hidden", "--labels", "--step", "--format", "--width", "--statement",
]);
const SWITCHES = new Set(["--flip", "--legend"]);
// An option this CLI does not know would otherwise read as a positional, and
// `-o out.svg` would write a file named `-o`. `-` alone is stdin.
const unknown = args.find(
  (a, i) => a.startsWith("-") && a !== "-" && !FLAGS.has(a) && !SWITCHES.has(a) && !FLAGS.has(args[i - 1]!),
);
if (unknown !== undefined) {
  process.stderr.write(`beloch-render: unknown option '${unknown}'\n`);
  process.exit(1);
}
const positional = args.filter((a, i) => !a.startsWith("--") && !FLAGS.has(args[i - 1]!));
const [inPath, outPath] = positional;
const format = formatFlag ?? (outPath?.endsWith(".png") ? "png" : "svg");

// undefined = show none; an explicit list renders exactly those named
// points/lines, even if also drawn elsewhere (a crease, a paper corner).
const labels = labelsFlag !== undefined
  ? labelsFlag.split(",").map((s) => s.trim()).filter(Boolean)
  : undefined;

try {
  const raw = !inPath || inPath === "-" ? await Bun.stdin.text() : await Bun.file(inPath).text();
  const scene = parseFold(raw);
  const opts = { title, labels, legend };
  const statementFlag = flagVal("--statement");
  const statement = statementFlag !== undefined ? Number(statementFlag) : undefined;
  const doc = viewFlag === "folded"
    ? renderFolded(scene, { ...opts, view: flip ? "bottom" : "top", hidden, step })
    : viewFlag === "candidates"
      ? renderCandidates(scene, { ...opts, statement })
      : renderCP(scene, opts);
  const svg = doc.toString();

  if (format === "png") {
    const { Resvg } = await import("@resvg/resvg-js");
    const width = widthFlag ? Number(widthFlag) : doc.width;
    const png = new Resvg(svg, { background: "white", fitTo: { mode: "width", value: width } })
      .render().asPng();
    if (outPath) await Bun.write(outPath, png);
    else process.stdout.write(png);
  } else if (outPath) {
    await Bun.write(outPath, svg);
  } else {
    process.stdout.write(svg);
  }
} catch (err) {
  if (err instanceof StepNotFoundError) {
    // process.stderr.write, not console.error — see comment near --view parsing above.
    process.stderr.write(
      `beloch-render: ${StepNotFoundError.render(err.label, err.available)}\n`,
    );
  } else if (err instanceof SceneError) {
    process.stderr.write(`beloch-render: ${err.message}\n`);
  } else {
    throw err;
  }
  process.exit(1);
}
