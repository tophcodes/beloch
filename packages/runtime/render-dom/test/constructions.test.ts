// A construction line is geometry the program built that the paper never
// carries, so the drawing shows it where the reader asked about it: all of
// them at once is a second drawing over the first. The fixture names one
// before the first fold (`--diag`), one after it (`--slant`), and folds two
// more into creases (`--bd`, `--ac`).
import { test, expect } from "bun:test";
import { parseFold, type FoldScene } from "@beloch/scene";
import { WEB_THEME } from "@beloch/render-svg";
import { createRuntime, renderCommand, type EntityRef, type RenderOptions } from "@beloch/runtime";
import { commandToSvg } from "../src/svg";

const scene: FoldScene = parseFold(
  await Bun.file(new URL("./fixtures/constructions.fold", import.meta.url)).text(),
);
const folded: RenderOptions = { view: "folded", hidden: "hide" };
const cp: RenderOptions = { view: "cp", hidden: "hide" };

const line = (name: string): EntityRef => ({ kind: "construction", name });

const drawnAt = (step: number, options: RenderOptions, selection: EntityRef[] = []): string[] => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene });
  rt.dispatch({ type: "step/to", index: step });
  rt.dispatch({ type: "selection/set", entities: selection });
  const svg = commandToSvg(scene, renderCommand(rt.state, options)!, WEB_THEME);
  // The overlay marks the shapes and the name it writes out with the same
  // attribute, so one line reaches the drawing twice; what is asked here is
  // which lines are in it.
  return [...new Set([...svg.matchAll(/data-construction="([^"]+)"/g)].map((m) => m[1]!))].sort();
};

test("a picture nobody has picked anything in carries no construction", () => {
  expect(drawnAt(0, cp)).toEqual([]);
  expect(drawnAt(2, folded)).toEqual([]);
});

test("the sheet before any statement shows the line named before it", () => {
  expect(drawnAt(0, cp, [line("diag")])).toEqual(["diag"]);
  expect(drawnAt(0, folded, [line("diag")])).toEqual(["diag"]);
});

test("a line joins the drawing at the step that named it", () => {
  // `--slant` is named after the first fold, so at step 0 there is nothing to
  // draw however it is picked.
  expect(drawnAt(0, folded, [line("slant")])).toEqual([]);
  expect(drawnAt(1, folded, [line("slant")])).toEqual(["slant"]);
});

test("two picked lines are both drawn", () => {
  expect(drawnAt(2, folded, [line("diag"), line("slant")])).toEqual(["diag", "slant"]);
});

test("a named line that was folded is drawn as its crease, not twice", () => {
  // `--bd` and `--ac` are named by the same program and exist by the last
  // step; the overlay leaves them to the creases they became.
  expect(drawnAt(2, folded, [line("bd"), line("ac")])).toEqual([]);
});

test("both views of one step draw the same constructions", () => {
  const picked = [line("diag"), line("slant")];
  expect(drawnAt(1, cp, picked)).toEqual(drawnAt(1, folded, picked));
  expect(drawnAt(2, cp, picked)).toEqual(drawnAt(2, folded, picked));
});

// The name a line carries into the drawing is the one the reader settled on,
// so a picture nobody has picked anything in has no word on it.
test("a construction carries its name into the drawing once it is selected", () => {
  const rt = createRuntime();
  rt.dispatch({ type: "document/set", scene });
  expect(commandToSvg(scene, renderCommand(rt.state, folded)!, WEB_THEME)).not.toContain("--slant");
  rt.dispatch({ type: "selection/set", entities: [line("slant")] });
  const svg = commandToSvg(scene, renderCommand(rt.state, folded)!, WEB_THEME);
  expect(svg).toContain("--slant");
  // The one that was not picked stays out of the picture.
  expect(svg).not.toContain("--diag");
});
