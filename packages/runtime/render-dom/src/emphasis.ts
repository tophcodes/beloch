// Lighting what a piece of source named, in the palette that already means
// "this word means this thing in the drawing" (docs/brand/design-language.md,
// B1.2 and B1.10). Each entity takes the next colour, so two things named by
// the same source stay apart.
//
// This is a second statement over the drawing, beside the highlight a reader's
// pointer or pick makes: that one says "you are on this", and it keeps the
// interface accent. A pick therefore outranks the palette on its own entity,
// which the host's stylesheet settles rather than this module.
import { DEFAULT_THEME } from "@beloch/render-svg";
import { HIT_CLASS } from "./hits";

export const EMPHASIS_CLASS = "bel-em";
// The colour of the slot an emphasised entity took, for the host's stylesheet
// to paint stroke, fill or both from.
export const EMPHASIS_VAR = "--bel-em";

// What a caller names. A crease is its bundle id (ADR-0014), a point and a
// construction line are the names the program gave them.
export interface Emphasis {
  creases: string[];
  points: string[];
  lines: string[];
}

const escapeAttr = (value: string): string =>
  typeof CSS !== "undefined" && typeof CSS.escape === "function"
    ? CSS.escape(value)
    : value.replace(/"/g, '\\"');

// One selector per kind, in the order the drawing carries them.
const selectorsFor = (emphasis: Emphasis): string[] => [
  ...emphasis.creases.map((id) => `[data-crease-id="${escapeAttr(id)}"]`),
  ...emphasis.lines.map((name) => `[data-construction="${escapeAttr(name)}"]`),
  ...emphasis.points.map((name) => `[data-bel-name="${escapeAttr(name)}"]`),
];

export function clearEmphasis(root: ParentNode): void {
  root.querySelectorAll(`.${EMPHASIS_CLASS}`).forEach((el) => {
    el.classList.remove(EMPHASIS_CLASS);
    (el as HTMLElement).style.removeProperty(EMPHASIS_VAR);
  });
}

// Lights every element the emphasis names, one palette colour per entity,
// clearing what the last call lit. An entity the drawing does not carry at
// this step lights nothing, which is the honest answer rather than a promise
// the picture cannot keep.
export function applyEmphasis(root: ParentNode, emphasis: Emphasis | null): void {
  clearEmphasis(root);
  if (emphasis === null) return;
  const palette = DEFAULT_THEME.highlightPalette;
  selectorsFor(emphasis).forEach((selector, i) => {
    const colour = palette[i % palette.length]!.stroke;
    root.querySelectorAll(selector).forEach((el) => {
      // A hit twin is transparent on purpose; painting it would put a fat
      // stroke over the thin mark it covers.
      if (el.classList.contains(HIT_CLASS)) return;
      el.classList.add(EMPHASIS_CLASS);
      (el as HTMLElement).style.setProperty(EMPHASIS_VAR, colour);
    });
  });
}
