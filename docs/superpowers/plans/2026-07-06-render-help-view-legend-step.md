# `beloch render` help, `--view`/`--flip`, `--legend`, step validation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `beloch render` gets a dedicated `--help` screen, a unified `--view cp|folded` (+`--flip`) flag replacing the overlapping `--view top|bottom`/`--folded`, an opt-in `--legend` (default off, was always-on), and `--step` that accepts a name or 1-based ordinal and errors clearly (listing available named steps) instead of silently falling back.

**Architecture:** Three layers, bottom-up. `@beloch/scene`'s `pickStep` gains ordinal matching and a structured `StepNotFoundError`. `@beloch/render-svg`'s `renderCP`/`renderFolded` gain a `legend` option (default off). `fold2svg.ts` (the `beloch-render` CLI) gets the new `--view`/`--flip`/`--legend` flags and a top-level error boundary that turns thrown `SceneError`s into a clean one-line stderr message (colored named-step list on a TTY). Two in-repo consumers of the old flags (`editors/vscode/src/preview.ts`, `render/README.md`) get updated to match. Finally, `beloch render --help`/`-h` is added on the OCaml side (`bin/main.ml` + `bin/render_cli.ml`), intercepted before the `beloch-render`-on-PATH check so it works even when `beloch-render` isn't installed.

**Tech Stack:** OCaml (dune, Alcotest) for `beloch render`'s CLI dispatch; TypeScript (Bun, `bun:test`) for `@beloch/scene` and `@beloch/render-svg`.

## Global Constraints

- No backwards-compat shim for `--folded` / `--view top|bottom` — removed outright (spec: pre-1.0, no external consumers besides this repo).
- `--view folded` is 2D only; 3D folded views are out of scope for this work.
- Color in error output is applied only at the `fold2svg.ts` CLI boundary, gated on `process.stderr.isTTY` — never baked into a thrown error's `.message`.
- Follow the existing pattern in `bin/render_cli.ml`/`bin/main.ml`: testable logic (string constants, pure predicates) lives in the `render_cli` library; `main.ml` stays a thin dispatcher.

Spec: `docs/superpowers/specs/2026-07-06-render-help-legend-step-validation-design.md`

---

### Task 1: `pickStep` accepts a name or 1-based ordinal, throws `StepNotFoundError`

**Files:**
- Modify: `render/scene/src/types.ts` (add `StepNotFoundError`)
- Modify: `render/scene/src/parse.ts:62-68` (`pickStep`)
- Test: `render/scene/test/parse.test.ts`

**Interfaces:**
- Produces: `StepNotFoundError` (exported from `@beloch/scene`, extends `SceneError`), constructed as `new StepNotFoundError(label: string, available: { index: number; label: string | null }[])`. Static `StepNotFoundError.render(label: string, available: { index: number; label: string | null }[], style: (s: string) => string): string` — pure formatting, `style` wraps each named step's label (e.g. for color; identity function for plain text).
- Produces: `pickStep(scene: FoldScene, label?: string): Step | undefined` (signature unchanged; still `undefined` only when `scene.steps` is empty and no `label` given — unchanged from before). Now throws `StepNotFoundError` when a `label` is given and doesn't match any step name or valid ordinal.
- Consumes: existing `FoldScene`, `Step` types from `render/scene/src/types.ts`.

- [ ] **Step 1: Replace the old "falls back" test and add name/ordinal/error tests**

In `render/scene/test/parse.test.ts`, change the import line:

```ts
import { parseFold, pickStep, SceneError, StepNotFoundError } from "@beloch/scene";
```

Replace this test:

```ts
test("pickStep: undefined or unmatched label falls back to last step", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  expect(pickStep(scene)).toBe(scene.steps[scene.steps.length - 1]);
  expect(pickStep(scene, "no-such-step")).toBe(scene.steps[scene.steps.length - 1]);
});
```

with:

