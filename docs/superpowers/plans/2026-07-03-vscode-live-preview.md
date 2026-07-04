# VSCode Live Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A cursor-synced preview webview showing the Beloch folded state / crease pattern at the current `step`, driven by a new multi-frame FOLD (one folded frame per step) and a class-tagged `fold2svg` render.

**Architecture:** Phase 1 (OCaml) makes the evaluator snapshot its folded state at each `step` boundary and `fold_emit` emit one self-contained `foldedForm` frame per snapshot, step-tagged. Phase 2 (TS) adds semantic `data-*` hooks to `fold2svg`, then a webview whose host renders SVG via `resolveBeloch()` + `fold2svg` and whose controls (CP/folded, sync on/off, step scrub, construction overlay, step highlight) act purely by CSS/DOM over that SVG.

**Tech Stack:** OCaml (dune, `lib/eval.ml`, `lib/fold_emit.ml`), `tools/fold2svg.mjs` (bun + rabbit-ear), TypeScript + bun (`editors/vscode`), `vscode` webview API.

## Global Constraints

- Folded frames are exact (`Num`), serialized to float only at the FOLD boundary (as `fold_emit` does today). Floats never enter the exact artifact.
- One `foldedForm` frame per `step` panel, tagged with the step id (the same id carried in `beloch:edges[].step`); plus a frame-0 baseline (step = `null`) for the pre-first-`step` state.
- No animation, no per-face isometries, no per-vertex paper-coord correspondence in this slice — deferred to the 3D-viewer slice.
- `fold2svg` is a temporary tool; its additions are confined to it.
- Webview holds NO fold geometry; the host renders, the webview styles by CSS/DOM. Host re-render only on document change — not on toggles/step/cursor.
- `editors/vscode/package.json` edits are additive only (deps + scripts); `contributes` blocks are frozen (the `beloch.showPreview` command already exists).
- Phase 1 commits on the OCaml side; Phase 2 on the TS side. All commits on branch `vscode-preview`.

---

## Phase 1 — multi-frame FOLD (closes #42 stages 1–2)

### Task 1: Evaluator snapshots folded state per step

