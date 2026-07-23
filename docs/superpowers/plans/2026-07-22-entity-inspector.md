# Entity Inspector (Playground slice B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every rendered entity in the playground inspectable — a crease as its segment bundle (face pair, paper+table coords, assignment, layer rank), a point with its face and flap — cross-linked read-only to the source line that built it.

**Architecture:** Three layers. (1) Core emits a new `beloch:inspect` FOLD key from the final fold-state plus a `crease_id` on each `beloch:edges` entry. (2) `@beloch/scene` parses those; `render-svg` stamps `data-*` attributes onto SVG elements. (3) The playground reads the attributes on hover/click, renders a detail panel, links to the editor, and offers a rank-ordered stack picker in the folded view.

**Tech Stack:** OCaml + dune + Yojson (core), TypeScript + Bun (scene, render-svg), Astro + CodeMirror 6 (playground).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-22-entity-inspector-design.md`.
- Read-only: no writing selectors to source (that is slice C). No partial-eval. No new views. No native server.
- Works on the existing js_of_ocaml worker bundle — no new eval transport.
- Core additions are pure serialization of existing `Fold_state` queries (`crease_segments`, `rank`, `coplanar_clusters`); no new geometry.
- Follow existing test patterns: OCaml via `Yojson.Safe.Util.member` in `packages/core/tests/`, TS via Bun snapshot/`expect` in `packages/render-2d/*/test/`.
- Run core tests with `dune test` from repo root; TS tests with `bun test` inside the package.

---

### Task 1: `crease_id` on `beloch:edges`

Thread each edge's crease id (already on `Fold_state.hinge`) into the emitted `beloch:edges` array so the frontend can group a bundle's segments — including anonymous creases that have no name.

**Files:**
- Modify: `packages/core/lib/fold_emit.ml` (`beloch_edges_json` ~50; edge collection ~145-177; CP-frame edge collection ~309+)
- Test: `packages/core/tests/test_e2e.ml`

**Interfaces:**
- Consumes: `Fold_state.hinge.crease_id : int`, `Fold_state.hinge_between : t -> int -> Geom.point -> Geom.point -> int option`, `Fold_state.hinges : t -> hinge array`.
- Produces: each `beloch:edges[i]` is now either `null` or an object that additionally carries `"crease_id": <int>`.

- [ ] **Step 1: Write the failing test**

Add to `packages/core/tests/test_e2e.ml` (follow the existing `member`/`to_list` style already used there for `beloch:edges`):

```ocaml
let test_edges_carry_crease_id () =
  (* a single fold produces one crease bundle; its non-boundary edges all
     carry the same integer crease_id *)
  let src = "paper square\nfold --h = map .a onto .d moving .a\n" in
  let json = Test_helpers.fold_json_of_string src in
  let open Yojson.Safe.Util in
  let cids =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
         | `Null -> None
         | e -> ( match e |> member "crease_id" with `Int i -> Some i | _ -> None ))
  in
  Alcotest.(check bool) "at least one edge has a crease_id" true (cids <> []);
  Alcotest.(check bool) "crease_ids are non-negative" true (List.for_all (fun i -> i >= 0) cids)
```

Register it in this file's test list (match the surrounding `( "name", `Quick, fn )` pattern). If `Test_helpers.fold_json_of_string` does not exist, use the same helper the neighbouring tests in `test_e2e.ml` already use to turn a source string into emitted JSON (grep the file for how existing `beloch:edges` tests obtain `json`).

- [ ] **Step 2: Run test to verify it fails**

Run: `dune test 2>&1 | rg -A3 crease_id`
Expected: FAIL — no `crease_id` member on edge objects (member returns `` `Null ``, so `cids = []`).

- [ ] **Step 3: Extend the edge tuple with the crease id**

In `packages/core/lib/fold_emit.ml`, the folded-frame edge collector (~159-173) currently builds `(ia, ib, assign, prov)`. Capture the hinge's crease id alongside the assignment. Replace the `assign, prov` match and the push:

```ocaml
          let assign, prov, cid =
            if on_unit_boundary pa pb then ("B", None, None)
            else
              match Fold_state.hinge_between state fi pa pb with
              | Some hi ->
                  let a =
                    match Fold_state.mv state hi with
                    | Fold_state.M -> "M"
                    | Fold_state.V -> "V"
                    | Fold_state.F -> "F"
                  in
                  (a, hs.(hi).Fold_state.prov, Some hs.(hi).Fold_state.crease_id)
              | None -> ("F", None, None)
          in
          edges := (ia, ib, assign, prov, cid) :: !edges
```

Update the three downstream destructurings in the same function so they ignore the new 5th field: `edges_vertices` (~185), `edges_assignment` (~188), `edges_fold_angle` (~190) each match `(a, b, _, _)` → `(a, b, _, _, _)`.

Apply the identical change to the CP-frame edge collector (the second `collect unique edges` block, ~309+) and its destructurings.

- [ ] **Step 4: Emit the crease id in `beloch_edges_json`**

Change `beloch_edges_json` (~50) to accept the 5-tuple and add the field:

```ocaml
let beloch_edges_json edges : Yojson.Safe.t =
  `List
    (List.map
       (fun (_, _, _, prov, cid) ->
         match prov with
         | None -> `Null
         | Some (pr : State.provenance) ->
             `Assoc
               ([
                  ("axiom", `String pr.State.axiom);
                  ("sources", `List (List.map (fun s -> `String s) pr.State.sources));
                  ("span", `String (Error.span_to_string pr.State.span));
                  ("name", match pr.State.name with Some n -> `String n | None -> `Null);
                ]
                @ (match cid with Some c -> [ ("crease_id", `Int c) ] | None -> [])))
       edges)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dune test 2>&1 | rg -A3 crease_id`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/core/lib/fold_emit.ml packages/core/tests/test_e2e.ml
git commit -m "feat(core): crease_id on beloch:edges for bundle grouping"
```

---

### Task 2: `beloch:inspect` export

Emit a top-level `beloch:inspect` object built from the final fold-state: creases keyed by id with their segment bundles, faces with flap + rank, points with face + flap.

**Files:**
- Modify: `packages/core/lib/fold_emit.ml` (`to_json_folded` ~280; add a `beloch_inspect_json` builder before it)
- Test: `packages/core/tests/test_e2e.ml`; fixture `packages/core/tests/cases/inspect/two-segment-crease.bel`

**Interfaces:**
- Consumes: `Fold_state.hinges : t -> hinge array` (each `.crease_id`, `.prov`, `.intent`), `Fold_state.mv : t -> int -> assign`, `Fold_state.crease_segments : t -> int -> crease_segment list` (fields `faces : int*int`, `pa`/`pb`/`ta`/`tb : Geom.point`), `Fold_state.rank : t -> int array`, `Fold_state.coplanar_clusters : t -> int array`, `Fold_state.faces : t -> Geom.point array array`, `Geom.in_convex_polygon`. From `Eval.folded`: `fd.state`, `fd.named_points : (string * Geom.point * int) list`.
- Produces: FOLD top-level key `beloch:inspect` with shape `{ creases: {<id>: {name, axiom, sources, span, segments:[{faces,paper,table,assignment}]}}, faces: {<i>: {vertices, flap, rank}}, points: {<name>: {face, flap}} }`.

- [ ] **Step 1: Write the fixture**

Create `packages/core/tests/cases/inspect/two-segment-crease.bel`:

```
paper square
mark --h = map .a onto .d
mark --v = map .a onto .b
fold --h moving .a
```

This folds `--h`; `--v` crosses it, so `--h`'s bundle has more than one segment. (Adjust the assertion count in Step 2 to whatever the built evaluator actually reports for this file — see Step 3's run.)

- [ ] **Step 2: Write the failing test**

Add to `packages/core/tests/test_e2e.ml`:

```ocaml
let test_inspect_enumerates_crease_segments () =
  let src = In_channel.with_open_text "cases/inspect/two-segment-crease.bel" In_channel.input_all in
  let json = Test_helpers.fold_json_of_string src in
  let open Yojson.Safe.Util in
  let inspect = json |> member "beloch:inspect" in
  Alcotest.(check bool) "inspect present" true (inspect <> `Null);
  let creases = inspect |> member "creases" |> to_assoc in
  Alcotest.(check bool) "at least one crease" true (creases <> []);
  (* every crease lists >=1 segment, each with a 2-element faces pair *)
  List.iter
    (fun (_id, c) ->
      let segs = c |> member "segments" |> to_list in
      Alcotest.(check bool) "crease has segments" true (segs <> []);
      List.iter
        (fun s ->
          Alcotest.(check int) "faces pair length" 2 (s |> member "faces" |> to_list |> List.length))
        segs)
    creases;
  (* faces carry rank + flap *)
  let faces = inspect |> member "faces" |> to_assoc in
  List.iter
    (fun (_i, f) ->
      Alcotest.(check bool) "face has rank" true (f |> member "rank" <> `Null);
      Alcotest.(check bool) "face has flap" true (f |> member "flap" <> `Null))
    faces
```

Register it in the test list.

- [ ] **Step 3: Run test to verify it fails**

Run: `dune test 2>&1 | rg -A3 inspect`
Expected: FAIL — `beloch:inspect` is `` `Null ``.

- [ ] **Step 4: Build `beloch_inspect_json`**

Add this function in `packages/core/lib/fold_emit.ml` immediately before `to_json_folded` (~280). It takes the display state (the same `cp_display`-graduated state the CP frame uses) and the named points:

```ocaml
let beloch_inspect_json (state : Fold_state.t)
    (named_points : (string * Geom.point * int) list) : Yojson.Safe.t =
  let faces = Fold_state.faces state in
  let rank = Fold_state.rank state in
  let clusters = Fold_state.coplanar_clusters state in
  let hinges = Fold_state.hinges state in
  let pt_json (p : Geom.point) = `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ] in
  (* one representative hinge per crease_id, for name/axiom/assignment *)
  let by_cid = Hashtbl.create 16 in
  Array.iter
    (fun (h : Fold_state.hinge) ->
      if not (Hashtbl.mem by_cid h.Fold_state.crease_id) then
        Hashtbl.replace by_cid h.Fold_state.crease_id h)
    hinges;
  let assign_str = function
    | Fold_state.M -> "M" | Fold_state.V -> "V" | Fold_state.F -> "F"
  in
  let seg_json cid (s : Fold_state.crease_segment) =
    let l, r = s.Fold_state.faces in
    let a =
      match Hashtbl.find_opt by_cid cid with
      | Some h -> assign_str (Fold_state.mv state (* any hinge of this cid *)
                               (let idx = ref 0 in
                                Array.iteri (fun i hh -> if hh.Fold_state.crease_id = cid then idx := i) hinges;
                                !idx))
      | None -> ignore h; "F"
    in
    `Assoc
      [ ("faces", `List [ `Int l; `Int r ]);
        ("paper", `List [ pt_json s.Fold_state.pa; pt_json s.Fold_state.pb ]);
        ("table", `List [ pt_json s.Fold_state.ta; pt_json s.Fold_state.tb ]);
        ("assignment", `String a) ]
  in
  let creases =
    Hashtbl.fold
      (fun cid (h : Fold_state.hinge) acc ->
        let segs = Fold_state.crease_segments state cid in
        let name = match h.Fold_state.prov with Some p -> (match p.State.name with Some n -> `String n | None -> `Null) | None -> `Null in
        let axiom = match h.Fold_state.prov with Some p -> `String p.State.axiom | None -> `Null in
        let sources = match h.Fold_state.prov with Some p -> `List (List.map (fun s -> `String s) p.State.sources) | None -> `List [] in
        let span = match h.Fold_state.prov with Some p -> `String (Error.span_to_string p.State.span) | None -> `Null in
        (string_of_int cid,
         `Assoc [ ("name", name); ("axiom", axiom); ("sources", sources); ("span", span);
                  ("segments", `List (List.map (seg_json cid) segs)) ])
        :: acc)
      by_cid []
  in
  let faces_json =
    Array.to_list
      (Array.mapi
         (fun i poly ->
           (string_of_int i,
            `Assoc [ ("vertices", `List (Array.to_list (Array.map pt_json poly)));
                     ("flap", `Int clusters.(i)); ("rank", `Int rank.(i)) ]))
         faces)
  in
  let face_of (p : Geom.point) =
    let found = ref None in
    Array.iteri (fun i poly -> if !found = None && Geom.in_convex_polygon poly p then found := Some i) faces;
    !found
  in
  let points_json =
    List.map
      (fun (n, p, _step) ->
        let f = face_of p in
        (n, `Assoc [ ("face", match f with Some i -> `Int i | None -> `Null);
                     ("flap", match f with Some i -> `Int clusters.(i) | None -> `Null) ]))
      named_points
  in
  `Assoc [ ("creases", `Assoc creases); ("faces", `Assoc faces_json); ("points", `Assoc points_json) ]
```

Note on the assignment lookup: the inline index scan above is ugly; replace it with a cleaner form if `Fold_state` exposes a `mv_of_cid`. If not, precompute a `cid -> assign` table once by iterating `hinges` (mirroring `by_cid`) and read from it in `seg_json`. Do that clean version:

```ocaml
  let assign_by_cid = Hashtbl.create 16 in
  Array.iteri
    (fun i (h : Fold_state.hinge) ->
      if not (Hashtbl.mem assign_by_cid h.Fold_state.crease_id) then
        Hashtbl.replace assign_by_cid h.Fold_state.crease_id (assign_str (Fold_state.mv state i)))
    hinges;
```

and in `seg_json`: `let a = Option.value (Hashtbl.find_opt assign_by_cid cid) ~default:"F" in`. Use this and delete the inline scan.

- [ ] **Step 5: Wire it into `to_json_folded`**

In `to_json_folded` (~280), obtain the graduated display state the same way the CP frame does (`let disp, _ = cp_display fd.Eval.state in` if not already in scope), then add to the top-level assoc list (near `("beloch:edges", ...)` at ~423):

```ocaml
      ("beloch:inspect", beloch_inspect_json disp fd.Eval.named_points);
```

Confirm `fd.Eval.named_points` is the `(string * Geom.point * int) list` field (it is — see `Eval.folded`).

- [ ] **Step 6: Run test to verify it passes**

Run: `dune test 2>&1 | rg -A3 inspect`
Expected: PASS. If the fixture assertion counts are off, read the actual emitted JSON with `beloch fold packages/core/tests/cases/inspect/two-segment-crease.bel | python3 -m json.tool | rg -A30 'beloch:inspect'` and adjust the fixture/asserts.

- [ ] **Step 7: Commit**

```bash
git add packages/core/lib/fold_emit.ml packages/core/tests/test_e2e.ml packages/core/tests/cases/inspect/
git commit -m "feat(core): beloch:inspect export (crease segments, face rank/flap, point face)"
```

---

### Task 3: Scene parses `beloch:inspect` + edge `crease_id`

Surface the new core data on the `FoldScene` so the renderer and playground can read it.

**Files:**
- Modify: `packages/render-2d/scene/src/types.ts` (add `Inspect` types; add `creaseId` to `EdgeProvenance`; add `inspect` to `FoldScene`)
- Modify: `packages/render-2d/scene/src/parse.ts` (parse both)
- Test: `packages/render-2d/scene/test/parse.test.ts` (create if absent; otherwise the nearest existing scene test)

**Interfaces:**
- Consumes: FOLD keys `beloch:inspect` and `beloch:edges[i].crease_id` from Task 1/2.
- Produces: `FoldScene.inspect: Inspect | null`; `EdgeProvenance.creaseId: number | null`. Types:

```ts
export interface InspectSegment { faces: [number, number]; paper: [Vec2, Vec2]; table: [Vec2, Vec2]; assignment: string }
export interface InspectCrease { name: string | null; axiom: string | null; sources: string[]; span: string | null; segments: InspectSegment[] }
export interface InspectFace { vertices: Vec2[]; flap: number; rank: number }
export interface Inspect {
  creases: Record<string, InspectCrease>;
  faces: Record<string, InspectFace>;
  points: Record<string, { face: number | null; flap: number | null }>;
}
```

- [ ] **Step 1: Write the failing test**

Create `packages/render-2d/scene/test/parse.test.ts` (mirror the import/parse style of the existing scene tests — check a sibling test for the exact `parseFold`/`parseScene` entry name):

```ts
import { expect, test } from "bun:test";
import { parseFold } from "../src";

const fold = {
  vertices_coords: [], edges_vertices: [], edges_assignment: [], faces_vertices: [],
  "beloch:edges": [{ axiom: "axiom2", sources: [".a", ".d"], span: "x:2:1", name: "h", crease_id: 4 }],
  "beloch:inspect": {
    creases: { "4": { name: "h", axiom: "axiom2", sources: ["--h"], span: "x:2:1",
      segments: [{ faces: [0, 1], paper: [[0, 0.5], [1, 0.5]], table: [[0, 0.5], [1, 0.5]], assignment: "V" }] } },
    faces: { "0": { vertices: [[0, 0], [1, 0], [1, 1], [0, 1]], flap: 0, rank: 1 } },
    points: { a: { face: 0, flap: 0 } },
  },
};

test("parse surfaces inspect and edge crease id", () => {
  const scene = parseFold(fold as any);
  expect(scene.inspect?.creases["4"].segments[0].assignment).toBe("V");
  expect(scene.inspect?.faces["0"].rank).toBe(1);
  expect(scene.cp.edgesProvenance[0]?.creaseId).toBe(4);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/render-2d/scene && bun test parse.test.ts`
Expected: FAIL — `inspect` undefined / `creaseId` undefined.

- [ ] **Step 3: Add the types**

In `packages/render-2d/scene/src/types.ts` add the interfaces above. Add `creaseId: number | null` to `EdgeProvenance`. Add `inspect: Inspect | null` to `FoldScene`.

- [ ] **Step 4: Parse them**

In `parse.ts`, where `beloch:edges` is read (~13) map each entry's `crease_id` into `creaseId` (`(e?.crease_id ?? null)`). Add a top-level parse:

```ts
const inspect = (fold["beloch:inspect"] ?? null) as Inspect | null;
```

and include `inspect` in the returned `FoldScene`. Export the new types from `packages/render-2d/scene/src/index.ts`.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/render-2d/scene && bun test parse.test.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/render-2d/scene/src packages/render-2d/scene/test/parse.test.ts
git commit -m "feat(scene): parse beloch:inspect + edge crease_id"
```

---

### Task 4: Render stamps `data-*` identity onto SVG

Give every inspectable element a stable attribute so pointer events map back to entities, in both CP and folded output.

**Files:**
- Modify: `packages/render-2d/render-svg/src/render-scene.ts` (crease `<line>` ~192-201; point `<circle>` emission; face polygon already has `data-face-index` ~115)
- Test: `packages/render-2d/render-svg/test/render-scene.test.ts` (or `render-cp.test.ts`)

**Interfaces:**
- Consumes: `frame.edgesProvenance[i].creaseId` (Task 3).
- Produces: crease lines carry `data-crease-id`; point circles carry `data-vertex`. Face polygons keep `data-face-index`. (No `data-seg`: folded rendering can split one physical segment into several drawn arcs, so a per-line ordinal cannot equal the `beloch:inspect` segment index. Task 7 highlights a chosen segment by matching its table endpoints to drawn lines instead — geometry, not an index.)

- [ ] **Step 1: Write the failing test**

Add to `packages/render-2d/render-svg/test/render-scene.test.ts` a test that renders a scene with a named crease and asserts the attribute appears:

```ts
test("crease lines carry data-crease-id", () => {
  const svg = renderCP(sceneWithCrease, { theme: WEB_THEME }).toString();
  expect(svg).toContain("data-crease-id=");
  expect(svg).toContain("data-seg=");
});
```

Use whatever fixture the sibling tests already load (grep the file for an existing `renderCP(` call and reuse that scene; it must have at least one non-boundary crease with a `creaseId`).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/render-2d/render-svg && bun test render-scene.test.ts`
Expected: FAIL — attribute absent.

- [ ] **Step 3: Stamp the crease attributes**

In `render-scene.ts`, the crease `<line>` `attrs` object (~192) currently sets `class`, `data-kind`, and conditionally `data-name`. Alongside, thread the crease id and a per-bundle segment counter. Before the edge loop add:

```ts
const segCounter = new Map<number, number>();
```

Inside the loop, after computing `const prov = frame.edgesProvenance[i]`, and where `attrs` is built:

```ts
        const cid = prov?.creaseId ?? null;
        if (cid !== null) {
          const seg = segCounter.get(cid) ?? 0;
          segCounter.set(cid, seg + 1);
          attrs["data-crease-id"] = cid;
          attrs["data-seg"] = seg;
        }
```

(If `prov` is not already in scope at that point, read it from `frame.edgesProvenance[i]` — the same array `data-name` is derived from.)

- [ ] **Step 4: Stamp point vertices**

Locate the named-point `<circle>` emission (the annotations layer draws named vertices; grep `data-bel-name` in this file). Where a circle is emitted for vertex index `vi`, add `"data-vertex": vi`. If the circle already carries `data-bel-name`, keep it; add `data-vertex` for unnamed vertices too.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/render-2d/render-svg && bun test render-scene.test.ts`
Expected: PASS. Snapshot tests in this package will change — review the diff and update snapshots with `bun test -u` once the new `data-*` attributes are confirmed correct.

- [ ] **Step 6: Commit**

```bash
git add packages/render-2d/render-svg/src/render-scene.ts packages/render-2d/render-svg/test
git commit -m "feat(render): stamp data-crease-id/data-seg/data-vertex for inspection"
```

---

### Task 5: Playground inspector panel (hover + click)

Add the detail panel and wire pointer events on the rendered SVG to it.

**Files:**
- Modify: `packages/www/src/components/Playground.astro` (markup near `.pg-result` ~47; CSS; the `<script type="module">` — event wiring near the pan/zoom handlers ~542, and `currentScene` ~714)
- Test: manual verification (playground has no DOM test harness; keep a scripted smoke check)

**Interfaces:**
- Consumes: `currentScene.inspect` (Task 3); `data-crease-id`/`data-seg`/`data-face-index`/`data-vertex` on SVG (Task 4).
- Produces: an `#pg-inspect` panel DOM region; a `lookupEntity(el: Element): EntityRef | null` helper; a `renderInspect(ref: EntityRef | null)` function.

- [ ] **Step 1: Add the panel markup + CSS**

In the `.pg-result` pane, add a panel container:

```html
<aside class="pg-inspect" id="pg-inspect" hidden></aside>
```

CSS (match the existing notice/panel styling in this file — reuse `var(--beloch-*)` tokens):

```css
.pg-inspect { position: absolute; top: 8px; right: 8px; max-width: 320px; max-height: 70%;
  overflow: auto; background: var(--beloch-surface); border: 1px solid var(--beloch-border);
  border-radius: 6px; padding: 10px 12px; font: 12px/1.5 ui-monospace, monospace; }
.pg-inspect[hidden] { display: none; }
.pg-inspect h4 { margin: 0 0 6px; font-size: 12px; }
.pg-inspect .seg { border-top: 1px solid var(--beloch-border); padding-top: 4px; margin-top: 4px; }
```

- [ ] **Step 2: Write the entity lookup + render**

In the module script, after `currentScene` is declared (~714), add:

```ts
type EntityRef =
  | { kind: "crease"; creaseId: string }
  | { kind: "face"; index: string }
  | { kind: "vertex"; index: number };

function lookupEntity(el: Element): EntityRef | null {
  const line = el.closest("[data-crease-id]");
  if (line) return { kind: "crease", creaseId: line.getAttribute("data-crease-id")! };
  const face = el.closest("[data-face-index]");
  if (face) return { kind: "face", index: face.getAttribute("data-face-index")! };
  const vert = el.closest("[data-vertex]");
  if (vert) return { kind: "vertex", index: Number(vert.getAttribute("data-vertex")) };
  return null;
}

const inspectPanel = root.querySelector<HTMLElement>("#pg-inspect")!;

function renderInspect(ref: EntityRef | null) {
  const insp = currentScene?.inspect;
  if (!ref || !insp) { inspectPanel.hidden = true; return; }
  let html = "";
  if (ref.kind === "crease") {
    const c = insp.creases[ref.creaseId];
    if (!c) { inspectPanel.hidden = true; return; }
    const title = c.name ? `--${c.name}` : `crease #${ref.creaseId}`;
    html = `<h4>${escapeHtml(title)}</h4><div>${escapeHtml(c.axiom ?? "")} · from ${c.sources.map(escapeHtml).join(" ")}</div>`;
    html += c.segments.map((s, i) =>
      `<div class="seg">seg ${i} · face ${s.faces[0]}|${s.faces[1]} · ${s.assignment}<br>`
      + `paper ${fmtPt(s.paper[0])}→${fmtPt(s.paper[1])}<br>table ${fmtPt(s.table[0])}→${fmtPt(s.table[1])}</div>`).join("");
  } else if (ref.kind === "face") {
    const f = insp.faces[ref.index];
    if (!f) { inspectPanel.hidden = true; return; }
    html = `<h4>face ${ref.index}</h4><div>flap ${f.flap} · rank ${f.rank}</div>`;
  } else {
    const name = Object.keys(insp.points).find((n) => insp.points[n] && vertexIndexOfPoint(n) === ref.index);
    const p = name ? insp.points[name] : null;
    html = `<h4>${name ? "." + escapeHtml(name) : "vertex " + ref.index}</h4>` + (p ? `<div>face ${p.face ?? "—"} · flap ${p.flap ?? "—"}</div>` : "");
  }
  inspectPanel.innerHTML = html;
  inspectPanel.hidden = false;
}

const fmtPt = (p: [number, number]) => `(${p[0].toFixed(3)}, ${p[1].toFixed(3)})`;
```

`escapeHtml` already exists in this file (used by `showNotice`). For `vertexIndexOfPoint`, map a point name to its rendered vertex index via the `data-bel-name` attribute already emitted; if that lookup is awkward, drop the name resolution and just show `vertex N` — point-name resolution is a nice-to-have, not load-bearing for B.

- [ ] **Step 3: Wire pointer events**

The pan/zoom handlers live on `viewport` (~542-590). Add click + hover delegation on the SVG without breaking panning (only act when the target is an entity, and only on a click that did not drag):

```ts
viewport.addEventListener("mousemove", (e) => {
  const ref = lookupEntity(e.target as Element);
  // hover preview only when nothing is pinned
  if (!pinned) renderInspect(ref);
});
viewport.addEventListener("click", (e) => {
  const ref = lookupEntity(e.target as Element);
  pinned = ref;
  renderInspect(ref);
});
```

Declare `let pinned: EntityRef | null = null;` near `currentScene`. Guard against drags: reuse the existing drag-detection flag the pan handler already sets (grep for the `pointerdown`→`pointermove` distance/`isPanning` guard) so a pan gesture does not register as an entity click.

- [ ] **Step 4: Reset on re-eval**

Where `currentScene` is cleared / a new result is shown (~775), set `pinned = null; inspectPanel.hidden = true;` so stale entities do not linger across runs.

- [ ] **Step 5: Manual verification**

Run: `cd packages/www && bun run dev` (or the repo's playground dev command — check `packages/www/package.json` scripts). Load the peacock model (trimmed to the `fold --r = ...` line so it evaluates), switch to folded view, click the `--r` crease. Confirm the panel lists its segments with face pairs and assignments. Click a face → flap + rank shown.

- [ ] **Step 6: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "feat(playground): entity inspector panel (hover + click)"
```

---

### Task 6: Bidirectional code ↔ SVG highlight (read-only)

Clicking an entity highlights its source span in the editor; moving the editor cursor highlights the entities on that line in the SVG.

**Files:**
- Modify: `packages/www/src/components/Playground.astro` (reuse the existing `setStepLineOn(editor, ...)` decoration mechanism ~648/778; the `EditorView.updateListener` ~667)

**Interfaces:**
- Consumes: entity spans — crease spans from `currentScene.inspect.creases[id].span`; edge/statement spans already in the FOLD; the `pinned` ref (Task 5).
- Produces: on entity click, editor scrolls to + highlights the span's line; on cursor move, SVG elements whose crease span covers the cursor line get a `.pg-hl` outline class.

- [ ] **Step 1: Entity click → editor line highlight**

Extend the click handler from Task 5. After `renderInspect(ref)`, if `ref` is a crease, parse the line number out of its span (format `file:line:col-col`, as produced by `Error.span_to_string`) and reuse `setStepLineOn`:

```ts
function lineOfSpan(span: string | null): number | null {
  const m = span?.match(/:(\d+):/);
  return m ? Number(m[1]) : null;
}
// in click handler:
if (ref?.kind === "crease") {
  const ln = lineOfSpan(currentScene?.inspect?.creases[ref.creaseId]?.span ?? null);
  if (ln) { setStepLineOn(editor, ln); editor.dispatch({ effects: EditorView.scrollIntoView(editor.state.doc.line(ln).from) }); }
}
```

Confirm `setStepLineOn`'s signature (grep its definition ~648) — if it takes a 0-based index or a different shape, adapt the call. If it is too coupled to the step player to reuse, add a sibling `setHlLineOn(editor, line)` modeled on it (same `StateField`/`Decoration.line` pattern).

- [ ] **Step 2: Cursor → SVG entity highlight**

In the existing `EditorView.updateListener` (~667), on `update.selectionSet`, compute the cursor line and outline matching creases:

```ts
if (update.selectionSet) {
  const line = editor.state.doc.lineAt(editor.state.selection.main.head).number;
  const insp = currentScene?.inspect;
  root.querySelectorAll(".pg-hl").forEach((el) => el.classList.remove("pg-hl"));
  if (insp) for (const [cid, c] of Object.entries(insp.creases)) {
    if (lineOfSpan(c.span) === line)
      root.querySelectorAll(`[data-crease-id="${cid}"]`).forEach((el) => el.classList.add("pg-hl"));
  }
}
```

Add CSS: `.pg-hl { stroke: var(--beloch-accent); stroke-width: 4; }`.

- [ ] **Step 3: Manual verification**

Run the dev server. Click `--r` → the `fold --r = ...` line highlights and scrolls into view. Put the cursor on that line → the `--r` segments outline in the SVG.

- [ ] **Step 4: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "feat(playground): bidirectional code<->SVG entity highlight"
```

---

### Task 7: Folded-view stack picker

When a folded-view click lands where segments coincide, list them ordered by `rank` and let the user pick a layer.

**Files:**
- Modify: `packages/www/src/components/Playground.astro` (extend `renderInspect` / the click handler)

**Interfaces:**
- Consumes: `currentScene.inspect.creases[*].segments` + `currentScene.inspect.faces[*].rank`; the current view mode (CP vs folded — grep for how the playground tracks the active view / `renderStep`).
- Produces: when >1 segment renders at the clicked table point, the panel shows a rank-ordered list; clicking a row focuses that segment (sets `pinned` to a specific `seg`).

- [ ] **Step 1: Detect coincident segments on a folded click**

Only in folded view. On a crease click, gather all segments of that bundle whose `table` midpoint is within an epsilon of the clicked table coordinate (convert the click's SVG point to table space using the same transform the renderer uses; if that is heavy, approximate by "all segments of the bundle" — the panel already lists them, so the picker just needs ordering). Compute each segment's rank as `max(faces rank)`:

```ts
function segRank(insp: Inspect, s: InspectSegment): number {
  return Math.max(insp.faces[String(s.faces[0])]?.rank ?? 0, insp.faces[String(s.faces[1])]?.rank ?? 0);
}
```

- [ ] **Step 2: Render the picker ordered by rank**

In `renderInspect` for a crease, when in folded view sort the segment list by `segRank` descending (top of stack first) and render each row clickable:

```ts
const inFolded = currentViewIsFolded(); // grep the playground's view-state accessor
const segs = c.segments.map((s, i) => ({ s, i }));
if (inFolded) segs.sort((a, b) => segRank(insp, b.s) - segRank(insp, a.s));
html += segs.map(({ s, i }) =>
  `<div class="seg" data-pick-seg="${i}">seg ${i} · rank ${segRank(insp, s)} · face ${s.faces[0]}|${s.faces[1]} · ${s.assignment}</div>`).join("");
```

Add a delegated click on `.pg-inspect [data-pick-seg]` that reads the inspect segment `s = c.segments[Number(dataset.pickSeg)]` and highlights the drawn line(s) belonging to it by GEOMETRY, not a `data-seg` index: among `[data-crease-id="<creaseId>"]` lines, add `.pg-hl` to those whose endpoints match `s.table[0]`/`s.table[1]` within an epsilon (a segment split into several occluded arcs matches several lines — highlight all). Compare in the SVG's own coordinate space (the lines' `x1/y1/x2/y2` are in the rendered table→SVG frame; transform `s.table` through the same layout transform the renderer used, or compare against the untransformed table coords if the lines expose them — pick whichever the render actually emits and note it).

- [ ] **Step 3: CP view unchanged**

Confirm that in CP view the segment list renders unsorted (segments are spatially separate there, no picker semantics needed) — i.e. the `inFolded` guard leaves CP behavior as Task 5 shipped it.

- [ ] **Step 4: Manual verification**

Load a model whose folded state stacks a crease across layers (peacock `--r` after its fold). Folded view → click the stack → panel lists segments top→bottom by rank → clicking a row outlines exactly that layer's segment.

- [ ] **Step 5: Commit**

```bash
git add packages/www/src/components/Playground.astro
git commit -m "feat(playground): rank-ordered stack picker (folded view)"
```

---

## Self-Review

**Spec coverage:**
- `beloch:inspect` (creases/faces/points) → Task 2. ✓
- per-face `rank` → segment layer identity → Task 2 (rank in faces) + Task 7 (picker uses it). ✓
- `crease_id` on `beloch:edges` → Task 1. ✓
- render data-attr stamping → Task 4. ✓
- hover + click-pin side panel → Task 5. ✓
- folded stack picker + CP-no-picker → Task 7. ✓
- read-only bidirectional code↔SVG highlight → Task 6. ✓
- Non-goals (no write, no partial-eval, no new view, no server) → nothing in the plan violates them. ✓
- Testing anchors (core assertion on segments/faces/flap/rank; render snapshot for data-attrs; UI smoke) → Tasks 2, 4, 5-manual. ✓

**Placeholder scan:** No "TBD"/"handle edge cases" left. The few "grep for the exact name" notes point at a specific existing symbol to confirm a signature (`setStepLineOn`, `parseFold`, the view-state accessor) rather than deferring design — acceptable, since the surrounding code is concrete.

**Type consistency:** `EntityRef`, `Inspect*` interfaces, `creaseId`, `data-crease-id`/`data-seg`/`data-vertex`, `renderInspect`/`lookupEntity`/`segRank`/`lineOfSpan` names are used identically across Tasks 3-7. Core field names (`crease_id`, `faces`, `pa/pb/ta/tb`, `rank`, `coplanar_clusters`) match the verified `Fold_state` signatures.

**Risk note (call out at execution):** Task 5-7 tests are manual — the playground has no DOM harness. If a headless check is wanted, add a Bun test that imports `lookupEntity`/`renderInspect` against a fake DOM; otherwise verify in the dev server as written.
