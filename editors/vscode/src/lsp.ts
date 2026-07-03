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
  const argv = resolveBeloch();
  const serverOptions: ServerOptions = {
    command: argv[0],
    args: [...argv.slice(1), "lsp"],
    transport: TransportKind.stdio,
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: "file", language: "beloch" }],
    // The server is a stub today; do not surface its failures to the user.
    errorHandler: {
      error: () => ({ action: ErrorAction.Continue, handled: true }),
      closed: () => ({ action: CloseAction.DoNotRestart, handled: true }),
    },
  };

  client = new LanguageClient("beloch", "Beloch Language Server", serverOptions, clientOptions);
  client.start().catch(() => {
    // stub server; swallow start failures instead of surfacing them
  });
  context.subscriptions.push({
    dispose: () => {
      client?.stop().catch(() => {});
    },
  });
}