**Files:**
- Modify: `lib/eval.ml` (the `folded` record ~13-16; the `ctx` record ~49-51; `eval_folded` ~91-102; `StepMark` handling ~545-549; the return `{ state = !(ctx.state); ... }` ~567). Line numbers per current `main` (post-#28); the structure is unchanged from when this plan was written — verify by reading around those anchors.
- Test: `tests/test_eval.ml` (add a step-frames test)

**Interfaces:**
- Produces: `Eval.folded` gains `frames : (string option * Fold_state.t) list` — ordered snapshots, one per step boundary plus a trailing final snapshot; the last element's state equals the existing `state` field. `List.map fst frames` is the ordered step ids (`None` for the pre-first-step baseline).

- [ ] **Step 1: Write the failing test**

In `tests/test_eval.ml`, add:

```ocaml
let test_step_frames () =
  let src =
    "paper square\n\
     step a\n\
     --v = map .a onto .b\n\
     step b\n\
     map .d onto .c\n"
  in
  let prog = Beloch.parse_string ~filename:"t" src in
  let fd = Beloch.Eval.eval_folded prog in
  let tags = List.map fst fd.Beloch.Eval.frames in
  (* baseline (None) + step a + step b *)
  Alcotest.(check (list (option string))) "step tags"
    [ None; Some "a"; Some "b" ] tags;
  (* last frame state is the final state *)
  Alcotest.(check bool) "last frame is final" true
    (snd (List.nth fd.frames (List.length fd.frames - 1)) == fd.state)
```

Register it in the test list for this file (follow the existing `( "name", `Quick, test_fn )` pattern already in `tests/test_eval.ml`).

- [ ] **Step 2: Run to verify it fails**

Run: `dune runtest 2>&1 | head -30`
Expected: compile error — `frames` field does not exist on `Eval.folded`.

- [ ] **Step 3: Add the `frames` field and snapshotting**

In `lib/eval.ml`, extend the `folded` record:

```ocaml
type folded = {
  state : Fold_state.t;
  named_points : (string * Geom.point) list;
  named_lines : (string * Geom.line) list;
  frames : (string option * Fold_state.t) list;
}
```

Add a mutable accumulator to the `ctx` record (alongside `mutable panel`):

```ocaml
  mutable frames_rev : (string option * Fold_state.t) list;
```

Initialize it in `eval_folded`'s `ctx = { ... }` with `frames_rev = [];`.

In the `Ast.StepMark (id, span)` case, snapshot the ending panel's state BEFORE switching panel (insert before `ctx.panel <- Some id`):

```ocaml
        ctx.frames_rev <- (ctx.panel, !(ctx.state)) :: ctx.frames_rev;
```

After `List.iter eval_stmt prog;`, push the final snapshot and build the ordered list:

```ocaml
  ctx.frames_rev <- (ctx.panel, !(ctx.state)) :: ctx.frames_rev;
  let frames = List.rev ctx.frames_rev in
```

Add `frames` to the returned record literal (alongside `state`, `named_points`, `named_lines`).

- [ ] **Step 4: Run to verify it passes**

Run: `dune runtest 2>&1 | tail -20`
Expected: all tests pass, including `step tags` and `last frame is final`.

- [ ] **Step 5: Commit**

```bash
git add lib/eval.ml tests/test_eval.ml
git commit -m "feat(eval): snapshot folded state per step for multi-frame output (#42)"
```

---

### Task 2: fold_emit emits one folded frame per step

**Files:**
- Modify: `lib/fold_emit.ml` (extract the folded-frame builder; emit `file_frames` per snapshot)
- Modify: `spec/SPECIFICATION.md` (§7 FOLD mapping — document the multi-frame layout)
- Test: `tests/test_fold.ml` or the existing FOLD test module (add a multi-frame assertion)

**Interfaces:**
- Consumes: `Eval.folded.frames` from Task 1.
- Produces: FOLD JSON whose top-level crease-pattern is unchanged (built from the final state) and whose `file_frames` is one `foldedForm` frame per snapshot, each self-contained (`frame_inherit: false`, its own `vertices_coords`/`edges_vertices`/`edges_assignment`/`faces_vertices`/`faceOrders`) and tagged `"beloch:step"` = the step id (or `null` for the baseline).

- [ ] **Step 1: Write the failing test**

Add to the FOLD test module (mirror the file's existing helper for turning source into JSON — e.g. `Beloch.fold_string`):

```ocaml
let test_multiframe () =
  let src =
    "paper square\n\
     step a\n\
     --v = map .a onto .b\n\
     step b\n\
     map .d onto .c\n"
  in
  let json = Beloch.fold_string ~filename:"t" src in
  let frames =
    match json with
    | `Assoc kv -> (match List.assoc "file_frames" kv with `List l -> l | _ -> [])
    | _ -> []
  in
  Alcotest.(check int) "one folded frame per step (baseline+a+b)" 3
    (List.length frames);
  let step_of = function
    | `Assoc kv -> (match List.assoc "beloch:step" kv with `String s -> Some s | _ -> None)
    | _ -> None
  in
  Alcotest.(check (list (option string))) "frame step tags"
    [ None; Some "a"; Some "b" ] (List.map step_of frames)
