# fold2svg Occlusion View + Aesthetic Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `tools/fold2svg.mjs`'s folded render occlusion-correct — only the topmost paper layer is drawn at each point, front/back sides are colour-distinguished, hidden creases can be dashed — plus a bounded aesthetic pass, so PR screenshots read like real folded models.

**Architecture:** Pure TypeScript-edge change (ADR 0001); no OCaml. Everything comes from the already-emitted foldedForm frame (`faceOrders`, folded `vertices_coords`, inherited `faces_vertices`/`edges_*`/`beloch:edges`). The CLI body is wrapped in an `import.meta.main` guard so pure helpers can be unit-tested. Occlusion is a painter's algorithm: linear-extend the `faceOrders` partial order to a bottom→top total order, paint faces opaque in that order so higher layers overwrite lower ones.

**Tech Stack:** Bun (runtime + `bun test`), hand-rolled SVG strings, Rabbit Ear (FOLD-load sanity check only), `@resvg/resvg-js` (PNG).

## Global Constraints

- Runtime is **Bun** (`#!/usr/bin/env bun`); tests run with `bun test`. Copied verbatim from spec.
- **No OCaml change** — read only what the foldedForm frame already emits.
- Rabbit Ear stays **only** as the FOLD-load check (`ear.graph(fold)`); it draws nothing.
- Preserve existing `--title`, output-path, and `.png` handling so the curl-assets PR-screenshot pipeline keeps working.
- `--folded` becomes equivalent to `--view top` (the old mushy silhouette had no value).
- The crease-pattern render (frame 0) keeps its geometry; only its typography/legend get the aesthetic polish.
- Faces are painted **opaque**; a flat fold's overlapping faces are totally ordered (guaranteed by the #21 tortilla-tortilla acyclicity guard), so a consistent linear extension always exists.

---

### Task 1: Occlusion top view — helpers, `import.meta.main` guard, painter's algorithm

Replace the all-layers-superimposed folded render with an opaque painter's-algorithm top view. Extract pure helpers and guard the CLI so helpers are importable by tests. `--view top` and `--folded` both select this render.

**Files:**
- Modify: `tools/fold2svg.mjs` (whole file — wrap execution in `import.meta.main`, add exports + occlusion render)
- Create: `tools/test/fixtures/fold-quarter.fold`, `tools/test/fixtures/fold-half.fold` (generated)
- Create: `tools/test/foldview.test.mjs`

**Interfaces:**
- Produces:
  - `export function linearExtension(faceOrders, nFaces)` → `number[]` (face indices bottom→top; respects every `[f,g,s]`: `s===1` ⇒ f above g, `s===-1` ⇒ f below g)
  - `export function faceEdgeIndex(F)` → `Map<string,number>` mapping `"a-b"` (sorted vertex pair) → edge index, built from `edges_vertices` (passed in; see code)
  - `export function foldedFrame(fold)` → the merged foldedForm frame object (parent ⊕ `file_frames[0]`)

- [ ] **Step 1: Generate test fixtures**

Run:
```bash
mkdir -p tools/test/fixtures
dune exec beloch -- fold examples/fold-quarter.bel > tools/test/fixtures/fold-quarter.fold
dune exec beloch -- fold examples/fold-half.bel   > tools/test/fixtures/fold-half.fold
```
Expected: two `.fold` JSON files written (fold-quarter has 4 faces / 6 faceOrders, fold-half 2 / 1).

- [ ] **Step 2: Write the failing test for `linearExtension`**

Create `tools/test/foldview.test.mjs`:
```javascript
import { test, expect } from "bun:test";
import { linearExtension, foldedFrame } from "../fold2svg.mjs";

const quarter = JSON.parse(
  await Bun.file(new URL("./fixtures/fold-quarter.fold", import.meta.url)).text()
);

test("linearExtension respects every faceOrders pair", () => {
  const ff = foldedFrame(quarter);
  const nF = (quarter.faces_vertices || []).length;
  const order = linearExtension(ff.faceOrders, nF);
  // bottom->top: every face appears exactly once
  expect([...order].sort((a, b) => a - b)).toEqual(
    Array.from({ length: nF }, (_, i) => i)
  );
  const pos = new Map(order.map((f, i) => [f, i]));
  for (const [f, g, s] of ff.faceOrders) {
    if (s === 1) expect(pos.get(f)).toBeGreaterThan(pos.get(g)); // f above g
    if (s === -1) expect(pos.get(f)).toBeLessThan(pos.get(g)); // f below g
  }
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bun test tools/test/foldview.test.mjs`
Expected: FAIL — `linearExtension`/`foldedFrame` are not exported yet (import error).

