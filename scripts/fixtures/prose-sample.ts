// Checks for scripts/prose.test.ts. Two comments hold a British spelling, on
// line 9 and line 11; the same word in code, in strings, in a code span and
// in a token shaped like code must pass.
const colour = "colour // colour";
const template = `colour /* colour */
colour`;
/**
 * A doc comment with `colour` in a code span, https://colour.example/colour,
 * <colour> as a tag, and the colour of a crease in prose.
 */
export const paletteColour = { colour_1: colour, template }; // Its colour.
