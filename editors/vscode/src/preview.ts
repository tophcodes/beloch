import * as vscode from "vscode";

export function registerPreview(context: vscode.ExtensionContext): void {
  const cmd = vscode.commands.registerCommand("beloch.showPreview", () => {
    const panel = vscode.window.createWebviewPanel(
      "belochPreview",
      "Beloch Preview",
      vscode.ViewColumn.Beside,
      { enableScripts: false },
    );
    panel.webview.html = `<!doctype html><html><body>
      <p>Beloch preview — rendering not implemented yet.</p>
    </body></html>`;
  });
  context.subscriptions.push(cmd);
}
