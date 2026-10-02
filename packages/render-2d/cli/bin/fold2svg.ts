#!/usr/bin/env bun
// fold2svg-compatible CLI: FOLD -> labeled SVG/PNG diagram, on top of
// @beloch/scene + @beloch/render-svg. It does not validate the FOLD input;
// the OCaml emitter's own tests own FOLD validity.
// Usage:
//   bun bin/fold2svg.ts input.fold [out.svg|out.png] [--title "..."]
//   bun bin/fold2svg.ts f.fold --view folded [--flip] [--hidden dashed|hide]
//   beloch fold --trace f.bel | bun bin/fold2svg.ts - --view candidates [--statement N]
//   beloch fold --trace f.bel | bun bin/fold2svg.ts - --view op [--statement N]
//   beloch fold --trace f.bel | bun bin/fold2svg.ts - --view stages --source f.bel [--statement N] [--stage N] [--checks]
//   beloch fold f.bel | bun bin/fold2svg.ts - --view side --along --s [--step K] [--far-side]
//   beloch fold f.bel | bun bin/fold2svg.ts - --view faces [--step K]
//   beloch fold f.bel | bun bin/fold2svg.ts - out.png --title f.bel
//   beloch fold f.bel | bun bin/fold2svg.ts - --view folded --plain   paper and creases, no names or point dots
//   beloch fold f.bel | bun bin/fold2svg.ts - --view yr               the YR folding diagram, one panel per step
import { parseFold, SceneError, StepNotFoundError } from "@beloch/scene";
import { renderCandidates, renderCP, renderFaces, renderFolded, renderOperation, renderSide, renderStages } from "@beloch/render-svg";
import { renderYr } from "@beloch/yr";

const args = process.argv.slice(2);
const flagVal = (name: string): string | undefined => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

const title = flagVal("--title") || "";
const viewFlag = flagVal("--view"); // undefined | "cp" | "folded" | "candidates" | "op" | "stages" | "side" | "faces" | "yr"
if (viewFlag !== undefined && !["cp", "folded", "candidates", "op", "stages", "side", "faces", "yr"].includes(viewFlag)) {
  // process.stderr.write, not console.error — Bun's console.error unconditionally
  // ANSI-colors its argument even when stderr is piped (non-TTY), which would break
  // the plain-text stderr assertions below.
  process.stderr.write(
    `beloch-render: unknown --view value '${viewFlag}' — expected cp, folded, candidates, op, stages, side, faces or yr\n`,
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
  "--source", "--stage", "--along",
]);
const SWITCHES = new Set(["--flip", "--legend", "--checks", "--far-side", "--plain"]);
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

// the program the trace's spans point into, for the stages view
const sourceText = async (): Promise<string | undefined> => {
  const path = flagVal("--source");
  return path === undefined ? undefined : await Bun.file(path).text();
};

// `--along --s` and `--along s` name the same line.
const alongName = (): string => {
  const along = flagVal("--along");
  if (along === undefined) throw new SceneError("--view side needs --along and a line name");
  return along.replace(/^--/, "");
};

try {
  const raw = !inPath || inPath === "-" ? await Bun.stdin.text() : await Bun.file(inPath).text();
  const scene = parseFold(raw);
  // --plain: no name written out (annotate: []) and so no point dot either
  // (dots: "annotated" draws the dots of written names alone), and no
  // backdrop, so the page the drawing sits on shows through.
  const opts = {
    title, labels, legend,
    ...(args.includes("--plain")
      ? { annotate: [] as string[], dots: "annotated" as const, theme: { background: "none" } }
      : {}),
  };
  const statementFlag = flagVal("--statement");
  const statement = statementFlag !== undefined ? Number(statementFlag) : undefined;
  // The diagram reports how it laid out the steps, such as a step group split
  // into 2a and 2b, as hints on stderr; the drawing is written either way.
  const yr = viewFlag === "yr"
    ? renderYr(scene, args.includes("--plain") ? { theme: { background: "none" } } : {})
    : null;
  for (const hint of yr?.hints ?? []) process.stderr.write(`beloch-render: hint: ${hint}\n`);
  const doc = yr ? yr.doc : viewFlag === "folded"
    ? renderFolded(scene, { ...opts, view: flip ? "bottom" : "top", hidden, step, orient: true })
    : viewFlag === "candidates"
      ? renderCandidates(scene, { ...opts, statement })
      : viewFlag === "op"
        ? renderOperation(scene, { ...opts, statement })
      : viewFlag === "stages"
        ? renderStages(scene, {
          ...opts, statement, source: await sourceText(),
          stage: flagVal("--stage") !== undefined ? Number(flagVal("--stage")) : undefined,
          checks: args.includes("--checks"),
        })
      : viewFlag === "side"
        ? renderSide(scene, { ...opts, along: alongName(), step, farSide: args.includes("--far-side") })
      : viewFlag === "faces"
        ? renderFaces(scene, { ...opts, step })
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
