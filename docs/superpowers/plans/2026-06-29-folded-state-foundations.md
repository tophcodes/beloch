# Folded-State Foundations Implementation Plan (Plan B-1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the exact, pure geometric primitives for flat folding — reflection, 2D isometries, convex half-plane clipping, and the folded-state data model with the simple-fold operation — all unit-tested in isolation, with no evaluator or output wiring yet.

**Architecture:** Four pure modules/extensions added bottom-up: `Geom` reflection + side test + convex clip/containment; a new `Isometry` module (2×2 orthogonal matrix + translation in `Num`); a new `Fold_state` module holding faces (paper polygon + isometry) and a global layer order, with `simple_fold` (split → reflect → restack) and material-point resolution. Everything stays exact in `Num`; no floating point, no 3D.

**Tech Stack:** OCaml, dune, `Num` (exact constructible reals), zarith, alcotest.

## Slice decomposition (context)

This is **Plan B-1** of the folded-state engine (design: `docs/superpowers/specs/2026-06-29-folded-state-engine-design.md`). It ships the pure primitives as a library foundation (no user-facing behaviour change yet — `@` folds still raise "not yet implemented" from `eval`). **Plan B-2** (the fold evaluator wiring `Ast.fold_spec` into `eval`, the dual `creasePattern` + `foldedForm` output, derived mountain/valley) is written separately, against these landed foundations. Precedent: the exact-reals `Num` slice (PR #2) landed as a foundation before axiom 5 consumed it.

## Global Constraints

- Build with `dune build`; test with `dune test`. Warnings are fatal in the dev profile — builds must be clean (no unused bindings).
- Code must be ocamlformat-clean (`.ocamlformat`: version 0.29.0, profile default). Run `dune fmt` before each commit.
- **All geometry exact via `Num` — no floating point anywhere in these modules.** `Num` API used here: `of_int`, `add`, `sub`, `mul`, `div`, `neg`, `sign`, `equal`, `compare`, `zero`, `one` (all in `lib/num.ml`).
- New library modules are picked up automatically by `lib/dune` (no module list), but the `beloch.ml` facade must re-export each new top-level module with `module X = X` or tests can't reach `Beloch.X` (see `antipatterns.md` — the dune facade re-export rule).
- Faces are **convex CCW** polygons (`Geom.point array`); the square is convex, straight-line clipping and reflection preserve convexity and orientation.
- Commits: Conventional Commits; end the body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

Existing types (do not redefine): `Geom.point = { x : Num.t; y : Num.t }`, `Geom.line = { a : Num.t; b : Num.t; c : Num.t }` (means `a·x + b·y = c`). Test helpers already in `tests/test_beloch.ml`: `let q = Num.of_int`, `let pt x y = { Geom.x = q x; y = q y }`, `let half = Num.of_q (Q.of_ints 1 2)`.

---

### Task 1: `Geom` — reflection and side-of-line

**Files:**
- Modify: `lib/geom.ml` (append two functions)
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Produces:
  - `Geom.reflect_point : line -> point -> point` — mirror `p` across the line.
  - `Geom.side_of_line : line -> point -> int` — `sign (a·px + b·py − c)`: `+1`/`−1` for the two sides, `0` on the line.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_beloch.ml` (after `test_parallel_midline`):

```ocaml
let test_reflect_point () =
  (* mirror line x = 1/2 is a=1,b=0,c=1/2 *)
  let l = { Geom.a = q 1; b = q 0; c = half } in
  Alcotest.(check bool) "(0,0) -> (1,0)" true
    (Geom.point_equal (Geom.reflect_point l (pt 0 0)) (pt 1 0));
  Alcotest.(check bool) "reflection is an involution" true
    (Geom.point_equal (Geom.reflect_point l (Geom.reflect_point l (pt 0 0))) (pt 0 0));
  Alcotest.(check bool) "a point on the line is fixed" true
    (Geom.point_equal (Geom.reflect_point l { Geom.x = half; y = q 7 }) { Geom.x = half; y = q 7 })

let test_side_of_line () =
  let l = { Geom.a = q 1; b = q 0; c = half } in
  Alcotest.(check int) "right of x=1/2 is +1" 1 (Geom.side_of_line l (pt 1 0));
  Alcotest.(check int) "left of x=1/2 is -1" (-1) (Geom.side_of_line l (pt 0 0));
  Alcotest.(check int) "on x=1/2 is 0" 0 (Geom.side_of_line l { Geom.x = half; y = q 9 })
```

Register them in a new `"fold_geom"` group in the `Alcotest.run` list:

```ocaml
      ("fold_geom",
       [ Alcotest.test_case "reflect point" `Quick test_reflect_point;
         Alcotest.test_case "side of line" `Quick test_side_of_line ]);
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `Unbound value Geom.reflect_point`.

- [ ] **Step 3: Implement in `lib/geom.ml`**

Append at the end of the file:

```ocaml
(* signed side of a point: sign (a·px + b·py − c). 0 means on the line. *)
let side_of_line (l : line) (p : point) : int =
  Num.sign (Num.sub (Num.add (Num.mul l.a p.x) (Num.mul l.b p.y)) l.c)

(* reflect p across a·x + b·y = c:  p − 2·(a·px+b·py−c)/(a²+b²)·(a,b). Exact, no sqrt. *)
let reflect_point (l : line) (p : point) : point =
  let n2 = Num.add (Num.mul l.a l.a) (Num.mul l.b l.b) in
  let d = Num.sub (Num.add (Num.mul l.a p.x) (Num.mul l.b p.y)) l.c in
  let k = Num.div (Num.mul (Num.of_int 2) d) n2 in
  { x = Num.sub p.x (Num.mul k l.a); y = Num.sub p.y (Num.mul k l.b) }
```

- [ ] **Step 4: Run to verify they pass**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS (all cases green, build clean).

- [ ] **Step 5: Commit**

```bash
git add lib/geom.ml tests/test_beloch.ml
git commit -m "feat(geom): exact point reflection and side-of-line

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `Isometry` module

**Files:**
- Create: `lib/isometry.ml`
- Modify: `lib/beloch.ml` (add `module Isometry = Isometry` re-export)
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Produces (`Isometry`):
  - `type t = { m00 : Num.t; m01 : Num.t; m10 : Num.t; m11 : Num.t; tx : Num.t; ty : Num.t }`
  - `identity : t`
  - `apply_point : t -> Geom.point -> Geom.point`
  - `compose : t -> t -> t` — `compose a b` is `a` after `b`: `(compose a b)(p) = a (b p)`.
  - `inverse : t -> t`
  - `reflect_across_line : Geom.line -> t`
  - `det_sign : t -> int` — orientation: `+1` direct (front), `−1` reflected (back).

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_beloch.ml`:

```ocaml
let test_isometry_basics () =
  let i = Isometry.identity in
  Alcotest.(check bool) "identity fixes a point" true
    (Geom.point_equal (Isometry.apply_point i (pt 3 4)) (pt 3 4));
  Alcotest.(check int) "identity det +1" 1 (Isometry.det_sign i)

let test_isometry_reflection () =
  let l = { Geom.a = q 1; b = q 0; c = half } in
  let r = Isometry.reflect_across_line l in
  (* agrees with Geom.reflect_point *)
  Alcotest.(check bool) "reflection isometry matches reflect_point" true
    (Geom.point_equal (Isometry.apply_point r (pt 0 0)) (Geom.reflect_point l (pt 0 0)));
  Alcotest.(check int) "a reflection has det -1" (-1) (Isometry.det_sign r);
  (* two reflections compose to a direct isometry *)
  let rr = Isometry.compose r r in
  Alcotest.(check int) "reflection twice has det +1" 1 (Isometry.det_sign rr);
  Alcotest.(check bool) "reflection twice is identity on a point" true
    (Geom.point_equal (Isometry.apply_point rr (pt 0 0)) (pt 0 0))

let test_isometry_inverse () =
  let l = { Geom.a = q 1; b = q 1; c = q 1 } in   (* x + y = 1, a slanted mirror *)
  let r = Isometry.reflect_across_line l in
  let inv = Isometry.inverse r in
  let p = pt 2 5 in
  Alcotest.(check bool) "inverse undoes apply" true
    (Geom.point_equal (Isometry.apply_point inv (Isometry.apply_point r p)) p)
```

Register in a new `"isometry"` group:

```ocaml
      ("isometry",
       [ Alcotest.test_case "basics" `Quick test_isometry_basics;
         Alcotest.test_case "reflection" `Quick test_isometry_reflection;
         Alcotest.test_case "inverse" `Quick test_isometry_inverse ]);
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `Unbound module Isometry`.

