#!/usr/bin/env bun
// fold2svg-compatible CLI: FOLD -> labelled SVG/PNG diagram, on top of
// @beloch/scene + @beloch/render-svg. Flag parsing ported from
// tools/fold2svg.mjs:162-184 (minus the rabbit-ear load-check — the OCaml
// emitter's own tests own FOLD validity).
// Usage:
//   bun bin/fold2svg.ts input.fold [out.svg|out.png] [--title "..."]
//   bun bin/fold2svg.ts f.fold --view folded [--flip] [--hidden dashed|hide]
//   bun bin/fold2svg.ts f.fold --style mono|cp
//   beloch fold f.bel | bun bin/fold2svg.ts - out.png --title f.bel
import { parseFold, SceneError, StepNotFoundError } from "@beloch/scene";
import { PRESETS, renderCP, renderFolded } from "@beloch/render-svg";

const args = process.argv.slice(2);
const flagVal = (name: string): string | undefined => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

const title = flagVal("--title") || "";
const viewFlag = flagVal("--view"); // undefined | "cp" | "folded"
if (viewFlag !== undefined && viewFlag !== "cp" && viewFlag !== "folded") {
  // process.stderr.write, not console.error — Bun's console.error unconditionally
  // ANSI-colors its argument even when stderr is piped (non-TTY), which would break
  // the plain-text stderr assertions below and this CLI's own TTY-conditional styling
  // (see the step-not-found case below).
  process.stderr.write(
    `beloch-render: unknown --view value '${viewFlag}' — expected cp or folded\n`,
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
const styleFlag = flagVal("--style") ?? "yr"; // "yr"|"mono"|"cp"
if (!(styleFlag in PRESETS)) {
  // process.stderr.write, not console.error — see the --view comment above.
  process.stderr.write(
    `beloch-render: unknown --style value '${styleFlag}' — expected yr, mono, or cp\n`,
  );
  process.exit(1);
}
const FLAGS = new Set([
  "--title", "--view", "--hidden", "--labels", "--step", "--format", "--width", "--style",
]);
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
  const opts = { title, labels, legend, theme: { lineStyle: PRESETS[styleFlag]! } };
  const doc = viewFlag === "folded"
    ? renderFolded(scene, { ...opts, view: flip ? "bottom" : "top", hidden, step })
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
    const tty = process.stderr.isTTY;
    const style = tty ? (s: string) => `\x1b[1;36m${s}\x1b[0m` : (s: string) => s;
    // process.stderr.write, not console.error — see comment near --view parsing above.
    // Using console.error here specifically would defeat the TTY check just above:
    // it would always color the step name, even for piped/non-TTY output.
    process.stderr.write(
      `beloch-render: ${StepNotFoundError.render(err.label, err.available, style)}\n`,
    );
  } else if (err instanceof SceneError) {
    process.stderr.write(`beloch-render: ${err.message}\n`);
  } else {
    throw err;
  }
  process.exit(1);
}
