# Playground Step Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the live Playground (`packages/www/src/components/Playground.astro`)
step back and forth through a fold's intermediate states, with a CM6 gutter
marker showing which source line produced the currently-shown step.

**Architecture:** All step→line data already exists end-to-end (OCaml
evaluator → FOLD JSON `beloch:source_line` → `@beloch/scene`'s
`Step.sourceLine` → `renderFolded(scene, {step})`) — this is purely front-end
work. A new, isolated CM6 extension module (`cm-step-marker.ts`) owns the
gutter-dot + line-highlight; `Playground.astro` owns the scrubber UI (dots
below the result) and wires clicks to a client-side-only re-render (no worker
round-trip — one eval already returns every step's frame).

**Tech Stack:** Astro component script (TypeScript), CodeMirror 6
(`@codemirror/state`, `@codemirror/view`), `@beloch/scene` /
`@beloch/render-svg`, `bun:test` + `@happy-dom/global-registrator` for the
new module's tests.

## Global Constraints

- No OCaml/evaluator changes — `beloch:step` / `beloch:source_line` /
  `Step.sourceLine` / `renderFolded(scene, {step})` already exist and are
  used as-is (see spec, "Existing data" section).
- No worker round-trip per step change — `renderStep(i)` re-renders the
  already-parsed `Scene` client-side only.
- One-directional only: player → code gutter. No click-in-gutter-to-jump
  (explicitly out of scope per the approved spec).
- Dirty doc clears only the gutter marker, never the scrubber or the
  currently-shown SVG (same philosophy as the existing Run-button behavior:
  a stale-but-still-useful result stays visible).
- Match existing visual language: `var(--beloch-valley)` for "this is
  active/current" (already used for the Run button border and the active
  paper-swatch outline), `var(--beloch-border)`/`var(--beloch-muted)` for
  inactive state.

---

### Task 1: `cm-step-marker.ts` — CM6 gutter dot + line highlight

**Files:**
- Create: `packages/www/src/lib/cm-step-marker.ts`
- Test: `packages/www/src/lib/cm-step-marker.test.ts`

**Interfaces:**
- Produces: `stepMarkerExtensions: Extension[]` (spread into an `EditorState`'s
  `extensions` array — **must be listed before `basicSetup`** so the gutter
  renders to the left of the line-number gutter; verified empirically, see
  Step 5 below), and `setStepLineOn(view: EditorView, line: number | null): void`.

- [ ] **Step 1: Write the module**

```ts
// packages/www/src/lib/cm-step-marker.ts
//
// CM6 extension pair for the Playground's step player: a small gutter dot
// (breakpoint-style) plus a line-background highlight on whichever source
// line produced the currently-shown fold step. Read-only/display-only by
// design — it never moves the text cursor/selection, so it can't interfere
// with editing (see docs/superpowers/specs/2026-07-19-playground-step-navigation-design.md).
import {
  Decoration, EditorView, gutter, GutterMarker,
} from "@codemirror/view";
import type { DecorationSet } from "@codemirror/view";
import { StateEffect, StateField } from "@codemirror/state";
import type { EditorState } from "@codemirror/state";

export const setStepLine = StateEffect.define<number | null>();

interface StepLineValue { line: number | null; deco: DecorationSet }

function decorationsFor(state: EditorState, line: number | null): DecorationSet {
  if (line == null || line < 1 || line > state.doc.lines) return Decoration.none;
  const { from } = state.doc.line(line);
  return Decoration.set([
    Decoration.line({ attributes: { class: "cm-step-line" } }).range(from),
  ]);
}

const stepLineField = StateField.define<StepLineValue>({
  create: () => ({ line: null, deco: Decoration.none }),
  update(value, tr) {
    let line = value.line;
    for (const e of tr.effects) if (e.is(setStepLine)) line = e.value;
    if (line === value.line && !tr.docChanged) return value;
    return { line, deco: decorationsFor(tr.state, line) };
  },
  provide: (f) => EditorView.decorations.from(f, (v) => v.deco),
});

class StepDotMarker extends GutterMarker {
  toDOM() {
    const dot = document.createElement("span");
    dot.className = "cm-step-dot";
    return dot;
  }
}
const stepDotMarker = new StepDotMarker();

const stepGutterExtension = gutter({
  class: "cm-step-gutter",
  lineMarker(view, line) {
    const { line: current } = view.state.field(stepLineField);
    if (current == null) return null;
    return view.state.doc.lineAt(line.from).number === current ? stepDotMarker : null;
  },
  lineMarkerChange: (update) =>
    update.startState.field(stepLineField).line !== update.state.field(stepLineField).line,
});

export const stepMarkerExtensions = [stepLineField, stepGutterExtension];

/** Show (or, with `line: null`, clear) the step-line gutter dot + highlight,
 * and scroll it into view. Never touches the selection/cursor. */
export function setStepLineOn(view: EditorView, line: number | null) {
  view.dispatch({ effects: setStepLine.of(line) });
  if (line != null && line >= 1 && line <= view.state.doc.lines) {
    const pos = view.state.doc.line(line).from;
    view.dispatch({ effects: EditorView.scrollIntoView(pos, { y: "center" }) });
  }
}
```