- [ ] **Step 3: Create `lib/isometry.ml`**

```ocaml
(** Exact 2D isometry: an orthogonal 2×2 matrix (det ±1) plus a translation,
    all in [Num]. Used to place each face of the paper onto the table. *)

type t = {
  m00 : Num.t;
  m01 : Num.t;
  m10 : Num.t;
  m11 : Num.t;
  tx : Num.t;
  ty : Num.t;
}

let identity : t =
  {
    m00 = Num.one;
    m01 = Num.zero;
    m10 = Num.zero;
    m11 = Num.one;
    tx = Num.zero;
    ty = Num.zero;
  }

let apply_point (i : t) (p : Geom.point) : Geom.point =
  {
    Geom.x =
      Num.add (Num.add (Num.mul i.m00 p.Geom.x) (Num.mul i.m01 p.Geom.y)) i.tx;
    y = Num.add (Num.add (Num.mul i.m10 p.Geom.x) (Num.mul i.m11 p.Geom.y)) i.ty;
  }

(* (compose a b)(p) = a (b p) *)
let compose (a : t) (b : t) : t =
  {
    m00 = Num.add (Num.mul a.m00 b.m00) (Num.mul a.m01 b.m10);
    m01 = Num.add (Num.mul a.m00 b.m01) (Num.mul a.m01 b.m11);
    m10 = Num.add (Num.mul a.m10 b.m00) (Num.mul a.m11 b.m10);
    m11 = Num.add (Num.mul a.m10 b.m01) (Num.mul a.m11 b.m11);
    tx = Num.add (Num.add (Num.mul a.m00 b.tx) (Num.mul a.m01 b.ty)) a.tx;
    ty = Num.add (Num.add (Num.mul a.m10 b.tx) (Num.mul a.m11 b.ty)) a.ty;
  }

let det_sign (i : t) : int =
  Num.sign (Num.sub (Num.mul i.m00 i.m11) (Num.mul i.m01 i.m10))

(* M is orthogonal, so M⁻¹ = Mᵀ; the inverse maps q ↦ Mᵀ (q − t). *)
let inverse (i : t) : t =
  let m00 = i.m00 and m01 = i.m10 and m10 = i.m01 and m11 = i.m11 in
  {
    m00;
    m01;
    m10;
    m11;
    tx = Num.neg (Num.add (Num.mul m00 i.tx) (Num.mul m01 i.ty));
    ty = Num.neg (Num.add (Num.mul m10 i.tx) (Num.mul m11 i.ty));
  }

(* Reflection across a·x + b·y = c as an isometry:
   M = I − 2/(a²+b²) [[a² ab];[ab b²]] ;  t = 2c/(a²+b²) (a, b). *)
let reflect_across_line (l : Geom.line) : t =
  let n2 = Num.add (Num.mul l.Geom.a l.Geom.a) (Num.mul l.Geom.b l.Geom.b) in
  let f = Num.div (Num.of_int 2) n2 in
  {
    m00 = Num.sub Num.one (Num.mul f (Num.mul l.Geom.a l.Geom.a));
    m01 = Num.neg (Num.mul f (Num.mul l.Geom.a l.Geom.b));
    m10 = Num.neg (Num.mul f (Num.mul l.Geom.a l.Geom.b));
    m11 = Num.sub Num.one (Num.mul f (Num.mul l.Geom.b l.Geom.b));
    tx = Num.mul f (Num.mul l.Geom.c l.Geom.a);
    ty = Num.mul f (Num.mul l.Geom.c l.Geom.b);
  }
```

