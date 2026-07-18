import { test, expect } from "bun:test";
import { DEFAULT_THEME, PRESETS } from "@beloch/render-svg";

const theme = DEFAULT_THEME;

test("PRESETS exposes exactly yr, mono, cp", () => {
  expect(Object.keys(PRESETS).sort()).toEqual(["cp", "mono", "yr"]);
});

test("yr preset: Lang diagramming conventions, monochrome ink", () => {
  const style = PRESETS.yr!;
  expect(style("B", theme)).toEqual({ stroke: theme.boundary, strokeWidth: 3 });
  expect(style("M", theme)).toEqual({
    stroke: theme.ink, strokeWidth: 1.75, dasharray: "10 3 1.5 3",
  });
  expect(style("V", theme)).toEqual({ stroke: theme.ink, strokeWidth: 1.75, dasharray: "6 4" });
  expect(style("F", theme)).toEqual({
    stroke: theme.ink, strokeWidth: 1.25, dasharray: "1 3", opacity: 0.45,
  });
  expect(style("U", theme)).toEqual({
    stroke: theme.unassigned, strokeWidth: 1.25, dasharray: "2 3", opacity: 0.55,
  });
});

test("mono preset: weight-coded, all solid ink [hull2020, §7.1]", () => {
  const style = PRESETS.mono!;
  expect(style("B", theme)).toEqual({ stroke: theme.ink, strokeWidth: 3 });
  expect(style("M", theme)).toEqual({ stroke: theme.ink, strokeWidth: 2.6 });
  expect(style("V", theme)).toEqual({ stroke: theme.ink, strokeWidth: 1.2 });
  expect(style("F", theme)).toEqual({
    stroke: theme.ink, strokeWidth: 1, dasharray: "1 3", opacity: 0.4,
  });
  expect(style("U", theme)).toEqual({
    stroke: theme.ink, strokeWidth: 1.2, dasharray: "2 3", opacity: 0.55,
  });
});

test("cp preset: tool-color convention, undriven = Origami Simulator magenta", () => {
  const style = PRESETS.cp!;
  expect(style("B", theme)).toEqual({ stroke: theme.boundary, strokeWidth: 3 });
  expect(style("M", theme)).toEqual({ stroke: theme.mountain, strokeWidth: 2 });
  expect(style("V", theme)).toEqual({ stroke: theme.valley, strokeWidth: 2 });
  expect(style("F", theme)).toEqual({ stroke: theme.flat, strokeWidth: 1.5, opacity: 0.5 });
  expect(style("U", theme)).toEqual({ stroke: "#d946ef", strokeWidth: 2, opacity: 0.8 });
});
