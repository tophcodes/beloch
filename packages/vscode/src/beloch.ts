import { execSync } from "node:child_process";

export interface ResolveDeps {
  configPath?: string;
  existsOnPath: (cmd: string) => boolean;
}

/** Pure resolution logic. Returns the argv prefix to invoke beloch. */
export function resolveBelochArgv(deps: ResolveDeps): string[] {
  if (deps.configPath && deps.configPath.length > 0) return [deps.configPath];
  if (deps.existsOnPath("beloch")) return ["beloch"];
  return ["dune", "exec", "beloch", "--"];
}

function onPath(cmd: string): boolean {
  try {
    execSync(process.platform === "win32" ? `where ${cmd}` : `command -v ${cmd}`, {
      stdio: "ignore",
    });
    return true;
  } catch {
    return false;
  }
}

/**
 * Resolve the beloch invocation from the current workspace configuration.
 *
 * Consumers must spawn the returned argv with `cwd` set to the workspace
 * folder — the `dune exec` fallback requires it.
 */
export function resolveBeloch(): string[] {
  // Lazy load vscode to avoid module resolution issues in testing environments
  const vscode = require("vscode") as typeof import("vscode");
  const configPath = vscode.workspace.getConfiguration("beloch").get<string>("path");
  return resolveBelochArgv({ configPath, existsOnPath: onPath });
}
