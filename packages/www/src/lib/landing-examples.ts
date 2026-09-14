/** The landing page's hero program: rendered to a static SVG at build time
 *  and loaded into the live playground. Read from `examples/bases/bird-base.bel`
 *  rather than duplicated here, so the landing page and the example file
 *  cannot drift and the `.bel` corpus's own asserts cover it. */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = process.env.BELOCH_REPO_ROOT ?? join(here, "..", "..", "..", "..");

export const HERO_SRC = readFileSync(
  join(repoRoot, "examples", "bases", "bird-base.bel"),
  "utf-8",
);