- [ ] **Step 4: Re-export in `lib/beloch.ml`**

Add alongside the other `module X = X` re-exports (e.g. after `module Geom = Geom`):

```ocaml
module Isometry = Isometry
```

- [ ] **Step 5: Run to verify they pass**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS, build clean.

- [ ] **Step 6: Commit**

```bash
git add lib/isometry.ml lib/beloch.ml tests/test_beloch.ml
git commit -m "feat(isometry): exact 2D isometry module (compose, inverse, reflection)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `Geom` — convex half-plane clip and point containment

**Files:**
- Modify: `lib/geom.ml` (append two functions)
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Produces:
  - `Geom.clip_convex_halfplane : line -> int -> point array -> point array` — `clip_convex_halfplane l keep poly` returns the sub-polygon of convex CCW `poly` on the side where `side_of_line l = keep` (points on the line are kept). Returns `[||]` when nothing on that side. Result is convex CCW.
  - `Geom.in_convex_polygon : point array -> point -> bool` — true iff `p` is inside or on the boundary of convex CCW `poly`.

- [ ] **Step 1: Write the failing tests**

```ocaml
let test_clip_halfplane () =
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let l = { Geom.a = q 1; b = q 0; c = half } in    (* x = 1/2 *)
  let right = Geom.clip_convex_halfplane l 1 sq in
  let left = Geom.clip_convex_halfplane l (-1) sq in
  Alcotest.(check int) "right half has 4 vertices" 4 (Array.length right);
  Alcotest.(check int) "left half has 4 vertices" 4 (Array.length left);
  Alcotest.(check bool) "right half area = 1/2" true
    (Num.equal (Geom.signed_area right) half);
  Alcotest.(check bool) "left half area = 1/2" true
    (Num.equal (Geom.signed_area left) half)

