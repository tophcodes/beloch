# Emit per-face isometries and declare the named-line frame — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Emit each face's paper→table isometry and an explicit named-line frame into the FOLD, then port `fold2svg` to consume the isometry instead of reconstructing it from float vertex pairs.

**Architecture:** Emit-only change in `lib/fold_emit.ml` (per folded frame + one top-level key), then a rendering-only change in `tools/fold2svg.mjs`. No kernel change. The two sides share one contract: `beloch:faces_matrix[fi]` is the paper→table isometry of face `fi`, and `beloch:named_lines` coefficients live in the `creasePattern` (paper) frame.

**Tech Stack:** OCaml (dune, Yojson, Alcotest), JavaScript (Bun, `bun:test`).

**Spec:** `docs/superpowers/specs/2026-07-03-fold-isometry-emission-design.md`. For [#31](https://git.toph.so/toph/beloch/issues/31).

## Global Constraints

- **Encoding:** each `beloch:faces_matrix` row is a flat 6-float array `[m00, m01, m10, m11, tx, ty]`, in `Isometry.t` field order, all via `Num.to_float` (`q_to_json`). Never `{m, t}`.
- **Row order:** `beloch:faces_matrix` rows are in the same order as that frame's `faces_vertices` (both derive from `state.faces`), so row index == face index.
- **Frame value:** `beloch:named_lines_frame` is the exact string `"creasePattern"`.
- **Golden discipline:** goldens are compared byte-for-byte and carry **no** trailing newline (`tests/golden/square.fold` ends with `}`). Regenerate them with an OCaml tool mirroring `tests/test_golden.ml`'s `fold_of` exactly — never via `beloch fold` redirection (its `print_endline` appends `\n`). The two ERROR goldens (`dup-point.fold`, `parallel.fold`) must stay unchanged.
- **Out of scope:** exact coordinates (rational strings / minpoly + interval). Float only.

---

### Task 1: Emit `beloch:faces_matrix` and `beloch:named_lines_frame`

**Files:**
- Modify: `lib/fold_emit.ml` (function `folded_frame_of_state`, ~lines 121-133; top-level `` `Assoc `` in `to_json_folded`, ~lines 253-270)
- Test: `tests/test_e2e.ml` (add one test case + register it)
- Create: `scratch/regen.ml`
- Modify: `scratch/dune`
- Regenerate: `tests/golden/*.fold` (successful examples only)

**Interfaces:**
- Produces: the folded frame gains `"beloch:faces_matrix": [[m00,m01,m10,m11,tx,ty], ...]` (one row per face, face-index aligned). The top-level object gains `"beloch:named_lines_frame": "creasePattern"`. `tools/fold2svg.mjs` (Task 2) consumes both.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_e2e.ml` (mirrors the existing `test_e2e_square_one_face` style — `square.bel` folds to a single face with the identity isometry):

```ocaml
let test_e2e_faces_matrix_and_frame () =
  let json =
    Beloch.fold_string ~filename:"square.bel" (read_example "square.bel")
  in
  let open Yojson.Safe.Util in
  (* named-line frame is declared, always *)
  Alcotest.(check string) "named-line frame"
    "creasePattern"
    (json |> member "beloch:named_lines_frame" |> to_string);
  (* the one folded frame carries one isometry row, the identity *)
  let rows =
    json |> member "file_frames" |> to_list |> List.hd
    |> member "beloch:faces_matrix" |> to_list
  in
  Alcotest.(check int) "one isometry row" 1 (List.length rows);
  Alcotest.(check (list (float 1e-9))) "identity isometry"
    [ 1.; 0.; 0.; 1.; 0.; 0. ]
    (List.hd rows |> to_list |> List.map to_float)
```

Register it in the test list in the same file (find the `Alcotest.test_case "e2e ..."` list and add):

```ocaml
    Alcotest.test_case "e2e faces_matrix + frame" `Quick
      test_e2e_faces_matrix_and_frame;
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `dune test 2>&1 | rg -A3 "faces_matrix"`
Expected: FAIL — `beloch:named_lines_frame` / `beloch:faces_matrix` members are `` `Null ``, so `to_string` / `to_list` raise or the row count is 0.

- [ ] **Step 3: Emit `beloch:faces_matrix` per folded frame**

In `lib/fold_emit.ml`, inside `folded_frame_of_state`, just before the final `` `Assoc `` (currently line ~121), build the rows from the already-bound `faces`:

```ocaml
  let beloch_faces_matrix =
    Array.to_list faces
    |> List.map (fun (f : Fold_state.face) ->
        let i = f.Fold_state.iso in
        `List
          [ q_to_json i.Isometry.m00; q_to_json i.Isometry.m01;
            q_to_json i.Isometry.m10; q_to_json i.Isometry.m11;
            q_to_json i.Isometry.tx;  q_to_json i.Isometry.ty ])
  in
```

Then add this entry to that frame's `` `Assoc `` list, immediately after the `("faces_vertices", `List faces_vertices);` line:

```ocaml
      ("beloch:faces_matrix", `List beloch_faces_matrix);
```

- [ ] **Step 4: Emit `beloch:named_lines_frame` top-level**

In `to_json_folded`, in the top-level `` `Assoc `` list, immediately after the `("beloch:named_lines", beloch_named_lines);` line, add:

```ocaml
      ("beloch:named_lines_frame", `String "creasePattern");
```

- [ ] **Step 5: Run the new test to verify it passes**

Run: `dune fmt 2>&1; dune build 2>&1 && dune exec tests/test_e2e.exe 2>&1 | tail -5`
Expected: the `faces_matrix + frame` case PASSES. The golden suite will still fail — that is Step 8.

- [ ] **Step 6: Add the golden regeneration tool**

Create `scratch/regen.ml` — a byte-for-byte mirror of `tests/test_golden.ml`'s `fold_of` (same pretty-printer, same error capture, so ERROR goldens are reproduced identically and successful ones differ only by the two new keys):

```ocaml
(* Regenerate tests/golden/*.fold. Run from the repo root:
   dune exec scratch/regen.exe *)
open Beloch

let () =
  let dir = "examples/" and out = "tests/golden/" in
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun n -> Filename.check_suffix n ".bel")
  |> List.iter (fun name ->
         let src = In_channel.with_open_text (dir ^ name) In_channel.input_all in
         let body =
           try Yojson.Safe.pretty_to_string (Beloch.fold_string ~filename:name src)
           with Error.Beloch_error (_, msg) -> "ERROR: " ^ msg
         in
         let path = out ^ Filename.chop_suffix name ".bel" ^ ".fold" in
         Out_channel.with_open_text path (fun oc ->
             Out_channel.output_string oc body))
```

Add a stanza to `scratch/dune` (it uses explicit `(modules ...)` per executable):

```
(executable
 (name regen)
 (modules regen)
 (libraries beloch))
```

- [ ] **Step 7: Regenerate the goldens**

Run (from repo root): `dune exec scratch/regen.exe`
Then confirm only additive changes and the two ERROR goldens untouched:

Run: `git diff --stat tests/golden/ && git status --porcelain tests/golden/dup-point.fold tests/golden/parallel.fold`
Expected: successful `.fold` files show insertions only (the two new keys); `dup-point.fold` and `parallel.fold` appear with **no** changes.

- [ ] **Step 8: Run the full suite**

Run: `dune test 2>&1 | tail -5`
Expected: PASS (golden suite green against regenerated files, `test_e2e` green).

- [ ] **Step 9: Commit**

```bash
git add lib/fold_emit.ml tests/test_e2e.ml scratch/regen.ml scratch/dune tests/golden/
git commit -m "feat(fold): emit per-face isometries and declare the named-line frame

For #31.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016FYbXyypfVm4RdPLGBdWYw"
```

---

### Task 2: Port fold2svg onto the emitted isometry

**Files:**
- Modify: `tools/fold2svg.mjs` (add exported `applyM`; overlay setup ~line 355; delete `sa2`/`applyIso` ~lines 383-395; folded-view loop ~lines 408-416)
- Test: `tools/test/foldview.test.mjs`

**Interfaces:**
- Consumes: `beloch:faces_matrix` from the (merged) folded frame — `frame["beloch:faces_matrix"][fi]` is `[m00,m01,m10,m11,tx,ty]`.
- Produces: exported `applyM(row, px, py) => [x, y]`.

- [ ] **Step 1: Write the failing test**

Add to `tools/test/foldview.test.mjs`. Extend the existing import line to include `applyM`, then add:

```js
test("applyM maps a paper point through a face isometry row", () => {
  expect(applyM([1, 0, 0, 1, 0, 0], 3, 4)).toEqual([3, 4]);        // identity
  expect(applyM([-1, 0, 0, 1, 2, 0], 3, 4)).toEqual([-1, 4]);      // reflect x, shift +2
  expect(applyM([0, -1, 1, 0, 0, 0], 1, 0)).toEqual([0, 1]);       // 90° rotation
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bun test tools/test/foldview.test.mjs 2>&1 | tail -6`
Expected: FAIL — `applyM` is not exported (`undefined`).

- [ ] **Step 3: Add the exported helper**

In `tools/fold2svg.mjs`, in the module-level pure-helpers region (next to `signedArea`, ~line 11-24), add:

```js
// Map a paper point [px,py] to table space via a face's paper→table isometry
// row [m00,m01,m10,m11,tx,ty]. The reflection is already in the row's det sign.
export const applyM = ([a, b, c, d, tx, ty], px, py) => [a * px + b * py + tx, c * px + d * py + ty];
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bun test tools/test/foldview.test.mjs 2>&1 | tail -6`
Expected: the `applyM` case PASSES.

- [ ] **Step 5: Delete the reconstruction and rewire the loop**

In `tools/fold2svg.mjs`, delete the local `sa2` (line ~383) and the whole `applyIso` definition (lines ~385-395).

In the construction-overlay setup (near `const rootV = ...`, ~line 355), add:

```js
    const FM = frame["beloch:faces_matrix"] || [];
```

Replace the folded-view loop body (currently ~lines 408-416, the `for (const face of F)` block) with:

```js
          for (let fi = 0; fi < F.length; fi++) {
            const M = FM[fi];
            if (!M) continue;
            const papPoly = F[fi].map(vi => rootV[vi]);
            const seg = clipLineToPoly(la, lb, lc, papPoly);
            if (!seg) continue;
            const [t1, t2] = seg.map(([ppx, ppy]) => applyM(M, ppx, ppy));
            g.push(`<line x1="${tx(t1[0])}" y1="${ty(t1[1])}" x2="${tx(t2[0])}" y2="${ty(t2[1])}" stroke="${CON_LN}" stroke-width="1.5" stroke-dasharray="6 3" opacity="0.8"/>`);
            drawn.push([t1, t2]);
          }
```

- [ ] **Step 6: Run the full JS suite (no regression on untouched paths)**

Run: `bun test 2>&1 | tail -8`
Expected: PASS. The existing overlay/step/occlusion tests are unaffected (they render default or top view over fields we did not change).

- [ ] **Step 7: Manual folded-overlay spot check**

Confirm the dashed construction line still lands on the folded faces, using a regenerated golden that has a folded frame + a named line (e.g. `bisect-intermediate` or `multiple-folds`):

```bash
git stash
bun tools/fold2svg.mjs tests/golden/multiple-folds.fold /tmp/before.svg --view top
git stash pop
dune exec scratch/regen.exe   # ensure the golden carries beloch:faces_matrix
bun tools/fold2svg.mjs tests/golden/multiple-folds.fold /tmp/after.svg --view top
```

Expected: the construction overlay in `/tmp/after.svg` matches `/tmp/before.svg` up to sub-pixel differences (the reconstruction epsilons are gone). Open both to eyeball.

- [ ] **Step 8: Commit**

```bash
git add tools/fold2svg.mjs tools/test/foldview.test.mjs
git commit -m "feat(fold2svg): consume emitted face isometries, drop float reconstruction

For #31.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016FYbXyypfVm4RdPLGBdWYw"
```

---

## Self-Review

**Spec coverage:**
- Emit per-face isometry → Task 1 Step 3. ✓
- Declare named-line frame → Task 1 Step 4. ✓
- Port fold2svg / delete reconstruction → Task 2 Steps 3, 5. ✓
- Golden regeneration, ERROR goldens untouched → Task 1 Steps 6-8. ✓
- fold2svg visual identity → Task 2 Step 7. ✓
- Out of scope (exact coords) → not implemented, by design. ✓

**Type consistency:** `beloch:faces_matrix` row is `[m00,m01,m10,m11,tx,ty]` in both the emitter (Task 1 Step 3) and consumer (`applyM`, Task 2 Step 3). Face-index alignment stated in Global Constraints and relied on in Task 2's `FM[fi]` / `F[fi]`. Frame string `"creasePattern"` identical in emitter and spec.

**Placeholder scan:** none — every code step carries full code and exact commands.
