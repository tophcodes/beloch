import * as vscode from "vscode";
import { registerLsp } from "./lsp";
import { registerPreview } from "./preview";

export function activate(context: vscode.ExtensionContext): void {
  registerLsp(context);
  registerPreview(context);
}

export function deactivate(): void {}
