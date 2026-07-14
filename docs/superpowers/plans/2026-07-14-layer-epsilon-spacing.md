# Layer ε-Spacing (Exploded Folded View) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the folded SVG view a per-layer ε-offset so stacked coplanar faces fan slightly and read as paper thickness (the stacked edge becomes visible).

**Architecture:** Compute a physical layer height per face (`faceDepth`) once in the scene model from `faceOrders` (which already *is* the overlap graph — no new polygon geometry). The 2D SVG folded backend shifts each face + its creases by `explode · faceDepth · (+1, −1)` screen px. Field is provisioned for a future three.js backend to read as `z`.

**Tech Stack:** TypeScript + Bun (`bun:test`), workspaces `@beloch/scene` (data model) and `@beloch/render-svg` (SVG backend).

## Global Constraints

- All new code is TypeScript, ESM, `bun:test` for tests. Run tests with `bun test` inside the relevant package dir.
- `faceOrders` is the sole overlap signal — do **not** add polygon-intersection geometry. A stacked overlapping pair is assumed always present in `faceOrders`; if omitted, depth undercounts there (acceptable, matches FOLD semantics).
- Depth metric = **local overlap depth** (longest chain of overlapping faces below), never the global paint index.
- Offset direction is fixed screen-space up-right `(+ε, −ε)`; default `ε = 1.5` px, **default-on**. `explode: 0` restores exact previous output.
- Occlusion (`coveredIntervals`) stays computed in true (unshifted) coordinates.

## File Structure

- `render/scene/src/topology.ts` — **new.** Pure face-topology/orientation helpers relocated from render-svg (`linearExtension`, `sideUp`, `signedArea`) plus `computeFaceDepth`.
- `render/scene/src/index.ts` — export the new module.
- `render/scene/src/types.ts` — add `faceDepth: number[]` to `Frame`.
- `render/scene/src/parse.ts` — populate `faceDepth` in `frameFrom`.
- `render/scene/test/topology.test.ts` — **new.** Unit test for `faceDepth`.
- `render/render-svg/src/geometry.ts` — remove the three relocated helpers.
- `render/render-svg/src/render-folded.ts` — import helpers from `@beloch/scene`; add `explode` option + per-face offset; `layerShadow` `dy` → 0.
- `render/render-svg/test/render-folded.test.ts` — add explode assertions.

---

### Task 1: Relocate topology helpers into `@beloch/scene`

Pure refactor, no behavior change. `linearExtension`/`sideUp` are used only by `render-folded.ts`; `signedArea` only by `sideUp`. Guarded by the existing test suites staying green.

**Files:**
- Create: `render/scene/src/topology.ts`
- Modify: `render/scene/src/index.ts`
- Modify: `render/render-svg/src/geometry.ts` (delete lines 6–42 `linearExtension`, 70–82 `signedArea`+`sideUp`)
- Modify: `render/render-svg/src/render-folded.ts:10` (import site)

**Interfaces:**
- Produces: `linearExtension(faceOrders: FaceOrder[], nFaces: number, faceUp?: boolean[]): number[]`, `sideUp(poly: Vec2[]): "front" | "back"`, `signedArea(poly: Vec2[]): number` — all exported from `@beloch/scene`.

- [ ] **Step 1: Create `render/scene/src/topology.ts`** with the three helpers moved verbatim (types come from `./types`, not `@beloch/scene`):

