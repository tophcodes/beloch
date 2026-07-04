import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import * as vscode from "vscode";
import { resolveBeloch } from "./beloch";
import {
  EdgeProv,
  HostToWebview,
  HostToWebviewCursor,
  HostToWebviewDiagnostic,
  WebviewToHost,
  stepAtLine,
} from "./preview-model";
// Bundled by esbuild.mjs's `webviewScriptPlugin` from `preview-webview.ts` —
// see that file's ambient `declare module` for why this resolves for tsc.
import webviewScript from "beloch:preview-webview-script";

const DEBOUNCE_MS = 300;

// One preview panel at a time, scoped to the document it was opened for.
let panel: vscode.WebviewPanel | undefined;
let currentDoc: vscode.TextDocument | undefined;
let currentEdges: EdgeProv[] = [];
let dirty = false;
let debounceTimer: ReturnType<typeof setTimeout> | undefined;
// Best-known webview sync toggle, updated from `WebviewToHost` `state`
// messages; lets the cursor listener skip posting updates the webview would
// just ignore anyway.
let webviewSync = true;

function run(argvTail: string[], input: string, cwd: string): string {
  const argv = resolveBeloch();
  return execFileSync(argv[0], [...argv.slice(1), ...argvTail], {
    input,
    cwd,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
}

function runFold2svg(args: string[], input: string, cwd: string): string {
  return execFileSync("bun", ["tools/fold2svg.mjs", ...args], {
    input,
    cwd,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
}

function workspaceCwd(doc: vscode.TextDocument): string {
  const folder = vscode.workspace.getWorkspaceFolder(doc.uri);
  return folder?.uri.fsPath ?? path.dirname(doc.uri.fsPath);
}

/** Run `beloch fold` on the document's current text. `beloch fold` reads a
 * file path (no stdin support), so the text goes to an OS temp file first. */
function evaluateFold(
  doc: vscode.TextDocument,
  cwd: string,
): { ok: true; fold: unknown } | { ok: false; message: string } {
  const tmpFile = path.join(os.tmpdir(), `beloch-preview-${process.pid}-${Date.now()}.bel`);
  fs.writeFileSync(tmpFile, doc.getText(), "utf8");
  try {
    const out = run(["fold", tmpFile], "", cwd);
    return { ok: true, fold: JSON.parse(out) };
  } catch (err) {
    const stderr = (err as { stderr?: string }).stderr;
    return { ok: false, message: stderr && stderr.length > 0 ? stderr : String(err) };
  } finally {
    fs.rmSync(tmpFile, { force: true });
  }
}

function extractEdges(fold: Record<string, unknown>): EdgeProv[] {
  const raw = (fold["beloch:edges"] as unknown[] | undefined) ?? [];
  const edges: EdgeProv[] = [];
  for (const e of raw) {
    if (e && typeof e === "object" && "span" in e) {
      const rec = e as { span: string; step: string | null };
      edges.push({ span: rec.span, step: rec.step });
    }
  }
  return edges;
}

/** Unique `data-construction` names actually rendered (fold2svg's
 * auxiliary-only overlay skips crease/corner duplicates — reading this back
 * out of the SVG avoids re-implementing that skip logic here). */
function extractConstructions(svg: string): string[] {
  const seen = new Set<string>();
  for (const m of svg.matchAll(/data-construction="([^"]+)"/g)) seen.add(m[1]);
  return [...seen];
}

/**
 * Render the crease pattern + one folded SVG per `file_frames` entry.
 *
 * `fold2svg --step <id>` selects a frame by matching `beloch:step` against a
 * CLI string, so it can pick any *named* step directly. The baseline frame's
 * `beloch:step` is JSON `null`, which no CLI string can match — `--step`
 * would silently fall back to the *last* frame instead (fold2svg's documented
 * fallback). To render the baseline correctly, the baseline case sends a
 * trimmed FOLD (`file_frames: [thatFrame]`) so the frame is both first and
 * last and needs no `--step` match at all.
 */
function renderPayload(fold: Record<string, unknown>, cwd: string): HostToWebview {
  const foldJson = JSON.stringify(fold);
  const creasePatternSvg = runFold2svg(["-"], foldJson, cwd);
  const constructions = extractConstructions(creasePatternSvg);

  const frames = (fold["file_frames"] as Record<string, unknown>[] | undefined) ?? [];
  const steps: (string | null)[] = frames.map((f) => (f["beloch:step"] as string | null) ?? null);

  const foldedSvgByStep: Record<string, string> = {};
  for (const frame of frames) {
    const stepId = (frame["beloch:step"] as string | null) ?? null;
    const key = stepId ?? "";
    if (stepId == null) {
      const baselineJson = JSON.stringify({ ...fold, file_frames: [frame] });
      foldedSvgByStep[key] = runFold2svg(["-", "--view", "top"], baselineJson, cwd);
    } else {
      foldedSvgByStep[key] = runFold2svg(["-", "--view", "top", "--step", stepId], foldJson, cwd);
    }
  }

  return { type: "render", creasePatternSvg, foldedSvgByStep, steps, constructions };
}

function renderAndPost(doc: vscode.TextDocument): void {
  if (!panel) return;
  const cwd = workspaceCwd(doc);
  const result = evaluateFold(doc, cwd);
  if (!result.ok) {
    currentEdges = [];
    const diagnostic: HostToWebviewDiagnostic = { type: "diagnostic", message: result.message };
    panel.webview.postMessage(diagnostic);
    return;
  }
  const fold = result.fold as Record<string, unknown>;
  currentEdges = extractEdges(fold);
  panel.webview.postMessage(renderPayload(fold, cwd));
}

/** 32 random alphanumeric chars for a per-render CSP nonce. */
function makeNonce(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let nonce = "";
  for (let i = 0; i < 32; i++) nonce += chars[Math.floor(Math.random() * chars.length)];
  return nonce;
}

/** Static shell: control bar + `#stage` + the bundled webview script. All
 * rendering after this is CSS/DOM done by `webviewScript` over the SVG the
 * host posts — this function never changes based on render content. */
function panelHtml(webview: vscode.Webview): string {
  const nonce = makeNonce();
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource} data:; style-src ${webview.cspSource} 'unsafe-inline'; script-src 'nonce-${nonce}';" />
<style>
  body { font-family: sans-serif; margin: 0; padding: 8px; }
  #controls { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 8px; }
  #constructions { display: flex; gap: 8px; flex-wrap: wrap; }
  #stage svg { max-width: 100%; height: auto; }
  #stage svg [data-step].current-step { stroke-width: 3; filter: drop-shadow(0 0 2px currentColor); }
  .hidden-construction { display: none; }
  .hidden-step { display: none; }
</style>
</head>
<body>
  <div id="controls">
    <label><input type="radio" name="view" id="view-folded" value="folded" checked /> Folded</label>
    <label><input type="radio" name="view" id="view-cp" value="cp" /> Crease pattern</label>
    <label><input type="checkbox" id="sync" checked /> Sync to cursor</label>
    <button id="prev-step" disabled>&laquo; Prev</button>
    <span id="step-label"></span>
    <button id="next-step" disabled>Next &raquo;</button>
    <div id="constructions"></div>
  </div>
  <div id="stage"></div>
  <script nonce="${nonce}">${webviewScript}</script>
</body>
</html>`;
}

export function registerPreview(context: vscode.ExtensionContext): void {
  const showCmd = vscode.commands.registerCommand("beloch.showPreview", () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor || editor.document.languageId !== "beloch") {
      vscode.window.showWarningMessage("Beloch: open a .bel file to preview it.");
      return;
    }
    currentDoc = editor.document;

    if (!panel) {
      panel = vscode.window.createWebviewPanel(
        "belochPreview",
        "Beloch Preview",
        vscode.ViewColumn.Beside,
        { enableScripts: true, retainContextWhenHidden: true },
      );
      panel.webview.html = panelHtml(panel.webview);
      panel.webview.onDidReceiveMessage((message: WebviewToHost) => {
        if (message.type === "state") webviewSync = message.sync;
      });
      panel.onDidDispose(() => {
        panel = undefined;
        currentDoc = undefined;
        currentEdges = [];
        webviewSync = true;
        if (debounceTimer) clearTimeout(debounceTimer);
      });
    } else {
      panel.reveal(vscode.ViewColumn.Beside);
    }

    renderAndPost(currentDoc);
  });

  const selectionListener = vscode.window.onDidChangeTextEditorSelection((e) => {
    if (!panel || !currentDoc || dirty || !webviewSync) return;
    if (e.textEditor.document.uri.toString() !== currentDoc.uri.toString()) return;
    const active = e.selections[0]?.active;
    if (!active) return;
    const step = stepAtLine(currentEdges, active.line + 1); // vscode lines are 0-based
    const cursor: HostToWebviewCursor = { type: "cursor", step };
    panel.webview.postMessage(cursor);
  });

  const changeListener = vscode.workspace.onDidChangeTextDocument((e) => {
    if (!panel || !currentDoc) return;
    if (e.document.uri.toString() !== currentDoc.uri.toString()) return;
    dirty = true;
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      dirty = false;
      if (currentDoc) renderAndPost(currentDoc);
    }, DEBOUNCE_MS);
  });

  context.subscriptions.push(showCmd, selectionListener, changeListener);
}
