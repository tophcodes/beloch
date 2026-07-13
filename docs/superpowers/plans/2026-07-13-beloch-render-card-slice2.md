# Beloch Render Card — Slice 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the docs `<Beloch>` card interactive — a `<beloch-figure>` web component reads the embedded FOLD and adds a CP↔folded view toggle with a per-step stepper, plus a bidirectional code↔diagram link (hover to preview, click to build a persistent multi-selection whose creases stay visible through every fold step).

**Architecture:** Provenance is decided in OCaml (exact rationals) and carried by array index into the pure-TS render pipeline, which stamps `data-bel-name` on SVG elements at draw time; the highlighter stamps the same attribute on code tokens; a vanilla `<beloch-figure>` custom element wires DOM events to CSS-class toggles and re-renders (via `@beloch/render-svg`) only on view/step change. The Slice-1 SSR CP-SVG stays as the no-JS fallback.

**Tech Stack:** OCaml (`lib/fold_emit.ml`, Alcotest), TypeScript (`@beloch/scene`, `@beloch/render-svg`, bun test), Astro/Starlight, a vanilla Web Component, happy-dom (new devDep, for component tests).

## Global Constraints

- **Addressing is index-based, never coordinate matching.** Every name→element link is decided in OCaml by exact `Geom.point_equal` and carried by array index; no float comparison in TS.
- **Addressing attribute is `data-bel-name`**, value = source name without sigil (`.center`→`center`, `--d1`→`d1`). Keep existing `data-name`/`data-kind`/`data-occluded` attrs — `data-bel-name` is additive.
- **Build tooling:** OCaml build/test/regen run inside the Nix devShell: `nix develop -c bash -lc '<cmd>'` (bare `beloch`/`dune` fail). TS render tests run bare from `render/`: `cd render && bun test`. Site tests run bare from `site/`: `cd site && bun test`. bun is on PATH; `dune`/`beloch` are not.
- **CP is the default view.** The folded toggle + stepper appear only when `scene.steps.length > 0`.
- **Re-render only on view/step change.** Hover and selection are CSS-class toggles re-applied from component state after each re-render.
- **Folded view renders with `hidden: 'dashed'`** so occluded crease geometry stays in the DOM (carries `data-occluded="true"`), letting a selected line show a ghosted occluded segment.
- **Graceful degradation:** if in-browser parse/render throws, keep the SSR static SVG and disable interactivity; never break the page.
- German UI copy. Conventional commits with the repo trailer. Commit only on the feature branch (see Task 0).
- Out of scope: Slice-3 content, Playground changes, fold-transition animation, extracting the component to a package.

---

### Task 0: Branch

- [ ] **Step 1: Create the feature branch from main**

```bash
cd /home/toph/Projects/beloch
git checkout main
git checkout -b feat/beloch-figure-hydration
git branch --show-current   # expect: feat/beloch-figure-hydration
```

All subsequent tasks commit on this branch. Verify `git branch --show-current` before every commit.

---

### Task 1: OCaml — folded-frame `beloch:edges` + per-frame `beloch:vertices_names`

**Files:**
- Modify: `lib/fold_emit.ml`
- Test: `tests/test_e2e.ml`
- Regen: `tests/golden/*.fold` (via `tools/regen.exe`)

**Interfaces:**
- Produces (FOLD): every frame (CP + each foldedForm) gains `beloch:vertices_names` — a JSON array parallel to `vertices_coords`, each entry a `` `String name `` or `` `Null ``. Folded frames additionally gain `beloch:edges` (same per-edge `{axiom,sources,span,name,step}` shape as the CP frame, or `null`), parallel to `edges_vertices`.

- [ ] **Step 1: Write the failing test** (`tests/test_e2e.ml`)

Add this test. It evaluates a program that folds and names a vertex, parses the emitted FOLD, and asserts the new fields. Use the yojson helpers already imported in the file.