```ts
import type { FaceOrder, Vec2 } from "./types";

// Topologically sort faces into a bottom->top order consistent with faceOrders.
// [f,g,s]: s=+1 => f above g (edge g->f), s=-1 => f below g (edge f->g).
export function linearExtension(
  faceOrders: FaceOrder[],
  nFaces: number,
  faceUp?: boolean[],
): number[] {
  const adj: number[][] = Array.from({ length: nFaces }, () => []);
  const indeg = new Array(nFaces).fill(0);
  const addEdge = (lo: number, hi: number) => { adj[lo]!.push(hi); indeg[hi]++; }; // lo below hi
  // FOLD's faceOrders sign is relative to g's NORMAL, not global +z:
  // [f,g,+1] means f lies on the side g's normal points to. So f is globally
  // BELOW g iff (s < 0) === gUp, where gUp = g faces up (front side up, i.e.
  // det_sign > 0 ⇔ folded winding CCW). faceUp[g] carries that; when omitted
  // (all faces up) the sign reads as plain global order.
  for (const [f, g, s] of faceOrders || []) {
    if (s === 0) continue;
    const gUp = faceUp ? faceUp[g] : true;
    if ((s < 0) === gUp) addEdge(f, g); // f below g
    else addEdge(g, f);                 // g below f
  }
  const queue: number[] = [];
  for (let i = 0; i < nFaces; i++) if (indeg[i] === 0) queue.push(i);
  queue.sort((a, b) => a - b); // deterministic tie-break
  const order: number[] = [];
  while (queue.length) {
    const n = queue.shift()!;
    order.push(n);
    for (const m of adj[n]!) if (--indeg[m] === 0) {
      let k = queue.length;
      while (k > 0 && queue[k - 1]! > m) k--;
      queue.splice(k, 0, m);
    }
  }
  return order;
}

// Shoelace signed area; >0 = CCW (front side up in folded coords).
export function signedArea(poly: Vec2[]): number {
  let s = 0;
  for (let i = 0; i < poly.length; i++) {
    const [x1, y1] = poly[i]!, [x2, y2] = poly[(i + 1) % poly.length]!;
    s += x1 * y2 - x2 * y1;
  }
  return s / 2;
}

export function sideUp(poly: Vec2[]): "front" | "back" {
  return signedArea(poly) >= 0 ? "front" : "back";
}
```

- [ ] **Step 2: Export from `render/scene/src/index.ts`** — add the line:

```ts
export * from "./topology";
```

- [ ] **Step 3: Delete the relocated helpers from `render/render-svg/src/geometry.ts`.** Remove `linearExtension` (the `export function linearExtension...` block through its closing `}`), and `signedArea` + `sideUp` (both `export function` blocks). Leave `faceEdgeIndex`, `lineToFace`, `pointInPolygon`, `segInsideIntervals`, `coveredIntervals`, `clipLineBox`, `clipLineToPoly` untouched. The top-of-file `import type { FaceOrder, ... } from "@beloch/scene"` stays (still used by `coveredIntervals`/`lineToFace`).

- [ ] **Step 4: Fix the import in `render/render-svg/src/render-folded.ts:10`.** Change:

```ts
import { coveredIntervals, faceEdgeIndex, linearExtension, sideUp } from "./geometry";
```
to:
```ts
import { coveredIntervals, faceEdgeIndex } from "./geometry";
import { linearExtension, sideUp } from "@beloch/scene";
```

- [ ] **Step 5: Run both suites to verify no behavior change.**

Run: `cd render/scene && bun test` then `cd ../render-svg && bun test`
Expected: PASS (all existing tests green; the move is behavior-preserving).

- [ ] **Step 6: Commit**

```bash
git add render/scene/src/topology.ts render/scene/src/index.ts render/render-svg/src/geometry.ts render/render-svg/src/render-folded.ts
git commit -m "refactor(scene): relocate face topology helpers from render-svg"
```

---

### Task 2: Add `faceDepth` to the scene model

**Files:**
- Modify: `render/scene/src/types.ts` (add field to `Frame`)
- Modify: `render/scene/src/topology.ts` (add `computeFaceDepth`)
- Modify: `render/scene/src/parse.ts` (populate in `frameFrom`)
- Test: `render/scene/test/topology.test.ts` (new)

**Interfaces:**
- Consumes: `linearExtension`, `sideUp` from Task 1.
- Produces: `computeFaceDepth(facesVertices: number[][], vertices: Vec2[], faceOrders: FaceOrder[]): number[]`; `Frame.faceDepth: number[]` (length = `facesVertices.length`; all `0` when `faceOrders` is empty, e.g. the CP frame).

- [ ] **Step 1: Write the failing test** in `render/scene/test/topology.test.ts`:

