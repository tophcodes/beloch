// A construction line is geometry the program built that the paper never
// carries: it is drawn as an overlay or it is not in the picture at all. The
// fixture names one before the first fold (`--diag`), one after it
// (`--slant`), and folds two more into creases (`--bd`, `--ac`).
import { test, expect } from "bun:test";
import { parseFold, type FoldScene } from "@beloch/scene";
import { WEB_THEME } from "@beloch/render-svg";
import { createRuntime, renderCommand, type RenderOptions } from "@beloch/runtime";
import { commandToSvg } from "../src/svg";

const scene: FoldScene = parseFold(
  await Bun.file(new URL("./fixtures/constructions.fold", import.meta.url)).text(),
);
const folded: RenderOptions = { view: "folded", hidden: "hide" };
const cp: RenderOptions = { view: "cp", hidden: "hide" };

const drawnAt = (step: number, options: RenderOptions): string[] => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene });
  rt.dispatch({ type: "step/to", index: step });
  const svg = commandToSvg(scene, renderCommand(rt.state, options)!, WEB_THEME);
  return [...svg.matchAll(/data-construction="([^"]+)"/g)].map((m) => m[1]!).sort();
};

test("the sheet before any statement shows the line named before it", () => {
  expect(drawnAt(0, cp)).toEqual(["diag"]);
  expect(drawnAt(0, folded)).toEqual(["diag"]);
});

test("a line named later joins the drawing at the step that named it", () => {
  expect(drawnAt(1, folded)).toEqual(["diag", "slant"]);
  expect(drawnAt(2, folded)).toEqual(["diag", "slant"]);
});

test("a named line that was folded is drawn as its crease, not twice", () => {
  // `--bd` and `--ac` are named by the same program and exist by the last
  // step; the overlay leaves them to the creases they became.
  const last = drawnAt(2, folded);
  expect(last).not.toContain("bd");
  expect(last).not.toContain("ac");
});

test("both views of one step draw the same constructions", () => {
  expect(drawnAt(1, cp)).toEqual(drawnAt(1, folded));
  expect(drawnAt(2, cp)).toEqual(drawnAt(2, folded));
});

test("a construction carries its name into the drawing", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene });
  const svg = commandToSvg(scene, renderCommand(rt.state, folded)!, WEB_THEME);
  expect(svg).toContain("--slant");
});
