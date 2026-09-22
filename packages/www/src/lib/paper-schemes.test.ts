import { test, expect } from "bun:test";
import { SCHEMES, DEFAULT_ID, resolveScheme, schemeVars, headSyncScript } from "./paper-schemes";

test("catalog has the four v1 schemes with the default first", () => {
  expect(SCHEMES.map((s) => s.id)).toEqual(["white", "kraft", "washi", "indigo"]);
  expect(SCHEMES[0].id).toBe(DEFAULT_ID);
});

test("resolveScheme falls back to default for unknown/empty id", () => {
  expect(resolveScheme("nope").id).toBe(DEFAULT_ID);
  expect(resolveScheme(null).id).toBe(DEFAULT_ID);
});

test("schemeVars sets ink vars for dark paper, clears them for light", () => {
  const indigoScheme = resolveScheme("indigo");
  const indigo = schemeVars(indigoScheme);
  expect(indigo["--bel-paper-front"]).toBe("#3b4a6b");
  // Ink and boundary move together and take the scheme's own value, so a
  // contrast correction there does not have to be restated here.
  expect(indigo["--bel-paper-ink"]).toBe(indigoScheme.ink);
  expect(indigo["--bel-paper-boundary"]).toBe(indigoScheme.ink);

  const white = schemeVars(resolveScheme("white"));
  expect(white["--bel-paper-front"]).toBe("#fafaf7");
  expect(white["--bel-paper-ink"]).toBeNull();
  expect(white["--bel-paper-boundary"]).toBeNull();
});

test("headSyncScript embeds the catalog and reads the storage key", () => {
  const src = headSyncScript();
  expect(src).toContain("beloch-paper");
  expect(src).toContain("--bel-paper-front");
  expect(src).toContain("#3b4a6b"); // indigo baked in
});