```ts
import { test, expect } from "bun:test";
import { parseFold } from "@beloch/scene";

const golden = (p: string) =>
  Bun.file(new URL(`./fixtures/${p}`, import.meta.url)).text();

test("faceDepth: quartered sheet is a full 4-layer stack", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const frame = scene.steps[scene.steps.length - 1]!.frame; // fully folded, 4 faces
  expect(frame.faceDepth.length).toBe(frame.facesVertices.length);
  // a quartered sheet stacks all four faces: depths are a permutation of 0..3
  expect([...frame.faceDepth].sort((a, b) => a - b)).toEqual([0, 1, 2, 3]);
});

test("faceDepth: CP frame (no faceOrders) is all zeros", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  expect(scene.cp.faceDepth.every((d) => d === 0)).toBe(true);
  expect(scene.cp.faceDepth.length).toBe(scene.cp.facesVertices.length);
});
```

- [ ] **Step 2: Run the test to verify it fails.**

Run: `cd render/scene && bun test topology.test.ts`
Expected: FAIL — `frame.faceDepth` is `undefined` (`Cannot read properties of undefined (reading 'length')`).

- [ ] **Step 3: Add the field to `Frame`** in `render/scene/src/types.ts` (immediately after the `faceOrders` line):

```ts
  faceOrders: FaceOrder[];                                   // [] on the CP frame
  faceDepth: number[];                                       // layer height per face; parallel to facesVertices, 0 without faceOrders
```

- [ ] **Step 4: Add `computeFaceDepth` to `render/scene/src/topology.ts`** (append):

```ts
// Physical layer height per face: the longest chain of overlapping faces below
// it. faceOrders IS the overlap graph (a pair is recorded only for overlapping
// faces), so this needs no polygon geometry. Faces are oriented below->above by
// their position in linearExtension order (which already decodes faceOrders'
// normal-relative sign). Flat single-layer regions get depth 0.
export function computeFaceDepth(
  facesVertices: number[][],
  vertices: Vec2[],
  faceOrders: FaceOrder[],
): number[] {
  const n = facesVertices.length;
  if (n === 0) return [];
  const faceUp = facesVertices.map((f) => sideUp(f.map((i) => vertices[i]!)) === "front");
  const order = linearExtension(faceOrders, n, faceUp);
  const pos = new Array<number>(n);
  order.forEach((f, i) => { pos[f] = i; });
  const belowOf: number[][] = Array.from({ length: n }, () => []);
  for (const [f, g, s] of faceOrders) {
    if (s === 0) continue;
    const hi = pos[f]! < pos[g]! ? g : f;   // larger pos is above
    const lo = pos[f]! < pos[g]! ? f : g;
    belowOf[hi]!.push(lo);
  }
  const depth = new Array<number>(n).fill(0);
  for (const f of order) {                  // ascending pos => below already done
    let d = 0;
    for (const b of belowOf[f]!) d = Math.max(d, depth[b]! + 1);
    depth[f] = d;
  }
  return depth;
}
```

- [ ] **Step 5: Populate `faceDepth` in `frameFrom`** (`render/scene/src/parse.ts`). Add the import and compute the field. Change the import block at the top:

```ts
import {
  Assignment, Crease, EdgeProvenance, FoldScene, Frame, LineCoeffs,
  Mark, NamedLine, NamedPoint, SceneError, Step, StepNotFoundError, Vec2,
} from "./types";
import { computeFaceDepth } from "./topology";
```

Then inside `frameFrom`, replace the `return { ... }` object's tail so `faceDepth` is computed from the locals. Replace:

```ts
    facesVertices: (raw["faces_vertices"] ?? []) as number[][],
    faceOrders: (raw["faceOrders"] ?? []) as Frame["faceOrders"],
    facesMatrix: (raw["beloch:faces_matrix"] ?? null) as Frame["facesMatrix"],
  };
```
with:
```ts
    facesVertices,
    faceOrders,
    faceDepth: computeFaceDepth(facesVertices, vertices, faceOrders),
    facesMatrix: (raw["beloch:faces_matrix"] ?? null) as Frame["facesMatrix"],
  };
```
and add these two `const`s just above the `return` (after the `vnames` line):
```ts
  const facesVertices = (raw["faces_vertices"] ?? []) as number[][];
  const faceOrders = (raw["faceOrders"] ?? []) as Frame["faceOrders"];
```

- [ ] **Step 6: Run the test to verify it passes.**

