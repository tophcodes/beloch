# Playground cumulative marks overlay — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scrubbing the Playground's folded-step view to step `i` shows every still-active mark from statements `0..i` (not just step `i`'s own mark), with the most recently added mark drawn in an accent color at full opacity.

**Architecture:** `SceneOptions.markOverlay` changes from a single `Mark` to `{ marks: Mark[]; newestCreaseId?: number }`. `render-scene.ts`'s folded-branch mark-drawing block loops over the array instead of drawing one mark, applying accent styling (`theme.construction`, `opacity: 1`) to the mark matching `newestCreaseId`. `Playground.astro`'s `renderStep(i)` builds the cumulative, still-active mark list from `currentStatements.slice(0, i+1)` filtered against `currentScene.marks` (drops graduated marks).

**Tech Stack:** TypeScript, Bun test runner (`bun test`), Astro (client-side `<script>` in `Playground.astro`, no automated test harness for it).

## Global Constraints

- `markOverlay` stays the field name (per spec, call sites are repo-scoped).
- No new theme token — reuse `theme.construction` (`#6366f1`) for the "newest mark" accent.
- Highlight = color + opacity change only; dasharray/stroke-width stay as today's mark style.
- Draw order: oldest → newest (array order), so newest paints on top.
- Flat CP view (`renderCP`, `render-scene.ts:438-468`) is out of scope — unchanged.
- No new Playground prop — behavior change is internal to `renderStep`.
- Spec: `docs/superpowers/specs/2026-07-20-playground-cumulative-marks-design.md`.

---

### Task 1: `MarkOverlay` type + multi-mark rendering in `render-scene.ts`

**Files:**
- Modify: `packages/render-2d/render-svg/src/render-scene.ts:26-36` (types), `:339-398` (draw loop)
- Modify: `packages/render-2d/render-svg/src/render-folded.ts:9-36` (`FoldedOptions.markOverlay` type + passthrough)
- Test: `packages/render-2d/render-svg/test/render-folded.test.ts:173-224` (existing single-mark tests → new shape; new multi-mark/highlight tests)

**Interfaces:**
- Produces: `export interface MarkOverlay { marks: Mark[]; newestCreaseId?: number }` from `render-scene.ts`, re-exported wherever `SceneOptions`/`FoldedOptions` are exported today (check `packages/render-2d/render-svg/src/index.ts` — add `MarkOverlay` to its export list if `SceneOptions`/`Mark` are already exported there).
- Consumes: existing `Mark`, `SegMark`, `PointMark` from `@beloch/scene` (unchanged), existing `theme.construction`, `theme.lineStyle` (unchanged).

- [ ] **Step 1: Read `packages/render-2d/render-svg/src/index.ts` to see current export shape**

Run: `grep -n "SceneOptions\|FoldedOptions\|export" packages/render-2d/render-svg/src/index.ts`

Confirm whether `SceneOptions`/`FoldedOptions`/`Mark` are re-exported by name or via `export *`. If `export *` from `render-scene.ts` and `render-folded.ts`, no index.ts change is needed — `MarkOverlay` is automatically exported once declared there. If named exports, add `MarkOverlay` to the list next to `SceneOptions`.

- [ ] **Step 2: Write the failing test — multiple marks render, newest is highlighted**

Add to `packages/render-2d/render-svg/test/render-folded.test.ts` (near the existing markOverlay tests, same `golden()`/`Mark` imports already in that file):