```

- [ ] **Step 2: Run to verify it fails**

Run: `dune runtest 2>&1 | tail -20`
Expected: FAIL — `file_frames` currently has length 1 and frames carry no `beloch:step`.

- [ ] **Step 3: Extract a per-state folded-frame builder**

In `lib/fold_emit.ml`, the current `to_json_folded` computes a single vertex dedup (`vpaper`/`vtable`), edges, `face_idx`, `face_orders`, and one `folded_frame`. Refactor so the folded-frame computation is a function of a single `Fold_state.t`:

```ocaml
(* Build one self-contained foldedForm frame for a given state. Its topology is
   this state's faces (earlier steps have fewer faces than the final CP, so the
   frame cannot inherit the parent's vertex/face set — frame_inherit is false). *)
let folded_frame_of_state (state : Fold_state.t) (step : string option) : Yojson.Safe.t =
  let faces = state.Fold_state.faces in
  (* --- move here the existing vertex dedup (vpaper/vtable/vindex/face_idx),
         the table-coords list (verts_table), the edges (edges_vertices +
         edges_assignment + edges_fold_angle), the faces_vertices, and the
         faceOrders loop — all computed from `faces`/`state.order` exactly as
         the current single-frame code does, but parameterized on `state`. --- *)
  `Assoc
    [
      ("frame_classes", `List [ `String "foldedForm" ]);
      ("frame_parent", `Int 0);
      ("frame_inherit", `Bool false);
      ("vertices_coords", `List verts_table);
      ("edges_vertices", `List edges_vertices);
      ("edges_assignment", `List edges_assignment);
      ("edges_foldAngle", `List edges_fold_angle);
      ("faces_vertices", `List faces_vertices);
      ("faceOrders", `List face_orders);
      ("beloch:step", (match step with Some s -> `String s | None -> `Null));
    ]
```

Move the existing per-face/per-edge/per-order computation bodies into this function (they already read only `faces` and `state.order`). The top-level crease-pattern section (paper `vertices_coords`, `edges_vertices`, `edges_assignment`, `faces_vertices`, `beloch:edges` provenance, `beloch:named_points/lines`) stays as-is, computed from the FINAL state (`fd.state`).

- [ ] **Step 4: Emit one frame per snapshot**

Replace the single `("file_frames", `List [ folded_frame ])` with a map over `fd.frames`:

```ocaml
      ( "file_frames",
        `List (List.map (fun (step, st) -> folded_frame_of_state st step) fd.Eval.frames) );
```

Remove the now-dead inline `folded_frame` binding (the single-frame one) — Task-created orphan cleanup.

- [ ] **Step 5: Run to verify it passes**

Run: `dune runtest 2>&1 | tail -20`
Expected: PASS — `file_frames` length 3, step tags `[None; Some "a"; Some "b"]`. Confirm the rest of the FOLD test suite is still green (the single-frame goldens: a one-step-or-fewer program still yields exactly one frame).

- [ ] **Step 6: Document the layout in the spec**

In `spec/SPECIFICATION.md` §7 (the FOLD mapping section), add a short paragraph: `file_frames` contains one `foldedForm` frame per `step` panel (plus a `beloch:step: null` baseline frame for the pre-first-step state); each is self-contained (`frame_inherit: false`) with its own topology; the top-level frame is the final cumulative crease pattern, and `beloch:edges[].step` lets a consumer map creases to frames.

- [ ] **Step 7: Commit**

```bash
git add lib/fold_emit.ml spec/SPECIFICATION.md tests/
git commit -m "feat(fold): emit one folded frame per step, step-tagged (#42)"
```

---

## Phase 2 — renderer hooks + webview

### Task 3: fold2svg emits semantic hooks + a step selector

**Files:**
- Modify: `tools/fold2svg.mjs` (add `data-step`/assignment class per crease; `class="construction" data-construction="<name>"` per named overlay; a `--step <id>` selector choosing which `file_frames` entry to render for the folded view)
- Test: `tools/test/` (assert the hooks appear; follow the existing test harness there)

**Interfaces:**
- Consumes: the multi-frame FOLD from Task 2 (`file_frames[].beloch:step`, `beloch:edges[].step`, `beloch:named_points`/`named_lines`).
- Produces: SVG where each crease element carries `data-step="<id>"` (from its `beloch:edges` provenance; `""` if none) and a `crease-M`/`crease-V`/`crease-U` class; each named-construction element carries `class="construction"` + `data-construction="<name>"`. `fold2svg f.fold --view top --step <id>` renders the folded frame whose `beloch:step` equals `<id>` (default: the last frame).

- [ ] **Step 1: Write the failing test**

In `tools/test/` add a test (match the directory's existing test style — it uses the exported pure helpers and/or runs the CLI). Assert on the produced SVG string:

```js
import { test, expect } from "bun:test";
import { execSync } from "node:child_process";

test("fold2svg tags creases with data-step and constructions", () => {
  const svg = execSync(
    "beloch fold examples/x-midpoint.bel | bun tools/fold2svg.mjs - -",
    { cwd: "..", encoding: "utf8" },
  );
  expect(svg).toContain("data-step=");
  expect(svg).toContain('class="construction"');
  expect(svg).toContain("data-construction=");
});
```

(If the harness prefers rendering a fixture `.fold` file over piping `beloch`, use that; the assertions on the SVG string are the point.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd tools && bun test 2>&1 | tail -20`
Expected: FAIL — the current SVG has no `data-step`/`construction` attributes.

- [ ] **Step 3: Add the hooks and `--step`**

In `tools/fold2svg.mjs`:
- Where crease edges are drawn (the loop over edges using `A`/assignment and `prov = frame["beloch:edges"]`), add to each crease element `class="crease-${assignment}"` and `data-step="${(prov[i] && prov[i].step) || ""}"`.
- Where named constructions are overlaid (the `beloch:named_points`/`beloch:named_lines` drawing), add `class="construction"` and `data-construction="${name}"` to each element.
- Parse a `--step <id>` CLI flag; when rendering the folded view (`--view`), select the `file_frames` entry whose `beloch:step === id` (fall back to the last frame if `--step` is omitted or unmatched). Update the exported `foldedFrame(fold)` helper to accept an optional step id: `foldedFrame(fold, step)` returning the matching frame merged over its parent (keep the no-arg behavior = last frame for existing callers).

- [ ] **Step 4: Run to verify it passes**

Run: `cd tools && bun test 2>&1 | tail -20`
Expected: PASS. Also spot-check `bun tools/fold2svg.mjs some.fold --view top --step a -` renders the step-`a` frame.

- [ ] **Step 5: Commit**

```bash
git add tools/fold2svg.mjs tools/test/
git commit -m "feat(fold2svg): data-step/construction hooks + --step frame selector"
```

---

### Task 4: Preview host — render pipeline + cursor→step mapping

**Files:**
- Modify: `editors/vscode/src/preview.ts` (replace the stub: on show, evaluate + render, wire cursor/selection listeners, post messages)
- Create: `editors/vscode/src/preview-model.ts` (pure, testable: cursor-line→step from `beloch:edges` spans; message types)
- Create: `editors/vscode/src/preview-model.test.ts`
- Modify: `editors/vscode/package.json` (additive: a `test` already runs bun; no new dep needed if using the FOLD JSON directly)

**Interfaces:**
- Consumes: `resolveBeloch()` from `./beloch`; the multi-frame FOLD (Task 2) and hooked SVG (Task 3).
- Produces:
  - `preview-model.ts`: `stepAtLine(edges: {span: string; step: string | null}[], line: number): string | null` — the step id whose `beloch:edges` spans cover a 1-based `line` (nearest-preceding step; `null` before the first step). `parseSpanLine(span: string): {startLine: number; endLine: number}` for `beloch:edges[].span` strings (format `Error.span_to_string`, e.g. `t:2:5-2:9` → lines).
  - message types `HostToWebview` / `WebviewToHost` (see Task 5).

- [ ] **Step 1: Write the failing test**

Create `editors/vscode/src/preview-model.test.ts`:

```ts
import { test, expect } from "bun:test";
import { stepAtLine } from "./preview-model";

const edges = [
  { span: "t:3:1-3:20", step: "a" },
  { span: "t:5:1-5:12", step: "b" },
];

test("line inside step a maps to a", () => {
  expect(stepAtLine(edges, 3)).toBe("a");
});
test("line inside step b maps to b", () => {
  expect(stepAtLine(edges, 5)).toBe("b");
});
test("line before any step is null", () => {
  expect(stepAtLine(edges, 1)).toBeNull();
});
test("line after last step's start stays on the nearest preceding step", () => {
  expect(stepAtLine(edges, 6)).toBe("b");
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd editors/vscode && bun test src/preview-model.test.ts`
Expected: FAIL — `./preview-model` / `stepAtLine` not found.

- [ ] **Step 3: Implement `preview-model.ts`**

```ts
export interface EdgeProv { span: string; step: string | null }

export interface HostToWebview {
  type: "render";
  creasePatternSvg: string;
  foldedSvgByStep: Record<string, string>; // step id ("" = baseline) -> folded SVG
  steps: (string | null)[];                // ordered step ids incl. null baseline
  constructions: string[];                 // named construction names
}
export interface WebviewToHost {
  type: "state";
  view: "cp" | "folded";
  sync: boolean;
  step: string | null;                     // active step when sync is off
  visibleConstructions: string[];
}

/** Parse an `Error.span_to_string` value like "t:3:1-3:20" into 1-based lines. */
export function parseSpanLine(span: string): { startLine: number; endLine: number } {
  // "<file>:<sl>:<sc>-<el>:<ec>"; file may contain ':' on Windows-ish paths, so
  // parse from the right.
  const m = span.match(/:(\d+):(\d+)-(\d+):(\d+)$/);
  if (!m) return { startLine: 0, endLine: 0 };
  return { startLine: Number(m[1]), endLine: Number(m[3]) };
}

/** The step id whose creases cover `line` (1-based); the nearest preceding step,
 *  or null before the first step. */
export function stepAtLine(edges: EdgeProv[], line: number): string | null {
  let best: string | null = null;
  let bestLine = -1;
  for (const e of edges) {
    if (e.step == null) continue;
    const { startLine } = parseSpanLine(e.span);
    if (startLine <= line && startLine > bestLine) {
      bestLine = startLine;
      best = e.step;
    }
  }
  return best;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd editors/vscode && bun test src/preview-model.test.ts`
Expected: PASS (4/4).

- [ ] **Step 5: Wire the host in `preview.ts`**

Replace the stub `registerPreview` body so the command:
1. Reads the active `.bel` document text.
2. Runs `resolveBeloch()` argv + `fold` on the document (spawn with `cwd` = the workspace folder — per the foundation contract) to get FOLD JSON; on error, post the diagnostic to the webview instead.
3. Runs `fold2svg` for the crease-pattern SVG and, per `file_frames` step, the folded SVG (`--view top --step <id>`), collecting `foldedSvgByStep`.
4. Posts a `HostToWebview` render message.
5. On `window.onDidChangeTextEditorSelection` for a `beloch` document, computes `stepAtLine(edges, cursorLine)` and posts it (the webview decides whether to honor it based on its sync toggle — but only send when the doc is unchanged; re-run steps 1–4 on `workspace.onDidChangeTextDocument`, debounced ~300ms).

Show the exact spawn helper (uses `resolveBeloch()`):

```ts
import { execFileSync } from "node:child_process";
import * as vscode from "vscode";
import { resolveBeloch } from "./beloch";

function run(argvTail: string[], input: string, cwd: string): string {
  const argv = resolveBeloch();
  return execFileSync(argv[0], [...argv.slice(1), ...argvTail], {
    input, cwd, encoding: "utf8", maxBuffer: 64 * 1024 * 1024,
  });
}
```

(Rendering detail — `beloch fold` reads a file path, so write the document text to a temp file in the workspace or pass via stdin if supported; `fold2svg` accepts `-` stdin. Keep it simple: write the doc to an OS temp file, `beloch fold tmp.bel`, pipe to `fold2svg - -`. The `cwd` for the dev `dune exec` fallback must be the workspace folder.)

- [ ] **Step 6: Build + verify**

Run: `cd editors/vscode && bunx tsc --noEmit && bun run compile`
Expected: 0 type errors; bundle builds. (Full extension-host behavior is a manual smoke test — documented in Task 6.)

- [ ] **Step 7: Commit**

```bash
git add editors/vscode/src/preview.ts editors/vscode/src/preview-model.ts editors/vscode/src/preview-model.test.ts
git commit -m "feat(vscode): preview host render pipeline + cursor→step mapping"
```

---

### Task 5: Webview controls (toggles, stepper, overlay, highlight)

**Files:**
- Create: `editors/vscode/src/preview-webview.ts` (the webview-side script, bundled into the panel HTML as an inline script string, or built as a separate esbuild entry)
- Modify: `editors/vscode/src/preview.ts` (set `panel.webview.html` with the controls UI + inline script; handle incoming `WebviewToHost` messages)

**Interfaces:**
- Consumes: `HostToWebview` / `WebviewToHost` from `preview-model.ts` (Task 4).
- Produces: the interactive webview. All view changes are CSS/DOM over the received SVG — no host round-trip except the document-change re-render.

- [ ] **Step 1: Build the webview HTML + controls**

In `preview.ts`, set `panel.webview.html` to a document containing:
- A control bar: a CP/folded toggle, a sync on/off checkbox, prev/next step buttons + a step label (enabled only when sync is off), and a construction checklist (populated from the render message).
- A container `<div id="stage">` into which the current SVG is injected.
- An inline `<script>` (the bundled `preview-webview.ts`) implementing:
  - Store the last `HostToWebview` payload; current UI state (`view`, `sync`, `step`, `visibleConstructions`).
  - On `render` message: populate the construction checklist and steps, then `applyState()`.
  - `applyState()`: choose the SVG to show — `view==="cp"` → the crease-pattern SVG with creases whose `data-step` is a step *after* the current step hidden (CSS: `[data-step="X"] { display:none }` for later steps); `view==="folded"` → `foldedSvgByStep[currentStep ?? ""]`. Apply construction visibility (hide `[data-construction="<name>"]` for unchecked). Apply current-step highlight (CSS class on `[data-step="<current>"]`). Inject into `#stage`.
  - When sync is on: the current step follows the host's cursor messages. When sync is off: prev/next buttons change the current step locally; cursor messages are ignored.
  - Post `WebviewToHost` `state` messages on control changes (so the host knows the sync/view state; the host only *needs* sync-state to decide whether to forward cursor updates).
- In `preview.ts`, on the cursor-selection listener, only post the cursor→step update; the webview honors it based on its own sync toggle. (Alternatively track sync-state host-side from the `state` messages and skip posting when off — either is fine; pick one and keep it consistent.)

Provide the highlight + step-filter CSS inline, e.g.:

```css
#stage svg [data-step].current-step { stroke-width: 3; filter: drop-shadow(0 0 2px currentColor); }
.hidden-construction { display: none; }
.hidden-step { display: none; }
```

- [ ] **Step 2: Build**

Run: `cd editors/vscode && bunx tsc --noEmit && bun run compile`
Expected: 0 errors; bundle builds.

- [ ] **Step 3: Verify the wiring is present in the bundle**

Run: `cd editors/vscode && grep -q "visibleConstructions" dist/extension.js && grep -q "current-step" dist/extension.js && echo ok`
Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add editors/vscode/src/preview-webview.ts editors/vscode/src/preview.ts
git commit -m "feat(vscode): preview webview controls — toggles, step scrub, overlay, highlight"
```

---

### Task 6: Manual smoke test + README

**Files:**
- Modify: `editors/vscode/README.md` (document the preview + its manual test)

**Interfaces:**
- Produces: a written manual smoke-test procedure (the extension-host interaction can't be unit-tested headlessly) and the preview entry in the README.

- [ ] **Step 1: Document the smoke test + preview**

In `editors/vscode/README.md`, add a "Live preview" section: run the extension (`code --extensionDevelopmentPath=$(pwd)`), open `examples/cube-root.bel`, run **Beloch: Show Preview**, and verify: the folded diagram appears; moving the cursor between `step` panels (sync on) changes the shown step; toggling to CP shows the crease pattern; toggling sync off lets prev/next step through manually; checking/unchecking a named construction shows/hides its overlay; the current step's crease is highlighted.

- [ ] **Step 2: Commit**

```bash
git add editors/vscode/README.md
git commit -m "docs(vscode): live preview usage + manual smoke test"
```

---

## Self-Review

**Spec coverage:**
- Phase 1 per-step folded frames, step-tagged, exact, baseline frame → Tasks 1–2. ✓
- Multi-frame FOLD documented in spec §7 → Task 2. ✓
- fold2svg `data-step`/`data-construction` hooks + step selector → Task 3. ✓
- Host pipeline (resolveBeloch + fold + fold2svg), cursor→step mapping, error display → Task 4. ✓
- Webview: CP/folded toggle, sync on/off with manual stepping, construction selector, current-step highlight, pre-first-step baseline → Task 5. ✓
- Webview holds no geometry; re-render only on doc change → Tasks 4–5 (host renders; webview CSS/DOM). ✓
- Additive package.json; contributes frozen → Tasks 4–5 (no contributes touched; command pre-exists). ✓
- Testing: OCaml per-step frames, fold2svg hooks, cursor→step + protocol pure fns, manual smoke → Tasks 1–6. ✓

**Placeholder scan:** No TBD/TODO. OCaml Task 2 is a refactor — the extract-and-parameterize is described against the exact existing structure with the new function's full signature and returned JSON; the moved bodies are the file's current per-face/per-edge/per-order computations, named explicitly. Webview Task 5 gives the concrete `applyState()` behavior, message types, and CSS; routine DOM plumbing is the implementer's to write against that spec.

**Type consistency:** `Eval.folded.frames : (string option * Fold_state.t) list` (Task 1) consumed by `fold_emit` (Task 2). `folded_frame_of_state : Fold_state.t -> string option -> Yojson.Safe.t` used in the `file_frames` map. `beloch:step` tag (Task 2) read by fold2svg `--step` (Task 3) and by the webview via `steps`/`foldedSvgByStep` keyed on step id ("" = baseline). `stepAtLine`/`parseSpanLine`/`HostToWebview`/`WebviewToHost` (Task 4) consumed by the webview (Task 5). Step id `null`/`""` convention: FOLD uses JSON `null` for the baseline `beloch:step`; the webview keys `foldedSvgByStep` with `""` for the baseline — the host maps `null`→`""` when building that record (noted in Task 4's `HostToWebview`).
