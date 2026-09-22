import { test, expect } from "bun:test";
import { DEFAULT_THEME, HIGHLIGHT_TEXT } from "@beloch/render-svg";

const read = (p: string) => Bun.file(new URL(p, import.meta.url)).text();

// A `paper` role and the Theme field it mirrors. resvg resolves no var(), so
// the renderer has to carry every one of these as a literal and the stylesheet
// carries it a second time for the surfaces that do resolve var(); nothing but
// this test holds the two copies equal. `highlightPalette` and `lineStyle` are
// out: neither is a single colour, and the highlights have their own test
// below.
const PAPER_ROLES = [
  "fill",
  "front",
  "back",
  "background",
  "ink",
  "boundary",
  "mountain",
  "valley",
  "flat",
  "unassigned",
  "construction",
] as const;

const declarations = (css: string): Map<string, string> => {
  const out = new Map<string, string>();
  for (const [, name, value] of css.matchAll(/(--bel-[a-z0-9-]+)\s*:\s*([^;]+);/g)) {
    if (!out.has(name)) out.set(name, value.trim());
  }
  return out;
};

test("the paper layer and the renderer's Theme carry the same roles", async () => {
  const vars = declarations(await read("../styles/theme.css"));
  const inCss = [...vars.keys()]
    .filter((n) => n.startsWith("--bel-paper-"))
    .map((n) => n.slice("--bel-paper-".length))
    .sort();
  expect(inCss).toEqual([...PAPER_ROLES].sort());

  const inTheme = Object.keys(DEFAULT_THEME)
    .filter((k) => k !== "highlightPalette" && k !== "lineStyle")
    .sort();
  expect(inTheme).toEqual([...PAPER_ROLES].sort());
});

test("the paper layer and the renderer's Theme carry the same values", async () => {
  const vars = declarations(await read("../styles/theme.css"));
  for (const role of PAPER_ROLES) {
    expect(vars.get(`--bel-paper-${role}`)).toBe(
      DEFAULT_THEME[role as keyof typeof DEFAULT_THEME] as string,
    );
  }
});

// The caption of a figure names entities the drawing highlights, and the name
// has to be printed in the colour the drawing uses. Three surfaces carry the
// value, because neither the SVG in the PDF nor the typst show rule resolves a
// variable.
test("figure highlight captions carry HIGHLIGHT_TEXT on the web and in print", async () => {
  const css = await read("../styles/theme.css");
  const typ = await read("../../../../scripts/typst-compat.typ");

  HIGHLIGHT_TEXT.forEach((colour, i) => {
    expect(css).toContain(`.figure-hl-${i} { color: ${colour}; }`);
    expect(typ).toContain(`#show raw.where(lang: "figure-hl-${i}"): it => text(fill: rgb("${colour}"))`);
  });

  // No seventh colour on either side: a caption that asks for one wraps round
  // to the first, and a stray rule would silently give it its own.
  expect(css).not.toContain(`.figure-hl-${HIGHLIGHT_TEXT.length}`);
  expect(typ).not.toContain(`figure-hl-${HIGHLIGHT_TEXT.length}`);
});
