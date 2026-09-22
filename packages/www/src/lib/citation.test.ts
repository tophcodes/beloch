import { test, expect } from "bun:test";
import { readCitation, citedName, doiUrl, bibtex, apa } from "./citation.ts";

const c = readCitation();

test("the citation comes out of CITATION.cff", () => {
  expect(c.doi).toMatch(/^10\.\d{4,}\/[^\s]+$/);
  expect(c.version).toMatch(/^\d+\.\d+\.\d+$/);
  expect(c.dateReleased).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  expect(c.orcid).toStartWith("https://orcid.org/");
  // A WebID is a URI with a fragment: the document is not the person.
  expect(c.webid).toMatch(/^https:\/\/[^\s#]+#[^\s#]+$/);
  expect(c.familyNames.length).toBeGreaterThan(0);
  expect(c.givenNames.length).toBeGreaterThan(0);
});

test("the derived forms carry the same values", () => {
  expect(citedName(c)).toBe(`${c.familyNames}, ${c.givenNames}`);
  expect(doiUrl(c)).toBe(`https://doi.org/${c.doi}`);
  expect(bibtex(c)).toContain(`doi       = {${c.doi}}`);
  expect(bibtex(c)).toContain(`version   = {${c.version}}`);
  expect(apa(c)).toContain(c.version);
  expect(apa(c)).toContain(c.doi);
});

// A wrong name in a citation is worse than no citation, so the reader fails
// loudly rather than handing back an empty string.
test("a missing field is an error, not a blank", () => {
  expect(() => readCitation("/dev/null")).toThrow(/no title/);
});