Run: `cd render/scene && bun test topology.test.ts`
Expected: PASS (both cases).

- [ ] **Step 7: Run the full scene suite** to confirm the new field didn't break existing parse tests.

Run: `cd render/scene && bun test`
Expected: PASS. If a whole-frame `toEqual` snapshot fails only because `faceDepth` was added, update that expectation to include the new field; do not change any other value.

- [ ] **Step 8: Commit**

```bash
git add render/scene/src/types.ts render/scene/src/topology.ts render/scene/src/parse.ts render/scene/test/topology.test.ts
git commit -m "feat(scene): faceDepth per-face layer height from faceOrders"
```

---

### Task 3: ε-offset in the folded SVG backend

**Files:**
- Modify: `render/render-svg/src/render-folded.ts`
- Test: `render/render-svg/test/render-folded.test.ts`

**Interfaces:**
- Consumes: `frame.faceDepth` from Task 2.
- Produces: `FoldedOptions.explode?: number` (default `1.5`; `0` = no offset). Face polygons carry `data-face-index`; a face with `faceDepth d` is shifted by `(explode·d, −explode·d)` in screen px.

- [ ] **Step 1: Write the failing test** — append to `render/render-svg/test/render-folded.test.ts`:

```ts
test("explode offsets stacked faces up-right; explode:0 does not", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  const frame = scene.steps[scene.steps.length - 1]!.frame;
  const topFace = frame.faceDepth.indexOf(Math.max(...frame.faceDepth)); // deepest layer

  const facePoints = (svg: string, fi: number): [number, number] => {
    const m = svg.match(
      new RegExp(`<polygon points="([^"]+)"[^>]*data-face-index="${fi}"`),
    );
    if (!m) throw new Error(`face ${fi} not found`);
    const [x, y] = m[1]!.split(" ")[0]!.split(",").map(Number);
    return [x!, y!];
  };

  const flat = renderFolded(scene, { explode: 0 }).toString();
  const fanned = renderFolded(scene, { explode: 1.5 }).toString();

  const [fx, fy] = facePoints(flat, topFace);
  const [gx, gy] = facePoints(fanned, topFace);
  const d = frame.faceDepth[topFace]!; // 3 for a quartered sheet
  expect(gx - fx).toBeCloseTo(1.5 * d, 6);   // +x
  expect(gy - fy).toBeCloseTo(-1.5 * d, 6);  // -y (up)
});

test("explode:0 reproduces the un-exploded baseline snapshot", async () => {
  const scene = parseFold(await golden("fold-quarter.fold"));
  expect(renderFolded(scene, { explode: 0 }).toString()).toMatchSnapshot();
});
```

- [ ] **Step 2: Run the test to verify it fails.**

Run: `cd render/render-svg && bun test render-folded.test.ts`
Expected: FAIL — with the default offset not yet implemented, `explode: 1.5` produces no shift (`gx-fx` is `0`, not `4.5`).

- [ ] **Step 3: Add the `explode` option** to `FoldedOptions` in `render/render-svg/src/render-folded.ts` (after the `step?` line):

```ts
  step?: string;               // beloch:step label; undefined/unmatched → final state
  explode?: number;            // per-layer ε-offset in px; default 1.5, 0 = flat
```

- [ ] **Step 4: Add the per-face shift helper** just after `const paint = ...` (around line 59) in `renderFolded`:

```ts
  const explode = opts.explode ?? 1.5;
  // up-right, toward the layerShadow light, so stagger and shadow agree
  const shift = (fi: number): [number, number] => {
    const d = frame.faceDepth[fi] ?? 0;
    return [explode * d, -explode * d];
  };
```

- [ ] **Step 5: Offset each face polygon.** In the `for (const fi of paint)` loop, replace the `pts` line:

```ts
    const pts = face.map((i) => `${mx(V[i]![0])},${ty(V[i]![1])}`).join(" ");
```
with:
```ts
    const [dx, dy] = shift(fi);
    const pts = face.map((i) => `${mx(V[i]![0]) + dx},${ty(V[i]![1]) + dy}`).join(" ");