```ts
test("renderFolded: markOverlay draws multiple marks, highlighting the newest", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));

  const older: Mark = {
    kind: "seg", a: [0.1, 0.1], b: [0.2, 0.2], line: [1, -1, 0], intent: "V", creaseId: 111,
  };
  const newest: Mark = {
    kind: "seg", a: [0.05, 0.15], b: [0.25, 0.35], line: [1, -1, 0.1], intent: "M", creaseId: 222,
  };
  const svg = renderFolded(scene, {
    theme: WEB_THEME,
    markOverlay: { marks: [older, newest], newestCreaseId: 222 },
  }).toString();

  const olderLine = svg.match(/<line class="mark" data-crease-id="111"[^>]*\/>/);
  const newestLine = svg.match(/<line class="mark" data-crease-id="222"[^>]*\/>/);
  expect(olderLine).not.toBeNull();
  expect(newestLine).not.toBeNull();

  expect(olderLine![0]).toContain('opacity="0.7"');
  expect(newestLine![0]).toContain('opacity="1"');
  expect(newestLine![0]).toContain(`stroke="${WEB_THEME.construction ?? "#6366f1"}"`);
  expect(olderLine![0]).not.toContain(`stroke="${WEB_THEME.construction ?? "#6366f1"}"`);
});

test("renderFolded: markOverlay with an empty marks array draws nothing, same as omitting it", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const withoutOverlay = renderFolded(scene, { theme: WEB_THEME }).toString();
  const withEmptyOverlay = renderFolded(scene, { theme: WEB_THEME, markOverlay: { marks: [] } }).toString();
  expect(withEmptyOverlay).toBe(withoutOverlay);
});
```

- [ ] **Step 3: Run the new tests, confirm they fail**

Run: `cd packages/render-2d/render-svg && bun test test/render-folded.test.ts -t "markOverlay draws multiple|empty marks array"`
Expected: FAIL — either a TS type error (`markOverlay` doesn't accept `{ marks, newestCreaseId }` yet) or, once the harness resolves types loosely, an assertion failure because only one mark is currently ever drawn.

- [ ] **Step 4: Update `SceneOptions.markOverlay` type in `render-scene.ts`**

In `packages/render-2d/render-svg/src/render-scene.ts`, replace line 35:

```ts
  markOverlay?: Mark; // folded only — project this one mark onto the step's faces
```

with:

```ts
  markOverlay?: MarkOverlay; // folded only — project these marks onto the step's faces
```

Add the new interface just above `SceneOptions` (after line 24's `TextureOptions` close):

```ts
export interface MarkOverlay {
  marks: Mark[];
  newestCreaseId?: number; // Mark.creaseId of the most recently added mark — drawn with an accent style
}
```

- [ ] **Step 5: Rewrite the mark-drawing block to loop and highlight**

Replace `packages/render-2d/render-svg/src/render-scene.ts:349-398` (the `if (opts.markOverlay) { ... }` block) with:

```ts
    if (opts.markOverlay) {
      const FM = frame.facesMatrix ?? [];
      const applyIso = ([m00, m01, m10, m11, ox, oy]: FaceMatrix, p: Vec2): Vec2 =>
        [m00 * p[0] + m01 * p[1] + ox, m10 * p[0] + m11 * p[1] + oy];
      for (const m of opts.markOverlay.marks) {
        const isNewest = m.creaseId === opts.markOverlay.newestCreaseId;
        const style = theme.lineStyle(m.intent, theme);
        const markAttrs = {
          stroke: isNewest ? theme.construction : style.stroke,
          "stroke-width": Math.max(1, style.strokeWidth - 1),
          "stroke-dasharray": "2 2",
          "stroke-linecap": "round" as const,
          opacity: isNewest ? 1 : 0.7,
          "data-crease-id": m.creaseId,
        };
        if (m.kind === "seg") {
          for (let fi = 0; fi < F.length; fi++) {
            const M = FM[fi];
            if (!M) continue;
            const tabPoly = F[fi]!.map((idx) => V[idx]!);
            const pa = applyIso(M, m.a), pb = applyIso(M, m.b);
            for (const [t0, t1] of segInsideIntervals(pa, pb, tabPoly)) {
              const p0: Vec2 = [pa[0] + (pb[0] - pa[0]) * t0, pa[1] + (pb[1] - pa[1]) * t0];
              const p1: Vec2 = [pa[0] + (pb[0] - pa[0]) * t1, pa[1] + (pb[1] - pa[1]) * t1];
              creases.children.push(el("line", {
                ...markAttrs, class: "mark", "data-kind": "mark",
                x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
              }));
            }
          }
        } else {
          for (let fi = 0; fi < F.length; fi++) {
            const M = FM[fi];
            if (!M) continue;
            const tabPoly = F[fi]!.map((idx) => V[idx]!);
            const pp = applyIso(M, m.p);
            if (!pointInPolygonInclusive(pp, tabPoly)) continue;
            const TICK = 0.03;
            const [la, lb] = m.line;
            const norm = Math.hypot(lb, -la) || 1;
            const dx = lb / norm, dy = -la / norm;
            const p0 = applyIso(M, [m.p[0] - dx * TICK, m.p[1] - dy * TICK]);
            const p1 = applyIso(M, [m.p[0] + dx * TICK, m.p[1] + dy * TICK]);
            creases.children.push(el("line", {
              ...markAttrs, class: "mark", "data-kind": "mark-tick",
              x1: mx(p0[0]), y1: ty(p0[1]), x2: mx(p1[0]), y2: ty(p1[1]),
            }));
            break; // a point belongs to exactly one face
          }
        }
      }
    }
