/** The two programs the standalone pages ship, each rendered to a static SVG
 *  at build time and handed to the card as its starting source.
 *
 *  Each is a display copy of a corpus file rather than the corpus file itself,
 *  because those open with a source-attribution comment block and end with
 *  `; assert` lines that are test fixture, not something a first-time visitor
 *  should have to scroll past. `landing-examples.test.ts` checks each copy
 *  evaluates to the same FOLD as its corpus file, so a display copy cannot
 *  drift from the corpus in anything but comments.
 *
 *  The playground starts on the bird base, and the hero goes one step further
 *  and lifts its petals. The hero's copy keeps its lines short enough for its
 *  narrower column, and wraps a statement where one would run past it. */
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

const read = (name: string) => readFileSync(join(siteDir, "src", "lib", name), "utf-8");

/** The landing hero's program: a display copy of examples/bases/bird-base-petal.bel. */
export const HERO_SRC = read("landing-hero.bel");

/** The playground's starting program: a display copy of examples/bases/bird-base.bel. */
export const PLAYGROUND_SRC = read("playground-start.bel");