- [ ] **Step 4: Rewrite `tools/fold2svg.mjs` — exports + guard + occlusion render**

Replace the entire file with:
```javascript
#!/usr/bin/env bun
// Render a Beloch FOLD file to a labelled SVG/PNG diagram.
// Rabbit Ear validates that the FOLD loads (the ADR-0009 consumer); the diagram
// itself is drawn here for full control over strokes, padding, and labels.
// Usage:
//   bun tools/fold2svg.mjs input.fold [out.svg|out.png] [--title "..."]
//   bun tools/fold2svg.mjs f.fold --view top|bottom [--hidden dashed|hide]
//   beloch fold f.bel | bun tools/fold2svg.mjs - out.png --title f.bel
import ear from "rabbit-ear";

// ---- pure helpers (exported for tests) ------------------------------------

// Merge the foldedForm frame (file_frames[0]) over its parent: the folded frame
// overrides vertices_coords + faceOrders and inherits topology from the parent.
export function foldedFrame(fold) {
  const ff = (fold.file_frames || [])[0];
  return ff ? { ...fold, ...ff } : fold;
}

// Topologically sort faces into a bottom->top order consistent with faceOrders.
// [f,g,s]: s=+1 => f above g (edge g->f), s=-1 => f below g (edge f->g).
export function linearExtension(faceOrders, nFaces) {
  const adj = Array.from({ length: nFaces }, () => []);
  const indeg = new Array(nFaces).fill(0);
  const addEdge = (lo, hi) => { adj[lo].push(hi); indeg[hi]++; }; // lo below hi
  for (const [f, g, s] of faceOrders || []) {
    if (s === 1) addEdge(g, f);
    else if (s === -1) addEdge(f, g);
  }
  const queue = [];
  for (let i = 0; i < nFaces; i++) if (indeg[i] === 0) queue.push(i);
  queue.sort((a, b) => a - b); // deterministic tie-break
  const order = [];
  while (queue.length) {
    const n = queue.shift();
    order.push(n);
    for (const m of adj[n]) if (--indeg[m] === 0) {
      // insert keeping ascending index among ready nodes (stable, deterministic)
      let k = queue.length;
      while (k > 0 && queue[k - 1] > m) k--;
      queue.splice(k, 0, m);
    }
  }
  return order;
}

// "a-b" key (sorted) -> edge index, for mapping a face outline segment to a
// FOLD edge (to recover its colour/assignment).
export function faceEdgeIndex(edgesVertices) {
  const m = new Map();
  (edgesVertices || []).forEach(([a, b], i) => {
    m.set(a < b ? `${a}-${b}` : `${b}-${a}`, i);
  });
  return m;
}

// ---- CLI ------------------------------------------------------------------

if (import.meta.main) {
  const args = process.argv.slice(2);
  const flagVal = (name) => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const title = flagVal("--title") || "";
  const viewFlag = args.includes("--folded") ? "top" : flagVal("--view"); // top|bottom
  const FLAGS = new Set(["--title", "--view", "--hidden"]);
  const positional = args.filter(
    (a, i) => !a.startsWith("--") && !FLAGS.has(args[i - 1])
  );
  const [inPath, outPath] = positional;

  const raw =
    !inPath || inPath === "-" ? await Bun.stdin.text() : await Bun.file(inPath).text();
  const fold = JSON.parse(raw);
  ear.graph(fold); // throws if the FOLD is not loadable — keep this as a check

  const frame = viewFlag ? foldedFrame(fold) : fold;
  const V = frame.vertices_coords;
  const E = frame.edges_vertices || [];
  const F = frame.faces_vertices || [];
  const A = frame.edges_assignment || [];
  const prov = frame["beloch:edges"] || [];

  // layout: unit-ish coords -> a padded px canvas, y flipped (math up -> svg down)
  const PAD = 56, SZ = 460, W = SZ + 2 * PAD, H = SZ + 2 * PAD;
  const xs = V.map((p) => p[0]), ys = V.map((p) => p[1]);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  const span = Math.max(maxX - minX, maxY - minY) || 1;
  const tx = (x) => PAD + ((x - minX) / span) * SZ;
  const ty = (y) => PAD + (1 - (y - minY) / span) * SZ;

  const AX = {
    axiom1: { c: "#2563eb", n: "axiom 1 · through" },
    axiom2: { c: "#16a34a", n: "axiom 2 · map onto" },
    axiom3: { c: "#db2777", n: "axiom 3 · perp" },
    axiom4: { c: "#ea580c", n: "axiom 4 · project" },
    axiom5: { c: "#9333ea", n: "axiom 5 · map onto" },
    axiom6: { c: "#0d9488", n: "axiom 6 · map through" },
    axiom7: { c: "#7c3aed", n: "axiom 7 · map onto + onto" },
  };
  const CREASE = "#f59e0b";
  const eColor = (i) => {
    if (A[i] === "B") return "#1f2937";
    const ax = prov[i] && prov[i].axiom;
    return (AX[ax] && AX[ax].c) || CREASE;
  };

  const near = (p, x, y) => Math.abs(p[0] - x) < 1e-6 && Math.abs(p[1] - y) < 1e-6;
  const CORNER = [[0, 0, "a"], [1, 0, "b"], [1, 1, "c"], [0, 1, "d"]];
  const cornerLabel = (p) => (CORNER.find(([x, y]) => near(p, x, y)) || [])[2];

  const out = [];
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="ui-sans-serif, system-ui, sans-serif">`);
  out.push(`<rect width="${W}" height="${H}" fill="white"/>`);

  if (viewFlag) {
    // ---- occlusion view: paint faces bottom->top, opaque -----------------
    const order = linearExtension(frame.faceOrders || [], F.length);
    const edgeIx = faceEdgeIndex(E);
    for (const fi of order) {
      const face = F[fi];
      const pts = face.map((i) => `${tx(V[i][0])},${ty(V[i][1])}`).join(" ");
      // opaque paper fill (single tone this task; front/back tint = Task 2)
      out.push(`<polygon points="${pts}" fill="#f8fafc" stroke="none"/>`);
      // this face's outline edges, coloured by their FOLD edge assignment
      for (let k = 0; k < face.length; k++) {
        const a = face[k], b = face[(k + 1) % face.length];
        const ei = edgeIx.get(a < b ? `${a}-${b}` : `${b}-${a}`);
        const col = ei === undefined ? CREASE : eColor(ei);
        const wgt = ei !== undefined && A[ei] === "B" ? 2.5 : 2;
        out.push(`<line x1="${tx(V[a][0])}" y1="${ty(V[a][1])}" x2="${tx(V[b][0])}" y2="${ty(V[b][1])}" stroke="${col}" stroke-width="${wgt}" stroke-linecap="round"/>`);
      }
    }
  } else {
    // ---- crease-pattern (frame 0): unchanged -----------------------------
    for (const f of F) {
      const pts = f.map((i) => `${tx(V[i][0])},${ty(V[i][1])}`).join(" ");
      out.push(`<polygon points="${pts}" fill="#f8fafc" stroke="none"/>`);
    }
    E.forEach((e, i) => {
      const [a, b] = e;
      const boundary = A[i] === "B";
      out.push(`<line x1="${tx(V[a][0])}" y1="${ty(V[a][1])}" x2="${tx(V[b][0])}" y2="${ty(V[b][1])}" stroke="${eColor(i)}" stroke-width="${boundary ? 2.5 : 2}" stroke-linecap="round"/>`);
    });
    V.forEach((p) => {
      out.push(`<circle cx="${tx(p[0])}" cy="${ty(p[1])}" r="3" fill="#0f172a"/>`);
      const lab = cornerLabel(p);
      if (lab) {
        const ox = p[0] < 0.5 ? -16 : 10, oy = p[1] < 0.5 ? 18 : -8;
        out.push(`<text x="${tx(p[0]) + ox}" y="${ty(p[1]) + oy}" font-size="17" font-weight="600" fill="#0f172a">.${lab}</text>`);
      }
    });
    const B_EPS = 1e-6;
    const onB = (p) =>
      Math.abs(p[0] - minX) < B_EPS || Math.abs(p[0] - maxX) < B_EPS ||
      Math.abs(p[1] - minY) < B_EPS || Math.abs(p[1] - maxY) < B_EPS;
    const creases = {};
    E.forEach((e, i) => {
      const nm = prov[i] && prov[i].name;
      if (!nm) return;
      if (!creases[nm]) creases[nm] = { vs: new Set(), col: eColor(i) };
      creases[nm].vs.add(e[0]);
      creases[nm].vs.add(e[1]);
    });
    for (const [nm, { vs, col }] of Object.entries(creases)) {
      const list = [...vs];
      let ends = list.filter((j) => onB(V[j]));
      if (ends.length < 2) {
        let best = [list[0], list[0]], bd = -1;
        for (const a of list) for (const b of list) {
          const d = (V[a][0] - V[b][0]) ** 2 + (V[a][1] - V[b][1]) ** 2;
          if (d > bd) { bd = d; best = [a, b]; }
        }
        ends = best;
      }
      const P = V[ends[0]], C = V[ends[1]], t = 0.18;
      const px = tx(P[0] + (C[0] - P[0]) * t), py = ty(P[1] + (C[1] - P[1]) * t);
      out.push(`<text x="${px}" y="${py}" font-size="13" font-weight="600" fill="${col}" stroke="white" stroke-width="3" paint-order="stroke" text-anchor="middle" dominant-baseline="middle">--${nm}</text>`);
    }
  }

  // title
  if (title) out.push(`<text x="${PAD}" y="28" font-size="16" font-weight="700" fill="#0f172a">${title}</text>`);
  // legend (axioms present in this diagram)
  const present = [...new Set(prov.filter(Boolean).map((p) => p.axiom))].filter((a) => AX[a]);
  present.forEach((ax, k) => {
    const lx = PAD + k * 150;
    out.push(`<line x1="${lx}" y1="${H - 22}" x2="${lx + 22}" y2="${H - 22}" stroke="${AX[ax].c}" stroke-width="3" stroke-linecap="round"/>`);
    out.push(`<text x="${lx + 28}" y="${H - 17}" font-size="13" fill="#334155">${AX[ax].n}</text>`);
  });
  out.push(`</svg>`);
  let svg = out.join("\n");

  if (outPath && outPath.endsWith(".png")) {
    const { Resvg } = await import("@resvg/resvg-js");
    const png = new Resvg(svg, { background: "white", fitTo: { mode: "width", value: W } }).render().asPng();
    await Bun.write(outPath, png);
  } else if (outPath) await Bun.write(outPath, svg);
  else process.stdout.write(svg);
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bun test tools/test/foldview.test.mjs`
Expected: PASS (1 test).

- [ ] **Step 6: Manually verify the render regressed nothing and occludes**

Run:
```bash
dune exec beloch -- fold examples/fold-quarter.bel | bun tools/fold2svg.mjs - /tmp/q-cp.png --title "quarter CP"
dune exec beloch -- fold examples/fold-quarter.bel | bun tools/fold2svg.mjs - /tmp/q-top.png --view top --title "quarter top"
```
Expected: both PNGs write with no error. `q-top.png` shows a single opaque top layer (not the old superimposed mush).

- [ ] **Step 7: Commit**

```bash
git add tools/fold2svg.mjs tools/test/foldview.test.mjs tools/test/fixtures/fold-quarter.fold tools/test/fixtures/fold-half.fold
git commit -m "feat(fold2svg): occlusion-correct top view via painter's over faceOrders"
```

---

### Task 2: Front/back side tinting + bottom view

Colour the paper by which side faces up, and add `--view bottom` (view from below = reverse paint order + horizontal mirror).

**Files:**
- Modify: `tools/fold2svg.mjs` (add `signedArea`/`sideUp` exports; tint fills; mirror + reverse for bottom)
- Modify: `tools/test/foldview.test.mjs` (add tests)

**Interfaces:**
- Consumes: `linearExtension`, `foldedFrame` (Task 1)
- Produces:
  - `export function signedArea(poly)` → `number` (poly is `[x,y][]`; shoelace, >0 = CCW)
  - `export function sideUp(poly)` → `"front" | "back"` (CCW ⇒ front, CW ⇒ back)

- [ ] **Step 1: Write failing tests for `signedArea` / `sideUp`**

Append to `tools/test/foldview.test.mjs`:
```javascript
import { signedArea, sideUp } from "../fold2svg.mjs";

