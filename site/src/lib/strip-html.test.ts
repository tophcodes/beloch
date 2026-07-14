import { test, expect } from "bun:test";
import { stripHtml } from "./strip-html";

test("decodes the numeric ampersand entity Astro emits for `&`", () => {
  // regression: Astro renders `&` (the keep/filter operator) as `&#x26;`, which
  // the old named-only decoder left intact → `beloch fold` lexed a literal
  // `&#x26;` and died on "unexpected character".
  expect(stripHtml("fold map (--cd &#x26; .c) onto --v")).toBe(
    "fold map (--cd & .c) onto --v",
  );
});

test("decodes decimal numeric entities too", () => {
  expect(stripHtml("a &#38; b")).toBe("a & b");
});

test("decodes the named entities and strips wrapper tags", () => {
  expect(stripHtml("<p>x &lt; y &gt; z &amp; w &quot;q&quot;</p>")).toBe(
    'x < y > z & w "q"',
  );
});

test("does not double-decode a decoded ampersand", () => {
  // `&amp;lt;` must decode to the literal text `&lt;`, not to `<`.
  expect(stripHtml("a &amp;lt; b")).toBe("a &lt; b");
});

test("leaves unknown entities untouched", () => {
  expect(stripHtml("keep &bogus; verbatim")).toBe("keep &bogus; verbatim");
});
