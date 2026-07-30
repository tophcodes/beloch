import * as vscode from "vscode";

/** Activation entry point. Language id, grammar and bracket/comment config are
 *  contributed declaratively by `package.json`, so there is nothing to register
 *  yet — this is the seam a future editor-integration slice hooks into. */
export function activate(context: vscode.ExtensionContext): void {
  void context;
}

export function deactivate(): void {}