- [ ] **Step 2: Write the test**

```ts
// packages/www/src/lib/cm-step-marker.test.ts
import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { EditorState } from "@codemirror/state";
import { EditorView, basicSetup } from "codemirror";
import { stepMarkerExtensions, setStepLineOn } from "./cm-step-marker";

beforeAll(() => { GlobalRegistrator.register(); });

function mountEditor(doc: string): EditorView {
  const state = EditorState.create({ doc, extensions: stepMarkerExtensions });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  return new EditorView({ state, parent });
}

test("setStepLineOn adds a gutter dot marker on the target line", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 2);
  const dot = view.dom.querySelector(".cm-step-gutter .cm-step-dot");
  expect(dot).not.toBeNull();
});

test("setStepLineOn(null) clears the marker", () => {
  const view = mountEditor("paper square\nfold X\n");
  setStepLineOn(view, 2);
  setStepLineOn(view, null);
  expect(view.dom.querySelector(".cm-step-gutter .cm-step-dot")).toBeNull();
});

test("setStepLineOn adds a line-background decoration on the target line", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 3);
  expect(view.dom.querySelector(".cm-step-line")).not.toBeNull();
});

test("moving to a different line clears the previous marker", () => {
  const view = mountEditor("paper square\nfold X\nfold Y\n");
  setStepLineOn(view, 2);
  setStepLineOn(view, 3);
  const dots = view.dom.querySelectorAll(".cm-step-gutter .cm-step-dot");
  expect(dots.length).toBe(1);
  const lines = view.dom.querySelectorAll(".cm-step-line");
  expect(lines.length).toBe(1);
});

test("gutter is registered before (left of) the default line-number gutter", () => {
  const state = EditorState.create({
    doc: "a\nb\nc\n",
    extensions: [...stepMarkerExtensions, basicSetup],
  });
  const parent = document.createElement("div");
  document.body.appendChild(parent);
  const view = new EditorView({ state, parent });
  const classes = Array.from(view.dom.querySelectorAll(".cm-gutters > *")).map((el) => el.className);
  const stepIdx = classes.findIndex((c) => c.includes("cm-step-gutter"));
  const lineNumIdx = classes.findIndex((c) => c.includes("cm-lineNumbers"));
  expect(stepIdx).toBeGreaterThanOrEqual(0);
  expect(lineNumIdx).toBeGreaterThan(stepIdx);
});
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `cd packages/www && bun test src/lib/cm-step-marker.test.ts`
Expected: `5 pass`, `0 fail` (this module was prototyped and verified
end-to-end against this exact test suite during design — it should pass on
the first run; if it doesn't, do not proceed to Task 2 until it does).

- [ ] **Step 4: Commit**

```bash
git add packages/www/src/lib/cm-step-marker.ts packages/www/src/lib/cm-step-marker.test.ts
git commit -m "feat(playground): CM6 step-line gutter marker module"
```

---

### Task 2: Wire the step-line extension into the Playground editor

**Files:**
- Modify: `packages/www/src/components/Playground.astro`

**Interfaces:**
- Consumes: `stepMarkerExtensions` and `setStepLineOn` from Task 1
  (`../lib/cm-step-marker`).
- Produces: nothing new for later tasks yet — this task only mounts the
  extension so the gutter exists in the live editor (still inert: nothing
  calls `setStepLineOn` with a real line yet, that's Task 3).

- [ ] **Step 1: Add the import**

In `packages/www/src/components/Playground.astro`, in the `<script>` block,
add this import alongside the existing CM6 imports (after the `keymap`
import, before the `@beloch/scene` import):

```ts
import { stepMarkerExtensions, setStepLineOn } from "../lib/cm-step-marker";
```

- [ ] **Step 2: Register the extension before `basicSetup`**

Find the `EditorState.create` call inside `setup()`:

```ts
    const editor = new EditorView({
      state: EditorState.create({
        doc: initialCode,
        extensions: [
          basicSetup,
          keymap.of([
```

Change the `extensions` array so `stepMarkerExtensions` comes **first**
(before `basicSetup` — this is required for the gutter to render to the left
of the line-number gutter, verified in Task 1's last test):

```ts
    const editor = new EditorView({
      state: EditorState.create({
        doc: initialCode,
        extensions: [
          ...stepMarkerExtensions,
          basicSetup,
          keymap.of([
```

(Leave the rest of the array — `keymap.of([...])`, `editorTheme`, the
existing `EditorView.updateListener.of(...)` — unchanged.)

- [ ] **Step 3: Verify it mounts without breaking anything**

Run: `cd packages/www && bun run dev` (or use the `run` skill), open the
Playground in a browser, confirm:
- The editor still loads and is editable (no console errors).
- A new, narrow empty gutter column appears to the left of the line numbers
  (empty because nothing calls `setStepLineOn` yet — that's expected).

- [ ] **Step 4: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "feat(playground): mount the step-line gutter extension"
```

---

### Task 3: Scrubber UI + client-side step rendering

**Files:**
- Modify: `packages/www/src/components/Playground.astro`

**Interfaces:**
- Consumes: `setStepLineOn` (Task 1/2), `parseFold`/`FoldScene` (`@beloch/scene`,
  already imported), `renderFolded`/`renderCP`/`WEB_THEME` (`@beloch/render-svg`,
  already imported), `editor` (the `EditorView`, already in scope in `setup()`).
- Produces: `renderStep(i: number): void`, `currentScene: FoldScene | null`
  (module-local to each `setup()` closure) — later tasks don't need these
  directly, but Task 4 relies on `setStepLineOn` already being wired here.

- [ ] **Step 1: Add the scrubber markup**

In the template section, find:

```astro
    <div class="pg-result">
      {seed ? <Fragment set:html={seed} /> : <p class="pg-notice pg-notice-info">„Run“ drücken, um auszuwerten.</p>}
    </div>
  </div>
```

Add a new `.pg-steps` bar right after `.pg-result`, still inside the
`.pg-output` pane:

```astro
    <div class="pg-result">
      {seed ? <Fragment set:html={seed} /> : <p class="pg-notice pg-notice-info">„Run“ drücken, um auszuwerten.</p>}
    </div>
    <div class="pg-steps" hidden>
      <div class="pg-step-dots"></div>
      <span class="pg-step-label"></span>
    </div>
  </div>
```

- [ ] **Step 2: Add the scrubber CSS**

In the `<style>` block, add these rules after the existing `.pg-swatch.is-active`
rule (end of the block, before `</style>`):

```css
  .pg-steps {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 16px;
    border-top: 1px solid var(--beloch-border);
    font-family: 'IBM Plex Mono', ui-monospace, monospace;
    font-size: 11px;
    color: var(--beloch-muted);
  }
  .pg-steps[hidden] { display: none; }
  .pg-step-dots { display: inline-flex; gap: 6px; }
  .pg-step-dot {
    width: 10px;
    height: 10px;
    padding: 0;
    border-radius: 50%;
    border: 1px solid var(--beloch-border);
    background: transparent;
    cursor: pointer;
  }
  .pg-step-dot.is-active {
    background: var(--beloch-valley);
    border-color: var(--beloch-valley);
  }
  .pg-step-label {
    white-space: nowrap;
  }
```

Also add the CM6 gutter-dot and line-highlight styling, next to the existing
`.pg-source :global(.cm-scroller)` rule:

```css
  .pg-source :global(.cm-step-gutter) {
    width: 14px;
  }
  .pg-source :global(.cm-step-dot) {
    display: block;
    width: 8px;
    height: 8px;
    margin: 6px auto 0;
    border-radius: 50%;
    background: var(--beloch-valley);
  }
  .pg-source :global(.cm-step-line) {
    background: color-mix(in srgb, var(--beloch-valley) 15%, transparent);
  }
```

- [ ] **Step 3: Query the new DOM elements and extend the required-element guard**

In `setup()`, find:

```ts
    const sourceMount = root.querySelector<HTMLDivElement>(".pg-source");
    const runBtn = root.querySelector<HTMLButtonElement>(".pg-run");
    const result = root.querySelector<HTMLDivElement>(".pg-result");
    const runHint = root.querySelector<HTMLDivElement>(".pg-run-hint");
    if (!sourceMount || !runBtn || !result || !runHint) return;
```

Replace with:

```ts
    const sourceMount = root.querySelector<HTMLDivElement>(".pg-source");
    const runBtn = root.querySelector<HTMLButtonElement>(".pg-run");
    const result = root.querySelector<HTMLDivElement>(".pg-result");
    const runHint = root.querySelector<HTMLDivElement>(".pg-run-hint");
    const stepsBar = root.querySelector<HTMLDivElement>(".pg-steps");
    const stepDots = root.querySelector<HTMLDivElement>(".pg-step-dots");
    const stepLabel = root.querySelector<HTMLSpanElement>(".pg-step-label");
    if (!sourceMount || !runBtn || !result || !runHint || !stepsBar || !stepDots || !stepLabel) return;
```

- [ ] **Step 4: Switch the `@beloch/scene` import to also bring in the `FoldScene` type**

Find:

```ts
  import { parseFold } from "@beloch/scene";
```

Replace with:

```ts
  import { parseFold, type FoldScene } from "@beloch/scene";
```

- [ ] **Step 5: Add step state + the scrubber/render functions**

Find:

```ts
    let worker: Worker | null = null;
    let timer: ReturnType<typeof setTimeout> | null = null;

    const showInfo = (message: string) => {
      result.innerHTML = `<p class="pg-notice pg-notice-info">${escapeHtml(message)}</p>`;
    };
    const showError = (message: string) => {
      result.innerHTML = `<p class="pg-notice pg-notice-error">${escapeHtml(message)}</p>`;
    };
    const showSvg = (svg: string) => {
      result.innerHTML = svg;
    };
```

Add the new state and functions right after `showSvg`'s definition (still
before `function finish(...)`):

```ts
    let worker: Worker | null = null;
    let timer: ReturnType<typeof setTimeout> | null = null;
    let currentScene: FoldScene | null = null;

    const showInfo = (message: string) => {
      result.innerHTML = `<p class="pg-notice pg-notice-info">${escapeHtml(message)}</p>`;
    };
    const showError = (message: string) => {
      result.innerHTML = `<p class="pg-notice pg-notice-error">${escapeHtml(message)}</p>`;
    };
    const showSvg = (svg: string) => {
      result.innerHTML = svg;
    };

    // Rebuilds the scrubber's dots for a freshly-parsed scene (called once
    // per successful run, not per step-click). Hides the bar entirely when
    // there's nothing to navigate (0 or 1 steps).
    function buildStepsUI(scene: FoldScene) {
      const n = scene.steps.length;
      stepDots!.innerHTML = "";
      if (n <= 1) {
        stepsBar!.hidden = true;
        return;
      }
      stepsBar!.hidden = false;
      for (let i = 0; i < n; i++) {
        const dot = document.createElement("button");
        dot.type = "button";
        dot.className = "pg-step-dot";
        dot.setAttribute("aria-label", `Step ${i + 1} von ${n}`);
        dot.addEventListener("click", () => renderStep(i));
        stepDots!.appendChild(dot);
      }
    }

    // Cheap per-step-change update: toggles the active dot + label text,
    // without touching event listeners (buildStepsUI owns those).
    function updateStepsUI(i: number, scene: FoldScene) {
      stepDots!.querySelectorAll<HTMLButtonElement>(".pg-step-dot").forEach((dot, idx) => {
        dot.classList.toggle("is-active", idx === i);
      });
      const step = scene.steps[i];
      stepLabel!.textContent = step?.label
        ? `Step ${i + 1}/${scene.steps.length} · ${step.label}`
        : `Step ${i + 1}/${scene.steps.length}`;
    }

    // Client-side-only re-render of one step of the already-parsed scene —
    // no worker round-trip, since one eval already returned every frame.
    function renderStep(i: number) {
      if (!currentScene) return;
      const n = currentScene.steps.length;
      const clamped = Math.max(0, Math.min(i, n - 1));
      const step = currentScene.steps[clamped]!;
      try {
        showSvg(renderFolded(currentScene, { theme: WEB_THEME, step: String(clamped) }).toString());
      } catch (err) {
        showError(`Render-Fehler: ${err instanceof Error ? err.message : String(err)}`);
        return;
      }
      setStepLineOn(editor, step.sourceLine);
      updateStepsUI(clamped, currentScene);
    }
```

- [ ] **Step 6: Rewire `renderResult` to use the scrubber**

Find:

```ts
      if (parsed.ok) {
        try {
          const scene = parseFold(parsed.fold as object);
          const doc = scene.steps.length > 0
            ? renderFolded(scene, { theme: WEB_THEME })
            : renderCP(scene, { theme: WEB_THEME });
          showSvg(doc.toString());
        } catch (err) {
          showError(`Render-Fehler: ${err instanceof Error ? err.message : String(err)}`);
        }
        return;
      }
```

Replace with:

```ts
      if (parsed.ok) {
        try {
          const scene = parseFold(parsed.fold as object);
          if (scene.steps.length > 0) {
            currentScene = scene;
            buildStepsUI(scene);
            renderStep(scene.steps.length - 1);
          } else {
            currentScene = null;
            stepsBar!.hidden = true;
            setStepLineOn(editor, null);
            showSvg(renderCP(scene, { theme: WEB_THEME }).toString());
          }
        } catch (err) {
          showError(`Render-Fehler: ${err instanceof Error ? err.message : String(err)}`);
        }
        return;
      }
```

- [ ] **Step 7: Verify manually**

Run: `cd packages/www && bun run dev` (or use the `run` skill). Open the
Playground, paste in a multi-step example (e.g. the `FISH_BASE_SRC` constant
from `packages/www/src/pages/index.astro`, which has two `step` blocks), and
click Run. Confirm:
- A row of dots + a `Step N/M` label appears under the result.
- Clicking each dot re-renders the SVG to that step, and the gutter shows a
  dot + highlighted line at the source line for that step (no dot for the
  first, flat-sheet step — it has no source line).
- Clicking dots does **not** trigger a new "lädt Playground-Runtime …" /
  "berechnet Geometrie …" hint or worker call (open devtools → Network,
  confirm no new requests) — it's instant, client-side only.
- Run a mark-only source with no `fold`/`flatten` statement at all, e.g.
  `paper square\nmark --diag = through .a .c` — this produces
  `scene.steps.length === 0` (no folded frames), so the scrubber must stay
  hidden and the crease-pattern render path (`renderCP`) is used, same as
  before this change.
- Run the `HERO_SRC` constant from `packages/www/src/pages/index.astro`
  (one `flatten` statement) — this produces exactly 2 steps (the flat sheet,
  then the flatten result), so the scrubber must show with exactly 2 dots.

- [ ] **Step 8: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "feat(playground): step scrubber + client-side step rendering"
```

---

### Task 4: Clear the gutter marker when the code goes dirty

**Files:**
- Modify: `packages/www/src/components/Playground.astro`

**Interfaces:**
- Consumes: `setStepLineOn` (Task 1/2), `editor` and `updateRunButtonState`
  (already in scope from the existing dirty-tracking code).

- [ ] **Step 1: Clear the marker inside `updateRunButtonState`**

Find:

```ts
    function updateRunButtonState() {
      const dirty = editor.state.doc.toString() !== lastRunCode;
      runBtn.disabled = running || !dirty;
      runBtn.title = running
        ? "wertet aus …"
        : dirty
          ? "Run"
          : "Code ändern, um erneut auszuführen";
    }
```

Replace with:

```ts
    function updateRunButtonState() {
      const dirty = editor.state.doc.toString() !== lastRunCode;
      runBtn.disabled = running || !dirty;
      runBtn.title = running
        ? "wertet aus …"
        : dirty
          ? "Run"
          : "Code ändern, um erneut auszuführen";
      // Line numbers from the last run no longer necessarily match the
      // edited text — clear the gutter indicator, but leave the scrubber
      // and the currently-shown SVG alone (same "stale result stays
      // visible" philosophy as the Run button itself).
      if (dirty) setStepLineOn(editor, null);
    }
```

- [ ] **Step 2: Verify manually**

Run: `cd packages/www && bun run dev` (or use the `run` skill). Run a
multi-step example, click a step dot so the gutter marker is visible, then
type a character anywhere in the editor. Confirm:
- The gutter dot and line highlight disappear immediately.
- The SVG in `.pg-result` and the step dots/label are unchanged (not
  cleared) — you can still click other step dots and they still re-render
  correctly.
- Deleting the typed character back to the exact last-run text does **not**
  need to bring the marker back (out of scope — dirty-clearing is one-way
  until the next Run; this matches the existing Run-button dirty check,
  which only compares current text to `lastRunCode`, not to a history of
  visited states).

- [ ] **Step 3: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "fix(playground): clear step-line gutter marker when code goes dirty"
```