```ts
test("pickStep: no label falls back to last step", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  expect(pickStep(scene)).toBe(scene.steps[scene.steps.length - 1]);
});

test("pickStep: unmatched label throws StepNotFoundError listing named steps", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  expect(() => pickStep(scene, "no-such-step")).toThrow(StepNotFoundError);
  try {
    pickStep(scene, "no-such-step");
    throw new Error("expected pickStep to throw");
  } catch (err) {
    expect(err).toBeInstanceOf(StepNotFoundError);
    expect((err as Error).message).toBe(
      "step 'no-such-step' not found — 4 step(s) available. " +
        "named steps are vertical_middle (2), thirds (3), beloch_fold (4)",
    );
  }
});

test("pickStep: numeric label selects by 1-based ordinal", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  expect(pickStep(scene, "2")!.label).toBe("vertical_middle");
  expect(pickStep(scene, "1")!.label).toBeNull();
});

test("pickStep: out-of-range ordinal throws StepNotFoundError", async () => {
  const scene = parseFold(await golden("syntax/cube-root.fold"));
  expect(() => pickStep(scene, "10")).toThrow(StepNotFoundError);
});

test("StepNotFoundError.render: no named steps omits the list", () => {
  expect(StepNotFoundError.render("x", [{ index: 0, label: null }], (s) => s)).toBe(
    "step 'x' not found — 1 step(s) available",
  );
});

test("StepNotFoundError.render: applies the given style to names only", () => {
  const available = [{ index: 0, label: null }, { index: 1, label: "a" }];
  const styled = StepNotFoundError.render("x", available, (s) => `[${s}]`);
  expect(styled).toBe("step 'x' not found — 2 step(s) available. named steps are [a] (2)");
});
```

- [ ] **Step 2: Run the tests, confirm they fail**

Run: `cd render && bun test scene/test/parse.test.ts`
Expected: FAIL — `StepNotFoundError` is not exported from `@beloch/scene` (module resolution error), or (once that's stubbed) the old `pickStep` still falls back silently instead of throwing.

- [ ] **Step 3: Add `StepNotFoundError` to `render/scene/src/types.ts`**

Append after the existing `export class SceneError extends Error {}` line:

```ts
export class StepNotFoundError extends SceneError {
  constructor(
    readonly label: string,
    readonly available: { index: number; label: string | null }[],
  ) {
    super(StepNotFoundError.render(label, available, (s) => s));
  }

  static render(
    label: string,
    available: { index: number; label: string | null }[],
    style: (s: string) => string,
  ): string {
    const named = available
      .filter((s) => s.label !== null)
      .map((s) => `${style(s.label!)} (${s.index + 1})`)
      .join(", ");
    return (
      `step '${label}' not found — ${available.length} step(s) available` +
      (named ? `. named steps are ${named}` : "")
    );
  }
}
```

- [ ] **Step 4: Implement name-or-ordinal matching in `pickStep`**

In `render/scene/src/parse.ts`, change the import line:

```ts
import {
  Assignment, Crease, EdgeProvenance, FoldScene, Frame, LineCoeffs,
  NamedLine, NamedPoint, SceneError, Step, StepNotFoundError, Vec2,
} from "./types";
```

Replace the `pickStep` function:

```ts
export function pickStep(scene: FoldScene, label?: string): Step | undefined {
  if (label === undefined) return scene.steps[scene.steps.length - 1];
  const byName = scene.steps.find((s) => s.label === label);
  if (byName) return byName;
  if (/^\d+$/.test(label)) {
    const idx = Number(label) - 1;
    if (idx >= 0 && idx < scene.steps.length) return scene.steps[idx];
  }
  throw new StepNotFoundError(
    label,
    scene.steps.map((s, i) => ({ index: i, label: s.label })),
  );
}
```

- [ ] **Step 5: Run the tests, confirm they pass**

Run: `cd render && bun test scene/test/parse.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 6: Commit**

```bash
git add render/scene/src/types.ts render/scene/src/parse.ts render/scene/test/parse.test.ts
git commit -m "feat(scene): pickStep accepts name or ordinal, throws StepNotFoundError"
```

---

### Task 2: `--legend` opt-in in `renderCP`/`renderFolded` (default off)

**Files:**
- Modify: `render/render-svg/src/render-cp.ts:9-13` (`RenderOptions`), `:133` (`appendLegend` call)
- Modify: `render/render-svg/src/render-folded.ts:212` (`appendLegend` call)
- Test: `render/render-svg/test/render-cp.test.ts`, `render/render-svg/test/render-folded.test.ts`
- Modify (regenerated): `render/render-svg/test/__snapshots__/render-cp.test.ts.snap`, `render/render-svg/test/__snapshots__/render-folded.test.ts.snap`

**Interfaces:**
- Produces: `RenderOptions.legend?: boolean` (default `false`), consumed by both `renderCP` and `renderFolded` (via `FoldedOptions extends RenderOptions`).
- Consumes: existing `appendLegend(doc, layout, theme, frame)` from `render/render-svg/src/constructions.ts` (unchanged).

- [ ] **Step 1: Add legend tests to both test files**

In `render/render-svg/test/render-cp.test.ts`, add:

```ts
test("legend hidden by default", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  const s = renderCP(scene).toString();
  expect(s).not.toContain('class="legend-panel"');
});