```

(This is the same per-mark logic as before, just moved inside `for (const m of opts.markOverlay.marks)` and with `markAttrs.stroke`/`opacity` branching on `isNewest`.)

- [ ] **Step 6: Update `FoldedOptions.markOverlay` type in `render-folded.ts`**

In `packages/render-2d/render-svg/src/render-folded.ts`, replace line 13:

```ts
  markOverlay?: Mark;          // project this one mark onto the step's faces
```

with:

```ts
  markOverlay?: MarkOverlay;   // project these marks onto the step's faces (newest highlighted)
```

Update the import on line 3 from `import type { FoldScene, Mark } from "@beloch/scene";` — `Mark` is no longer referenced directly in this file, so import `MarkOverlay` from `./render-scene` instead:

```ts
import type { FoldScene } from "@beloch/scene";
import type { MarkOverlay } from "./render-scene";
```

(Keep the existing `markOverlay: opts.markOverlay` passthrough on line 35 — type now matches.)

- [ ] **Step 7: Update the two existing single-mark tests to the new shape**

In `packages/render-2d/render-svg/test/render-folded.test.ts`:
- Line 177: `markOverlay: undefined` — unchanged (still valid, still a no-op).
- Line 187: change `markOverlay: seg` to `markOverlay: { marks: [seg] }`.
- Line 211: change `markOverlay: stmt.mark` to `markOverlay: { marks: [stmt.mark] }`.
- Line 220: change `markOverlay: rayStmt.mark!` to `markOverlay: { marks: [rayStmt.mark!] }`.

- [ ] **Step 8: Run the full render-svg test suite, confirm everything passes**

Run: `cd packages/render-2d/render-svg && bun test`
Expected: PASS, all tests including the two new ones from Step 2 and the four updated from Step 7.

- [ ] **Step 9: Typecheck the package**

Run: `cd packages/render-2d/render-svg && bunx tsc --noEmit` (or the package's existing typecheck script — check `package.json` for a `"typecheck"` or `"check"` script first and prefer that if present)
Expected: no errors.

- [ ] **Step 10: Commit**

```bash
git add packages/render-2d/render-svg/src/render-scene.ts packages/render-2d/render-svg/src/render-folded.ts packages/render-2d/render-svg/test/render-folded.test.ts
git commit -m "feat(render-svg): markOverlay accepts multiple marks, highlights newest"
```

---

### Task 2: Playground scrubber accumulates marks across steps

**Files:**
- Modify: `packages/www/src/components/Playground.astro:494-512` (`renderStep`)

**Interfaces:**
- Consumes: `MarkOverlay` shape from Task 1 (`{ marks: Mark[]; newestCreaseId?: number }`), `Statement` (`index`, `kind`, `mark`, `frameIndex`, `sourceLine` — unchanged, from `@beloch/scene`), `renderFolded(scene, opts)` (unchanged signature, `opts.markOverlay` now typed `MarkOverlay | undefined`).
- Produces: nothing consumed by later tasks (this is the last task).

Note: an earlier draft of this task also filtered `activeMarks` against
`FoldScene.marks` to drop "graduated" marks. Dropped during implementation —
graduation is a per-frame, purely geometric check (see spec doc's "Existing
data" section, updated); the single final-state `FoldScene.marks` snapshot
is not a valid per-step proxy for it, and a graduated mark's line is already
drawn by the frame's own crease layer regardless, so showing the mark
overlay too is redundant but harmless. No filtering needed.

- [ ] **Step 1: Replace `renderStep`'s markOverlay construction**

In `packages/www/src/components/Playground.astro`, replace lines 500-504:

```ts
        const svg = renderFolded(currentScene, {
          theme: WEB_THEME,
          step: String(stmt.frameIndex),
          markOverlay: stmt.mark ?? undefined,
        }).toString();