```

- [ ] **Step 6: Offset creases by their topmost incident face's depth.** In the `E.forEach((e, i) => {...})` block, after `const covered = coveredIntervals(...)` add the crease shift, and apply it to both the visible and dashed `lerp` outputs. Insert after the `lerp` definition (line ~125):

```ts
    const topFace = faces.reduce((p, q) => (frame.faceDepth[q]! > frame.faceDepth[p]! ? q : p));
    const [edx, edy] = shift(topFace);
```
Then in the visible loop change the two coordinate expressions:
```ts
      x1: mx(p0[0]) + edx, y1: ty(p0[1]) + edy, x2: mx(p1[0]) + edx, y2: ty(p1[1]) + edy,
```
and in the `if (opts.hidden === "dashed")` loop, the same:
```ts
          x1: mx(p0[0]) + edx, y1: ty(p0[1]) + edy, x2: mx(p1[0]) + edx, y2: ty(p1[1]) + edy,
```

- [ ] **Step 7: Offset phantom edges by their owning face's depth.** In the `for (const { a, b, fi } of phantom)` loop, add after `const refPos = pos.get(fi)!;`:

```ts
    const [pdx, pdy] = shift(fi);
```
and apply `+ pdx` / `+ pdy` to the `x1/y1/x2/y2` in both the solid `creases.children.push(el("line", {...}))` and the dashed `dashedLines.push(el("line", {...}))` calls in that loop, mirroring Step 6.

- [ ] **Step 8: Soften the shadow.** The real offset now carries depth, so change `layerShadow`'s `dy` from `1` to `0` (line ~38):

```ts
        dx: 0, dy: 0, stdDeviation: 1.1, "flood-color": "#0f172a", "flood-opacity": 0.18,
```

- [ ] **Step 9: Run the new tests.** Write the baseline snapshot on first run.

Run: `cd render/render-svg && bun test render-folded.test.ts`
Expected: the offset test PASSES; the snapshot test writes a new baseline (green). Re-run once more — Expected: PASS (snapshot now stable).

- [ ] **Step 10: Regenerate the default-on folded snapshots.** The default `explode: 1.5` changes coordinates in every folded render that doesn't pass `explode: 0`.

Run: `cd render/render-svg && bun test --update-snapshots`
Then: `bun test`
Expected: PASS. Inspect the snapshot diff (`git diff render/render-svg/test/__snapshots__/`) — only coordinate values shift; element counts, colors, and `data-*` attributes are unchanged.

- [ ] **Step 11: Commit**

```bash
git add render/render-svg/src/render-folded.ts render/render-svg/test/render-folded.test.ts render/render-svg/test/__snapshots__/
git commit -m "feat(render-svg): ε-spacing between folded layers (explode, default on)"
```

---

## Notes on deviations from the design doc

- **Coordinate offset instead of `<g transform>` bands.** The design sketched per-depth `<g transform=translate>` groups. The backend keeps faces and creases as two flat CSS-toggleable layers (`render-folded.ts:66-73`); nesting depth-`<g>`s inside would fight that structure. Directly adding the offset to each element's coordinates yields identical geometry while preserving the layer split. Same visual result, smaller structural change.
- **Annotations (named-vertex dots/labels) are not offset.** A vertex can belong to faces at different depths; at ε ≈ 1.5px leaving them at true coordinates is visually negligible and avoids per-vertex face-membership bookkeeping. Revisit only if labels visibly detach.

## Self-Review

- **Spec coverage:** `faceDepth` field (Task 2) ✓; overlap-DAG-from-faceOrders depth, no new geometry (Task 2 `computeFaceDepth`) ✓; helper relocation to scene (Task 1) ✓; `explode` default-on 1.5, `(+ε,−ε)`, creases glued (Task 3) ✓; `layerShadow` dy→0 (Task 3 Step 8) ✓; occlusion in true coords (unchanged — `coveredIntervals` untouched) ✓; scene unit test + snapshot (Tasks 2/3) ✓; goldens regenerated (Task 3 Step 10) ✓.
- **Placeholder scan:** none — all steps carry concrete code/commands.
- **Type consistency:** `computeFaceDepth(facesVertices, vertices, faceOrders)` and `Frame.faceDepth: number[]` used consistently across Tasks 2 & 3; `shift(fi)` returns `[number, number]` everywhere.
