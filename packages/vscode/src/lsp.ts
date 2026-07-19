import * as vscode from "vscode";
import {
  CloseAction,
  ErrorAction,
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind,
} from "vscode-languageclient/node";
import { resolveBeloch } from "./beloch";

let client: LanguageClient | undefined;

export function registerLsp(context: vscode.ExtensionContext): void {
  // The `beloch lsp` server is not implemented yet — it exits 1 immediately.
  // Starting a LanguageClient against it makes vscode-languageclient pop up an
  // error dialog on every .bel open: `LanguageClient.start()`'s init-failure
  // path calls `showErrorMessage` directly, bypassing `clientOptions.errorHandler`
  // (so `handled: true` does not suppress it, and `.catch()` only swallows the
  // promise rejection, not the dialog). Until the LSP subsystem ships a real
  // server, do NOT start the client. The seam below is kept for that slice.
  void context;
  void startClient; // referenced so the seam isn't flagged as dead
}

/** LSP client bootstrap seam. The LSP subsystem slice calls this once
 *  `beloch lsp` is a real server. Not invoked while the server is a stub. */
function startClient(context: vscode.ExtensionContext): void {
  const argv = resolveBeloch();
  const serverOptions: ServerOptions = {
    command: argv[0],
    args: [...argv.slice(1), "lsp"],
    transport: TransportKind.stdio,
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: "file", language: "beloch" }],
    errorHandler: {
      error: () => ({ action: ErrorAction.Continue, handled: true }),
      closed: () => ({ action: CloseAction.DoNotRestart, handled: true }),
    },
  };

  client = new LanguageClient("beloch", "Beloch Language Server", serverOptions, clientOptions);
  client.start().catch(() => {
    // swallow start failures instead of surfacing them
  });
  context.subscriptions.push({
    dispose: () => {
      client?.stop().catch(() => {});
    },
  });
}
