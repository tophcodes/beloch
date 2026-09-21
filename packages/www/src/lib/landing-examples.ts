/** The landing page's hero program: rendered to a static SVG at build time
 *  and loaded into the live playground. Kept as its own display file
 *  (`landing-hero.bel`) rather than the raw `examples/bases/bird-base.bel`,
 *  because that corpus file opens with a source-attribution comment block
 *  and ends with `; assert` lines that are test fixture, not something a
 *  first-time visitor should have to scroll past. `landing-examples.test.ts`
 *  checks the two evaluate to the same FOLD, so this display copy cannot
 *  drift from the corpus in anything but comments. */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

// Resolve against the site dir. import.meta.url is unreliable in Astro prerender
// bundles, so prefer BELOCH_REPO_ROOT (set in astro.config.mjs); fall back to the
// module path for `bun test` / standalone use. Same pattern as highlight-bel.ts.
const here = dirname(fileURLToPath(import.meta.url));
const siteDir = process.env.BELOCH_REPO_ROOT
  ? join(process.env.BELOCH_REPO_ROOT, "packages", "www")
  : join(here, "..", "..");

export const HERO_SRC = readFileSync(
  join(siteDir, "src", "lib", "landing-hero.bel"),
  "utf-8",
);