test("legend: true shows the legend panel", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  const s = renderCP(scene, { legend: true }).toString();
  expect(s).toContain('class="legend-panel"');
});
```

In `render/render-svg/test/render-folded.test.ts`, add:

```ts
test("legend hidden by default", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  const s = renderFolded(scene).toString();
  expect(s).not.toContain('class="legend-panel"');
});

test("legend: true shows the legend panel", async () => {
  const scene = parseFold(await golden("syntax/fold-quarter.fold"));
  const s = renderFolded(scene, { legend: true }).toString();
  expect(s).toContain('class="legend-panel"');
});
```

Also update the existing test in `render-cp.test.ts` that currently asserts the legend is present by default — it must now pass `legend: true`:

```ts
test("bisect-a CP: faces, colored creases, named constructions, legend", async () => {
  const scene = parseFold(await golden("syntax/bisect-a.fold"));
  const s = renderCP(scene, { legend: true }).toString();
```

(only the `renderCP(scene)` call on that line changes to `renderCP(scene, { legend: true })`; the rest of the test body is unchanged.)

- [ ] **Step 2: Run the tests, confirm the new "hidden by default" tests fail**

Run: `cd render && bun test render-svg/test/render-cp.test.ts render-svg/test/render-folded.test.ts`
Expected: FAIL on both new "legend hidden by default" tests (legend is currently always rendered) and on the "bisect-a CP: faces, colored creases, named constructions, legend" test (`legend: true` option doesn't exist yet, so it's just ignored — that one may still pass; the two new "hidden by default" tests are the ones that must fail here).

- [ ] **Step 3: Gate `appendLegend` in `render-cp.ts`**

Change the `RenderOptions` interface:

```ts
export interface RenderOptions {
  title?: string;
  constructions?: string[];             // ["--v", ".e"]; undefined = all auxiliary
  theme?: Partial<Theme>;
  legend?: boolean;                     // default false
}
```

Change the `appendLegend` call:

```ts
  appendConstructions(doc, scene, layout, theme, opts.constructions, null);
  if (opts.title) appendTitle(doc, theme, opts.title);
  if (opts.legend) appendLegend(doc, layout, theme, frame);
  return doc;
}
```

- [ ] **Step 4: Gate `appendLegend` in `render-folded.ts`**

Change the `appendLegend` call:

```ts
  appendConstructions(doc, scene, layout, theme, opts.constructions, { frame });
  if (opts.title) appendTitle(doc, theme, opts.title);
  if (opts.legend) appendLegend(doc, layout, theme, frame);
  return doc;
}
```

- [ ] **Step 5: Run the tests, confirm the new tests pass and the golden snapshot tests fail**

Run: `cd render && bun test render-svg/test/render-cp.test.ts render-svg/test/render-folded.test.ts`
Expected: the new legend tests and the updated "bisect-a CP..." test PASS. The three pre-existing golden snapshot tests ("bisect-a CP golden snapshot", "fold-quarter folded golden snapshot", "fold-occlude dashed golden snapshot") FAIL — their stored `.snap` output still has the legend group, current output no longer does.

- [ ] **Step 6: Re-record the golden snapshots**

Run: `cd render && bun test render-svg/test/render-cp.test.ts render-svg/test/render-folded.test.ts --update-snapshots`
Expected: snapshot files updated, run reports all tests passing.

- [ ] **Step 7: Run the tests once more to confirm everything is green**

Run: `cd render && bun test render-svg/test/render-cp.test.ts render-svg/test/render-folded.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 8: Commit**

