import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

/**
 * Evaluate Beloch source to a FOLD object using the native `beloch` binary.
 *
 * Build-time only — never import this into a client bundle. `beloch` must be on
 * PATH (the Nix devShell provides it in dev; `nix build .#beloch` in CI). Throws
 * an Error carrying beloch's stderr diagnostic if evaluation fails, so an
 * example that no longer parses/evaluates breaks the Astro build (drift guard).
 */
export function evalBelToFold(source: string): unknown {
  const dir = mkdtempSync(join(tmpdir(), "beloch-"));
  const file = join(dir, "snippet.bel");
  try {
    writeFileSync(file, source);
    let stdout: string;
    try {
      stdout = execFileSync("beloch", ["fold", file], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch (err) {
      const e = err as { code?: string; stderr?: Buffer | string; message?: string };
      if (e.code === "ENOENT") {
        throw new Error(
          "beloch: binary not found on PATH — run `nix develop` (or `nix build .#beloch` in CI).",
        );
      }
      const stderr = e.stderr?.toString() ?? "";
      throw new Error(`beloch fold failed:\n${stderr || e.message || String(err)}`);
    }
    return JSON.parse(stdout);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
