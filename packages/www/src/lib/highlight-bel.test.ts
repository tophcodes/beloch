import { test, expect } from "bun:test";
import { highlightBel } from "./highlight-bel";

test("variable tokens get data-bel-name, non-variables don't", async () => {
  const html = await highlightBel(
    "paper square\nmark --d1 = through .a .c\n.center = --d1 * --d2\n",
  );
  expect(html).toContain('data-bel-name="d1"');
  expect(html).toContain('data-bel-name="center"');
  expect(html).toContain('data-bel-name="a"');
  // keyword 'through' must not be tagged
  expect(html).not.toMatch(/data-bel-name="through"/);
});

test("bracket operators are not tagged as variables", async () => {
  const html = await highlightBel("paper square\n.center = .[--d1 --d2]\n");
  // the '.[' meet-bracket must not produce data-bel-name="["
  expect(html).not.toContain('data-bel-name="["');
});