test("signedArea is positive for a CCW square, negative reversed", () => {
  const ccw = [[0, 0], [1, 0], [1, 1], [0, 1]];
  expect(signedArea(ccw)).toBeGreaterThan(0);
  expect(signedArea([...ccw].reverse())).toBeLessThan(0);
});

test("sideUp maps winding to front/back", () => {
  expect(sideUp([[0, 0], [1, 0], [1, 1], [0, 1]])).toBe("front");
  expect(sideUp([[0, 0], [0, 1], [1, 1], [1, 0]])).toBe("back");
});

test("fold-quarter top view has both a front and a back face", () => {
  const ff = foldedFrame(quarter);
  const V = ff.vertices_coords;
  const sides = (quarter.faces_vertices || []).map((f) =>
    sideUp(f.map((i) => V[i]))
  );
  expect(sides).toContain("front");
  expect(sides).toContain("back");
});
```

- [ ] **Step 2: Run to verify failure**

Run: `bun test tools/test/foldview.test.mjs`
Expected: FAIL — `signedArea`/`sideUp` not exported.

- [ ] **Step 3: Add the helpers**

In `tools/fold2svg.mjs`, in the pure-helpers section (after `faceEdgeIndex`), add:
```javascript
// Shoelace signed area; >0 = CCW (front side up in folded coords).
export function signedArea(poly) {
  let s = 0;
  for (let i = 0; i < poly.length; i++) {
    const [x1, y1] = poly[i], [x2, y2] = poly[(i + 1) % poly.length];
    s += x1 * y2 - x2 * y1;
  }
  return s / 2;
}

