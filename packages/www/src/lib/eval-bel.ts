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
 * With `trace`, the file carries `beloch:trace`, and a program that evaluates
 * up to a failing statement returns that file instead of throwing.
 */
export function evalBelToFold(source: string, opts: { trace?: boolean } = {}): unknown {
  const dir = mkdtempSync(join(tmpdir(), "beloch-"));
  const file = join(dir, "snippet.bel");
  try {
    writeFileSync(file, source);
    let stdout: string;
    try {
      stdout = execFileSync("beloch", opts.trace ? ["fold", "--trace", file] : ["fold", file], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch (err) {
      const e = err as {
        code?: string; stdout?: Buffer | string; stderr?: Buffer | string; message?: string;
      };
      // Traced, a program that fails still writes its file, with the failure in
      // `beloch:error` (spec/FOLD.md, "The trace"); a figure may draw that state.
      const partial = opts.trace ? e.stdout?.toString() : undefined;
      if (partial) return JSON.parse(partial);
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