```bash
git add render/render-svg/src/render-cp.ts render/render-svg/src/render-folded.ts \
  render/render-svg/test/render-cp.test.ts render/render-svg/test/render-folded.test.ts \
  render/render-svg/test/__snapshots__/render-cp.test.ts.snap \
  render/render-svg/test/__snapshots__/render-folded.test.ts.snap
git commit -m "feat(render-svg): legend is opt-in via legend:true (was always on)"
```

---

### Task 3: `fold2svg.ts` — `--view cp|folded`, `--flip`, `--legend`, clean error surface

**Files:**
- Modify: `render/render-svg/bin/fold2svg.ts` (full rewrite of flag parsing + error handling)
- Test: `render/render-svg/test/cli.test.ts`

**Interfaces:**
- Consumes: `StepNotFoundError`, `SceneError` from `@beloch/scene` (Task 1); `RenderOptions.legend`, `FoldedOptions.view` from `@beloch/render-svg` (Task 2, unchanged internal `"top" | "bottom"` shape).
- Produces: CLI flags `--view cp|folded` (validated), `--flip` (boolean), `--legend` (boolean); stderr format `beloch-render: <message>` on any `SceneError`, exit code 1.

- [ ] **Step 1: Update `cli.test.ts` for the new flags and error behavior**

Replace the full contents of `render/render-svg/test/cli.test.ts`:

```ts
import { test, expect } from "bun:test";

const CLI = new URL("../bin/fold2svg.ts", import.meta.url).pathname;
const FIX = new URL("../../../tests/golden/syntax/fold-quarter.fold", import.meta.url).pathname;
const CUBE_ROOT = new URL("../../../tests/golden/syntax/cube-root.fold", import.meta.url).pathname;

test("CLI: fold → SVG on stdout", async () => {
  const p = Bun.spawn(["bun", CLI, FIX]);
  const out = await new Response(p.stdout).text();
  expect(await p.exited).toBe(0);
  expect(out).toStartWith("<svg");
});

test("CLI: --view folded → folded view PNG file", async () => {
  const out = `${process.env.TMPDIR ?? "/tmp"}/beloch-cli-test.png`;
  const p = Bun.spawn(["bun", CLI, FIX, out, "--view", "folded"]);
  expect(await p.exited).toBe(0);
  const bytes = new Uint8Array(await Bun.file(out).arrayBuffer());
  // PNG magic
  expect([...bytes.slice(0, 4)]).toEqual([0x89, 0x50, 0x4e, 0x47]);
});

test("CLI: --view folded --flip renders a different SVG than unflipped", async () => {
  const top = Bun.spawn(["bun", CLI, FIX, "--view", "folded"]);
  const bottom = Bun.spawn(["bun", CLI, FIX, "--view", "folded", "--flip"]);
  const topOut = await new Response(top.stdout).text();
  const bottomOut = await new Response(bottom.stdout).text();
  expect(await top.exited).toBe(0);
  expect(await bottom.exited).toBe(0);
  expect(topOut).not.toBe(bottomOut);
});

test("CLI: unknown --view value exits 1 with a plain error", async () => {
  const p = Bun.spawn(["bun", CLI, FIX, "--view", "top"], { stderr: "pipe" });
  const err = await new Response(p.stderr).text();
  expect(await p.exited).toBe(1);
  expect(err).toContain("unknown --view value 'top' — expected cp or folded");
});

test("CLI: stdin input", async () => {
  const p = Bun.spawn(["bun", CLI, "-"], { stdin: Bun.file(FIX) });
  const out = await new Response(p.stdout).text();
  expect(await p.exited).toBe(0);
  expect(out).toStartWith("<svg");
});

test("CLI: --legend adds the legend panel", async () => {
  const p = Bun.spawn(["bun", CLI, FIX]);
  const without = await new Response(p.stdout).text();
  expect(await p.exited).toBe(0);
  const q = Bun.spawn(["bun", CLI, FIX, "--legend"]);
  const withLegend = await new Response(q.stdout).text();
  expect(await q.exited).toBe(0);
  expect(without).not.toContain('class="legend-panel"');
  expect(withLegend).toContain('class="legend-panel"');
});

test("CLI: unmatched --step exits 1 with the available named steps", async () => {
  const p = Bun.spawn(
    ["bun", CLI, CUBE_ROOT, "--view", "folded", "--step", "no-such-step"],
    { stderr: "pipe" },
  );
  const err = await new Response(p.stderr).text();
  expect(await p.exited).toBe(1);
  expect(err).toBe(
    "beloch-render: step 'no-such-step' not found — 4 step(s) available. " +
      "named steps are vertical_middle (2), thirds (3), beloch_fold (4)\n",
  );
});
```