export function sideUp(poly) {
  return signedArea(poly) >= 0 ? "front" : "back";
}
```

- [ ] **Step 4: Tint fills + add bottom view in the CLI occlusion block**

In `tools/fold2svg.mjs`, replace the occlusion `if (viewFlag) { ... }` block's body with:
```javascript
    // ---- occlusion view: paint faces bottom->top, opaque -----------------
    const FRONT = "#fafaf7", BACK = "#dbe4ee"; // paper front / back tint
    const bottom = viewFlag === "bottom";
    // bottom view: look from below => reverse the stack and mirror x
    const mx = (x) => (bottom ? W - tx(x) : tx(x));
    const order = linearExtension(frame.faceOrders || [], F.length);
    const paint = bottom ? [...order].reverse() : order;
    const edgeIx = faceEdgeIndex(E);
    for (const fi of paint) {
      const face = F[fi];
      const poly = face.map((i) => V[i]);
      const fill = sideUp(poly) === "front" ? FRONT : BACK;
      const pts = face.map((i) => `${mx(V[i][0])},${ty(V[i][1])}`).join(" ");
      out.push(`<polygon points="${pts}" fill="${fill}" stroke="none"/>`);
      for (let k = 0; k < face.length; k++) {
        const a = face[k], b = face[(k + 1) % face.length];
        const ei = edgeIx.get(a < b ? `${a}-${b}` : `${b}-${a}`);
        const col = ei === undefined ? CREASE : eColor(ei);
        const wgt = ei !== undefined && A[ei] === "B" ? 2.5 : 2;
        out.push(`<line x1="${mx(V[a][0])}" y1="${ty(V[a][1])}" x2="${mx(V[b][0])}" y2="${ty(V[b][1])}" stroke="${col}" stroke-width="${wgt}" stroke-linecap="round"/>`);
      }
    }
