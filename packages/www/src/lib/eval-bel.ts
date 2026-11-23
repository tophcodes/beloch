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
      // `beloch:error` (docs/reference/FOLD.md, "The trace"); a figure may draw that state.
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

/**
 * The diagnostic `beloch fold` prints for a program that fails, with the
 * program written to a file named `name`, so the message points at
 * `name:line:column`. Throws when the program evaluates: a page that shows an
 * error has to break the build once the kernel stops raising it.
 */
export function belDiagnostic(source: string, name: string): string {
  const dir = mkdtempSync(join(tmpdir(), "beloch-"));
  try {
    writeFileSync(join(dir, name), source);
    try {
      execFileSync("beloch", ["fold", name], { cwd: dir, encoding: "utf8", stdio: ["ignore", "ignore", "pipe"] });
    } catch (err) {
      const stderr = (err as { stderr?: Buffer | string }).stderr?.toString() ?? "";
      // The devshell's `beloch` runs through `dune exec`, which reports the
      // directory it enters and leaves on the same stream.
      return stderr
        .split("\n")
        .filter((l) => !/^(Entering|Leaving) directory /.test(l))
        .join("\n")
        .trimEnd();
    }
    throw new Error(`beloch fold: ${name} evaluates, but the page shows the error it should raise`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