```ocaml
let test_folded_provenance () =
  let src =
    "paper square\n\
     mark --d1 = through .a .c\n\
     mark --d2 = through .b .d\n\
     .center = --d1 * --d2\n\
     fold map .a onto .center\n"
  in
  let json = Beloch.fold_string ~filename:"prov.bel" src in
  let open Yojson.Safe.Util in
  (* CP frame: vertices_names contains "center" *)
  let cp_names = json |> member "beloch:vertices_names" |> to_list in
  Alcotest.(check bool) "cp vertices_names has center" true
    (List.exists (fun v -> v = `String "center") cp_names);
  (* first foldedForm frame carries beloch:edges AND beloch:vertices_names *)
  let frames = json |> member "file_frames" |> to_list in
  let folded =
    List.find
      (fun f ->
        f |> member "frame_classes" |> to_list
        |> List.exists (fun c -> c = `String "foldedForm"))
      frames
  in
  Alcotest.(check bool) "folded frame has beloch:edges" true
    (match folded |> member "beloch:edges" with `Null -> false | _ -> true);
  Alcotest.(check bool) "folded frame vertices_names has center" true
    (folded |> member "beloch:vertices_names" |> to_list
     |> List.exists (fun v -> v = `String "center"))
```

Register it in the file's Alcotest test list (add `Alcotest.test_case "folded provenance" `Quick test_folded_provenance` to the appropriate suite list in `tests/test_e2e.ml`'s `let () = Alcotest.run ...`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `nix develop -c bash -lc 'dune build @runtest 2>&1 | tail -30'`
Expected: FAIL — the folded frame has no `beloch:edges` (returns `` `Null `` → the "has beloch:edges" check fails), and `beloch:vertices_names` is absent (yojson `member` returns `` `Null `` → `to_list` raises / check fails).

- [ ] **Step 3: Implement — add two emit helpers + wire them into both frame builders** (`lib/fold_emit.ml`)

First, near the top of the file (after `q_to_json` at line 3), add two reusable helpers:

```ocaml
(* name for each vertex, by exact paper-coord match against named points *)
let vertices_names_json (vpaper : Geom.point Dynarray.t)
    (named_points : (string * Geom.point) list) : Yojson.Safe.t =
  `List
    (Dynarray.to_list vpaper
    |> List.map (fun (p : Geom.point) ->
           match
             List.find_opt (fun (_, q) -> Geom.point_equal p q) named_points
           with
           | Some (name, _) -> `String name
           | None -> `Null))

(* beloch:edges array from an (ia, ib, assign, prov) edge list *)
let beloch_edges_json edges : Yojson.Safe.t =
  `List
    (List.map
       (fun (_, _, _, prov) ->
         match prov with
         | None -> `Null
         | Some (pr : State.provenance) ->
             `Assoc
               [
                 ("axiom", `String pr.State.axiom);
                 ( "sources",
                   `List (List.map (fun s -> `String s) pr.State.sources) );
                 ("span", `String (Error.span_to_string pr.State.span));
                 ( "name",
                   match pr.State.name with
                   | Some n -> `String n
                   | None -> `Null );
                 ( "step",
                   match pr.State.step with
                   | Some s -> `String s
                   | None -> `Null );
               ])
       edges)
```

Then refactor the **CP frame** builder (`to_json_folded`, the existing `let beloch_edges = List.map ... edges in` at lines 261-280) to call the helper:

```ocaml
  let beloch_edges = beloch_edges_json edges in
```

and add, alongside it, the CP vertices_names (its vpaper is the paper-vertex Dynarray at lines 190-204; `fd.Eval.named_points` is in scope in `to_json_folded`):

```ocaml
  let beloch_vertices_names = vertices_names_json vpaper fd.Eval.named_points in
```

Add both to the CP frame's `` `Assoc `` (near the existing `("beloch:named_points", ...)` at ~line 349):

```ocaml
      ("beloch:vertices_names", beloch_vertices_names);
```
(`beloch:edges` is already in the CP Assoc; only `beloch:vertices_names` is new there.)

Now the **folded frame** builder. `folded_frame_of_state` (line 45) needs `named_points` — thread it through. Change its signature:

```ocaml
let folded_frame_of_state (named_points : (string * Geom.point) list)
    (state : Fold_state.t) (step : string option) : Yojson.Safe.t =
```

Inside it, after the local `edges` list is fully built (after line 114's loop) and `vpaper`/`vtable` are populated, compute:

```ocaml
  let beloch_edges = beloch_edges_json (List.rev !edges) in
  let beloch_vertices_names = vertices_names_json vpaper named_points in
```
(Use whatever order the existing `edges_vertices`/`edges_assignment` JSON lists use — they derive from `!edges`; match that same order. If those lists use `List.rev !edges`, use `List.rev !edges` here too so `beloch:edges` aligns index-for-index with `edges_vertices`. VERIFY the ordering matches the existing `edges_vertices` construction in this function and mirror it exactly.)

Add both to the folded frame's `` `Assoc `` (lines 170-183):

```ocaml
      ("beloch:edges", beloch_edges);
      ("beloch:vertices_names", beloch_vertices_names);
```

Finally, update the **call site** of `folded_frame_of_state` (in `to_json_folded`, where it maps over `fd.Eval.frames`) to pass `fd.Eval.named_points` as the new first argument.

- [ ] **Step 4: Run the test to verify it passes**

Run: `nix develop -c bash -lc 'dune build @runtest 2>&1 | tail -40'`
Expected: `test_folded_provenance` passes. `test_golden` will now FAIL (goldens are stale) — that is expected and fixed in Step 5.

- [ ] **Step 5: Regenerate goldens and verify**

Run: `nix develop -c bash -lc 'dune exec tools/regen.exe && dune build @runtest 2>&1 | tail -20'`
Expected: goldens regenerated (every `.fold` gains `beloch:vertices_names`; folded frames gain `beloch:edges`), then the full test suite passes (golden + the new test). Spot-check one diff:

```bash
nix develop -c bash -lc 'git diff --stat tests/golden | tail -3'
```
Expected: many `.fold` files changed (additive `beloch:*` fields).

- [ ] **Step 6: Commit**

```bash
git add lib/fold_emit.ml tests/test_e2e.ml tests/golden
git commit -m "feat(fold): emit folded-frame beloch:edges + per-frame beloch:vertices_names

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: scene — carry `verticesNames` on `Frame`

**Files:**
- Modify: `render/scene/src/types.ts`, `render/scene/src/parse.ts`
- Test: `render/scene/test/parse.test.ts`

**Interfaces:**
- Consumes: FOLD frames with `beloch:vertices_names` (Task 1) and folded frames with `beloch:edges` (Task 1).
- Produces: `Frame.verticesNames: (string | null)[]` (same length as `vertices`), populated per-frame; folded steps now carry `edgesProvenance[i].name` for creases.

- [ ] **Step 1: Write the failing test** (`render/scene/test/parse.test.ts`)

Use the regenerated `x-midpoint.fold` golden (it binds `.center` and folds). Add:

```ts
test("frame carries verticesNames from beloch:vertices_names", async () => {
  const scene = parseFold(await golden("syntax/x-midpoint.fold"));
  expect(scene.cp.verticesNames).toContain("center");
  expect(scene.cp.verticesNames.length).toBe(scene.cp.vertices.length);
});

test("folded step frames carry crease provenance names", async () => {
  const scene = parseFold(await golden("syntax/x-midpoint.fold"));
  const step = scene.steps[scene.steps.length - 1]!;
  const hasNamedCrease = step.frame.edgesProvenance.some((p) => p?.name);
  expect(hasNamedCrease).toBe(true);
});
```

(Match the existing `golden()` helper + `Step` shape in this test file. If `Step` wraps the frame under a different property than `.frame`, adjust the second test to the actual shape — read the top of `parse.test.ts` / `types.ts` `Step` definition first.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd render && bun test scene/test/parse.test.ts 2>&1 | tail -20`
Expected: FAIL — `scene.cp.verticesNames` is `undefined` (property doesn't exist yet).

- [ ] **Step 3: Implement** — add the field to `Frame` and populate it in `frameFrom`.

In `render/scene/src/types.ts`, add to `interface Frame` (after `edgesProvenance`):

```ts
  verticesNames: (string | null)[];                          // beloch:vertices_names, per vertex
```

In `render/scene/src/parse.ts` `frameFrom`, after the `const prov = ...` line, add:

```ts
  const vnames = (raw["beloch:vertices_names"] ?? []) as (string | null)[];
```

and in the returned object add:

```ts
    verticesNames: Array.from(
      { length: vertices.length },
      (_, i) => vnames[i] ?? null,
    ),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd render && bun test scene/test/parse.test.ts 2>&1 | tail -20`
Expected: both new tests PASS. Then run the whole scene suite to catch fallout:
`cd render && bun test 2>&1 | tail -20` — expected all green (additive field).

- [ ] **Step 5: Commit**

```bash
git add render/scene/src/types.ts render/scene/src/parse.ts render/scene/test/parse.test.ts
git commit -m "feat(scene): carry verticesNames on Frame from beloch:vertices_names

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: render-svg — stamp `data-bel-name` on creases + vertex dots (CP + folded)

**Files:**
- Modify: `render/render-svg/src/render-cp.ts`, `render/render-svg/src/render-folded.ts`
- Test: `render/render-svg/test/render-cp.test.ts`, `render/render-svg/test/render-folded.test.ts`

**Interfaces:**
- Consumes: `scene.cp.verticesNames` / a folded frame's `verticesNames` (Task 2), `edgesProvenance[i].name`.
- Produces: `<line data-bel-name="d1">` on named creases (CP + folded, visible + occluded); `<circle data-bel-name="center" data-kind="point">` on named vertex dots (CP + folded).

- [ ] **Step 1: Write the failing tests**

In `render/render-svg/test/render-cp.test.ts`:

```ts
test("CP stamps data-bel-name on named creases and named vertex dots", async () => {
  const scene = parseFold(await golden("syntax/x-midpoint.fold"));
  const s = renderCP(scene).toString();
  expect(s).toContain('data-bel-name="center"');            // the named crossing vertex
  expect(s).toMatch(/data-bel-name="d1"|data-bel-name="d2"/); // a named diagonal crease
});
```

In `render/render-svg/test/render-folded.test.ts` (match its existing imports/golden helper):

```ts
test("folded stamps data-bel-name on named vertex dots and keeps occluded creases", async () => {
  const scene = parseFold(await golden("syntax/x-midpoint.fold"));
  const s = renderFolded(scene, { hidden: "dashed" }).toString();
  expect(s).toContain('data-bel-name="center"');
  expect(s).toContain('data-occluded="true"');               // occluded geometry retained
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd render && bun test render-svg/test/render-cp.test.ts render-svg/test/render-folded.test.ts 2>&1 | tail -25`
Expected: FAIL — no `data-bel-name` emitted yet; folded has no vertex dots.

- [ ] **Step 3: Implement — render-cp.ts**

Crease line (in the `E.forEach` block, after the existing `if (name) attrs["data-name"] = name;` at ~line 76):

```ts
    if (name) attrs["data-bel-name"] = name;
```

Vertex dots — change the `V.forEach((p) => {` block (~line 122) to use the index and stamp the name from `scene.cp.verticesNames`:

```ts
  V.forEach((p, i) => {
    const nm = scene.cp.verticesNames[i];
    const circleAttrs: Record<string, string | number> = {
      cx: tx(p[0]), cy: ty(p[1]), r: 3, fill: theme.ink,
    };
    if (nm) { circleAttrs["data-bel-name"] = nm; circleAttrs["data-kind"] = "point"; }
    annotations.children.push(el("circle", circleAttrs));
    const lab = cornerLabel(p);
    if (lab) {
      const ox = p[0] < 0.5 ? -16 : 10, oy = p[1] < 0.5 ? 18 : -8;
      annotations.children.push(el("text", {
        x: tx(p[0]) + ox, y: ty(p[1]) + oy,
        "font-size": 17, "font-weight": 600, fill: theme.ink,
      }, [], `.${lab}`));
    }
  });
```

- [ ] **Step 4: Implement — render-folded.ts**

Crease lines: in BOTH the visible-segment block (~line 141) and the occluded/dashed block (~line 162), after `if (name) attrs["data-name"] = name;` add:

```ts
      if (name) attrs["data-bel-name"] = name;
```

Add a named-vertex-dot pass. After the creases are appended (`creases.children.push(...dashedLines);`, ~line 208) and before `appendConstructions(...)` (~line 210), insert (use the picked frame's `vertices` + `verticesNames`, and the same `mx`/`ty` transforms the folded creases use):

```ts
  // named-vertex dots (hover/selection targets in the folded view)
  const fverts = frame.vertices;
  frame.verticesNames.forEach((nm, i) => {
    if (!nm) return;
    const p = fverts[i]!;
    annotations.children.push(
      el("circle", {
        cx: mx(p[0]), cy: ty(p[1]), r: 3, fill: theme.ink,
        "data-bel-name": nm, "data-kind": "point",
      }),
    );
  });
```
(Confirm the local names: the folded frame variable it iterates for creases — call it `frame` here to match; if the file names it differently, e.g. `f` or `step.frame`, use that. Ensure an `annotations` layer exists — if render-folded has no `annotations` layer yet, create it with `const annotations = doc.layer("annotations");` before the loop, mirroring render-cp.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd render && bun test render-svg/test 2>&1 | tail -25`
Expected: the two new tests pass. Existing render-svg snapshot tests may change (new attrs on lines/circles) — update snapshots if the repo uses them: `cd render && bun test render-svg/test --update-snapshots` (only if snapshots exist and the diffs are purely the additive attrs — inspect first).

- [ ] **Step 6: Commit**

```bash
git add render/render-svg/src/render-cp.ts render/render-svg/src/render-folded.ts render/render-svg/test
git commit -m "feat(render-svg): stamp data-bel-name on named creases + vertex dots (CP + folded)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: highlighter — `data-bel-name` on variable code tokens

**Files:**
- Modify: `site/src/lib/highlight-bel.ts`
- Test: `site/src/lib/highlight-bel.test.ts` (create)

**Interfaces:**
- Produces: point tokens `.<ident>` → `<span class="bel-point" data-bel-name="<ident>">`; crease tokens `--<ident>` → `<span class="bel-line" data-bel-name="<ident>">`. Bracket operators (`.[`, `--[`, `#[`), keywords, numbers, punctuation get NO `data-bel-name`.

- [ ] **Step 1: Write the failing test** (`site/src/lib/highlight-bel.test.ts`)

```ts
import { test, expect } from "bun:test";
import { highlightBel } from "./highlight-bel";

test("variable tokens get data-bel-name, non-variables don't", async () => {
  const html = await highlightBel(
    "paper square\nmark --d1 = through .a .c\n.center = --d1 * --d2\n",
  );
  expect(html).toContain('data-bel-name="d1"');
  expect(html).toContain('data-bel-name="center"');
  expect(html).toContain('data-bel-name="a"');
  // keyword 'through' must not be tagged
  expect(html).not.toMatch(/data-bel-name="through"/);
});

test("bracket operators are not tagged as variables", async () => {
  const html = await highlightBel("paper square\n.center = .[--d1 --d2]\n");
  // the '.[' meet-bracket must not produce data-bel-name="["
  expect(html).not.toContain('data-bel-name="["');
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd site && bun test src/lib/highlight-bel.test.ts 2>&1 | tail -20`
Expected: FAIL — no `data-bel-name` emitted.

- [ ] **Step 3: Implement** (`site/src/lib/highlight-bel.ts`)

Replace the emit line (line 69, `out += \`<span class="bel-${c.name}">...\`;`) with sigil-aware tagging. Insert before the `out +=`:

```ts
    const tokenText = source.slice(s, e);
    let belName = "";
    if (c.name === "point") {
      const m = /^\.([A-Za-z_]\w*)$/.exec(tokenText);   // .center — not .[ 
      if (m) belName = m[1]!;
    } else if (c.name === "line") {
      const m = /^--([A-Za-z_]\w*)$/.exec(tokenText);   // --d1 — not --[
      if (m) belName = m[1]!;
    }
    const dataAttr = belName ? ` data-bel-name="${belName}"` : "";
    out += `<span class="bel-${c.name}"${dataAttr}>${esc(tokenText)}</span>`;
```

(Reuses the existing `esc` and `source.slice(s, e)`; only adds the optional attribute.)

- [ ] **Step 4: Run to verify it passes**

Run: `cd site && bun test src/lib/highlight-bel.test.ts 2>&1 | tail -20`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/highlight-bel.ts site/src/lib/highlight-bel.test.ts
git commit -m "feat(site): tag variable code tokens with data-bel-name

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `<beloch-figure>` web component — hydration + view toggle + stepper

**Files:**
- Create: `site/src/lib/beloch-figure.ts` (the custom element + pure helpers)
- Modify: `site/src/components/Beloch.astro` (wrap in `<beloch-figure>` + register the element via a client `<script>`)
- Create: `site/src/lib/beloch-figure.test.ts`
- Modify: `site/package.json` (add `happy-dom` devDep)

**Interfaces:**
- Consumes: the embedded `<script class="beloch-fold">` FOLD JSON; `parseFold` (@beloch/scene), `renderCP`/`renderFolded` (@beloch/render-svg).
- Produces: a registered custom element `beloch-figure`; exported pure helpers `clampStep(i, n): number` and `viewHasSteps(scene): boolean` for unit testing.

- [ ] **Step 1: Add happy-dom devDep**

```bash
cd site && bun add -d happy-dom
```
Run: expect `happy-dom` added to `site/package.json` devDependencies.

- [ ] **Step 2: Write the failing test** (`site/src/lib/beloch-figure.test.ts`)

```ts
import { test, expect, beforeAll } from "bun:test";
import { GlobalRegistrator } from "@happy-dom/global-registrator";

beforeAll(() => { GlobalRegistrator.register(); });

// x-midpoint folds → has steps; inline its FOLD by evaluating at test time is
// heavy, so load a golden the render tests also use.
const foldJson = await Bun.file(
  new URL("../../../tests/golden/syntax/x-midpoint.fold", import.meta.url),
).text();

function mountCard(fold: string): HTMLElement {
  document.body.innerHTML = `
    <beloch-figure>
      <figure class="beloch-card">
        <div class="beloch-code-panel"></div>
        <div class="beloch-diagram"><svg></svg></div>
        <script type="application/json" class="beloch-fold">${fold}</script>
      </figure>
    </beloch-figure>`;
  return document.querySelector("beloch-figure") as HTMLElement;
}

test("hydration adds a view toggle when the fold has steps", async () => {
  await import("./beloch-figure");            // registers the element
  const el = mountCard(foldJson);
  (el as any).hydrate();                       // force hydration (bypass IntersectionObserver in test)
  expect(el.querySelector('[data-view="cp"]')).not.toBeNull();
  expect(el.querySelector('[data-view="folded"]')).not.toBeNull();
});

test("switching to folded renders a folded svg; stepper advances", async () => {
  await import("./beloch-figure");
  const el = mountCard(foldJson);
  (el as any).hydrate();
  (el.querySelector('[data-view="folded"]') as HTMLElement).click();
  const diagram = el.querySelector(".beloch-diagram")!;
  expect(diagram.querySelector("svg")).not.toBeNull();       // re-rendered
  const stepper = el.querySelector(".beloch-stepper");
  expect(stepper).not.toBeNull();
});
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd site && bun test src/lib/beloch-figure.test.ts 2>&1 | tail -20`
Expected: FAIL — `./beloch-figure` doesn't exist / `hydrate` undefined.

- [ ] **Step 4: Implement the element** (`site/src/lib/beloch-figure.ts`)

```ts
import { parseFold, type FoldScene } from "@beloch/scene";
import { renderCP, renderFolded } from "@beloch/render-svg";

export function clampStep(i: number, n: number): number {
  if (n <= 0) return 0;
  return Math.max(0, Math.min(i, n - 1));
}
export function viewHasSteps(scene: FoldScene): boolean {
  return scene.steps.length > 0;
}

type View = "cp" | "folded";

class BelochFigure extends HTMLElement {
  private scene: FoldScene | null = null;
  private view: View = "cp";
  private step = 0;
  private cpHTML = "";                 // cached SSR CP svg
  private hydrated = false;

  connectedCallback() {
    // Lazy: hydrate when near the viewport.
    if (!("IntersectionObserver" in window)) { this.hydrate(); return; }
    const io = new IntersectionObserver((entries, obs) => {
      if (entries.some((e) => e.isIntersecting)) { obs.disconnect(); this.hydrate(); }
    });
    io.observe(this);
  }

  hydrate() {
    if (this.hydrated) return;
    this.hydrated = true;
    const raw = this.querySelector("script.beloch-fold")?.textContent ?? "";
    const diagram = this.querySelector(".beloch-diagram") as HTMLElement | null;
    if (!raw || !diagram) return;
    try {
      this.scene = parseFold(JSON.parse(raw));
    } catch (err) {
      console.warn("beloch-figure: parse failed, keeping static SVG", err);
      return;                            // graceful degradation
    }
    this.cpHTML = diagram.innerHTML;      // keep the SSR CP as the CP view + fallback
    if (viewHasSteps(this.scene)) {
      this.step = this.scene.steps.length - 1;
      this.buildControls();
    }
  }

  private buildControls() {
    const bar = document.createElement("div");
    bar.className = "beloch-controls";
    bar.innerHTML = `
      <button type="button" data-view="cp" class="beloch-tab is-active">Faltbild</button>
      <button type="button" data-view="folded" class="beloch-tab">Gefaltet</button>
      <span class="beloch-stepper" hidden>
        <button type="button" class="beloch-step-prev" aria-label="Schritt zurück">◀</button>
        <span class="beloch-step-label"></span>
        <button type="button" class="beloch-step-next" aria-label="Schritt vor">▶</button>
      </span>`;
    this.querySelector(".beloch-card")?.prepend(bar);
    bar.querySelector('[data-view="cp"]')!.addEventListener("click", () => this.setView("cp"));
    bar.querySelector('[data-view="folded"]')!.addEventListener("click", () => this.setView("folded"));
    bar.querySelector(".beloch-step-prev")!.addEventListener("click", () => this.setStep(this.step - 1));
    bar.querySelector(".beloch-step-next")!.addEventListener("click", () => this.setStep(this.step + 1));
  }

  private setView(v: View) {
    this.view = v;
    this.querySelectorAll(".beloch-tab").forEach((b) =>
      b.classList.toggle("is-active", (b as HTMLElement).dataset.view === v));
    (this.querySelector(".beloch-stepper") as HTMLElement).hidden = v !== "folded";
    this.render();
  }
  private setStep(i: number) {
    if (!this.scene) return;
    this.step = clampStep(i, this.scene.steps.length);
    this.render();
  }

  private render() {
    const diagram = this.querySelector(".beloch-diagram") as HTMLElement;
    if (!this.scene) return;
    if (this.view === "cp") {
      diagram.innerHTML = this.cpHTML || renderCP(this.scene).toString();
    } else {
      const step = this.scene.steps[this.step];
      const label = (step as any)?.label as string | undefined;
      diagram.innerHTML = renderFolded(this.scene, {
        step: label, hidden: "dashed",
      }).toString();
      const lbl = this.querySelector(".beloch-step-label");
      if (lbl) lbl.textContent = `${this.step + 1}/${this.scene.steps.length}`;
    }
    // (selection re-application hook — filled in Task 6)
    this.afterRender?.();
  }

  afterRender?: () => void;             // Task 6 attaches selection re-apply here
}

if (typeof customElements !== "undefined" && !customElements.get("beloch-figure")) {
  customElements.define("beloch-figure", BelochFigure);
}
```

(Note on `renderFolded`'s `step` option: it takes the `beloch:step` **label** string, not an index — pass the picked step's label. If `Step` in `@beloch/scene` exposes the label under a different property than `.label`, read `render/scene/src/types.ts`'s `Step` and use the right one; `pickStep` matches by label and falls back to final, so passing `undefined` yields the final step.)

- [ ] **Step 5: Wire the component into the Astro card** (`site/src/components/Beloch.astro`)

Wrap the `<figure>` in `<beloch-figure>` and register the element with a client script. Change the template so the figure is nested:

```astro
<beloch-figure>
  <figure class="beloch-card">
    ...unchanged children (code panel, diagram, beloch-fold script)...
  </figure>
</beloch-figure>
<script>
  import "../lib/beloch-figure";
</script>
```

(The `<script>` with a bare `import` is a client-side module Astro bundles + ships once per page; it registers the custom element.)

- [ ] **Step 6: Run the component test to verify it passes**

Run: `cd site && bun test src/lib/beloch-figure.test.ts 2>&1 | tail -25`
Expected: both tests PASS (toggle present; folded render + stepper appear).

- [ ] **Step 7: Build the site to confirm the client script bundles**

Run: `nix develop -c bash -lc 'cd site && bun run build 2>&1 | tail -8'`
Expected: build green; `site/dist/index.html` contains `<beloch-figure>` wrapping the card.

```bash
grep -c '<beloch-figure' site/dist/index.html   # expect >= 1
```

- [ ] **Step 8: Commit**

```bash
git add site/src/lib/beloch-figure.ts site/src/lib/beloch-figure.test.ts \
        site/src/components/Beloch.astro site/package.json site/bun.lock
git commit -m "feat(site): <beloch-figure> hydration — view toggle + step stepper

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Interaction — bidirectional hover + multi-selection + through-step styling

**Files:**
- Modify: `site/src/lib/beloch-figure.ts` (add hover + selection wiring)
- Modify: `site/src/styles/theme.css` (hover/selection/palette CSS — global, targets both code spans and injected SVG)
- Test: `site/src/lib/beloch-figure.test.ts` (extend)

**Interfaces:**
- Consumes: `data-bel-name` on code spans (Task 4) and SVG elements (Task 3); the `afterRender` hook (Task 5).
- Produces: hover class `.bel-hover` (transient), selection class `.bel-selected` (persistent) + per-name colour via inline `--bel-sel` custom property, both applied to every `[data-bel-name="<n>"]` in the card and re-applied after each re-render.

- [ ] **Step 1: Write the failing test** (extend `site/src/lib/beloch-figure.test.ts`)

```ts
test("clicking a code token toggles selection on both sides and persists over re-render", async () => {
  await import("./beloch-figure");
  const el = mountCard(foldJson);
  // inject a code token so both sides exist
  el.querySelector(".beloch-code-panel")!.innerHTML =
    '<span class="bel-point" data-bel-name="center">.center</span>';
  (el as any).hydrate();
  const token = el.querySelector('.beloch-code-panel [data-bel-name="center"]') as HTMLElement;
  token.click();
  expect(token.classList.contains("bel-selected")).toBe(true);
  // svg side (CP already has the dot from SSR? in the test svg is empty, so assert state instead)
  expect((el as any).selected.has("center")).toBe(true);
  token.click();                                   // toggle off
  expect(token.classList.contains("bel-selected")).toBe(false);
  expect((el as any).selected.has("center")).toBe(false);
});

test("hover adds and removes .bel-hover", async () => {
  await import("./beloch-figure");
  const el = mountCard(foldJson);
  el.querySelector(".beloch-code-panel")!.innerHTML =
    '<span class="bel-point" data-bel-name="center">.center</span>';
  (el as any).hydrate();
  const token = el.querySelector('[data-bel-name="center"]') as HTMLElement;
  token.dispatchEvent(new Event("mouseenter", { bubbles: true }));
  expect(el.querySelectorAll(".bel-hover").length).toBeGreaterThan(0);
  token.dispatchEvent(new Event("mouseleave", { bubbles: true }));
  expect(el.querySelectorAll(".bel-hover").length).toBe(0);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd site && bun test src/lib/beloch-figure.test.ts 2>&1 | tail -20`
Expected: FAIL — `selected` undefined, no hover/selection wiring.

- [ ] **Step 3: Implement selection + hover** (`site/src/lib/beloch-figure.ts`)

Add fields + a palette + wiring. Inside the class add:

```ts
  private static PALETTE = ["#e8a33d", "#3db0a8", "#a878e0", "#5fa85f", "#e06e9e", "#4aa8d8"];
  selected = new Set<string>();
  private colorOf = new Map<string, string>();

  private wireInteraction() {
    // event delegation on the whole card
    this.addEventListener("mouseover", (e) => {
      const n = (e.target as HTMLElement)?.closest?.("[data-bel-name]") as HTMLElement | null;
      if (n) this.setHover(n.dataset.belName!, true);
    });
    this.addEventListener("mouseout", (e) => {
      const n = (e.target as HTMLElement)?.closest?.("[data-bel-name]") as HTMLElement | null;
      if (n) this.setHover(n.dataset.belName!, false);
    });
    this.addEventListener("click", (e) => {
      const n = (e.target as HTMLElement)?.closest?.("[data-bel-name]") as HTMLElement | null;
      if (n) this.toggleSelect(n.dataset.belName!);
    });
    this.afterRender = () => this.applySelection();
  }

  private matches(name: string): HTMLElement[] {
    return Array.from(this.querySelectorAll<HTMLElement>(`[data-bel-name="${CSS.escape(name)}"]`));
  }
  private setHover(name: string, on: boolean) {
    this.matches(name).forEach((el) => el.classList.toggle("bel-hover", on));
  }
  private toggleSelect(name: string) {
    if (this.selected.has(name)) { this.selected.delete(name); }
    else {
      this.selected.add(name);
      if (!this.colorOf.has(name))
        this.colorOf.set(name, BelochFigure.PALETTE[this.colorOf.size % BelochFigure.PALETTE.length]!);
    }
    this.applySelection();
  }
  private applySelection() {
    this.querySelectorAll(".bel-selected").forEach((el) => {
      el.classList.remove("bel-selected");
      (el as HTMLElement).style.removeProperty("--bel-sel");
    });
    this.selected.forEach((name) => {
      const color = this.colorOf.get(name)!;
      this.matches(name).forEach((el) => {
        el.classList.add("bel-selected");
        el.style.setProperty("--bel-sel", color);
      });
    });
  }
```

Call `this.wireInteraction()` at the end of `hydrate()` (after building controls / caching cpHTML), and ensure `render()` already calls `this.afterRender?.()` (from Task 5) so selection re-applies after a re-render.

- [ ] **Step 4: Add the CSS** (`site/src/styles/theme.css`, append)

```css
/* ── <beloch-figure> interaction ────────────────────────────────────────── */
.beloch-controls { display: flex; align-items: center; gap: 8px; padding: 8px 12px; }
.beloch-tab { font: inherit; padding: 3px 10px; border-radius: 7px; border: 1px solid var(--beloch-border); background: transparent; color: var(--beloch-muted); cursor: pointer; }
.beloch-tab.is-active { color: var(--beloch-ink); border-color: var(--beloch-valley); }
.beloch-stepper { display: inline-flex; align-items: center; gap: 6px; color: var(--beloch-muted); }
.beloch-stepper button { background: none; border: none; color: inherit; cursor: pointer; font-size: 13px; }

/* hover — neutral, transient */
[data-bel-name].bel-hover { outline: 2px solid var(--beloch-muted); outline-offset: 1px; }
svg [data-bel-name].bel-hover { outline: none; filter: drop-shadow(0 0 3px var(--beloch-muted)); }

/* selection — per-name colour via --bel-sel */
.beloch-code-panel [data-bel-name].bel-selected {
  background: color-mix(in srgb, var(--bel-sel) 32%, transparent);
  border-radius: 4px; box-shadow: 0 0 0 1px var(--bel-sel);
}
svg line.bel-selected { stroke: var(--bel-sel) !important; stroke-width: 3 !important; }
svg circle.bel-selected { fill: var(--bel-sel) !important; r: 4.5; }
/* selected but occluded → ghosted, still dashed */
svg [data-bel-name].bel-selected[data-occluded] { stroke: var(--bel-sel) !important; opacity: 0.25; }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd site && bun test src/lib/beloch-figure.test.ts 2>&1 | tail -25`
Expected: all tests (Task 5 + Task 6) PASS.

- [ ] **Step 6: Build + manual-verify note**

Run: `nix develop -c bash -lc 'cd site && bun run build 2>&1 | tail -6'`
Expected: green. (Interaction is client-side; the build only confirms bundling. A human should later open the dev server and confirm hover/click/step feel right — note this in the report, don't block on it.)

- [ ] **Step 7: Commit**

```bash
git add site/src/lib/beloch-figure.ts site/src/lib/beloch-figure.test.ts site/src/styles/theme.css
git commit -m "feat(site): bidirectional hover + multi-selection with through-step visibility

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **Build/test commands differ per package:** OCaml → `nix develop -c bash -lc 'dune build @runtest'`; render TS → `cd render && bun test`; site TS → `cd site && bun test`; site build (needs beloch) → `nix develop -c bash -lc 'cd site && bun run build'`.
- **Tasks 1→2→3 are a data chain** (OCaml emits → scene carries → render-svg stamps). Don't reorder. Task 4 (highlighter) is independent of 1–3 but the component (5–6) needs all of 1–4.
- The golden regen in Task 1 touches ~33 `.fold` files — that's expected additive churn, commit them.
- `renderFolded`'s `step` option is a **label string**, not an index — see the Task 5 note.
- Verify local variable names in `render-folded.ts` (the folded frame + transforms `mx`/`ty`) before pasting the vertex-dot block — the plan uses `frame`/`mx`/`ty` to match render-cp conventions; adjust to the file's actual identifiers.
- Do not touch the OCaml `eassign`/`eintent` split or mark emission — Slice 2 only adds provenance fields.
```