- [ ] **Step 2: Run the tests, confirm the new ones fail**

Run: `cd render && bun test render-svg/test/cli.test.ts`
Expected: FAIL on 4 tests — "unknown --view value exits 1...", "--legend adds the legend panel", "unmatched --step exits 1..." (none of this behavior exists yet), and "--view folded --flip renders a different SVG..." (old code has no `--flip` handling, so both spawns render identically). The plain "--view folded → folded view PNG file" test already passes against the old code by coincidence — any truthy `--view` value falls into the old code's folded branch, and only the literal string `"bottom"` triggers its mirroring. That's fine; it stays green through this step.

- [ ] **Step 3: Rewrite `fold2svg.ts`**

Replace the full contents of `render/render-svg/bin/fold2svg.ts`:

```ts
#!/usr/bin/env bun
// fold2svg-compatible CLI: FOLD -> labelled SVG/PNG diagram, on top of
// @beloch/scene + @beloch/render-svg. Flag parsing ported from
// tools/fold2svg.mjs:162-184 (minus the rabbit-ear load-check — the OCaml
// emitter's own tests own FOLD validity).
// Usage:
//   bun bin/fold2svg.ts input.fold [out.svg|out.png] [--title "..."]
//   bun bin/fold2svg.ts f.fold --view folded [--flip] [--hidden dashed|hide]
//   beloch fold f.bel | bun bin/fold2svg.ts - out.png --title f.bel
import { parseFold, SceneError, StepNotFoundError } from "@beloch/scene";
import { renderCP, renderFolded } from "@beloch/render-svg";

const args = process.argv.slice(2);
const flagVal = (name: string): string | undefined => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

const title = flagVal("--title") || "";
const viewFlag = flagVal("--view"); // undefined | "cp" | "folded"
if (viewFlag !== undefined && viewFlag !== "cp" && viewFlag !== "folded") {
  console.error(`beloch-render: unknown --view value '${viewFlag}' — expected cp or folded`);
  process.exit(1);
}
const flip = args.includes("--flip");
const hidden = (flagVal("--hidden") || "hide") as "dashed" | "hide";
const constructionsFlag = flagVal("--constructions"); // undefined = show all
const legend = args.includes("--legend");
const step = flagVal("--step");
const formatFlag = flagVal("--format"); // "svg"|"png", overrides outPath extension
const widthFlag = flagVal("--width"); // PNG output width in px; default = doc width
const FLAGS = new Set([
  "--title", "--view", "--hidden", "--constructions", "--step", "--format", "--width",
]);
const positional = args.filter((a, i) => !a.startsWith("--") && !FLAGS.has(args[i - 1]!));
const [inPath, outPath] = positional;
const format = formatFlag ?? (outPath?.endsWith(".png") ? "png" : "svg");

// undefined = show all (fold2svg.mjs:360); "" splits to [] = show none.
const constructions = constructionsFlag !== undefined
  ? constructionsFlag.split(",").map((s) => s.trim()).filter(Boolean)
  : undefined;

try {
  const raw = !inPath || inPath === "-" ? await Bun.stdin.text() : await Bun.file(inPath).text();
  const scene = parseFold(raw);
  const opts = { title, constructions, legend };
  const doc = viewFlag === "folded"
    ? renderFolded(scene, { ...opts, view: flip ? "bottom" : "top", hidden, step })
    : renderCP(scene, opts);
  const svg = doc.toString();

  if (format === "png") {
    const { Resvg } = await import("@resvg/resvg-js");
    const width = widthFlag ? Number(widthFlag) : doc.width;
    const png = new Resvg(svg, { background: "white", fitTo: { mode: "width", value: width } })
      .render().asPng();
    if (outPath) await Bun.write(outPath, png);
    else process.stdout.write(png);
  } else if (outPath) {
    await Bun.write(outPath, svg);
  } else {
    process.stdout.write(svg);
  }
} catch (err) {
  if (err instanceof StepNotFoundError) {
    const tty = process.stderr.isTTY;
    const style = tty ? (s: string) => `\x1b[1;36m${s}\x1b[0m` : (s: string) => s;
    console.error(`beloch-render: ${StepNotFoundError.render(err.label, err.available, style)}`);
  } else if (err instanceof SceneError) {
    console.error(`beloch-render: ${err.message}`);
  } else {
    throw err;
  }
  process.exit(1);
}
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `cd render && bun test render-svg/test/cli.test.ts`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add render/render-svg/bin/fold2svg.ts render/render-svg/test/cli.test.ts
git commit -m "feat(render-svg): unify --view cp|folded + --flip, --legend flag, clean errors"
```

---

### Task 4: Update in-repo consumers of the old flags

**Files:**
- Modify: `editors/vscode/src/preview.ts:99-105` (comment), `:121`, `:123` (`runFold2svg` calls)
- Modify: `render/README.md:25,31` (flag synopsis)

**Interfaces:**
- Consumes: the new `--view folded` flag from Task 3 (no more `--view top`).

- [ ] **Step 1: Update `preview.ts`'s two `runFold2svg` calls and the stale comment**

Change:

```ts
      foldedSvgByStep[key] = runFold2svg(["-", "--view", "top"], baselineJson, cwd);
    } else {
      foldedSvgByStep[key] = runFold2svg(["-", "--view", "top", "--step", stepId], foldJson, cwd);
```

to:

```ts
      foldedSvgByStep[key] = runFold2svg(["-", "--view", "folded"], baselineJson, cwd);
    } else {
      foldedSvgByStep[key] = runFold2svg(["-", "--view", "folded", "--step", stepId], foldJson, cwd);
```

And update the comment above (currently describing the old silent-fallback behavior) from:

```ts
 * `fold2svg --step <id>` selects a frame by matching `beloch:step` against a
 * CLI string, so it can pick any *named* step directly. The baseline frame's
 * `beloch:step` is JSON `null`, which no CLI string can match — `--step`
 * would silently fall back to the *last* frame instead (fold2svg's documented
 * fallback). To render the baseline correctly, the baseline case sends a
 * trimmed FOLD (`file_frames: [thatFrame]`) so the frame is both first and
 * last and needs no `--step` match at all.
 */
```

to:

```ts
 * `fold2svg --step <id>` selects a frame by matching `beloch:step` against a
 * CLI string, so it can pick any *named* step directly. The baseline frame's
 * `beloch:step` is JSON `null`, which no CLI string can match — `--step`
 * now throws a step-not-found error instead of silently rendering the wrong
 * frame. To render the baseline correctly, the baseline case sends a
 * trimmed FOLD (`file_frames: [thatFrame]`) so the frame is both first and
 * last and needs no `--step` match at all.
 */
```

- [ ] **Step 2: Update `render/README.md`'s flag synopsis**

Change:

```
bun render/render-svg/bin/fold2svg.ts <in.fold|-> [out.svg|out.png]
  [--title "..."] [--folded] [--view top|bottom] [--hidden dashed|hide]
  [--constructions "--v,.e"] [--step <label>]
```

```
`-`/missing input reads stdin; missing output writes SVG to stdout; a
`.png` output suffix renders via `@resvg/resvg-js` (white background,
fit-to-width). `--folded` is shorthand for `--view top`.
```

to:

```
bun render/render-svg/bin/fold2svg.ts <in.fold|-> [out.svg|out.png]
  [--title "..."] [--view cp|folded] [--flip] [--hidden dashed|hide]
  [--constructions "--v,.e"] [--step <label|N>] [--legend]
```

```
`-`/missing input reads stdin; missing output writes SVG to stdout; a
`.png` output suffix renders via `@resvg/resvg-js` (white background,
fit-to-width). `--view folded` renders the folded state (2D); `--flip`
views it from the other side.
```

- [ ] **Step 3: Typecheck both affected workspaces**

Run: `cd render && bun x tsc --noEmit`
Expected: no errors.

Run: `cd editors/vscode && bun x tsc --noEmit`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add editors/vscode/src/preview.ts render/README.md
git commit -m "docs+fix: update --view folded consumers (vscode preview, render/README)"
```

---

### Task 5: OCaml `render_cli` — help text + `wants_help`

**Files:**
- Modify: `bin/render_cli.ml`
- Test: `tests/test_render_cli.ml`

**Interfaces:**
- Produces: `Render_cli.wants_help : string list -> bool`, `Render_cli.render_help : string` (full help text, trailing newline, ends with a final blank-line-free `examples:` block).
- Consumes: nothing new (pure string/list operations, no external deps).

- [ ] **Step 1: Add failing tests to `tests/test_render_cli.ml`**

Replace the full contents of `tests/test_render_cli.ml`:

```ocaml
open Render_cli

let test_which_found () =
  let dir = Filename.temp_file "render_cli_test" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let path = Filename.concat dir "myprog" in
  let oc = open_out path in
  output_string oc "#!/bin/sh\nexit 0\n";
  close_out oc;
  Unix.chmod path 0o755;
  let saved_path = Sys.getenv_opt "PATH" in
  Unix.putenv "PATH" dir;
  let result = which "myprog" in
  (match saved_path with Some p -> Unix.putenv "PATH" p | None -> ());
  Sys.remove path;
  Unix.rmdir dir;
  Alcotest.(check bool) "found on PATH" true (result <> None)

let test_which_missing () =
  let dir = Filename.temp_file "render_cli_test" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let saved_path = Sys.getenv_opt "PATH" in
  Unix.putenv "PATH" dir;
  let result = which "nonexistent-binary-xyz" in
  (match saved_path with Some p -> Unix.putenv "PATH" p | None -> ());
  Unix.rmdir dir;
  Alcotest.(check bool) "not found" true (result = None)

let test_dim_tty () =
  Alcotest.(check string) "dimmed" "\027[2mhint\027[0m" (dim ~is_tty:true "hint")

let test_dim_no_tty () =
  Alcotest.(check string) "plain" "hint" (dim ~is_tty:false "hint")

let test_wants_help_flag () =
  Alcotest.(check bool) "--help" true (wants_help [ "--help" ]);
  Alcotest.(check bool) "-h" true (wants_help [ "-h" ]);
  Alcotest.(check bool)
    "mixed with other args" true
    (wants_help [ "f.bel"; "--legend"; "--help" ])

let test_wants_help_absent () =
  Alcotest.(check bool) "no help flag" false (wants_help [ "f.bel"; "--legend" ])

let contains_substring ~needle haystack =
  let nlen = String.length needle and hlen = String.length haystack in
  let rec loop i =
    if i + nlen > hlen then false
    else if String.sub haystack i nlen = needle then true
    else loop (i + 1)
  in
  nlen = 0 || loop 0

let test_render_help_mentions_flags () =
  List.iter
    (fun sub ->
      Alcotest.(check bool)
        (Printf.sprintf "render_help mentions %s" sub)
        true
        (contains_substring ~needle:sub render_help))
    [
      "beloch render";
      "--view cp|folded";
      "--flip";
      "--legend";
      "--step NAME|N";
      "--constructions";
      "--format svg|png";
      "--width";
      "--open";
    ]

let () =
  Alcotest.run "render_cli"
    [
      ( "which",
        [
          Alcotest.test_case "found on PATH" `Quick test_which_found;
          Alcotest.test_case "not found" `Quick test_which_missing;
        ] );
      ( "dim",
        [
          Alcotest.test_case "tty wraps in ANSI dim" `Quick test_dim_tty;
          Alcotest.test_case "non-tty passes through" `Quick test_dim_no_tty;
        ] );
      ( "wants_help",
        [
          Alcotest.test_case "recognizes --help/-h" `Quick test_wants_help_flag;
          Alcotest.test_case "false without a help flag" `Quick
            test_wants_help_absent;
        ] );
      ( "render_help",
        [
          Alcotest.test_case "mentions every flag" `Quick
            test_render_help_mentions_flags;
        ] );
    ]
```

- [ ] **Step 2: Run the test, confirm it fails to build**

Run: `dune exec tests/test_render_cli.exe`
Expected: FAIL — build error, `wants_help` and `render_help` are unbound in `Render_cli`.

- [ ] **Step 3: Add `wants_help` and `render_help` to `bin/render_cli.ml`**

Append to `bin/render_cli.ml`:

```ocaml
let wants_help args = List.mem "--help" args || List.mem "-h" args

let render_help =
  {|beloch render — render a .bel or .fold file to SVG/PNG

usage:
  beloch render FILE.bel|FILE.fold [OUT] [flags]

file selection:
  FILE.bel                  evaluated first (like `beloch fold`), then rendered
  FILE.fold                 rendered directly (FOLD JSON)
  OUT                       output path; extension picks the format unless
                            --format is set. Omit OUT to write to stdout.

what gets rendered:
  --view cp|folded          cp (default): crease pattern, the flat unfolded
                            state. folded: the folded state (2D; 3D planned
                            for later, not this release).
  --flip                    view the folded state from the other side
                            (ignored/no-op with --view cp)

step selection (--view folded only):
  --step NAME|N             NAME = a declared `step <name>` label from the
                            .bel source; N = 1-based ordinal position among
                            declared steps. Default: last step (final
                            folded state). Errors if NAME/N doesn't exist,
                            listing the named steps that do.

constructions (named points/lines):
  --constructions a,b,c     only render these named constructions
                            (comma-separated). Default: render all.

display options:
  --legend                  show the M/V/B/U crease-type legend (default: off)
  --title TEXT              caption drawn in the top-left corner
  --hidden dashed|hide      how occluded creases are drawn in folded view
                            (default: hide)

output options:
  --format svg|png          overrides the format implied by OUT's extension
                            (default: svg)
  --width N                 PNG output width in px (default: document width)
  --open                    render to a temp file and open it (xdg-open)

examples:
  beloch render kite.bel
  beloch render kite.bel --view folded out.png
  beloch render kite.bel --view folded --flip out.png
  beloch render kite.bel --step precrease --open
|}
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: `dune exec tests/test_render_cli.exe`
Expected: PASS, all test cases OK.

- [ ] **Step 5: Commit**

```bash
git add bin/render_cli.ml tests/test_render_cli.ml
git commit -m "feat(cli): render_cli.wants_help + render_help text"
```

---

### Task 6: Wire `beloch render --help` into `bin/main.ml`

**Files:**
- Modify: `bin/main.ml:14-25` (`usage()`), `:95` (`run_render`)

**Interfaces:**
- Consumes: `Render_cli.wants_help`, `Render_cli.render_help` (Task 5).

- [ ] **Step 1: Intercept `--help`/`-h` at the top of `run_render`, and point `usage()` at it**

Change the `usage()` function's render line from:

```ocaml
  beloch render FILE.fold|FILE.bel    render to a visual output (SVG/PNG)%s
```

to:

```ocaml
  beloch render FILE.fold|FILE.bel    render to a visual output (SVG/PNG) — see `beloch render --help`%s
```

Change the start of `run_render`:

```ocaml
let run_render args =
  match Render_cli.which render_bin with
```

to:

```ocaml
let run_render args =
  if Render_cli.wants_help args then begin
    print_string Render_cli.render_help;
    exit 0
  end;
  match Render_cli.which render_bin with
```

- [ ] **Step 2: Build**

Run: `dune build`
Expected: success, no errors.

- [ ] **Step 3: Smoke-test `beloch render --help`**

Run:
```bash
dune exec bin/main.exe -- render --help
echo "exit: $?"
```
Expected: prints the help text starting with `beloch render — render a .bel or .fold file to SVG/PNG`, includes `--view cp|folded`, `--flip`, `--legend`, `--step NAME|N`; `exit: 0`.

Run also with `-h`:
```bash
dune exec bin/main.exe -- render -h
echo "exit: $?"
```
Expected: same output, `exit: 0`.

- [ ] **Step 4: Commit**

```bash
git add bin/main.ml
git commit -m "feat(cli): beloch render --help/-h"
```