```
Note: the `mx` helper replaces the bare `tx` for x in this block only; `ty` is unchanged. `sideUp` is computed on unmirrored coords so front/back is intrinsic to the paper, not the view.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bun test tools/test/foldview.test.mjs`
Expected: PASS (all tests).

- [ ] **Step 6: Manually verify top vs bottom**

Run:
```bash
dune exec beloch -- fold examples/fold-quarter.bel | bun tools/fold2svg.mjs - /tmp/q-top.png --view top
dune exec beloch -- fold examples/fold-quarter.bel | bun tools/fold2svg.mjs - /tmp/q-bot.png --view bottom
```
Expected: both write; `q-bot` is the horizontal mirror of `q-top` with front/back tints swapped where layers differ.

- [ ] **Step 7: Commit**

```bash
git add tools/fold2svg.mjs tools/test/foldview.test.mjs
git commit -m "feat(fold2svg): front/back side tinting + bottom (flipped) view"
```

---

### Task 3: Hidden-crease mode (`--hidden dashed|hide`)

Add an x-ray toggle: creases occluded by a higher face are either dropped (default `hide`, already the painter's behaviour) or redrawn dashed over the paper.

**Files:**
- Modify: `tools/fold2svg.mjs` (add `pointInPolygon`/`edgeCovered`; parse `--hidden`; dashed overpass)
- Modify: `tools/test/foldview.test.mjs`

**Interfaces:**
- Consumes: `linearExtension`, `foldedFrame` (Task 1)
- Produces:
  - `export function pointInPolygon(pt, poly)` → `boolean` (ray cast; `pt`=`[x,y]`, `poly`=`[x,y][]`)
  - `export function edgeCovered(mid, incidentMaxPos, order, F, V)` → `boolean` — true if any face strictly above position `incidentMaxPos` in `order` contains `mid`

- [ ] **Step 1: Write failing tests**

Append to `tools/test/foldview.test.mjs`:
```javascript
import { pointInPolygon, edgeCovered } from "../fold2svg.mjs";

test("pointInPolygon: inside vs outside a unit square", () => {
  const sq = [[0, 0], [1, 0], [1, 1], [0, 1]];
  expect(pointInPolygon([0.5, 0.5], sq)).toBe(true);
  expect(pointInPolygon([1.5, 0.5], sq)).toBe(false);
});

test("edgeCovered: a point under a higher face is covered", () => {
  // faces: 0 = lower square, 1 = higher square overlapping it
  const F = [[0, 1, 2, 3], [0, 1, 2, 3]];
  const V = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const order = [0, 1]; // 1 is above 0
  expect(edgeCovered([0.5, 0.5], 0, order, F, V)).toBe(true);  // face 1 above pos 0
  expect(edgeCovered([0.5, 0.5], 1, order, F, V)).toBe(false); // nothing above pos 1
});
```

- [ ] **Step 2: Run to verify failure**

Run: `bun test tools/test/foldview.test.mjs`
Expected: FAIL — `pointInPolygon`/`edgeCovered` not exported.

- [ ] **Step 3: Add the helpers**

In the pure-helpers section of `tools/fold2svg.mjs` (after `sideUp`), add:
```javascript
// Ray-casting point-in-polygon (boundary counts as inside is not required here).
export function pointInPolygon(pt, poly) {
  const [x, y] = pt;
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    const hit = (yi > y) !== (yj > y) &&
      x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
    if (hit) inside = !inside;
  }
  return inside;
}

// Is `mid` covered by a face strictly above `incidentMaxPos` in the stack order?
export function edgeCovered(mid, incidentMaxPos, order, F, V) {
  for (let pos = incidentMaxPos + 1; pos < order.length; pos++) {
    const fi = order[pos];
    if (pointInPolygon(mid, F[fi].map((i) => V[i]))) return true;
  }
  return false;
}
```

- [ ] **Step 4: Parse `--hidden` and add the dashed overpass**

In `tools/fold2svg.mjs` CLI section, after the `viewFlag` line add:
```javascript
  const hidden = flagVal("--hidden") || "hide"; // dashed | hide
```
Then, at the END of the occlusion `if (viewFlag) { ... }` block (after the paint loop, still inside the block), add the dashed overpass:
```javascript
    // x-ray: redraw occluded creases dashed over the paper
    if (hidden === "dashed") {
      const pos = new Map(order.map((f, i) => [f, i]));
      // incident faces per edge: faces whose outline contains the edge
      const incident = E.map(() => []);
      F.forEach((face, fi) => {
        for (let k = 0; k < face.length; k++) {
          const a = face[k], b = face[(k + 1) % face.length];
          const ei = edgeIx.get(a < b ? `${a}-${b}` : `${b}-${a}`);
          if (ei !== undefined) incident[ei].push(fi);
        }
      });
      E.forEach((e, i) => {
        if (A[i] === "B") return; // boundary edges are always on the silhouette
        const faces = incident[i];
        if (!faces.length) return;
        const maxPos = Math.max(...faces.map((fi) => pos.get(fi)));
        const [a, b] = e;
        const mid = [(V[a][0] + V[b][0]) / 2, (V[a][1] + V[b][1]) / 2];
        if (!edgeCovered(mid, maxPos, order, F, V)) return; // visible already
        out.push(`<line x1="${mx(V[a][0])}" y1="${ty(V[a][1])}" x2="${mx(V[b][0])}" y2="${ty(V[b][1])}" stroke="#94a3b8" stroke-width="1.2" stroke-dasharray="4 3" stroke-linecap="round"/>`);
      });
    }
```
Note: `edgeIx`, `order`, `mx` are already in scope from the paint loop in this block.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bun test tools/test/foldview.test.mjs`
Expected: PASS (all tests).

- [ ] **Step 6: Add an integration assertion for dashed output**

Append to `tools/test/foldview.test.mjs`:
```javascript
test("--hidden dashed emits a dashed stroke; hide does not", async () => {
  const run = (extra) =>
    new Promise((res) => {
      const p = Bun.spawn(
        ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/fold-quarter.fold", "--view", "top", ...extra],
        { stdout: "pipe" }
      );
      res(new Response(p.stdout).text());
    });
  const dashed = await run(["--hidden", "dashed"]);
  const hide = await run(["--hidden", "hide"]);
  expect((await dashed).includes("stroke-dasharray")).toBe(true);
  expect((await hide).includes("stroke-dasharray")).toBe(false);
});
```

- [ ] **Step 7: Run the integration test**

Run: `bun test tools/test/foldview.test.mjs`
Expected: PASS. (Run from repo root so the relative fixture path resolves.)

- [ ] **Step 8: Commit**

```bash
git add tools/fold2svg.mjs tools/test/foldview.test.mjs
git commit -m "feat(fold2svg): --hidden dashed|hide x-ray for occluded creases"
```

---

### Task 4: Aesthetic pass

Bounded polish: per-layer hairline drop-shadow, refined stroke weights, cleaner legend box + title, and the crease-pattern frame gets the same typography/legend treatment. Exact values are tuned against the rendered PNGs; the set is fixed by the spec.

**Files:**
- Modify: `tools/fold2svg.mjs`
- Modify: `tools/test/foldview.test.mjs`

**Interfaces:** none new (rendering-only changes).

- [ ] **Step 1: Write a failing test pinning the polish hooks**

Append to `tools/test/foldview.test.mjs`:
```javascript
test("occlusion view defines a soft layer shadow and a legend panel", async () => {
  const p = Bun.spawn(
    ["bun", "tools/fold2svg.mjs", "tools/test/fixtures/fold-quarter.fold", "--view", "top", "--title", "q"],
    { stdout: "pipe" }
  );
  const svg = await new Response(p.stdout).text();
  expect(svg.includes('id="layerShadow"')).toBe(true); // drop-shadow filter defined
  expect(svg.includes('class="legend-panel"')).toBe(true); // legend backing panel
});
```

- [ ] **Step 2: Run to verify failure**

Run: `bun test tools/test/foldview.test.mjs`
Expected: FAIL — no `layerShadow` filter / `legend-panel` yet.

- [ ] **Step 3: Add a `<defs>` shadow filter and apply it to layer fills**

In `tools/fold2svg.mjs`, right after the opening `<svg ...>` push and the white `<rect>`, add:
```javascript
  out.push(`<defs><filter id="layerShadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="1" stdDeviation="1.1" flood-color="#0f172a" flood-opacity="0.18"/></filter></defs>`);
```
Then in the occlusion paint loop, change the face-fill polygon push to reference the filter:
```javascript
      out.push(`<polygon points="${pts}" fill="${fill}" stroke="none" filter="url(#layerShadow)"/>`);
```

- [ ] **Step 4: Add a legend panel + title treatment**

In `tools/fold2svg.mjs`, replace the legend block (the `present.forEach(...)` loop and, if present, the preceding title push) with:
```javascript
  // title
  if (title) {
    out.push(`<rect x="${PAD - 10}" y="10" width="${title.length * 9 + 20}" height="26" rx="6" fill="#f1f5f9"/>`);
    out.push(`<text x="${PAD}" y="28" font-size="16" font-weight="700" fill="#0f172a">${title}</text>`);
  }
  // legend (axioms present in this diagram) with a soft backing panel
  const present = [...new Set(prov.filter(Boolean).map((p) => p.axiom))].filter((a) => AX[a]);
  if (present.length) {
    out.push(`<rect class="legend-panel" x="${PAD - 12}" y="${H - 38}" width="${present.length * 150 + 4}" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>`);
    present.forEach((ax, k) => {
      const lx = PAD + k * 150;
      out.push(`<line x1="${lx}" y1="${H - 25}" x2="${lx + 22}" y2="${H - 25}" stroke="${AX[ax].c}" stroke-width="3" stroke-linecap="round"/>`);
      out.push(`<text x="${lx + 28}" y="${H - 20}" font-size="13" fill="#334155">${AX[ax].n}</text>`);
    });
  }
```
Delete the old `if (title) ...` push and old `present.forEach(...)` block so the title/legend are emitted exactly once (here, at the end, applying to both branches). Ensure this new block sits after the `if (viewFlag) {...} else {...}` render branches and before `out.push(\`</svg>\`)`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bun test tools/test/foldview.test.mjs`
Expected: PASS (all tests).

- [ ] **Step 6: Render the full example set for visual review**

Run:
```bash
for ex in fold-half fold-quarter multiple-folds complex-fold; do
  dune exec beloch -- fold examples/$ex.bel | bun tools/fold2svg.mjs - /tmp/$ex-cp.png  --title "$ex"
  dune exec beloch -- fold examples/$ex.bel | bun tools/fold2svg.mjs - /tmp/$ex-top.png --view top --title "$ex top"
  dune exec beloch -- fold examples/$ex.bel | bun tools/fold2svg.mjs - /tmp/$ex-bot.png --view bottom --title "$ex bottom"
done
```
Expected: all PNGs write. Eyeball for occlusion correctness, front/back tint, shadow depth, legend panel. (These become the PR screenshots.)

- [ ] **Step 7: Commit**

```bash
git add tools/fold2svg.mjs tools/test/foldview.test.mjs
git commit -m "feat(fold2svg): aesthetic pass — layer shadow, legend panel, title treatment"
```

---

## Self-Review

**Spec coverage:**
- Occlusion top view (painter's over faceOrders, opaque) → Task 1 ✓
- Top + bottom views → Task 1 (top) + Task 2 (bottom) ✓
- Front/back side tinting (winding) → Task 2 ✓
- `--hidden dashed|hide` → Task 3 ✓
- `--folded` becomes `--view top` → Task 1 (`viewFlag = args.includes("--folded") ? "top" : flagVal("--view")`) ✓
- Aesthetic pass (paper look, layer shadow, typo/legend, CP frame typo-only) → Task 2 (paper tint) + Task 4 (shadow, legend, title; CP frame shares the end-of-file title/legend block) ✓
- Testing: linear-extension order, back-side class, dashed occluded crease, mirror → Tasks 1–3 tests; mirror is covered by the bottom-view render + manual check in Task 2 Step 6 (SVG mirror is a pure `W - tx(x)`; no separate unit needed) ✓
- No OCaml change; Rabbit Ear load-check preserved; `--title`/output/png preserved → Task 1 rewrite keeps `ear.graph`, arg parsing, output handling ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code. ✓

**Type consistency:** `linearExtension(faceOrders, nFaces)`, `foldedFrame(fold)`, `faceEdgeIndex(edgesVertices)`, `signedArea(poly)`, `sideUp(poly)`, `pointInPolygon(pt, poly)`, `edgeCovered(mid, incidentMaxPos, order, F, V)` — names/params consistent across tasks and tests. The CLI-local `mx`, `edgeIx`, `order` are referenced only within the single `if (viewFlag)` block where they are defined. ✓

**Note for the implementer:** Tasks 3 & 4 integration tests spawn `bun tools/fold2svg.mjs` with a repo-root-relative fixture path — run `bun test` from the repository root.
