/**
 * Webview-side script for the Beloch preview panel.
 *
 * Runs inside the panel's browser context, not Node — this project's
 * `tsconfig.json` `lib` is ES2022-only (the rest of the extension runs in
 * Node), so the DOM globals used here are declared locally as untyped
 * rather than pulling in the full DOM lib project-wide.
 *
 * Pure CSS/DOM over the SVG the host already rendered into the last
 * `render` message — no fold geometry lives here (see the Task 5 brief /
 * CLAUDE.md). `esbuild.mjs` bundles this file to plain browser JS and
 * inlines it into `preview.ts`'s webview HTML (see `webviewScriptPlugin`).
 */
import {
  HostToWebview,
  HostToWebviewCursor,
  HostToWebviewDiagnostic,
  WebviewToHost,
  hiddenStepDataValues,
} from "./preview-model";

declare function acquireVsCodeApi(): { postMessage(message: unknown): void };
declare const document: any;
declare const window: any;

type View = "cp" | "folded";

const vscode = acquireVsCodeApi();

const stageEl = document.getElementById("stage");
const viewFoldedEl = document.getElementById("view-folded");
const viewCpEl = document.getElementById("view-cp");
const syncEl = document.getElementById("sync");
const prevEl = document.getElementById("prev-step");
const nextEl = document.getElementById("next-step");
const stepLabelEl = document.getElementById("step-label");
const constructionsEl = document.getElementById("constructions");

let render: HostToWebview | undefined;
let view: View = "folded";
let sync = true;
let step: string | null = null; // active step when sync is off; follows the host cursor when sync is on
let visibleConstructions = new Set<string>();

function postState(): void {
  const message: WebviewToHost = {
    type: "state",
    view,
    sync,
    step,
    visibleConstructions: [...visibleConstructions],
  };
  vscode.postMessage(message);
}

function populateConstructions(): void {
  if (!render) return;
  visibleConstructions = new Set(render.constructions); // all visible by default
  constructionsEl.innerHTML = render.constructions
    .map(
      (name: string) =>
        `<label><input type="checkbox" class="construction-toggle" value="${name}" checked /> ${name}</label>`,
    )
    .join(" ");
}

function applyState(): void {
  if (!render) return;

  const svg = view === "folded" ? render.foldedSvgByStep[step ?? ""] : render.creasePatternSvg;
  stageEl.innerHTML = svg ?? "";

  if (view === "cp") {
    for (const hidden of hiddenStepDataValues(render.steps, step)) {
      for (const el of stageEl.querySelectorAll(`[data-step="${hidden}"]`)) {
        el.classList.add("hidden-step");
      }
    }
  }

  for (const name of render.constructions) {
    if (!visibleConstructions.has(name)) {
      for (const el of stageEl.querySelectorAll(`[data-construction="${name}"]`)) {
        el.classList.add("hidden-construction");
      }
    }
  }

  for (const el of stageEl.querySelectorAll(`[data-step="${step ?? ""}"]`)) {
    el.classList.add("current-step");
  }

  prevEl.disabled = sync;
  nextEl.disabled = sync;
  stepLabelEl.textContent = step ?? "(baseline)";
}

function setStepByIndex(index: number): void {
  if (!render) return;
  const clamped = Math.max(0, Math.min(render.steps.length - 1, index));
  step = render.steps[clamped];
}

viewFoldedEl.addEventListener("change", () => {
  if (!viewFoldedEl.checked) return;
  view = "folded";
  applyState();
  postState();
});

viewCpEl.addEventListener("change", () => {
  if (!viewCpEl.checked) return;
  view = "cp";
  applyState();
  postState();
});

syncEl.addEventListener("change", () => {
  sync = syncEl.checked;
  applyState();
  postState();
});

prevEl.addEventListener("click", () => {
  if (sync || !render) return;
  setStepByIndex(render.steps.indexOf(step) - 1);
  applyState();
  postState();
});

nextEl.addEventListener("click", () => {
  if (sync || !render) return;
  setStepByIndex(render.steps.indexOf(step) + 1);
  applyState();
  postState();
});

constructionsEl.addEventListener("change", (event: any) => {
  const target = event.target;
  if (!target || !target.classList.contains("construction-toggle")) return;
  if (target.checked) visibleConstructions.add(target.value);
  else visibleConstructions.delete(target.value);
  applyState();
  postState();
});

function escapeHtml(s: string): string {
  const escapes: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;" };
  return s.replace(/[&<>]/g, (c) => escapes[c]);
}

window.addEventListener("message", (event: any) => {
  const message = event.data as HostToWebview | HostToWebviewCursor | HostToWebviewDiagnostic;
  if (message.type === "render") {
    render = message;
    step = null; // the previously active step id may not exist in the new render
    populateConstructions();
    applyState();
  } else if (message.type === "cursor") {
    if (!sync) return;
    step = message.step;
    applyState();
  } else if (message.type === "diagnostic") {
    stageEl.innerHTML = `<pre class="diagnostic">${escapeHtml(message.message)}</pre>`;
  }
});