let test_clip_halfplane_all_or_nothing () =
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let l = { Geom.a = q 1; b = q 0; c = q 2 } in     (* x = 2, misses the square *)
  Alcotest.(check int) "whole square on the -1 side" 4
    (Array.length (Geom.clip_convex_halfplane l (-1) sq));
  Alcotest.(check int) "nothing on the +1 side" 0
    (Array.length (Geom.clip_convex_halfplane l 1 sq))

let test_in_convex_polygon () =
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  Alcotest.(check bool) "center inside" true
    (Geom.in_convex_polygon sq { Geom.x = half; y = half });
  Alcotest.(check bool) "corner on boundary counts" true
    (Geom.in_convex_polygon sq (pt 0 0));
  Alcotest.(check bool) "outside is outside" false
    (Geom.in_convex_polygon sq (pt 2 2))
```

Register in a new `"fold_clip"` group:

```ocaml
      ("fold_clip",
       [ Alcotest.test_case "half-plane clip" `Quick test_clip_halfplane;
         Alcotest.test_case "clip all or nothing" `Quick test_clip_halfplane_all_or_nothing;
         Alcotest.test_case "point in convex polygon" `Quick test_in_convex_polygon ]);
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `Unbound value Geom.clip_convex_halfplane`.

- [ ] **Step 3: Implement in `lib/geom.ml`**

Append at the end of the file:

```ocaml
(* Keep the part of convex CCW [poly] on the side where [side_of_line l = keep]
   (vertices on the line are kept). Sutherland–Hodgman against one half-plane;
   preserves convexity and CCW order. Returns [||] if no area remains. *)
let clip_convex_halfplane (l : line) (keep : int) (poly : point array) :
    point array =
  let n = Array.length poly in
  if n = 0 then [||]
  else begin
    let out = ref [] in
    for i = 0 to n - 1 do
      let cur = poly.(i) and nxt = poly.((i + 1) mod n) in
      let sc = side_of_line l cur and sn = side_of_line l nxt in
      if sc = keep || sc = 0 then out := cur :: !out;
      if sc <> 0 && sn <> 0 && sc <> sn then
        match intersection l (line_through cur nxt) with
        | Some r -> out := r :: !out
        | None -> ()
    done;
    let pts = List.rev !out in
    if List.length pts < 3 then [||] else Array.of_list pts
  end

(* p inside or on the boundary of convex CCW [poly]: left-of-or-on every edge. *)
let in_convex_polygon (poly : point array) (p : point) : bool =
  let n = Array.length poly in
  let ok = ref true in
  for i = 0 to n - 1 do
    let a = poly.(i) and b = poly.((i + 1) mod n) in
    let cross =
      Num.sub
        (Num.mul (Num.sub b.x a.x) (Num.sub p.y a.y))
        (Num.mul (Num.sub b.y a.y) (Num.sub p.x a.x))
    in
    if Num.sign cross < 0 then ok := false
  done;
  !ok
```

- [ ] **Step 4: Run to verify they pass**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS, build clean.

- [ ] **Step 5: Commit**

```bash
git add lib/geom.ml tests/test_beloch.ml
git commit -m "feat(geom): convex half-plane clip and point-in-convex test

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `Fold_state` module — faces, layers, and the simple fold

**Files:**
- Create: `lib/fold_state.ml`
- Modify: `lib/beloch.ml` (add `module Fold_state = Fold_state` re-export)
- Test: `tests/test_beloch.ml`

**Interfaces:**
- Consumes: `Isometry` (Task 2), `Geom.clip_convex_halfplane` / `in_convex_polygon` (Task 3), `Geom.side_of_line` (Task 1), `Geom.signed_area`.
- Produces (`Fold_state`):
  - `type face = { paper : Geom.point array; iso : Isometry.t }`
  - `type t = { faces : face array; layers : int array }` — `layers` lists face indices bottom→top.
  - `init_square : t` — one identity-placed unit-square face, single layer.
  - `table_polygon : t -> int -> Geom.point array` — face `i`'s polygon in table coords.
  - `table_position : t -> Geom.point -> Geom.point` — current table position of a material paper point (resolved via the face containing it).
  - `simple_fold : t -> axis:Geom.line -> move_side:int -> valley:bool -> t` — reflect every layer-part on the `move_side` of `axis` and restack (valley → moved parts on top, mountain → underneath, reversed).

- [ ] **Step 1: Write the failing tests**

```ocaml
let fs_pt = pt   (* reuse existing helper *)

let test_fold_state_init () =
  let st = Fold_state.init_square in
  Alcotest.(check int) "one face" 1 (Array.length st.Fold_state.faces);
  Alcotest.(check int) "one layer" 1 (Array.length st.Fold_state.layers);
  Alcotest.(check bool) "corner .a at (0,0) on the table" true
    (Geom.point_equal (Fold_state.table_position st (fs_pt 0 0)) (fs_pt 0 0))

let test_fold_state_half () =
  (* fold the right half of the square onto the left, valley, along x = 1/2.
     map .b (1,0) onto .a (0,0): axis is x = 1/2; moving side is .b's side (+1). *)
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  Alcotest.(check int) "two faces after one fold" 2 (Array.length st.Fold_state.faces);
  Alcotest.(check int) "two layers" 2 (Array.length st.Fold_state.layers);
  (* the material point .b = (1,0) now lands exactly on .a = (0,0) *)
  Alcotest.(check bool) ".b maps onto .a" true
    (Geom.point_equal (Fold_state.table_position st (fs_pt 1 0)) (fs_pt 0 0));
  (* both faces' table footprints lie in the left half (x ≤ 1/2) *)
  let all_left =
    Array.for_all
      (fun i ->
        Array.for_all
          (fun p -> Num.compare p.Geom.x half <= 0)
          (Fold_state.table_polygon st i))
      [| 0; 1 |]
  in
  Alcotest.(check bool) "folded footprint is the left half" true all_left

let test_fold_state_layer_order () =
  (* valley fold: the moved face is the top layer (last in `layers`). The moved
     face is the one whose isometry is a reflection (det -1). *)
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  let top = st.Fold_state.layers.(Array.length st.Fold_state.layers - 1) in
  Alcotest.(check int) "top layer is the moved (reflected) face" (-1)
    (Isometry.det_sign st.Fold_state.faces.(top).Fold_state.iso);
  let bottom = st.Fold_state.layers.(0) in
  Alcotest.(check int) "bottom layer is stationary (det +1)" 1
    (Isometry.det_sign st.Fold_state.faces.(bottom).Fold_state.iso)
```

Register in a new `"fold_state"` group:

```ocaml
      ("fold_state",
       [ Alcotest.test_case "init square" `Quick test_fold_state_init;
         Alcotest.test_case "half fold geometry" `Quick test_fold_state_half;
         Alcotest.test_case "valley layer order" `Quick test_fold_state_layer_order ]);