```

with:

```ts
        const activeMarks = currentStatements
          .slice(0, clamped + 1)
          .filter((s) => s.kind === "mark" && s.mark !== null)
          .map((s) => s.mark!);
        const newestCreaseId = activeMarks.at(-1)?.creaseId;
        const svg = renderFolded(currentScene, {
          theme: WEB_THEME,
          step: String(stmt.frameIndex),
          markOverlay: activeMarks.length > 0 ? { marks: activeMarks, newestCreaseId } : undefined,
        }).toString();
```

- [ ] **Step 2: Typecheck the www package**

Run: `cd packages/www && bunx astro check` (or check `package.json` for an existing `"check"`/`"typecheck"` script and prefer that)
Expected: no errors — confirms `activeMarks: Mark[]` and the `MarkOverlay` shape line up with `render-folded.ts`'s updated type from Task 1.

- [ ] **Step 3: Manual browser verification**

There's no automated test harness for `Playground.astro` (confirmed in the prior statement-sourcemap plan — same convention applies here). Verify by hand:

Run: `cd packages/www && bun run dev` (or the package's existing dev script — check `package.json`)

In the browser, paste a `.bel` source with 3+ marks before any fold, e.g.:

```
paper square
mark --hm = map .a onto .d
mark --vm = map .a onto .b
mark --v34 = map .b onto .vm
```

Run it, then:
1. Click through the scrubber dots left to right — confirm marks accumulate (step 2 shows marks 1+2, step 3 shows marks 1+2+3), and the most recently added mark is drawn in the indigo accent color at full opacity while earlier marks stay dashed/translucent.
2. Click backward (e.g. from step 3 back to step 1) — confirm only that step's marks-so-far show, no stale marks from step 3 linger.

- [ ] **Step 4: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "feat(playground): scrubber shows cumulative marks, newest highlighted"
```

---

## Self-Review Notes

- **Spec coverage:** `MarkOverlay` type change (Task 1, Steps 4/6), highlight styling (Task 1, Step 5), cumulative-list construction (Task 2, Step 1), out-of-scope flat CP view (untouched by both tasks) — all spec sections have a task. Graduation filtering was dropped mid-implementation (see Task 2 note) — spec doc updated to match.
- **Type consistency:** `MarkOverlay` declared once in `render-scene.ts` (Task 1, Step 4), imported into `render-folded.ts` (Task 1, Step 6) and used structurally in `Playground.astro` (Task 2, Step 1, via `renderFolded`'s exported option type) — no duplicate/divergent definitions.
- **No placeholders:** every step has literal code; manual-verification step (Task 2, Step 3) is explicit because no automated harness exists for `.astro` files in this repo, matching the prior statement-sourcemap plan's precedent.