```

- [ ] **Step 2: Run to verify they fail**

Run: `dune build 2>&1`
Expected: FAIL — `Unbound module Fold_state`.

- [ ] **Step 3: Create `lib/fold_state.ml`**

```ocaml
(** The folded state of the paper as a stack of flat faces. Each face is a
    convex CCW polygon in paper coordinates plus the isometry placing it on the
    table; [layers] orders the face indices bottom→top. Flat folds keep
    everything in the table plane, so the only "3D" is this stacking order. *)

type face = { paper : Geom.point array; iso : Isometry.t }
type t = { faces : face array; layers : int array }

let init_square : t =
  let p x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  {
    faces = [| { paper = [| p 0 0; p 1 0; p 1 1; p 0 1 |]; iso = Isometry.identity } |];
    layers = [| 0 |];
  }

let table_polygon (st : t) (i : int) : Geom.point array =
  Array.map (Isometry.apply_point st.faces.(i).iso) st.faces.(i).paper

(* current table position of a material paper point: find the face whose paper
   polygon contains it, apply that face's isometry. Faces partition the paper,
   and isometries agree on shared crease edges, so any containing face works. *)
let table_position (st : t) (paper : Geom.point) : Geom.point =
  let n = Array.length st.faces in
  let rec find i =
    if i >= n then invalid_arg "Fold_state.table_position: point in no face"
    else if Geom.in_convex_polygon st.faces.(i).paper paper then
      Isometry.apply_point st.faces.(i).iso paper
    else find (i + 1)
  in
  find 0

(* simple flat fold: reflect every layer-part on [move_side] of [axis] across it,
   then restack. valley → moved parts (reversed) on top; mountain → underneath. *)
let simple_fold (st : t) ~(axis : Geom.line) ~(move_side : int) ~(valley : bool) :
    t =
  let refl = Isometry.reflect_across_line axis in
  let stay = ref [] (* accumulates top→bottom via prepend *) in
  let mov = ref [] (* accumulates top→bottom via prepend = reversed order *) in
  Array.iter
    (fun fi ->
      let f = st.faces.(fi) in
      let table = table_polygon st fi in
      let inv = Isometry.inverse f.iso in
      let part keep =
        let sub = Geom.clip_convex_halfplane axis keep table in
        if Array.length sub >= 3 then
          Some (Array.map (Isometry.apply_point inv) sub)
        else None
      in
      (match part (- move_side) with
       | Some paper -> stay := { paper; iso = f.iso } :: !stay
       | None -> ());
      (match part move_side with
       | Some paper -> mov := { paper; iso = Isometry.compose refl f.iso } :: !mov
       | None -> ()))
    st.layers;
  let stationary = List.rev !stay (* bottom→top *) in
  let moved = !mov (* already reversed: top→bottom of original = wrap order *) in
  let ordered = if valley then stationary @ moved else moved @ stationary in
  let faces = Array.of_list ordered in
  { faces; layers = Array.init (Array.length faces) (fun i -> i) }
```

- [ ] **Step 4: Re-export in `lib/beloch.ml`**

Add alongside the other re-exports:

```ocaml
module Fold_state = Fold_state
```

- [ ] **Step 5: Run to verify they pass**

Run: `dune fmt 2>&1; dune build 2>&1 && dune test 2>&1`
Expected: PASS, build clean.

- [ ] **Step 6: Commit**

```bash
git add lib/fold_state.ml lib/beloch.ml tests/test_beloch.ml
git commit -m "feat(fold-state): folded-state model with the simple flat fold

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage** (against the folded-state design doc §3 data model, §5 fold algorithm, parts of §4 reference resolution):
- `Isometry` (2×2 + translation, compose/inverse/reflect/det_sign) → Task 2.
- Exact reflection without sqrt → Task 1 (`reflect_point`) and Task 2 (`reflect_across_line`); the tests assert they agree.
- Convex half-plane clip (faces stay convex) → Task 3.
- `Fold_state` faces + global layer order; `simple_fold` split → reflect → restack (reverse + above/below) → Task 4.
- Material-point resolution against current state (`table_position`) → Task 4.
- **Not in this plan (Plan B-2):** the fold *evaluator* (wiring `Ast.fold_spec` through `eval`, computing the axis from current positions, `moving` defaulting/errors), the dual `creasePattern` + `foldedForm` output, derived M/V, `faceOrders`. Intentional — these build on the landed foundations.

**Placeholder scan:** none — every code step shows the full function bodies and complete test cases.

**Type consistency:** `Isometry.t` fields (`m00..ty`) and functions (`identity`, `apply_point`, `compose`, `inverse`, `reflect_across_line`, `det_sign`) are defined in Task 2 and used verbatim in Task 4. `Fold_state.face`/`t` field names (`paper`, `iso`, `faces`, `layers`) match between the interface block, the implementation, and the tests. `Geom.clip_convex_halfplane l keep poly`, `Geom.in_convex_polygon poly p`, `Geom.side_of_line`, `Geom.reflect_point` signatures are consistent across Tasks 1, 3, 4. Test helpers (`q`, `pt`, `half`) are the ones already defined at the top of `tests/test_beloch.ml`.
